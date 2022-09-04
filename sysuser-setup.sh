#!/bin/sh

# Fail on error
set -e

# Install bdf-unifont (make dependency for grub-improved-luks2-git) beforehand
sudo pacman -Sy --noprogressbar --noconfirm
git clone https://aur.archlinux.org/bdf-unifont.git ~/git/bdf-unifont
cd ~/git/bdf-unifont
gpg --recv-keys 1A09227B1F435A33
makepkg -sri --noprogressbar --noconfirm --needed

# Install grub-improved-luks2-git
git clone https://aur.archlinux.org/grub-improved-luks2-git.git ~/git/grub-improved-luks2-git
cd ~/git/grub-improved-luks2-git
makepkg -sri --noprogressbar --noconfirm --needed

# Install mkinitcpio-chkcryptoboot
git clone https://aur.archlinux.org/mkinitcpio-chkcryptoboot.git ~/git/mkinitcpio-chkcryptoboot
cd ~/git/mkinitcpio-chkcryptoboot
makepkg -sri --noprogressbar --noconfirm --needed

# Install grub-btrfs
sudo pacman -Syu --noprogressbar --noconfirm --needed grub-btrfs

# Remove bdf-unifont (make dependency for grub-improved-luks2-git)
sudo pacman --noprogressbar --noconfirm -Rsnc bdf-unifont

# Set up post-install.sh
git clone --branch encrypted-boot-partition https://github.com/LeoMeinel/mdadm-encrypted-btrfs.git ~/git/mdadm-encrypted-btrfs
mv ~/git/mdadm-encrypted-btrfs/post-install.sh ~/
mv ~/git/mdadm-encrypted-btrfs/packages_post-install.txt ~/
chmod +x ~/post-install.sh

# Remove repo
rm -rf ~/git
