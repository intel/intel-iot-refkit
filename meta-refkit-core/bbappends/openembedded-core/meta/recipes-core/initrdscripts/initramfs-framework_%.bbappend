# Refkit has its own installer image and doesn't use initramfs-module-install-efi
# or initramfs-module-setup-live.
#
# We cannot disable them easily (no PACKAGECONFIG), so here we merely
# override the dependencies and ignore the resulting broken packages.
#
# Ideally these modules shouldn't even be part of the base initramfs-module (see
# "Re: [OE-core] [PATCH 2/3] initramfs-framework: include install-efi module in recipe for installation" and
# "Re: [OE-core] [PATCH v6 1/1] initramfs-framework: module to support boot live image").
RDEPENDS_initramfs-module-install-efi_df-refkit-config = ""
RDEPENDS_initramfs-module-setup-live_df-refkit-config = ""
