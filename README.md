# Ubuntu Autoinstall ISO and Cloud-Init Seed Floppy Builder

This project simplifies the creation of:

- A custom Ubuntu Autoinstall ISO for fully automated installations
- A VFAT-formatted "cidata" floppy image with cloud-init configuration
  (NoCloud data source)

All processes are managed through a single `Makefile`.

## Features

- Automatic dependency checks for ISO builds and required-file checks
- Customizable GRUB menu
- Non-interactive scripts: controlled entirely via `make`
- VFAT floppy image production using a temporary mount point

## Typical Use Cases

- Provisioning multiple Ubuntu servers quickly and consistently in a
  datacenter or virtualized environment
- Automated lab or testbed setup
- Infrastructure as Code (IaC) deployments

## Requirements

### Ubuntu Host Packages

Install the following packages on your Ubuntu host:

```bash
sudo apt install curl p7zip-full xorriso dosfstools
```

**Note**: `sudo` is required for `make cidata` to create and mount the
floppy image as a loop device.

You also need roughly **8 GB free** on the build host: about 3 GB for the
downloaded ISO, the same again for the extracted tree, and the rebuilt ISO on
top.

## Preparation

Provide the following files in your project directory:

| File                    | Purpose                                         |
| ----------------------- | ----------------------------------------------- |
| `meta-data.yml`         | Cloud-init meta-data file (used by both ISO and |
|                         | floppy targets)                                 |
| `user-data.yml`         | Cloud-init user-data file (used by both ISO and |
|                         | floppy targets)                                 |
| `grub-autoinstall.menu` | GRUB menu entries for the autoinstall ISO       |

The repo includes three `user-data` variants to choose from:

- `user-data-bios.yml` — BIOS-only installs
- `user-data-efi.yml` — EFI-only installs
- `user-data-bios+efi.yml` — dual BIOS/EFI installs

Copy the appropriate one to `user-data.yml` before building:

```bash
cp user-data-bios+efi.yml user-data.yml
```

The `ubuntu` user's password is `ubuntu`. This is deliberately a **bootstrap
credential**: these hosts are handed to configuration management immediately
after install, and the first pass rotates it. Treat the window between first
boot and that pass as the exposure, and keep provisioning on a trusted
segment.

If you are not following that workflow, change the hash in the `identity`
section before deploying — generate a replacement with `openssl passwd -6`.

### Minimum Target Disk Size

The fixed logical volumes total 27 GiB before `lvm_part` (`size: -1`) claims
anything, so the **install disk** must be at least **28 GiB** — 27 GiB of
volumes plus a 1 GiB boot partition and the 1 MiB BIOS grub reserve.

A 20 GB VM disk — a natural default — fails during partitioning. This is
separate from the build-host space noted above. Shrink the `lvm_partition`
sizes if you want a smaller target.

### Example `grub-autoinstall.menu`

```text
menuentry "Ubuntu Server Autoinstall" {
    set gfxpayload=keep
    linux /casper/vmlinuz autoinstall ds=nocloud\;s=/cdrom/server/ ---
    initrd /casper/initrd
}
```

## Usage

### 1. Create the Custom Ubuntu Autoinstall ISO

Run:

```bash
make
```

This command:

- Downloads the Ubuntu server ISO
- Extracts it
- Adds autoinstall files
- Patches GRUB
- Creates `ubuntu-26.04-autoinstall.iso` by default

You can boot this ISO in a virtual machine or on physical hardware for
an unattended installation.

### 2. Create the Cloud-Init "cidata" VFAT Floppy Image

Run (requires root privileges):

```bash
sudo make cidata
```

**Output**: `cidata.img` (1.44MB VFAT-formatted floppy image)

**Contents**:

- `meta-data`
- `user-data`

Use this image as a secondary disk ("cidata") in your hypervisor for
NoCloud-based installs. For example:

- **Proxmox**: Add as a "floppy" to the VM
- **QEMU**: Use with `-drive file=cidata.img,if=floppy,format=raw,readonly=on`

### 3. Clean Up Build Artifacts

Run:

```bash
make clean
```

