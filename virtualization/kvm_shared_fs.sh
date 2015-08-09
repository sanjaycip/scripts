#!/bin/bash

if [ "$(id -u)" != "0" ]; then
	echo "run as root"
	exit 1
fi

FS_ROOT=$(readlink -f $1)

if [ "$FS_ROOT" == "/" ]; then
	echo "[error] FS_ROOT=/"
	echo "using system rootfs as kvm rootfs can be problematic"
	exit 1
fi

MEMORY=$2
KERNEL_PARAMETERS=$3

run() {
	kvm \
		-smp $(nproc) -m $MEMORY \
		-serial mon:stdio \
		-kernel "/boot/vmlinuz-$(uname -r)" \
		-initrd "/boot/initrd.img-$(uname -r)" \
		-fsdev local,id=r,path=$FS_ROOT,security_model=passthrough \
		-device virtio-9p-pci,fsdev=r,mount_tag=r \
		-append "$KERNEL_PARAMETERS root=r rw rootfstype=9p rootflags=trans=virtio"
}

echo "KVM_ROOT_DIR: $FS_ROOT"
echo "KERNEL_PARAMETERS: '$KERNEL_PARAMETERS'"
echo "CPU: $(nproc)"
echo "MEMORY: $MEMORY"
echo "kernel version: $(uname -r)"

run
