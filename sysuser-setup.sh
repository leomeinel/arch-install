#!/bin/sh

# Fail on error
set -e

# Set up post-install.sh
git clone https://github.com/LeoMeinel/mdadm-encrypted-btrfs.git ~/git/mdadm-encrypted-btrfs
mv ~/git/mdadm-encrypted-btrfs/post-install.sh ~/post-install.sh
chmod +x ~/post-install.sh

# Remove repo
rm -rf ~/git
