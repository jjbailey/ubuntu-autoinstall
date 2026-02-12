#!/bin/bash
# kernel-extractor.sh
# vim: set tabstop=4 shiftwidth=4 expandtab:

if [[ $# -ne 2 ]] ; then
    echo "Usage: $0 <path-to.iso> <output-dir>"
    exit 1
fi

set -euo pipefail

ISO="$1"
OUTDIR="$2"

if [[ ! -f $ISO ]] ; then
    echo "ERROR: ISO file not found: $ISO"
    exit 1
fi

mkdir -p "$OUTDIR"

if [ ! -w "$OUTDIR" ] ; then
    echo "ERROR: Output directory not writable: $OUTDIR"
    exit 1
fi

MNT=$(mktemp -d)

cleanup()
{
    umount "$MNT" 2> /dev/null || true
    rmdir "$MNT" 2> /dev/null || true
}

trap cleanup EXIT

echo "[+] Mounting ISO..."
mount -o loop,ro "$ISO" "$MNT"

if ! mountpoint -q "$MNT" ; then
    echo "ERROR: Failed to mount ISO at $MNT"
    exit 1
fi

echo "[+] Searching for kernel, initrd, and squashfs root filesystem..."

KERNEL=""
INITRD=""
SQUASHFS=""
KERNEL_COUNT=0
INITRD_COUNT=0
SQUASHFS_COUNT=0

while IFS= read -r -d '' f ; do
    fname="$(basename "$f")"
    case "$fname" in
        linux | vmlinuz* | bzImage | vmlinux)
            if [ -z "$KERNEL" ] ; then
                KERNEL="$f"
            fi
            KERNEL_COUNT=$((KERNEL_COUNT + 1))
            ;;
        initrd* | initramfs*)
            if [ -z "$INITRD" ] ; then
                INITRD="$f"
            fi
            INITRD_COUNT=$((INITRD_COUNT + 1))
            ;;
        rootfs.squashfs | filesystem.squashfs)
            if [ -z "$SQUASHFS" ] ; then
                SQUASHFS="$f"
            fi
            SQUASHFS_COUNT=$((SQUASHFS_COUNT + 1))
            ;;
    esac
done < <(find "$MNT" -type f \( \
    -name 'linux' -o \
    -name 'vmlinuz*' -o \
    -name 'bzImage' -o \
    -name 'vmlinux' -o \
    -name 'initrd*' -o \
    -name 'initramfs*' -o \
    -name 'rootfs.squashfs' -o \
    -name 'filesystem.squashfs' \
    \) -print0)

if [[ -z $KERNEL || -z $INITRD ]] ; then
    echo "[-] Failed to locate kernel or initrd"
    exit 1
fi

if [ "$KERNEL_COUNT" -gt 1 ] ; then
    echo "[!] Warning: Multiple kernel files found ($KERNEL_COUNT), using $KERNEL"
fi
if [ "$INITRD_COUNT" -gt 1 ] ; then
    echo "[!] Warning: Multiple initrd files found ($INITRD_COUNT), using $INITRD"
fi
if [ "$SQUASHFS_COUNT" -gt 1 ] ; then
    echo "[!] Warning: Multiple squashfs files found ($SQUASHFS_COUNT), using $SQUASHFS"
fi

echo "[+] Kernel : $KERNEL"
echo "[+] Initrd : $INITRD"
if [[ -n $SQUASHFS ]] ; then
    echo "[+] Found squashfs: $SQUASHFS"
else
    echo "[-] rootfs.squashfs/filesystem.squashfs not found (continuing)"
fi

echo "[+] Checking available disk space..."
TOTAL_SIZE=0
TOTAL_SIZE=$((TOTAL_SIZE + $(stat -c%s "$KERNEL")))
TOTAL_SIZE=$((TOTAL_SIZE + $(stat -c%s "$INITRD")))
if [ -n "$SQUASHFS" ] ; then
    TOTAL_SIZE=$((TOTAL_SIZE + $(stat -c%s "$SQUASHFS")))
fi
AVAIL_KB=$(df -k "$OUTDIR" | awk 'NR==2 {print $4}')
TOTAL_SIZE_KB=$(((TOTAL_SIZE + 1023) / 1024))
if [ "$AVAIL_KB" -lt "$TOTAL_SIZE_KB" ] ; then
    echo "ERROR: Not enough space in $OUTDIR (need ${TOTAL_SIZE_KB} KB, available ${AVAIL_KB} KB)"
    exit 1
fi

echo "[+] Copying files to $OUTDIR..."
cp -p "$KERNEL" "$OUTDIR"
if [ ! -f "$OUTDIR/$(basename "$KERNEL")" ] || [ "$(stat -c%s "$KERNEL")" != "$(stat -c%s "$OUTDIR/$(basename "$KERNEL")")" ] ; then
    echo "ERROR: Failed to copy kernel"
    exit 1
fi
cp -p "$INITRD" "$OUTDIR"
if [ ! -f "$OUTDIR/$(basename "$INITRD")" ] || [ "$(stat -c%s "$INITRD")" != "$(stat -c%s "$OUTDIR/$(basename "$INITRD")")" ] ; then
    echo "ERROR: Failed to copy initrd"
    exit 1
fi
if [[ -n $SQUASHFS ]] ; then
    cp -p "$SQUASHFS" "$OUTDIR"
    if [ ! -f "$OUTDIR/$(basename "$SQUASHFS")" ] || [ "$(stat -c%s "$SQUASHFS")" != "$(stat -c%s "$OUTDIR/$(basename "$SQUASHFS")")" ] ; then
        echo "ERROR: Failed to copy squashfs"
        exit 1
    fi
fi

echo "[+] Done."
echo "Kernel: $OUTDIR/$(basename "$KERNEL")"
echo "Initrd: $OUTDIR/$(basename "$INITRD")"
if [[ -n $SQUASHFS ]] ; then
    echo "SquashFS: $OUTDIR/$(basename "$SQUASHFS")"
fi
