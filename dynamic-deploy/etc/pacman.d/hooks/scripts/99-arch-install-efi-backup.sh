#!/usr/bin/env bash
###
# File: 99-arch-install-efi-backup.sh
# Author: Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2025 Leopold Meinel & contributors
# SPDX ID: MIT
# URL: https://opensource.org/licenses/MIT
# -----
###

# Fail on error
set -e

# Make sure that /efi and /efi.bak from /etc/fstab are mounted
if /usr/bin/mountpoint -q /efi; then
    /usr/bin/umount -AR /efi
fi
if /usr/bin/mountpoint -q /boot; then
    /usr/bin/umount -AR /boot
fi
if /usr/bin/mountpoint -q /efi.bak; then
    /usr/bin/umount -AR /efi.bak
fi
/usr/bin/mount /efi
/usr/bin/mount /boot
/usr/bin/mount /efi.bak

# Backup /efi to /efi.bak
/usr/bin/rsync -aq --delete --mkpath /efi.bak/ /efi.bak.old
/usr/bin/rsync -aq --delete --mkpath /efi/ /efi.bak

# Unmount /efi.bak
/usr/bin/umount /efi.bak
