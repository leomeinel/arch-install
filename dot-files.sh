#!/bin/bash
###
# File: dot-files.sh
# Author: Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2023 Leopold Meinel & contributors
# SPDX ID: GPL-3.0-or-later
# URL: https://www.gnu.org/licenses/gpl-3.0-standalone.html
# -----
###

# Fail on error
set -e

# Set up dot-files
case "$1" in
setup)
    git clone -b games https://github.com/LeoMeinel/dot-files.git ~/dot-files
    chmod +x ~/dot-files/setup.sh
    ~/dot-files/setup.sh
    ;;
setup-root)
    git clone -b games https://github.com/LeoMeinel/dot-files.git ~/dot-files
    chmod +x ~/dot-files/setup-root.sh
    ~/dot-files/setup-root.sh
    ;;
vscodium)
    git clone -b games https://github.com/LeoMeinel/dot-files.git ~/dot-files
    chmod +x ~/dot-files/exts-code.sh
    ~/dot-files/exts-code.sh
    ;;
esac
