# Copyright (C) 2017 Ismo Puustinen <ismo.puustinen@intel.com>
# Released under the MIT license (see COPYING.MIT for the terms)

DESCRIPTION = "Download the BVLC reference network as test data."
HOMEPAGE = "https://github.com/BVLC/caffe/tree/master/models/bvlc_reference_caffenet"
LICENSE = "BVLC-model-license & CC-BY-2.5 & BSD-3-Clause"
SECTION = "tests"
DEPENDS = ""

# Image by Lilly M #
# (https://en.wikipedia.org/wiki/Saluki#/media/File:Chart_perski_0002.jpg)
# using CC BY 2.5 license (https://creativecommons.org/licenses/by/2.5/)
LIC_FILES_CHKSUM = " \
    file://${COMMON_LICENSE_DIR}/CC-BY-SA-3.0;md5=3248afbd148270ac7337a6f3e2558be5 \
    file://${WORKDIR}/LICENSE;md5=650b869bd8ff2aed59c62bad2a22a821 \
"

SRC_URI = " \
    http://dl.caffe.berkeleyvision.org/caffe_ilsvrc12.tar.gz;name=ilsvrc12 \
    http://dl.caffe.berkeleyvision.org/bvlc_reference_caffenet.caffemodel;name=caffenet \
    https://raw.githubusercontent.com/BVLC/caffe/f16b5f2eb96cbb97d9a4b2b7312a23cb16f43dac/models/bvlc_reference_caffenet/deploy.prototxt;name=deploy \
    https://upload.wikimedia.org/wikipedia/commons/2/27/Chart_perski_0002.jpg;downloadfilename=dog.jpg;name=dog \
    https://raw.githubusercontent.com/opencv/opencv_contrib/009d2efb75fbb0eded127864cb1ca932d58d1738/LICENSE;name=bsd3 \
    file://dnn-test.py \
    file://change_input_format.patch \
"

SRC_URI[ilsvrc12.md5sum] = "f963098ea0e785a968ca1eb634003a90"
SRC_URI[ilsvrc12.sha256sum] = "e35c0c1994a21f7d8ed49d01881ce17ab766743d3b0372cdc0183ff4d0dfc491"

SRC_URI[caffenet.md5sum] = "af678f0bd3cdd2437e35679d88665170"
SRC_URI[caffenet.sha256sum] = "472d4a06035497b180636d8a82667129960371375bd10fcb6df5c6c7631f25e0"

SRC_URI[deploy.md5sum] = "955051d11e44bd29dd87a25dd766ec23"
SRC_URI[deploy.sha256sum] = "922248a4d2f6aac1cc8e7e5dbd996cc2ecd3356480d67c198f6cf96b12311a04"

SRC_URI[dog.md5sum] = "76efa2a64d2c78078166f8f4ff375682"
SRC_URI[dog.sha256sum] = "f163822499bdd03a3bf4d3cb437d52ab5082d51edbcb7c98f1c42101d6358c70"

SRC_URI[bsd3.md5sum] = "650b869bd8ff2aed59c62bad2a22a821"
SRC_URI[bsd3.sha256sum] = "7c34d28e784b202aa4998f477fd0aa9773146952d7f6fa5971369fcdda59cf48"

do_patch_prepend() {
    bb.utils.movefile(os.path.join(d.getVar("WORKDIR"), "deploy.prototxt"), d.getVar("S"))
}

do_install() {
    install -d ${D}${datadir}/Caffe/models/bvlc_reference_caffenet/
    install -d ${D}${datadir}/Caffe/data/ilsvrc12
    install -d ${D}${bindir}

    install ${WORKDIR}/synset_words.txt ${D}${datadir}/Caffe/data/ilsvrc12
    install ${WORKDIR}/bvlc_reference_caffenet.caffemodel ${D}${datadir}/Caffe/models/bvlc_reference_caffenet/
    install ${S}/deploy.prototxt ${D}${datadir}/Caffe/data/
    install ${WORKDIR}/dog.jpg ${D}${datadir}/Caffe/data/
    install -m 755 ${WORKDIR}/dnn-test.py ${D}${bindir}
}

FILES_${PN} += "${datadir}/Caffe/*"

