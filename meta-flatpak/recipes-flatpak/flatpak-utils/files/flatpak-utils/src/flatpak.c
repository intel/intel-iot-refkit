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

#include <string.h>
#include <errno.h>
#include <ctype.h>
#include <dirent.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>

#include "flatpak-session.h"


static GKeyFile *meta_load(FlatpakInstalledRef *ref);
static GKeyFile *meta_fetch(context_t *c, FlatpakRemoteRef *rref);
static void meta_free(GKeyFile *m);
static const char *meta_get(GKeyFile *m, const char *sec, const char *key,
                            const char *def);
#define meta_str meta_get
static int meta_int(GKeyFile *m, const char *sec, const char *key, int def);
static int meta_bool(GKeyFile *m, const char *sec, const char *key, int def);


int fpak_create_remote(context_t *c, const char *name, const char *url,
                       const char *key, int keylen)
{
    FlatpakRemote *r;
    GError        *e;
    GBytes        *key_bytes;

    e = NULL;
    r = flatpak_installation_get_remote_by_name(c->f, name, NULL, &e);

    if (r != NULL)
        goto out;

    g_error_free(e);
    e = NULL;

    log_info("flatpak: creating remote '%s' (%s)", name, url);

    r = flatpak_remote_new(name);

    if (r == NULL)
        return -1;

    flatpak_remote_set_url(r, url);
    flatpak_remote_set_gpg_verify(r, TRUE);
    flatpak_remote_set_noenumerate(r, FALSE);
    flatpak_remote_set_gpg_key(r, key_bytes = g_bytes_new(key, keylen));
    g_bytes_unref(key_bytes);

    if (!flatpak_installation_modify_remote(c->f, r, NULL, &e))
        goto failed;

 out:
    g_object_unref(r);
    return 0;

 failed:
    log_error("flatpak: failed to install remote %s (%s: %d: %s)",
              name, g_quark_to_string(e->domain), e->code, e->message);
    g_object_unref(r);
    g_error_free(e);

    return -1;
}


static void strip_whitespace(char *url, int len)
{
    char *p = url;
    int n;

    for (p = url; isspace(*p) && p < url + len; p++)
        ;

    if (p != url) {
        n = p - url;
        len -= n;
        memmove(url, p, len);
    }

    while (len > 0 && isspace(url[len - 1]))
        url[--len] = '\0';
}


static ssize_t read_url_and_key(int urlfd, char *url, size_t urlsize,
                                int keyfd, char *key, size_t keysize)
{
    int         len, n;
    struct stat st;

    if (urlfd < 0 || keyfd < 0)
        return -1;

    if (fstat(urlfd, &st) < 0)
        return -1;

    if (st.st_size > (int)urlsize - 1)
        return -1;

    len = 0;
    while (len < st.st_size) {
        n = read(urlfd, url + len, st.st_size - len);

        if (n < 0) {
            if (errno != EINTR)
                return -1;
            else
                continue;
        }

        len += n;
    }
    url[len] = '\0';

    if (len > 0)
        strip_whitespace(url, len - 1);

    if (fstat(keyfd, &st) < 0)
        return -1;

    if (st.st_size > (int)keysize)
        return -1;

    len = 0;
    while (len < st.st_size) {
        n = read(keyfd, key + len, st.st_size - len);

        if (n < 0) {
            if (errno != EINTR)
                return -1;
            else
                continue;
        }

        len += n;
    }

    return len;
}


int fpak_install_remotes(context_t *c, const char *dir)
{
    DIR           *dp;
    struct dirent *de;
    char          *suff, name[PATH_MAX], path[PATH_MAX];
    int            keyfd, urlfd, keylen, len;
    char           key[4096], url[1024 + PATH_MAX];

    dp = opendir(dir);

    if (dp == NULL)
        return errno == ENOENT ? 0 : -1;

    while ((de = readdir(dp)) != NULL) {
        if (de->d_type != DT_REG)
            continue;

        if ((suff = strrchr(de->d_name, '.')) == NULL)
            continue;

        if (strcmp(suff + 1, "url") != 0)
            continue;

        len = (int)(suff - de->d_name);
        snprintf(name, sizeof(name), "%.*s", len, de->d_name);

        snprintf(path, sizeof(path), "%s/%s.url", dir, name);
        urlfd = open(path, O_RDONLY);
        snprintf(path, sizeof(path), "%s/%s.key", dir, name);
        keyfd = open(path, O_RDONLY);

        keylen = read_url_and_key(urlfd, url, sizeof(url),
                                  keyfd, key, sizeof(key));

        close(urlfd);
        close(keyfd);

        if (keylen > 0)
            fpak_create_remote(c, name, url, key, keylen);
        else
            log_error("flatpak: failed to read URL or key for remote %s", name);
    }

    closedir(dp);

    return 0;
}


