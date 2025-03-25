# arch-install

My personal Arch Linux install script using LUKS2 encryption, LVM and btrfs.

RAID can also be used.

Meant for general purpose systems with a GUI.

## Info

:information_source: | Expect errors or warnings to occur during the installation. They only matter if any of the scripts don't finish successfully.

:information_source: | I recommend disks with at least 512GiB (change DISK_ALLOCATION in install.conf otherwise).

:warning: | All data on selected disks will be wiped!

:exclamation: | Follow [these instructions](https://github.com/leomeinel/arch-install/blob/main/virt-manager-install.md) for virt-manager.

## Pre-installation

:information_source: | Follow the `Pre-installation` section of [this guide](https://wiki.archlinux.org/title/Installation_guide#Pre-installation) until (including) the `Connect to the internet` section.

:information_source: | To install via ssh follow [this guide](https://wiki.archlinux.org/title/Install_Arch_Linux_via_SSH). See [these instructions](https://github.com/leomeinel/arch-install/blob/main/ssh-install.md) for more details, especially if you want to use ssh for `Post-installation`.

## Installation

```sh
pacman -Sy
pacman -S git
# Instead of main, you can also use a tag
git clone -b main https://github.com/leomeinel/arch-install.git
chmod +x /root/arch-install/prepare.sh
# Modify install.conf before executing prepare.sh
/root/arch-install/prepare.sh
arch-chroot /mnt
/git/arch-install/setup.sh
# If you want to use ssh for running post.sh add your public key to SYSUSER account here
exit
umount -AR /mnt
reboot
```

:information_source: | Use `<...>.sh |& tee <logfile>.log` to create a log file.

:information_source: | Configure installation using `vim /root/arch-install/install.conf`.

## Post-installation

:warning: | If using virt-manager skip ¹.

:information_source: | ¹Enable `Secure Boot` [`Setup Mode`](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot#Putting_firmware_in_"Setup_Mode") in [`UEFI Firmware Settings`](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot#Before_booting_the_OS).

:information_source: | ¹Set your UEFI password(s) and reboot.

:information_source: | Log into SYSUSER account and run:

```sh
~/post.sh
doas reboot
```

:information_source: | ¹Enable `Secure Boot` in [`UEFI Firmware Settings`](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot#Before_booting_the_OS).
