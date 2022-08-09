# mdadm-encrypted-btrfs
Arch Linux Installation using mdadm RAID1, LUKS encryption and btrfs

## Installation

Make sure that any raid arrays, encryptions and partitions are removed before continuing!

```
pacman -Sy git
git clone https://github.com/LeoMeinel/mdadm-encrypted-btrfs.git
chmod +x /root/mdadm-encrypted-btrfs/partition-disks.sh
vim /root/mdadm-encrypted-btrfs/partition-disks.sh (EDIT VARIABLES AT THE TOP)
/root/mdadm-encrypted-btrfs/partition-disks.sh
arch-chroot /mnt
vim /git/mdadm-encrypted-btrfs/setup.sh (EDIT VARIABLES AT THE TOP)
/git/mdadm-encrypted-btrfs/setup.sh
exit
umount -a
reboot
```

## Post Installation

```
sudo timedatectl set-ntp true
sudo hwclock --systohc
```
