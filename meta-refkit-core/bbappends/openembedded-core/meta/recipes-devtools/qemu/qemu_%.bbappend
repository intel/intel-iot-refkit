FILESEXTRAPATHS_prepend := "${THISDIR}/qemu:"

# Replace CUSE backend with socket backend.
SRC_URI_remove_df-refkit-config = " \
    file://0001-Provide-support-for-the-CUSE-TPM.patch \
    file://0002-Introduce-condition-to-notify-waiters-of-completed-c.patch \
    file://0003-Introduce-condition-in-TPM-backend-for-notification.patch \
    file://0004-Add-support-for-VM-suspend-resume-for-TPM-TIS-v2.9.patch \
"
SRC_URI_append_df-refkit-config = " \
    file://0001-tpm-Clean-up-driver-registration-lookup.patch \
    file://0002-tpm-Clean-up-model-registration-lookup.patch \
    file://0003-tpm-backend-Remove-unneeded-member-variable-from-bac.patch \
    file://0004-tpm-backend-Move-thread-handling-inside-TPMBackend.patch \
    file://0005-tpm-backend-Initialize-and-free-data-members-in-it-s.patch \
    file://0006-tpm-backend-Made-few-interface-methods-optional.patch \
    file://0007-tpm-backend-Add-new-api-to-read-backend-TpmInfo.patch \
    file://0008-tpm-backend-Move-realloc_buffer-implementation-to-tp.patch \
    file://0009-tpm-passthrough-move-reusable-code-to-utils.patch \
    file://0010-tpm-Added-support-for-TPM-emulator.patch \
    file://0011-tpm-Move-tpm_cleanup-to-right-place.patch \
    file://0012-tpm-Use-EMSGSIZE-instead-of-EBADMSG-to-compile-on-Op.patch \
    file://chardev-connect-socket-to-a-spawned-command.patch \
"
