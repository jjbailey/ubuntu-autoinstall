#!/usr/bin/env bash
# kernel-extractor.sh
# vim: set tabstop=4 shiftwidth=4 expandtab:

set -euo pipefail

if [[ $# -ne 2 ]] ; then
    echo "Usage: $0 <path-to.iso> <output-dir>"
    exit 1
fi

ISO="$1"
OUTDIR="$2"

if [[ ! -f $ISO ]] ; then
    echo "ERROR: ISO file not found: $ISO"
    exit 1
fi

mkdir -p "$OUTDIR"

MNT=$(mktemp -d)

cleanup()
{
    umount "$MNT" 2> /dev/null || true
    rmdir "$MNT" 2> /dev/null || true
}

trap cleanup EXIT

echo "[+] Mounting ISO..."
mount -o loop,ro "$ISO" "$MNT"

echo "[+] Searching for kernel, initrd, and squashfs root filesystem..."

KERNEL=""
INITRD=""
SQUASHFS=""

while IFS= read -r -d '' f ; do
    fname="$(basename "$f")"
    case "$fname" in
        linux | vmlinuz | vmlinuz-linux)
            [ -z "$KERNEL" ] && KERNEL="$f"
            ;;
        initrd | initrd.img | initrd.gz | initrd.xz)
            [ -z "$INITRD" ] && INITRD="$f"
            ;;
        rootfs.squashfs | filesystem.squashfs)
            [ -z "$SQUASHFS" ] && SQUASHFS="$f"
            ;;
    esac
done < <(find "$MNT" -type f \( \
    -name 'linux' -o \
    -name 'vmlinuz*' -o \
    -name 'initrd*' -o \
    -name 'rootfs.squashfs' -o \
    -name 'filesystem.squashfs' \
    \) -print0)

if [[ -z $KERNEL || -z $INITRD ]] ; then
    echo "[-] Failed to locate kernel or initrd"
    exit 1
fi

echo "[+] Kernel : $KERNEL"
echo "[+] Initrd : $INITRD"
if [[ -n $SQUASHFS ]] ; then
    echo "[+] Found squashfs: $SQUASHFS"
else
    echo "[-] rootfs.squashfs/filesystem.squashfs not found (continuing)"
fi

echo "[+] Copying files to $OUTDIR..."
cp -p "$KERNEL" "$OUTDIR"
cp -p "$INITRD" "$OUTDIR"
if [[ -n $SQUASHFS ]] ; then
    cp -p "$SQUASHFS" "$OUTDIR"
fi

echo "[+] Done."
echo "Kernel: $OUTDIR/$(basename "$KERNEL")"
echo "Initrd: $OUTDIR/$(basename "$INITRD")"
if [[ -n $SQUASHFS ]] ; then
    echo "SquashFS: $OUTDIR/$(basename "$SQUASHFS")"
fi
