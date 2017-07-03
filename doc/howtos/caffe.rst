Using Caffe modules for deep neural networks
############################################

Refkit currently supports two ways to run Caffe models for classifying
data.

OpenCV DNN module
=================

OpenCV contrib repository has a deep neural network (DNN) module. The
module allows running Caffe modules for classifying data using OpenCV
API. This is convenient because the other image processing (loading,
resizing, conversions, etc.) can ge done using OpenCV too. `There is a
test for OpenCV DNN module in meta-iotqa
<../../meta-iotqa/lib/oeqa/runtime/multimedia/opencv/opencv_dnn_1.py>`_
that shows how to use the classifier with an ImageNet model. However,
since data is in NumPy arrays, there is no strict requirement that the
data has to be image data. OpenCV DNN module supports only a subset of
Caffe layers, but the subset is selected to contain the widely-used
layers.

Caffe framework
===============

Caffe itself is part of meta-refkit-extra layer. Documentation about
using Caffe for classifying images can be found in `computervision.rst
in meta-refkit-extra layer
<../../meta-refkit-extra/doc/computervision.rst#example-2-recognizing-objects-in-images-using-caffenet>`_.
In order to use Caffe, you have to enable the meta-refkit-extra layer:
see instructions in `the layer README <../../meta-refkit-extra/doc/README>`_.
