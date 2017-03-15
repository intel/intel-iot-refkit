# meta-iotqa
Layer for IoT Reference OS Kit QA components.
This layer is originally from https://github.com/ostroproject/meta-iotqa

## Building tests with docker

Follow the guide on [building with docker](https://github.com/intel/intel-iot-refkit#building-with-docker) and after running `$ docker/local-build.sh` you should have the test files built.

## Building tests without docker

Follow the guide on [building without docker](https://github.com/intel/intel-iot-refkit#building-without-docker) and before building an image add 'INHERIT += "test-iot"' to local.conf:
```
echo 'INHERIT += "test-iot"' >> conf/local.conf
```
Then build the image with 'do_test_iot_export' task eg.:
```
bitbake refkit-image-common:do_test_iot_export
```

## Setting up environment for running tests

1. Host: Ubuntu 14.04 is tested and recommended. Install expect as some tests might require it: `$ sudo apt-get install expect`

2. Boot and install the image to target device

3. Target device should be remote accessible with ssh from Host machine

## Running tests

After building the tests you can find the test files from intel-iot-refkit/build/tmp-glibc/deploy/testsuite/refkit-image-<profile>/.
Extracting the the test files can be done with:
```
$ tar xvf iot-testsuite.tar.gz`
$ tar xvf iot-testfiles.xxx.tar.gz -C iottest/
```

Running the tests:
```
$ cd iottest
$ python runtest.py -f testplan/xxx.manifest -m <target machine> -t <target IP>[:<port number>] -s <host IP>
```

For example:
```
$ python runtest.py -f testplan/image-testplan.manifest -m intel-corei7-64  -t 192.168.7.2 -s 192.168.7.1
```
