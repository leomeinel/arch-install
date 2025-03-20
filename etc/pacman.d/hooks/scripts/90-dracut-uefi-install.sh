#!/usr/bin/env bash
###
# File: 90-dracut-uefi-install.sh
# Author: Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2025 Leopold Meinel & contributors
# SPDX ID: MIT
# URL: https://opensource.org/licenses/MIT
# -----
###

set -e
if /usr/bin/mountpoint -q /efi; then
    /usr/bin/umount -AR /efi
fi
/usr/bin/mount /efi
/usr/bin/dracut --regenerate-all -fq
