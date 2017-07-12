# Check we have the necessary distro features enabled.
inherit distro_features_check
REQUIRED_DISTRO_FEATURES_append = " usrmerge systemd pam"

inherit flatpak-config

# These are lists of files we check to determine the flatpak
# runtime type of an image if it is not directly visible from
# the image name. This did not used to be necessary before we
# made the gateway image a flatpak-enabled (flatpak-runtime)
# by itself, but now it is. Actually we could now drop the
# other, image name based, tests altogether...
FLATPAK_RUNTIME_FILES = " \
    /usr/bin/flatpak \
"

FLATPAK_SDK_FILES = " \
    /usr/bin/flatpak /usr/bin/gcc /usr/bin/make \
    /usr/bin/patch /usr/bin/pkg-config \
    /usr/include/stdio.h /usr/include/stdlib.h \
"

#
# Create and populate a primary flatpak repository from/for an image.
#
fakeroot do_flatpak_populate_repository () {
   echo "Flatpak repository population:"
   echo "  * FLATPAKBASE:    ${FLATPAKBASE}"
   echo "  * IMAGE_BASENAME: ${IMAGE_BASENAME}"

   # Bail out early if flatpak is not enabled for this image.
   case ${IMAGE_BASENAME} in
       *-flatpak-runtime) RUNTIME_TYPE=BasePlatform;;
       *-flatpak-sdk)     RUNTIME_TYPE=BaseSdk;;
       *)
           RUNTIME_TYPE=BaseSdk
           for f in ${FLATPAK_SDK_FILES}; do
               if [ ! -e ${IMAGE_ROOTFS}/$f ]; then
                   RUNTIME_TYPE=""
                   break
               fi
           done

           if [ -z "$RUNTIME_TYPE" ]; then
               RUNTIME_TYPE=BasePlatform
               for f in ${FLATPAK_RUNTIME_FILES}; do
                   if [ ! -e ${IMAGE_ROOTFS}/$f ]; then
                       RUNTIME_TYPE=""
                       break
                   fi
               done
           fi

           if [ -z "$RUNTIME_TYPE" ]; then
               echo "${IMAGE_BASENAME} is not a flatpak-enabled image..."
               return 0
           fi
           ;;
   esac

   echo "${IMAGE_BASENAME} is a flatpak $RUNTIME_TYPE image"

   if [ -n "${FLATPAK_GPGID}" ]; then
       GPG_SIGN="--gpg-home ${FLATPAK_GPGDIR} --gpg-id ${FLATPAK_GPGID}"
   else
       GPG_SIGN=""
   fi

   # Hmm... it might be a better idea to either preconstruct this in
   # flatpak-config and just be a postman for it here, or pass these
   # separately to the backend script and let that construct these.
   # XXX TODO: We'll need to revisit this and decide...

   _base="runtime/${FLATPAK_DOMAIN}.$RUNTIME_TYPE/${FLATPAK_ARCH}"
   _t=""
   for _b in ${FLATPAK_BRANCH} ${FLATPAK_LATEST} ${FLATPAK_BUILD}; do
       BRANCHES="$BRANCHES$_t$_base/$_b"
       _t=","
   done

   echo "Using flatpak branches $BRANCHES for ${IMAGE_ROOTFS}..."

   # Generate/populate flatpak/OSTree repository
   ${FLATPAKBASE}/scripts/flatpak-populate-repo.sh \
       --repo-path ${FLATPAK_REPO} \
       --repo-mode bare-user \
       $GPG_SIGN \
       --branches "$BRANCHES" \
       --image-sysroot ${IMAGE_ROOTFS} \
       --tmp-dir ${TMPDIR}
}

do_flatpak_populate_repository[depends] += " \
    ostree-native:do_populate_sysroot \
    flatpak-native:do_populate_sysroot \
    gnupg1-native:do_populate_sysroot \
"

do_flatpak_populate_repository[vardeps] += " \
    FLATPAK_REPO \
    FLATPAK_EXPORT \
    FLATPAK_DOMAIN \
    FLATPAK_BRANCH \
    FLATPAK_LATEST \
    FLATPAK_BUILD \
    FLATPAK_GPGID \
"

#
# Export an image (well the bare-user repo, really) to an archive-z2 repo.
#
fakeroot do_flatpak_export_repository () {
   # Bail out early if no export repository is defined.
   if [ -z "${FLATPAK_EXPORT}" ]; then
       echo "Flatpak repository for export not specified, skip export..."
       return 0
   fi

   # Bail out early if flatpak is not enabled for this image.
   case ${IMAGE_BASENAME} in
       *-flatpak-runtime) RUNTIME_TYPE=BasePlatform;;
       *-flatpak-sdk)     RUNTIME_TYPE=BaseSdk;;
       *)
           RUNTIME_TYPE=BaseSdk
           for f in ${FLATPAK_SDK_FILES}; do
               if [ ! -e ${IMAGE_ROOTFS}/$f ]; then
                   RUNTIME_TYPE=""
                   break
               fi
           done

           if [ -z "$RUNTIME_TYPE" ]; then
               RUNTIME_TYPE=BasePlatform
               for f in ${FLATPAK_RUNTIME_FILES}; do
                   if [ ! -e ${IMAGE_ROOTFS}/$f ]; then
                       RUNTIME_TYPE=""
                       break
                   fi
               done
           fi

           if [ -z "$RUNTIME_TYPE" ]; then
               echo "${IMAGE_BASENAME} is not a flatpak-enabled image..."
               return 0
           fi
           ;;
   esac

   echo "${IMAGE_BASENAME} is a flatpak $RUNTIME_TYPE image"

   if [ -n "${FLATPAK_GPGID}" ]; then
       GPG_SIGN="--gpg-home ${FLATPAK_GPGDIR} --gpg-id ${FLATPAK_GPGID}"
   else
       GPG_SIGN=""
   fi

   # Export to archive-z2 flatpak/OSTree repository
   ${FLATPAKBASE}/scripts/flatpak-populate-repo.sh \
       --repo-path ${FLATPAK_REPO} \
       --repo-export ${FLATPAK_EXPORT} \
       --machine ${MACHINE} \
       $GPG_SIGN \
       --tmp-dir ${TMPDIR}
}

do_flatpak_export_repository[depends] += " \
    ostree-native:do_populate_sysroot \
    flatpak-native:do_populate_sysroot \
    gnupg1-native:do_populate_sysroot \
"

do_flatpak_export_repository[vardeps] += " \
    FLATPAK_REPO \
    FLATPAK_EXPORT \
    FLATPAK_DOMAIN \
    FLATPAK_BRANCH \
    FLATPAK_LATEST \
    FLATPAK_BUILD \
    FLATPAK_GPGID \
    MACHINE \
"

addtask flatpak_populate_repository \
    after do_rootfs \
    before do_image_complete

addtask flatpak_export_repository \
    after do_flatpak_populate_repository \
    before do_image_complete

