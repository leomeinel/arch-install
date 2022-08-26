#!/bin/bash

KEYMAP="de-latin1"
MIRRORCOUNTRIES="NL,DE,DK,FR"

# Fail on error
set -e

# Unmount everything from /mnt
mountpoint -q /mnt &&
umount -AR /mnt

# Detect disks
readarray -t DISKS < <(lsblk -drnpo NAME -I 259,8,254 | tr -d "[:blank:]")
DISKS_LENGTH="${#DISKS[@]}"
for (( i = 0; i < DISKS_LENGTH; i++ ))
do
  udevadm info -q property --property=ID_BUS --value "${DISKS[$i]}" | grep -q "usb" &&
  {
    unset 'DISKS[$i]'
    continue
  }
  DISKS=( "${DISKS[@]}" )
done

[ "${#DISKS[@]}" -ne 2 ] &&
{
  echo "ERROR: There are not exactly 2 disks attached!"
  exit 19
}

SIZE1="$(lsblk -drno SIZE "${DISKS[0]}" | tr -d "[:space:]")"
SIZE2="$(lsblk -drno SIZE "${DISKS[1]}" | tr -d "[:space:]")"
if [ "$SIZE1" = "$SIZE2" ]
then
  DISK1="${DISKS[0]}"
  DISK2="${DISKS[1]}"
else
  echo "ERROR: The attached disks don't have the same size!"
  exit 19
fi

# Prompt user
read -rp "Erase $DISK1 and $DISK2? (Type 'yes' in capital letters): " choice
case "$choice" in
  YES ) echo "Erasing $DISK1 and $DISK2..."
  ;;
  * ) echo "ERROR: User aborted erasing $DISK1 and $DISK2"
  exit 125
  ;;
esac

# Detect and erase old crypt volumes
if lsblk -rno TYPE | grep -q "crypt"
then
  OLD_CRYPT="$(lsblk -Mrno TYPE,NAME | grep "crypt" | sed 's/crypt//' | tr -d "[:space:]")"
  DISK1P2="$(lsblk -rnpo NAME "$DISK1" | sed -n '3p' | tr -d "[:space:]")"
  DISK2P2="$(lsblk -rnpo NAME "$DISK2" | sed -n '3p' | tr -d "[:space:]")"
  cryptsetup luksClose "$OLD_CRYPT"
  if lsblk -rno TYPE | grep -q "raid1"
  then
    OLD_RAID="$(lsblk -Mrnpo TYPE,NAME | grep "raid1" | sed 's/raid1//' | tr -d "[:space:]")"
    cryptsetup erase "$OLD_RAID"
    sgdisk -Z "$OLD_RAID"
    mdadm --stop --scan
    mdadm --zero-superblock "$DISK1P2"
    mdadm --zero-superblock "$DISK2P2"
  fi
fi

# Detect and erase closed crypt and raid1 volumes
if lsblk -rno TYPE | grep -q "raid1"
then
  DISK1P2="$(lsblk -rnpo NAME "$DISK1" | sed -n '3p' | tr -d "[:space:]")"
  DISK2P2="$(lsblk -rnpo NAME "$DISK2" | sed -n '3p' | tr -d "[:space:]")"
  OLD_RAID="$(lsblk -Mrnpo TYPE,NAME | grep "raid1" | sed 's/raid1//' | tr -d "[:space:]")"
  if cryptsetup isLuks "$OLD_RAID"
  then
    cryptsetup erase "$OLD_RAID"
  fi
  sgdisk -Z "$OLD_RAID"
  mdadm --stop --scan
  mdadm --zero-superblock "$DISK1P2"
  mdadm --zero-superblock "$DISK2P2"
fi

# Load $KEYMAP and set time
loadkeys "$KEYMAP"
timedatectl set-ntp true

# Erase and partition disks
sgdisk -Z "$DISK1"
sgdisk -Z "$DISK2"
sgdisk -n 0:0:+1G -t 1:ef00 "$DISK1"
sgdisk -n 0:0:+1G -t 1:ef00 "$DISK2"
sgdisk -n 0:0:0 -t 1:fd00 "$DISK1"
sgdisk -n 0:0:0 -t 1:fd00 "$DISK2"

