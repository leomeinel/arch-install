#!/bin/sh

cd
mkdir ./git
cd git
git clone https://aur.archlinux.org/paru.git
cd paru
rustup default stable
makepkg -si
paru -S waterfox-g4-bin
