#!/bin/bash

# bug: apt-get update
#	E: Unable to determine file size of fd 7 ....
# https://bugs.launchpad.net/qemu/+bug/1336794

if [ "$(id -u)" != "0" ]; then
	echo "run as root"
	exit 1
fi

FS_ROOT=$1

TMP_DIR=/dev/shm/kvm_unionmount_root.sh/$$
CACHE_DIR=$TMP_DIR/root-cache
KVM_ROOT_DIR=$TMP_DIR/root

cleanup() {
	umount $KVM_ROOT_DIR
	umount $CACHE_DIR
	rmdir $KVM_ROOT_DIR $CACHE_DIR
	rmdir $TMP_DIR
	echo "cleanup ok"
}

run() {
	mkdir -p $TMP_DIR $KVM_ROOT_DIR $CACHE_DIR
	mount -t tmpfs tmpfs $CACHE_DIR -o size=512M

	mkdir -p $CACHE_DIR/root

	unionmount.sh $FS_ROOT $CACHE_DIR/root $KVM_ROOT_DIR
	rm -f $KVM_ROOT_DIR/etc/fstab $KVM_ROOT_DIR/etc/crypttab

	KVM_MEMORY=$KVM_MEMORY KVM_KERNEL_PARAMETERS=${KVM_KERNEL_PARAMETERS} kvm_shared_fs.sh $KVM_ROOT_DIR
}

trap cleanup EXIT

echo "TMP_DIR: $TMP_DIR"
echo "CACHE_DIR: $CACHE_DIR"

run
