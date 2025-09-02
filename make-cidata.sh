#!/bin/bash
# make-cidata.sh
# vim: set tabstop=4 shiftwidth=4 expandtab:

# example usage in a grub menu entry:

# menuentry "Ubuntu Server Autoinstall" {
#     set     gfxpayload=keep
#     linux   /casper/vmlinuz autoinstall console=ttyS0,115200 ds=nocloud ---
#     initrd  /casper/initrd
# }

set -euo pipefail

IMG=cidata.img
MNTDIR=$(mktemp -d /tmp/cidata.XXXXXX)

cleanup()
{
    if mountpoint -q "$MNTDIR" ; then
        umount "$MNTDIR"
    fi

    rmdir "$MNTDIR"
}

trap cleanup EXIT

if [[ -f $IMG ]] ; then
    echo "Removing old $IMG"
    rm -f "$IMG"
fi

echo "Creating image..."
dd if=/dev/zero of="$IMG" bs=1024 count=1440 status=progress

echo "Formatting image..."
mkfs.vfat -n cidata "$IMG"

echo "Mounting image..."
mount -o loop "$IMG" "$MNTDIR"

for f in meta-data.yml user-data.yml ; do
    if [[ ! -f $f ]] ; then
        echo "Missing file: $f" >&2
        exit 1
    fi

    echo "Copying $f..."
    cp $f $MNTDIR/$(basename $f .yml)
done

echo "Syncing..."
sync

echo "Done. Unmounting..."
# (trap will clean up and unmount)
