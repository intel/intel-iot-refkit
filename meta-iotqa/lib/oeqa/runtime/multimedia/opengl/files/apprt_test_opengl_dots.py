from OpenGL.GL import *
from OpenGL.GLUT import *
from OpenGL.GLU import *

import time

def initFun():
    glClearColor(1.0,1.0,1.0,0.0)
    glColor3f(0.0,0.0, 0.0)
    glPointSize(4.0)
    glMatrixMode(GL_PROJECTION)
    glLoadIdentity()
    gluOrtho2D(0.0,640.0,0.0,480.0)
    

def displayFun():
    glClear(GL_COLOR_BUFFER_BIT)
    glBegin(GL_POINTS)
    glVertex2i(100,50)
    glVertex2i(100,130)
    glVertex2i(150,130)
    glEnd()
    glFlush()

def main():
    glutInit()
    glutInitWindowSize(640,480)
    glutCreateWindow("Drawdots")
    glutInitDisplayMode(GLUT_SINGLE | GLUT_RGB)
    glutDisplayFunc(displayFun)
    initFun()
    glutMainLoopEvent()
    time.sleep(5)

if __name__ == '__main__':main()
