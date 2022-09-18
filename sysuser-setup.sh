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

# Remove repo
rm -rf ~/git
