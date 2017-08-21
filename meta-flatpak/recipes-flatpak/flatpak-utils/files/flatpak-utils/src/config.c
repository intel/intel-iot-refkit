/*
 * Copyright (c) 2016, Intel Corporation
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
#include <string.h>
#include <errno.h>

#define _GNU_SOURCE
#include <getopt.h>

#include "flatpak-session.h"

static __attribute__((noreturn))
void print_usage(const char *argv0, int exit_code, const char *fmt, ...)
{
    va_list ap;

    if (fmt && *fmt) {
        va_start(ap, fmt);
        vfprintf(stderr, fmt, ap);
        fprintf(stderr, "\n");
        va_end(ap);
    }

    fprintf(stderr, "usage: %s [common-options] {command} [command-options]}\n"
            "\n"
            "The possible commands are:\n"
            "  generate: act as a systemd generator\n"
            "    Discover all repositories with an associated session user.\n"
            "    For all repositories found, generate and enable a systemd\n"
            "    service for starting up the session and populating it with\n"
            "    applications. %s will be used to start\n"
            "    the applications within the session. This is the default\n"
            "    behavior if the executable binary is %s.\n"
            "  start: start session applications\n"
            "    Start applications. Discover all applications originating\n"
            "    from the repository associated with the current user. Start\n"
            "    all applications which are not marked exempt from auto-\n"
            "    starting within the current session.\n"
            "  stop: stop a session (by sending SIGTERM)\n"
            "    Stop the session for the current or given user. Discover the\n"
            "    instance (%s) used to start the session\n"
            "    and send it SIGTERM. That instance is expected to stop all\n"
            "    applications running within its session, then exit itself.\n"
            "  list: list sessions\n"
            "    List all known sessions, all running sessions, or the session\n"
            "    session associated with the given user/repository.\n"
            "  signal: send a signal to a session\n"
            "    Same as stop but the signal can be specified.\n"
            "\n"
            "The possible common options are:\n"
            "  -u, --allow-unsigned      allow unverifiable (unsigned) remotes\n"
            "  -n, --dry-run             just print, don't generate anything\n"
            "  -v, --verbose             increase logging verbosity\n"
            "  -d, --debug               enable debug messages\n"
            "  -h, --help                print this help message\n"
            "\n"
            "The possible options for start are:\n"
            "  -r, --restart-status <n>  use n for forced restart exit status\n"
            "\n"
            "The possible options for update are:\n"
            "  -o, --one-shot            don't daemonize and poll updates\n"
            "  -i, --poll-interval ival  use the given interval for polling\n"
            "  -s, --start-signal <sig>  signal sessions after initial update\n",
            /* usage    */argv0,
            /* generate */FPAK_SESSION_PATH, FPAK_SYSTEMD_GENERATOR,
            /* stop     */FPAK_SESSION_PATH);

    exit(exit_code);
}


static inline int is_systemd_generator(const char *argv0)
{
    const char *p;

    if ((p = strrchr(argv0, '/')) == NULL)
        p = argv0;
    else
        p++;

    return !strcmp(p, FPAK_SYSTEMD_GENERATOR);
}


static void set_defaults(context_t *c, char **argv)
{
    memset(c, 0, sizeof(*c));
    c->sigfd      = -1;
    c->argv0      = argv[0];
    c->gpg_verify = 1;

    if (is_systemd_generator(argv[0]))
        c->action = ACTION_GENERATE;
    else
        c->action = ACTION_START;
}


static int parse_interval(const char *argv0, const char *val)
{
#   define SUFFIX(_e, _s, _l, _p)                                       \
       (!strcmp(_e, _s) || (_l && !strcmp(_e, _l)) || (_p && !strcmp(_e, _p)))
    char   *end;
    double  d;
    int     interval;


    d = strtod(val, &end);

    if (end != NULL && *end != '\0') {
        if (SUFFIX(end, "s", "sec", "secs"))
            interval = d < 30 ? 30 : (int)d;
        else if (SUFFIX(end, "m", "min", "mins"))
            interval = (int)(d * 60);
        else if (SUFFIX(end, "h", "hour", "hours"))
            interval = (int)(d * 60 * 60);
        else if (SUFFIX(end, "d", "day", "days"))
            interval = (int)(d * 24 * 60 * 60);
        else
            print_usage(argv0, EINVAL, "invalid poll interval '%s'", val);
    }
    else
        interval = (int)d;

    if (interval < FPAK_POLL_MIN_INTERVAL)
        interval = FPAK_POLL_MIN_INTERVAL;

    return interval;

#   undef SUFFIX
}


