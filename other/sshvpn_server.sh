#!/bin/bash

CLIENT_COMMAND=$(echo $SSH_ORIGINAL_COMMAND | awk '{print $1}')

if [ "$CLIENT_COMMAND" != "sshvpn_server.sh" ]; then
    echo "[SERVER] ERROR! ssh command not supperted"
    echo "SSH_ORIGINAL_COMMAND : $SSH_ORIGINAL_COMMAND"
    exit 1
fi

SERVER_TUN=$(echo $SSH_ORIGINAL_COMMAND | awk '{print $2}')
SERVER_TUN_IP=$(echo $SSH_ORIGINAL_COMMAND | awk '{print $3}')
CLIENT_TUN_IP=$(echo $SSH_ORIGINAL_COMMAND | awk '{print $4}')
NETMASK=$(echo $SSH_ORIGINAL_COMMAND | awk '{print $5}')

ifconfig tun$SERVER_TUN $SERVER_TUN_IP pointopoint $CLIENT_TUN_IP netmask $NETMASK
echo "[SERVER] tun$SERVER_TUN: $SERVER_TUN_IP"
INTERNET_INTERFACE=$(ip route get 8.8.8.8 | head -n 1 | awk '{print $5}' | tr -d '\n')
echo "[SERVER] internet interface: $INTERNET_INTERFACE"
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A POSTROUTING -o $INTERNET_INTERFACE -j MASQUERADE
echo "[SERVER] internet sharing ready"
