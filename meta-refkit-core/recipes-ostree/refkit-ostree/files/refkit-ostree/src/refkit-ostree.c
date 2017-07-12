/*
 * Copyright (c) 2017, Intel Corporation
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *   * Redistributions of source code must retain the above copyright notice,
 *     this list of conditions and the following disclaimer.
 *   * Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *   * Neither the name of Intel Corporation nor the names of its contributors
 *     may be used to endorse or promote products derived from this software
 *     without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <stdarg.h>
#include <string.h>
#include <limits.h>
#define _GNU_SOURCE                          /* getopt_long */
#include <getopt.h>
#include <locale.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <sys/mount.h>

#include <ostree-1/ostree.h>

/* defaults */
#define UPDATER_HOOK(path) HOOK_DIR"/"path
#define UPDATER_HOOK_APPLY UPDATER_HOOK("post-apply")
#define UPDATER_INTERVAL   (15 * 60)
#define UPDATER_DISTRO     "refkit"
#define UPDATER_PREFIX     "REFKIT_OSTREE"

/* updater modes */
enum {
    UPDATER_MODE_DEFAULT,
    UPDATER_MODE_FETCH  = 0x1,               /* only fetch, don't apply */
    UPDATER_MODE_APPLY  = 0x2,               /* don't fetch, only apply */
    UPDATER_MODE_UPDATE = 0x3,               /* fetch and apply updates */
    UPDATER_MODE_ENTRIES,                    /* parse and show boot entries */
    UPDATER_MODE_RUNNING,                    /* show running entry */
    UPDATER_MODE_LATEST,                     /* show running entry */
    UPDATER_MODE_PATCH,                      /* patch /proc/cmdline */
    UPDATER_MODE_PREPARE,                    /* prepare root from initramfs */
};

/* printing modes */
enum {
    PRINT_HUMAN_READABLE,                    /* for human/primate consumption */
    PRINT_SHELL_EVAL,                        /* for shell eval */
    PRINT_SHELL_EXPORT,                      /* for shell eval, exporting */
};

/* a boot entry */
typedef struct {
    int    id;                               /* 0/1 entry id */
    int    version;                          /* entry version */
    char  *options;                          /* entry options */
    char  *boot;                             /* boot path */
    char  *deployment;                       /*   resolved to deployment */
    dev_t  device;                           /* device number */
    ino_t  inode;                            /* inode number */
} boot_entry_t;

/* updater runtime context */
typedef struct {
    int                    mode;             /* mode of operation */
    int                    interval;         /* update check interval */
    int                    oneshot;          /* run once, then exit */
    const char            *distro;           /* distro name */
    OstreeRepo            *repo;             /* ostree repo instance */
    OstreeSysroot         *sysroot;          /* ostree sysroot instance */
    OstreeSysrootUpgrader *u;                /* ostree sysroot upgrader */
    const char            *hook_apply;       /* post-update script */
    int                    inhibit_fd;       /* shutdown inhibitor pid */
    int                    inhibit_pid;      /* active inhibitor process */
    const char            *argv0;            /* us... */
    boot_entry_t           entries[2];       /* boot entries */
    int                    nentry;
    int                    latest;           /* latest boot entry */
    int                    running;          /* running boot entry */
    int                    print;            /* var/setup printing mode */
    const char            *prefix;           /* shell variable prefix */
} context_t;

/* fd redirection for child process */
typedef struct {
    int parent;                              /* original file descriptor */
    int child;                               /* dupped to this one */
} redirfd_t;

/* a file/directory, potentially under a potentially prefixed root */
typedef struct {
    const char *prefix;
    const char *root;
    const char *path;
} path_t;


/* log levels, current log level */
enum {
    UPDATER_LOG_NONE    = 0x00,
    UPDATER_LOG_FATAL   = 0x01,
    UPDATER_LOG_ERROR   = 0x02,
    UPDATER_LOG_WARN    = 0x04,
    UPDATER_LOG_INFO    = 0x08,
    UPDATER_LOG_DEBUG   = 0x10,
    UPDATER_LOG_ALL     = 0x1f,
    UPDATER_LOG_DAEMON  = UPDATER_LOG_WARN|UPDATER_LOG_ERROR|UPDATER_LOG_FATAL,
    UPDATER_LOG_CONSOLE = UPDATER_LOG_INFO|UPDATER_LOG_DAEMON,
};

static int log_mask;

/* logging macros */
#define log_fatal(...) do {                      \
        log_msg(UPDATER_LOG_FATAL, __VA_ARGS__); \
        exit(1);                                 \
    } while (0)
#define log_error(...) log_msg(UPDATER_LOG_ERROR, __VA_ARGS__)
#define log_warn(...)  log_msg(UPDATER_LOG_WARN , __VA_ARGS__)
#define log_info(...)  log_msg(UPDATER_LOG_INFO , __VA_ARGS__)
#define log_debug(...) log_msg(UPDATER_LOG_DEBUG, __VA_ARGS__)

/* macro to tag unused variables */
#define UNUSED_VAR(v) (void)v


static void log_msg(int lvl, const char *fmt, ...)
{
    static const char *prefix[] = {
        [UPDATER_LOG_FATAL] = "fatal error: ",
        [UPDATER_LOG_ERROR] = "error: ",
        [UPDATER_LOG_WARN]  = "warning: ",
        [UPDATER_LOG_INFO ] = "",
        [UPDATER_LOG_DEBUG] = "D: ",
    };
    FILE *out;
    va_list ap;

    if (!(log_mask & lvl) || lvl < UPDATER_LOG_NONE || lvl > UPDATER_LOG_DEBUG)
        return;

    switch (lvl) {
    case UPDATER_LOG_DEBUG:
    case UPDATER_LOG_INFO:
        out = stdout;
        break;
    default:
        out = stderr;
        break;
    }

    fputs(prefix[lvl], out);
    va_start(ap, fmt);
    vfprintf(out, fmt, ap);
    va_end(ap);
    fputc('\n', out);
    fflush(out);
}


