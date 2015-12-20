#!/bin/bash

# bug: apt-get update
#	E: Unable to determine file size of fd 7 ....
# https://bugs.launchpad.net/qemu/+bug/1336794

if [ "$(id -u)" != "0" ]; then
	echo "run as root"
	exit 1
fi

FS_ROOT=$1
#KVM_KERNEL_PARAMETERS

TMP_DIR=/dev/shm/kvm_aufs_root/$$
CACHE_DIR=$TMP_DIR/root-aufs-cache
KVM_ROOT_DIR=$TMP_DIR/root-aufs

cleanup() {
	umount $TMP_DIR/root-aufs
	umount $TMP_DIR/root-aufs-cache
	rmdir $TMP_DIR/root-aufs $TMP_DIR/root-aufs-cache
	rmdir $TMP_DIR
	echo "cleanup ok"
}

run() {
	mkdir -p $TMP_DIR $KVM_ROOT_DIR $CACHE_DIR
	mount -t tmpfs tmpfs $CACHE_DIR -o size=512M
	mount -t aufs -o br=$CACHE_DIR=rw:$FS_ROOT=ro -o udba=reval none $KVM_ROOT_DIR

	rm -f $KVM_ROOT_DIR/etc/fstab $KVM_ROOT_DIR/etc/crypttab

	KVM_MEMORY=$KVM_MEMORY KVM_KERNEL_PARAMETERS=$KVM_KERNEL_PARAMETERS kvm_shared_fs.sh $KVM_ROOT_DIR
}

trap cleanup EXIT

echo "TMP_DIR: $TMP_DIR"
echo "CACHE_DIR: $CACHE_DIR"

run
