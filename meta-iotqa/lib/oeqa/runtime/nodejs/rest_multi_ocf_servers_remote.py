#!/usr/bin/env python3

import os
import sys
import time
import json

from oeqa.oetest import oeRuntimeTest

sys.path.append(os.path.dirname(__file__))
import copy_necessary_files
import iot_config

class RestApiMultiOcfServersTest(oeRuntimeTest):

    iot_target = iot_config.IoTTargetConfiguration()

    @classmethod
    def setUpClass(cls):
        '''
        Launch the led.js and gas.js OCF servers on target device.
        '''
        if cls.iot_target.need_copy_files:
            copy_necessary_files.copy_smarthome_demo_ocf_server(cls.tc.target.ip)

        cls.iot_target.launch_ocf_server(cls.tc.target.ip, 'led.js')
        cls.iot_target.launch_ocf_server(cls.tc.target.ip, 'gas.js')
        time.sleep(cls.iot_target.wait_launch_ocf_server)

        cls.iot_target.prepare_test(cls.tc.target)
        cls.iot_target.send_multi_requests(cls.tc.target.ip, 2)

    def test_multi_ocf_devices_remote(self):
        '''
        Send REST request and find mutiple OCF device.
        '''
        response = self.iot_target.session.get(self.iot_target.url_oic_d.format(ip = self.target.ip))
        data = response.content
        devices = json.loads(data.decode('utf8'))

        devLedFound = False
        devGasFound = False

        for device in devices:
            if device.get('n') == 'Smart Home LED':
                devLedFound = True

            if device.get('n') == 'Smart Home Gas Sensor':
                devGasFound = True

        self.assertEqual(2, len(devices), 'Only the LED & gas devices should be found!')
        self.assertTrue(devLedFound, 'Smart Home LED device not found!')
        self.assertTrue(devGasFound, 'Smart Home Gas Sensor device not found!')

    def test_multi_ocf_platforms_remote(self):
        '''
        Send REST request and find only one OCF platform.
        '''
        response = self.iot_target.session.get(self.iot_target.url_oic_p.format(ip = self.target.ip))
        data = response.content
        platforms = json.loads(data.decode('utf8'))

        self.assertEqual(2, len(platforms), 'Two OCF platforms should be found!')
        for platform in platforms:
            self.assertEqual('Intel', platform.get('mnmn'))

    def test_multi_ocf_resources_remote(self):
        '''
        Send REST request and find the LED and Gas OCF resource.
        '''
        response = self.iot_target.session.get(self.iot_target.url_oic_res.format(ip = self.target.ip))
        data = response.content
        resources = json.loads(data.decode('utf8'))

        ledHrefNum = 0
        ledRt = ''
        gasHrefNum = 0;
        gasRt = ''
        for resource in resources:
            if resource.get('links')[0].get('href') == '/a/led':
                ledHrefNum += 1
                ledRt = resource.get('links')[0].get('rt')

            if resource.get('links')[0].get('href') == '/a/gas':
                gasHrefNum += 1
                gasRt = resource.get('links')[0].get('rt')            

        self.assertEqual(1, ledHrefNum, 'Only one LED resource should be found!')
        self.assertEqual('oic.r.led', ledRt)

        self.assertEqual(1, gasHrefNum, 'Only one gas resource should be found!')
        self.assertEqual('oic.r.sensor.carbondioxide', gasRt)

    @classmethod
    def tearDownClass(cls):
        '''
        Clean up work.
        '''
        cls.iot_target.kill_ocf_server(cls.tc.target, 'led.js')  
        cls.iot_target.kill_ocf_server(cls.tc.target, 'gas.js')
        time.sleep(cls.iot_target.wait_kill_ocf_server)

        cls.iot_target.clean_up(cls.tc.target)