# remove readline dependency from nftables
DEPENDS_remove_refkit-config = "readline"
EXTRA_OECONF_append_refkit-config = " --without-cli"

# make nftables require a settings package
VIRTUAL-RUNTIME_nftables-settings ?= "nftables-settings-default"
RDEPENDS_nftables_append_refkit-config = " ${VIRTUAL-RUNTIME_nftables-settings}"
