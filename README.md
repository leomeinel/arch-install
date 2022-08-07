# mdadm-encrypted-btrfs
Arch Linux Installation using mdadm RAID1, LUKS encryption and btrfs

## Installation

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

If you have devices that are encrypted before installation run
```
lsblk (encrypted partitions = <partition>)
cryptsetup erase /dev/<partition>
wipefs -a /dev/<partition>
```
