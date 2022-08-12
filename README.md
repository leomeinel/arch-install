# mdadm-encrypted-btrfs

Arch Linux Installation using mdadm RAID1, LUKS encryption and btrfs

## Installation

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
```

=> Reboot now

## Post Installation

Log into sysuser account and run

```
~/post-install.sh

```
Set `chrome://flags/#extension-mime-request-handling` in `ungoogled-chromium` to `Always prompt for install`

=> Install Sweet KDE & Papirus through System Settings

=> Reboot now
