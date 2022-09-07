#!/bin/sh

# Fail on error
set -e

# Install cryptboot
git clone https://aur.archlinux.org/cryptboot.git ~/git/cryptboot
cd ~/git/cryptboot
makepkg -sri --noprogressbar --noconfirm --needed

# Set up post-install.sh
git clone https://github.com/LeoMeinel/mdadm-encrypted-btrfs.git ~/git/mdadm-encrypted-btrfs
mv ~/git/mdadm-encrypted-btrfs/post-install.sh ~/
mv ~/git/mdadm-encrypted-btrfs/packages_post-install.txt ~/
chmod +x ~/post-install.sh

# Download the Microsoft Corporation UEFI CA 2011 certificate to support option ROMs
mkdir ~/efi-certs
cd ~/efi-certs
wget -U 'Mozilla/5.0 (X11; Linux x86_64; rv:30.0) Gecko/20100101 Firefox/30.0' https://www.microsoft.com/pkiops/certs/MicCorUEFCA2011_2011-06-27.crt

# Remove repo
rm -rf ~/git
