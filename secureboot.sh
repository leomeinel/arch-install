#!/usr/bin/env bash
###
# File = secureboot.sh
# Author = Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2025 Leopold Meinel & contributors
# SPDX ID = MIT
# URL = https://opensource.org/licenses/MIT
# -----
###

# INFO: This file is not needed for the installation

# Fail on error
set -e

# Source config
# shellcheck source=/dev/null
. /etc/cryptboot.conf

# Configure secureboot
# Prompt user
read -rp "Have you transferred your keys to ${EFI_KEYS_DIR}? (Type 'yes' in capital letters): " choice
case "${choice}" in
YES)
    doas chmod 000 "${EFI_KEYS_DIR}"/*
    if mountpoint -q /efi; then
        doas umount -AR /efi
    fi
    doas mount /efi
    doas cryptboot systemd-boot-sign
    doas /bin/sh -c '{
        echo "uefi_secureboot_cert='\""${EFI_KEYS_DIR}"\"'/db.crt"
        echo "uefi_secureboot_key='\""${EFI_KEYS_DIR}"\"'/db.key"
    } >/etc/dracut.conf.d/50-arch-install-secureboot.conf'
    rm -f ~/secureboot.sh
    ;;
*)
    echo "ERROR: User has not transferred keys to ${EFI_KEYS_DIR}!"
    exit 1
    ;;
esac

# Notify user if script has finished successfully
echo "INFO: $(basename "${0}") has finished successfully."
