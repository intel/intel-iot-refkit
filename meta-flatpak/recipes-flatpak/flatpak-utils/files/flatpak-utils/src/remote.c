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
#include <string.h>
#include <pwd.h>
#include <sys/types.h>

#include "flatpak-session.h"


static int chkgecos(const char *gecos, const char *remote)
{
    const char *prefix = FPAK_GECOS_PREFIX;
    int         len    = sizeof(FPAK_GECOS_PREFIX) - 1;

    return !strncmp(gecos, prefix, len) && !strcmp(gecos + len, remote);
}


static uid_t search_passwd(const char *remote, char *buf, size_t size)
{
    struct passwd *pwd;

    setpwent();
    while ((pwd = getpwent()) != NULL) {
        if (chkgecos(pwd->pw_gecos, remote)) {
            if (buf != NULL) {
                strncpy(buf, pwd->pw_name, size - 1);
                buf[size - 1] = '\0';
            }

            return pwd->pw_uid;
        }
    }
    endpwent();

    return INVALID_UID;
}


uid_t remote_user_id(const char *remote, char *buf, size_t size)
{
    struct passwd *pwd;

    if (buf != NULL)
        *buf = '\0';

    if ((pwd = getpwnam(remote)) != NULL) {
        if (chkgecos(pwd->pw_gecos, remote)) {
            if (buf != NULL) {
                strncpy(buf, pwd->pw_name, size - 1);
                buf[size - 1] = '\0';
            }

            return pwd->pw_uid;
        }
    }

    return search_passwd(remote, buf, size);
}


char *remote_user_name(uid_t uid, char *buf, size_t size)
{
    static char    usr[64], *name;
    struct passwd *pwd;

    if (buf != NULL)
        *buf = '\0';
    else {
        buf  = usr;
        size = sizeof(usr);
    }

    if ((pwd = getpwuid(uid)) != NULL)
        name = pwd->pw_name;
    else
        name = "<unknown>";

    strncpy(buf, name, size - 1);
    buf[size - 1] = '\0';

    return buf;
}
