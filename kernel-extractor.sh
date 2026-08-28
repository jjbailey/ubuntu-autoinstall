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

if [[ $EUID -ne 0 ]] ; then
    echo "ERROR: must be run as root -- mounting the ISO needs loopback privileges"
    echo "       try: sudo $0 $ISO $OUTDIR"
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

if ! mount -o loop,ro "$ISO" "$MNT" ; then
    echo "ERROR: Failed to mount ISO at $MNT"
    exit 1
fi

echo "[+] Searching for kernel, initrd, and squashfs root filesystem..."

KERNEL=""
INITRD=""
KERNEL_COUNT=0
INITRD_COUNT=0

SQUASHFS_LIST=()

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
        *.squashfs | install.img)
            SQUASHFS_LIST+=("$f")
            ;;
    esac
done < <(find "$MNT" -type f \( \
    -name 'linux' -o \
    -name 'vmlinuz*' -o \
    -name 'bzImage' -o \
    -name 'vmlinux' -o \
    -name 'initrd*' -o \
    -name 'initramfs*' -o \
    -name '*.squashfs' -o \
    -name 'install.img' \
    \) -print0 | sort -z)

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

echo "[+] Kernel : $KERNEL"
echo "[+] Initrd : $INITRD"
if [ "${#SQUASHFS_LIST[@]}" -gt 0 ] ; then
    echo "[+] Root filesystem images (${#SQUASHFS_LIST[@]}):"
    for f in "${SQUASHFS_LIST[@]}" ; do
        echo "      ${f#"$MNT"/}"
    done
else
    echo "[-] No .squashfs or install.img found (continuing)"
fi

echo "[+] Checking available disk space..."
TOTAL_SIZE=0
TOTAL_SIZE=$((TOTAL_SIZE + $(stat -c%s "$KERNEL")))
TOTAL_SIZE=$((TOTAL_SIZE + $(stat -c%s "$INITRD")))
for f in ${SQUASHFS_LIST[@]+"${SQUASHFS_LIST[@]}"} ; do
    TOTAL_SIZE=$((TOTAL_SIZE + $(stat -c%s "$f")))
done

AVAIL_KB=$(df -Pk "$OUTDIR" | awk 'NR==2 {print $4}')
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

for f in ${SQUASHFS_LIST[@]+"${SQUASHFS_LIST[@]}"} ; do
    cp -p "$f" "$OUTDIR"
    if [ ! -f "$OUTDIR/$(basename "$f")" ] || [ "$(stat -c%s "$f")" != "$(stat -c%s "$OUTDIR/$(basename "$f")")" ] ; then
        echo "ERROR: Failed to copy $(basename "$f")"
        exit 1
    fi
done

echo "[+] Done."
echo "Kernel: $OUTDIR/$(basename "$KERNEL")"
echo "Initrd: $OUTDIR/$(basename "$INITRD")"
for f in ${SQUASHFS_LIST[@]+"${SQUASHFS_LIST[@]}"} ; do
    echo "Root FS: $OUTDIR/$(basename "$f")"
done
