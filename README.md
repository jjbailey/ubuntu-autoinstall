# Ubuntu Autoinstall ISO and Cloud-Init Seed Floppy Builder

This project simplifies the creation of:

- A custom Ubuntu Autoinstall ISO for fully automated installations
- A VFAT-formatted "cidata" floppy image with cloud-init configuration
  (NoCloud data source)

All processes are managed through a single `Makefile`.

## Features

- Automatic dependency and file checks
- Customizable GRUB menu
- Non-interactive scripts: controlled entirely via `make`
- Safe floppy image production: uses a temporary mount point and cleans
  up after errors

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
- Creates `ubuntu-24.04.4-autoinstall.iso`

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

## Customization

- **Ubuntu Release**: Edit `VERSION` in the `Makefile` to change the
  Ubuntu release.
- **GRUB Menu**: Modify `grub-autoinstall.menu` to add or edit GRUB menu
  entries, including different kernel arguments for multiple install modes.
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

The Ubuntu Autoinstall ISO can be used in a iPXE setup. The following iPXE
menu uses the cloud-init user-data file in the uai directory on an iPXE server:

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

- **Missing Dependencies**: The first run checks for required commands.
  Install any missing packages as indicated in error messages.
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
