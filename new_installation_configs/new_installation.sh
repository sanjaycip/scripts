#!/bin/bash

source $1

# echo "nameserver 208.67.222.222" > /etc/resolv.conf
apt-get update

install_build_dep

add_repositories

install_ratpoison

apt-get -y install $EMACS $RATPOISON_EXTENSIONS $CODE $NET $UTIL $SYSTEM $HW_MONITOR $FIREFOX_EXTENSIONS || exit

# add ratpoison
echo "[Desktop Entry]
Exec=ratpoison
TryExec=ratpoison
Name=Ratpoison
Comment=" >  /usr/share/xsessions/ratpoison.desktop

# disable pc speaker beep
echo "blacklist pcspkr" > /etc/modprobe.d/disable-pcspkr.conf

disable_services

clean_build_dep

# clean
apt-get clean
