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
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>


#include "generator.h"

int template_load(generator_t *g)
{
    const char  *path = g->path_template;
    struct stat  st;
    char        *buf, *p;
    int          fd, n, l;

    if (stat(path, &st) < 0)
        goto ioerror;

    if (st.st_size > 16 * 1024)
        goto overflow;

    fd = open(path, O_RDONLY);

    if (fd < 0)
        goto ioerror;

    buf = calloc(st.st_size + 1, 1);
    p   = buf;
    l   = st.st_size;

    while (l > 0) {
        n = read(fd, p, l);

        if (n < 0) {
            if (errno == EAGAIN || errno == EINTR)
                continue;
            else
                goto ioerror;
        }

        p += n;
        l -= n;
    }

    close(fd);
    *p = '\0';

    g->template = buf;

    return 0;

 ioerror:
    log_error("failed to load template file '%s' (%d: %s)", path,
              errno, strerror(errno));
    return -1;

 overflow:
    log_error("template file '%s' too large", path);
    return -1;

}


static int print_tag(int fd, const char *tag, int len, const char *usr,
                     const char *remote)
{
    if (!strncmp(tag, "USER", len))
        dprintf(fd, "%s", usr);
    else if (!strncmp(tag, "REMOTE", len))
        dprintf(fd, "%s", remote);
    else
        dprintf(fd, "<value of tag '%*.*s'>", len, len, tag);

    return 0;
}


int template_eval(generator_t *g, const char *usr, const char *remote,
                  const char *out)
{
    const char *p, *b, *e, *nl, *tag;
    int         fd, len;

    fd = open(out, O_WRONLY|O_CREAT, 0644);

    if (fd < 0)
        goto ioerror;

    p = g->template;
    while (p && *p) {
        b = strchr(p, '@');

        if (b != NULL) {
            e  = strchr(b + 1, '@');
            nl = strchr(b + 1, '\n');

            if (e != NULL && (nl == NULL || e < nl)) {
                dprintf(fd, "%*.*s", (int)(b - p), (int)(b - p), p);

                tag = b + 1;
                len = e - b - 1;

                print_tag(fd, tag, len, usr, remote);

                p = e + 1;
            }
            else {
                if (e == NULL && nl == NULL) {
                    dprintf(fd, "%s", p);
                    p = NULL;
                }
                else if (e != NULL) {
                    dprintf(fd, "%*.*s", (int)(e - p - 1), (int)(e - p - 1), p);
                    p = e - 1;
                }
                else {
                    dprintf(fd, "%s", p);
                    p = NULL;
                }
            }
        }
        else {
            dprintf(fd, "%s", p);
            p = NULL;
        }
    }

    close(fd);

    return 0;

 ioerror:
    log_error("failed to open output file '%s' (%d: %s)", out,
              errno, strerror(errno));

    return -1;
}
