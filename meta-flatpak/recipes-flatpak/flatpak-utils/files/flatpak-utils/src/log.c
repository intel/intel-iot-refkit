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
#include <syslog.h>
#include <fcntl.h>
#include <stdarg.h>
#include <sys/types.h>
#include <sys/stat.h>


#include "flatpak-session.h"

static int log_fd   = -1;
static int log_mask = FPAK_LOG_FATAL | FPAK_LOG_ERROR;


int log_set_mask(int mask)
{
    int old_mask = log_mask;

    log_mask = mask;

    return old_mask;
}


int log_get_mask(void)
{
    return log_mask;
}


void log_open(context_t *c)
{
    log_close();

    if (c->dry_run || c->action != ACTION_GENERATE)
        log_fd = 1;
    else
        log_fd = open("/dev/kmsg", O_WRONLY);

    if (log_fd < 0)
        log_fd = 1;
}


void log_close(void)
{
    if (log_fd > 1)
        close(log_fd);

    log_fd = -1;
}


void log_msg(int lvl, const char *fn, const char *file, int line,
             const char *format, ...)
{
    char    *hdrstr, hdrbuf[256];
    int      hdrlen;
    va_list  ap;

    UNUSED_ARG(fn);
    UNUSED_ARG(file);
    UNUSED_ARG(line);

    if (!(log_mask & lvl))
        return;

    switch (lvl) {
    case FPAK_LOG_FATAL:   hdrstr = "F: "; hdrlen = 3; break;
    case FPAK_LOG_ERROR:   hdrstr = "E: "; hdrlen = 3; break;
    case FPAK_LOG_WARNING: hdrstr = "W: "; hdrlen = 3; break;
    case FPAK_LOG_INFO:    hdrstr = "I: "; hdrlen = 3; break;
    default:               hdrstr = "?: "; hdrlen = 3; break;
    case FPAK_LOG_DEBUG:
        hdrlen = snprintf(hdrstr = hdrbuf, sizeof(hdrbuf), "D: [%s] ", fn);
        break;
    }

    write(log_fd, hdrstr, hdrlen);
    va_start(ap, format);
    vdprintf(log_fd, format, ap);
    va_end(ap);
    write(log_fd, "\n", 1);
}
