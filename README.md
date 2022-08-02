# mdadm-encrypted-btrfs
Arch Linux Installation using mdadm RAID1, LUKS encryption and btrfs (Only works on empty drives)

## Installation

```
loadkeys de-latin1
pacman -Sy git
git clone https://github.com/LeoMeinel/mdadm-encrypted-btrfs.git
chmod +x /root/mdadm-encrypted-btrfs/partition-disks.sh
/root/mdadm-encrypted-btrfs/partition-disks.sh
arch-chroot /mnt
/git/mdadm-encrypted-btrfs/setup.sh
exit
reboot
```
