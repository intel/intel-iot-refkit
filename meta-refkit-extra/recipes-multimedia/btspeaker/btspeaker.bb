SUMMARY = "Bluetooth speaker"
DESCRIPTION = "This recipe configures refkit gateway image into a stand alone bluetooth speaker"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${META_REFKIT_BASE}/COPYING.MIT;md5=838c366f69b72c5df05c96dff79b35f2"

SRC_URI = "\
        file://btspeaker.py \
        file://btspeaker.service \
        file://client.conf \
        file://leds.rules \
        file://btspeaker-bluetooth.conf \
        file://btspeaker-connman.conf \
        file://pulseaudio-bluetooth.conf \
        file://audio.conf \
        file://btpairing.wav \
        file://btstartup.wav \
        file://btsuccess.wav \
"

RDEPENDS_${PN} = "\
        python-dbus \
        python-pygobject \
        python-pyalsaaudio\
        python-evdev \
"

inherit useradd systemd

USERADD_PACKAGES = "${PN}"
GROUPADD_PARAM_${PN} = "-g 1100 -r leds"
USERADD_PARAM_${PN} = "-u 1200 -d /home/btspeaker -r -s /bin/sh -G audio,leds,input btspeaker"
SYSTEMD_SERVICE_${PN} = "btspeaker.service"

do_install () {
        install -d -m 755 ${D}/home/btspeaker
        install -d -m 755 ${D}/home/btspeaker/.pulse
        install -d -m 755 ${D}${sysconfdir}/udev/rules.d/
        install -d -m 755 ${D}${sysconfdir}/dbus-1/system.d/
        install -d -m 755 ${D}${sysconfdir}/bluetooth/
        install -d -m 755 ${D}${systemd_system_unitdir}

        install -p -m 644 ${WORKDIR}/btspeaker.py ${D}/home/btspeaker/
        install -p -m 644 ${WORKDIR}/btpairing.wav ${D}/home/btspeaker/
        install -p -m 644 ${WORKDIR}/btstartup.wav ${D}/home/btspeaker/
        install -p -m 644 ${WORKDIR}/btsuccess.wav ${D}/home/btspeaker/
        install -p -m 644 ${WORKDIR}/client.conf ${D}/home/btspeaker/.pulse
        install -p -m 644 ${WORKDIR}/leds.rules ${D}${sysconfdir}/udev/rules.d/
        install -p -m 644 ${WORKDIR}/btspeaker-bluetooth.conf ${D}${sysconfdir}/dbus-1/system.d/
        install -p -m 644 ${WORKDIR}/btspeaker-connman.conf ${D}${sysconfdir}/dbus-1/system.d/
        install -p -m 644 ${WORKDIR}/pulseaudio-bluetooth.conf ${D}${sysconfdir}/dbus-1/system.d/
        install -p -m 644 ${WORKDIR}/audio.conf ${D}${sysconfdir}/bluetooth/

        install -p -m 644 ${WORKDIR}/btspeaker.service ${D}${systemd_system_unitdir}

        chown -R btspeaker ${D}/home/btspeaker
}

FILES_${PN} = " \
        /home/btspeaker/btspeaker.py \
        /home/btspeaker/btpairing.wav \
        /home/btspeaker/btstartup.wav \
        /home/btspeaker/btsuccess.wav \
        /home/btspeaker/.pulse/client.conf \
        ${sysconfdir}/udev/rules.d/leds.rules \
        ${sysconfdir}/dbus-1/system.d/btspeaker-bluetooth.conf \
        ${sysconfdir}/dbus-1/system.d/btspeaker-connman.conf \
        ${sysconfdir}/dbus-1/system.d/pulseaudio-bluetooth.conf \
        ${sysconfdir}/bluetooth/audio.conf \
        ${systemd_system_unitdir}/btspeaker.service \
"
