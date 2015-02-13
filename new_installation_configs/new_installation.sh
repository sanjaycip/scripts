#!/bin/bash

source $1

# echo "nameserver 208.67.222.222" > /etc/resolv.conf
apt-get update

add_repositories

apt-get -y install $EMACS $RATPOISON $CODE $NET $UTIL $FIREFOX_EXTENSIONS || exit

# add ratpoison
echo "[Desktop Entry]
Exec=ratpoison
TryExec=ratpoison
Name=Ratpoison
Comment=" >  /usr/share/xsessions/ratpoison.desktop

# disable pc speaker beep
echo "blacklist pcspkr" > /etc/modprobe.d/disable-pcspkr.conf

disable_services

# clean
apt-get clean
