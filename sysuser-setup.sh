#!/bin/sh

cd || exit
mkdir ./git
cd ./git || exit
git clone https://aur.archlinux.org/paru.git
cd ./paru || exit
rustup default stable
makepkg -si
cd || exit
rm -rf ./git
paru --noprogressbar --noconfirm -S waterfox-g4-bin sweet-kde-git papirus-icon-theme
