# Add missing runtime dependency to udev rule files.
RDEPENDS_${PN}-udevrules_append_class-target = " lvm2"
