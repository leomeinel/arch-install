# arch-install

Arch Linux Installation using mdadm RAID1, LUKS encryption and btrfs.

Meant for general purpose systems.

## Info

:information_source: | Expect errors to occur during the installation. They only matter if any of the scripts don't finish successfully.

:information_source: | This script will only work on a system with exactly 2 disks of the same size attached!

:information_source: | I recommend disks with at least 512GB (change allocation in prepare.sh otherwise).

:warning: | All data on both disks will be wiped!

:exclamation: | Follow [these instructions](https://github.com/leomeinel/arch-install/blob/main/virt-manager.md) for virt-manager.

## Pre-installation

:information_source: | Follow the `Pre-installation` section of this [guide](https://wiki.archlinux.org/title/Installation_guide#Pre-installation) until (including) the `Connect to the internet` section.

## Installation

```sh
pacman -Sy git
git clone https://github.com/leomeinel/arch-install.git
chmod +x /root/arch-install/prepare.sh
/root/arch-install/prepare.sh
arch-chroot /mnt
/git/arch-install/setup.sh
exit
umount -AR /mnt
reboot
```

:information_source: | Use `<...>.sh |& tee <logfile>.log` to create a log file.

:information_source: | Set variables for `prepare.sh` using `vim /root/arch-install/prepare.sh`.

:information_source: | Set variables after `prepare.sh` using `nvim /git/arch-install/setup.sh` and `nvim ~/post.sh`.

## Post-installation (tty)

:warning: | If using virt-manager skip ¹.

:information_source: | ¹Enable `Secure Boot` [`Setup Mode`](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot#Putting_firmware_in_"Setup_Mode") in [`UEFI Firmware Settings`](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot#Before_booting_the_OS).

:information_source: | ¹Set your UEFI password(s) and reboot.

:information_source: | Log into $SYSUSER account and run:

```sh
~/post.sh
reboot
```

:information_source: | ¹Enable `Secure Boot` in [`UEFI Firmware Settings`](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot#Before_booting_the_OS).
