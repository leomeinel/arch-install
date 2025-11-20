#!/usr/bin/env bash
###
# File: 50-arch-install-log-orphans.sh
# Author: Leopold Johannes Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2025 Leopold Johannes Meinel & contributors
# SPDX ID: Apache-2.0
# URL: https://www.apache.org/licenses/LICENSE-2.0
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
