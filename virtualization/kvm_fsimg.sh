#!/bin/bash

if [ "$KVM_MEMORY" == "" ]; then
	KVM_MEMORY="512"
fi


INPUT_FS_FILE=$1
if [ "INPUT_FS_FILE" != "" ]; then
	KVM_FS_FILE=$INPUT_FS_FILE
fi

if [ "$KVM_FS_FILE" == "" ]; then
	echo "KVM_FS_FILE empty"
	exit 1
fi

MOUNT_DIR=${KVM_FS_FILE}.kvm-mount
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

	mount -o rw $KVM_FS_FILE $MOUNT_DIR || exit
	eval $EVAL_KVM_COPY_FILES
	for i in "${KVM_COPY_FILES[@]}" ; do
		IFS=':' read -r src dst <<< "$i"
		echo "cp $src $MOUNT_DIR/$dst"
		cp -f $src $MOUNT_DIR/$dst || exit
	done
	umount $MOUNT_DIR


	mount -o ro $KVM_FS_FILE $MOUNT_DIR  || exit
	if [ "" != "$KVM_VMLINUZ" ];then
		vmlinuz=$KVM_VMLINUZ
	elif [ "" != "$(readlink -f $MOUNT_DIR/boot/vmlinuz-*)" ]; then
		vmlinuz=$(readlink -f $MOUNT_DIR/boot/vmlinuz-* | head -n 1)
	else
		vmlinuz="/boot/vmlinuz-$(uname -r)"
	fi

	if [ "" != "$KVM_INITRD" ]; then
		initrd=$KVM_INITRD
	elif [ "" != "$(readlink -f $MOUNT_DIR/boot/initrd.img-*)" ]; then
		initrd=$(readlink -f $MOUNT_DIR/boot/initrd.img-* | head -n 1)
	else
		initrd="/boot/initrd.img-$(uname -r)"
	fi

	echo "kernel: $vmlinuz"
	echo "initrd: $initrd"

	kvm \
		-smp $(nproc) -m $KVM_MEMORY \
		-serial mon:stdio \
		-kernel "$vmlinuz" \
		-initrd "$initrd" \
		-drive file=$KVM_FS_FILE,if=virtio \
		$KVM_PARAMETERS \
		-append "$KVM_KERNEL_PARAMETERS root=/dev/vda rw"
}

trap cleanup EXIT

echo "KVM_FS_FILE: $KVM_FS_FILE"
echo "KERNEL_PARAMETERS: '$KVM_KERNEL_PARAMETERS'"
echo "CPU: $(nproc)"
echo "MEMORY: $KVM_MEMORY"
echo "KVM_PARAMETERS: $KVM_PARAMETERS"

run
