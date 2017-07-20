import os
import cv2 as cv

file = '/tmp/pic5.png' 
if not os.path.exists(file):
    raise Exception('OpenCV: Failed to find image file (%s).' % file)

img = cv.imread(file)
gray_img = cv.cvtColor(img, cv.COLOR_BGR2GRAY)
blur_img = cv.GaussianBlur(gray_img, (3,3), 0)
threshold_img = cv.adaptiveThreshold(blur_img, 255, cv.ADAPTIVE_THRESH_MEAN_C, cv.THRESH_BINARY, 3, 5)
cv.imwrite('/tmp/process_output.png', threshold_img)
