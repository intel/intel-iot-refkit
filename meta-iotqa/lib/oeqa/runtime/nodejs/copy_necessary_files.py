#!/usr/bin/env python3

import os

def copy_smarthome_demo_ocf_server(ip, to_dir = '/home/root'):
	'''
	Copy SmartHome-Demo/ocf-servers directory to target IP.
	'''
	files_dir = os.path.join(os.path.dirname(__file__), 'files')
	target_sh_demo_dir = '{prefix}/SmartHome-Demo/ocf-servers/js-servers'.format(prefix = to_dir)

	os.system('ssh root@{ip} "test -d {d1} || mkdir -pv {d2}"'.format(
						ip = ip, d1 = target_sh_demo_dir, d2 = target_sh_demo_dir))
	os.chdir(files_dir)
	os.system('scp -r ocfservers/*.js root@{ip}:{target_dir}/'.format(ip = ip, target_dir = target_sh_demo_dir))

def copy_rest_api_check_local_js(ip, to_dir = '/home/root'):
	'''
	Copy local directory restapilocal to to_dir on target devices.
	'''
	files_dir = os.path.join(os.path.dirname(__file__), 'files')
	restapilocal_dir = os.path.join(files_dir, 'restapilocal')
	mocha_dir = os.path.join(restapilocal_dir, 'node_modules', 'mocha')

	if not os.path.exists(mocha_dir):
		os.chdir(restapilocal_dir)
		os.system('npm install')

	os.chdir(files_dir)
	os.system('scp -r restapilocal root@{ip}:{to}/SmartHome-Demo'.format(ip = ip, to = to_dir))