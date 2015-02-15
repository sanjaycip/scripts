EMACS="emacs23-nox emacs-jabber emms auto-complete-el mpg321"
RATPOISON_EXTENSIONS="dmenu stalonetray xscreensaver suckless-tools conkeror htop xclip"
CODE="git build-essential ipython"
NET="sshfs encfs openvpn vpnc"
UTIL="archivemount pv btrfs-tools"
FIREFOX_EXTENSIONS="foxyproxy"
SYSTEM="kvm schroot"
HW_MONITOR="cpufreq-utils stress mesa-utils lm-sensors"

add_repositories() {
	# firefox
	apt-get install pkg-mozilla-archive-keyring || exit
	echo "deb http://mozilla.debian.net/ wheezy-backports iceweasel-release" > /etc/apt/sources.list.d/firefox.list
	echo "deb-src http://ftp.nl.debian.org/debian/ jessie main" > /etc/apt/sources.list.d/jessie_source_packages.list
	apt-get update || exit
	apt-get -y dist-upgrade || exit
}

disable_services() {
	apt-get -y install rcconf || exit
	rcconf --off speech-dispatcher,avahi-daemon,bluetooth,gdm3,motd,openvpn || exit
	# disable modem-manager
	sudo mv /usr/share/dbus-1/system-services/org.freedesktop.ModemManager.service /usr/share/dbus-1/system-services/org.freedesktop.ModemManager.service.disabled
}

install_build_dep() {
	apt-get -y install devscripts
}

clean_build_dep() {
	apt-get -y autoremove devscripts
}

install_ratpoison() {
	apt-get -y build-dep ratpoison
	CURDIR=`pwd`

	mkdir tmp; cd tmp;
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
