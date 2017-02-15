# From meta-clang (cb30aad4d6ff5e996f7a8c5837591071243dcd2c):
# 
# Author: Mikko Ylinen <mikko.ylinen@linux.intel.com>
# Date:   Mon Feb 13 18:06:00 2017 +0200
# 
#     clang: set target DEPENDS for gcc TOOLCHAIN
# 
#     With the layer defaults (TOOLCHAIN ??= gcc) clang for target fails
#     to build due to missing compilers in the native (recipe specific)
#     sysroot.
# 
#     Set the necessary additional DEPENDS if TOOLCHAIN = gcc to get the
#     compilers installed.
# 
#     Signed-off-by: Mikko Ylinen <mikko.ylinen@linux.intel.com>

DEPENDS_append_class-target = " clang-cross-${TARGET_ARCH} ${@bb.utils.contains('TOOLCHAIN', 'gcc', 'virtual/${TARGET_PREFIX}gcc virtual/${TARGET_PREFIX}g++', '', d)}"
