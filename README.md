# arch-install

My personal Arch Linux install script using LVM and btrfs.

RAID can also be used.

Meant for cloud servers that are mainly hosting docker.

## Info

:information_source: | Expect errors to occur during the installation. They only matter if any of the scripts don't finish successfully.

:information_source: | I recommend disks with at least 32GB (change $DISK_ALLOCATION in install.conf otherwise).

:warning: | All data on selected disks will be wiped!

## Pre-installation

:information_source: | Follow the `Pre-installation` section of this [guide](https://wiki.archlinux.org/title/Installation_guide#Pre-installation) until (including) the `Connect to the internet` section.

## Installation

```sh
pacman -Sy
pacman -S git
git clone -b cloud https://github.com/leomeinel/arch-install.git
chmod +x /root/arch-install/prepare.sh
/root/arch-install/prepare.sh
arch-chroot /mnt
/git/arch-install/setup.sh
exit
umount -AR /mnt
reboot
```

:information_source: | Use `<...>.sh |& tee <logfile>.log` to create a log file.

:information_source: | Configure installation using `vim /root/arch-install/install.conf`.

## Post-installation (tty)

:information_source: | Log into $SYSUSER account and run:

```sh
~/post.sh
reboot
```