int fpak_init(context_t *c, int flags)
{
    GError *e;

    if (c->f != NULL)
        return 0;

    e    = NULL;
    c->f = flatpak_installation_new_system(NULL, &e);

    if (c->f == NULL)
        goto init_failed;

    fpak_install_remotes(c, FPAK_REPOS_DIR);
    flatpak_installation_drop_caches(c->f, NULL, &e);

    if (flags & (FPAK_DISCOVER_REMOTES | FPAK_DISCOVER_APPS))
        if (fpak_discover_remotes(c) < 0)
            goto fail;

    if (flags & FPAK_DISCOVER_APPS)
        if (fpak_discover_apps(c) < 0)
            goto fail;

    return 0;

 init_failed:
    log_fatal("flatpak: failed to initialize library (%s: %d: %s)",
              g_quark_to_string(e->domain), e->code, e->message);

 fail:
    return -1;
}


int fpak_discover_remotes(context_t *c)
{
    remote_t      *r;
    const char    *name, *url;
    uid_t          uid;
    GPtrArray     *refs;
    FlatpakRemote *ref;
    GError        *e;
    int            i;

    if (c->remotes != NULL)
        return 0;

    e    = NULL;
    refs = flatpak_installation_list_remotes(c->f, NULL, &e);

    if (refs == NULL)
        goto list_failed;

    c->remotes = calloc(refs->len + 1, sizeof(*c->remotes));

    if (c->remotes == NULL)
        log_fatal("flatpak: failed to allocate remotes");

    r = c->remotes;
    for (i = 0; i < (int)refs->len; i++) {
        ref  = g_ptr_array_index(refs, i);
        name = flatpak_remote_get_name(ref);
        url  = flatpak_remote_get_url(ref);

        if (flatpak_remote_get_disabled(ref)) {
            log_warn("flatpak: skipping disabled remote '%s'", name);
            continue;
        }

        if (c->gpg_verify && !flatpak_remote_get_gpg_verify(ref)) {
            log_warn("flatpak: skipping unverifiable remote '%s'", name);
            continue;
        }

        if ((uid = remote_user_id(name, NULL, 0)) == INVALID_UID) {
            log_warn("flatpak: skipping remote without user '%s'", name);
            continue;
        }

        if (c->remote_uid > 0 && uid != c->remote_uid) {
            log_debug("flatpak: skipping other remote '%s'", name);
            continue;
        }

        r->name = strdup(name);
        r->url  = strdup(url);
        r->user = strdup(remote_user_name(uid, NULL, 0));
        r->uid  = uid;

        if (r->name == NULL || r->url == NULL || r->user == NULL)
            log_fatal("flatpak: failed to allocate remote");

        log_info("flatpak: discovered remote '%s' (%s)", r->name, r->url);

        c->nremote++;
        r++;

    }

    g_ptr_array_unref(refs);

    return 0;

 list_failed:
    log_error("flatpak: failed to query remotes (%s: %d: %s)",
              g_quark_to_string(e->domain), e->code, e->message);
    return -1;
}


static int update_urgent(const char *urgency)
{
    return !!(!strcmp(urgency, "critical") || !strcmp(urgency, "important"));
}


