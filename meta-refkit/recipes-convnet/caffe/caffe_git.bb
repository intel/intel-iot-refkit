DESCRIPTION = "Build Caffe library for CNN using OpenBLAS lib"
AUTHOR = "Alexander Leiva <norxander@gmail.com>"
SUMMARY = "Caffe : A fast open framework for deep learning"
HOMEPAGE = "http://caffe.berkeleyvision.org/"
LICENSE = "BSD & BVLC-model-license"
PRIORITY= "optional"
SECTION = "libs"
PR = "r0"

DEPENDS = " \
    boost \
    openblas \
    protobuf-native \
    protobuf \
    glog \
    gflags \
    hdf5 \
    opencv \
    lmdb \
    snappy \
    leveldb \
    viennacl \
    ocl-icd \
    python3 \
    python3-native \
    python3-numpy-native \
"

inherit python3native

RDEPENDS_${PN} = "python3-numpy python3-imageio python3-six python3-protobuf"

LIC_FILES_CHKSUM = "file://LICENSE;md5=91d560803ea3d191c457b12834553991"

SRC_URI = " \
    git://github.com/BVLC/caffe.git;branch=opencl \
    http://dl.caffe.berkeleyvision.org/caffe_ilsvrc12.tar.gz;name=ilsvrc12 \
    http://dl.caffe.berkeleyvision.org/bvlc_reference_caffenet.caffemodel;name=caffenet \
    file://0001-Allow-setting-numpy-include-dir-from-outside.patch \
    file://0002-cmake-do-not-use-SYSTEM-for-non-system-include-direc.patch \
    file://0003-cmake-fix-RPATHS.patch \
    file://0004-config-use-Python-3.patch \
    file://0005-io-change-to-imageio.patch \
    file://0006-classify-demo-added-a-demo-app-for-classifying-image.patch \
"
SRCREV = "f3ba72c520165d7c403a82770370f20472685d63"

SRC_URI[ilsvrc12.md5sum] = "f963098ea0e785a968ca1eb634003a90"
SRC_URI[ilsvrc12.sha256sum] = "e35c0c1994a21f7d8ed49d01881ce17ab766743d3b0372cdc0183ff4d0dfc491"

SRC_URI[caffenet.md5sum] = "af678f0bd3cdd2437e35679d88665170"
SRC_URI[caffenet.sha256sum] = "472d4a06035497b180636d8a82667129960371375bd10fcb6df5c6c7631f25e0"

S = "${WORKDIR}/git"

PACKAGES += "${PN}-imagenet-model"

RDEPENDS_${PN}-imagenet-model = "${PN}"

do_install_append() {
    install -d ${D}${datadir}/Caffe/models/bvlc_reference_caffenet/
    install -d ${D}${datadir}/Caffe/data/ilsvrc12

    install ${S}/models/bvlc_reference_caffenet/* ${D}${datadir}/Caffe/models/bvlc_reference_caffenet/
    install ${WORKDIR}/synset_words.txt ${D}${datadir}/Caffe/data/ilsvrc12
    install ${WORKDIR}/bvlc_reference_caffenet.caffemodel ${D}${datadir}/Caffe/models/bvlc_reference_caffenet/

    # ilsvrc_2012_mean.npy is already installed at /usr/python/caffe/imagenet/ilsvrc_2012_mean.npy
}

FILES_${PN}-imagenet-model += " \
    ${datadir}/Caffe/models/bvlc_reference_caffenet/* \
    ${datadir}/Caffe/data/ilsvrc12/* \
"
FILES_${PN} += " \
    ${prefix}/python/* \
"
FILES_${PN}-dev = " \
    ${includedir} \
    ${datadir}/Caffe/*cmake \
    ${libdir}/*.so \
"

inherit cmake python-dir

EXTRA_OECMAKE = " \
    -DBLAS=open \
    -DPYTHON_NUMPY_INCLUDE_DIR=${STAGING_DIR_TARGET}/usr/lib/python3.5/site-packages/numpy/core/include \
    -DPYTHON_EXECUTABLE=${STAGING_BINDIR_NATIVE}/python3-native/python3 \
    -DPYTHON_INCLUDE_DIRS=${STAGING_INCDIR_TARGET}/python3-native/python3.5m \
    -DPYTHON_LIBRARIES=${STAGING_LIBDIR_TARGET}/python3.5 \
"

