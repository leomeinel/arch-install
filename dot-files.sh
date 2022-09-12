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

# Run dot-files/setup.sh
git clone https://github.com/LeoMeinel/dot-files.git ~/dot-files
chmod +x ~/dot-files/setup.sh
~/dot-files/setup.sh
