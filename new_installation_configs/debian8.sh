EMACS="emacs-nox emms auto-complete-el mplayer2"
RATPOISON="ratpoison dmenu stalonetray xscreensaver suckless-tools conkeror htop xclip"
CODE="git build-essential ipython kvm"
NET="sshfs encfs openvpn vpnc"
UTIL="archivemount pv btrfs-tools"
FIREFOX_EXTENSIONS="foxyproxy"

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
