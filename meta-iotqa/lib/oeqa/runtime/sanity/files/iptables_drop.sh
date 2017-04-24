#!/bin/sh
iptables -D INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j DROP
sleep 10
iptables -D INPUT -p tcp --dport 22 -j DROP
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
