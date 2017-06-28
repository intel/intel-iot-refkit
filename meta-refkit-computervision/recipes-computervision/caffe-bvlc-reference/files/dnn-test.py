#!/usr/bin/env python3

# Classify an image using a suitable model. The image conversion magic
# is from
# https://github.com/opencv/opencv_contrib/blob/master/modules/dnn/samples/googlenet_python.py
# (3-clause BSD license).

import numpy as np
import cv2
import sys

if len(sys.argv) != 4:
    print("Usage: dnn.py <prototxt> <caffemodel> <image>")
    sys.exit(1)

cv2.ocl.setUseOpenCL(False)

# read the image
test_img = cv2.imread(sys.argv[3])

# resize
resized = cv2.resize(test_img, (224,224))
converted = np.moveaxis(resized, 2, 0)
data = np.reshape(converted.astype(np.float32), (-1, 3, 224, 224))

# initialize network
net = cv2.dnn.readNetFromCaffe(sys.argv[1], sys.argv[2])
net.setBlob(".data", data)

# run the network
net.forward()

# print the class
print(str(net.getBlob("prob").argmax()))
