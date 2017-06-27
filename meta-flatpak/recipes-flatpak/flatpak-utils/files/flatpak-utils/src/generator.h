/*
 * Copyright (c) 2015, Intel Corporation
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

#ifndef __FSG_GENERATOR_H__
#define __FSG_GENERATOR_H__

#include <stdio.h>
#include <sys/types.h>

#include <flatpak/flatpak.h>

#include "config.h"

#ifndef SYSCONFDIR
#    define SYSCONFDIR "/etc"
#endif

#ifndef LIBDIR
#    define LIBDIR "/usr/lib"
#endif

#ifndef LIBEXECDIR
#    define LIBEXECDIR "/usr/libexec"
#endif

#ifndef SYSTEM_SERVICEDIR
#    define SYSTEM_SERVICEDIR "/usr/lib/systemd/system"
#endif

#define PATH_TEMPLATE LIBEXECDIR"/flatpak-utils/flatpak-session.template"

#define UNUSED_ARG(name) (void)name

typedef struct {
    FlatpakInstallation *f;
    GPtrArray           *remotes;
    char                *template;
    const char          *argv0;
    int                  dry_run : 1;
    const char          *dir_normal;
    const char          *dir_early;
    const char          *dir_late;
    const char          *dir_service;
    const char          *path_template;
} generator_t;


/* config.c */
void config_parse_cmdline(generator_t *g, int argc, char **argv);

/* filesystem.c */
char *fs_mkpath(char *path, size_t size, const char *fmt, ...);
int fs_mkdir(const char *path, mode_t mode);
int fs_mkdirp(mode_t mode, const char *fmt, ...);
int fs_symlink(const char *path, const char *dst);
char *fs_service_path(generator_t *g, const char *usr, char *path, size_t size);
char *fs_service_link(generator_t *g, const char *usr, char *path, size_t size);
int fs_prepare_directories(generator_t *g);

/* flatpak.c */
int fp_discover_remotes(generator_t *g);
uid_t fp_resolve_user(FlatpakRemote *r, char *usrbuf, size_t size);

/* service.c */
int service_generate_sessions(generator_t *g);

/* template.c */
int template_load(generator_t *g);
int template_eval(generator_t *g, const char *usr, const char *remote,
                  const char *out);

/* log.c */
#define log(fmt, args...) do {                          \
        dprintf(log_fd, fmt"\n" , ## args);             \
    } while (0)

#define log_info(fmt, args...)    log("I: "fmt, ## args)
#define log_warning(fmt, args...) log("W: "fmt, ## args)
#define log_error(fmt, args...)   log("E: "fmt, ## args)
#define log_debug(fmt, args...)   log("D: "fmt, ## args)

extern int log_fd;
extern int log_mask;

void log_open(generator_t *g);


#endif /* __FSG_GENERATOR_H__ */
