# mdadm-encrypted-btrfs
Arch Linux Installation using mdadm RAID1, LUKS encryption and btrfs

## Installation

Make sure that any raid arrays, encryptions and partitions are removed before continuing!

```
pacman -Sy git
git clone https://github.com/LeoMeinel/mdadm-encrypted-btrfs.git
chmod +x /root/mdadm-encrypted-btrfs/partition-disks.sh
/root/mdadm-encrypted-btrfs/partition-disks.sh
arch-chroot /mnt
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
