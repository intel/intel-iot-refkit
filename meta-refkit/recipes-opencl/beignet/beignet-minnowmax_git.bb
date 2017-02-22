# Recipe for compiling beignet for Minnowboard Max

require beignet.inc

EXTRA_OECMAKE_append = " -DGEN_PCI_ID=0x0F31"