#ifdef __REFKIT_UPDATER__
static void log_handler(const gchar *domain, GLogLevelFlags level,
                        const gchar *message, gpointer user_data)
{
    static int map[] = {
        [G_LOG_LEVEL_CRITICAL] = UPDATER_LOG_FATAL,
        [G_LOG_LEVEL_ERROR]    = UPDATER_LOG_ERROR,
        [G_LOG_LEVEL_WARNING]  = UPDATER_LOG_WARN,
        [G_LOG_LEVEL_MESSAGE]  = UPDATER_LOG_INFO,
        [G_LOG_LEVEL_INFO]     = UPDATER_LOG_INFO,
        [G_LOG_LEVEL_DEBUG]    = UPDATER_LOG_DEBUG,
    };
    int fatal, lvl;

    UNUSED_VAR(user_data);

    fatal  = level & G_LOG_FLAG_FATAL;
    level &= G_LOG_LEVEL_MASK;

    if (level < 0 || level >= (int)(sizeof(map) / sizeof(map[0])))
        return;

    if (fatal)
        lvl = UPDATER_LOG_FATAL;
    else
        lvl = map[level];

    if (lvl == UPDATER_LOG_DEBUG)
        log_debug("[%s] %s", domain, message);
    else
        log_msg(lvl, "%s", message);
}
#endif


static void set_defaults(context_t *c, const char *argv0)
{
    if (isatty(fileno(stdout)))
        log_mask = UPDATER_LOG_CONSOLE;
    else
        log_mask = UPDATER_LOG_DAEMON;

    memset(c, 0, sizeof(*c));
    c->mode       = UPDATER_MODE_DEFAULT;
    c->interval   = UPDATER_INTERVAL;
    c->hook_apply = UPDATER_HOOK_APPLY;
    c->argv0      = argv0;
    c->distro     = UPDATER_DISTRO;
    c->prefix     = UPDATER_PREFIX;
    c->nentry     = 0;
    c->latest     = -1;
    c->running    = -1;
}


#define OPTION_FETCH   "-F/--fetch-only"
#define OPTION_APPLY   "-A/--apply-only"
#define OPTION_ENTRIES "-b/boot-entries"
#define OPTION_RUNNING "-r/running-entry"
#define OPTION_LATEST  "-L/latest-entry"
#define OPTION_PATCH   "-p/patch-procfs"
#define OPTION_PREPARE "-I/--prepare-root"

static const char *mode_option(int mode)
{
    switch (mode) {
    case UPDATER_MODE_FETCH:   return OPTION_FETCH;
    case UPDATER_MODE_APPLY:   return OPTION_APPLY;
    case UPDATER_MODE_ENTRIES: return OPTION_ENTRIES;
    case UPDATER_MODE_RUNNING: return OPTION_RUNNING;
    case UPDATER_MODE_LATEST:  return OPTION_LATEST;
    case UPDATER_MODE_PATCH:   return OPTION_PATCH;
    case UPDATER_MODE_PREPARE: return OPTION_PREPARE;
    default:                   return "WTF?";
    }
}


static void set_mode(context_t *c, int mode)
{
    if (c->mode)
        log_warn("multiple modes specified (%s, %s), using last one",
                 mode_option(c->mode), mode_option(mode));

    c->mode = mode;
}


static void print_usage(const char *argv0, int exit_code, const char *fmt, ...)
{
    va_list ap;
    context_t c;

    if (fmt != NULL) {
        va_start(ap, fmt);
        vfprintf(stderr, fmt, ap);
        fputc('\n', stderr);
        va_end(ap);
    }

    fprintf(stderr, "usage: %s [options]\n"
            "\n"
            "The possible options are:\n"
            "  -b, --boot-entries           list boot entries\n"
            "  -r, --running-entry          show running entry\n"
            "  -L, --latest-entry           show latest local available entry\n"
            "  -p, --patch-procfs           patch /proc/cmdline\n"
            "  -I, --prepare-root           prepare root (from initramfs)\n"
            "  -s, --shell                  list/show as shell assignment\n"
            "  -S, --shell-export           use export in shell assignments\n"
            "  -V, --prefix                 variable prefix in assignments\n"
#ifdef __REFKIT_UPDATER__
            "  -F, --fetch-only             fetch without applying updates\n"
            "  -A, --apply-only             don't fetch, apply cached updates\n"
            "  -O, --one-shot               run once, then exit\n"
            "  -i, --check-interval         update check interval (in seconds)\n"
            "  -P, --post-apply-hook PATH   script to run after an update\n"
#endif
            "  -l, --log LEVELS             set logging levels\n"
            "  -v, --verbose                increase loggin verbosity\n"
            "  -d, --debug [DOMAINS]        enable given debug domains or all\n"
            "  -h, --help                   print this help on usage\n",
            argv0);

    set_defaults(&c, argv0);

#ifdef __REFKIT_UPDATER__
    fprintf(stderr, "\nThe defaults are:\n"
            "  distro name: %s\n"
            "  post-apply hook: %s\n"
            "  shell variable prefix: %s\n"
            "  check interval: %d\n",
            c.distro,
            c.hook_apply,
            c.prefix,
            c.interval);
#endif

    exit(exit_code);
}


