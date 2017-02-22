SUMMARY = "Minimal caffe requirements"
DESCRIPTION = "The minimal set of packages required to build the caffe library"
LICENSE = "MIT"
PR = "r0"

inherit packagegroup

RDEPENDS_${PN} = "\
			openssl			\
			openssl-dev		\
			libffi			\
			libffi-dev		\
			libxslt			\
			libxslt-dev		\
			libxml2			\
			libxml2-dev		\
			glog 			\
			glog-dev 		\
			gflags 			\
			gflags-dev		\
			leveldb 		\
			leveldb-dev 		\
			snappy 			\
			snappy-dev 		\
			lmdb			\
			lmdb-dev		\
			jpeg			\
			jpeg-dev		\
			hdf5			\
			hdf5-dev		\
			boost			\
			boost-dev		\
			protobuf		\
			protobuf-dev		\
			python-pip		\
			python-numpy		\
			opencv			\
			opencv-dev		\
			opencv-apps		\
			openblas		\
			openblas-dev		\
			gstreamer1.0		\
			gstreamer1.0-dev	\
			"

