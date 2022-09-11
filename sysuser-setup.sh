#!/bin/sh

# Fail on error
set -e

# Install vscodium-bin
git clone https://aur.archlinux.org/vscodium-bin.git ~/git/vscodium-bin
cd ~/git/vscodium-bin
makepkg -sri --noprogressbar --noconfirm --needed

# Set up post-install.sh
git clone https://github.com/LeoMeinel/mdadm-encrypted-btrfs.git ~/git/mdadm-encrypted-btrfs
mv ~/git/mdadm-encrypted-btrfs/post-install.sh ~/
mv ~/git/mdadm-encrypted-btrfs/packages_post-install.txt ~/
chmod +x ~/post-install.sh

# Remove repo
rm -rf ~/git