static int parse_log_levels(const char *levels)
{
    const char *l, *e, *n;
    int         c, mask;

    if (!strcmp(levels, "none"))
        return UPDATER_LOG_NONE;
    if (!strcmp(levels, "all"))
        return UPDATER_LOG_ALL;

    for (mask = 0, l = levels; l != NULL; l = n) {
        e = strchr(l, ',');
        if (e == NULL)
            n = NULL;
        else
            n = e + 1;

        if ((c = e - l) == 0)
            continue;

        switch (c) {
        case 4:
            if (!strncmp(l, "none", 4))
                continue;
            else if (!strncmp(l, "info", 4))
                mask |= UPDATER_LOG_INFO;
            else if (!strncmp(l, "warn", 4))
                mask |= UPDATER_LOG_WARN;
            else
                goto ignore_unknown;
            break;

        case 5:
            if (!strncmp(l, "debug", 5))
                mask |= UPDATER_LOG_DEBUG;
            else if (!strncmp(l, "error", 5))
                mask |= UPDATER_LOG_ERROR;
            else if (!strncmp(l, "fatal", 5))
                mask |= UPDATER_LOG_FATAL;
            else
                goto ignore_unknown;
            break;

        case 6:
            if (!strncmp(l, "daemon", 6))
                mask |= UPDATER_LOG_DAEMON;
            else
                goto ignore_unknown;
            break;

        case 7:
            if (!strncmp(l, "console", 7))
                mask |= UPDATER_LOG_CONSOLE;
            else
                goto ignore_unknown;
            break;

        default:
        ignore_unknown:
            log_error("unknown log level %*.*s", c, c, l);
            return log_mask;
        }
    }

    return mask;
}


static void enable_debug_domains(char **domains)
{
    static char   debug[1024];
    char        **dom, *p;
    const char   *t;
    int           l, n;

    p = debug;
    l = sizeof(debug);
    for (dom = domains, t = ""; *dom && l > 0; dom++, t = ",") {
        n = snprintf(p, l, "%s%s", t, *dom);

        if (n < 0 || n >= l) {
            *p = '\0';
            l  = 0;
        }
        else {
            p += n;
            l -= n;
        }
    }

    log_mask |= UPDATER_LOG_DEBUG;

    log_debug("enabling debug domains '%s'", debug);
    setenv("G_MESSAGES_DEBUG", debug, TRUE);
}


static int parse_boot_entry(FILE *fp, boot_entry_t *b)
{
    char line[512], path[PATH_MAX], *p, *e;
    int  l;

    free(b->options);
    free(b->boot);
    free(b->deployment);
    b->options = b->boot = b->deployment = NULL;

    b->version = 0;
    b->device  = 0;
    b->inode   = 0;

    while (fgets(line, sizeof(line), fp) != NULL) {
        log_debug("read config entry line '%s'");

        if (!strncmp(line, "options ", 8)) {
            p = line + 8;
            e = strchr(line, '\n');
            l = e ? e - p : (int)strlen(p);

            if ((b->options = malloc(l + 1)) == NULL)
                goto nomem;

            strncpy(b->options, p, l);
            b->options[l] = '\0';

            if (b->version)
                break;
            else
                continue;
        }

        if (!strncmp(line, "version ", 8)) {
            p = line + 8;

            b->version = (int)strtoul(p, NULL, 10);

            if (b->options)
                break;
            else
                continue;
        }
    }

    if (!b->version)
        goto missing_version;

    if (b->options == NULL)
        goto missing_options;

    if ((p = strstr(b->options, "ostree=")) == NULL)
        goto missing_ostree;

    p += 7;

    if ((e = strchr(p, ' ')) == NULL)
        l = strlen(p);
    else
        l = e - p;

    snprintf(path, sizeof(path), "%*.*s", l, l, p);

    if ((b->boot = strdup(path)) == NULL)
        goto nomem;

    return 0;

 missing_version:
    log_error("missing config entry 'version'");
    return -1;

 missing_options:
    log_error("missing config entry 'options'");
    return -1;

 missing_ostree:
    log_error("missing ostree-entry in 'options'");
    return -1;

 nomem:
    return -1;
}


static int resolve_boot_path(boot_entry_t *b)
{
    struct stat st;
    char        path[PATH_MAX], pwd[PATH_MAX], *p;

    if (stat(p = b->boot, &st) < 0 && errno == ENOENT) {
        snprintf(path, sizeof(path), "/rootfs/%s", b->boot);

        if (stat(p = path, &st) < 0)
            goto invalid_path;
    }

    if (getcwd(pwd, sizeof(pwd)) == NULL)
        goto resolve_failed;

    if (chdir(p) < 0)
        goto resolve_failed;

    if (getcwd(path, sizeof(path)) == NULL)
        goto resolve_failed;

    chdir(pwd);

    if (!strncmp(path, "/rootfs/", 8))
        p = path + 7;
    else
        p = path;

    if (!strncmp(path, "/sysroot/", 9))
        p += 8;

    b->deployment = strdup(p);

    if (b->deployment == NULL)
        goto nomem;

    if (stat(path, &st) < 0)
        goto resolve_failed;

    b->device = st.st_dev;
    b->inode  = st.st_ino;

    return 0;

 invalid_path:
    log_error("failed to resolve boot path '%s'", p);
    return -1;

 resolve_failed:
    log_error("failed to resolve boot symlink '%s' to deployment", p);
 nomem:
    return -1;
}


