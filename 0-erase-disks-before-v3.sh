#!/bin/bash
###
# File: 0-erase-disks-before-v3.sh
# Author: Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2023 Leopold Meinel & contributors
# SPDX ID: GPL-3.0-or-later
# URL: https://www.gnu.org/licenses/gpl-3.0-standalone.html
# -----
###

# Fail on error
set -eu

# Detect, close & erase old crypt volumes
if lsblk -rno TYPE "$DISK1" | grep -q "crypt"; then
    OLD_CRYPT_0="$(lsblk -Mrno TYPE,NAME $DISK1 | grep "crypt" | sed 's/crypt//' | sed -n '1p' | tr -d "[:space:]")"
    OLD_CRYPT_1="$(lsblk -Mrno TYPE,NAME $DISK1 | grep "crypt" | sed 's/crypt//' | sed -n '2p' | tr -d "[:space:]")"
    OLD_DISK1P2="$(lsblk -rnpo TYPE,NAME $DISK1 | grep "part" | sed 's/part//' | sed -n '2p' | tr -d "[:space:]")"
    OLD_DISK1P3="$(lsblk -rnpo TYPE,NAME $DISK1 | grep "part" | sed 's/part//' | sed -n '3p' | tr -d "[:space:]")"
    ## Close old crypt volumes
    cryptsetup close "$OLD_CRYPT_0"
    cryptsetup close "$OLD_CRYPT_1"
    ## Erase old crypt volumes
    if cryptsetup isLuks "$OLD_DISK1P2"; then
        cryptsetup erase "$OLD_DISK1P2"
        sgdisk -Z "$OLD_DISK1P2"
    else
        echo "ERROR: Can't erase old crypt volume"
        exit 1
    fi
    if cryptsetup isLuks "$OLD_DISK1P3"; then
        cryptsetup erase "$OLD_DISK1P3"
        sgdisk -Z "$OLD_DISK1P3"
    else
        echo "ERROR: Can't erase old crypt volume"
        exit 1
    fi
fi
