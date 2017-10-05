# Recipe for compiling beignet for Intel HD Graphics 500

require beignet.inc

EXTRA_OECMAKE_append = " -DGEN_PCI_ID=0x5A85"
