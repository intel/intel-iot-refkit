Building with swupd enabled
===========================

* git clone --recursive --branch installer-image https://github.com/pohly/intel-iot-refkit.git
* git clone https://git.yoctoproject.org/git/meta-swupd
* cd intel-iot-refkit
* . refkit-init-build-env
* bitbake-layers add-layer `pwd`/../../meta-swupd
* Add to local.conf:

      require conf/distro/include/refkit-development.inc

      REFKIT_IMAGE_COMMON_EXTRA_FEATURES_append = " swupd"
      OS_VERSION = "1000"
      SWUPD_VERSION_URL = ""
      SWUPD_CONTENT_URL = ""

* bitbake ovmf refkit-installer-image refkit-image-common swtpm-wrappers
* meta-swupd/scripts/swupd-http-server &
* Edit local.conf to build an incremental update:

      OS_VERSION = "1010"
      SWUPD_VERSION_URL = "http://localhost:8000"
      SWUPD_CONTENT_URL = "http://localhost:8000"

* bitbake refkit-image-common # Do not rebuild the refkit-installer-image!

Installing, rebooting, updating
===============================

Precondition: user must be able to run commands as root with sudo.

* cd intel-iot-refkit
* . refkit-init-build-env
* export PATH=../doc/howtos/image-installer:$PATH
* meta-swupd/scripts/swupd-http-server &
* init-tpm # initializes content of a virtual TPM
* run-swtpm # run software TPM in background as root, creates /dev/vtpm0 (must be repeated after each runqemu run!)
* runqemu-install
* Once booting has finished:
  * lsblk # dm-verity is active, shown twice and size is a bit odd (hash partition /dev/vda4 should be smaller)
  * mount # rootfs is ro
  * image-installer
  * select refkit-image-common (swupd enabled!), confirm vdb, yes
  * reboot
* run-swtpm
* cp tmp-glibc/deploy/images/intel-corei7-64/my-installed-image-intel-corei7-64.wic tmp-glibc/deploy/images/intel-corei7-64/my-installed-image-intel-corei7-64.wic.1000 # can be copied back to repeat the following steps without starting at the top
* runqemu-internal-disk
* Once booted:
  * cat /etc/os-release
  * lsblk # LUKS crypt active
  * mount # rootfs is rw
  * connmanctl services
  * connmanctl config ethernet_525400123402_cable --ipv4 manual 192.168.7.2 # must match tap0 on host
  * swupd verify --url http://192.168.7.1:8000
  * cryptsetup # command not available
  * swupd update --url http://192.168.7.1:8000 # fast, incremental update
  * cryptsetup status rootfs
  * cat /etc/os-release

Troubleshooting
===============

bitbake do_fetch_swupd_inputs fails: SWUPD_VERSION_URL and
SWUPD_CONTENT_URL must be empty for the first build, and non-empty in the
second build. meta-swupd/scripts/swupd-http-server must be running
during the second build.

qemu can't open /dev/vtpm0: run-swtpm. Must be done after each runqemu invocation
because swtpm shuts down after use.