static int get_boot_entries(context_t *c)
{
    boot_entry_t *buf  = c->entries;
    size_t        size = sizeof(c->entries) / sizeof(c->entries[0]);
    struct stat   root;
    char          conf[PATH_MAX], *base;
    boot_entry_t *b;
    int           latest, i, status;
    FILE         *fp = NULL;

    if (c->nentry > 0)
        return c->nentry;

    if (access(base = "/boot/loader/entries", X_OK) < 0) {
        if (errno == ENOENT) {
            if (access(base = "/rootfs/boot/loader/entries", X_OK) < 0) {
                if (errno == ENOENT)
                    goto no_entries;

                goto get_failed;
            }
        }
        else
            goto get_failed;
    }

    if (stat("/", &root) < 0)
        memset(&root, 0, sizeof(root));

    c->latest = c->running = latest = -1;

    for (i = 0, b = buf; i < 2; i++, b++) {
        if (i >= (int)size)
            goto no_buf;

        memset(b, 0, sizeof(*b));
        b->id = i;

        snprintf(conf, sizeof(conf), "%s/ostree-%s-%d.conf", base, c->distro, i);

        if ((fp = fopen(conf, "r")) == NULL) {
            if (i == 0)
                goto get_failed;
            else
                break;
        }

        log_debug("parsing config file '%s'...", conf);
        status = parse_boot_entry(fp, b);

        fclose(fp);
        fp = NULL;

        if (status < 0)
            goto invalid_entry;

        if (resolve_boot_path(b) < 0)
            goto invalid_entry;

        if (b->version > latest) {
            c->latest = i;
            latest = b->version;
        }

        if (b->device == root.st_dev && b->inode == root.st_ino)
            c->running = i;
    }

    if (i < (int)size - 1)
        memset(buf + i, 0, sizeof(*buf));

    return (c->nentry = i);

 no_entries:
 get_failed:
    log_error("failed to find any boot loader entries");
    if (fp)
        fclose(fp);
    return -1;

 invalid_entry:
    log_error("invalid entry, failed to parse '%s'", conf);

 no_buf:
    errno = ENOBUFS;
    return -1;
}


static void parse_cmdline(context_t *c, int argc, char **argv)
{
#ifdef __REFKIT_UPDATER__
#   define UPDATER_OPTIONS "FAOi:P:R"
#   define UPDATER_ENTRIES \
        { "fetch-only"     , no_argument      , NULL, 'F' }, \
        { "apply-only"     , no_argument      , NULL, 'A' }, \
        { "one-shot"       , no_argument      , NULL, 'O' }, \
        { "check-interval" , required_argument, NULL, 'i' }, \
        { "post-apply-hook", required_argument, NULL, 'P' }
#else
#    define UPDATER_OPTIONS ""
#    define UPDATER_ENTRIES { NULL, 0, NULL, 0 }
#endif

#   define OPTIONS "-brLpIsSV:l:vd::h"UPDATER_OPTIONS
    static struct option options[] = {
        { "boot-entries"   , no_argument      , NULL, 'b' },
        { "running-entry"  , no_argument      , NULL, 'r' },
        { "latest-entry"   , no_argument      , NULL, 'L' },
        { "patch-procfs"   , no_argument      , NULL, 'p' },
        { "prepare-root"   , no_argument      , NULL, 'I' },
        { "shell"          , no_argument      , NULL, 's' },
        { "shell-export"   , no_argument      , NULL, 'S' },
        { "prefix"         , required_argument, NULL, 'V' },
        { "log"            , required_argument, NULL, 'l' },
        { "verbose"        , no_argument      , NULL, 'v' },
        { "debug"          , optional_argument, NULL, 'd' },
        { "help"           , no_argument      , NULL, 'h' },
        UPDATER_ENTRIES                                    ,
        { NULL, 0, NULL, 0 }
    };
    static char *domains[32] = { [0 ... 31] = NULL };
    int          ndomain     = 0;

    int   opt, vmask, lmask;
#ifdef __REFKIT_UPDATER__
    char *e;
#endif

    set_defaults(c, argv[0]);
    lmask = 0;
    vmask = log_mask;

    while ((opt = getopt_long(argc, argv, OPTIONS, options, NULL)) != -1) {
        switch (opt) {
        case 'b':
            set_mode(c, UPDATER_MODE_ENTRIES);
            break;

        case 'r':
            set_mode(c, UPDATER_MODE_RUNNING);
            break;

        case 'L':
            set_mode(c, UPDATER_MODE_LATEST);
            break;

        case 'p':
            set_mode(c, UPDATER_MODE_PATCH);
            break;

        case 'I':
            set_mode(c, UPDATER_MODE_PREPARE);
            break;

        case 's':
            c->print = PRINT_SHELL_EVAL;
            break;

        case 'S':
            c->print = PRINT_SHELL_EXPORT;
            break;

        case 'V':
            c->prefix = optarg;
            break;

#ifdef __REFKIT_UPDATER__
        case 'F':
            set_mode(c, UPDATER_MODE_FETCH);
            break;

        case 'A':
            set_mode(c, UPDATER_MODE_APPLY);
            break;

        case 'O':
            c->oneshot = 1;
            break;

        case 'i':
            c->interval = strtol(optarg, &e, 10);
            if (e && *e)
                log_fatal("invalid update check interval '%s'", optarg);
            break;

        case 'P':
            c->hook_apply = optarg;
            break;
#endif

        case 'l':
            lmask = parse_log_levels(optarg);
            break;

        case 'v':
            vmask <<= 1;
            vmask |= 1;
            break;

        case 'd':
            if (optarg == NULL || (optarg[0] == '*' && optarg[1] == '\0'))
                optarg = "all";

            if (ndomain < (int)(sizeof(domains) / sizeof(domains[0])) - 1)
                domains[ndomain++] = optarg;
            else
                log_warn("too many debug domains, ignoring '%s'...", optarg);
            break;

        case 'h':
            print_usage(argv[0], 0, "");

        case '?':
            print_usage(argv[0], EINVAL, "invalid option");
            break;
        }
    }
#undef OPTIONS

    if (!c->mode)
        c->mode = UPDATER_MODE_UPDATE;

    if (vmask && lmask)
        log_warn("both -v and -l options used to change logging level...");

    log_mask = vmask | lmask | UPDATER_LOG_FATAL;

    if (ndomain > 0)
        enable_debug_domains(domains);
}


