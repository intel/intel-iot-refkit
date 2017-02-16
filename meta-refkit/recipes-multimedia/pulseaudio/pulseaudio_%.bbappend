DEPENDS_remove = "speexdsp gconf"
DEPENDS += "libsamplerate0"
EXTRA_OECONF += " --without-speex --disable-gconf --enable-samplerate"
