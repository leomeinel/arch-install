#!/usr/bin/env bash
###
# File: 50-arch-install-log-orphans.sh
# Author: Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2025 Leopold Meinel & contributors
# SPDX ID: MIT
# URL: https://opensource.org/licenses/MIT
# -----
###

# Fail on error
set -e

PKGS="$(/usr/bin/pacman -Qtdq || true)"
if [[ -n "${PKGS}" ]]; then
    {
        /usr/bin/echo "The following packages are installed but not required (anymore): "
        /usr/bin/echo "${PKGS}"
        /usr/bin/echo "You can remove them all using 'pacman -Qtdq | pacman -Rns -'"
    }
fi
