Introduction
============

Rock Paper Scissors - demo (rps-demo) is a computer vision demo of the classic Rock Paper Scissors game. The demo uses a
Realsense camera to get video from the players hand and then uses trained Haar Cascade Classifiers to recognize player selections.

Prerequisites
=============

1. You need a working Realsense camera to play the demo. This demo was validated using the Realsense 3D Camera R200 but other Realsense
cameras should work too. This is a graphical demo with a GUI so you need to have a graphical screen such as a monitor.

2. First initialize the bitbake environment by running:

    source oe-init-build-env

3. Enable the refkit-extra layer by running the following command in the "build" folder:

    bitbake-layers add-layer ../meta-refkit-extra

4. In "conf/local.conf" you need to ADD the following lines to include the rps-demo in the image and to enable x11:

    require conf/distro/include/refkit-core-x11.inc
    require conf/distro/include/refkit-extra.conf
    REFKIT_IMAGE_EXTRA_INSTALL_append = " rps-demo"

5. The demo uses GTK, which is disabled by default, so you need to enable it by COMMENTING the following line in the "meta-refkit-core/conf/distro/include/refkit-config.inc"

    PACKAGECONFIG_remove_pn-opencv_df-refkit-config = "gtk"

6. Now build the refkit-image-computervision after making the modifications listed above.

    bitbake refkit-image-computervision

7. Finally flash the image containing the demo to the device such as Minnowboard and connect the required peripheral devices (mouse, keyboard, Realsense camera, monitor) to the DUT.

8. Boot the image and run "startx" in the terminal to start the graphical interface.


Running the demo
=============

First make sure you have the Realsense camera connected to the device, otherwise running the demo will throw an error.

1. To launch the demo open terminal and run the following command (the demo binary is installed in the /bin folder by default):

    rps-demo

(You might have to position the window with your mouse and left click to place it.)

2. To start the game click "Start game" - button. This starts the camera and opens up the game screen.

3. Press "Play" to start a round of Rock Paper Scissors. When the "Play" - button is pressed, a timer (Rock - Paper - Scissors) will start. When the "Scissors" text is shown in the screen,
keep your hand in front of the camera for couple of seconds. Note, that the classifier is not very accurate due to insufficient amount of training data. The classifier works best when the players
hand is placed in the middle of the camera frame approximately 30-50cm away from the camera.
