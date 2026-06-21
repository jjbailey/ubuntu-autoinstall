#!/usr/bin/env bash
# kernel-extractor.sh
# vim: set tabstop=4 shiftwidth=4 expandtab:

set -euo pipefail

usage()
{
    echo "Usage: $0 <path-to.iso> <output-dir>" >&2
}

die()
{
    echo "ERROR: $*" >&2
    exit 1
}

require_cmd()
{
    local cmd

    for cmd in "$@" ; do
        command -v "$cmd" > /dev/null 2>&1 || die "Required command not found: $cmd"
    done
}

score_path()
{
    local path=$1
    local score=999

    case "$path" in
        */casper/vmlinuz | */casper/vmlinuz.* | */casper/initrd | */casper/initrd.*)
            score=0
            ;;
        */boot/vmlinuz | */boot/vmlinuz.* | */boot/initrd | */boot/initrd.*)
            score=5
            ;;
        */live/vmlinuz | */live/vmlinuz.* | */live/initrd | */live/initrd.*)
            score=10
            ;;
    esac

    printf '%03d:%s\n' "$score" "$path"
}

pick_best_match()
{
    local best_score=1000
    local best_path=""
    local entry score path

    for entry in "$@" ; do
        IFS=: read -r score path <<< "$(score_path "$entry")"
        if ((score < best_score)) ; then
            best_score=$score
            best_path=$path
        fi
    done

    printf '%s\n' "$best_path"
}

copy_and_verify()
{
    local src=$1
    local dst=$2

    cp -p "$src" "$dst"

    if [[ ! -f $dst ]] ; then
        die "Failed to copy $(basename "$src")"
    fi

    if [[ $(stat -c%s "$src") -ne $(stat -c%s "$dst") ]] ; then
        die "Copied file size mismatch for $(basename "$src")"
    fi
}

if [[ $# -ne 2 ]] ; then
    usage
    exit 1
fi

require_cmd mount umount mountpoint find stat df cp mktemp sort

if ((EUID != 0)) ; then
    die "This script must be run as root so it can mount the ISO"
fi

readonly ISO=$1
readonly OUTDIR=$2

[[ -f $ISO ]] || die "ISO file not found: $ISO"

mkdir -p "$OUTDIR"
[[ -w $OUTDIR ]] || die "Output directory not writable: $OUTDIR"

MNT=$(mktemp -d)

cleanup()
{
    if mountpoint -q "$MNT" ; then
        umount "$MNT"
    fi
    rmdir "$MNT" 2> /dev/null || true
}

trap cleanup EXIT

echo "[+] Mounting ISO..."
mount -o loop,ro "$ISO" "$MNT"
mountpoint -q "$MNT" || die "Failed to mount ISO at $MNT"

echo "[+] Searching for kernel, initrd, and squashfs root filesystem..."

declare -a kernels=()
declare -a initrds=()
declare -a squashfses=()

while IFS= read -r -d '' path ; do
    case "$(basename "$path")" in
        linux | vmlinuz* | bzImage | vmlinux)
            kernels+=("$path")
            ;;
        initrd* | initramfs*)
            initrds+=("$path")
            ;;
        rootfs.squashfs | filesystem.squashfs)
            squashfses+=("$path")
            ;;
    esac
done < <(
    find "$MNT" -type f \(
    -name 'linux' -o
    -name 'vmlinuz*' -o
    -name 'bzImage' -o
    -name 'vmlinux' -o
    -name 'initrd*' -o
    -name 'initramfs*' -o
    -name 'rootfs.squashfs' -o
    -name 'filesystem.squashfs'
    \) -print0 | sort -z
)

((${#kernels[@]} > 0)) || die "Failed to locate a kernel in $ISO"
((${#initrds[@]} > 0)) || die "Failed to locate an initrd in $ISO"

KERNEL=$(pick_best_match "${kernels[@]}")
INITRD=$(pick_best_match "${initrds[@]}")
SQUASHFS=""
if ((${#squashfses[@]} > 0)) ; then
    SQUASHFS=$(pick_best_match "${squashfses[@]}")
fi

if ((${#kernels[@]} > 1)) ; then
    echo "[!] Warning: Multiple kernel files found (${#kernels[@]}), using $KERNEL"
fi
if ((${#initrds[@]} > 1)) ; then
    echo "[!] Warning: Multiple initrd files found (${#initrds[@]}), using $INITRD"
fi
if ((${#squashfses[@]} > 1)) ; then
    echo "[!] Warning: Multiple squashfs files found (${#squashfses[@]}), using $SQUASHFS"
fi

echo "[+] Kernel : $KERNEL"
echo "[+] Initrd : $INITRD"
if [[ -n $SQUASHFS ]] ; then
    echo "[+] SquashFS: $SQUASHFS"
else
    echo "[-] rootfs.squashfs/filesystem.squashfs not found (continuing)"
fi

echo "[+] Checking available disk space..."
TOTAL_SIZE=$(stat -c%s "$KERNEL")
TOTAL_SIZE=$((TOTAL_SIZE + $(stat -c%s "$INITRD")))
if [[ -n $SQUASHFS ]] ; then
    TOTAL_SIZE=$((TOTAL_SIZE + $(stat -c%s "$SQUASHFS")))
fi

AVAIL_KB=$(df -Pk "$OUTDIR" | awk 'NR==2 {print $4}')
TOTAL_SIZE_KB=$(((TOTAL_SIZE + 1023) / 1024))
if ((AVAIL_KB < TOTAL_SIZE_KB)) ; then
    die "Not enough space in $OUTDIR (need ${TOTAL_SIZE_KB} KB, available ${AVAIL_KB} KB)"
fi

echo "[+] Copying files to $OUTDIR..."

KERNEL_DST="$OUTDIR/$(basename "$KERNEL")"
INITRD_DST="$OUTDIR/$(basename "$INITRD")"
copy_and_verify "$KERNEL" "$KERNEL_DST"
copy_and_verify "$INITRD" "$INITRD_DST"

if [[ -n $SQUASHFS ]] ; then
    SQUASHFS_DST="$OUTDIR/$(basename "$SQUASHFS")"
    copy_and_verify "$SQUASHFS" "$SQUASHFS_DST"
fi

echo "[+] Done."
echo "Kernel: $KERNEL_DST"
echo "Initrd: $INITRD_DST"
if [[ -n $SQUASHFS ]] ; then
    echo "SquashFS: $SQUASHFS_DST"
fi
