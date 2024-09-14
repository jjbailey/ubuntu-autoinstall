# ubuntu-autoinstall

Create an ISO for Ubuntu LTS unattended auto-install.

### Goals

- Create an ISO that boots itself with a cloud-config auto-installer.
- Publish examples of cloud-config files for BIOS and UEFI boot with LVM.

### Required packages (Ubuntu)

- p7zip-full
- p7zip-rar
- wget
- xorriso

### Build

The `create-iso.sh` script downloads a version of the Ubuntu LTS ISO, extracts the contents, adds a cloud-config with meta-data.yml, user-data.yml, and a grub.cfg entry.  The script then creates a new, bootable ISO.

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

### CREDITS

Credit to Dr. Donald Kinghorn who did all the p7zip and xorriso heavy lifting.

Credit to Andrew Lowther for the early-commands cleverness.

Credit to many others who posted sample configs for the various ideas they presented.
