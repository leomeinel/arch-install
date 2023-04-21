#!/bin/bash
###
# File: sysuser.sh
# Author: Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2023 Leopold Meinel & contributors
# SPDX ID: GPL-3.0-or-later
# URL: https://www.gnu.org/licenses/gpl-3.0-standalone.html
# -----
###

# Fail on error
set -eu

# Set up post.sh
cp /git/arch-install/pkgs-post.txt ~/
cp /git/arch-install/post.sh ~/
cp /git/arch-install/install.conf ~/
chmod +x ~/post.sh

# Remove repo
rm -rf ~/git
