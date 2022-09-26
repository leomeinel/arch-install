#!/bin/bash
###
# File: 99-efibackup.sh
# Author: Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2022 Leopold Meinel & contributors
# SPDX ID: GPL-3.0-or-later
# URL: https://www.gnu.org/licenses/gpl-3.0-standalone.html
# -----
###

set -e
if /usr/bin/mountpoint -q /efi; then
    /usr/bin/umount -AR /efi
fi
if /usr/bin/mountpoint -q /.efi.bak; then
    /usr/bin/umount -AR /.efi.bak
fi
if /usr/bin/mountpoint -q /boot; then
    /usr/bin/umount -AR /boot
fi
/usr/bin/mount /boot
/usr/bin/mount /efi
/usr/bin/mount /.efi.bak
/usr/bin/rsync -aq --delete --mkpath /.efi.bak/ /.efi.bak.old
/usr/bin/rsync -aq --delete --mkpath /efi/ /.efi.bak
if [ -d /.boot.bak ]; then
    /usr/bin/rsync -aq --delete --mkpath /.boot.bak/ /.boot.bak.old
fi
/usr/bin/rsync -aq --delete --mkpath /boot/ /.boot.bak
/usr/bin/umount /.efi.bak
