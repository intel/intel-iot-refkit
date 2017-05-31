# Recipe for compiling beignet for Intel 550x

require beignet.inc

EXTRA_OECMAKE_append = " -DGEN_PCI_ID=0x1A85"
