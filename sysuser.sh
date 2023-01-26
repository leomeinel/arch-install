#!/bin/bash
###
# File: sysuser.sh
# Author: Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2022 Leopold Meinel & contributors
# SPDX ID: GPL-3.0-or-later
# URL: https://www.gnu.org/licenses/gpl-3.0-standalone.html
# -----
###

# Fail on error
set -eu

# Set up post.sh
git clone -b server https://github.com/LeoMeinel/arch-install.git ~/git/arch-install
cp ~/git/arch-install/pkgs-post.txt ~/
cp ~/git/arch-install/post.sh ~/
sed -i 's/<INSERT_SYSUSER>/'"$1"'/;s/<INSERT_DOCKUSER>/'"$2"'/;s/<INSERT_HOMEUSER>/'"$3"'/' ~/post.sh
chmod +x ~/post.sh

# Remove repo
rm -rf ~/git
