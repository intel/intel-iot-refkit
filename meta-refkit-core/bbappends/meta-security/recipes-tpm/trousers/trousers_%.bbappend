# The upstream recipe does not start tcsd automatically, but we
# want that because the installer image calls the TPM tools
# without starting tcsd first (it shouldn't have to!), and
# without tcsd already running, the tools just fail. A better
# solution would be socket-activation, but tcsd does not support
# that. Does not matter, tcsd is only installed when needed.
SYSTEMD_AUTO_ENABLE_refkit-config = "enable"
