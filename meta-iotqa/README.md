# meta-iotqa
Layer for IoT Reference OS Kit QA components.
This layer is originally from https://github.com/ostroproject/meta-iotqa

## Building tests with docker

Follow the guide on
[building with docker](https://github.com/intel/intel-iot-refkit#building-with-docker)
and after running `$ docker/local-build.sh` you should have the test files built.

## Building tests without docker

Follow the guide on
[building without docker](https://github.com/intel/intel-iot-refkit#building-without-docker)
and before building an image add `INHERIT += "test-iot"` to `conf/local.conf`.

Then build the image with `do_test_iot_export` task eg.:
```
$ bitbake refkit-image-common -c do_test_iot_export
```

If the task fails, you may need to use `cleanall` task for the image and then
try again:
```
$ bitbake -c cleanall refkit-image-common
```

## Setting up environment for running tests

1. Host: Ubuntu 14.04 is tested and recommended. Install expect as some tests
might require it: `$ sudo apt-get install expect`

2. Boot and install the image to target device

3. Target device should be remote accessible with ssh from Host machine

## Running tests

After building the tests you can find the test files from
`intel-iot-refkit/build/tmp-glibc/deploy/testsuite/refkit-image-<profile>/`.
Extracting the the test files can be done with:
```
$ tar xf iot-testsuite.tar.gz
$ tar xf iot-testfiles.intel-corei7.tar.gz -C iottest/
```

Running the tests:
```
$ cd iottest
$ python runtest.py -f testplan/<manifest> -m <target machine> -t <target IP>[:<port number>] -s <host IP>
```

For example:
```
$ python runtest.py -f testplan/image-testplan.manifest -m intel-corei7-64  -t 192.168.7.2 -s 192.168.7.1
```