#ifdef __REFKIT_UPDATER__
static void updater_init(context_t *c, const char *argv0)
{
    GCancellable *gcnc = NULL;
    GError       *gerr = NULL;

    g_set_prgname(argv0);
    g_setenv("GIO_USE_VFS", "local", TRUE);
    g_log_set_handler(G_LOG_DOMAIN, G_LOG_LEVEL_MESSAGE, log_handler, NULL);

    c->repo = ostree_repo_new_default();

    if (!ostree_repo_open(c->repo, gcnc, &gerr))
        log_fatal("failed to open OSTree repository (%s)", gerr->message);
}


static pid_t updater_invoke(char **argv, redirfd_t *rfd)
{
    pid_t      pid;
    redirfd_t *r;
    int        i, fd;

    switch ((pid = fork())) {
    case -1:
        log_error("failed to fork to exec '%s'", argv[0]);
        return -1;

    case 0:
        /*
         * child
         *   - close file descriptors skip the ones we will be dup2'ing
         *   - do filedescriptor redirections
         *   - exec
         */

        for (i = 0; i < sysconf(_SC_OPEN_MAX); i++) {
            fd = i;

            if (fd == fileno(stdout) && (log_mask & UPDATER_LOG_DEBUG))
                continue;

            if (rfd != NULL) {
                for (r = rfd; r->parent >= 0 && fd >= 0; r++)
                    if (r->parent == i)
                        fd = -1;
            }

            if (fd >= 0)
                close(fd);
        }

        if (rfd != NULL) {
            for (r = rfd; r->parent >= 0; r++) {
                if (rfd->parent == rfd->child)
                    continue;

                log_debug("redirecting child fd %d -> %d", r->child, r->parent);

                dup2(r->parent, r->child);
                close(r->parent);
            }
        }

        if (execv(argv[0], argv) < 0) {
            log_error("failed to exec '%s' (%d: %s)", argv[0],
                      errno, strerror(errno));
            exit(-1);
        }
        break;

    default:
        /*
         * parent
         *   - close file descriptor we'll be using on the child side
         */

        if (rfd != NULL) {
            for (r = rfd; r->parent >= 0; r++) {
                log_debug("closing parent fd %d", r->parent);
                close(r->parent);
            }
        }

        break;
    }

    return pid;
}


static int updater_block_shutdown(context_t *c)
{
#   define RD 0
#   define WR 1

    char      *argv[16], *path;
    int        argc, pipefds[2];
    redirfd_t  rfd[2];

    if (c->inhibit_pid > 0)
        return 0;

    if (access((path = "/usr/bin/systemd-inhibit"), X_OK) != 0)
        if (access((path = "/bin/systemd-inhibit"), X_OK) != 0)
            goto no_inhibit;

    log_debug("using %s to block system shutdown/reboot...", path);

    /*
     * systemd-inhibit --what=shutdown --who=ostree-updater \
     *    --why='pulling/applying system update' --mode=block \
     *    /bin/sh -c "read foo; exit 0"
     */

    argc = 0;
    argv[argc++] = path;
    argv[argc++] = "--what=shutdown";
    argv[argc++] = "--who=ostree-update";
    argv[argc++] = "--why=pulling/applying system update";
    argv[argc++] = "--mode=block";
    argv[argc++] = "/bin/sh";
    argv[argc++] = "-c";
    argv[argc++] = "read foo";
    argv[argc++] = NULL;

    if (pipe(pipefds) < 0)
        goto pipe_err;

    rfd[0].parent = pipefds[RD];
    rfd[0].child  = fileno(stdin);
    rfd[1].parent = rfd[1].child = -1;
    c->inhibit_fd = pipefds[WR];

    log_info("activating shutdown-inhibitor...");

    c->inhibit_pid = updater_invoke(argv, rfd);

    if (c->inhibit_pid < 0) {
        close(pipefds[WR]);
        c->inhibit_fd = -1;

        return -1;
    }

    return 0;

 no_inhibit:
    log_error("failed to find an executable systemd-inhibit");
    return -1;

 pipe_err:
    log_error("failed to create pipe for systemd-inhibit");
    return -1;

#undef RD
#undef WR
}


static void updater_allow_shutdown(context_t *c)
{
    pid_t pid;
    int   cnt, ec;

    if (!c->inhibit_pid && c->inhibit_fd < 0) {
        c->inhibit_pid = 0;
        c->inhibit_fd  = -1;

        return;
    }

    log_info("deactivating shutdown-inhibitor...");

    close(c->inhibit_fd);
    c->inhibit_fd = -1;

    usleep(10 * 1000);

    cnt = 0;
    while ((pid = waitpid(c->inhibit_pid, &ec, WNOHANG)) != c->inhibit_pid) {
        if (cnt++ < 5)
            usleep(250 * 1000);
        else
            break;
    }

    if (pid <= 0) {
        log_warn("Hmm... hammering inhibitor child (%u)...", c->inhibit_pid);
        kill(c->inhibit_pid, SIGKILL);
    }

    c->inhibit_pid = 0;
    c->inhibit_fd  = -1;
}


