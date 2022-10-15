#!/bin/bash
###
# File: dot-files.sh
# Author: Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2022 Leopold Meinel & contributors
# SPDX ID: GPL-3.0-or-later
# URL: https://www.gnu.org/licenses/gpl-3.0-standalone.html
# -----
###

# Fail on error
set -e

# Set up dot-files in 2 stages
case "$1" in
setup)
    git clone https://github.com/LeoMeinel/dot-files.git ~/dot-files
    chmod +x ~/dot-files/setup.sh
    ~/dot-files/setup.sh
    ;;
setup-guest)
    git clone https://github.com/LeoMeinel/dot-files.git ~/dot-files
    chmod +x ~/dot-files/setup.sh
    ~/dot-files/setup.sh
    sed -i "s/defaultSaveLocation=.*/defaultSaveLocation=\/home\/$2\/Documents\/Pictures\/screenshots/" ~/.config/spectaclerc
    ;;
setup-root)
    git clone https://github.com/LeoMeinel/dot-files.git ~/dot-files
    chmod +x ~/dot-files/setup-root.sh
    ~/dot-files/setup-root.sh
    ;;
vscodium)
    chmod +x ~/dot-files/exts-code.sh
    ~/dot-files/exts-code.sh
    ;;
esac