# Detect partitions and set variables accordingly
DISK1P1="$(lsblk -rnpo NAME "$DISK1" | sed -n '2p' | tr -d "[:space:]")"
DISK1P2="$(lsblk -rnpo NAME "$DISK1" | sed -n '3p' | tr -d "[:space:]")"
DISK2P1="$(lsblk -rnpo NAME "$DISK2" | sed -n '2p' | tr -d "[:space:]")"
DISK2P2="$(lsblk -rnpo NAME "$DISK2" | sed -n '3p' | tr -d "[:space:]")"

# Configure raid1
mdadm --create --verbose --level=1 --metadata=1.2 --raid-devices=2 --homehost=any /dev/md/md0 "$DISK1P2" "$DISK2P2"

# Configure encryption
cryptsetup open --type plain -d /dev/urandom /dev/md/md0 to_be_wiped
cryptsetup close to_be_wiped
cryptsetup -y -v -h sha512 -s 512 luksFormat /dev/md/md0
cryptsetup luksOpen /dev/md/md0 md0_crypt

# Format boot
mkfs.fat -n BOOT -F32 "$DISK1P1"
mkfs.fat -n BOOT -F32 "$DISK2P1"

# Configure btrfs
mkfs.btrfs -L MDCRYPT /dev/mapper/md0_crypt
mount /dev/mapper/md0_crypt /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@var
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@tmp
btrfs subvolume create /mnt/@snapshots

# Mount volumes
umount /mnt
mount -o noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=256 /dev/mapper/md0_crypt /mnt
mkdir /mnt/var
mkdir /mnt/home
mkdir /mnt/tmp
mkdir /mnt/.snapshots
mkdir /mnt/boot
mount -o noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=257 /dev/mapper/md0_crypt /mnt/var
mount -o noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=258 /dev/mapper/md0_crypt /mnt/home
mount -o noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=259 /dev/mapper/md0_crypt /mnt/tmp
mount -o noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=260 /dev/mapper/md0_crypt /mnt/.snapshots
mount "$DISK1P1" /mnt/boot

# Install packages
{
  echo "base"
  echo "base-devel"
  echo "linux"
  echo "linux-firmware"
  echo "linux-headers"
  echo "neovim"
  echo "btrfs-progs"
  echo "git"
  echo "iptables"
  echo "reflector"
  echo "mesa"
  echo "mdadm"
} > /root/packages.txt
sed -i 's/#Color/Color/;s/#ParallelDownloads = 5/ParallelDownloads = 10/;s/#NoProgressBar/NoProgressBar/' /etc/pacman.conf
reflector --save /etc/pacman.d/mirrorlist --country $MIRRORCOUNTRIES --protocol https --latest 20 --sort rate
pacman -Sy --noprogressbar --noconfirm archlinux-keyring lshw
lscpu | grep "Vendor ID:" | grep -q "GenuineIntel" &&
echo "intel-ucode" >> /root/packages.txt
lscpu | grep "Vendor ID:" | grep -q "AuthenticAMD" &&
echo "amd-ucode" >> /root/packages.txt
lshw -C display | grep "vendor:" | grep -q "NVIDIA Corporation" &&
{
  echo "nvidia"
  echo "nvidia-settings"
} >> /root/packages.txt
lshw -C display | grep "vendor:" | grep -q "Advanced Micro Devices, Inc." &&
{
  echo "xf86-video-amdgpu"
  echo "vulkan-radeon"
  echo "libva-mesa-driver"
  echo "mesa-vdpau"
} >> /root/packages.txt
lshw -C display | grep "vendor:" | grep -q "Intel Corporation" &&
{
  echo "xf86-video-intel"
  echo "vulkan-intel"
} >> /root/packages.txt
pacstrap /mnt - < /root/packages.txt

# Configure /mnt/etc/fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Prepare /mnt/git/mdadm-encrypted-btrfs/setup.sh
git clone https://github.com/LeoMeinel/mdadm-encrypted-btrfs.git /mnt/git/mdadm-encrypted-btrfs
chmod +x /mnt/git/mdadm-encrypted-btrfs/setup.sh

# Remove repo
rm -rf /root/mdadm-encrypted-btrfs
rm -f /root/packages.txt
