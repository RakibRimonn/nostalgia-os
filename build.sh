#!/usr/bin/env bash
set -Eeuo pipefail

WORK_DIR="/tmp/nostalgia-build"
ROOTFS="${WORK_DIR}/chroot"
LIVE="${WORK_DIR}/iso"

rm -rf "${WORK_DIR}"
mkdir -p "${ROOTFS}" "${LIVE}/live" "${LIVE}/boot/grub"

echo "[1/7] Bootstrapping Base Debian 12 (x86_64)..."
debootstrap --arch=amd64 bookworm "${ROOTFS}" http://deb.debian.org/debian/

mount --bind /dev "${ROOTFS}/dev"
mount --bind /proc "${ROOTFS}/proc"
mount --bind /sys "${ROOTFS}/sys"

echo "[2/7] Preparing Sunset Landscape Default Wallpaper..."
mkdir -p "${ROOTFS}/usr/share/backgrounds/nostalgia"
python3 - << 'PYEOF'
import os
from PIL import Image, ImageDraw

out_dir = "/tmp/nostalgia-build/chroot/usr/share/backgrounds/nostalgia"
os.makedirs(out_dir, exist_ok=True)
w, h = 3840, 2160
img = Image.new("RGB", (w, h), (45, 52, 98))
draw = ImageDraw.Draw(img)

# Sky Sunset Gradient
for y in range(h):
    r = int(55 + (235 - 55) * (y / h))
    g = int(70 + (125 - 70) * (y / h))
    b = int(120 + (80 - 120) * (y / h))
    draw.line([(0, y), (w, y)], fill=(r, g, b))

