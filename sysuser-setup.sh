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
paru --noprogressbar --noconfirm -S waterfox-g4-bin sweet-kde-git paper-icon-theme snap-pac-grub snapper-gui-git
