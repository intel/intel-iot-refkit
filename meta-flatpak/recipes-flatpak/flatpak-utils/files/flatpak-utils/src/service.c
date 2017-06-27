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

#include "generator.h"


static int service_generate(generator_t *g, FlatpakRemote *r, const char *usr)
{
    char  srv[PATH_MAX], lnk[PATH_MAX];
    const char *remote = flatpak_remote_get_name(r);

    log_info("generating session service for user %s (remote %s)...",
             usr, remote);

    if (!fs_service_path(g, usr, srv, sizeof(srv)) ||
        !fs_service_link(g, usr, lnk, sizeof(lnk)))
        goto fail;

    if (template_eval(g, usr, remote, srv) < 0)
        goto template_fail;

    if (symlink(srv, lnk) < 0)
        goto fail;

    return 0;

 template_fail:
    log_error("service template evaluation failed for usr %s (remote %s)",
              usr, remote);

 fail:
    return -1;
}


int service_generate_sessions(generator_t *g)
{
    FlatpakRemote *r;
    unsigned int   i;
    char           usr[256];

    for (i = 0; i < g->remotes->len; i++) {
        r = g_ptr_array_index(g->remotes, i);

        log_warning("process remote %s...", flatpak_remote_get_name(r));

        if (fp_resolve_user(r, usr, sizeof(usr)) == (uid_t)-1) {
            log_warning("remote %s has no associated user, ignoring...",
                        flatpak_remote_get_name(r));
            continue;
        }

        if (service_generate(g, r, usr) < 0)
            log_error("failed to generate session for remote '%s'",
                      flatpak_remote_get_name(r));
    }

    return 0;
}

