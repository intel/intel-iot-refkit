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

#include <stdlib.h>

#include "flatpak-session.h"


static int generate_session(context_t *c, remote_t *r)
{
    char srv[PATH_MAX], lnk[PATH_MAX];

    if (!fsys_service_path(c, r->user, srv, sizeof(srv)) ||
        !fsys_service_link(c, r->user, lnk, sizeof(lnk)))
        return -1;

    log_info("remote %s: generating session (user %s)", r->name, r->user);

    if (c->dry_run) {
        log_info("symlinking %s -> %s", lnk, srv);
        return 0;
    }

    unlink(lnk);

    if (symlink(srv, lnk) < 0)
        return -1;

    return 0;
}


static void action_generate(context_t *c)
{
    remote_t *r;

    if (fpak_init(c, FPAK_DISCOVER_REMOTES) < 0)
        log_fatal("failed to initialize flatpak library");

    if (fsys_prepare_session(c) < 0)
        log_fatal("failed to prepare filesystem for session generation");

    fpak_foreach_remote(c, r) {
        if (generate_session(c, r) < 0)
            log_error("remote %s: failed to generate session", r->name);
    }
}


static void remote_pending_cb(context_t *c)
{
    if (fpak_update_apps(c) < 0)
        log_error("failed to update applications");
}


static void action_update(context_t *c)
{
    if (fpak_init(c, FPAK_DISCOVER_APPS) < 0)
        log_fatal("failed to initialize flatpak library");

    if (fpak_poll_updates(c))
        if (fpak_update_apps(c) < 0)
            log_error("failed to update applications");

    if (c->poll_interval > 0)
        if (fpak_track_remote_updates(c, remote_pending_cb) < 0)
            log_fatal("failed to track remote updates");
}


static void local_updates_cb(context_t *c)
{
    if (fpak_reload_apps(c) < 0)
        log_error("failed to reload local updates");
    if (fpak_reload_session(c) < 0)
        log_error("failed to reload session for %d", c->remote_uid);
}


static void action_start(context_t *c)
{
    if (fpak_init(c, FPAK_DISCOVER_APPS) < 0)
        log_fatal("failed to initialize flatpak library");

    if (fpak_start_session(c) < 0)
        log_fatal("failed to start session for user %d", c->remote_uid);

    if (fpak_track_local_updates(c, local_updates_cb) < 0)
        log_error("failed to track local updates");
}


int main(int argc, char *argv[])
{
    context_t ctx, *c = &ctx;

    config_parse_cmdline(c, argc, argv);

    if (mainloop_needed(c))
        mainloop_create(c);

    switch (c->action) {
    case ACTION_GENERATE: action_generate(c); break;
    case ACTION_UPDATE:   action_update(c);   break;
    case ACTION_START:    action_start(c);    break;
    default:
        log_error("internal error: unknown action (%d)", c->action);
        exit(1);
    }

#if 0
    switch (c->action) {
    case ACTION_STOP:     stop_session(c);        break;
    case ACTION_LIST:     list_session(c);        break;
    case ACTION_SIGNAL:   signal_session(c);      break;
    default:
        log_error("internal error: unknown action (%d)", c->action);
        exit(1);
    }
#endif

    if (c->ml != NULL)
        mainloop_run(c);

    exit(c->exit_code);
}
