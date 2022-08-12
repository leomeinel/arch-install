#!/bin/sh

set -e
sudo timedatectl set-ntp true
sudo hwclock --systohc
paru -S --needed librewolf-bin ungoogled-chromium chromium-extension-web-store snap-pac-grub pacman-log-orphans-hook snapper-gui-git arc-kde-git arc-gtk-theme papirus-icon-theme-stripped
paru -Scc
paru -Syu
