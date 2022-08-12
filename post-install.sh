#!/bin/sh

set -e
sudo timedatectl set-ntp true
sudo hwclock --systohc
sudo sed -i 's/#LocalRepo/LocalRepo/;s/#Chroot/Chroot/;s/#RemoveMake/RemoveMake/;s/#CleanAfter/CleanAfter/' /etc/paru.conf
paru -S --needed librewolf-bin ungoogled-chromium chromium-extension-web-store snap-pac-grub pacman-log-orphans-hook snapper-gui-git
paru -Scc
paru -Syu
