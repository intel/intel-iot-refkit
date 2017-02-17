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

var child;

describe('One OCF server case', function() {
    before(function() {
        // console.log('launch led.js...');
        child = spawn('node', ['led.js'], {
            cwd: ocfServerDir,
            env: process.env
        });        
    });

    describe('Only one LED device should be found', function() {
        this.timeout(testCaseTimeout);

        before(function() {
            setTimeout(function() {
                sendRestRequests(options_d, multiReqNum);
            }, waitChildProcess);
        });

        it('unique_ocf_device_local', function(done) {
            setTimeout(function() {
                // send HTTP request
                var req = http.request(options_d, function(res) {
                    res.setEncoding('utf8');
                    res.on('data', function (data) {
                        // console.log('in test ', data);
                        var devices = JSON.parse(data);
                        assert.equal(1, devices.length);
                        assert.equal('Smart Home LED', devices[0]['n']);
                        done();                    
                    });
                });
                req.end();            
            }, requestTimeout);
        });
    });

    describe('Only one LED platform should be found', function() {
        this.timeout(testCaseTimeout);

        before(function() {
            setTimeout(function() {
                sendRestRequests(options_p, multiReqNum);
            }, waitChildProcess);
        });

        it('unique_ocf_platform_local', function(done) {
            setTimeout(function() {
                // send HTTP request
                var req = http.request(options_p, function(res) {
                    res.setEncoding('utf8');
                    res.on('data', function (data) {
                        // console.log('in test ', data);
                        var platforms = JSON.parse(data);                    
                        assert.equal(1, platforms.length);
                        assert.equal('Intel', platforms[0]['mnmn']);
                        done();
                    });
                });
                req.end();
            }, requestTimeout);
        });
    });

    describe('Only one LED resource should be found', function() {
        this.timeout(testCaseTimeout);

        before(function() {
            setTimeout(function() {
                sendRestRequests(options_res, multiReqNum);
            }, waitChildProcess);
        });

        it('unique_ocf_resource_local', function(done) {
            setTimeout(function() {
                // send HTTP request
                var req = http.request(options_res, function(res) {
                    res.setEncoding('utf8');
                    res.on('data', function (data) {
                        // console.log('in test ', data);
                        var ledHrefNum = 0,
                            iterTimes = 0;
                        var ledRt;
                        var resources = JSON.parse(data);

                        resources.forEach(function (resource, key, array) {                        
                            if (resource.links[0]['href'] === '/a/led') {
                                ledHrefNum++;
                                ledRt = resource.links[0]['rt'];
                            }
                            iterTimes++;
                            if (iterTimes === array.length ) {
                                assert.equal(1, ledHrefNum);
                                assert.equal('oic.r.led', ledRt);
                                done();                            
                            }
                        });
                    });
                });
                req.end();            
            }, requestTimeout);
        });
    });

    after(function(){
        // console.log('killing led.js...');
        child.kill('SIGINT');
    })
});