int fpak_discover_apps(context_t *c)
{
    application_t       *a;
    GKeyFile            *m;
    const char          *origin, *name, *head, *urgency;
    GPtrArray           *refs;
    FlatpakInstalledRef *ref;
    FlatpakRefKind       knd;
    GError              *e;
    int                  install, start, urgent;
    int                  i;

    if (c->apps != NULL)
        return 0;

    if (fpak_discover_remotes(c) < 0)
        return -1;

    knd  = FLATPAK_REF_KIND_APP;
    e    = NULL;
    refs = flatpak_installation_list_installed_refs_by_kind(c->f, knd, NULL, &e);

    if (refs == NULL)
        goto list_failed;

    c->apps = calloc(refs->len + 1, sizeof(*c->apps));

    if (c->apps == NULL)
        log_fatal("flatpak: failed to allocate applications");

    a = c->apps;
    for (i = 0; i < (int)refs->len; i++) {
        ref    = g_ptr_array_index(refs, i);
        origin = flatpak_installed_ref_get_origin(ref);
        name   = flatpak_ref_get_name(FLATPAK_REF(ref));
        head   = flatpak_ref_get_commit(FLATPAK_REF(ref));

        if (fpak_lookup_remote(c, origin) == NULL) {
            log_debug("flatpak: skipping app '%s' without remote", name);
            continue;
        }

        if ((m = meta_load(ref)) == NULL)
            goto meta_failed;
        install = meta_bool(m, FPAK_SECTION_REFKIT, FPAK_KEY_INSTALL, 1);
        start   = meta_bool(m, FPAK_SECTION_REFKIT, FPAK_KEY_START  , 1);
        urgency = meta_str (m, FPAK_SECTION_REFKIT, FPAK_KEY_URGENCY, "-");
        urgent  = update_urgent(urgency);
        meta_free(m);

        a->origin  = strdup(origin);
        a->name    = strdup(name);
        a->head    = strdup(head);
        a->install = install;
        a->start   = start;
        a->urgent  = urgent;

        if (a->origin == NULL || a->name == NULL || a->head == NULL)
            log_fatal("flatpak: failed to allocate app");

        c->napp++;
        a++;
    }

    g_ptr_array_unref(refs);

    return 0;

 list_failed:
    log_error("flatpak: failed to query applications (%s: %d: %s)",
              g_quark_to_string(e->domain), e->code, e->message);
    return -1;

 meta_failed:
    log_error("flatpak: failed to load metadata for '%s'", name);
    return -1;
}


int fpak_start_app(context_t *c, application_t *a)
{
    GError *e;
    int     status;

    log_info("flatpak: starting application %s", a->name);

    if (c->dry_run)
        return 0;

    sigprocmask(SIG_UNBLOCK, &c->signals, NULL);
    e = NULL;
    if (!flatpak_installation_launch(c->f, a->name, NULL, NULL, NULL, NULL, &e))
        status = -1;
    else
        status = 0;
    sigprocmask(SIG_BLOCK, &c->signals, NULL);

    if (!status)
        return 0;
    else {
        log_error("flatpak: failed to start '%s' (%s: %d: %s)", a->name,
                  g_quark_to_string(e->domain), e->code, e->message);
        return -1;
    }
}


int fpak_start_session(context_t *c)
{
    remote_t      *r;
    application_t *a;

    r = fpak_remote_for_uid(c, c->remote_uid);

    if (r == NULL)
        goto no_remote;

    fpak_foreach_app(c, a) {
        if (strcmp(a->origin, r->name))
            continue;

        fpak_start_app(c, a);
    }

    return 0;

 no_remote:
    log_error("flatpak: no remote associated with uid %d", c->remote_uid);
    return -1;
}


int fpak_reload_session(context_t *c)
{
    application_t *a;

    fpak_foreach_app(c, a) {
        if (a->updated) {
            log_info("flatpak: %s had updates, should be restarted", a->name);
            a->updated = 0;
        }
    }

    if (c->forced_restart)
        exit(c->forced_restart);

    return 0;
}


static void progress_cb(const char *status, guint pcnt, gboolean estim,
                        gpointer user_data)
{
    application_t *a = user_data;

    if (estim)
        return;

    log_info("flatpak: %s/%s, %s, %d %% done", a->origin, a->name, status, pcnt);
}


