# mdadm-encrypted-btrfs
Arch Linux Installation using mdadm RAID1, LUKS encryption and btrfs

## Installation

If you have devices that were encrypted before the installation run this before continuing!
```
lsblk (encrypted device = <device>)
cryptsetup erase /dev/<device>
wipefs -a /dev/<device>
```

If you have devices that are using mdadm-raid before the installation run this before continuing!
```
lsblk (raid device = <device>)
mdadm --stop /dev/<device>
```

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
