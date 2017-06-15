# remove readline dependency from nftables
DEPENDS_remove_df-refkit-config = "readline"
EXTRA_OECONF_append_df-refkit-config = " --without-cli"

# make nftables require a settings package
VIRTUAL-RUNTIME_nftables-settings ?= "nftables-settings-default"
RDEPENDS_nftables_append_df-refkit-config = " ${VIRTUAL-RUNTIME_nftables-settings}"
