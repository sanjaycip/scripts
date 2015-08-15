#!/bin/bash

# bug: apt-get update
#	E: Unable to determine file size of fd 7 ....
# https://bugs.launchpad.net/qemu/+bug/1336794

if [ "$(id -u)" != "0" ]; then
	echo "run as root"
	exit 1
fi

FS_ROOT=$1
MEMORY=$2
KERNEL_PARAMETERS=$3

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

	kvm \
		-smp $(nproc) -m $MEMORY \
		-serial mon:stdio \
		-kernel "/boot/vmlinuz-$(uname -r)" \
		-initrd "/boot/initrd.img-$(uname -r)" \
		-fsdev local,id=r,path=$KVM_ROOT_DIR,security_model=passthrough \
		-device virtio-9p-pci,fsdev=r,mount_tag=r \
		-append "$KERNEL_PARAMETERS root=r rw rootfstype=9p rootflags=trans=virtio"
}

trap cleanup EXIT

echo "TMP_DIR: $TMP_DIR"
echo "CACHE_DIR: $CACHE_DIR"
echo "KVM_ROOT_DIR: $KVM_ROOT_DIR"
echo "KERNEL_PARAMETERS: '$KERNEL_PARAMETERS'"
echo "CPU: $(nproc)"
echo "MEMORY: $MEMORY"
echo "kernel version: $(uname -r)"

run
