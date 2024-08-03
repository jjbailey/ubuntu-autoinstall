# ubuntu-autoinstall

Create an ISO for Ubuntu 22.04 unattended auto-install.

### Goals

- Create an ISO that boots itself with a cloud-config auto-installer.
- Publish an example of a cloud-config file that is hard to get right and easy to get wrong.

### Required packages (Ubuntu)

- p7zip-full
- p7zip-rar
- wget
- xorriso

### Build

The ```create-iso.sh``` script downloads the Ubuntu 22.04 ISO, extracts the contents, adds a cloud-config with meta-data.yml, user-data.yml, and a grub.cfg entry.  The script then creates a new, bootable ISO.

The ```user-data.yml``` file configures BIOS boot and has the following layout (40GB test run):
```
ubuntu@ubuntu:~$ lsblk
NAME             MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda                8:0    0   40G  0 disk 
├─sda1             8:1    0    1M  0 part 
├─sda2             8:2    0    1G  0 part /boot
└─sda3             8:3    0   39G  0 part 
  ├─vg1-lv_root  253:0    0    6G  0 lvm  /
  ├─vg1-lv_swap  253:1    0    4G  0 lvm  [SWAP]
  ├─vg1-lv_tmp   253:2    0    4G  0 lvm  /tmp
  ├─vg1-lv_home  253:3    0    4G  0 lvm  /home
  ├─vg1-lv_var   253:4    0    4G  0 lvm  /var
  ├─vg1-lv_log   253:5    0    4G  0 lvm  /var/log
  └─vg1-lv_audit 253:6    0    1G  0 lvm  /var/log/audit

ubuntu@ubuntu:~$ sudo pvs
  PV         VG  Fmt  Attr PSize   PFree  
  /dev/sda3  vg1 lvm2 a--  <39.00g <12.00g

```

Adjust the script and yaml files to fit your needs.

The ubuntu user's password is guessable (cough).

### TODO

- Create an EFI boot ISO
- Create an ISO that boots BIOS or EFI

### CREDITS

Special credit to Dr. Donald Kinghorn who did all the p7zip and xorriso heavy lifting.

Credit to many others who posted sample configs, both working and broken, for the various ideas they presented.

