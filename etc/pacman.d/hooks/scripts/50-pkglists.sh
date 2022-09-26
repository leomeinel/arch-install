#!/bin/bash
###
# File: 50-pkglists.sh
# Author: Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2022 Leopold Meinel & contributors
# SPDX ID: GPL-3.0-or-later
# URL: https://www.gnu.org/licenses/gpl-3.0-standalone.html
# -----
###

/usr/bin/pacman -Qqen >/var/log/pkglist-explicit.pacman.log
/usr/bin/chmod 644 /var/log/pkglist-explicit.pacman.log
/usr/bin/pacman -Qqem >/var/log/pkglist-foreign.pacman.log
/usr/bin/chmod 644 /var/log/pkglist-foreign.pacman.log
/usr/bin/pacman -Qqd >/var/log/pkglist-deps.pacman.log
/usr/bin/chmod 644 /var/log/pkglist-deps.pacman.log
