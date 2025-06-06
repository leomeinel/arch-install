#!/usr/bin/env bash
###
# File: secureboot.sh
# Author: Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2025 Leopold Meinel & contributors
# SPDX ID: MIT
# URL: https://opensource.org/licenses/MIT
# -----
###

# INFO: This file is not needed for the installation

# Fail on error
set -e

# Define functions
log_err() {
    /usr/bin/logger -s -p local0.err <<<"$(basename "${0}"): ${*}"
}

# Source config
# shellcheck source=/dev/null
. /etc/cryptboot.conf

# Configure secureboot
# Prompt user
read -rp "Have you transferred your keys to '${EFI_KEYS_DIR:?}/keys'? (Type 'yes' in capital letters): " choice
case "${choice}" in
"YES")
    doas chmod 000 "${EFI_KEYS_DIR:?}"/keys/*
    if mountpoint -q /efi; then
        doas umount -AR /efi
    fi
    if mountpoint -q /boot; then
        doas umount -AR /boot
    fi
    doas mount /efi
    doas mount /boot
    doas cryptboot systemd-boot-sign
    doas /bin/sh -c '{
        echo "uefi_secureboot_cert='\""${EFI_KEYS_DIR:?}"/keys\"'/db.crt"
        echo "uefi_secureboot_key='\""${EFI_KEYS_DIR:?}"/keys\"'/db.key"
    } >/etc/dracut.conf.d/50-arch-install-secureboot.conf'
    rm -f ~/secureboot.sh
    ;;
*)
    log_err "User has not transferred keys to '${EFI_KEYS_DIR:?}/keys'."
    exit 1
    ;;
esac

# Notify user if script has finished successfully
echo "'$(basename "${0}")' has finished successfully."