static int updater_prepare(context_t *c)
{
    GCancellable *gcnc   = NULL;
    GError       *gerr   = NULL;
    gboolean      locked = FALSE;

    if (c->sysroot == NULL)
        c->sysroot = ostree_sysroot_new(NULL);

    if (!ostree_sysroot_load(c->sysroot, gcnc, &gerr))
        goto load_failure;

    if (!ostree_sysroot_try_lock(c->sysroot, &locked, &gerr))
        goto lock_failure;

    if (!locked)
        return 0;

    if (updater_block_shutdown(c) < 0)
        goto block_failure;

    c->u = ostree_sysroot_upgrader_new_for_os(c->sysroot, NULL, gcnc, &gerr);

    if (c->u == NULL)
        goto no_upgrader;

    return 1;

 load_failure:
    log_error("failed to load OSTree sysroot (%s)", gerr->message);
    return -1;

 lock_failure:
    log_error("failed to lock OSTree sysroot (%s)", gerr->message);
    return -1;

 block_failure:
    log_error("failed to block shutdown");
    return -1;

 no_upgrader:
    log_error("failed to create OSTree upgrader (%s)", gerr->message);
    updater_allow_shutdown(c);
    return -1;
}


static void updater_cleanup(context_t *c)
{
    if (c->sysroot)
        ostree_sysroot_unlock(c->sysroot);

    if (c->u) {
        g_object_unref(c->u);
        c->u = NULL;
    }

    updater_allow_shutdown(c);
}


static int updater_post_apply_hook(context_t *c, const char *o, const char *n)
{
#   define TIMEOUT 60

    char      *argv[8];
    int        argc, cnt;
    redirfd_t  rfd[3];
    pid_t      pid, ec, status;

    if (!*c->hook_apply)
        goto no_hook;

    if (access(c->hook_apply, X_OK) < 0)
        goto no_access;

    argc = 0;
    argv[argc++] = (char *)c->hook_apply;
    if (o != NULL && n != NULL) {
        argv[argc++] = (char *)o;
        argv[argc++] = (char *)n;
    }
    argv[argc] = NULL;

    rfd[0].parent = rfd[0].child = fileno(stdout);
    rfd[1].parent = rfd[1].child = fileno(stderr);
    rfd[2].parent = rfd[2].child = -1;

    pid = updater_invoke(argv, rfd);

    if (pid <= 0)
        return -1;

    log_info("waiting for post-apply hook (%s) to finish...", c->hook_apply);

    cnt = 0;
    while ((status = waitpid(pid, &ec, WNOHANG)) != pid) {
        if (cnt++ < TIMEOUT)
            sleep(1);
        else
            break;
    }

    if (status != pid)
        goto timeout;

    if (!WIFEXITED(ec))
        goto hook_error;

    if (WEXITSTATUS(ec) != 0)
        goto hook_failure;

    log_info("post-apply hook (%s) succeeded", c->hook_apply);
    return 0;

 no_hook:
    return 0;

 no_access:
    log_error("can't execute post-apply hook '%s'", c->hook_apply);
    return -1;

 timeout:
    log_error("post-apply hook (%s) didn't finish in %d seconds",
              c->hook_apply, TIMEOUT);
    return -1;

 hook_error:
    log_error("post-apply hook (%s) exited abnormally", c->hook_apply);
    return -1;

 hook_failure:
    log_error("post-apply hook (%s) failed with status %d", c->hook_apply,
              WEXITSTATUS(ec));
    return -1;

#   undef TIMEOUT
}


static int updater_fetch(context_t *c)
{
    GCancellable *gcnc = NULL;
    GError       *gerr = NULL;
    int           flg  = 0;
    int           changed;
    const char   *src;

    if (!(c->mode & UPDATER_MODE_FETCH)) {
        flg = OSTREE_SYSROOT_UPGRADER_PULL_FLAGS_SYNTHETIC;
        src = "local repository";
    }
    else
        src = "server";

    log_info("polling OSTree %s for available updates...", src);

    if (!ostree_sysroot_upgrader_pull(c->u, 0, flg, NULL, &changed, gcnc, &gerr))
        goto pull_failed;

    if (!changed)
        log_info("no updates pending");
    else
        log_info("updates fetched successfully");

    return changed;

 pull_failed:
    log_error("failed to poll %s for updates (%s)", src, gerr->message);
    if (!(c->mode & UPDATER_MODE_APPLY))         /* mimick stock ostree logic */
        ostree_sysroot_cleanup(c->sysroot, NULL, NULL);
    return -1;
}


static int updater_apply(context_t *c)
{
    GCancellable *gcnc = NULL;
    GError       *gerr = NULL;
    const char   *prev = NULL;
    const char   *curr = NULL;

    if (!(c->mode & UPDATER_MODE_APPLY))
        return 0;

    if (!ostree_sysroot_upgrader_deploy(c->u, gcnc, &gerr))
        goto deploy_failure;

    log_info("OSTree updates applied");

    if (get_boot_entries(c) < 0 || c->latest < 0)
        goto entry_failure;

    if (c->running >= 0)
        prev = c->entries[c->running].deployment;
    else
        prev = "";

    curr = c->entries[c->latest].deployment;

    log_info("updated from %s to %s", *prev ? prev : "unknown", curr);

    if (updater_post_apply_hook(c, prev, curr) < 0)
        goto hook_failure;

    return 1;

 deploy_failure:
    log_error("failed to deploy OSTree updates locally (%s)", gerr->message);
    return -1;

 entry_failure:
    log_error("failed to determine post-update boot entries");
    return -1;

 hook_failure:
    log_error("update post-apply hook failed");
    return -1;
}


static int updater_run(context_t *c)
{
    int status;

    if (updater_prepare(c) <= 0)
        return -1;

    if ((status = updater_fetch(c)) > 0)
        status = updater_apply(c);

    updater_cleanup(c);

    return status;
}


static void updater_loop(context_t *c)
{
    int updates;

    /*
     * Notes:
     *
     *   This is extremely simplistic now. Since ostree uses heavily
     *   gobjects/GMainLoop we could easily/perhaps should switch
     *   to using GMainLoop.
     */

    for (;;) {
        updates = updater_run(c);

        if (c->oneshot)
            break;

        switch (updates) {
        case 0: /* no updates available */
            sleep(c->interval);
            break;

        case 1: /* updates fetched and applied, we're done until a reboot */
            exit(0);

        default:
            sleep(30);
            break;
        }
    }
}



