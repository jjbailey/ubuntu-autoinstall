#!/bin/bash
# create-iso.sh
# vim: set tabstop=4 shiftwidth=4 expandtab:

# Required by this script:
# curl p7zip-full p7zip-rar xorriso

# Hint:
# openssl passwd -5 -salt $RANDOM ubuntu

# To check which firmware booted:
# [ -d /sys/firmware/efi ] && echo UEFI || echo BIOS

set -euo pipefail

# Configuration -- Change this to target a different Ubuntu version
VERSION="24.04.3"

ISO="ubuntu-${VERSION}-live-server-amd64.iso"
ISO_URL="https://releases.ubuntu.com/${VERSION}/${ISO}"
ISODIR="ubuntu-${VERSION}-autoinstall"
NEWISO="${ISODIR}.iso"

PROJECT_HOME="$(pwd)"

check_dependencies()
{
    local deps=(curl 7z xorriso)
    for bin in "${deps[@]}" ; do
        command -v "${bin}" > /dev/null 2>&1 || {
            echo "Error: '${bin}' is not installed" >&2
            exit 1
        }
    done
}

download_iso()
{
    echo "Downloading ISO..."
    curl -C - --remote-time -o "${ISO}" "${ISO_URL}"
    [[ -f ${ISO} ]] || {
        echo "Failed to download ISO"
        exit 1
    }
}

check_required_files()
{
    for file in meta-data.yml user-data.yml ; do
        [[ -f "${PROJECT_HOME}/${file}" ]] || {
            echo "Missing required file: ${file}"
            exit 1
        }
    done
}

extract_iso()
{
    # Clean up previous run
    [[ -d ${ISODIR} ]] && rm -fr "${ISODIR}"

    mkdir -p "${ISODIR}/source-files"
    cd "${ISODIR}"
    if [[ ! -d source-files/boot ]] ; then
        7z x -y "${PROJECT_HOME}/${ISO}" -osource-files
    fi
    [[ -d source-files/boot/grub ]] || {
        echo "Extraction failed or unexpected ISO structure"
        exit 1
    }

    # Move [BOOT] directory (created by 7z)
    [[ -d source-files/\[BOOT\] ]] && mv source-files/\[BOOT\] BOOT
}

add_autoinstall_files()
{
    mkdir -p "source-files/server"
    cp -p "${PROJECT_HOME}/meta-data.yml" "source-files/server/meta-data"
    cp -p "${PROJECT_HOME}/user-data.yml" "source-files/server/user-data"
}

patch_grub()
{
    local grub_cfg="source-files/boot/grub/grub.cfg"
    echo "Patching GRUB..."

    grep -q "Ubuntu Server Autoinstall" "${grub_cfg}" && return 0

    local first_entry
    first_entry=$(grep -n -m1 '^menuentry' "${grub_cfg}" | cut -d: -f1)
    local insert_line=$((first_entry - 1))

    {
        head -n "${insert_line}" "${grub_cfg}"
        cat << EOF
menuentry "Ubuntu Server Autoinstall" {
    set gfxpayload=keep
    linux   /casper/vmlinuz autoinstall ds=nocloud\\;s=/cdrom/server/  ---
    initrd  /casper/initrd
}
EOF
        tail -n +"${first_entry}" "${grub_cfg}"
    } > "${grub_cfg}.new"

    mv -b "${grub_cfg}.new" "${grub_cfg}"
}

build_iso()
{
    # multiple boot images (BIOS and EFI) with -eltorito-alt-boot each
    # must have its own -b, -no-emul-boot, etc., in this exact sequence

    echo "Building ISO image..."
    cd source-files

    xorriso -as mkisofs -r \
        -V "Ubuntu-Server $VERSION LTS AUTO" \
        -o "$PROJECT_HOME/$NEWISO" \
        --grub2-mbr ../BOOT/1-Boot-NoEmul.img \
        -partition_offset 16 \
        --mbr-force-bootable \
        -append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b ../BOOT/2-Boot-NoEmul.img \
        -appended_part_as_gpt \
        -iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
        -c '/boot.catalog' \
        -b '/boot/grub/i386-pc/eltorito.img' \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        --grub2-boot-info \
        -eltorito-alt-boot \
        -e '--interval:appended_partition_2:::' \
        -no-emul-boot \
        .
}

main()
{
    echo "=== Ubuntu Autoinstall ISO Builder ==="
    echo "Target Version: ${VERSION}"
    echo "Working Directory: ${PROJECT_HOME}"
    echo

    check_dependencies
    check_required_files
    download_iso
    extract_iso
    add_autoinstall_files
    patch_grub
    build_iso

    echo
    echo "✅ ISO created successfully: ${PROJECT_HOME}/${NEWISO}"
}

main "$@"
