var http = require('http');

var ocfServerDir = '/home/root/SmartHome-Demo/ocf-servers/js-servers';
var waitChildProcess = 2000,
    testCaseTimeout = 20000,
    requestTimeout = 5000,
    multiReqNum = 2;

var options_t = {
    host: '127.0.0.1',
    port: 8000,
    path: '',
    method: 'GET',
    headers: {
        'Accept': 'text/json'
    }
};

var options_d = Object.assign({}, options_t);
options_d.path = '/api/oic/d';

var options_p = Object.assign({}, options_t);
options_p.path = '/api/oic/p';

var options_res = Object.assign({}, options_t);
options_res.path = '/api/oic/res';

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

exports.ocfServerDir = ocfServerDir;
exports.waitChildProcess = waitChildProcess;
exports.testCaseTimeout = testCaseTimeout;
exports.requestTimeout = requestTimeout;
exports.multiReqNum = multiReqNum;

exports.options_d = options_d;
exports.options_p = options_p
exports.options_res = options_res;

exports.sendRestRequests = sendRestRequests;