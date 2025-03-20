#!/usr/bin/env bash
###
# File: 51-pkglists.sh
# Author: Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2025 Leopold Meinel & contributors
# SPDX ID: MIT
# URL: https://opensource.org/licenses/MIT
# -----
###

print_header() {
    /usr/bin/echo ''
    /usr/bin/echo '########################'
    /usr/bin/date -u +"#%Y-%m-%dT%H:%M:%S %Z"
    /usr/bin/echo '########################'
}
{
    print_header
    /usr/bin/pacman -Qen
} >>/var/log/pkglist-explicit.pacman.log
{
    print_header
    /usr/bin/pacman -Qem
} >>/var/log/pkglist-foreign.pacman.log
{
    print_header
    /usr/bin/pacman -Qd
} >>/var/log/pkglist-deps.pacman.log
