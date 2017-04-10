#!/usr/bin/env python3

import os
import sys
import time
import json

from oeqa.oetest import oeRuntimeTest

sys.path.append(os.path.dirname(__file__))
import copy_necessary_files
import iot_config

class RestApiCheckLocalTest(oeRuntimeTest):

    iot_target = iot_config.IoTTargetConfiguration()

    @classmethod
    def setUpClass(cls):
        '''
        Copy necessary files to target.
        '''
        if cls.iot_target.need_copy_files:
            copy_necessary_files.copy_smarthome_demo_ocf_server(cls.tc.target.ip)
            copy_necessary_files.copy_rest_api_check_local_js(cls.tc.target.ip)

        cls.iot_target.prepare_test(cls.tc.target)

    def test_restapi_locally(self):
        '''
        Send REST request again and find only one OCF device.
        '''
        test_cmd = 'export NODE_PATH=/usr/lib/node_modules/;'\
                   'cd {js_test_dir};./node_modules/mocha/bin/mocha -R json'.format(
                        js_test_dir = self.iot_target.js_test_dir)
        (status, output) = self.target.run(test_cmd)

        self.parse_test_results(output)

    def parse_test_results(self, output):
        '''
        Parse the test results from mocha JSON format.
        '''
        results = json.loads(output.strip())

        template = '%s - runtest.py - RESULTS - Testcase %s: %s\n'
        results_data = []
        for failure in results.get('failures'):
            result = template % (time.strftime('%H:%M:%S', time.gmtime()),
                        failure.get('title'), 'FAILED')
            results_data.append(result)
        for block in results.get('pending'):
            result = template % (time.strftime('%H:%M:%S', time.gmtime()),
                        block.get('title'), 'BLOCKED')
            results_data.append(result)
        for passe in results.get('passes'):
            result = template % (time.strftime('%H:%M:%S', time.gmtime()),
                        passe.get('title'), 'PASS')
            results_data.append(result)

        root_dir = None
        nodejs_dir = os.path.dirname(__file__)
        root_dir = os.path.dirname(os.path.dirname(os.path.dirname(nodejs_dir)))
        result_log = os.path.join(root_dir, 'results-restapi-check-local.log')
        with open(result_log, 'w') as f:
            f.writelines(results_data)

    @classmethod
    def tearDownClass(cls):
        '''
        Clean up work.
        '''
        cls.iot_target.clean_up(cls.tc.target)