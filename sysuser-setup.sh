#!/bin/sh

# Fail on error
set -e

# Install opendoas-sudo
git clone https://aur.archlinux.org/opendoas-sudo.git ~/git/opendoas-sudo
cd ~/git/opendoas-sudo
makepkg -sri --noprogressbar --noconfirm --needed

# Install paru
git clone https://aur.archlinux.org/paru.git ~/git/paru
cd ~/git/paru
rustup default stable
makepkg -sri --noprogressbar --noconfirm --needed

# Set up post-install.sh
git clone https://github.com/LeoMeinel/mdadm-encrypted-btrfs.git ~/git/mdadm-encrypted-btrfs
mv ~/git/mdadm-encrypted-btrfs/post-install.sh ~/post-install.sh
chmod +x ~/post-install.sh

# Remove repo
rm -rf ~/git
