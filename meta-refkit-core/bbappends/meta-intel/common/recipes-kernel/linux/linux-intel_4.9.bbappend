# snd-soc-skl module init fails with an error:
#
#    snd_soc_skl 0000:00:0e.0: ipc: set large config fail, err: -110
#
# but the module remains loaded. An alternative driver 'snd-hda-intel'
# is also loaded but snd-soc-skl is "used".
#
# The end result is soundcards are missing (due to the failure)
# on, e.g., Intel 570x/Joule.
#
# As snd-soc-skl is known to be problematic, let's blacklist that
#and prefer snd-hda-intel to get audio working.
#
# Submitted to meta-intel.
KERNEL_MODULE_PROBECONF_df-refkit-config += "snd-soc-skl"
module_conf_snd-soc-skl_df-refkit-config = "blacklist snd-soc-skl"