static void parse_common_options(context_t *c, int argc, char **argv)
{
#   define OPTIONS "-uvndh"
    static struct option options[] = {
        { "allow-unsigned", no_argument, NULL, 'u' },
        { "verbose"       , no_argument, NULL, 'v' },
        { "dry-run"       , no_argument, NULL, 'n' },
        { "debug"         , no_argument, NULL, 'd' },
        { "help"          , no_argument, NULL, 'h' },
        { NULL, 0, NULL, 0 }
    };

    int opt, m;

    while ((opt = getopt_long(argc, argv, OPTIONS, options, NULL)) != -1) {
        switch (opt) {
        case 'u':
            c->gpg_verify = 0;
            break;

        case 'n':
            c->dry_run = 1;
            break;

        case 'v':
            m = log_get_mask();
            m = (((m << 1) | 0x1) & ~FPAK_LOG_DEBUG) | (m & FPAK_LOG_DEBUG);
            log_set_mask(m);
            break;

        case 'd':
            log_set_mask(log_get_mask() | FPAK_LOG_DEBUG);
            break;

        case 'h':
            print_usage(argv[0], 0, "");

        case 1:
            optind--; /* we'll need to rescan it as a command argument */
            return;

        case '?':
            print_usage(argv[0], EINVAL, "invalid option");
            break;
        }
    }
#undef OPTIONS
}


static void parse_action(context_t *c, int argc, char **argv)
{
    static struct {
        const char *name;
        action_t    action;
    } actions[] = {
        { "generate", ACTION_GENERATE },
        { "update"  , ACTION_UPDATE   },
        { "start"   , ACTION_START    },
        { "stop"    , ACTION_STOP     },
        { "list"    , ACTION_LIST     },
        { "signal"  , ACTION_SIGNAL   },
        { NULL, 0 },
    }, *a;
    const char *action;

    if (c->action == ACTION_GENERATE)
        return;

    if (optind >= argc)
        return;

    action = argv[optind];

    if (action[0] == '-' || action[0] == '/')
        return;

    for (a = actions; a->name != NULL; a++) {
        if (!strcmp(action, a->name)) {
            c->action = a->action;
            optind++;
            return ;
        }
    }

    print_usage(argv[0], EINVAL, "unknown action '%s'", action);
}


static void parse_generate_options(context_t *c, int argc, char **argv)
{
    if (optind + 2 > argc - 1)
        print_usage(argv[0], EINVAL,
                    "missing systemd generator directory arguments");

    if (argv[optind  ][0] == '-' ||
        argv[optind+1][0] == '-' ||
        argv[optind+2][0] == '-') {
        print_usage(argv[0], EINVAL,
                    "can't mix options with systemd generator directories");
    }

    c->service_dir = argv[optind];
    optind += 3;

    if (optind <= argc - 1)
        print_usage(argv[0], EINVAL,
                    "unknown options starting at '%s'", argv[optind]);
}


static int parse_signal(const char *argv0, const char *sigstr)
{
#define NSIGNAL (sizeof(signals) / sizeof(signals[0]))
    struct signals {
        const char *sigstr;
        int         signo;
        int         reject : 1;
    } signals[] = {
#       define ACCEPT(_sig) [SIG##_sig] = { #_sig, SIG##_sig, 0 }
#       define REJECT(_sig) [SIG##_sig] = { #_sig, SIG##_sig, 1 }
        ACCEPT(HUP)   , ACCEPT(INT)   , ACCEPT(QUIT)  ,
        REJECT(ILL)   , REJECT(TRAP)  , REJECT(ABRT)  ,
        REJECT(BUS)   , REJECT(FPE)   , REJECT(KILL)  ,
        ACCEPT(USR1)  , REJECT(SEGV)  , ACCEPT(USR2)  ,
        ACCEPT(PIPE)  , ACCEPT(ALRM)  , ACCEPT(TERM)  ,
        REJECT(STKFLT), REJECT(CHLD)  , ACCEPT(CONT)  ,
        REJECT(STOP)  , ACCEPT(TSTP)  , ACCEPT(TTIN)  ,
        ACCEPT(TTOU)  , ACCEPT(URG)   , ACCEPT(XCPU)  ,
        ACCEPT(XFSZ)  , ACCEPT(VTALRM), ACCEPT(PROF)  ,
        ACCEPT(WINCH) , ACCEPT(IO)    , ACCEPT(PWR)   ,
        { NULL, -1, 0 }
#       undef ACCEPT
#       undef REJECT
    }, *s;

    const char *p = sigstr;
    char       *e;
    int         signo;

    if ('0' <= *p && *p <= '9') {
        signo = strtoul(p, &e, 10);

        if (e && *e != '\0')
            goto invalid_signal;
    }
    else {
        if (!strncmp(p, "SIG", 3))
            p += 3;

        for (signo = 0, s = signals + 1; !signo && s < signals + NSIGNAL; s++) {
            if (!strcmp(p, s->sigstr))
                signo = s->signo;
        }
    }

    if (signo < 0 || signo >= (int)NSIGNAL)
        goto invalid_signal;

    s = signals + signo;

    if (s->reject)
        goto reject_signal;

    return signo;

 invalid_signal:
    print_usage(argv0, EINVAL, "invalid signal '%s'", sigstr);
    return -1;

 reject_signal:
    print_usage(argv0, EINVAL, "unusable signal '%s'", sigstr);
    return -1;

#undef NSIGNAL
}


