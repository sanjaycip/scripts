EMACS="emacs-nox emms auto-complete-el mplayer2"
RATPOISON_EXTENSIONS="dmenu stalonetray xscreensaver suckless-tools conkeror htop xclip"
CODE="git build-essential ipython"
NET="sshfs encfs openvpn vpnc"
UTIL="archivemount pv btrfs-tools zip unzip alsa-utils rsync"
FIREFOX_EXTENSIONS="foxyproxy"
SYSTEM="kvm schroot"
HW_MONITOR="cpufreq-utils stress mesa-utils lm-sensors"

add_repositories() {
	# firefox
	apt-get install pkg-mozilla-archive-keyring || exit
	echo "deb http://mozilla.debian.net/ wheezy-backports iceweasel-release" > /etc/apt/sources.list.d/firefox.list
	apt-get update || exit
	apt-get -y dist-upgrade || exit
}

disable_services() {
	apt-get -y install rcconf || exit
	rcconf --off speech-dispatcher,avahi-daemon,bluetooth,gdm3,motd,openvpn || exit
	# disable modem-manager
	sudo mv /usr/share/dbus-1/system-services/org.freedesktop.ModemManager1.service /usr/share/dbus-1/system-services/org.freedesktop.ModemManager1.service.disabled
}

install_build_dep() {
	apt-get -y install devscripts fakeroot
}

clean_build_dep() {
	apt-get -y autoremove devscripts fakeroot
}

install_ratpoison() {
	apt-get -y build-dep ratpoison
	CURDIR=`pwd`

	mkdir tmp || exit 1
	cd tmp;
	apt-get source ratpoison
	cd ratpoison-*
	wget https://raw.githubusercontent.com/tanerguven/conf/master/ratpoison-configuration/lastmsg_stdout.patch
	patch -p1 -i lastmsg_stdout.patch
	dch -i "lastmsg_stdout.patch"
	dpkg-buildpackage -b -us -uc -rfakeroot
	cd ..
	dpkg -i ratpoison*.deb

	cd $CURDIR
	yes | aptitude markauto $(apt-cache showsrc ratpoison | sed -e '/Build-Depends/!d;s/Build-Depends: \|,\|([^)]*),*\|\[[^]]*\]//g')
}
