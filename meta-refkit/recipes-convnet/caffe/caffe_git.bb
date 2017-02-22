DESCRIPTION = "Build Caffe library for CNN using OpenBLAS lib"
AUTHOR = "Alexander Leiva <norxander@gmail.com>"
SUMMARY = "Caffe : A fast open framework for deep learning"
HOMEPAGE = "http://caffe.berkeleyvision.org/"
LICENSE = "BSD"
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
    file://0001-Allow-setting-numpy-include-dir-from-outside.patch \
    file://0002-cmake-do-not-use-SYSTEM-for-non-system-include-direc.patch \
    file://0003-cmake-fix-RPATHS.patch \
    file://0004-config-use-Python-3.patch \
    file://0005-io-change-to-imageio.patch \
    file://0006-classify-demo-added-a-demo-app-for-classifying-image.patch \
"
SRCREV = "f3ba72c520165d7c403a82770370f20472685d63"

S = "${WORKDIR}/git"

FILES_${PN} += " \
    ${prefix}/python/* \
"
FILES_${PN}-dev = " \
    ${includedir} \
    ${datadir}/Caffe/*cmake \
    ${libdir}/*.so \
"

inherit cmake python-dir

# allow cmake to find native Python interpreter
#OECMAKE_FIND_ROOT_PATH_MODE_PROGRAM = "BOTH"

EXTRA_OECMAKE = " \
    -DBLAS=open \
    -DPYTHON_NUMPY_INCLUDE_DIR=${STAGING_DIR_TARGET}/usr/lib/python3.5/site-packages/numpy/core/include \
    -DPYTHON_EXECUTABLE=${STAGING_BINDIR_NATIVE}/python3-native/python3 \
    -DPYTHON_INCLUDE_DIRS=${STAGING_INCDIR_TARGET}/python3-native/python3.5m \
    -DPYTHON_LIBRARIES=${STAGING_LIBDIR_TARGET}/python3.5 \
"
