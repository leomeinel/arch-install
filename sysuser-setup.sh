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
sudo sed -i 's/#LocalRepo/LocalRepo/;s/#Chroot/Chroot/;s/#RemoveMake/RemoveMake/;s/#CleanAfter/CleanAfter/' /etc/paru.conf
sudo sed -i 's/#CacheDir/CacheDir/;s/#ParallelDownloads = 5\nInclude = /etc/paru-chroot.conf/ParallelDownloads = 10/' /etc/pacman.conf
paru -S --noprogressbar --noconfirm librewolf-bin ungoogled-chromium chromium-extension-web-store sweet-kde-theme-git papirus-icon-theme snap-pac-grub pacman-log-orphans-hook snapper-gui-git
paru -Syu --noprogressbar --noconfirm
paru -Scc --noprogressbar --noconfirm
