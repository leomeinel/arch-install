#!/bin/bash
###
# File: custom-sign-modules.sh
# Author: Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2022 Leopold Meinel & contributors
# SPDX ID: GPL-3.0-or-later
# URL: https://www.gnu.org/licenses/gpl-3.0-standalone.html
# -----
###

if /usr/bin/pacman -Qq "linux"; then
    /usr/bin/abk -u linux
    /usr/bin/abk -b linux
    /usr/bin/abk -i linux
fi
if /usr/bin/pacman -Qq "linux-lts"; then
    /usr/bin/abk -u linux-lts
    /usr/bin/abk -b linux-lts
    /usr/bin/abk -i linux-lts
fi
if /usr/bin/pacman -Qq "linux-zen"; then
    /usr/bin/abk -u linux-zen
    /usr/bin/abk -b linux-zen
    /usr/bin/abk -i linux-zen
fi
