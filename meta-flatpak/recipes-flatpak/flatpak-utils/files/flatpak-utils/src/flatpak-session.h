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

#ifndef __FLATPAK_SESSION_H__
#define __FLATPAK_SESSION_H__

#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <flatpak/flatpak.h>

#include "config.h"

/* default system path definitions */
#ifndef SYSCONFDIR
#    define SYSCONFDIR "/etc"
#endif

#ifndef LIBDIR
#    define LIBDIR "/usr/lib"
#endif

#ifndef LIBEXECDIR
#    define LIBEXECDIR "/usr/libexec"
#endif

#ifndef SYSTEMD_SERVICEDIR
#    define SYSTEMD_SERVICEDIR LIBDIR"/systemd/system"
#endif

/* default repo URL and key dir */
#ifndef FPAK_REPOS_DIR
#    define FPAK_REPOS_DIR SYSCONFDIR"/flatpak-session"
#endif

/* default systemd service, target, and generator */
#ifndef FPAK_SYSTEMD_SESSION
#    define FPAK_SYSTEMD_SESSION "flatpak-session@.service"
#endif

#ifndef FPAK_SYSTEMD_TARGET
#    define FPAK_SYSTEMD_TARGET "flatpak-sessions.target"
#endif

#ifndef FPAK_SYSTEMD_GENERATOR
#    define FPAK_SYSTEMD_GENERATOR "flatpak-session-enable"
#endif

/* flatpak session binary path */
#ifndef FPAK_SESSION_PATH
#    define FPAK_SESSION_PATH "/usr/bin/flatpak-session"
#endif

/* default path to systemd user slice top directory */
#ifndef SYSTEMD_USER_SLICE
#    define SYSTEMD_USER_SLICE "/sys/fs/cgroup/systemd/user.slice"
#endif

/* root directory used by flatpak in application-specific namespaces */
#ifndef FLATPAK_APP_ROOT
#    define FLATPAK_APP_ROOT "/newroot/app"
#endif

/* gecos prefix we look for to identify remote-specific users */
#ifndef FPAK_GECOS_PREFIX
#    define FPAK_GECOS_PREFIX "flatpak user for "
#endif

/* section and key names for our extra flatpak metadata */
#define FPAK_SECTION_REFKIT "Application"  /* reuse existing section */
#define FPAK_KEY_INSTALL    "X-Install"    /* autoinstall application */
#define FPAK_KEY_START      "X-Start"      /* autostart application */
#define FPAK_KEY_URGENCY    "X-Urgency"    /* update urgency */

/* timers, intervals */
#define FPAK_UPDATE_LOWPASS_TIMER 15       /* update monitor lowpass filter */
#define FPAK_POLL_MIN_INTERVAL    15       /* minimum polling interval */

/* forward declaration of types */
typedef struct context_s     context_t;
typedef struct remote_s      remote_t;
typedef struct application_s application_t;

/* actions (modes of operation) */
typedef enum {
    ACTION_UNKNOWN = -1,
    ACTION_GENERATE,                 /* generate systemd services for remotes */
    ACTION_UPDATE,                   /* update flatpaks managed by us */
    ACTION_START,                    /* start flatpaks for/in a session */
    ACTION_STOP,                     /* stop flatpaks for/in a session */
    ACTION_SIGNAL,                   /* signal flatpaks in a session */
    ACTION_LIST,                     /* list flatpaks */
} action_t;

struct context_s {
    FlatpakInstallation *f;          /* flatpak (system) context */
    remote_t            *remotes;    /* remotes of interest */
    int                  nremote;    /* number of remotes */
    application_t       *apps;       /* flatpaks (applications) of interest */
    int                  napp;       /* number of flatpaks */
    GMainLoop           *ml;         /* main loop, if we need one */
    GFileMonitor        *lm;         /* flatpak monitor for local changes */
    int                  lmcn;       /*     monitor gobject connection */
    unsigned int         lmlpt;      /*     monitor lowpass filter timer */
    unsigned int         rpt;        /* remote polling timer */
    sigset_t             signals;    /* signals we catch */
    int                  sigfd;      /* signalfd */
    GIOChannel          *sigio;      /* I/O channel for sigfd */
    guint                sigw;       /* watch source id for sigio */
    int                  exit_code;  /* status to exit with */

    struct {                         /* various notification callbacks */
        void (*r_up)(context_t *c);  /*   remote updates available */
        void (*l_up)(context_t *c);  /*   local updates available */
    } notify;

    /* configuration/command line */
    const char *argv0;               /* our binary */
    action_t    action;              /* action/mode we're running in */
    const char *service_dir;         /* systemd generator output directory */
    int         forced_restart;      /* exit status for forced restart */
    uid_t       remote_uid;          /* remote to stop/signal session for */
    int         poll_interval;       /* remote monitor polling interval */
    int         signal;              /* signal to send */
    int         dry_run    : 1;      /* just show actions, don't execute them */
    int         gpg_verify : 1;      /* ignore unverifiable remotes */
};

/* a remote repository (associated with a session/user and applications) */
struct remote_s {
    char  *name;                     /* flatpak remote name */
    char  *url;                      /* remote repository URL */
    char  *user;                     /* associated user to run session */
    uid_t  uid;                      /* and its user id */
};

