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


int mainloop_needed(context_t *c)
{
    switch (c->action) {
    case ACTION_UPDATE:
        return c->poll_interval > 0;

    case ACTION_START:
    case ACTION_STOP:
        return TRUE;

    default:
        return FALSE;
    }
}


void mainloop_create(context_t *c)
{
    if (c->ml != NULL)
        return;

    c->ml = g_main_loop_new(NULL, FALSE);

    if (c->ml == NULL)
        log_fatal("failed to create mainloop");
}


void mainloop_destroy(context_t *c)
{
    g_main_loop_unref(c->ml);
    c->ml = NULL;
}


void mainloop_run(context_t *c)
{
    g_main_loop_run(c->ml);
}


void mainloop_quit(context_t *c, int exit_status)
{
    g_main_loop_quit(c->ml);

    if (!c->exit_code && exit_status)
        c->exit_code = exit_status;
}


unsigned int timer_add(context_t *c, int secs, int (*cb)(void *),
                       void *user_data)
{
    UNUSED_ARG(c);

    if (c->ml == NULL)
        mainloop_create(c);

    return g_timeout_add(1000 * secs, cb, user_data);
}


void timer_del(context_t *c, unsigned int id)
{
    UNUSED_ARG(c);

    if (id)
        g_source_remove(id);
}
