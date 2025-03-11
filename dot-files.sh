#!/usr/bin/env bash
###
# File: dot-files.sh
# Author: Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2025 Leopold Meinel & contributors
# SPDX ID: GPL-3.0-or-later
# URL: https://www.gnu.org/licenses/gpl-3.0-standalone.html
# -----
###

# Fail on error
set -e

# Run dot-files
git clone -b main https://github.com/leomeinel/dot-files.git ~/.config/dot-files
cat /install.conf >>~/.config/dot-files/install.conf
chmod +x ~/.config/dot-files/setup.sh
~/.config/dot-files/setup.sh
