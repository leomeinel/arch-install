#!/usr/bin/env bash

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
