#!/usr/bin/env bash
###
# File: rescue-mount.sh
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
log_warning() {
    /usr/bin/logger -s -p local0.warning <<<"$(basename "${0}"): ${*}"
}

# Source config
SCRIPT_DIR="$(dirname -- "$(readlink -f -- "${0}")")"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}"/install.conf

# Unmount everything from /mnt
mountpoint -q /mnt &&
    umount -AR /mnt

# Prompt user for RAID
read -rp "Use RAID? (Type 'yes' in capital letters): " choice
case "${choice}" in
"YES")
    ## Detect disks
    readarray -t DISKS < <(lsblk -drnpo NAME -I 259,8,254 | tr -d "[:blank:]")
    DISKS_LENGTH="${#DISKS[@]}"
    for ((i = 0; i < DISKS_LENGTH; i++)); do
        if udevadm info -q property --property=ID_BUS --value "${DISKS[${i}]}" | grep -q "usb"; then
            unset 'DISKS[${i}]'
            continue
        fi
        DISKS=("${DISKS[@]}")
    done
    if [[ "${#DISKS[@]}" -lt 2 ]]; then
        log_err "There are less than 2 disks attached."
        exit 1
    fi
    if [[ "${#DISKS[@]}" -gt 2 ]]; then
        log_warning "There are more than 2 disks attached."
        lsblk -drnpo SIZE,NAME,MODEL,LABEL -I 259,8,254
        ### Prompt user to select 2 RAID members
        read -rp "Which disk is the first RAID member? (Type '/dev/sdX' fex.): " choice0
        read -rp "Which disk is the second RAID member? (Type '/dev/sdY' fex.): " choice1
        if [[ "$(tr -d "[:space:]" <<<"${choice0}")" != "$(tr -d "[:space:]" <<<"${choice1}")" ]] && lsblk -drnpo SIZE,NAME,MODEL,LABEL -I 259,8,254 "${choice0}" "${choice1}"; then
            echo "Using '${choice0}' and '${choice1}' for rescue-system."
            DISKS=(
                "${choice0}"
                "${choice1}"
            )
        else
            log_err "Drives not suitable for rescue-system."
            exit 1
        fi
    fi
    ## Set disks
    DISK1="${DISKS[0]}"
    DISK2="${DISKS[1]}"
    ## Prompt user to confirm selection
    read -rp "Use '${DISK1}' and '${DISK2}'? (Type 'yes' in capital letters): " choice
    case "${choice}" in
    "YES")
        echo "Using '${DISK1}' and '${DISK2}'..."
        ;;
    *)
        log_err "User aborted using '${DISK1}' and '${DISK2}'."
        exit 1
        ;;
    esac
    ;;
*)
    ## Prompt user for disk
    ## NOTE: USB will be valid to allow external SSDs
    lsblk -drnpo SIZE,NAME,MODEL,LABEL -I 259,8,254
    read -rp "Which disk do you want to use? (Type '/dev/sdX' fex.): " choice
    if lsblk -drnpo SIZE,NAME,MODEL,LABEL -I 259,8,254 "${choice}"; then
        ### Set DISK1
        DISK1="${choice}"
        echo "Using '${DISK1}'..."
    else
        log_err "Drive not suitable for rescue-system."
        exit 1
    fi
    ;;
esac

# Configure raid and encryption
DISK1P1="$(lsblk -rnpo TYPE,NAME "${DISK1}" | grep "part" | sed 's/part//g' | sed -n '1p' | tr -d "[:space:]")"
DISK1P2="$(lsblk -rnpo TYPE,NAME "${DISK1}" | grep "part" | sed 's/part//g' | sed -n '2p' | tr -d "[:space:]")"
if [[ -n "${DISK2}" ]]; then
    DISK2P1="$(lsblk -rnpo TYPE,NAME "${DISK2}" | grep "part" | sed 's/part//g' | sed -n '1p' | tr -d "[:space:]")"
    ## Configure raid1
    RAID_DEVICE=/dev/md/md0
    ## Configure encryption
    for i in {1..5}; do
        if [[ "${i}" -eq 5 ]]; then
            log_err "Too many retries."
            exit 1
        fi
        if cryptsetup open "${RAID_DEVICE}" md0_crypt; then
            break
        else
            log_warning "You have entered an incorrect password. Retrying now."
        fi
    done
else
    ## Configure encryption
    for i in {1..5}; do
        if [[ "${i}" -eq 5 ]]; then
            log_err "Too many retries."
            exit 1
        fi
        if cryptsetup open "${DISK1P2}" md0_crypt; then
            break
        else
            log_warning "You have entered an incorrect password. Retrying now."
        fi
    done