static void parse_start_options(context_t *c, int argc, char **argv)
{
#   define OPTIONS "w:r:"
    static struct option options[] = {
        { "restart-status", required_argument, NULL, 'r' },
        { NULL, 0, NULL, 0 },
    };

    int   opt;
    char *e;

    c->remote_uid     = geteuid();
    c->forced_restart = 69;

    if (c->remote_uid == 0)
        print_usage(argv[0], EINVAL, "cannot start session as root");

    if (optind >= argc)
        return;

    while ((opt = getopt_long(argc, argv, OPTIONS, options, NULL)) != -1) {
        switch (opt) {
        case 'r':
            c->forced_restart = strtol(optarg, &e, 10);

            if (e && *e) {
                print_usage(argv[0], EINVAL, "invalid restart status '%s'",
                            optarg);
            }
            break;

        case '?':
            print_usage(argv[0], EINVAL, "invalid start option");
            break;
        }
    }

#   undef OPTIONS
}


static uid_t parse_remote(const char *argv0, const char *remote)
{
    uid_t uid;

    uid = remote_user_id(remote, NULL, 0);

    if (uid == INVALID_UID)
        print_usage(argv0, EINVAL,
                    "failed to resolve user for remote '%s'", remote);
    else
        return uid;
}


static void parse_stop_options(context_t *c, int argc, char **argv)
{
#   define OPTIONS "r:s:"
    static struct option options[] = {
        { "remote", required_argument, NULL, 'r' },
        { "signal", required_argument, NULL, 's' },
        { NULL, 0, NULL, 0 },
    };

    int opt;

    c->remote_uid = geteuid();

    if (optind >= argc)
        return;

    while ((opt = getopt_long(argc, argv, OPTIONS, options, NULL)) != -1) {
        switch (opt) {
        case 'r':
            c->remote_uid = parse_remote(c->argv0, optarg);
            break;

        case 's':
            c->signal = parse_signal(c->argv0, optarg);
            break;

        case '?':
            print_usage(argv[0], EINVAL, "invalid 'stop' option '%c'", opt);
            break;
        }
    }
#   undef OPTIONS
}


static void parse_list_options(context_t *c, int argc, char **argv)
{
    const char *remote;

    if (optind > argc - 1)
        c->remote_uid = geteuid();
    else if (optind == argc - 1) {
        remote = optarg;

        if (!strcmp(remote, "all") || !strcmp(remote, "."))
            c->remote_uid = 0;
        else
            c->remote_uid = parse_remote(c->argv0, remote);
    }
    else
        print_usage(argv[0], EINVAL, "too many arguments for 'list'");
}


static void parse_signal_options(context_t *c, int argc, char **argv)
{
#   define OPTIONS "r:s:"
    static struct option options[] = {
        { "remote", required_argument, NULL, 'r' },
        { "signal", required_argument, NULL, 's' },
        { NULL, 0, NULL, 0 },
    };

    int opt;

    c->remote_uid = geteuid();
    c->signal     = SIGTERM;

    if (optind >= argc)
        return;

    while ((opt = getopt_long(argc, argv, OPTIONS, options, NULL)) != -1) {
        switch (opt) {
        case 'r':
            c->remote_uid = parse_remote(c->argv0, optarg);
            break;

        case 's':
            c->signal = parse_signal(c->argv0, optarg);
            break;

        case '?':
            print_usage(argv[0], EINVAL, "invalid 'signal' option '%c'", opt);
            break;
        }
    }
#   undef OPTIONS
}


static void parse_update_options(context_t *c, int argc, char **argv)
{
#   define OPTIONS "oi:"
    static struct option options[] = {
        { "one-shot"     , no_argument      , NULL, 'o' },
        { "poll-interval", required_argument, NULL, 'i' },
        { NULL, 0, NULL, 0 },
    };

    int opt;

    if (c->poll_interval <= 0)
        c->poll_interval = FPAK_POLL_MIN_INTERVAL;

    if (optind >= argc)
        return;

    while ((opt = getopt_long(argc, argv, OPTIONS, options, NULL)) != -1) {
        switch (opt) {
        case 'o':
            c->poll_interval = -1;
            break;

        case 'i':
            c->poll_interval = parse_interval(c->argv0, optarg);
            break;

        case '?':
            print_usage(argv[0], EINVAL, "invalid 'update' option");
            break;
        }
    }
#   undef OPTIONS
}


void config_parse_cmdline(context_t *c, int argc, char **argv)
{
    set_defaults(c, argv);
    log_open(c);

    parse_common_options(c, argc, argv);
    parse_action(c, argc, argv);

    switch (c->action) {
    case ACTION_GENERATE: parse_generate_options(c, argc, argv); break;
    case ACTION_UPDATE:   parse_update_options(c, argc, argv);   break;
    case ACTION_START:    parse_start_options(c, argc, argv);    break;
    case ACTION_STOP:     parse_stop_options(c, argc, argv);     break;
    case ACTION_SIGNAL:   parse_signal_options(c, argc, argv);   break;
    case ACTION_LIST:     parse_list_options(c, argc, argv);     break;
    default:
        break;
    }

    log_open(c);
}