static void updater_exit(context_t *c)
{
    UNUSED_VAR(c);
}

#endif /* __REFKIT_UPDATER__ */


static void print_entries(context_t *c)
{
    boot_entry_t *e;
    int           i;
    const char   *exp;

    if (get_boot_entries(c) < 0)
        exit(1);

    exp = (c->print == PRINT_SHELL_EXPORT ? "export " : "");

    if (c->print != PRINT_HUMAN_READABLE) {
        printf("%s%s_BOOT_ENTRIES=%d\n", exp, c->prefix, c->nentry);
        printf("%s%s_RUNNING_ENTRY=%d\n", exp, c->prefix, c->running);
        printf("%s%s_LATEST_ENTRY=%d\n", exp, c->prefix, c->latest);
    }

    for (i = 0, e = c->entries; i < c->nentry; i++, e++) {
        switch (c->print) {
        case PRINT_HUMAN_READABLE:
        default:
            printf("boot entry #%d:\n", i);
            printf("            id: %d\n", e->id);
            printf("       version: %d\n", e->version);
            printf("       options: '%s'\n", e->options);
            printf("          boot: '%s'\n", e->boot);
            printf("    deployment: '%s'\n", e->deployment);
            printf("       dev/ino: 0x%lx/0x%lx\n", e->device, e->inode);
            break;

        case PRINT_SHELL_EVAL:
        case PRINT_SHELL_EXPORT:
            printf("%s%s_BOOT%d_VERSION=%d\n", exp, c->prefix, i, e->version);
            printf("%s%s_BOOT%d_OPTIONS='%s'\n", exp, c->prefix, i, e->options);
            printf("%s%s_BOOT%d_PATH='%s'\n", exp, c->prefix, i, e->deployment);
            printf("%s%s_BOOT%d_DEVICE=0x%lx\n", exp, c->prefix, i, e->device);
            printf("%s%s_BOOT%d_INODE=%lu\n", exp, c->prefix, i, e->inode);
            break;
        }
    }

    exit(0);
}


static void print_running(context_t *c)
{
    boot_entry_t *e;
    const char   *exp;

    if (get_boot_entries(c) < 0)
        exit(1);

    if (c->running < 0)
        exit(1);

    e   = c->entries + c->running;
    exp = (c->print == PRINT_SHELL_EXPORT ? "export " : "");

    switch (c->print) {
    case PRINT_HUMAN_READABLE:
    default:
        printf("running entry #%d:\n", c->running);
        printf("            id: %d\n", e->id);
        printf("       version: %d\n", e->version);
        printf("       options: '%s'\n", e->options);
        printf("          boot: '%s'\n", e->boot);
        printf("    deployment: '%s'\n", e->deployment);
        printf("       dev/ino: 0x%lx/0x%lx\n", e->device, e->inode);
        break;

    case PRINT_SHELL_EVAL:
    case PRINT_SHELL_EXPORT:
        printf("%s%s_BOOTED_VERSION=%d\n", exp, c->prefix, e->version);
        printf("%s%s_BOOTED_OPTIONS='%s'\n", exp, c->prefix, e->options);
        printf("%s%s_BOOTED_PATH='%s'\n", exp, c->prefix, e->deployment);
        printf("%s%s_BOOTED_DEVICE=0x%lx\n", exp, c->prefix, e->device);
        printf("%s%s_BOOTED_INODE=%lu\n", exp, c->prefix, e->inode);
        break;
    }

    exit(0);
}


static void print_latest(context_t *c)
{
    boot_entry_t *e;
    const char   *exp;

    if (get_boot_entries(c) < 0)
        exit(1);

    if (c->latest < 0)
        exit(1);

    e   = c->entries + c->latest;
    exp = (c->print == PRINT_SHELL_EXPORT ? "export " : "");

    switch (c->print) {
    case PRINT_HUMAN_READABLE:
    default:
        printf("latest entry #%d:\n", c->running);
        printf("              id: %d\n", e->id);
        printf("         version: %d\n", e->version);
        printf("         options: '%s'\n", e->options);
        printf("            boot: '%s'\n", e->boot);
        printf("      deployment: '%s'\n", e->deployment);
        printf("         dev/ino: 0x%lx/0x%lx\n", e->device, e->inode);
        break;

    case PRINT_SHELL_EVAL:
    case PRINT_SHELL_EXPORT:
        printf("%s%s_LATEST_VERSION=%d\n", exp, c->prefix, e->version);
        printf("%s%s_LATEST_OPTIONS='%s'\n", exp, c->prefix, e->options);
        printf("%s%s_LATEST_PATH='%s'\n", exp, c->prefix, e->deployment);
        printf("%s%s_LATEST_DEVICE=0x%lx\n", exp, c->prefix, e->device);
        printf("%s%s_LATEST_INODE=%lu\n", exp, c->prefix, e->inode);
        break;
    }

    exit(0);
}


const char *full_path(char *buf, path_t *path)
{
    int n;

    n = snprintf(buf, PATH_MAX, "%s%s%s%s%s",
                 path->prefix ? path->prefix : "",
                 path->root && *path->root != '/' ? "/" : "",
                 path->root ? path->root : "",
                 path->path && *path->path != '/' ? "/" : "",
                 path->path ? path->path : "");

    if (n < 0 || n >= PATH_MAX)
        return "<invalid-path:too-long>";

    return buf;
}


static int bind_mount(path_t *s, path_t *d)
{
    const char *src, *dst;
    char        srcbuf[PATH_MAX], dstbuf[PATH_MAX];

    src = full_path(srcbuf, s);
    dst = full_path(dstbuf, d);

    log_info("bind-mounting %s to %s", src, dst);

    return mount(src, dst, NULL, MS_BIND, NULL);
}