`clean` deliberately keeps the downloaded ISO so you do not have to re-fetch
several GB. Use `make distclean` to remove that as well.

### 4. Extract Kernel/Initrd for Netboot (`kernel-extractor.sh`)

`kernel-extractor.sh` mounts an Ubuntu ISO (loopback) and copies out the
kernel, initrd, and every root filesystem image — useful for iPXE or other
netboot setups where the kernel and initrd are served directly rather than
booted from an ISO. This script is standalone and not wired into the
`Makefile`.

It copies **all** `.squashfs` images, not just one. Since roughly 23.04 the
live-server ISO no longer ships a single `filesystem.squashfs`; it carries a
layered set (`ubuntu-server-minimal.squashfs`, then
`ubuntu-server-minimal.ubuntu-server.squashfs`, and so on) that is stacked at
boot and is useless a layer at a time.

```bash
sudo ./kernel-extractor.sh <path-to.iso> <output-dir>
```

Requires root (or equivalent loopback-mount privileges) to mount the ISO.

## Customization

- **Ubuntu Release**: Edit `VERSION` in the `Makefile` to change the
  Ubuntu release. The current default is `26.04`.
- **GRUB Menu**: Modify `grub-autoinstall.menu` to add or edit GRUB menu
  entries, including different kernel arguments for multiple install modes.
  Rename the entries freely — the patch rule brackets whatever it inserts
  between `UBUNTU-AUTOINSTALL-MENU-BEGIN` / `-END` comment markers and
  rewrites that block on every build, so menu edits are picked up and the
  entries never accumulate. Do not hand-edit between those markers; the next
  build discards it. The patch rule also sets `set default="0"` so the
  autoinstall entry is the one that boots unattended.
- **Cloud-Init Configuration**: Use valid cloud-init syntax in
  `meta-data.yml` and `user-data.yml`.

### Example Seed `grub-autoinstall.menu`

```text
menuentry "Ubuntu Server Autoinstall" {
    set gfxpayload=keep
    linux /casper/vmlinuz autoinstall ds=nocloud ---
    initrd /casper/initrd
}
```

When the cloud-init files are on a floppy, some documentation recommends
setting the nocloud device:

```text
    linux /casper/vmlinuz autoinstall ds=nocloud\;s=/dev/fd0/ ---
```

### Example iPXE Menu Entry

The Ubuntu Autoinstall ISO can be used in a iPXE setup. Use
`kernel-extractor.sh` to pull `vmlinuz` and `initrd` out of the ISO built
above. The following iPXE menu uses the cloud-init user-data file in the uai
directory on an iPXE server:

```text
/tftpboot/uai
├── /tftpboot/uai/initrd
├── /tftpboot/uai/server
│   ├── /tftpboot/uai/server/meta-data
│   └── /tftpboot/uai/server/user-data
├── /tftpboot/uai/uai.iso
└── /tftpboot/uai/vmlinuz
```

```text
:uai
kernel http://10.0.0.6/uai/vmlinuz
initrd http://10.0.0.6/uai/initrd
imgargs vmlinuz initrd=initrd ip=dhcp \
    url=http://10.0.0.6/uai/uai.iso autoinstall \
    cloud-config-url=http://10.0.0.6/uai/server/user-data ---
boot
```

## Troubleshooting

- **Missing Dependencies**: The default `make` target checks for required
  commands before building the ISO. The `cidata` target checks its own
  (`mkfs.vfat`, `fsck.fat`, `mount`, `umount`, `dd`).
- **Root Privileges**: If you see "must be run as root" when building
  `cidata`, use `sudo make cidata`.
- **Autoinstall Issues**: If the VM does not detect the autoinstall from
  the ISO, try attaching `cidata.img` as a floppy or secondary disk.

### References

<https://en.wikipedia.org/wiki/GUID_Partition_Table#Partition_type_GUIDs>

<https://askubuntu.com/q/1403546>

## Author, License, and Disclaimer

- **Author**: Copyright (c) 2023-2026 Jack Bailey
- **License**: MIT
- **Disclaimer**: [Use at your own risk!](MAINTENANCE-TERMS.md)
