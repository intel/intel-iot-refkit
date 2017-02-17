var http = require('http'),
    assert = require('assert'),
    spawn = require('child_process').spawn;

var common = require('./common');
var ocfServerDir = common.ocfServerDir,
    waitChildProcess = common.waitChildProcess,
    testCaseTimeout = common.testCaseTimeout,
    requestTimeout = common.requestTimeout,
    multiReqNum = common.multiReqNum,
    options_d = common.options_d,
    options_p = common.options_p,
    options_res = common.options_res,
    sendRestRequests = common.sendRestRequests;

var childLed,
    childGas;

function sendRestRequests(options, n) {
    for (var i = 0; i < n; i++) {
        // console.log('request time ', i);
        var req = http.request(options, function(res){
            res.setEncoding('utf8');
            res.on('data', function (data) {
                // console.log('in before ', data);
            });
        });
        req.end();
    }
}

describe('Multiple OCF server case', function() {
    before(function() {
        // console.log('launch led.js...');
        childLed = spawn('node', ['led.js'], {
            cwd: ocfServerDir,
            env: process.env
        });
        // console.log('launch gas.js...');
        childGas = spawn('node', ['gas.js'], {
            cwd: ocfServerDir,
            env: process.env
        });
    });
    
    describe('Multiple devices should be found', function() {
        this.timeout(testCaseTimeout);

        before(function() {
            setTimeout(function() {
                sendRestRequests(options_d, multiReqNum);
            }, waitChildProcess);
        });

        it('multi_ocf_devices_local', function(done) {
            setTimeout(function(){

                // send HTTP request
                var req = http.request(options_d, function(res) {
                    res.setEncoding('utf8');
                    res.on('data', function (data) {
                        // console.log('in test ', data);                        
                        var devLedFound = false,
                            devGasFound = false,
                            iterTimes = 0;
                        var devices = JSON.parse(data);

                        assert.equal(2, devices.length);
                        devices.forEach(function(device, index, arrary) {
                            if (device['n'] === 'Smart Home LED') {
                                devLedFound = true;
                            }
                            if (device['n'] === 'Smart Home Gas Sensor') {
                                devGasFound = true;
                            }
                            iterTimes++;
                            if (iterTimes === arrary.length) {
                                assert(devLedFound);
                                assert(devGasFound);
                                done();
                            }
                        });
                    });
                });
                req.end();
            }, requestTimeout);
        })
    });

    describe('Multiple platforms should be found', function() {
        this.timeout(testCaseTimeout);

        before(function() {
            setTimeout(function() {
                sendRestRequests(options_p, multiReqNum);
            }, waitChildProcess);
        });

        it('multi_ocf_platforms_local', function(done) {
            setTimeout(function(){

                // send HTTP request
                var req = http.request(options_p, function(res) {
                    res.setEncoding('utf8');

                    res.on('data', function (data) {
                        // console.log('in test', data);
                        var iterTimes = 0;
                        var platforms = JSON.parse(data);

                        assert.equal(2, platforms.length);
                        platforms.forEach(function(platform, index, array) {
                            assert.equal('Intel', platform['mnmn']);
                            iterTimes++;
                            if (iterTimes === array.length) {
                                done();
                            }
                        });
                    });
                });
                req.end();
            }, requestTimeout);
        });
    });

    describe('Multiple resources should be found', function() {
        this.timeout(testCaseTimeout);

        before(function() {
            setTimeout(function() {
                sendRestRequests(options_res, multiReqNum);
            }, waitChildProcess);
        });

        it('multi_ocf_resources_local', function(done) {
            setTimeout(function(){

                // send HTTP request
                var req = http.request(options_res, function(res) {
                    res.setEncoding('utf8');
                    res.on('data', function (data) {
                        // console.log('in test ', data);
                        var ledHrefNum = 0,
                            gasHrefNum = 0,
                            iterTimes = 0;
                        var ledRt, gasRt;
                        var resources = JSON.parse(data);

                        resources.forEach(function (resource, index, arrary) {
                            if (resource.links[0]['href'] === '/a/led') {
                                ledHrefNum++;
                                ledRt = resource.links[0]['rt'];
                            }
                            if (resource.links[0]['href'] === '/a/gas') {
                                gasHrefNum++;
                                gasRt = resource.links[0]['rt'];
                            }
                            iterTimes++;
                            if (iterTimes === arrary.length) {
                                assert.equal(1, ledHrefNum);
                                assert.equal('oic.r.led', ledRt);
                                assert.equal(1, gasHrefNum);
                                assert.equal('oic.r.sensor.carbondioxide', gasRt);
                                done();
                            }               
                        });
                    });
                });
                req.end();
            }, requestTimeout);
        });
    });

    after(function() {
        // console.log('killing led.js...');
        childLed.kill('SIGINT');
        // console.log('killing gas.js...');
        childGas.kill('SIGINT');
    });
});