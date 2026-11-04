#!/bin/bash
set -euo pipefail
M=$1
mmdebstrap --arch=arm64 --variant=important --skip=check/empty \
  --components="main restricted universe multiverse" \
  --include=ubuntu-desktop-minimal,gnome-initial-setup,network-manager,wpasupplicant,iw,bluez,sudo,locales,python3,e2fsprogs,dosfstools,pciutils,usbutils,kmod,systemd-zram-generator,pipewire-audio,wireplumber,ca-certificates,curl,nano,less \
  --dpkgopt='path-exclude=/usr/share/doc/*' --dpkgopt='path-include=/usr/share/doc/*/copyright' \
  --aptopt='APT::Install-Recommends "true"' \
  --essential-hook='mkdir -p "$1/etc/apt/preferences.d"; printf "Package: snapd linux-image-* linux-generic* grub-* shim-signed flash-kernel\nPin: release *\nPin-Priority: -1\n" > "$1/etc/apt/preferences.d/no-snap-kernel"' \
  resolute "$M" \
  "deb http://ports.ubuntu.com/ubuntu-ports resolute main restricted universe multiverse" \
  "deb http://ports.ubuntu.com/ubuntu-ports resolute-updates main restricted universe multiverse" \
  "deb http://ports.ubuntu.com/ubuntu-ports resolute-security main restricted universe multiverse"