int fpak_update_apps(context_t *c)
{
    application_t       *a;
    FlatpakInstalledRef *u;
    const char          *name, *origin, *urgency;
    GKeyFile            *m;
    int                  install, start, urgent;
    FlatpakRefKind       rk = FLATPAK_REF_KIND_APP;
    GError              *e;

    fpak_foreach_app(c, a) {
        if (!a->pending)
            continue;

        name   = a->name;
        origin = a->origin;
        e      = NULL;

        log_info("flatpak: %s '%s'", a->head ? "updating" : "installing", name);

        if (c->dry_run)
            continue;

        if (a->head != NULL)
            u = flatpak_installation_update(c->f, 0, rk, name, NULL, NULL,
                                            progress_cb, a, NULL, &e);
        else
            u = flatpak_installation_install(c->f, origin, rk, name, NULL, NULL,
                                             progress_cb, a, NULL, &e);

        if (u == NULL) {
            if (e && e->code)
                log_warn("flatpak: failed to update '%s' (%s: %d: %s)", name,
                         g_quark_to_string(e->domain), e->code, e->message);
            continue;
        }

        if ((m = meta_load(u)) == NULL) {
            log_warn("flatpak: failed to load metadata for '%s'", name);
            goto next;
        }
        start   = meta_bool(m, FPAK_SECTION_REFKIT, FPAK_KEY_START  , 1);
        install = meta_bool(m, FPAK_SECTION_REFKIT, FPAK_KEY_INSTALL, 1);
        urgency = meta_str (m, FPAK_SECTION_REFKIT, FPAK_KEY_URGENCY, "-");
        urgent  = update_urgent(urgency);
        meta_free(m);

        a->start   = start;
        a->install = install;
        a->urgent  = urgent;

        free(a->head);
        a->head = strdup(flatpak_ref_get_commit(FLATPAK_REF(u)));

        if (!install) {
            /* XXX TODO: I think this will fail if app is running... */
            if (!flatpak_installation_uninstall(c->f, rk, name, NULL, NULL,
                                                progress_cb, a, NULL, &e))
                log_warn("flatpak: failed to uninstall '%s' (%s: %d: %s)", name,
                         g_quark_to_string(e->domain), e->code, e->message);
        }

    next:
        g_object_unref(u);
        a->pending = 0;
    }

    return 0;
}


int fpak_reload_apps(context_t *c)
{
    application_t       *a;
    const char          *name, *head;
    FlatpakInstalledRef *u;
    GError              *e;

    e = NULL;
    flatpak_installation_drop_caches(c->f, NULL, &e);

    fpak_foreach_app(c, a) {
        name = a->name;
        e = NULL;
        u = flatpak_installation_get_current_installed_app(c->f, name, NULL, &e);

        if (u == NULL)
            continue;

        head = flatpak_ref_get_commit(FLATPAK_REF(u));
        if (strcmp(a->head, head)) {
            log_info("flatpak: '%s' updated (%s -> %s)", name, a->head, head);

            free(a->head);
            a->head    = strdup(head);
            a->updated = 1;
        }
        else {
            log_info("flatpak: '%s' did not change", name);
            a->updated = 0;
        }

        g_object_unref(u);
    }

    return 0;
}


remote_t *fpak_lookup_remote(context_t *c, const char *name)
{
    remote_t *r;

    if (c->remotes == NULL)
        return NULL;

    for (r = c->remotes; r->name; r++)
        if (!strcmp(r->name, name))
            return r;

    return NULL;
}


remote_t *fpak_remote_for_uid(context_t *c, uid_t uid)
{
    remote_t *r;

    if (c->remotes == NULL)
        return NULL;

    for (r = c->remotes; r->name; r++)
        if (r->uid == uid)
            return r;

    return NULL;
}


application_t *fpak_lookup_app(context_t *c, const char *name)
{
    application_t *a;

    if (c->apps == NULL)
        return NULL;

    for (a = c->apps; a->name; a++)
        if (!strcmp(a->name, name))
            return a;

    return NULL;
}


