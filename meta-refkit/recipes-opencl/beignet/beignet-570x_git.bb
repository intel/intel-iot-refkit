# Recipe for compiling beignet for Intel 570x

require beignet.inc

EXTRA_OECMAKE_append = " -DGEN_PCI_ID=0x1A84"
