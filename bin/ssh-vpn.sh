#!/bin/bash

## not: server /etc/ssh/sshd_config dosyasina "PermitTunnel yes" satirini ekle

ID_RSA=$1
SERVER_IP_OR_DOMAIN=$2
TUN_NO=$3
SERVER_PORT=$4

SERVER_IP=$(dig +short $SERVER_IP_OR_DOMAIN | head -n 1 | tr -d '\n')
if [ "$SERVER_IP" == "" ]; then
	SERVER_IP=$SERVER_IP_OR_DOMAIN
fi

if [ "$SERVER_PORT" == "" ]; then
	SERVER_PORT=22
fi

[ "$ID_RSA" != "" ] || exit 1
[ "$SERVER_IP" != "" ] || exit 1

IP_3=$((200 + $TUN_NO))
CLIENT_TUN=$TUN_NO
CLIENT_TUN_IP=192.168.${IP_3}.2
SERVER_TUN=$TUN_NO
SERVER_TUN_IP=192.168.${IP_3}.1
NETMASK=255.255.255.0

echo "[CLIENT] ssh-server: $SERVER_IP:$SERVER_PORT"

get_gateway() {
	ip route get 8.8.8.8 | head -n 1 | awk '{print $3}' | tr -d '\n'
}

GW=$(get_gateway)
echo "[CLIENT] gateway: $GW"

clean_exit() {
	answer=""
	while [ "$answer" != "exit" ]; do
		echo -n "write 'exit' for clean exit: "
		read answer
	done
	ip route del $SERVER_IP via $GW
	ip route replace default via $GW
	echo "[CLIENT] gateway: $(get_gateway)"
	echo "[CLIENT] clean ok"
}


trap "clean_exit" SIGTERM EXIT SIGKILL

ip route add $SERVER_IP via $GW;

ssh -i $ID_RSA \
	-o PermitLocalCommand=yes \
	-o LocalCommand='\
		ifconfig tun'$CLIENT_TUN' '$CLIENT_TUN_IP' pointopoint '$SERVER_TUN_IP' netmask '$NETMASK'; \
		ip route replace default via '$SERVER_TUN_IP'; \
		echo "[CLIENT] tun'$CLIENT_TUN': '$CLIENT_TUN_IP'" ; \
		GATEWAY=$(ip route get 8.8.8.8 | head -n 1 | awk '"'"'{print $3}'"'"' | tr -d '"'"'\n'"'"') ; \
		echo "[CLIENT] gateway: $GATEWAY" ; \
		' \
	-o ServerAliveInterval=60 \
	-w $CLIENT_TUN:$SERVER_TUN \
	\
	root@$SERVER_IP -p $SERVER_PORT \
	'ifconfig tun'$SERVER_TUN' '$SERVER_TUN_IP' pointopoint '$CLIENT_TUN_IP' netmask '$NETMASK'; \
	echo "[SERVER] tun'$SERVER_TUN': '$SERVER_TUN_IP'"; \
	\
	INTERNET_INTERFACE=$(ip route get 8.8.8.8 | head -n 1 | awk '"'"'{print $5}'"'"' | tr -d '"'"'\n'"'"') ; \
	echo "[SERVER] internet interface: $INTERNET_INTERFACE" ; \
	\
	echo 1 > /proc/sys/net/ipv4/ip_forward; \
	iptables -t nat -A POSTROUTING -o $INTERNET_INTERFACE -j MASQUERADE; \
	echo "[SERVER] internet sharing ready"; \
	'

SSH_EXIT_CODE=$?

ip route replace default via 127.0.0.1
echo -e "\n"
echo "WARNING: ssh process exited with $SSH_EXIT_CODE"
echo "[CLIENT] gateway: $(get_gateway)"
echo

wait
