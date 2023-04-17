# arch-install

Arch Linux Installation using mdadm RAID1, LUKS encryption and btrfs.

Meant for servers that are mainly hosting docker.

## Info

:information_source: | Expect errors to occur during the installation. They only matter if any of the scripts don't finish successfully.

:information_source: | This script will only work on a system with exactly 2 disks of the same size attached!

:exclamation: | Follow [these instructions](https://github.com/leomeinel/arch-install/blob/server/virt-manager.md) for virt-manager.

:warning: | All data on both disks will be wiped!

## Pre-installation

:information_source: | Follow the `Pre-installation` section of this [guide](https://wiki.archlinux.org/title/Installation_guide#Pre-installation) until (including) the `Connect to the internet` section.

## Installation

```sh
pacman -Sy git
git clone -b server https://github.com/leomeinel/arch-install.git
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

### _Low GRUBRESOLUTION for VM_

:bulb: | _For a VM set a low GRUBRESOLUTION._

:bulb: | _Expect inconveniences otherwise._

:bulb: | _"1280x720" should be reasonable._

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
