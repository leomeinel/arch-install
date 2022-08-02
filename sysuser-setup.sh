#!/bin/sh

cd
mkdir ./git
cd git
git clone https://aur.archlinux.org/paru.git
cd paru
rustup default stable
makepkg -si
cd
rm -rf ./git
paru -S waterfox-g4-bin