int fpak_poll_updates(context_t *c)
{
    remote_t         *r;
    application_t    *a;
    GPtrArray        *refs;
    FlatpakRemoteRef *ref;
    const char       *origin, *name, *head, *urgency;
    GKeyFile         *m;
    GError           *e;
    int               i, install, urgent, updates;

    updates = 0;

    fpak_foreach_remote(c, r) {
        name = r->name;

        log_info("flatpak: polling remote '%s' for updates...", name);

        e    = NULL;
        refs = flatpak_installation_list_remote_refs_sync(c->f, name, NULL, &e);

        if (refs == NULL) {
            log_error("flatpak: failed to query updates for %s (%s: %d: %s)",
                      g_quark_to_string(e->domain), e->code, e->message);
            continue;
        }

        origin = name;
        for (i = 0; i < (int)refs->len; i++) {
            ref = g_ptr_array_index(refs, i);

            if (flatpak_ref_get_kind(FLATPAK_REF(ref)) != FLATPAK_REF_KIND_APP)
                continue;

            name = flatpak_ref_get_name(FLATPAK_REF(ref));
            head = flatpak_ref_get_commit(FLATPAK_REF(ref));

            if ((m = meta_fetch(c, ref)) == NULL) {
                log_error("flatpak: failed to fetch metadata for '%s'", name);
                continue;
            }
            install = meta_bool(m, FPAK_SECTION_REFKIT, FPAK_KEY_INSTALL, 1);
            urgency = meta_get (m, FPAK_SECTION_REFKIT, FPAK_KEY_URGENCY, "-");
            urgent  = update_urgent(urgency);
            meta_free(m);

            a = fpak_lookup_app(c, name);

            if (a == NULL) {
                if (!install)
                    continue;

                log_info("flatpak: pending new app '%s'", name);

                c->apps = realloc(c->apps, (c->napp + 2) * sizeof(*c->apps));

                if (c->apps == NULL)
                    log_fatal("flatpak: failed to allocate applications");

                a = c->apps + c->napp;

                memset(a    , 0, sizeof(*a)); /* shouldn't be necessary */
                memset(a + 1, 0, sizeof(*a));

                a->name    = strdup(name);
                a->origin  = strdup(origin);
                a->head    = NULL;

                if (a->name == NULL || a->origin == NULL)
                    log_fatal("flatpak: failed to allocate application");

                a->pending = 1;
                a->urgent  = urgent;

                c->napp++;
                updates++;
            }
            else {
                if (a->head != NULL && strcmp(a->head, head)) {
                    log_info("flatpak: pending updates for app '%s'", name);
                    a->pending = 1;
                    updates++;
                }
                else
                    log_info("flatpak: %s up-to-date", name);
            }
        }
    }

    if (!updates)
        log_info("no pending updates");

    return updates;
}


static int check_remote_update(gpointer user_data)
{
    context_t *c = user_data;

    if (fpak_poll_updates(c) > 0)
        c->notify.r_up(c);

    return G_SOURCE_CONTINUE;
}


int fpak_track_remote_updates(context_t *c, void (*cb)(context_t *))
{
    if (c->notify.r_up != NULL)
        return -1;

    c->rpt = timer_add(c, c->poll_interval, check_remote_update, c);

    c->notify.r_up = cb;

    return 0;
}


static int notify_local_update(gpointer user_data)
{
    context_t *c = user_data;

    timer_del(c, c->lmlpt);
    c->lmlpt = 0;

    c->notify.l_up(c);

    return G_SOURCE_REMOVE;
}


static void l_changed(GFileMonitor *m, GFile *file, GFile *other,
                      GFileMonitorEvent e, gpointer user_data)
{
    context_t *c = user_data;
    char      *fpath, *opath;

    UNUSED_ARG(m);
    UNUSED_ARG(e);

    fpath = file  ? g_file_get_path(file)  : NULL;
    opath = other ? g_file_get_path(other) : NULL;
    log_debug("local change (%s, %s), arming low-pass filter timer...\n",
              fpath ? fpath : "-", opath ? opath : "-");
    g_free(fpath);
    g_free(opath);

    timer_del(c, c->lmlpt);
    c->lmlpt = timer_add(c, FPAK_UPDATE_LOWPASS_TIMER, notify_local_update, c);
}


