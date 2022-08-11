#!/bin/sh

set -e
cd
mkdir ./git
cd ./git
git clone https://aur.archlinux.org/paru.git
cd ./paru
rustup default stable
makepkg -si
cd
rm -rf ./git
sudo sed -i 's/#LocalRepo/LocalRepo/' /etc/paru.conf
sudo sed -i 's/#Chroot/Chroot/' /etc/paru.conf
sudo sed -i 's/#RemoveMake/RemoveMake/' /etc/paru.conf
sudo sed -i 's/#CleanAfter/CleanAfter/' /etc/paru.conf
paru -S --noprogressbar --noconfirm librewolf-bin ungoogled-chromium chromium-extension-web-store sweet-kde-theme-git papirus-icon-theme snap-pac-grub  pacman-log-orphans-hook snapper-gui-git
paru -Syu --noprogressbar --noconfirm
paru -Scc --noprogressbar --noconfirm
