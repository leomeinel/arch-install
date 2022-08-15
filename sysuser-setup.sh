#!/bin/sh

# Fail on error
set -e

# Install paru
mkdir ~/git
cd ~/git
git clone https://aur.archlinux.org/paru.git
cd ~/git/paru
rustup default stable
makepkg -si --noprogressbar --noconfirm --needed

# Set up post-install.sh
cd ~/git
git clone https://github.com/LeoMeinel/mdadm-encrypted-btrfs.git
mv ~/git/mdadm-encrypted-btrfs/post-install.sh ~/post-install.sh
chmod +x ~/post-install.sh

# Remove repo
rm -rf ~/git
