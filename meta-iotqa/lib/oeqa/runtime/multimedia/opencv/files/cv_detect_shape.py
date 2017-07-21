'''
This test case tests that OpenCV python interface
can detect triangle shape from an image using the 
funtions from the OpenCV CV component. 
'''
import os
import cv2 as cv
import numpy as np

file = '/tmp/pic5.png' 
if not os.path.exists(file):
    raise Exception('OpenCV: Failed to find image file (%s).' % file)

img = cv.imread(file)
gray = cv.cvtColor(img, cv.COLOR_BGR2GRAY)
thresh = cv.adaptiveThreshold(gray, 255, cv.ADAPTIVE_THRESH_MEAN_C, cv.THRESH_BINARY, 3, 5)
_, contours, hierarchy = cv.findContours(thresh, cv.RETR_LIST, cv.CHAIN_APPROX_SIMPLE)

triangles = []
for cnt in contours:
    approx = cv.approxPolyDP(cnt, 0.01*cv.arcLength(cnt,True),True)
    if len(approx) == 3:
        triangles.append(approx)

print('number of triangles: ', len(triangles))
if len(triangles) < 1:
    raise Exception('OpenCV: Failed to find any triangle in the picture')
