#!/bin/sh

KEYMAP="de-latin1"
KEYLAYOUT="de"

set -e
sudo timedatectl set-ntp true
sudo hwclock --systohc
sudo localectl set-keymap "$KEYMAP"
sudo localectl set-x11-keymap "$KEYLAYOUT"
paru -S --needed librewolf-bin ungoogled-chromium chromium-extension-web-store snap-pac-grub pacman-log-orphans-hook snapper-gui-git arc-kde-git papirus-icon-theme-stripped sddm-nordic-theme-git laptop-mode-tools
paru -Scc
paru -Syu
sudo systemctl enable laptop-mode.service
rm -rf ~/post-install.sh
