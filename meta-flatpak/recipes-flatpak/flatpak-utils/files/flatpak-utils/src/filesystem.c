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
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <stdarg.h>
#include <fcntl.h>
#include <limits.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/wait.h>

#include "flatpak-session.h"


int fsys_prepare_session(context_t *c)
{
    char *dir = fsys_mkpath(NULL, 0, "%s/%s.wants",
                            c->service_dir, FPAK_SYSTEMD_TARGET);

    log_info("creating service directory %s...", dir);

    if (c->dry_run)
        return 0;
    else
        return fsys_mkdirp(0755, dir);
}


char *fsys_mkpath(char *path, size_t size, const char *fmt, ...)
{
    static char buf[PATH_MAX];
    va_list     ap;
    int         n;

    if (path == NULL) {
        path = buf;
        size = sizeof(buf);
    }
    else if (size > PATH_MAX)
        size = PATH_MAX;

    va_start(ap, fmt);
    n = vsnprintf(path, size, fmt, ap);
    va_end(ap);

    if (n < 0 || n >= (int)size)
        goto nametoolong;

    return path;

 nametoolong:
    errno = ENAMETOOLONG;
    return NULL;
}


int fsys_mkdir(const char *path, mode_t mode)
{
    const char *p;
    char       *q, buf[PATH_MAX];
    int         n, undo[PATH_MAX / 2];
    struct stat st;

    if (path == NULL || path[0] == '\0') {
        errno = path ? EINVAL : EFAULT;
        return -1;
    }

    log_debug("checking/creating '%s'...", path);

    p = path;
    q = buf;
    n = 0;
    while (1) {
        if (q - buf >= (ptrdiff_t)sizeof(buf) - 1) {
            errno = ENAMETOOLONG;
            goto cleanup;
        }

        if (*p && *p != '/') {
            *q++ = *p++;
            continue;
        }

        *q = '\0';

        if (q != buf) {
            log_debug("checking/creating '%s'...", buf);

            if (stat(buf, &st) < 0) {
                if (errno != ENOENT)
                    goto cleanup;

                if (mkdir(buf, mode) < 0)
                    goto cleanup;

                undo[n++] = q - buf;
            }
            else {
                if (!S_ISDIR(st.st_mode)) {
                    errno = ENOTDIR;
                    goto cleanup;
                }
            }
        }

        while (*p == '/')
            p++;

        if (!*p)
            break;

        *q++ = '/';
    }

    return 0;

 cleanup:
    while (--n >= 0) {
        buf[undo[n]] = '\0';
        log_debug("cleaning up '%s'...", buf);
        rmdir(buf);
    }

    return -1;
}


int fsys_mkdirp(mode_t mode, const char *fmt, ...)
{
    va_list ap;
    char path[PATH_MAX];
    int n;

    va_start(ap, fmt);
    n = vsnprintf(path, sizeof(path), fmt, ap);
    va_end(ap);

    if (n < 0 || n >= (int)sizeof(path))
        goto nametoolong;

    return fsys_mkdir(path, mode);

 nametoolong:
    errno = ENAMETOOLONG;
    return -1;
}


int fsys_symlink(const char *path, const char *dst)
{
    struct stat stp, std;

    if (lstat(path, &stp) < 0)
        return -1;

    if (!S_ISLNK(stp.st_mode))
        return 0;

    if (dst == NULL)
        return 1;

    if (stat(path, &std) < 0)
        return 0;

    if (stat(path, &stp) < 0)
        return -1;

    if (stp.st_dev == std.st_dev && stp.st_ino == std.st_ino)
        return 1;
    else
        return 0;
}


char *fsys_service_path(context_t *c, const char *usr, char *path, size_t size)
{
    const char *srvdir  = SYSTEMD_SERVICEDIR;
    const char *session = FPAK_SYSTEMD_SESSION;

    UNUSED_ARG(c);
    UNUSED_ARG(usr);

    return fsys_mkpath(path, size, "%s/%s", srvdir, session);
}


char *fsys_service_link(context_t *c, const char *usr, char *path, size_t size)
{
    const char *session = FPAK_SYSTEMD_SESSION, *s;
    char       *d;
    int         l, n;

    d = path;
    l = (int)size;

    n = snprintf(d, l, "%s/%s.wants/", c->service_dir, FPAK_SYSTEMD_TARGET);

    if (n < 0)
        return NULL;
    if (n >= l)
        goto overflow;

    d += n;
    l -= n;

    s = strchr(session, '@');

    if (s != NULL) {
        n = snprintf(d, l, "%.*s", (int)(s - session + 1), session);

        if (n < 0)
            return NULL;
        if (n >= l)
            goto overflow;

        d += n;
        l -= n;
        s++;

        n = snprintf(d, l, "%s", usr);

        if (n < 0)
            return NULL;
        if (n >= l)
            goto overflow;

        d += n;
        l -= n;
    }

    n = snprintf(d, l, "%s", s);

    if (n < 0)
        return NULL;
    if (n >= l)
        goto overflow;

    return path;

 overflow:
    errno = EOVERFLOW;
    return NULL;
}


int fs_scan_proc(const char *exe, uid_t uid,
                 int (*cb)(pid_t pid, void *user_data), void *user_data)
{
    DIR           *dp;
    struct dirent *de;
    struct stat    st;
    char           file[PATH_MAX + 1], *bin;
    int            n, status;

    if ((dp = opendir("/proc")) == NULL)
        return -1;

    while ((de = readdir(dp)) != NULL) {
        if (!('0' <= de->d_name[0] && de->d_name[0] <= '9'))
            continue;

        snprintf(file, sizeof(file), "/proc/%s/exe", de->d_name);

        if (lstat(file, &st) != 0)
            continue;

        if (uid != (uid_t)-1 && st.st_uid != uid)
            continue;

        if ((n = readlink(file, file, sizeof(file) - 1)) < 0)
            continue;

        file[n] = '\0';

        if (exe[0] == '/') {
            bin = file;
        }
        else {
            if ((bin = strrchr(file, '/')) != NULL)
                bin++;
            else
                bin = file;
        }

        if (!strcmp(exe, bin)) {
            status = cb((pid_t)strtoul(de->d_name, NULL, 10), user_data);

            if (status == 0)
                break;

            if (status < 0)
                goto fail;
        }
    }

    closedir(dp);

    return 0;

 fail:
    closedir(dp);

    return -1;
}
