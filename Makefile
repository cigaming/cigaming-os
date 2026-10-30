# CiGaming OS — common tasks.  `make help` lists them.
SHELL := /bin/bash
.DEFAULT_GOAL := help

help: ## Show this list
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  \033[38;2;245;165;36m%-12s\033[0m %s\n", $$1, $$2}'

deps: ## Install build tools (Debian trixie host)
	sudo apt-get update
	sudo apt-get install -y live-build librsvg2-bin dpkg-dev reprepro gnupg shellcheck lintian curl \
	  xorriso squashfs-tools isolinux syslinux-common grub-efi-amd64-bin grub-pc-bin mtools dosfstools

assets: ## Re-render wallpaper/logo/boot art from branding/
	./scripts/render-assets.sh

packages: assets ## Build the cigamingos-* .debs into build/debs/
	./scripts/build-packages.sh

key: ## One-time: create the repo signing key
	./scripts/repo-keygen.sh

repo: packages ## Build the signed static apt repo into build/repo-public/
	./scripts/repo-publish.sh

desktop: ## Build the desktop ISO (needs sudo)
	sudo ./build.sh desktop

server: ## Build the server ISO (needs sudo)
	sudo ./build.sh server

isos: desktop server ## Build both ISOs

lint: ## shellcheck every script
	shellcheck -S warning build.sh scripts/*.sh packages/cigamingos-tools/usr/bin/cigaming \
	  packages/cigamingos-tools/usr/lib/cigamingos/firstboot packages/*/DEBIAN/p* \
	  editions/*/hooks/live/*.hook.*

test-vm: ## Boot the newest ISO in QEMU (UEFI)
	qemu-system-x86_64 -m 6G -smp 4 -enable-kvm -bios /usr/share/ovmf/OVMF.fd \
	  -cdrom $$(ls -t dist/*.iso | head -1) -vga virtio

clean: ## Remove build output (keeps dist/)
	sudo rm -rf build

.PHONY: help deps assets packages key repo desktop server isos lint test-vm clean
