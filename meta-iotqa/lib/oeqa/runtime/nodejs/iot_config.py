#!/usr/bin/env python3

import os
import requests

class IoTTargetConfiguration:
	'''
	IoT Target configuration
	'''

	def __init__(self):
		self.restapilocal = 'restapilocal'
		self.home_dir = '/home/root'
		self.sh_demo_dir = os.path.join(self.home_dir, 'SmartHome-Demo')
		self.js_test_dir = os.path.join(self.sh_demo_dir, self.restapilocal)
		self.ocf_dir = os.path.join(self.sh_demo_dir, 'ocf-servers', 'js-servers')

		self.cleanup = True
		self.need_copy_files = True
		self.use_systemd_rest_api = True
		self.do_open_port = True
		self.do_close_port = True

		self.url_oic_d = 'http://{ip}:8000/api/oic/d'
		self.url_oic_p = 'http://{ip}:8000/api/oic/p'
		self.url_oic_res = 'http://{ip}:8000/api/oic/res'
		self.wait_launch_ocf_server = 10
		self.wait_kill_ocf_server = 4

		self.session = requests.Session()
		self.session.trust_env = False

	def launch_iot_rest_api_server(self, target):
		'''
		Launch the iot-rest-api-server service via systemctl.
		'''
		if self.use_systemd_rest_api:
			target.run('systemctl start iot-rest-api-server')

	def open_ports_for_rest_api(self, target):
		'''
		Open 5683/5684/8000 port for iot-rest-api-server.
		'''
		if self.do_open_port:
			target.run('iptables -A INPUT -p tcp -m tcp --dport 8000 -j ACCEPT')
			target.run('iptables -A INPUT -p udp -m udp --dport 5683 -j ACCEPT')
			target.run('iptables -A INPUT -p udp -m udp --dport 5684 -j ACCEPT')
			target.run('ip6tables -w -A INPUT -s fe80::/10 -p udp -m udp --dport 5683 -j ACCEPT')
			target.run('ip6tables -w -A INPUT -s fe80::/10 -p udp -m udp --dport 5684 -j ACCEPT')

	def close_ports_for_cleanup(self, target):
		'''
		Close 5683/5684/8000 port after tests.
		'''
		if self.do_close_port:
			target.run('iptables -D INPUT -p tcp -m tcp --dport 8000 -j ACCEPT')
			target.run('iptables -D INPUT -p udp -m udp --dport 5683 -j ACCEPT')
			target.run('iptables -D INPUT -p udp -m udp --dport 5684 -j ACCEPT')
			target.run('ip6tables -w -D INPUT -s fe80::/10 -p udp -m udp --dport 5683 -j ACCEPT')
			target.run('ip6tables -w -D INPUT -s fe80::/10 -p udp -m udp --dport 5684 -j ACCEPT')

	def prepare_test(self, target):
		'''
		Prepare work before the test.
		'''
		self.launch_iot_rest_api_server(target)
		self.open_ports_for_rest_api(target)

	def send_multi_requests(self, ip, n):
		'''
		Send several requests
		'''
		for i in range(n):
			self.session.get(self.url_oic_d.format(ip = ip))
			self.session.get(self.url_oic_p.format(ip = ip))
			self.session.get(self.url_oic_res.format(ip = ip))

	def launch_ocf_server(self, ip, ocf_server_file):
		'''
		Launch an OCF server.
		'''
		print('\nLaunch the OCF server {ocf_server} on the target device...'.format(
			ocf_server = ocf_server_file))
		launch_ocf_server_cmd = 'ssh root@{ip} '\
								'"export NODE_PATH=/usr/lib/node_modules/;'\
								'cd {ocf_dir};node {ocf_server} &" &'.format(
									ip = ip,
									ocf_dir = self.ocf_dir,
									ocf_server = ocf_server_file)
		os.system(launch_ocf_server_cmd)

	def kill_ocf_server(self, target, pattern, signal = '-INT'):
		'''
		Kill process that contains the pattern in the command line.
		'''
		ps_ocf_svr_cmd = 'ps | grep -v grep | grep {p}'.format(p = pattern)
		(status, output) = target.run(ps_ocf_svr_cmd)
		print('\n' + output)
		ps = output.strip().split('\n')

		for p in ps:
			if not p:
				continue
			pid = p.strip().split()[0]
			kill_ocf_svr_cmd = 'kill {sig} {pid}'.format(sig = signal, pid = pid)
			print(kill_ocf_svr_cmd)
			target.run(kill_ocf_svr_cmd)

	def clean_up(self, target):
		'''
		Clean up work
		'''
		if self.cleanup:
			target.run('rm -fr {d}'.format(d = self.sh_demo_dir))

		if self.do_close_port:
			self.close_ports_for_cleanup(target)