int fpak_track_local_updates(context_t *c, void (*cb)(context_t *))
{
    GError *e;

    if (c->notify.l_up != NULL)
        return -1;

    e     = NULL;
    c->lm = flatpak_installation_create_monitor(c->f, NULL, &e);

    if (c->lm == NULL)
        goto monitor_failed;

    c->lmcn = g_signal_connect(c->lm, "changed", G_CALLBACK(l_changed), c);

    if (c->lmcn <= 0)
        goto connect_failed;

    c->notify.l_up = cb;

    return 0;

 monitor_failed:
    log_error("flatpak: failed to create installation monitor (%s: %d: %s)",
              g_quark_to_string(e->domain), e->code, e->message);
    return -1;

 connect_failed:
    log_error("flatpak: failed to connect to installation monitor");
    return -1;

    return 0;
}


static GKeyFile *meta_load(FlatpakInstalledRef *ref)
{
    GKeyFile   *m;
    GBytes     *b;
    const void *d;
    size_t      l;
    GError     *e;

    b = NULL;
    m = g_key_file_new();

    if (m == NULL)
        log_fatal("flatpak: failed to allocate metadata");

    e = NULL;
    b = flatpak_installed_ref_load_metadata(ref, NULL, &e);

    if (b == NULL)
        goto fail_meta;

    d = g_bytes_get_data(b, &l);

    if (d == NULL)
        goto fail_data;

    if (!g_key_file_load_from_data(m, d, l, 0, &e))
        goto fail_load;

    g_bytes_unref(b);

    return m;

 fail_load:
    log_error("flatpak: failed to parse metadata (%s: %d: %s)",
              g_quark_to_string(e->domain), e->code, e->message);
 fail_meta:
 fail_data:
    g_key_file_unref(m);
    g_bytes_unref(b);
    return NULL;
}


static GKeyFile *meta_fetch(context_t *c, FlatpakRemoteRef *rref)
{
    GKeyFile   *m;
    GBytes     *b;
    const void *d;
    size_t      l;
    FlatpakRef *ref;
    const char *remote;
    GError     *e;

    b = NULL;
    m = g_key_file_new();

    if (m == NULL)
        log_fatal("flatpak: failed to allocate metadata");

    g_object_get(rref, "remote-name", &remote, NULL);

    ref = FLATPAK_REF(rref);
    e   = NULL;
    b   = flatpak_installation_fetch_remote_metadata_sync(c->f, remote, ref,
                                                          NULL, &e);

    if (b == NULL)
        goto fail_meta;

    d = g_bytes_get_data(b, &l);

    if (d == NULL)
        goto fail_data;

    if (!g_key_file_load_from_data(m, d, l, 0, &e))
        goto fail_load;

    g_bytes_unref(b);

    return m;

 fail_load:
    log_error("flatpak: failed to parse metadata (%s: %d: %s)",
              g_quark_to_string(e->domain), e->code, e->message);
 fail_meta:
 fail_data:
    g_key_file_unref(m);
    g_bytes_unref(b);
    return NULL;
}


static void meta_free(GKeyFile *m)
{
    if (m != NULL)
        g_key_file_unref(m);
}


static const char *meta_get(GKeyFile *m, const char *sec, const char *key,
                            const char *def)
{
    const char *val;

    if (m == NULL)
        return def;

    val = g_key_file_get_value(m, sec, key, NULL);

    return val ? val : def;
}


static int meta_int(GKeyFile *m, const char *sec, const char *key, int def)
{
    const char *val;
    char       *e;
    int         i;

    if (m == NULL)
        return def;

    val = g_key_file_get_value(m, sec, key, NULL);

    if (val == NULL)
        return def;

    i = strtol(val, &e, 10);

    if (e && !*e)
        return i;

    log_warn("flatpak: invalid metadata integer '%s'", val);
    return def;
}


static int meta_bool(GKeyFile *m, const char *sec, const char *key, int def)
{
    const char *val;

    UNUSED_ARG(meta_int);

    if (m == NULL)
        return !!def;

    val = g_key_file_get_value(m, sec, key, NULL);

    if (val == NULL)
        return !!def;

    return !!(!strcasecmp(val, "true") || !strcasecmp(val, "yes"));
}
