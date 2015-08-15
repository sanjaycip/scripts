#!/bin/bash

FS_FILE=$1
MEMORY=$2
KERNEL_PARAMETERS=$3

MOUNT_DIR=${FS_FILE}.kvm-mount
if [ -e "$MOUNT_DIR" ]; then
	echo "$MOUNT_DIR dir exists"
	exit 1
fi


cleanup() {
	umount $MOUNT_DIR
	rmdir $MOUNT_DIR || exit
	echo "cleanup ok"
}

run() {
	mkdir $MOUNT_DIR
	mount -o ro $FS_FILE $MOUNT_DIR

	if [ "" != "$(readlink -f $MOUNT_DIR/boot/vmlinuz-*)" ]; then
		vmlinuz=$(readlink -f $MOUNT_DIR/boot/vmlinuz-* | head -n 1)
	else
		vmlinuz="/boot/vmlinuz-$(uname -r)"
	fi

	if [ "" != "$(readlink -f $MOUNT_DIR/boot/initrd.img-*)" ]; then
		initrd=$(readlink -f $MOUNT_DIR/boot/initrd.img-* | head -n 1)
	else
		initrd="/boot/initrd.img-$(uname -r)"
	fi

	echo "kernel: $vmlinuz"
	echo "initrd: $initrd"

	kvm \
		-smp $(nproc) -m $MEMORY \
		-serial mon:stdio \
		-kernel "$vmlinuz" \
		-initrd "$initrd" \
		-drive file=$FS_FILE,if=virtio \
		-append "$KERNEL_PARAMETERS root=/dev/vda rw"
}

trap cleanup EXIT

echo "FS_FILE: $FS_FILE"
echo "KERNEL_PARAMETERS: '$KERNEL_PARAMETERS'"
echo "CPU: $(nproc)"
echo "MEMORY: $MEMORY"

run
