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
    # Only try to unmount if it's still mounted (in case of script interruption)
    if mountpoint -q "$MNTDIR" ; then
        umount "$MNTDIR"
    fi

    # Remove the mount directory if present
    if [ -d "$MNTDIR" ] ; then
        rmdir "$MNTDIR"
    fi
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
    cp "$f" "$MNTDIR/$(basename $f .yml)"
done

echo "Syncing..."
sync

echo "Unmounting image..."
umount "$MNTDIR"

echo "Checking image with fsck.fat..."
if ! fsck.fat -nv "$IMG" ; then
    echo "Image integrity check FAILED!"
    exit 1
fi

# Clean up the mount dir (handled by trap, but for immediate clarity)
if [ -d "$MNTDIR" ] ; then
    rmdir "$MNTDIR"
fi

echo "Done. Image $IMG is ready and verified."
