FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

SRC_URI_append_df-refkit-config = "\
    file://0001-unit-service-allow-rerunning-reload-tasks.patch \
    file://0002-path-add-ReloadOnTrigger-option.patch \
"
