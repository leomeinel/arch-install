#!/bin/sh

DISK1="vda"
DISK2="vdb"

loadkeys de-latin1
ls /sys/firmware/efi/efivars
timedatectl set-ntp true
lsblk
sgdisk -o /dev/"$DISK1"
sgdisk -o /dev/"$DISK2"
sgdisk -n 0:0:+1G -t 1:ef00 /dev/"$DISK1"
sgdisk -n 0:0:+1G -t 1:ef00 /dev/"$DISK2"
sgdisk -n 0:0:0 -t 1:fd00 /dev/"$DISK1"
sgdisk -n 0:0:0 -t 1:fd00 /dev/"$DISK2"
mdadm --misc --zero-superblock /dev/"$DISK1"2
mdadm --misc --zero-superblock /dev/"$DISK2"2
mkfs.fat -n BOOT -F32 /dev/"$DISK1"1
mkfs.fat -n BOOT -F32 /dev/"$DISK2"1
mdadm --create --verbose --level=1 --metadata=1.2 --raid-devices=2 /dev/md0 /dev/"$DISK1"2 /dev/"$DISK2"2
cat /proc/mdstat
cryptsetup open --type plain -d /dev/urandom /dev/md0 to_be_wiped
cryptsetup close to_be_wiped
cryptsetup -y -v -h sha512 -s 512 luksFormat /dev/md0
cryptsetup luksOpen /dev/md0 md0_crypt
mkfs.btrfs -L MDCRYPT /dev/mapper/md0_crypt
mount /dev/mapper/md0_crypt /mnt
cd /mnt
btrfs subvolume create @
btrfs subvolume create @tmp
btrfs subvolume create @.snapshots
btrfs subvolume create @var
btrfs subvolume create @home
cd
btrfs subvolume list /mnt
umount /mnt
mount -o noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=256 /dev/mapper/md0_crypt /mnt
mkdir -p /mnt/boot
mkdir -p /mnt/tmp
mkdir -p /mnt/.snapshots
mkdir -p /mnt/var
mkdir -p /mnt/home
mount -o noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=257 /dev/mapper/md0_crypt /mnt/tmp
mount -o noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=258 /dev/mapper/md0_crypt /mnt/.snapshots
mount -o noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=259 /dev/mapper/md0_crypt /mnt/var
mount -o noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvolid=260 /dev/mapper/md0_crypt /mnt/home
mount /dev/"$DISK1"1 /mnt/boot
pacman -Sy archlinux-keyring
pacstrap /mnt base base-devel linux linux-firmware linux-headers vim btrfs-progs intel-ucode nvidia git
genfstab -U /mnt >> /mnt/etc/fstab
# Now do "arch-chroot /mnt" and ./setup.sh
