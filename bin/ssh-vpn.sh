#!/bin/bash

## not: server /etc/ssh/sshd_config dosyasina "PermitTunnel yes" satirini ekle

if [ "$1" == "--help" ] || [ "$1" == "" ]; then
	echo "usage : ssh-vpn.sh RSA_FILE SERVER [TUN_NO] [PORT]"
	echo "        ssh-vpn.sh --pwd SERVER [TUN_NO] [PORT]"
	exit
fi

ID_RSA=$1
SERVER_IP_OR_DOMAIN=$2
TUN_NO=$3
SERVER_PORT=$4

DNS=8.8.8.8

validate_ip() {
	if [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		return 0
	else
		return 1
	fi
}

get_gateway() {
	ip route get 8.8.8.8 | head -n 1 | awk '{print $3}' | tr -d '\n'
}

get_interface() {
	ip route get 8.8.8.8 | head -n 1 | awk '{print $5}' | tr -d '\n'
}

convert_domain_to_ip() {
	if which dig &> /dev/null; then
		SERVER_IP=$(dig +short $SERVER_IP_OR_DOMAIN | head -n 1 | tr -d '\n')
		if [ "$SERVER_IP" == "" ]; then
			echo $SERVER_IP_OR_DOMAIN
		else
			echo $SERVER_IP
		fi
	else
		echo $SERVER_IP_OR_DOMAIN
	fi
}

is_android() {
	if [ -e "/system/bin/adb" ]; then
		return 0
	else
		return 1
	fi
}

clean_exit() {
	answer=""
	while [ "$answer" != "exit" ]; do
		echo -n "write 'exit' for clean exit: "
		read answer
	done

	if is_android ; then
		ip route del table 100 default via $SERVER_TUN_IP
		ip route del table 100 $SERVER_TUN_IP
		ip route del table 100 $SERVER_IP via $OLD_GATEWAY
		ip route del table 100 default via 127.0.0.1
		ip rule del table 100
	else
		ip route del $SERVER_IP via $OLD_GATEWAY
		ip route replace default via $OLD_GATEWAY
	fi
	echo "[CLIENT] gateway: $(get_gateway)"
	echo "[CLIENT] clean ok"
}

run() {

	[ "$ID_RSA" != "" ] || exit 1

	if [ "$TUN_NO" == "" ]; then
		TUN_NO=1
	fi

	if [ "$SERVER_PORT" == "" ]; then
		SERVER_PORT=22
	fi

	SERVER_IP=$(convert_domain_to_ip $SERVER_IP_OR_DOMAIN)

	if ! validate_ip ${SERVER_IP} ; then
		echo "server parameter : ${SERVER_IP_OR_DOMAIN}"
		echo "SERVER_IP error : ${SERVER_IP}"
		echo "check default gateway"
		echo "check DNS configuration if server parameter is domain name"
		exit 1
	fi

	# tunnel device IP configuration
	IP_3=$((200 + $TUN_NO))
	CLIENT_TUN=$TUN_NO
	CLIENT_TUN_IP=192.168.${IP_3}.2
	SERVER_TUN=$TUN_NO
	SERVER_TUN_IP=192.168.${IP_3}.1
	NETMASK=255.255.255.0

	OLD_GATEWAY=$(get_gateway)
	OLD_INTERFACE=$(get_interface)
	echo "[CLIENT] ssh-server: $SERVER_IP:$SERVER_PORT"
	echo "[CLIENT] gateway: $OLD_GATEWAY - interface: $OLD_INTERFACE "


	trap "clean_exit" SIGTERM EXIT SIGKILL

	if is_android ; then
		echo "[CLIENT] Android System"

		if [ ! -e "/dev/net/tun" ];then
			mkdir -p /dev/net
			ln -s /dev/tun /dev/net/tun
		fi

		ip route add $SERVER_IP via $OLD_GATEWAY;
		ip rule add prio 100 from all lookup 100
		ip route add table 100 $SERVER_IP via $OLD_GATEWAY

		ROUTE_CONFIG='\
			ifconfig tun'$CLIENT_TUN' '$CLIENT_TUN_IP' pointopoint '$SERVER_TUN_IP' netmask '$NETMASK'; \
			ip route add table 100 '$SERVER_TUN_IP' dev tun'$CLIENT_TUN'; \
			ip route add table 100 default via '$SERVER_TUN_IP';'

		DNS_CONFIG='\
			iptables -t nat -I OUTPUT -p tcp --dport 53 -j DNAT --to '$DNS':53 ; \
			iptables -t nat -I OUTPUT -p udp --dport 53 -j DNAT --to '$DNS':53 ; \
			iptables -t nat -I POSTROUTING -j MASQUERADE ; \
			setprop net.dns1 '$DNS' ; \
			setprop net.dns2 '$DNS' ; \
			setprop dhcp.wlan0.dns1 '$DNS' ; \
			setprop dhcp.wlan0.dns2 '$DNS' ; \
			setprop dhcp.wlan0.dns3 '$DNS' ; \
			setprop dhcp.wlan0.dns4 '$DNS' ;'

	else # PC
		ip route add $SERVER_IP via $OLD_GATEWAY;
		ROUTE_CONFIG='\
			ifconfig tun'$CLIENT_TUN' '$CLIENT_TUN_IP' pointopoint '$SERVER_TUN_IP' netmask '$NETMASK'; \
			ip route replace default via '$SERVER_TUN_IP';'

		DNS_CONFIG='echo nameserver '$DNS' > /etc/resolv.conf ;'
	fi


	LOCAL_COMMAND='\
		'$ROUTE_CONFIG' \
		echo "[CLIENT] tun'$CLIENT_TUN': '$CLIENT_TUN_IP'" ; \
		GATEWAY=$(ip route get 8.8.8.8 | head -n 1 | awk '"'"'{print $3}'"'"' | tr -d '"'"'\n'"'"') ; \
		echo "[CLIENT] gateway: $GATEWAY" ; \
		'$DNS_CONFIG' \
		echo "[CLIENT] dns: '$DNS'" ; \
		'

	REMOTE_COMMAND='ifconfig tun'$SERVER_TUN' '$SERVER_TUN_IP' pointopoint '$CLIENT_TUN_IP' netmask '$NETMASK'; \
		echo "[SERVER] tun'$SERVER_TUN': '$SERVER_TUN_IP'"; \
		\
		INTERNET_INTERFACE=$(ip route get 8.8.8.8 | head -n 1 | awk '"'"'{print $5}'"'"' | tr -d '"'"'\n'"'"') ; \
		echo "[SERVER] internet interface: $INTERNET_INTERFACE" ; \
		\
		echo 1 > /proc/sys/net/ipv4/ip_forward; \
		iptables -t nat -A POSTROUTING -o $INTERNET_INTERFACE -j MASQUERADE; \
		echo "[SERVER] internet sharing ready"; \
		'

	if [ $ID_RSA == "--pwd" ]; then
		SSH_COMMAND="ssh"
	else
		SSH_COMMAND="ssh -i $ID_RSA"
	fi

	$SSH_COMMAND \
		-o PermitLocalCommand=yes \
		-o LocalCommand="$LOCAL_COMMAND" \
		-o ServerAliveInterval=60 \
		-w $CLIENT_TUN:$SERVER_TUN \
		\
		root@$SERVER_IP -p $SERVER_PORT \
		"$REMOTE_COMMAND"

	SSH_EXIT_CODE=$?

	if is_android ; then
		ip route replace table 100 default via 127.0.0.1
	else
		ip route replace default via 127.0.0.1
	fi

	echo -e "\n"
	echo "WARNING: ssh process exited with $SSH_EXIT_CODE"
	echo "[CLIENT] gateway: $(get_gateway)"
	echo

	wait
}

run
