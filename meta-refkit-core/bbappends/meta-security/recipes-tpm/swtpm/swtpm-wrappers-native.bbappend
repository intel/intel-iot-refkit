# Temporary workaround (needs to be fixed in meta-security once the
# necessary patch "net-tools: enable native and nativesdk variant"
# is in OE-core): swtpm_setup.sh needs netstat command.
DEPENDS_append_df-refkit-config = " net-tools-native"
