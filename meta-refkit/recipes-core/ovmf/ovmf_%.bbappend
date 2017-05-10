
FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

SRC_URI_append_class-target_refkit-config = " \
	file://0001-ovmf-RefkitTestCA-TEST-UEFI-SecureBoot.patch \
"
