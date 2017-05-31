SUMMARY = "IoT Reference OS Kit Bluetooth Audio"
LICENSE = "MIT"

inherit packagegroup

RDEPENDS_${PN} = " \
    pulseaudio \
    pulseaudio-server \
    pulseaudio-misc \
    pulseaudio-module-loopback \
    pulseaudio-module-bluetooth-discover \
    pulseaudio-module-bluetooth-policy \
    pulseaudio-module-bluez5-device \
    pulseaudio-module-bluez5-discover \
    sbc \
"
