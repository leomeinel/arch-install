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

# INFO: This file is executed automatically during installation.
#       There is no need to execute it manually.

# Source config
SCRIPT_DIR="$(dirname -- "$(readlink -f -- "${0}")")"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}"/install.conf

# Fail on error
set -e

# Clone dot-files
if [ "${IS_RELEASE}" ]; then
    git clone -b "${DOTFILES_VERSION}" https://github.com/leomeinel/dot-files.git ~/.config/dot-files
else
    git clone -b main https://github.com/leomeinel/dot-files.git ~/.config/dot-files
fi

# Run dot-files
cat "${SCRIPT_DIR}"/install.conf >>~/.config/dot-files/install.conf
chmod 755 ~/.config/dot-files/setup.sh
~/.config/dot-files/setup.sh
