Setting up computer vision demos
################################

Introduction
============

This layer contains components such as Caffe deep learning framework and
Python bindings to librealsense (pyrealsense). The components are
scriptable with Python 3, making it relatively easy to construct complex
computer vision demos using only Python.

Example 1: measuring distance to cats
=====================================

This is an example how the bindings can be used for measuring distance to cats
using a RealSense camera for taking pictures and distance calculations. OpenCV
does the cat recognition with a pre-configured classifier. You need to
have packages ``python3-pyrealsense`` and ``opencv`` installed and
Intel RealSense R200 camera connected to your device.

.. code:: python

   #!/usr/bin/python3
   
   import sys
   
   import numpy as np
   import cv2
   import pyrealsense as pyrs
   
   n_devices = pyrs.start()
   
   if n_devices == 0:
       print("No RealSense devices found!")
       sys.exit(1)
   
   cam = pyrs.Device()
   
   cat_cascade = cv2.CascadeClassifier("/usr/share/OpenCV/haarcascades/haarcascade_frontalcatface.xml")
   
   for x in range(30):
       # stabilize exposure
       cam.wait_for_frame()
   
   while True:
       # get image from web cam
       cam.wait_for_frame()
       img = cam.colour
   
       cats = cat_cascade.detectMultiScale(img)
   
       for (x,y,w,h) in cats:
           # find center
           cx = x+(w/2)
           cy = y+(h/2)
       
           depth = cam.depth[cy][cx]
    
           print("Cat found, distance " + str(depth/10.0) + " cm")

Example 2: recognizing objects in images using Caffenet
=======================================================

Install ``caffe-imagenet-model`` package. Then run ``classify-demo.py
--mean_file=""`` in Caffe's Python directory (``/usr/python``) for an
interactive demo recognizing images in web camera stream. You need to
have a web camera connected. Point the web camera at things and in the
console you will see what the image classifier considers them to be. The
deep neural network which the example uses is Caffenet, which is trained
using the 1.3 million image ImageNet training set.
