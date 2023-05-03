#!/bin/bash
###
# File: prepare.sh
# Author: Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2023 Leopold Meinel & contributors
# SPDX ID: GPL-3.0-or-later
# URL: https://www.gnu.org/licenses/gpl-3.0-standalone.html
# -----
###

# Source config
SCRIPT_DIR="$(dirname -- "$(readlink -f -- "$0")")"
source "$SCRIPT_DIR/install.conf"

# Fail on error
set -e

# Define functions
sed_exit() {
    echo "ERROR: 'sed' didn't replace, report this @"
    echo "       https://github.com/leomeinel/arch-install/issues"
    exit 1
}

# Unmount everything from /mnt
mountpoint -q /mnt &&
    umount -AR /mnt

# Detect disks
readarray -t DISKS < <(lsblk -drnpo NAME -I 259,8,254 | tr -d "[:blank:]")
DISKS_LENGTH="${#DISKS[@]}"
for ((i = 0; i < DISKS_LENGTH; i++)); do
    udevadm info -q property --property=ID_BUS --value "${DISKS[$i]}" | grep -q "usb" &&
        {
            unset 'DISKS[$i]'
            continue
        }
    DISKS=("${DISKS[@]}")
done
[[ "${#DISKS[@]}" -ne 2 ]] &&
    {
        echo "ERROR: There are not exactly 2 disks attached!"
        exit 1
    }
SIZE1="$(lsblk -drno SIZE "${DISKS[0]}" | tr -d "[:space:]")"
SIZE2="$(lsblk -drno SIZE "${DISKS[1]}" | tr -d "[:space:]")"
if [[ "$SIZE1" = "$SIZE2" ]]; then
    DISK1="${DISKS[0]}"
    DISK2="${DISKS[1]}"
else
    echo "ERROR: The attached disks don't have the same size!"
    exit 1
fi

# Prompt user
read -rp "Erase $DISK1 and $DISK2? (Type 'yes' in capital letters): " choice
case "$choice" in
YES)
    echo "Erasing $DISK1 and $DISK2..."
    ;;
*)
    echo "ERROR: User aborted erasing $DISK1 and $DISK2"
    exit 1
    ;;
esac

# Detect & close old crypt volumes
if lsblk -rno TYPE | grep -q "crypt"; then
    OLD_CRYPT_0="$(lsblk -Mrno TYPE,NAME | grep "crypt" | sed 's/crypt//' | sed -n '1p' | tr -d "[:space:]")"
    cryptsetup close "$OLD_CRYPT_0"
fi

# Detect & erase old crypt/raid1 volumes
if lsblk -rno TYPE | grep -q "raid1"; then
    DISK1P2="$(lsblk -rnpo TYPE,NAME "$DISK1" | grep "part" | sed 's/part//' | sed -n '2p' | tr -d "[:space:]")"
    DISK2P2="$(lsblk -rnpo TYPE,NAME "$DISK2" | grep "part" | sed 's/part//' | sed -n '2p' | tr -d "[:space:]")"
    OLD_RAID_0="$(lsblk -Mrnpo TYPE,NAME | grep "raid1" | sed 's/raid1//' | sed -n '1p' | tr -d "[:space:]")"
    if cryptsetup isLuks "$OLD_RAID_0"; then
        cryptsetup erase "$OLD_RAID_0"
    fi
    sgdisk -Z "$OLD_RAID_0"
    mdadm --stop "$OLD_RAID_0"
    mdadm --zero-superblock "$DISK1P2"
    mdadm --zero-superblock "$DISK2P2"
fi

# Load $KEYMAP & set time
loadkeys "$KEYMAP"
timedatectl set-ntp true

# Erase & partition disks
sgdisk -Z "$DISK1"
sgdisk -Z "$DISK2"
sgdisk -n 0:0:+1G -t 1:ef00 "$DISK1"
sgdisk -n 0:0:+1G -t 1:ef00 "$DISK2"
sgdisk -n 0:0:0 -t 2:fd00 "$DISK1"
sgdisk -n 0:0:0 -t 2:fd00 "$DISK2"

# Detect partitions & set variables accordingly
DISK1P1="$(lsblk -rnpo TYPE,NAME "$DISK1" | grep "part" | sed 's/part//' | sed -n '1p' | tr -d "[:space:]")"
DISK1P2="$(lsblk -rnpo TYPE,NAME "$DISK1" | grep "part" | sed 's/part//' | sed -n '2p' | tr -d "[:space:]")"
DISK2P1="$(lsblk -rnpo TYPE,NAME "$DISK2" | grep "part" | sed 's/part//' | sed -n '1p' | tr -d "[:space:]")"
DISK2P2="$(lsblk -rnpo TYPE,NAME "$DISK2" | grep "part" | sed 's/part//' | sed -n '2p' | tr -d "[:space:]")"

