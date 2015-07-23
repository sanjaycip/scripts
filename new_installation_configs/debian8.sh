EMACS="emacs-nox emms auto-complete-el mplayer2"
RATPOISON_EXTENSIONS="dmenu stalonetray xscreensaver suckless-tools htop xclip"
CODE="git build-essential ipython gdb manpages-dev manpages-posix-dev"
NET="sshfs encfs openvpn vpnc nmap filezilla"
UTIL="archivemount pv zip unzip alsa-utils rsync arandr usbutils xbacklight nocache uml-utilities dialog"
SYSTEM="kvm qemu-utils schroot btrfs-tools testdisk extundelete gparted xvnc4viewer"
HW_MONITOR="cpufrequtils stress mesa-utils lm-sensors"
DESKTOP="owncloud-client transmission-gtk file-roller synergy foxyproxy"
MEDIA="libav-tools gstreamer1.0-libav brasero easytag"

add_repositories() {
	# firefox
	apt-get install pkg-mozilla-archive-keyring || exit
	echo "deb http://mozilla.debian.net/ jessie-backports iceweasel-release" > /etc/apt/sources.list.d/firefox.list
	apt-get update || exit
	apt-get -y dist-upgrade || exit
	apt-get install -t jessie-backports iceweasel
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
