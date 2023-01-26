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

[ "${#DISKS[@]}" -ne 2 ] &&
    {
        echo "ERROR: There are not exactly 2 disks attached!"
        exit 19
    }

SIZE1="$(lsblk -drno SIZE "${DISKS[0]}" | tr -d "[:space:]")"
SIZE2="$(lsblk -drno SIZE "${DISKS[1]}" | tr -d "[:space:]")"
if [ "$SIZE1" = "$SIZE2" ]; then
    DISK1="${DISKS[0]}"
    DISK2="${DISKS[1]}"
else
    echo "ERROR: The attached disks don't have the same size!"
    exit 19
fi

# Prompt user
read -rp "Erase $DISK1 and $DISK2? (Type 'yes' in capital letters): " choice
case "$choice" in
YES)
    echo "Erasing $DISK1 and $DISK2..."
    ;;
*)
    echo "ERROR: User aborted erasing $DISK1 and $DISK2"
    exit 125
    ;;
esac

# Detect & close old crypt volumes
if lsblk -rno TYPE | grep -q "crypt"; then
    OLD_CRYPT_0="$(lsblk -Mrno TYPE,NAME | grep "crypt" | sed 's/crypt//' | sed -n '1p' | tr -d "[:space:]")"
    OLD_CRYPT_1="$(lsblk -Mrno TYPE,NAME | grep "crypt" | sed 's/crypt//' | sed -n '2p' | tr -d "[:space:]")"
    cryptsetup close "$OLD_CRYPT_0"
    cryptsetup close "$OLD_CRYPT_1"
fi

# Detect & erase old crypt/raid1 volumes
if lsblk -rno TYPE | grep -q "raid1"; then
    DISK1P2="$(lsblk -rnpo TYPE,NAME "$DISK1" | grep "part" | sed 's/part//' | sed -n '2p' | tr -d "[:space:]")"
    DISK2P2="$(lsblk -rnpo TYPE,NAME "$DISK2" | grep "part" | sed 's/part//' | sed -n '2p' | tr -d "[:space:]")"
    DISK1P3="$(lsblk -rnpo TYPE,NAME "$DISK1" | grep "part" | sed 's/part//' | sed -n '3p' | tr -d "[:space:]")"
    DISK2P3="$(lsblk -rnpo TYPE,NAME "$DISK2" | grep "part" | sed 's/part//' | sed -n '3p' | tr -d "[:space:]")"
    OLD_RAID_0="$(lsblk -Mrnpo TYPE,NAME | grep "raid1" | sed 's/raid1//' | sed -n '1p' | tr -d "[:space:]")"
    OLD_RAID_1="$(lsblk -Mrnpo TYPE,NAME | grep "raid1" | sed 's/raid1//' | sed -n '2p' | tr -d "[:space:]")"
    if cryptsetup isLuks "$OLD_RAID_0"; then
        cryptsetup erase "$OLD_RAID_0"
    fi
    if cryptsetup isLuks "$OLD_RAID_1"; then
        cryptsetup erase "$OLD_RAID_1"
    fi
    sgdisk -Z "$OLD_RAID_0"
    sgdisk -Z "$OLD_RAID_1"
    mdadm --stop "$OLD_RAID_0"
    mdadm --stop "$OLD_RAID_1"
    mdadm --zero-superblock "$DISK1P2"
    mdadm --zero-superblock "$DISK2P2"
    mdadm --zero-superblock "$DISK1P3"
    mdadm --zero-superblock "$DISK2P3"
fi

# Load $KEYMAP & set time
loadkeys "$KEYMAP"
timedatectl set-ntp true

# Erase & partition disks
sgdisk -Z "$DISK1"
sgdisk -Z "$DISK2"
sgdisk -n 0:0:+1G -t 1:ef00 "$DISK1"
sgdisk -n 0:0:+1G -t 1:ef00 "$DISK2"
sgdisk -n 0:0:+1G -t 1:fd00 "$DISK1"
sgdisk -n 0:0:+1G -t 1:fd00 "$DISK2"
sgdisk -n 0:0:0 -t 1:fd00 "$DISK1"
sgdisk -n 0:0:0 -t 1:fd00 "$DISK2"

