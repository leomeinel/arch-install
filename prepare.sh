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
set -eu

# Define functions
sed_exit() {
    echo "ERROR: 'sed' didn't replace, report this @"
    echo "       https://github.com/leomeinel/arch-install/issues"
    exit 1
}

# Unmount everything from /mnt
mountpoint -q /mnt &&
    umount -AR /mnt

# Prompt user for disk
# I will use this on an external SSD, therefore USB volumes will be valid
lsblk -drnpo SIZE,NAME -I 259,8,254
read -rp "Which disk do you want to erase? (Type '/dev/sdX' fex.): " choice
if lsblk -drnpo SIZE,NAME -I 259,8,254 $choice; then
    echo "Erasing $choice..."
    DISK1="$choice"
else
    echo "ERROR: Drive not suitable for installation"
    exit 1
fi

# Detect, close & erase old crypt volumes
if lsblk -rno TYPE "$DISK1" | grep -q "crypt"; then
    OLD_CRYPT_0="$(lsblk -Mrno TYPE,NAME $DISK1 | grep "crypt" | sed 's/crypt//' | sed -n '1p' | tr -d "[:space:]")"
    OLD_DISK1P2="$(lsblk -rnpo TYPE,NAME $DISK1 | grep "part" | sed 's/part//' | sed -n '2p' | tr -d "[:space:]")"
    ## Close old crypt volumes
    cryptsetup close "$OLD_CRYPT_0"
    ## Erase old crypt volumes
    if cryptsetup isLuks "$OLD_DISK1P2"; then
        cryptsetup erase "$OLD_DISK1P2"
        sgdisk -Z "$OLD_DISK1P2"
    else
        echo "ERROR: Can't erase old crypt volume"
        exit 1
    fi
fi

# Load $KEYMAP & set time
loadkeys "$KEYMAP"
timedatectl set-ntp true

# Erase & partition disks
sgdisk -Z "$DISK1"
sgdisk -n 0:0:+1G -t 1:ef00 "$DISK1"
sgdisk -n 0:0:0 -t 2:8300 "$DISK1"

# Detect partitions & set variables accordingly
DISK1P1="$(lsblk -rnpo TYPE,NAME "$DISK1" | grep "part" | sed 's/part//' | sed -n '1p' | tr -d "[:space:]")"
DISK1P2="$(lsblk -rnpo TYPE,NAME "$DISK1" | grep "part" | sed 's/part//' | sed -n '2p' | tr -d "[:space:]")"

# Configure encryption
## NOTE: md0_crypt will be used for convenience, even tho it might be confusing
## root
cryptsetup open --type plain -d /dev/urandom "$DISK1P2" to_be_wiped
cryptsetup close to_be_wiped
cryptsetup -y -v -h sha512 -s 512 luksFormat --type luks2 "$DISK1P2"
cryptsetup open --type luks2 "$DISK1P2" md0_crypt

# Configure lvm
pvcreate /dev/mapper/md0_crypt
vgcreate vg0 /dev/mapper/md0_crypt
lvcreate -l ${DISK_ALLOCATION[0]} vg0 -n lv0
lvcreate -l ${DISK_ALLOCATION[1]} vg0 -n lv1
lvcreate -l ${DISK_ALLOCATION[2]} vg0 -n lv2
lvcreate -l ${DISK_ALLOCATION[3]} vg0 -n lv3

# Format efi
mkfs.fat -n EFI -F32 "$DISK1P1"

# Configure btrfs
## /
mkfs.btrfs -L ROOT /dev/mapper/vg0-lv0
mount /dev/mapper/vg0-lv0 /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@snapshots
umount /mnt
## /usr
mkfs.btrfs -L USR /dev/mapper/vg0-lv1
mount /dev/mapper/vg0-lv1 /mnt
btrfs subvolume create /mnt/@usr
btrfs subvolume create /mnt/@usr_snapshots
umount /mnt
## /var
mkfs.btrfs -L VAR /dev/mapper/vg0-lv2
mount /dev/mapper/vg0-lv2 /mnt
btrfs subvolume create /mnt/@var
btrfs subvolume create /mnt/@var_snapshots
### /var/lib
btrfs subvolume create /mnt/@var_lib
btrfs subvolume create /mnt/@var_lib_snapshots
#### /var/lib/libvirt
btrfs subvolume create /mnt/@var_lib_libvirt
btrfs subvolume create /mnt/@var_lib_libvirt_snapshots
#### /var/lib/mysql
btrfs subvolume create /mnt/@var_lib_mysql
btrfs subvolume create /mnt/@var_lib_mysql_snapshots
### /var/cache
btrfs subvolume create /mnt/@var_cache
btrfs subvolume create /mnt/@var_cache_snapshots
### /var/games
btrfs subvolume create /mnt/@var_games
btrfs subvolume create /mnt/@var_games_snapshots
### /var/log
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@var_log_snapshots
umount /mnt
## /home
mkfs.btrfs -L HOME /dev/mapper/vg0-lv3
mount /dev/mapper/vg0-lv3 /mnt
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@home_snapshots
umount /mnt

