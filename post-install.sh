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
paru -Sy --needed librewolf-bin ungoogled-chromium chromium-extension-web-store snap-pac-grub pacman-log-orphans-hook snapper-gui-git arc-kde-git papirus-icon-theme-stripped sddm-nordic-theme-git laptop-mode-tools
paru -Scc
paru -Syu

# Enable systemd services
sudo systemctl enable laptop-mode.service

# Install nvidia config if needed
if pacman -Qq | grep -q "nvidia-settings"
then
~/nvidia-install.sh
rm -rf ~/nvidia-install.sh
fi

# Remove script
rm -rf ~/post-install.sh

