SUBDIRS     = .
AM_CFLAGS   = $(WARNING_CFLAGS) $(AM_CPPFLAGS) $(PATHDEFS)
AM_CPPFLAGS = -I$(top_srcdir) -I$(top_srcdir)/src \
              -I$(top_builddir) -I$(top_builddir)/src
PATHDEFS    = -DSYSCONFDIR=\"${sysconfdir}\" \
              -DLIBDIR=\"${libdir}\" \
              -DLIBEXECDIR=\"${libexecdir}\"

generator_PROGRAMS = flatpak-session-enable
generatordir       = @SYSTEMD_UNITDIR@/system-generators

systemd_DATA       = flatpak-session@.service \
                     flatpak-sessions.target \
	             flatpak-update.service
systemddir         = @SYSTEMD_UNITDIR@/system

bin_PROGRAMS    =

#############################################
# flatpak-service-generator
#

bin_PROGRAMS += flatpak-session

flatpak_session_SOURCES =		\
		flatpak-session.c	\
		config.c		\
		log.c			\
		mainloop.c		\
		remote.c		\
		filesystem.c		\
		flatpak.c

flatpak_session_CFLAGS =		\
		$(AM_CFLAGS)		\
		$(PATHDEFS)		\
		$(FLATPAK_CFLAGS)

flatpak_session_LDADD =			\
		$(FLATPAK_LIBS)		\
		-lm

flatpak-session-enable: flatpak-session
	rm -f $@ && ln $< $@

# cleanup
clean-local:
	-rm -f *~