/* a flatpak (application) */
struct application_s {
    char *origin;                    /* remote repository of origin */
    char *name;                      /* flatpak application name */
    char *head;                      /* current latest commit */
    int   install : 1;               /* automatically install */
    int   start   : 1;               /* automatically start within session */
    int   urgent  : 1;               /* urgent update */
    int   pending : 1;               /* pending remote updates */
    int   updated : 1;               /* locally updated */
};


/*
 * miscallaneous macros
 */
#define INVALID_UID      ((uid_t)-1)
#define UNUSED_ARG(_arg) (void)(_arg)

/*
 * declarations, function prototypes
 */

/* config.c */
void config_parse_cmdline(context_t *c, int argc, char **argv);

/* mainloop.c */
int mainloop_needed(context_t *c);
void mainloop_create(context_t *c);
void mainloop_destroy(context_t *c);
void mainloop_run(context_t *c);
void mainloop_quit(context_t *c, int exit_status);
unsigned int mainloop_add_timer(context_t *c, int secs, int (*cb)(void *),
                                void *user_data);
void mainloop_del_timer(context_t *c, unsigned int id);
unsigned int timer_add(context_t *c, int secs, int (*cb)(void *),
                       void *user_data);
void timer_del(context_t *c, unsigned int id);

/* remote.c */
uid_t remote_user_id(const char *remote, char *usrbuf, size_t size);
char *remote_user_name(uid_t uid, char *usrbuf, size_t size);

/* filesystem.c */
int fsys_prepare_session(context_t *c);
char *fsys_mkpath(char *path, size_t size, const char *fmt, ...);
int fsys_mkdir(const char *path, mode_t mode);
int fsys_mkdirp(mode_t mode, const char *fmt, ...);
int fsys_symlink(const char *path, const char *dst);
char *fsys_service_path(context_t *c, const char *usr, char *path, size_t size);
char *fsys_service_link(context_t *c, const char *usr, char *path, size_t size);
int fs_scan_proc(const char *exe, uid_t uid,
                 int (*cb)(pid_t pid, void *user_data), void *user_data);

/* flatpak.c */
typedef enum {
    FPAK_DISCOVER_REMOTES = 0x1,
    FPAK_DISCOVER_APPS    = 0x2,
} fpak_flag_t;

int fpak_init(context_t *c, int flags);
int fpak_install_remotes(context_t *c, const char *dir);
int fpak_create_remote(context_t *c, const char *name, const char *url,
                       const char *key, int keylen);
int fpak_discover_remotes(context_t *c);
int fpak_discover_apps(context_t *c);
int fpak_start_app(context_t *c, application_t *a);
int fpak_start_session(context_t *c);
char *fpak_app_systemd_scope(uid_t uid, pid_t session, const char *app,
                             char *scope, size_t size);
int fpak_poll_updates(context_t *c);
int fpak_update_apps(context_t *c);
int fpak_reload_apps(context_t *c);
int fpak_reload_session(context_t *c);
remote_t *fpak_lookup_remote(context_t *c, const char *name);
remote_t *fpak_remote_for_uid(context_t *c, uid_t uid);
application_t *fpak_lookup_app(context_t *c, const char *name);
int fpak_track_remote_updates(context_t *c, void (*cb)(context_t *));
int fpak_track_local_updates(context_t *c, void (*cb)(context_t *));

#define fpak_foreach_remote(_c, _r) \
    for (_r = _c->remotes; _r && _r->name; _r++)

#define fpak_foreach_app(_c, _a) \
    for (_a = _c->apps; _a && _a->name; _a++)

/* log.c */
typedef enum {
    FPAK_LOG_NONE    = 0x00,
    FPAK_LOG_FATAL   = 0x01,
    FPAK_LOG_ERROR   = 0x02,
    FPAK_LOG_WARNING = 0x04,
    FPAK_LOG_INFO    = 0x08,
    FPAK_LOG_DEBUG   = 0x10,
    FPAK_LOG_ALL     = 0x1f,
} fpak_log_level_t;

int  log_set_mask(int mask);
int  log_get_mask(void);
void log_open(context_t *c);
void log_close(void);
void log_msg(int lvl, const char *function, const char *file, int line,
             const char *fmt, ...);

#define __LOC__ __FUNCTION__, __FILE__, __LINE__

#define log_fatal(_fmt, _args...) log_msg(FPAK_LOG_FATAL  , __LOC__,    \
                                          _fmt, ## _args), exit(1)
#define log_error(_fmt, _args...) log_msg(FPAK_LOG_ERROR  , __LOC__,    \
                                          _fmt, ## _args)
#define log_warn(_fmt, _args...)  log_msg(FPAK_LOG_WARNING, __LOC__,    \
                                          _fmt, ## _args)
#define log_info(_fmt, _args...)  log_msg(FPAK_LOG_INFO   , __LOC__,    \
                                          _fmt, ## _args)
#define log_debug(_fmt, _args...) log_msg(FPAK_LOG_DEBUG  , __LOC__,    \
                                          _fmt, ## _args)

#endif /* __FLATPAK_SESSION_H__ */