fi

# Configure lvm
vgchange -ay

## Mount subvolumes
SUBVOLUMES_LENGTH="${#SUBVOLUMES[@]}"
LV0=/dev/mapper/vg0-lv0
LV1=/dev/mapper/vg0-lv1
LV2=/dev/mapper/vg0-lv2
LV3=/dev/mapper/vg0-lv3
LV4=/dev/mapper/vg0-lv4
OPTIONS0="noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvol=/@"
OPTIONS1="nodev,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvol=/@"
OPTIONS2="nodev,nosuid,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvol=/@"
OPTIONS3="noexec,nodev,nosuid,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvol=/@"
mount_subs0() {
    mount -m -o "${3}${2}" -t btrfs "${4}" /mnt"${1}"
    mount -m -o "${OPTIONS3}${2}_snapshots" -t btrfs "${4}" /mnt"${1}".snapshots
    mount_subs1 "${1}" "${3}" "${4}"
}
mount_subs1() {
    for ((a = 0; a < SUBVOLUMES_LENGTH; a++)); do
        if [[ "${SUBVOLUMES[${a}]}" != "${1}" ]] && grep -q "^${1}" <<<"${SUBVOLUMES[${a}]}"; then
            if { grep -q "^${1}log/" <<<"${SUBVOLUMES[${a}]}"; } || { grep -q "^${1}lib/" <<<"${SUBVOLUMES[${a}]}" && ! grep -q "^${1}lib/flatpak/" <<<"${SUBVOLUMES[${a}]}"; }; then
                mount -m -o "${OPTIONS3}${CONFIGS[${a}]}" -t btrfs "${3}" /mnt"${SUBVOLUMES[${a}]}"
            else
                mount -m -o "${2}${CONFIGS[${a}]}" -t btrfs "${3}" /mnt"${SUBVOLUMES[${a}]}"
            fi
            mount -m -o "${OPTIONS3}${CONFIGS[${a}]}_snapshots" -t btrfs "${3}" /mnt"${SUBVOLUMES[${a}]}".snapshots
        fi
    done
}
for ((i = 0; i < SUBVOLUMES_LENGTH; i++)); do
    case "${SUBVOLUMES[${i}]}" in
    /)
        mount -m -o "${OPTIONS0}" -t btrfs "${LV0}" /mnt"${SUBVOLUMES[${i}]}"
        mount -m -o "${OPTIONS3}snapshots" -t btrfs "${LV0}" /mnt"${SUBVOLUMES[${i}]}".snapshots
        ;;
    /usr/)
        mount_subs0 "${SUBVOLUMES[${i}]}" "${CONFIGS[${i}]}" "${OPTIONS1}" "${LV1}"
        ;;
    /nix/)
        mount_subs0 "${SUBVOLUMES[${i}]}" "${CONFIGS[${i}]}" "${OPTIONS1}" "${LV2}"
        ;;
    /var/)
        mount_subs0 "${SUBVOLUMES[${i}]}" "${CONFIGS[${i}]}" "${OPTIONS2}" "${LV3}"
        ;;
    /home/)
        mount_subs0 "${SUBVOLUMES[${i}]}" "${CONFIGS[${i}]}" "${OPTIONS2}" "${LV4}"
        ;;
    esac
done
## tmpfs
mount -m -o "noexec,nodev,nosuid,size=80%" -t tmpfs tmpfs /mnt/dev/shm
### FIXME: Ideally, /tmp should be noexec; See: https://github.com/NixOS/nix/issues/10492
mount -m -o "nodev,nosuid,mode=1700,size=80%" -t tmpfs tmpfs /mnt/tmp
## proc
mount -m -o "noexec,nodev,nosuid,gid=proc,hidepid=2" -t proc proc /mnt/proc
## /efi
OPTIONS4="noexec,nodev,nosuid,noatime,fmask=0077,dmask=0077"
mount -m -o "${OPTIONS4}" -t vfat "${DISK1P1}" /mnt/efi
[[ -n "${DISK2}" ]] &&
    mount -m -o "${OPTIONS4}" -t vfat "${DISK2P1}" /mnt/efi.bak
## Configure bind mounts
### /boot
mount -m -B /mnt/efi /mnt/boot

# Inform user how to use arch-chroot
echo "To enter the rescue-system, execute the following: 'arch-chroot /mnt'"

# Notify user if script has finished successfully
echo "'$(basename "${0}")' has finished successfully."
