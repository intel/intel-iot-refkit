SUMMARY = "Tools for using the ESRT and UpdateCapsule() to apply firmware updates"
LICENSE = "GPLv2"
LIC_FILES_CHKSUM = "file://${S}/COPYING;md5=6d7bfc784f89da02599036c034adfb34"
DEPENDS = " \
    efibootmgr \
    efivar \
    gnu-efi \
"

SRC_URI = "git://github.com/rhboot/fwupdate.git;method=https \
           file://0001-add_to_boot_order-actually-always-pass-in-attributes.patch \
           file://0002-Fix-sprintf-formatting-for-Boot.patch \
           file://0003-Fix-uninitialized-variable.patch \
           "
SRCREV = "58532d474d084ed39c977279108dbbf208413ef5"
S = "${WORKDIR}/git"

inherit gettext pkgconfig check-available
CHECK_AVAILABLE[efibootmgr] = "${HAVE_EFIBOOTMGR}"

# There is -I/usr/include/efi/ -I/usr/include/efi/$(ARCH)/ in efi/Makefile,
# but those seem to be ignored due to -nostdinc (considered "system includes"
# because of the path by gcc?). We need to specify them with the full, non-standard
# path.
#
# GNUEFIDIR and LIBDIR below includes the sysroot for the same reason.
CFLAGS += "-I${RECIPE_SYSROOT}${includedir}/efi -I${RECIPE_SYSROOT}${includedir}/efi/${ARCH} -I${RECIPE_SYSROOT}${includedir}/efivar"

# Does not work in combination with the -mno-sse that is needed
# for the EFI app.
CC_remove = "-mfpmath=sse"

EXTRA_OEMAKE += " \
    CC='${CC}' \
    LD='${LD}' \
    CPP='${CPP}' \
    OBJCOPY='${OBJCOPY}' \
    CFLAGS='${CFLAGS}' \
    libdir=${libdir}/ \
    libexecdir=${libexecdir}/ \
    datadir=${datadir}/cache/ \
    localedir=${datadir}/locale/ \
    LIBDIR=${RECIPE_SYSROOT}${libdir}/ \
    GNUEFIDIR=${RECIPE_SYSROOT}${libdir}/ \
    EFIDIR=${@ '${DISTRO}'.lower() } \
"

# libsmbios currently has no recipe. fwupdate compiles also without it.
EXTRA_OEMAKE += "HAVE_LIBSMBIOS=no"

do_install () {
    oe_runmake install DESTDIR=${D}
    rm -f ${D}/${debuglibdir}/boot/efi/EFI/refkit/fwupx64.efi.debug
}

PACKAGES += "${PN}-bash-completion"
FILES_${PN}-bash-completion = "${datadir}/bash-completion/completions/"
RDEPENDS_${PN}-bash-completion = "bash"

# Packaging these files does not help much. We lack conventions and
# a postinst for installing them into the actual EFI system partition.
# TODO: deploy the files into the image dir instead and build images
# with them via the EFI_PROVIDER mechanism.
PACKAGES += "${PN}-boot"
FILES_${PN}-boot += "/boot"

FILES_${PN} += " \
    ${datadir}/cache/fwupdate \
    ${systemd_system_unitdir} \
"

# The EFI app doesn't pass the test because it needs to be (?) compiled
# differently. We therefore disable the check to avoid:
# do_package_qa: QA Issue: No GNU_HASH in the elf binary: '.../packages-split/fwupdate-dbg/usr/lib/debug/boot/efi/EFI/refkit/fwupx64.efi.debug' [ldflags]
WARN_QA_remove = "ldflags"
ERROR_QA_remove = "ldflags"
