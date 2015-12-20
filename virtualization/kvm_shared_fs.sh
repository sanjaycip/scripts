#!/bin/bash

if [ "$KVM_MEMORY" == "" ]; then
	KVM_MEMORY="512"
fi


KVM_ROOT_DIR=$1
if [ "$KVM_ROOT_DIR" == "/" ]; then
	echo "ERROR: system root cannot used as ROOT_DIR"
	exit 1
fi

cleanup() {

	echo "cleanup ok"
}

run() {

	if [ "" != "$KVM_VMLINUZ" ];then
		vmlinuz=$KVM_VMLINUZ
	elif [ "" != "$(readlink -e $KVM_ROOT_DIR/boot/vmlinuz-*)" ]; then
		vmlinuz=$(readlink -e $KVM_ROOT_DIR/boot/vmlinuz-* | head -n 1)
	else
		vmlinuz="/boot/vmlinuz-$(uname -r)"
	fi

	if [ "" != "$KVM_INITRD" ]; then
		initrd=$KVM_INITRD
	elif [ "" != "$(readlink -e $KVM_ROOT_DIR/boot/initrd.img-*)" ]; then
		initrd=$(readlink -e $KVM_ROOT_DIR/boot/initrd.img-* | head -n 1)
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
		-fsdev local,id=r,path=$KVM_ROOT_DIR,security_model=passthrough \
		-device virtio-9p-pci,fsdev=r,mount_tag=r \
		$KVM_PARAMETERS \
		-append "$KVM_KERNEL_PARAMETERS root=r rw rootfstype=9p rootflags=trans=virtio"
}

trap cleanup EXIT

echo "KVM_ROOT_DIR: $KVM_ROOT_DIR"
echo "KERNEL_PARAMETERS: '$KVM_KERNEL_PARAMETERS'"
echo "CPU: $(nproc)"
echo "MEMORY: $KVM_MEMORY"
echo "KVM_PARAMETERS: $KVM_PARAMETERS"

run
