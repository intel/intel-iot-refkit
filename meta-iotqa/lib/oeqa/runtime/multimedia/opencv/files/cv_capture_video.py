import cv2 as cv
import sys

arg = sys.argv[1]
vc = cv.VideoCapture(int(arg))

if vc.isOpened():
   rval, frame = vc.read()
else:
   rval = False

if rval != False:
   rval, frame = vc.read()
   cv.imwrite('/tmp/capture_ouput.jpg', frame)