# Detect partitions & set variables accordingly
DISK1P1="$(lsblk -rnpo TYPE,NAME "$DISK1" | grep "part" | sed 's/part//' | sed -n '1p' | tr -d "[:space:]")"
DISK1P2="$(lsblk -rnpo TYPE,NAME "$DISK1" | grep "part" | sed 's/part//' | sed -n '2p' | tr -d "[:space:]")"
DISK1P3="$(lsblk -rnpo TYPE,NAME "$DISK1" | grep "part" | sed 's/part//' | sed -n '3p' | tr -d "[:space:]")"
DISK2P1="$(lsblk -rnpo TYPE,NAME "$DISK2" | grep "part" | sed 's/part//' | sed -n '1p' | tr -d "[:space:]")"
DISK2P2="$(lsblk -rnpo TYPE,NAME "$DISK2" | grep "part" | sed 's/part//' | sed -n '2p' | tr -d "[:space:]")"
DISK2P3="$(lsblk -rnpo TYPE,NAME "$DISK2" | grep "part" | sed 's/part//' | sed -n '3p' | tr -d "[:space:]")"

# Configure raid1
mdadm --create --verbose --level=1 --metadata=1.2 --raid-devices=2 --homehost=any /dev/md/md0 "$DISK1P2" "$DISK2P2"
mdadm --create --verbose --level=1 --metadata=1.2 --raid-devices=2 --homehost=any /dev/md/md1 "$DISK1P3" "$DISK2P3"

# Configure encryption
## boot
cryptsetup open --type plain -d /dev/urandom /dev/md/md0 to_be_wiped
cryptsetup close to_be_wiped
echo -e "\e[31mUS keymap will be used when booting from\e[0m /dev/md/md0"
cryptsetup -y -v -h sha512 -s 512 luksFormat --type luks1 /dev/md/md0
cryptsetup open --type luks1 /dev/md/md0 md0_crypt
## root
cryptsetup open --type plain -d /dev/urandom /dev/md/md1 to_be_wiped
cryptsetup close to_be_wiped
cryptsetup -y -v -h sha512 -s 512 luksFormat --type luks2 /dev/md/md1
cryptsetup open --type luks2 /dev/md/md1 md1_crypt

# Format efi
mkfs.fat -n EFI -F32 "$DISK1P1"
mkfs.fat -n EFI -F32 "$DISK2P1"

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
mkdir /mnt/.efi.bak
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
mount -o noexec,nodev,nosuid "$DISK2P1" /mnt/.efi.bak
mount -o noexec,nodev,nosuid /dev/mapper/md0_crypt /mnt/boot
chmod 775 /mnt/var/games

# Set SSD state to "frozen" after sleep
mkdir -p /mnt/usr/lib/systemd/system-sleep
DISK1UUID="$(blkid -s UUID -o value $DISK1)"
DISK2UUID="$(blkid -s UUID -o value $DISK2)"
{
    echo 'if [ "$1" = "post" ]; then'
    echo '    sleep 1'
    echo '    if hdparm --security-freeze /dev/disk/by-uuid/'"$DISK1UUID"'; then'
    echo '        logger "$0: SSD freeze command executed successfully"'
    echo '    else'
    echo '        logger "$0: SSD freeze command failed"'
    echo '    fi'
    echo '    if hdparm --security-freeze /dev/disk/by-uuid/'"$DISK2UUID"'; then'
    echo '        logger "$0: SSD freeze command executed successfully"'
    echo '    else'
    echo '        logger "$0: SSD freeze command failed"'
    echo '    fi'
    echo 'fi'
} >/mnt/usr/lib/systemd/system-sleep/freeze-ssd.sh
chmod 744 /mnt/usr/lib/systemd/system-sleep/freeze-ssd.sh

# Install packages
## START sed
FILE=/etc/pacman.conf
STRING="^#Color"
grep -q "$STRING" "$FILE" &&
    sed -i "s/$STRING/Color/" "$FILE"
STRING="^#ParallelDownloads =.*"
grep -q "$STRING" "$FILE" &&
    sed -i "s/$STRING/ParallelDownloads = 10/" "$FILE"
STRING="^#NoProgressBar"
grep -q "$STRING" "$FILE" &&
    sed -i "s/$STRING/NoProgressBar/" "$FILE"
## END sed
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
## START sed
FILE=/mnt/etc/fstab
STRING0="\/.efi.bak.*vfat"
grep -q "$STRING0" "$FILE" &&
    {
        STRING1="rw"
        grep -q "$STRING1" "$FILE" &&
            sed -i "/$STRING0/s/$STRING1/$STRING1,noauto/" "$FILE"
    }
## END sed

# Prepare /mnt/git/arch-install/setup.sh
git clone https://github.com/LeoMeinel/arch-install.git /mnt/git/arch-install
chmod +x /mnt/git/arch-install/setup.sh

# Remove repo
rm -rf /root/arch-install
