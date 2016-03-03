#!/bin/bash

## not: server /etc/ssh/sshd_config dosyasina "PermitTunnel yes" satirini ekle

ID_RSA=$1
SERVER_IP_OR_DOMAIN=$2
SERVER_PORT=$3

SERVER_IP=`dig +short $SERVER_IP_OR_DOMAIN | head -n 1 | tr -d '\n'`
if [ "$SERVER_IP" == "" ]; then
	SERVER_IP=$SERVER_IP_OR_DOMAIN
fi

if [ "$SERVER_PORT" == "" ]; then
	SERVER_PORT=22
fi

echo "[CLIENT] ssh-server: $SERVER_IP:$SERVER_PORT"

[ "$ID_RSA" != "" ] || exit 1
[ "$SERVER_IP" != "" ] || exit 1

GW=`ip route get 8.8.8.8 |  awk '{print $3}' | tr -d '\n'`
echo "[CLIENT] current gateway: $GW"

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
	-w 5:5 root@$SERVER_IP -p $SERVER_PORT \
	'ifconfig tun5 192.168.244.1 pointopoint 192.168.244.2 netmask 255.255.255.0; \
	echo "[SERVER] tun ready"; \
	\
	INTERNET_INTERFACE=`ip route get 8.8.8.8 | awk '"'"'{print $5}'"'"' | head -n 1 | tr -d '"'"'\n'"'"'` ; \
	echo "[SERVER] internet interface: $INTERNET_INTERFACE" ; \
	\
	echo 1 > /proc/sys/net/ipv4/ip_forward; \
	iptables -t nat -A POSTROUTING -o $INTERNET_INTERFACE -j MASQUERADE; \
	echo "[SERVER] internet sharing ready"; \
	'
