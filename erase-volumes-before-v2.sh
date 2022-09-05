#!/bin/bash

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

# Detect and close old crypt volumes
if lsblk -rno TYPE | grep -q "crypt"
then
  OLD_CRYPT_0="$(lsblk -Mrno TYPE,NAME | grep "crypt" | sed 's/crypt//' | sed -n '1p' | tr -d "[:space:]")"
  cryptsetup luksClose "$OLD_CRYPT_0"
fi

# Detect and erase old crypt/raid1 volumes
if lsblk -rno TYPE | grep -q "raid1"
then
  DISK1P2="$(lsblk -rnpo TYPE,NAME "$DISK1" | grep "part" | sed 's/part//' | sed -n '2p' | tr -d "[:space:]")"
  DISK2P2="$(lsblk -rnpo TYPE,NAME "$DISK2" | grep "part" | sed 's/part//' | sed -n '2p' | tr -d "[:space:]")"
  OLD_RAID_0="$(lsblk -Mrnpo TYPE,NAME | grep "raid1" | sed 's/raid1//' | sed -n '1p' | tr -d "[:space:]")"
  if cryptsetup isLuks "$OLD_RAID_0"
  then
    cryptsetup erase "$OLD_RAID_0"
  fi
  sgdisk -Z "$OLD_RAID_0"
  mdadm --stop "$OLD_RAID_0"
  mdadm --zero-superblock "$DISK1P2"
  mdadm --zero-superblock "$DISK2P2"
fi

# Erase disks
sgdisk -Z "$DISK1"
sgdisk -Z "$DISK2"