static int move_mount(path_t *s, path_t *d)
{
    const char *src, *dst;
    char        srcbuf[PATH_MAX], dstbuf[PATH_MAX];

    src = full_path(srcbuf, s);
    dst = full_path(dstbuf, d);

    log_info("move-mounting %s to %s", src, dst);

    return mount(src, dst, NULL, MS_MOVE, NULL);
}


static int make_movable(const char *root, const char *dir)
{
    path_t path = { NULL, root, dir };

    return bind_mount(&path, &path);
}


static int prepare_root(const char *root)
{
    struct {
        path_t src;
        path_t dst;
    } mounts[] = {
        { { "/rootfs", root  , "../../var" }, { "/rootfs", root, "var"  } },
        { { "/rootfs", "boot", NULL        }, { "/rootfs", root, "boot" } },
        { { "/rootfs", "home", NULL        }, { "/rootfs", root, "home" } },
        { { NULL, NULL, NULL }, { NULL, NULL, NULL } },
    }, *m;

    for (m = mounts; m->src.prefix || m->src.root || m->src.path; m++)
        if (bind_mount(&m->src, &m->dst) < 0)
            return -1;

    return 0;
}


static int shuffle_root(const char *root)
{
    struct {
        path_t src;
        path_t dst;
    } mounts[] = {
        { { "/rootfs"     , root, NULL }, { "/sysroot.tmp", NULL, NULL      } },
        { { "/rootfs"     , NULL, NULL }, { "/sysroot.tmp", "sysroot", NULL } },
        { { "/sysroot.tmp", NULL, NULL }, { "/rootfs"     , NULL, NULL      } },
        { { NULL, NULL, NULL }, { NULL, NULL, NULL } },
    }, *m;

    if (mkdir("/sysroot.tmp", 0755) < 0 && errno != EEXIST)
        return -1;

    for (m = mounts; m->src.prefix || m->src.root || m->src.path; m++)
        if (move_mount(&m->src, &m->dst) < 0)
            return -1;

    return 0;
}


static void initramfs_prepare(context_t *c)
{
    boot_entry_t *boot;

    if (get_boot_entries(c) < 0)
        log_fatal("failed to determine boot entries");

    if (c->latest < 0 || c->latest >= c->nentry)
        log_fatal("failed to discover latest boot entry");

    boot = c->entries + c->latest;

    if (make_movable("/rootfs", boot->deployment) < 0)
        log_fatal("failed to make '/rootfs/%s' movable (%d: %s)",
                  boot->deployment, errno, strerror(errno));

    if (prepare_root(boot->deployment) < 0)
        log_fatal("failed to prepare ostree root '%s' (%d: %s)",
                  boot->deployment, errno, strerror(errno));

    if (shuffle_root(boot->deployment) < 0)
        log_fatal("failed to shuffle ostree root '%s' (%d: %s)",
                  boot->deployment, errno, strerror(errno));
}


static void patch_procfs(context_t *c)
{
    boot_entry_t *boot;
    char          cmdline[4096], *p;
    const char   *orig, *patched;
    int           n, l, cnt, fd, nl;

    if (get_boot_entries(c) < 0)
        exit(1);

    if (c->running < 0)
        exit(1);

    boot = c->entries + c->running;

    if ((fd = open(orig = "/proc/cmdline", O_RDONLY)) < 0)
        exit(1);

    if ((n = read(fd, cmdline, sizeof(cmdline))) < 0)
        exit(1);

    close(fd);

    if (n >= (int)sizeof(cmdline) - 1)
        exit(1);

    nl = 0;
    while (n > 0 && cmdline[n - 1] == '\n') {
        n--;
        nl = 1;
    }

    cmdline[n] = '\0';

    if (strstr(cmdline, " ostree=") || strstr(cmdline, "ostree=") == cmdline)
        exit(0);

    l = sizeof(cmdline) - n - 1;

    p   = cmdline + n;
    cnt = snprintf(p, l, " ostree=%s%s", boot->boot, nl ? "\n" : "");

    if (cnt < 0 || cnt > l)
        exit(1);

    n += cnt;

    fd = open(patched = "/run/cmdline.patched",
              O_CREAT | O_TRUNC | O_WRONLY, 0644);

    if (fd < 0)
        exit(1);

    p = cmdline;
    l = n;
    while (l > 0) {
        n = write(fd, p, l);

        if (n < 0 && !(errno == EINTR || errno == EAGAIN))
            exit(1);

        p += n;
        l -= n;
    }

    close(fd);

    if (mount(patched, orig, NULL, MS_BIND|MS_RDONLY, NULL) < 0)
        exit(1);

    unlink(patched);
    exit(0);
}


int main(int argc, char *argv[])
{
    context_t c;

    setlocale(LC_ALL, "");

    parse_cmdline(&c, argc, argv);

    switch (c.mode) {
    case UPDATER_MODE_ENTRIES:
        print_entries(&c);
        break;

    case UPDATER_MODE_RUNNING:
        print_running(&c);
        break;

    case UPDATER_MODE_LATEST:
        print_latest(&c);
        break;

    case UPDATER_MODE_PATCH:
        patch_procfs(&c);
        break;

    case UPDATER_MODE_PREPARE:
        initramfs_prepare(&c);
        break;

#ifdef __REFKIT_UPDATER__
    case UPDATER_MODE_FETCH:
    case UPDATER_MODE_APPLY:
    case UPDATER_MODE_UPDATE:
        updater_init(&c, argv[0]);
        updater_loop(&c);
        updater_exit(&c);
        break;
#endif

    default:
        exit(-1);
    }

    return 0;
}

