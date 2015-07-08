3#!/bin/bash

CONF_FILE=$1
OUTPUT_DIR=$2

if [ ! -f ${CONF_FILE} ] || [ ${OUTPUT_DIR} == "" ] ; then
	echo "wrong paramter"
	echo "usage : $1 CONFFILE OUTPUTDIR"
	exit 1
fi

source ${CONF_FILE}

EASY_RSA_DIR=/usr/share/easy-rsa/

CURDIR=`pwd`
OUT_DIR=$CURDIR/$2

DH=dh$KEY_SIZE.pem

SERVER_DIR=$OUT_DIR/server

mkdir -p $SERVER_DIR

create_server_conf() {
	printf "port $PORT\nproto $PROTO\ndev $DEV\ncipher $CIPHER\n" > $SERVER_DIR/vpn.conf;
	if [[ -n "$COMPRESSION" ]]; then echo "$COMPRESSION" >> $SERVER_DIR/vpn.conf; fi

	printf "\npersist-key\npersist-tun\nstatus status.log\nverb 3\n" >> $SERVER_DIR/vpn.conf;

	printf "\nca ca.crt\ncert $SERVER_HOSTNAME.crt\nkey $SERVER_HOSTNAME.key\ndh $DH\n\n" >> $SERVER_DIR/vpn.conf;

	echo "server $LOCAL_NETWORK $LOCAL_NETMASK" >> $SERVER_DIR/vpn.conf;
	if [[ -n "$SHARE_INTERNET" ]]; then echo "$SHARE_INTERNET" >> $SERVER_DIR/vpn.conf; fi
	for v in $DNS
	do
		echo "push \"dhcp-option DNS $v\"" >> $SERVER_DIR/vpn.conf
	done

	printf "keepalive 10 120\nifconfig-pool-persist ipp.txt\n\n" >> $SERVER_DIR/vpn.conf
	if [[ -n "$USER" ]]; then echo "user $USER" >> $SERVER_DIR/vpn.conf; fi
	if [[ -n "$GROUP" ]]; then echo "group $GROUP" >> $SERVER_DIR/vpn.conf; fi
}

create_client_conf() {
	CLIENT_NAME=$1
	CLIENT_DIR=$2

	CONF_FILE=${CLIENT_DIR}/vpn.conf
	echo "client" > $CONF_FILE

	echo "remote $SERVER_IP" >> $CONF_FILE;

	printf "port $PORT\nproto $PROTO\ndev $DEV\ncipher $CIPHER\nns-cert-type server\n" >> $CONF_FILE;
	if [[ -n "$COMPRESSION" ]]; then echo "$COMPRESSION" >> $CONF_FILE; fi

	printf "\nnobind\nauth-nocache\npersist-key\npersist-tun\n\n" >> $CONF_FILE;

	if [[ -n "$USER" ]]; then echo "user $USER" >> $CONF_FILE; fi
	if [[ -n "$GROUP" ]]; then echo "group $GROUP" >> $CONF_FILE; fi

	if [[ -n "$SHARE_INTERNET" ]]; then
		printf "script-security 2\nup /etc/openvpn/update-resolv-conf\ndown /etc/openvpn/update-resolv-conf\n" >> $CONF_FILE;
	fi

	################## .ovpn file #####################
	OVPN_FILE=${CLIENT_DIR}/${CLIENT_NAME}.ovpn
	cp $CONF_FILE $OVPN_FILE
	echo "<ca>" >> $OVPN_FILE
	cat ${CLIENT_DIR}/ca.crt >> $OVPN_FILE
	echo "</ca>" >> $OVPN_FILE
	echo "<cert>" >> $OVPN_FILE
	cat ${CLIENT_DIR}/${CLIENT_NAME}.crt >> $OVPN_FILE
	echo "</cert>" >> $OVPN_FILE
	echo "<key>" >> $OVPN_FILE
	cat ${CLIENT_DIR}/${CLIENT_NAME}.key >> $OVPN_FILE
	echo "</key>" >> $OVPN_FILE
	###################################################

	printf "\nca ca.crt\ncert $1.crt\nkey $1.key\n" >> $CONF_FILE;
}

run() {
	rm -rf $OUT_DIR/easy-rsa
	cp -rf ${EASY_RSA_DIR} $OUT_DIR/easy-rsa

	cd $OUT_DIR/easy-rsa;

	# change keysize to $KEY_SIZE
	sed -i 's/^\(export\ KEY_SIZE=\).*/\1$KEY_SIZE/' vars

	source vars;
	./clean-all
	# build-ca
	./pkitool --initca

	# build-key-server
	KEY_NAME=$SERVER_HOSTNAME ./pkitool --server $SERVER_HOSTNAME


	for v in $CLIENT_HOSTNAMES
	do
		echo ""
		echo "adding client key: $v"
		# build-key
		KEY_OU=ou_$v KEY_CN=cn_$v KEY_NAME=$v ./pkitool $v
	done

	./build-dh
}

copy_files() {
	cd $OUT_DIR/easy-rsa;

	mkdir -p $SERVER_DIR
	cp keys/ca.crt $SERVER_DIR
	cp keys/$DH $SERVER_DIR
	cp keys/$SERVER_HOSTNAME.crt $SERVER_DIR
	cp keys/$SERVER_HOSTNAME.key $SERVER_DIR
	create_server_conf

	for v in $CLIENT_HOSTNAMES
	do
		CLIENT_DIR=$OUT_DIR/client/$v
		mkdir -p $CLIENT_DIR
		cp keys/ca.crt $CLIENT_DIR
		cp keys/$v.key $CLIENT_DIR
		cp keys/$v.crt $CLIENT_DIR
		create_client_conf $v $CLIENT_DIR
	done

	cd $CURDIR
	rm -rf $OUT_DIR/easy-rsa;
}

run
copy_files
