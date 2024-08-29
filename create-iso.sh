#!/bin/bash
# create-iso.sh
# vim: set tabstop=4 shiftwidth=4 expandtab:

# Required by this script:
# p7zip-full p7zip-rar wget xorriso

# Hint:
# openssl passwd -5 -salt $RANDOM ubuntu

# To check which firmware booted:
# [ -d /sys/firmware/efi ] && echo UEFI || echo BIOS

PROJECT_HOME=$(pwd)
unset CDPATH
umask 022

# Modify as necessary

# jammy
# VERSION="22.04.4"

# noble
VERSION="24.04.1"

ISO="ubuntu-$VERSION-live-server-amd64.iso"
ISOURL="https://releases.ubuntu.com/$VERSION/$ISO"
ISODIR="ubuntu-$VERSION-autoinstall"
NEWISO="$ISODIR.iso"

wget -c $ISOURL

if [ ! -f "$ISO" ] ; then
    echo "failed to wget $ISO"
    exit 1
fi

if [ ! -f $PROJECT_HOME/meta-data.yml ] ; then
    echo "$PROJECT_HOME/meta-data.yml is missing"
    exit 1
fi

if [ ! -f $PROJECT_HOME/user-data.yml ] ; then
    echo "$PROJECT_HOME/user-data.yml is missing"
    exit 1
fi

mkdir -p $ISODIR || exit 1
cd $ISODIR
mkdir -p source-files || exit 1
[ -d source-files/boot ] || 7z -y x $PROJECT_HOME/$ISO -osource-files

cd source-files
[ -d boot/grub ] || exit 1
[ -d '[BOOT]' ] && mv '[BOOT]' ../BOOT

mkdir -p server || exit 1
cp -p $PROJECT_HOME/meta-data.yml server/meta-data
cp -p $PROJECT_HOME/user-data.yml server/user-data

(
    cd boot/grub
    grep -q "Ubuntu Server Autoinstall" grub.cfg && exit 0

    FIRSTITEM=$(grep -n -m1 '^menuentry' grub.cfg | awk -F: '{ print $1 }')
    INSERTHERE=$((FIRSTITEM - 1))

    (
        head -$INSERTHERE grub.cfg
        echo 'menuentry "Ubuntu Server Autoinstall" {'
        echo -e '\tset gfxpayload=keep'
        echo -e '\tlinux   /casper/vmlinuz autoinstall ds=nocloud\;s=/cdrom/server/  ---'
        echo -e '\tinitrd  /casper/initrd'
        echo '}'
        tail -n +$FIRSTITEM grub.cfg
    ) > grub.cfg.new

    mv -b grub.cfg.new grub.cfg
)

# To dig some info from the source ISO:
# xorriso -indev $PROJECT_HOME/$ISO -report_el_torito as_mkisofs

xorriso -as mkisofs -r \
    -V "Ubuntu-Server $VERSION LTS AUTO" \
    -o $PROJECT_HOME/$NEWISO \
    --grub2-mbr ../BOOT/1-Boot-NoEmul.img \
    -partition_offset 16 \
    --mbr-force-bootable \
    -append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b ../BOOT/2-Boot-NoEmul.img \
    -appended_part_as_gpt \
    -iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
    -c '/boot.catalog' \
    -b '/boot/grub/i386-pc/eltorito.img' \
    -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
    -eltorito-alt-boot \
    -e '--interval:appended_partition_2:::' \
    -no-emul-boot \
    .

exit $?
