
IP=`ifconfig eth0 2>/dev/null|awk '/inet addr:/ {print $2}'|sed 's/addr://'`

cp out/server/* /etc/openvpn/

# /etc/sysctl.conf -> net.ipv4.ip_forward=1
sed -i 's|#net.ipv4.ip_forward=1|net.ipv4.ip_forward=1|' /etc/sysctl.conf
echo 1 > /proc/sys/net/ipv4/ip_forward

### remove
sed -i '/iptables -t nat -A POSTROUTING -s 10.8.0.0/d' /etc/rc.local
### add
sed -i "1 a\iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -j SNAT --to-source $IP" /etc/rc.local
### run
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -j SNAT --to-source $IP
