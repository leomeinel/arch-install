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

KEYMAP="de-latin1"
MIRRORCOUNTRIES="NL,DE,DK,FR"

# Fail on error
set -eu

# Unmount everything from /mnt
mountpoint -q /mnt &&
    umount -AR /mnt

# Prompt user for disk
# I will use this on an external SSD, therefore USB volumes will be listed too
lsblk -drnpo SIZE,NAME -I 259,8,254
read -rp "Which disk do you want to erase? (Type '/dev/sdX' fex.): " choice
if lsblk -drnpo SIZE,NAME -I 259,8,254 $choice; then
    echo "Erasing $choice..."
    DISK1="$choice"
else
    echo "ERROR: Drive not suitable for installation"
    exit 125
fi

# Detect & close old crypt volumes
if lsblk -rno TYPE | grep -q "crypt"; then
    OLD_CRYPT_0="$(lsblk -Mrno TYPE,NAME $DISK1 | grep "crypt" | sed 's/crypt//' | sed -n '1p' | tr -d "[:space:]")"
    OLD_CRYPT_1="$(lsblk -Mrno TYPE,NAME $DISK1 | grep "crypt" | sed 's/crypt//' | sed -n '2p' | tr -d "[:space:]")"
    cryptsetup close "$OLD_CRYPT_0"
    cryptsetup close "$OLD_CRYPT_1"
fi

# Detect & erase old crypt volumes
DISK1P2="$(lsblk -rnpo TYPE,NAME $DISK1 | grep "part" | sed 's/part//' | sed -n '2p' | tr -d "[:space:]")"
if cryptsetup isLuks "$DISK1P2"; then
    cryptsetup erase "$DISK1P2"
    sgdisk -Z "$DISK1P2"
else
    echo "ERROR: Can't erase old crypt volume"
    exit 125
fi
DISK1P3="$(lsblk -rnpo TYPE,NAME $DISK1 | grep "part" | sed 's/part//' | sed -n '3p' | tr -d "[:space:]")"
if cryptsetup isLuks "$DISK1P3"; then
    cryptsetup erase "$DISK1P3"
    sgdisk -Z "$DISK1P3"
else
    echo "ERROR: Can't erase old crypt volume"
    exit 125
fi

# Load $KEYMAP & set time
loadkeys "$KEYMAP"
timedatectl set-ntp true

# Erase & partition disks
sgdisk -Z "$DISK1"
sgdisk -n 0:0:+1G -t 1:ef00 "$DISK1"
sgdisk -n 0:0:+1G -t 1:ef02 "$DISK1"
sgdisk -n 0:0:0 -t 1:8300 "$DISK1"

# Detect partitions & set variables accordingly
DISK1P1="$(lsblk -rnpo TYPE,NAME "$DISK1" | grep "part" | sed 's/part//' | sed -n '1p' | tr -d "[:space:]")"
DISK1P2="$(lsblk -rnpo TYPE,NAME "$DISK1" | grep "part" | sed 's/part//' | sed -n '2p' | tr -d "[:space:]")"
DISK1P3="$(lsblk -rnpo TYPE,NAME "$DISK1" | grep "part" | sed 's/part//' | sed -n '3p' | tr -d "[:space:]")"

# Configure encryption
# md0_crypt & md1_crypt will be used for convenience, even tho it might be confusing
## boot
cryptsetup open --type plain -d /dev/urandom "$DISK1P2" to_be_wiped
cryptsetup close to_be_wiped
echo -e "\e[31mUS keymap will be used when booting from\e[0m $DISK1P2"
cryptsetup -y -v -h sha512 -s 512 luksFormat --type luks1 "$DISK1P2"
cryptsetup open --type luks1 "$DISK1P2" md0_crypt
## root
cryptsetup open --type plain -d /dev/urandom "$DISK1P3" to_be_wiped
cryptsetup close to_be_wiped
cryptsetup -y -v -h sha512 -s 512 luksFormat --type luks2 "$DISK1P3"
cryptsetup open --type luks2 "$DISK1P3" md1_crypt

# Format efi
mkfs.fat -n EFI -F32 "$DISK1P1"

# Format boot
mkfs.ext4 -L BOOT /dev/mapper/md0_crypt

# Configure btrfs
mkfs.btrfs -L MDCRYPT /dev/mapper/md1_crypt
mount /dev/mapper/md1_crypt /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@var_cache
btrfs subvolume create /mnt/@var_games
btrfs subvolume create /mnt/@var_lib_libvirt
btrfs subvolume create /mnt/@var_lib_mysql
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots

# Mount volumes
umount /mnt
mount -o noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=256 /dev/mapper/md1_crypt /mnt
mkdir /mnt/efi
mkdir /mnt/boot
mkdir /mnt/var &&
    {
        mkdir /mnt/var/cache
        mkdir /mnt/var/games
        mkdir /mnt/var/lib &&
            {
                mkdir /mnt/var/lib/libvirt
                mkdir /mnt/var/lib/mysql
            }
        mkdir /mnt/var/log
    }
mkdir /mnt/home
mkdir /mnt/.snapshots
mount -o nodev,nosuid,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=257 /dev/mapper/md1_crypt /mnt/var/cache
mount -o nodev,nosuid,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=258 /dev/mapper/md1_crypt /mnt/var/games
mount -o noexec,nodev,nosuid,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=259 /dev/mapper/md1_crypt /mnt/var/lib/libvirt
mount -o noexec,nodev,nosuid,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=260 /dev/mapper/md1_crypt /mnt/var/lib/mysql
mount -o noexec,nodev,nosuid,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=261 /dev/mapper/md1_crypt /mnt/var/log
mount -o nodev,nosuid,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=262 /dev/mapper/md1_crypt /mnt/home
mount -o noexec,nodev,nosuid,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=263 /dev/mapper/md1_crypt /mnt/.snapshots
mount -o noexec,nodev,nosuid "$DISK1P1" /mnt/efi
mount -o noexec,nodev,nosuid /dev/mapper/md0_crypt /mnt/boot
chmod 775 /mnt/var/games

# Set SSD state to "frozen" after sleep
mkdir -p /mnt/usr/lib/systemd/system-sleep
DISK1UUID="$(blkid -s UUID -o value $DISK1)"
{
    echo 'if [ "$1" = "post" ]; then'
    echo '    sleep 1'
    echo '    if hdparm --security-freeze /dev/disk/by-uuid/'"$DISK1UUID"'; then'
    echo '        logger "$0: SSD freeze command executed successfully"'
    echo '    else'
    echo '        logger "$0: SSD freeze command failed"'
    echo '    fi'
    echo 'fi'
} >/mnt/usr/lib/systemd/system-sleep/freeze-ssd.sh
chmod 744 /mnt/usr/lib/systemd/system-sleep/freeze-ssd.sh

# Install packages
sed -i 's/^#Color/Color/;s/^#ParallelDownloads =.*/ParallelDownloads = 10/;s/^#NoProgressBar/NoProgressBar/' /etc/pacman.conf
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
lshw -C display | grep "vendor:" | grep -q "NVIDIA Corporation" &&
    {
        echo "egl-wayland"
        echo "nvidia-dkms"
        echo "lib32-nvidia-utils"
    } >>/root/arch-install/pkgs-prepare.txt
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

# Prepare /mnt/git/arch-install/setup.sh
git clone -b games https://github.com/LeoMeinel/arch-install.git /mnt/git/arch-install
chmod +x /mnt/git/arch-install/setup.sh

# Remove repo
rm -rf /root/arch-install
