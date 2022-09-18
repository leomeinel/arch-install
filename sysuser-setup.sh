#!/bin/bash
###
# File: sysuser-setup.sh
# Author: Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2022 Leopold Meinel & contributors
# SPDX ID: GPL-3.0-or-later
# URL: https://www.gnu.org/licenses/gpl-3.0-standalone.html
# -----
###

# Fail on error
set -e

# Set up post-install.sh
git clone --branch security https://github.com/LeoMeinel/mdadm-encrypted-btrfs.git ~/git/mdadm-encrypted-btrfs
mv ~/git/mdadm-encrypted-btrfs/post-install.sh ~/
mv ~/git/mdadm-encrypted-btrfs/packages_sysuser-setup.txt ~/
sed -i 's/"<INSERT_USERS>"/'"$1 $2 $3 $4"'/' ~/post-install.sh
chmod +x ~/post-install.sh

# Install paru
rustup default stable
git clone https://aur.archlinux.org/paru.git ~/git/paru
cd ~/git/paru
makepkg -sri --noprogressbar --noconfirm --needed

# Configure paru.conf
doas sed -i 's/^#RemoveMake/RemoveMake/;s/^#CleanAfter/CleanAfter/;s/^#\[bin\]/\[bin\]/;s/^#FileManager =.*/FileManager = nvim/;s/^#Sudo =.*/Sudo = doas/' /etc/paru.conf
doas sh -c 'echo FileManagerFlags = '"\'"'-c,\"NvimTreeFocus\"'"\'"' >> /etc/paru.conf'

# Install packages
paru -S --noprogressbar --noconfirm --needed - <~/packages_post-install.txt
paru --noprogressbar --noconfirm -Syu
paru -Scc

# Remove repo
rm -rf ~/git
