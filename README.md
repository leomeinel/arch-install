# mdadm-encrypted-btrfs

Arch Linux Installation using mdadm RAID1, LUKS encryption and btrfs

## Pre-installation

Follow the `Pre-installation` section of this [guide](https://wiki.archlinux.org/title/Installation_guide#Pre-installation) until (including) the `Connect to the internet` section if needed.

## Installation

```
pacman -Sy git
git clone https://github.com/LeoMeinel/mdadm-encrypted-btrfs.git
chmod +x /root/mdadm-encrypted-btrfs/partition-disks.sh
/root/mdadm-encrypted-btrfs/partition-disks.sh
arch-chroot /mnt
/git/mdadm-encrypted-btrfs/setup.sh
exit
umount -AR /mnt
reboot
```

Use `<...>.sh |& tee <logfile>.log` to create a log file.

Set variables using vim (GRUB_RESOLUTION should be low for VMs¹)

¹ Otherwise there might be problems with the display resolution when running `post-install.sh`

## Post Installation (tty)

Log into sysuser account and run (Exit nvim with `:q`)

```
~/post-install.sh
reboot
```

## Post Installation (DE)

### Do for every user account

* Set `chrome://flags/#extension-mime-request-handling` in `ungoogled-chromium` to `Always prompt for install`
* Change Wallpaper

**Only if you have an NVIDIA GPU**

```
~/nvidia-install.sh
```

## Information

This script will only work on a system with exactly 2 disks attached. The disks have to be exactly the same size!

All data on both disks will be wiped!
