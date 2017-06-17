#!/usr/bin/env python3

# TODO: allow defining the zones on-the-fly based on the configuration

import os
import sys
import re
import fcntl
import configparser

zonesConfigPaths = ["/usr/lib/firewall/zones.config", "/etc/firewall/zones.config"]
zonesTemplatePath = "/usr/lib/firewall/zones.template"
zonesRulesetPath = "/run/firewall/zones.ruleset"
servicePaths = ["/usr/lib/firewall/services", "/etc/firewall/services"]
configTemplatePath = "/usr/lib/firewall/firewall.template"
configRulesetPath = "/run/firewall/firewall.ruleset"

# lock to prevent processing several events at once
lock = open("/run/firewall/config_flock", "w")
fcntl.lockf(lock, fcntl.LOCK_EX)

# get available interfaces
interfaces = os.listdir("/sys/class/net")

# map interfaces to zones according to configuration
config = configparser.ConfigParser()
files = config.read(zonesConfigPaths)

def search_interfaces(key, conf):
    ret = ""
    if "match" in conf:
        if key in conf["match"]:
            r = re.compile(conf["match"][key])
            ifs = ", ".join([i for i in interfaces if r.search(i)])
            ret = "elements = { " + ifs + " }"

    return ret

# run regexps on the interfaces
local_ifs = search_interfaces("ZONE_LOCAL", config)
lan_ifs = search_interfaces("ZONE_LAN", config)
wan_ifs = search_interfaces("ZONE_WAN", config)
dmz_ifs = search_interfaces("ZONE_DMZ", config)
vpn_ifs = search_interfaces("ZONE_VPN", config)
all_ifs = search_interfaces("ZONE_ALL", config)

# read the zones template
with open(zonesTemplatePath, "r") as f:
    data = f.read()

output_data = data.format(local_interfaces=local_ifs, lan_interfaces=lan_ifs,
                          wan_interfaces=wan_ifs, dmz_interfaces=dmz_ifs,
                          vpn_interfaces=vpn_ifs, all_interfaces=all_ifs)

# Do not write the ruleset file if it already exists and there is no change.
# This prevents unneccessary firewall setup changes.

current_data = None

if os.path.exists(zonesRulesetPath):
    with open(zonesRulesetPath, "r", encoding="utf-8") as f:
        current_data = f.read()

if not current_data or current_data != output_data:
    # different file content, write the ruleset file
    with open(zonesRulesetPath, "w") as f:
        f.write(output_data)

if "--only-zones" in sys.argv:
    # configured to run only zone update
    sys.exit(0)

# read the firewall template
with open(configTemplatePath, "r") as f:
    data = f.read()

serviceFiles = []
for path in filter(os.path.exists, servicePaths):
    serviceFiles += [os.path.realpath(os.path.join(path, f)) for f in os.listdir(path)]

service_file_blob = "\n".join(['include "%s"' % f for f in serviceFiles])

output_data = data.format(service_chains=service_file_blob)

# write the ruleset file
with open(configRulesetPath, "w") as f:
    f.write(output_data)
