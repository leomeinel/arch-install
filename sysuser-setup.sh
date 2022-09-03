#!/bin/sh

# Fail on error
set -e

# Install bdf-unifont (make dependency for grub-improved-luks2-git) beforehand
git clone https://aur.archlinux.org/bdf-unifont.git ~/git/bdf-unifont
cd ~/git/bdf-unifont
makepkg -sri --noprogressbar --noconfirm --needed

# Install grub-improved-luks2-git
git clone https://aur.archlinux.org/grub-improved-luks2-git.git ~/git/grub-improved-luks2-git
cd ~/git/grub-improved-luks2-git
makepkg -sri --noprogressbar --noconfirm --needed
sudo pacman -Syu grub-btrfs

# Remove bdf-unifont (make dependency for grub-improved-luks2-git)
sudo pacman -Rsnc bdf-unifont

# Set up post-install.sh
git clone --branch encrypted-boot https://github.com/LeoMeinel/mdadm-encrypted-btrfs.git ~/git/mdadm-encrypted-btrfs
mv ~/git/mdadm-encrypted-btrfs/post-install.sh ~/
mv ~/git/mdadm-encrypted-btrfs/packages_post-install.txt ~/
chmod +x ~/post-install.sh

# Remove repo
rm -rf ~/git
