#!/bin/sh

# Fail on error
set -e

# Install prettier and extensions through npm
sudo npm install --global prettier @prettier/plugin-php @prettier/plugin-ruby @prettier/plugin-xml prettier-plugin-java prettier-plugin-properties prettier-plugin-rust prettier-plugin-sh prettier-plugin-toml prettier-plugin-kotlin

# Install vscodium-bin
git clone https://aur.archlinux.org/vscodium-bin.git ~/git/vscodium-bin
cd ~/git/vscodium-bin
makepkg -sri --noprogressbar --noconfirm --needed

# Install vscodium-bin-marketplace
git clone https://aur.archlinux.org/vscodium-bin-marketplace.git ~/git/vscodium-bin-marketplace
cd ~/git/vscodium-bin-marketplace
makepkg -sri --noprogressbar --noconfirm --needed

# Set up post-install.sh
git clone https://github.com/LeoMeinel/mdadm-encrypted-btrfs.git ~/git/mdadm-encrypted-btrfs
mv ~/git/mdadm-encrypted-btrfs/post-install.sh ~/
mv ~/git/mdadm-encrypted-btrfs/packages_post-install.txt ~/
chmod +x ~/post-install.sh

# Remove repo
rm -rf ~/git
