#!/bin/sh

# Fail on error
set -e

# Install paru
git clone https://aur.archlinux.org/paru.git ~/git/paru
cd ~/git/paru
rustup default stable
makepkg -sri --noprogressbar --noconfirm --needed

# Set up post-install.sh
git clone https://github.com/LeoMeinel/mdadm-encrypted-btrfs.git ~/git/mdadm-encrypted-btrfs
mv ~/git/mdadm-encrypted-btrfs/post-install.sh ~/post-install.sh
chmod +x ~/post-install.sh

# Install packages
{
  echo "arc-kde-git"
  echo "papirus-icon-theme-stripped"
  echo "sddm-nordic-theme-git"
} > ~/packages.txt
paru -Sy --needed - < ~/packages.txt

# Remove repo
rm -rf ~/git
rm -rf ~/packages.txt
