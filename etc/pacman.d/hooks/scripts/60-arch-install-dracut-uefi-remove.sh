#!/usr/bin/env bash

# Fail on error
set -e

# Make sure that /efi from /etc/fstab is mounted
if /usr/bin/mountpoint -q /efi; then
    /usr/bin/umount -AR /efi
fi
if /usr/bin/mountpoint -q /boot; then
    /usr/bin/umount -AR /boot
fi
/usr/bin/mount /efi
/usr/bin/mount /boot

# Delete old *.efi files
shopt -s nocaseglob
/usr/bin/rm -f /efi/EFI/Linux/*.efi
