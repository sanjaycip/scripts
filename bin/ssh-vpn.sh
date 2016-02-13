#!/bin/bash

## not: server /etc/ssh/sshd_config dosyasina "PermitTunnel yes" satirini ekle

ID_RSA=$1
SERVER_IP=$2

[ "$ID_RSA" != "" ] || exit 1
[ "$SERVER_IP" != "" ] || exit 1

GW=`ip route get $SERVER_IP |  awk '{print $3}' | tr -d '\n'`
echo "current gateway : $GW"

clean() {
	ip route replace default via $GW;
	echo "clean ok"
}

trap "clean" SIGTERM EXIT

ip route add $SERVER_IP via $GW;

ssh -i $ID_RSA \
	-o PermitLocalCommand=yes \
	-o LocalCommand="\
		ifconfig tun5 192.168.244.2 pointopoint 192.168.244.1 netmask 255.255.255.0; \
		ip route replace default via 192.168.244.2; \
		" \
	-o ServerAliveInterval=60 \
	-w 5:5 root@$SERVER_IP \
	'ifconfig tun5 192.168.244.1 pointopoint 192.168.244.2 netmask 255.255.255.0; \
	echo tun ready; \
	\
	echo 1 > /proc/sys/net/ipv4/ip_forward; \
	iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE; \
	echo "internet sharing ready"; \
	'
