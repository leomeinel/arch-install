# mdadm-encrypted-btrfs
Arch Linux Installation using mdadm RAID1, LUKS encryption and btrfs

## Installation

Make sure that any raid arrays, encryptions and partitions are removed before continuing!

```
pacman -Sy git
git clone https://github.com/LeoMeinel/mdadm-encrypted-btrfs.git
chmod +x /root/mdadm-encrypted-btrfs/partition-disks.sh
vim /root/mdadm-encrypted-btrfs/partition-disks.sh
/root/mdadm-encrypted-btrfs/partition-disks.sh
arch-chroot /mnt
vim /git/mdadm-encrypted-btrfs/setup.sh
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
Set `chrome://flags/#extension-mime-request-handling` in `ungoogled-chromium` to `Always prompt for install`
