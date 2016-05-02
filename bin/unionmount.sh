#!/bin/bash

RO_DIR=$1
CACHE_DIR=$2
MOUNT_POINT=$3

FS_LIST=$( (cat /proc/filesystems | awk '{print $NF}' | sed '/^$/d'; ls -1 /lib/modules/$(uname -r)/kernel/fs) | sort -u )

fs_available() {
	# return 0 -> available
	for fs in $FS_LIST
	do
		if [ "$1" == "$fs" ]; then
			return 0
		fi
	done
	return 1
}


if fs_available "overlayfs" ; then
	echo "mounting overlayfs"
	mkdir ${CACHE_DIR}.overlayfs
	mount -t overlay -o lowerdir=${RO_DIR},upperdir=${CACHE_DIR},workdir=${CACHE_DIR}.overlayfs none ${MOUNT_POINT} || exit 2
elif fs_available "aufs" ; then
	echo "mounting aufs"
	mount -t aufs -o br=${CACHE_DIR}=rw:${RO_DIR}=ro -o udba=reval none ${MOUNT_POINT} || exit 2
else
	return 1
fi
