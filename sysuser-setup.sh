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
paru -S --noprogressbar --noconfirm librewolf ungoogled-chromium chromium-extension-web-store sweet-kde-theme-git papirus-icon-theme snap-pac-grub  pacman-log-orphans-hook snapper-gui-git
paru -Scc --noprogressbar --noconfirm
paru -Qtdq --noconfirm | paru -Rns --noprogressbar --noconfirm -
