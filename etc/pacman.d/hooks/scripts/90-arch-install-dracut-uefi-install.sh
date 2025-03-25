#!/usr/bin/env bash
###
# File = 90-arch-install-dracut-uefi-install.sh
# Author = Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2025 Leopold Meinel & contributors
# SPDX ID = MIT
# URL = https://opensource.org/licenses/MIT
# -----
###

# Fail on error
set -e

# Make sure that /efi from /etc/fstab is mounted
if /usr/bin/mountpoint -q /efi; then
    /usr/bin/umount -AR /efi
fi
/usr/bin/mount /efi

# Regenerate dracut files
/usr/bin/dracut --regenerate-all -fq
