#!/usr/bin/env bash
###
# File: dot-files.sh
# Author: Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2025 Leopold Meinel & contributors
# SPDX ID: MIT
# URL: https://opensource.org/licenses/MIT
# -----
###

# Fail on error
set -e

# Run dot-files
git clone -b main https://github.com/leomeinel/dot-files.git ~/.config/dot-files
cat ~/install.conf >>~/.config/dot-files/install.conf
chmod 755 ~/.config/dot-files/setup.sh
~/.config/dot-files/setup.sh
