# ubuntu-autoinstall

This script automates the creation of a custom Ubuntu Server autoinstall ISO.
It downloads the official Ubuntu live server image, extracts its contents,
injects preconfigured `meta-data` and `user-data` files for cloud-init,
patches the GRUB menu to add an unattended installation option, and rebuilds
a bootable ISO with support for both BIOS and UEFI. The result is a self-contained
image (`ubuntu-<version>-autoinstall.iso`) that installs Ubuntu Server
automatically with no manual input required.

### Goals

- Build a self-contained, bootable Ubuntu Server ISO with automated
installation (unattended setup) enabled via pre-supplied cloud-init configs.
- Publish examples of cloud-config files for BIOS and UEFI boot with LVM.

### Required Packages (Ubuntu)

- curl
- p7zip-full
- p7zip-rar
- xorriso

## What This Script Does

1. **Configuration**
   - Targets a specific Ubuntu version (`24.04.3` by default).
   - Defines input ISO and output ISO names.

2. **Dependency & Input Checks**
   - Ensures required tools (`curl`, `7z`, `xorriso`) are installed.
   - Verifies that `meta-data.yml` and `user-data.yml` exist (used for cloud-init autoinstall).

3. **Download the Base ISO**
   - Fetches the official Ubuntu live server ISO from `releases.ubuntu.com`, resuming if interrupted.

4. **Extract ISO Contents**
   - Unpacks the ISO into a working directory with `7z`.
   - Moves boot-related files into place.

5. **Add Autoinstall Config Files**
   - Copies `meta-data.yml` and `user-data.yml` into `/server/` inside the ISO structure,
where cloud-init looks for them.

6. **Patch the GRUB Boot Menu**
   - Inserts a new boot menu entry called **"Ubuntu Server Autoinstall"**.
   - Configures it to boot with `autoinstall` mode and use the NoCloud data source
(`ds=nocloud;s=/cdrom/server/`).

7. **Rebuild ISO with Boot Support**
   - Uses `xorriso` to generate a new ISO that supports both BIOS and UEFI boot.
   - Preserves original boot loaders and adds GPT/MBR partition info for bootability.

8. **Final Output**
   - Produces a bootable custom ISO named `ubuntu-<version>-autoinstall.iso`.
   - This ISO can automatically install Ubuntu Server using the provided autoinstall config.

### Build

To build an ISO:

 1. Copy one of `user-data-bios.yml`, `user-data-efi.yml`, `user-data-bios+efi.yml` to `user-data.yml`
 2. Adjust the script and yaml files to meet your needs
 3. Run `./create-iso.sh`

The `user-data-bios+efi.yml` file auto-configures itself for either BIOS *or* UEFI, not both.

The `user-data.yml` file creates a system which should look something like the following (40GB test run):

```
ubuntu@ubuntu:~$ lsblk /dev/sda
NAME             MAJ:MIN RM SIZE RO TYPE MOUNTPOINTS
sda                8:0    0  40G  0 disk
├─sda1             8:1    0   1M  0 part
├─sda2             8:2    0   1G  0 part /boot
└─sda3             8:3    0  39G  0 part
  ├─vg1-lv_root  253:0    0   6G  0 lvm  /
  ├─vg1-lv_swap  253:1    0   4G  0 lvm  [SWAP]
  ├─vg1-lv_tmp   253:2    0   4G  0 lvm  /tmp
  ├─vg1-lv_home  253:3    0   4G  0 lvm  /home
  ├─vg1-lv_var   253:4    0   4G  0 lvm  /var
  ├─vg1-lv_log   253:5    0   4G  0 lvm  /var/log
  └─vg1-lv_audit 253:6    0   1G  0 lvm  /var/log/audit

ubuntu@ubuntu:~$ sudo pvs
  PV         VG  Fmt  Attr PSize   PFree
  /dev/sda3  vg1 lvm2 a--  <39.00g <12.00g

```

### Cloud-init Data on Separate Media

The `make-cidata.sh` script creates a floppy image for cloud-init.
The script creates `cidata.img`.
Next, change this line in the `create-iso.sh` script from
```
    linux   /casper/vmlinuz autoinstall ds=nocloud\\;s=/cdrom/server/  ---
```
to
```
    linux   /casper/vmlinuz autoinstall ds=nocloud  ---
```

### References

https://en.wikipedia.org/wiki/GUID_Partition_Table#Partition_type_GUIDs
https://askubuntu.com/questions/1403546/ubuntu-22-04-build-iso-both-mbr-and-efi

