#!/usr/bin/env bash
set -Eeuo pipefail

WORK_DIR="/tmp/nostalgia-build"
ROOTFS="${WORK_DIR}/chroot"
LIVE="${WORK_DIR}/iso"

rm -rf "${WORK_DIR}"
mkdir -p "${ROOTFS}" "${LIVE}/live" "${LIVE}/boot/grub"

echo "[1/6] Bootstrapping Debian 12 (Bookworm) 64-bit..."
debootstrap --arch=amd64 bookworm "${ROOTFS}" http://deb.debian.org/debian/

mount --bind /dev "${ROOTFS}/dev"
mount --bind /proc "${ROOTFS}/proc"
mount --bind /sys "${ROOTFS}/sys"

echo "[2/6] Generating Wallpapers..."
python3 generate_wallpapers.py
mkdir -p "${ROOTFS}/usr/share/backgrounds/nostalgia"
cp wallpapers/* "${ROOTFS}/usr/share/backgrounds/nostalgia/"

echo "[3/6] Installing Kernel, GUI, Black Cursor & Drivers..."
chroot "${ROOTFS}" /bin/bash << 'EOF'
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
    linux-image-amd64 live-boot systemd-sysv \
    xwayland weston wayland-protocols \
    kitty firefox-esr pcmanfm sudo network-manager \
    pipewire pipewire-pulse wireplumber \
    breeze-cursor-theme papirus-icon-theme fonts-inter

# Setting OS Identity & Developer Credit
cat << 'OEF' > /etc/os-release
NAME="NOSTALGIA OS"
PRETTY_NAME="NOSTALGIA OS 1.0 (x86_64)"
ID=nostalgia
VERSION="1.0"
DEVELOPER="Rakib Hasan Rimon"
OEF

# Configure Black Cursor as Global Default
mkdir -p /etc/skel/.icons/default
cat << 'CEF' > /etc/skel/.icons/default/index.theme
[Icon Theme]
Name=Default
Inherits=Breeze_Obsidian
CEF

# Setup User Account for Live Session
useradd -m -s /bin/bash -G sudo,audio,video nostalgia
echo "nostalgia:live" | chpasswd
echo "nostalgia ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/nostalgia

echo "nostalgia-os" > /etc/hostname
apt-get clean
rm -rf /tmp/* /var/lib/apt/lists/*
EOF

echo "[4/6] Exporting Boot Kernel & Initramfs..."
cp "${ROOTFS}"/vmlinuz "${LIVE}/live/vmlinuz"
cp "${ROOTFS}"/initrd.img "${LIVE}/live/initrd"

umount -lf "${ROOTFS}/dev" || true
umount -lf "${ROOTFS}/proc" || true
umount -lf "${ROOTFS}/sys" || true

echo "[5/6] Creating SquashFS Filesystem..."
mksquashfs "${ROOTFS}" "${LIVE}/live/filesystem.squashfs" -comp xz -e boot

echo "[6/6] Building Bootable ISO with GRUB..."
cat << 'EOF' > "${LIVE}/boot/grub/grub.cfg"
set default="0"
set timeout=5
menuentry "NOSTALGIA OS 1.0 - Rakib Hasan Rimon (Live & Install)" {
    linux /live/vmlinuz boot=live quiet splash
    initrd /live/initrd
}
EOF

grub-mkrescue -o "NostalgiaOS-1.0-x86_64.iso" "${LIVE}"
echo "SUCCESS! NostalgiaOS-1.0-x86_64.iso is ready."
