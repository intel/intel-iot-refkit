HOOK_DIR  = ${datadir}/${PACKAGE_NAME}/hooks
AM_CFLAGS = $(WARNING_CFLAGS) -DHOOK_DIR="\"${HOOK_DIR}\""

bin_PROGRAMS   =
script_SCRIPTS = scripts/refkit-ostree scripts/systemd-inhibitable-reboot
scriptdir      = ${datadir}/${PACKAGE_NAME}/scripts

servicedir   = ${SYSTEMD_UNITDIR}
service_DATA = \
	services/refkit-patch-ostree-param.service \
        services/refkit-update.service \
        services/refkit-update-post-check.service \
        services/refkit-reboot.service \
        services/refkit-update-post-failure.service \
        services/refkit-update-post-failure.target

# refkit-ostree
bin_PROGRAMS += refkit-ostree

refkit_ostree_SOURCES = src/refkit-ostree.c
refkit_ostree_CFLAGS  = $(AM_CFLAGS) $(OSTREE_CFLAGS)
refkit_ostree_LDADD   =

# refkit-ostree-update
bin_PROGRAMS += refkit-ostree-update

refkit_ostree_update_SOURCES = src/refkit-ostree.c
refkit_ostree_update_CFLAGS  = $(AM_CFLAGS) $(OSTREE_CFLAGS) -D__REFKIT_UPDATER__
refkit_ostree_update_LDADD   = $(OSTREE_LIBS)

install-data-local:
	install -m 0755 -d $(DESTDIR)$(HOOK_DIR)/post-apply.d
	install -m 0755 -T $(top_srcdir)/hooks/run-hooks \
	    $(DESTDIR)$(HOOK_DIR)/post-apply
	for h in $(top_srcdir)/hooks/post-apply.d/[0-9]*; do \
	    if [ -x $$h ]; then \
	        install -m 0755 $$h $(DESTDIR)$(HOOK_DIR)/post-apply.d; \
	    fi; \
	done

	install -m 0755 -d $(DESTDIR)$(HOOK_DIR)/post-update-check.d
	install -m 0755 -T $(top_srcdir)/hooks/run-hooks \
	    $(DESTDIR)$(HOOK_DIR)/post-update-check
	for h in $(top_srcdir)/hooks/post-update-check.d/[0-9]*; do \
	    if [ -x $$h ]; then \
	        install -m 0755 $$h $(DESTDIR)$(HOOK_DIR)/post-update-check.d; \
	    fi; \
	done

	install -m 0755 -d $(DESTDIR)$(HOOK_DIR)/rollback.d
	install -m 0755 -T $(top_srcdir)/hooks/run-hooks \
	    $(DESTDIR)$(HOOK_DIR)/rollback
