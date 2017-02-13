GCC_TOOLCHAIN = "virtual/${TARGET_PREFIX}gcc virtual/${TARGET_PREFIX}g++"
DEPENDS_append_class-target = " ${@bb.utils.contains('TOOLCHAIN', 'gcc','${GCC_TOOLCHAIN}','',d)}"
