#!/bin/bash

## not: server /etc/ssh/sshd_config dosyasina "PermitTunnel yes" satirini ekle

if [ "$1" == "--help" ] || [ "$1" == "" ]; then
	echo "usage : ssh-vpn.sh RSA_FILE SERVER [TUN_NO] [PORT]"
	echo "        ssh-vpn.sh --pwd SERVER [TUN_NO] [PORT]"
	exit
fi

#env SERVER_SCRIPT=local|remote|path
#env SSH_PARAMETERS=

if [ "$SERVER_SCRIPT" == "" ]; then
	SERVER_SCRIPT=local
fi

ID_RSA=$1
SERVER_IP_OR_DOMAIN=$2
SERVER_PORT=$3
IP_1=192
IP_2=168
IP_3=189
# IP_4 -> server,client 1,2 - 3,4 - 5,6 ... seklinde otomatik hesaplaniyor

TUN_NO=0 # hata verirse otomatik arttiriyor

DNS=8.8.8.8

validate_ip() {
	if [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		return 0
	else
		return 1
	fi
}

get_gateway() {
	if is_android; then
		get_gateway_android
	else
		get_gateway_pc
	fi
}

# FIXME: get_gateway_pc ve get_interface_pc fonksiyonlarina duzgun bir cozum bulunmali
get_gateway_pc() {
	a=`ip route get 8.8.8.8 | grep via | wc -l`
	if [ "$a" == "0" ]; then
		ip route get 8.8.8.8 | head -n 1 | awk '{print $(NF-0)}' | tr -d '\n'
	else
		ip route get 8.8.8.8 | head -n 1 | awk '{print $3}' | tr -d '\n'
	fi
}

calculate_gateway() {
	IP=$1
	PREFIX=$2

	IFS=. read -r i1 i2 i3 i4 <<< $IP
	IFS=. read -r xx m1 m2 m3 m4 <<< $(for a in $(seq 1 32); do if [ $(((a - 1) % 8)) -eq 0 ]; then echo -n .; fi; if [ $a -le $PREFIX ]; then echo -n 1; else echo -n 0; fi; done)
	a=$(( i1 & (2#$m1) ))
	b=$(( i2 & (2#$m2) ))
	c=$(( i3 & (2#$m3) ))
	d=$(( i4 & (2#$m4) ))
	d=$((d+1))
	printf "%d.%d.%d.%d\n" "$a" "$b" "$c" "$d"
}

get_interface_type_android() {
	a=`get_interface_android`
	echo ${a:0:-1}
}

get_gateway_android() {
	line=`netcfg | grep UP | grep wlan | head -n 1`
	if [ "$line" == "" ]; then
		line=`netcfg | grep UP | grep -v 127.0.0.1 | head -n 1`
	fi
	ip_prefix=`echo $line | awk '{print $3}'`
	IP=`echo $ip_prefix | awk -F '/' '{print $1}'`
	PREFIX=`echo $ip_prefix | awk -F '/' '{print $2}'`

	if [ "$(get_interface_type_android)" == "wlan" ]; then
		gateway=`calculate_gateway $IP $PREFIX`
	else
		gateway=$IP
	fi

	echo $gateway
}

get_interface() {
	if is_android; then
		get_interface_android
	else
		get_interface_pc
	fi
}

get_interface_pc() {
	ip route get 8.8.8.8 | head -n 1 | awk '{print $5}' | tr -d '\n'
}

get_interface_android() {
	line=`netcfg | grep UP | grep wlan | head -n 1`
	if [ "$line" == "" ]; then
		line=`netcfg | grep UP | grep -v 127.0.0.1 | head -n 1`
	fi
	echo $line | awk '{print $1}'
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
		return 0 # 0 true
	else
		return 1
	fi
}

connection_error() {
	IP=$1
	PORT=$2
	if nc -w 10 -z $IP $PORT &> /dev/null; then
		return 1 # 1 false
	else
		return 0 # true
	fi
}
clean_exit() {
	answer=""
	while [ "$answer" != "exit" ]; do
		sleep 0.1
		echo -n "write 'exit' for clean exit: "
		read answer
	done

	if is_android ; then
		ip route del table 100 default via $SERVER_TUN_IP
		ip route del table 100 $SERVER_TUN_IP
		ip route del table 100 $SERVER_IP
		ip route del table 100 default via 127.0.0.1
		ip rule del table 100
	else
		ip route del $SERVER_IP via $OLD_GATEWAY
		ip route replace default via $OLD_GATEWAY
	fi
	echo "[CLIENT] gateway: $(get_gateway)"
	echo "[CLIENT] clean ok"
}

config() {
	[ "$ID_RSA" != "" ] || exit 1

	if [ "$SERVER_PORT" == "" ]; then
		SERVER_PORT=22
	fi

	if validate_ip ${SERVER_IP_OR_DOMAIN}; then
		SERVER_IP=$SERVER_IP_OR_DOMAIN
	else
		SERVER_IP=$(convert_domain_to_ip $SERVER_IP_OR_DOMAIN)
		if ! validate_ip ${SERVER_IP} ; then
			echo "server parameter : ${SERVER_IP_OR_DOMAIN}"
			echo "SERVER_IP error : ${SERVER_IP}"
			echo "check default gateway"
			echo "check DNS configuration if server parameter is domain name"
			exit 1
		fi
	fi

	trap "clean_exit" SIGTERM EXIT SIGKILL

	OLD_GATEWAY=$(get_gateway)
	OLD_INTERFACE=$(get_interface)
	echo "[CLIENT] ssh-server: $SERVER_IP:$SERVER_PORT"
	echo "[CLIENT] gateway: $OLD_GATEWAY - interface: $OLD_INTERFACE "

	if is_android ; then
		ip route add $SERVER_IP via $OLD_GATEWAY;
		ip rule add prio 100 from all lookup 100
	else # PC
		ip route add $SERVER_IP via $OLD_GATEWAY;
	fi
}

connect() {
	# tunnel device IP configuration
	IP_4_SERVER=$((2 * $TUN_NO - 1))
	IP_4_CLIENT=$((2 * $TUN_NO))
	CLIENT_TUN=${TUN_NO}
	CLIENT_TUN_IP=${IP_1}.${IP_2}.${IP_3}.${IP_4_CLIENT}
	SERVER_TUN=${TUN_NO}
	SERVER_TUN_IP=${IP_1}.${IP_2}.${IP_3}.${IP_4_SERVER}
	NETMASK=255.255.255.254

	if is_android ; then
		echo "[CLIENT] Android System"

		if [ ! -e "/dev/net/tun" ];then
			mkdir -p /dev/net
			ln -s /dev/tun /dev/net/tun
		fi

		gw=$(get_gateway)
		interface=$(get_interface)
		if [ "$gw" == "" ] ; then
			exit 1
		fi

		ip route replace table 100 $SERVER_IP via $gw dev $interface

		ROUTE_CONFIG='\
			ifconfig tun'$CLIENT_TUN' '$CLIENT_TUN_IP' pointopoint '$SERVER_TUN_IP' netmask '$NETMASK'; \
			ip route replace table 100 '$SERVER_TUN_IP' dev tun'$CLIENT_TUN'; \
			ip route replace table 100 default via '$SERVER_TUN_IP';'

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

	echo "[CLIENT] SERVER_SCRIPT : $SERVER_SCRIPT"
	if [ "$SERVER_SCRIPT" == "local" ]; then
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
	elif [ "$SERVER_SCRIPT" == "remote" ]; then
		REMOTE_COMMAND='sshvpn_server.sh '$SERVER_TUN' '$SERVER_TUN_IP' '$CLIENT_TUN_IP' '$NETMASK' '
	else
		REMOTE_COMMAND=$SERVER_SCRIPT
	fi

	if [ $ID_RSA == "--pwd" ]; then
		SSH_COMMAND="ssh"
	else
		SSH_COMMAND="ssh -i $ID_RSA"
	fi

	$SSH_COMMAND \
		$SSH_PARAMETERS \
		-o PermitLocalCommand=yes \
		-o LocalCommand="$LOCAL_COMMAND" \
		-o ServerAliveInterval=10 -o ServerAliveCountMax=1 \
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

config

while true; do
	((TUN_NO=(TUN_NO%120)+1))
	echo "TUN_NO: $TUN_NO"

	connect
	sleep 5
done
