SUMMARY = "fwupd demo firmware data"
DESCRIPTION = "This demonstrates how to package firmware so that it \
can be delivered via the normal system update. It uses \
the firmware for the Logitech Unifying Receiver as example \
and thus can be used to update real devices. \
However, the vendor only granted permission to distribute the \
.cab file to the Linux Vendor Firmware Service and thus \
this example can only be used in local builds where the result \
does not get re-distributed."
HOMEPAGE = "https://github.com/hughsie/fwupd/tree/master/plugins/unifying"
LICENSE = "CLOSED"
DEPENDS = "gcab-native"

inherit allarch

# We include firmware for two different device flavors and two versions.
# This allows testing both updates and downgrades.
SRC_URI = " \
    file://metadata.xml \
    file://demo.conf \
    https://fwupd.org/downloads/6e5ab5961ec4c577bff198ebb465106e979cf686-Logitech-Unifying-RQR12.05_B0028.cab;name=RQR12.05 \
    https://fwupd.org/downloads/938fec082652c603a1cdafde7cd25d76baadc70d-Logitech-Unifying-RQR12.07_B0029.cab;name=RQR12.07 \
    https://fwupd.org/downloads/82b90b2614a9a4d0aced1ab8a4a99e228c95585c-Logitech-Unifying-RQ024.03_B0027.cab;name=RQR24.03 \
    https://fwupd.org/downloads/4511b9b0d123bdbe8a2007233318ab215a59dfe6-Logitech-Unifying-RQR24.05_B0029.cab;name=RQR24.05 \
"
SRC_URI[RQR12.05.sha256sum] = "f38cd350c8557db834f6208a006040c66772e514808fcbd5daf27397eafb4f78"
SRC_URI[RQR12.07.sha256sum] = "6c2d1b06d4cdafc0f5f9c03f06e0fe094209b277a38ed4011f2af533e7c047f8"
SRC_URI[RQR24.03.sha256sum] = "e55f7f6a9524652a17c7763e817dac05944957cef45ff1b54f964b693c5f17fb"
SRC_URI[RQR24.05.sha256sum] = "1313be32515f52df37c641a928f232f921e641472e8d08c78a0e9cef8e73c2d8"

python do_compile () {
    import glob
    import hashlib
    import subprocess
    import tempfile

    workdir = d.getVar('WORKDIR')

    # Remove GPG signature. We trust that the content gets delivered unmodified
    # and having the signature would force us to install GnuPG, because fwupd
    # always invokes it when it sees a signature.
    metadata = open(os.path.join(workdir, 'metadata.xml')).read()
    for cab in glob.glob(os.path.join(workdir, '*.cab')):
        with tempfile.TemporaryDirectory() as tmpdir:
            subprocess.check_output(['gcab', '--extract', cab],
                                    cwd=tmpdir, stderr=subprocess.STDOUT)
            signatures = glob.glob(os.path.join(tmpdir, '*.asc'))
            stripped = cab + '.stripped'
            if os.path.exists(stripped):
                os.unlink(stripped)
            if signatures:
                for i in signatures:
                    os.unlink(i)
                subprocess.check_output(['gcab', '--create', stripped] + os.listdir(tmpdir),
                                        cwd=tmpdir, stderr=subprocess.STDOUT)
                # We consider hash collisions unlikely and just search/replace
                # the hash string in the entire XML document after modifying the cab.
                oldhash = hashlib.sha1(open(cab, 'rb').read()).hexdigest()
                newhash = hashlib.sha1(open(stripped, 'rb').read()).hexdigest()
                metadata = metadata.replace(oldhash, newhash)
            else:
                os.link(cab, stripped)
    open(os.path.join(workdir, 'metadata.xml.stripped'), 'w').write(metadata)
}

do_install () {
    install -d ${D}${sysconfdir}/fwupd/remotes.d
    install ${WORKDIR}/demo.conf ${D}${sysconfdir}/fwupd/remotes.d/
    install -d ${D}${datadir}/fwupd/remotes.d/demo/firmware
    for i in ${WORKDIR}/*.cab.stripped; do
        install $i ${D}${datadir}/fwupd/remotes.d/demo/firmware/`basename $i .stripped`
    done
    install -d ${D}${datadir}/fwupd/remotes.d/demo/
    gzip -c ${WORKDIR}/metadata.xml.stripped >${D}${datadir}/fwupd/remotes.d/demo/demo.xml.gz
}

FILES_${PN} += " \
    ${datadir}/fwupd/ \
"
