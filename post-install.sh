#!/bin/sh

set -e
sudo timedatectl set-ntp true
sudo hwclock --systohc
paru -S --needed librewolf-bin ungoogled-chromium chromium-extension-web-store snap-pac-grub pacman-log-orphans-hook snapper-gui-git arc-kde-git papirus-icon-theme-stripped multicolor-sddm-theme
paru -Scc
paru -Syu
