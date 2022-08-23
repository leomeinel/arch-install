#!/bin/sh

KEYMAP="de-latin1"
KEYLAYOUT="de"

# Fail on error
set -e

# Configure clock
sudo timedatectl set-ntp true

# Configure $KEYMAP
sudo localectl set-keymap "$KEYMAP"
sudo localectl set-x11-keymap "$KEYLAYOUT"

# Install packages
{
  echo "librewolf-bin"
  echo "chromium-extension-web-store"
  echo "snap-pac-grub"
  echo "snapper-gui-git"
  echo "laptop-mode-tools"
  echo "macchina"
} > ~/packages.txt
paru -Sy --needed - < ~/packages.txt
paru -Scc
paru -Syu

# Enable systemd services
sudo systemctl enable laptop-mode.service

# Generate nvidia config if needed
pacman -Qq "nvidia-settings" &&
~/nvidia-install.sh &&
rm -f ~/nvidia-install.sh

# Remove script
rm -f ~/post-install.sh
rm -f ~/packages.txt