# Sun
draw.ellipse([(w//2 - 120, int(h*0.62) - 120), (w//2 + 120, int(h*0.62) + 120)], fill=(255, 235, 170))
# Mountain & Green Hill contours
draw.polygon([(0, int(h*0.72)), (w//3, int(h*0.65)), (w, int(h*0.75)), (w, h), (0, h)], fill=(40, 68, 50))
img.save(os.path.join(out_dir, "nostalgia-default.png"), "PNG")
PYEOF

echo "[3/7] Installing Full Desktop Environment, Dock & Themes..."
chroot "${ROOTFS}" /bin/bash << 'EOF'
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
    linux-image-amd64 live-boot systemd-sysv \
    xfce4-session xfwm4 xfce4-panel xfdesktop4 \
    thunar plank kitty firefox-esr \
    fonts-inter fonts-noto-core fonts-beng \
    papirus-icon-theme breeze-cursor-theme \
    sudo network-manager pipewire pipewire-pulse wireplumber \
    lightdm lightdm-gtk-greeter python3-gi gir1.2-gtk-3.0

# 1. Developer Identity Configuration
cat << 'OEF' > /etc/os-release
NAME="NOSTALGIA OS"
PRETTY_NAME="NOSTALGIA OS 2.0"
VERSION="2.0 (Desktop Edition)"
DEVELOPER="Rakib Hasan Rimon"
DEVELOPER_EMAIL="rakibhasanrimon77@gmail.com"
DEVELOPER_WEBSITE="https://rakibhasanrimon.wordpress.com/"
OEF

# 2. Black Cursor Theme as System Default
mkdir -p /etc/skel/.icons/default
cat << 'CEF' > /etc/skel/.icons/default/index.theme
[Icon Theme]
Name=Default
Inherits=Breeze_Obsidian
CEF

# 3. Create Desktop Clickable Icons (This PC, Recycle Bin, Documents, Store, Rimon Profile)
mkdir -p /etc/skel/Desktop

cat << 'DEF' > /etc/skel/Desktop/this-pc.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=This PC
Exec=thunar /
Icon=computer
Terminal=false
DEF

cat << 'DEF' > /etc/skel/Desktop/recycle-bin.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Recycle Bin
Exec=thunar trash:///
Icon=user-trash
Terminal=false
DEF

cat << 'DEF' > /etc/skel/Desktop/documents.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Documents
Exec=thunar /home/nostalgia/Documents
Icon=folder-documents
Terminal=false
DEF

cat << 'DEF' > /etc/skel/Desktop/nostalgia-store.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Nostalgia Store
Exec=firefox-esr https://rakibhasanrimon.wordpress.com/
Icon=software-store
Terminal=false
DEF

cat << 'DEF' > /etc/skel/Desktop/about-rimon.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Rimon (Developer)
Exec=nostalgia-about
Icon=user-info
Terminal=false
DEF

chmod +x /etc/skel/Desktop/*.desktop

# 4. Built-in "About System & Developer" GUI App
cat << 'APP' > /usr/local/bin/nostalgia-about
#!/usr/bin/env python3
import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk

class AboutWindow(Gtk.Window):
    def __init__(self):
        super().__init__(title="About NOSTALGIA OS")
        self.set_default_size(480, 360)
        self.set_position(Gtk.WindowPosition.CENTER)
        
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        box.set_margin_top(24); box.set_margin_bottom(24)
        box.set_margin_start(24); box.set_margin_end(24)
        
        lbl_title = Gtk.Label()
        lbl_title.set_markup("<span font='18' weight='bold' foreground='#00f0ff'>★ NOSTALGIA OS 2.0</span>")
        box.pack_start(lbl_title, False, False, 0)
        
        frame = Gtk.Frame(label="Developer Information")
        grid = Gtk.Grid()
        grid.set_column_spacing(12); grid.set_row_spacing(10)
        grid.set_margin_top(14); grid.set_margin_bottom(14); grid.set_margin_start(14)
        
        grid.attach(Gtk.Label(label="Lead Architect:"), 0, 0, 1, 1)
        grid.attach(Gtk.Label(label="Rakib Hasan Rimon"), 1, 0, 1, 1)
        grid.attach(Gtk.Label(label="Email:"), 0, 1, 1, 1)
        grid.attach(Gtk.Label(label="rakibhasanrimon77@gmail.com"), 1, 1, 1, 1)
        grid.attach(Gtk.Label(label="Website:"), 0, 2, 1, 1)
        grid.attach(Gtk.Label(label="https://rakibhasanrimon.wordpress.com/"), 1, 2, 1, 1)
        
        frame.add(grid)
        box.pack_start(frame, True, True, 0)
        
        btn = Gtk.Button(label="Visit Portfolio")
        btn.connect("clicked", lambda x: Gtk.show_uri_on_window(None, "https://rakibhasanrimon.wordpress.com/", 0))
        box.pack_start(btn, False, False, 0)
        
        self.add(box)

win = AboutWindow()
win.connect("destroy", Gtk.main_quit)
win.show_all()
Gtk.main()
APP

chmod +x /usr/local/bin/nostalgia-about

# 5. Autostart Floating Dock & Welcome Setup
mkdir -p /etc/skel/.config/autostart
cat << 'AEF' > /etc/skel/.config/autostart/dock.desktop
[Desktop Entry]
Type=Application
Exec=plank
Name=Plank Dock
AEF

# 6. Auto Login - No Password Required!
mkdir -p /etc/lightdm/lightdm.conf.d
cat << 'LEF' > /etc/lightdm/lightdm.conf.d/01_autologin.conf
[Seat:*]
autologin-user=nostalgia
autologin-user-timeout=0
LEF

# 7. Setup Live User Profile
useradd -m -s /bin/bash -G sudo,audio,video nostalgia
echo "nostalgia:live" | chpasswd
echo "nostalgia ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/nostalgia
echo "nostalgia-os" > /etc/hostname

mkdir -p /home/nostalgia/Documents
chown -R nostalgia:nostalgia /home/nostalgia

apt-get clean
rm -rf /tmp/* /var/lib/apt/lists/*
EOF

echo "[4/7] Exporting Kernel & Initrd..."
cp "${ROOTFS}"/vmlinuz "${LIVE}/live/vmlinuz"
cp "${ROOTFS}"/initrd.img "${LIVE}/live/initrd"

umount -lf "${ROOTFS}/dev" || true
umount -lf "${ROOTFS}/proc" || true
umount -lf "${ROOTFS}/sys" || true

echo "[5/7] Compressing Root FileSystem into SquashFS..."
mksquashfs "${ROOTFS}" "${LIVE}/live/filesystem.squashfs" -comp xz -e boot

echo "[6/7] Writing Bootloader Menu with Rakib Hasan Rimon Credit..."
cat << 'EOF' > "${LIVE}/boot/grub/grub.cfg"
set default="0"
set timeout=3

menuentry "NOSTALGIA OS 2.0 (Desktop Edition) - By Rakib Hasan Rimon" {
    linux /live/vmlinuz boot=live quiet splash
    initrd /live/initrd
}
EOF

echo "[7/7] Generating Bootable ISO..."
grub-mkrescue -o "NostalgiaOS-2.0-x86_64.iso" "${LIVE}"

echo "SUCCESS! NostalgiaOS-2.0-x86_64.iso is ready."