# Mount volumes
## /
mount -o noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=256 /dev/mapper/vg0-lv0 /mnt
mkdir /mnt/.snapshots
mount -o noexec,nodev,nosuid,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=257 /dev/mapper/vg0-lv0 /mnt/.snapshots
## /usr
mkdir /mnt/usr
mount -o nodev,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=256 /dev/mapper/vg0-lv1 /mnt/usr
mkdir /mnt/usr/.snapshots
mount -o noexec,nodev,nosuid,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=257 /dev/mapper/vg0-lv1 /mnt/usr/.snapshots
## /var
mkdir /mnt/var
mount -o nodev,nosuid,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=256 /dev/mapper/vg0-lv2 /mnt/var
mkdir /mnt/var/.snapshots
mount -o noexec,nodev,nosuid,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=257 /dev/mapper/vg0-lv2 /mnt/var/.snapshots
### /var/lib
mkdir /mnt/var/lib
mount -o noexec,nodev,nosuid,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=258 /dev/mapper/vg0-lv2 /mnt/var/lib
mkdir /mnt/var/lib/.snapshots
mount -o noexec,nodev,nosuid,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=259 /dev/mapper/vg0-lv2 /mnt/var/lib/.snapshots
#### /var/lib/libvirt
mkdir /mnt/var/lib/libvirt
mount -o noexec,nodev,nosuid,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=260 /dev/mapper/vg0-lv2 /mnt/var/lib/libvirt
mkdir /mnt/var/lib/libvirt/.snapshots
mount -o noexec,nodev,nosuid,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=261 /dev/mapper/vg0-lv2 /mnt/var/lib/libvirt/.snapshots
#### /var/lib/mysql
mkdir /mnt/var/lib/mysql
mount -o noexec,nodev,nosuid,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=262 /dev/mapper/vg0-lv2 /mnt/var/lib/mysql
mkdir /mnt/var/lib/mysql/.snapshots
mount -o noexec,nodev,nosuid,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=263 /dev/mapper/vg0-lv2 /mnt/var/lib/mysql/.snapshots
### /var/cache
mkdir /mnt/var/cache
mount -o nodev,nosuid,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=264 /dev/mapper/vg0-lv2 /mnt/var/cache
mkdir /mnt/var/cache/.snapshots
mount -o noexec,nodev,nosuid,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=265 /dev/mapper/vg0-lv2 /mnt/var/cache/.snapshots
### /var/games
mkdir /mnt/var/games
chmod 775 /mnt/var/games
mount -o nodev,nosuid,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=266 /dev/mapper/vg0-lv2 /mnt/var/games
chmod 775 /mnt/var/games
mkdir /mnt/var/games/.snapshots
mount -o noexec,nodev,nosuid,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=267 /dev/mapper/vg0-lv2 /mnt/var/games/.snapshots
### /var/log
mkdir /mnt/var/log
mount -o noexec,nodev,nosuid,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=268 /dev/mapper/vg0-lv2 /mnt/var/log
mkdir /mnt/var/log/.snapshots
mount -o noexec,nodev,nosuid,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=269 /dev/mapper/vg0-lv2 /mnt/var/log/.snapshots
## /home
mkdir /mnt/home
mount -o nodev,nosuid,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=256 /dev/mapper/vg0-lv3 /mnt/home
mkdir /mnt/home/.snapshots
mount -o noexec,nodev,nosuid,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=257 /dev/mapper/vg0-lv3 /mnt/home/.snapshots
## /efi
mkdir /mnt/efi
mount -o noexec,nodev,nosuid "$DISK1P1" /mnt/efi
## /boot
mkdir /mnt/boot

# Set SSD state to "frozen" after sleep
for link in /dev/disk/by-id/*; do
    if [[ "$(readlink -f "$link")" = "$DISK1" ]]; then
        DISK1ID="$link"
    fi
done
mkdir -p /mnt/usr/lib/systemd/system-sleep
{
    echo 'if [[ "$1" = "post" ]]; then'
    echo '    sleep 1'
    echo '    if hdparm --security-freeze '"$DISK1ID"'; then'
    echo '        logger "$0: SSD freeze command executed successfully"'
    echo '    else'
    echo '        logger "$0: SSD freeze command failed"'
    echo '    fi'
    echo 'fi'
} >/mnt/usr/lib/systemd/system-sleep/freeze-ssd.sh
chmod 755 /mnt/usr/lib/systemd/system-sleep/freeze-ssd.sh

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
{
    echo ""
    echo "# Custom"
    echo "[multilib]"
    echo "Include = /etc/pacman.d/mirrorlist"
} >>/etc/pacman.conf
reflector --save /etc/pacman.d/mirrorlist --country $MIRRORCOUNTRIES --protocol https --latest 20 --sort rate
pacman -Sy --noprogressbar --noconfirm archlinux-keyring lshw
lscpu | grep "Vendor ID:" | grep -q "GenuineIntel" &&
    echo "intel-ucode" >>/root/arch-install/pkgs-prepare.txt
lscpu | grep "Vendor ID:" | grep -q "AuthenticAMD" &&
    echo "amd-ucode" >>/root/arch-install/pkgs-prepare.txt
lshw -C display | grep "vendor:" | grep -q "Advanced Micro Devices, Inc." &&
    {
        echo "libva-mesa-driver"
        echo "mesa-vdpau"
        echo "vulkan-radeon"
        echo "xf86-video-amdgpu"
    } >>/root/arch-install/pkgs-prepare.txt
lshw -C display | grep "vendor:" | grep -q "Intel Corporation" &&
    {
        echo "intel-media-driver"
        echo "vulkan-intel"
        echo "xf86-video-intel"
    } >>/root/arch-install/pkgs-prepare.txt
pacstrap /mnt - </root/arch-install/pkgs-prepare.txt

# Configure /mnt/etc/fstab
genfstab -U /mnt >>/mnt/etc/fstab
{
    echo '# tmpfs'
    echo 'tmpfs /dev/shm tmpfs rw,noexec,nodev,nosuid 0 0'
    echo 'tmpfs /tmp tmpfs rw,nodev,nosuid,uid=0,gid=0,mode=1700 0 0'
} >>/mnt/etc/fstab

# Prepare /mnt/git/arch-install
mkdir /mnt/git
mv "$SCRIPT_DIR" /mnt/git/
chmod +x /mnt/git/arch-install/setup.sh
