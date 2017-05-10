#!/bin/sh
iptables -D INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j REJECT
sleep 5
iptables -D INPUT -p tcp --dport 22 -j REJECT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
