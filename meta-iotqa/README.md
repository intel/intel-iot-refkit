# meta-iotqa
Layer for IoT Reference OS Kit QA components.
This layer is originally from https://github.com/ostroproject/meta-iotqa

Setup environment
=================
1. Host: Ubuntu 14.04 is tested and recommended.

  Install expect:  ``$ sudo apt-get install expect``

2. Boot and install the image to target device

3. Target device should be remote accessible with ssh from Host machine

Run test
=========
1. Building testsuite and tests:

 - To get tests for an image, use ``-c do_test_iot_export`` when building the image:
    ``$ bitbake <image> -c do_test_iot_export``

 - To untar the tests and testsuite run:
    ``$ tar xvf iot-testsuite.tar.gz``
    ``$ tar xvf iot-testfiles.xxx.tar.gz -C iottest/``

2. Run automated test:
     ``$ cd iottest``

     ``$ python  runtest.py -f testplan/xxx.manifest -m  [ target machine ]  -t [ target IP ] -s [ host IP ]``
