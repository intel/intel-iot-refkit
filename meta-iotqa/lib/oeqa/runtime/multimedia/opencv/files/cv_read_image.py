'''
This test case tests that OpenCV python interface
can read image from file system using the 
funtions from the OpenCV HighGUI component. 
'''
import os
import cv2 as cv

file = '/tmp/pic5.png' 
if not os.path.exists(file):
    raise Exception('OpenCV: Failed to find image file (%s).' % file)

img = cv.imread(file)
cv.imwrite('/tmp/read_output.png', img)