# Configure raid1
mdadm --create --verbose --level=1 --metadata=1.2 --raid-devices=2 --homehost=any --name=md0 /dev/md/md0 "$DISK1P2" "$DISK2P2"

# Configure encryption
## root
cryptsetup open --type plain -d /dev/urandom /dev/md/md0 to_be_wiped
cryptsetup close to_be_wiped
cryptsetup -y -v -h sha512 -s 512 luksFormat --type luks2 /dev/md/md0
cryptsetup open --type luks2 --perf-no_read_workqueue --perf-no_write_workqueue --persistent /dev/md/md0 md0_crypt

# Configure lvm
pvcreate /dev/mapper/md0_crypt
vgcreate vg0 /dev/mapper/md0_crypt
lvcreate -l "${DISK_ALLOCATION[0]}" vg0 -n lv0
lvcreate -l "${DISK_ALLOCATION[1]}" vg0 -n lv1
lvcreate -l "${DISK_ALLOCATION[2]}" vg0 -n lv2
lvcreate -l "${DISK_ALLOCATION[3]}" vg0 -n lv3

# Format efi
mkfs.fat -n EFI -F32 "$DISK1P1"
mkfs.fat -n EFI -F32 "$DISK2P1"

# Configure mounts
## Create subvolumes
SUBVOLUMES_LENGTH="${#SUBVOLUMES[@]}"
[[ "$SUBVOLUMES_LENGTH" -ne "${#CONFIGS[@]}" ]] &&
    {
        echo "ERROR: SUBVOLUMES and CONFIGS aren't the same length!"
        exit 1
    }
create_subs0() {
    mkfs.btrfs -L "$3" "$4"
    mount "$4" /mnt
    btrfs subvolume create "/mnt/@$2"
    btrfs subvolume create "/mnt/@${2}_snapshots"
    create_subs1 "$1"
    umount /mnt
}
create_subs1() {
    for ((a = 0; a < SUBVOLUMES_LENGTH; a++)); do
        if [[ "${SUBVOLUMES[$a]}" != "$1" ]] && grep -nq "^$1" <<<"${SUBVOLUMES[$a]}"; then
            btrfs subvolume create "/mnt/@${CONFIGS[$a]}"
            btrfs subvolume create "/mnt/@${CONFIGS[$a]}_snapshots"
        fi
    done
}
for ((i = 0; i < SUBVOLUMES_LENGTH; i++)); do
    case "${SUBVOLUMES[$i]}" in
    "/")
        mkfs.btrfs -L ROOT /dev/mapper/vg0-lv0
        mount /dev/mapper/vg0-lv0 /mnt
        btrfs subvolume create /mnt/@
        btrfs subvolume create /mnt/@snapshots
        umount /mnt
        ;;
    "/usr/")
        create_subs0 "${SUBVOLUMES[$i]}" "${CONFIGS[$i]}" "USR" "/dev/mapper/vg0-lv1"
        ;;
    "/var/")
        create_subs0 "${SUBVOLUMES[$i]}" "${CONFIGS[$i]}" "VAR" "/dev/mapper/vg0-lv2"
        ;;
    "/home/")
        create_subs0 "${SUBVOLUMES[$i]}" "${CONFIGS[$i]}" "HOME" "/dev/mapper/vg0-lv3"
        ;;
    esac
done
## Mount subvolumes
OPTIONS0="noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvol=/@"
OPTIONS1="nodev,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvol=/@"
OPTIONS2="nodev,nosuid,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvol=/@"
OPTIONS3="noexec,nodev,nosuid,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvol=/@"
mount_subs0() {
    mkdir "/mnt$1"
    mount -o "$3$2" "$4" "/mnt$1"
    mkdir "/mnt$1.snapshots"
    mount -o "$OPTIONS3${2}_snapshots" "$4" "/mnt${SUBVOLUMES[$i]}.snapshots"
    mount_subs1 "$1" "$3" "$4"
}
mount_subs1() {
    for ((a = 0; a < SUBVOLUMES_LENGTH; a++)); do
        if [[ "${SUBVOLUMES[$a]}" != "$1" ]] && grep -nq "^$1" <<<"${SUBVOLUMES[$a]}"; then
            mkdir "/mnt${SUBVOLUMES[$a]}"
            if grep -nq "^${1}lib/" <<<"${SUBVOLUMES[$a]}"; then
                mount -o "$OPTIONS3${CONFIGS[$a]}" "$3" "/mnt${SUBVOLUMES[$a]}"
            else
                mount -o "$2${CONFIGS[$a]}" "$3" "/mnt${SUBVOLUMES[$a]}"
            fi
            mkdir "/mnt${SUBVOLUMES[$a]}.snapshots"
            mount -o "$OPTIONS3${CONFIGS[$a]}_snapshots" "$3" "/mnt${SUBVOLUMES[$a]}.snapshots"
        fi
    done
}
for ((i = 0; i < SUBVOLUMES_LENGTH; i++)); do
    case "${SUBVOLUMES[$i]}" in
    "/")
        mount -o "$OPTIONS0" /dev/mapper/vg0-lv0 "/mnt${SUBVOLUMES[$i]}"
        mkdir "/mnt${SUBVOLUMES[$i]}.snapshots"
        mount -o "${OPTIONS3}snapshots" /dev/mapper/vg0-lv0 "/mnt${SUBVOLUMES[$i]}.snapshots"
        ;;
    "/usr/")
        mount_subs0 "${SUBVOLUMES[$i]}" "${CONFIGS[$i]}" "$OPTIONS1" "/dev/mapper/vg0-lv1"
        ;;
    "/var/")
        mount_subs0 "${SUBVOLUMES[$i]}" "${CONFIGS[$i]}" "$OPTIONS2" "/dev/mapper/vg0-lv2"
        ;;
    "/home/")
        mount_subs0 "${SUBVOLUMES[$i]}" "${CONFIGS[$i]}" "$OPTIONS2" "/dev/mapper/vg0-lv3"
        ;;
    esac
