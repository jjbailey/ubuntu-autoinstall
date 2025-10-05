# Makefile: Ubuntu Autoinstall ISO Builder & Cloud-Init VFAT Floppy (cidata.img)

VERSION := 24.04.3
ISO := ubuntu-$(VERSION)-live-server-amd64.iso
ISO_URL := https://releases.ubuntu.com/$(VERSION)/$(ISO)
ISODIR := ubuntu-$(VERSION)-autoinstall
NEWISO := $(ISODIR).iso
PROJECT_HOME := $(CURDIR)

CIDATA := cidata.img

DEPS := curl 7z xorriso mkfs.vfat mount umount dd fsck.fat

.PHONY: all check-deps check-files clean download extract addfiles patch build-iso cidata

all: check-deps check-files $(NEWISO)

check-deps:
	@for dep in $(DEPS); do \
		command -v $$dep >/dev/null 2>&1 || { echo "'$$dep' is not installed"; exit 1; }; \
	done

check-files:
	@test -f meta-data.yml || { echo "Missing meta-data.yml"; exit 1; }
	@test -f user-data.yml  || { echo "Missing user-data.yml"; exit 1; }
	@test -f grub-autoinstall.menu || { echo "Missing grub-autoinstall.menu"; exit 1; }

download: $(ISO)
$(ISO):
	curl -C - --remote-time -o "$@" "$(ISO_URL)"

extract: $(ISODIR)/source-files/boot/grub/grub.cfg

$(ISODIR)/source-files/boot/grub/grub.cfg: $(ISO)
	rm -rf $(ISODIR)
	mkdir -p $(ISODIR)/source-files
	cd $(ISODIR) && 7z x -y "$(PROJECT_HOME)/$(ISO)" -osource-files
	test -d $(ISODIR)/source-files/boot/grub
	@if [ -d $(ISODIR)/source-files/\[BOOT\] ]; then mv $(ISODIR)/source-files/\[BOOT\] $(ISODIR)/BOOT; fi

addfiles: $(ISODIR)/source-files/server/user-data $(ISODIR)/source-files/server/meta-data

$(ISODIR)/source-files/server/user-data: user-data.yml | extract
	mkdir -p $(ISODIR)/source-files/server
	cp -p user-data.yml $(ISODIR)/source-files/server/user-data

$(ISODIR)/source-files/server/meta-data: meta-data.yml | extract
	mkdir -p $(ISODIR)/source-files/server
	cp -p meta-data.yml $(ISODIR)/source-files/server/meta-data

patch: $(ISODIR)/source-files/boot/grub/grub.cfg addfiles grub-autoinstall.menu
	@GRUB_CFG="$(ISODIR)/source-files/boot/grub/grub.cfg"; \
    MENU_IN="$(PROJECT_HOME)/grub-autoinstall.menu"; \
    if ! grep -q "Ubuntu Server Autoinstall" $$GRUB_CFG; then \
        FIRST_ENTRY=$$(grep -n -m1 '^menuentry' $$GRUB_CFG | cut -d: -f1); \
        INSERT_LINE=$$(($$FIRST_ENTRY - 1)); \
        head -n $$INSERT_LINE $$GRUB_CFG > $$GRUB_CFG.new; \
        cat $$MENU_IN >> $$GRUB_CFG.new; \
        tail -n +$$FIRST_ENTRY $$GRUB_CFG >> $$GRUB_CFG.new; \
        mv $$GRUB_CFG.new $$GRUB_CFG; \
        echo "Patched GRUB menu"; \
    else \
        echo "GRUB already patched."; \
    fi

grub-autoinstall.menu:
	@echo "Please create a grub-autoinstall.menu file with your custom GRUB menu entries." ; exit 1

$(NEWISO): patch
	cd $(ISODIR)/source-files && xorriso -as mkisofs -r \
	-V "Ubuntu-Server $(VERSION) LTS AUTO" \
	-o "$(PROJECT_HOME)/$(NEWISO)" \
	--grub2-mbr ../BOOT/1-Boot-NoEmul.img \
	-partition_offset 16 \
	--mbr-force-bootable \
	-append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b ../BOOT/2-Boot-NoEmul.img \
	-appended_part_as_gpt \
	-iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
	-c /boot.catalog \
	-b /boot/grub/i386-pc/eltorito.img \
	-no-emul-boot \
	-boot-load-size 4 \
	-boot-info-table \
	--grub2-boot-info \
	-eltorito-alt-boot \
	-e '--interval:appended_partition_2:::' \
	-no-emul-boot \
	.

# -- Cloud-Init VFAT floppy builder --
.PHONY: cidata

cidata: meta-data.yml user-data.yml
	@if [ "$$(id -u)" -ne 0 ]; then \
		echo "This rule must be run as root (sudo make cidata)"; exit 1; \
	fi
	rm -f $(CIDATA)
	dd if=/dev/zero of=$(CIDATA) bs=1024 count=1440 status=none
	mkfs.vfat -n cidata $(CIDATA)
	MNTDIR=$$(mktemp -d /tmp/cidata.XXXXXX); \
	mount -o loop $(CIDATA) $$MNTDIR; \
	cp meta-data.yml $$MNTDIR/meta-data; \
	cp user-data.yml  $$MNTDIR/user-data; \
	sync; \
	umount $$MNTDIR; \
	if ! fsck.fat -nv $(CIDATA); then echo "Image integrity check FAILED!"; exit 1; fi; \
	rmdir $$MNTDIR; \
	echo "cidata VFAT floppy image created: $(CIDATA)"

clean:
	rm -rf $(ISODIR) $(NEWISO) $(ISO) $(CIDATA)