done
chmod 775 /mnt/var/games
## /efi
mkdir /mnt/efi
mount -o noexec,nodev,nosuid "$DISK1P1" /mnt/efi
mkdir /mnt/.efi.bak
mount -o noexec,nodev,nosuid "$DISK2P1" /mnt/.efi.bak
## /boot
mkdir /mnt/boot

# Set SSD state to "frozen" after sleep
for link in /dev/disk/by-id/*; do
    if [[ "$(readlink -f "$link")" = "$DISK1" ]]; then
        DISK1ID="$link"
    fi
    if [[ "$(readlink -f "$link")" = "$DISK2" ]]; then
        DISK2ID="$link"
    fi
done
if [[ -n "$DISK1ID" ]] && [[ -n "$DISK2ID" ]]; then
    mkdir -p /mnt/usr/lib/systemd/system-sleep
    {
        echo 'if [[ "$1" = "post" ]]; then'
        echo '    sleep 1'
        echo '    if hdparm --security-freeze '"$DISK1ID"'; then'
        echo '        logger "$0: SSD freeze command executed successfully"'
        echo '    else'
        echo '        logger "$0: SSD freeze command failed"'
        echo '    fi'
        echo '    if hdparm --security-freeze '"$DISK2ID"'; then'
        echo '        logger "$0: SSD freeze command executed successfully"'
        echo '    else'
        echo '        logger "$0: SSD freeze command failed"'
        echo '    fi'
        echo 'fi'
    } >/mnt/usr/lib/systemd/system-sleep/freeze-ssd.sh
    chmod 755 /mnt/usr/lib/systemd/system-sleep/freeze-ssd.sh
fi

# Install packages
## START sed
FILE=/etc/pacman.conf
STRING="^#Color"
grep -q "$STRING" "$FILE" || sed_exit
sed -i "s/$STRING/Color/" "$FILE"
STRING="^#ParallelDownloads =.*"
grep -q "$STRING" "$FILE" || sed_exit
sed -i "s/$STRING/ParallelDownloads = 10/" "$FILE"
STRING="^#NoProgressBar"
grep -q "$STRING" "$FILE" || sed_exit
sed -i "s/$STRING/NoProgressBar/" "$FILE"
## END sed
reflector --save /etc/pacman.d/mirrorlist --country "$MIRRORCOUNTRIES" --protocol https --latest 20 --sort rate
pacman -Sy --noprogressbar --noconfirm archlinux-keyring lshw
lscpu | grep "Vendor ID:" | grep -q "GenuineIntel" &&
    echo "intel-ucode" >>"$SCRIPT_DIR/pkgs-prepare.txt"
lscpu | grep "Vendor ID:" | grep -q "AuthenticAMD" &&
    echo "amd-ucode" >>"$SCRIPT_DIR/pkgs-prepare.txt"
pacstrap /mnt - <"$SCRIPT_DIR/pkgs-prepare.txt"

# Configure /mnt/etc/fstab
genfstab -U /mnt >>/mnt/etc/fstab
{
    echo '# tmpfs'
    echo 'tmpfs /dev/shm tmpfs rw,noexec,nodev,nosuid 0 0'
    echo 'tmpfs /tmp tmpfs rw,nodev,nosuid,uid=0,gid=0,mode=1700 0 0'
} >>/mnt/etc/fstab
## START sed
FILE=/mnt/etc/fstab
STRING0="\/.efi.bak.*vfat"
grep -q "$STRING0" "$FILE" || sed_exit
STRING1="rw"
grep -q "$STRING1" "$FILE" || sed_exit
sed -i "/$STRING0/s/$STRING1/$STRING1,noauto/" "$FILE"
## END sed

# Configure /mnt/etc/resolv.conf
ln -sf /run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf

# Prepare /mnt/git/arch-install
mkdir /mnt/git
mv "$SCRIPT_DIR" /mnt/git/
chmod +x /mnt/git/arch-install/setup.sh
