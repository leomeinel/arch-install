# arch-install

My personal Arch Linux install script using LUKS2 encryption, LVM and btrfs. With optional RAID1.

Meant for general purpose systems with a GUI.

## Info

:warning: | All data on selected disks will be wiped!

:information_source: | Expect errors or warnings to occur during the installation. They only matter if any of the scripts don't finish successfully.

:information_source: | I recommend disks with at least 512GiB (change `DISK_ALLOCATION` in `install.conf` otherwise).

:information_source: | I recommend at least 16GiB of RAM. By specifying `TMPDIR` manually before running `post.sh` to force nix to not use the tmpfs, you might be able to circumvent this. Also see [this](https://github.com/NixOS/nixpkgs/issues/54707) and [this](https://github.com/NixOS/nix/issues/2098). I haven't tried this myself.

:exclamation: | Follow [these instructions](https://github.com/leomeinel/arch-install/blob/main/virt-manager-install.md) for installing to virt-manager.

:exclamation: | See [these instructions](https://github.com/leomeinel/arch-install/blob/main/ssh-install.md) for installing via ssh.

## Pre-installation

:information_source: | Follow the `Pre-installation` section of [this guide](https://wiki.archlinux.org/title/Installation_guide#Pre-installation) until (including) the `Connect to the internet` section.

## Installation

:information_source: | `<...>.sh |& tee <logfile>.log` will create a log file automatically.

```sh
pacman -Sy git
# Instead of main, you can also use a tag
git clone -b main https://github.com/leomeinel/arch-install.git
chmod +x /root/arch-install/prepare.sh
# Modify install.conf before executing prepare.sh
vim /root/arch-install/install.conf
/root/arch-install/prepare.sh |& tee "$(basename "${0}").log" && mv prepare.sh.log /mnt
arch-chroot /mnt
/git/arch-install/setup.sh |& tee "$(basename "${0}").log"
exit
umount -AR /mnt
reboot
```

## Post-installation

:warning: | If installing to virt-manager skip ¹.

:information_source: | ¹Enable `Secure Boot` [`Setup Mode`](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot#Putting_firmware_in_"Setup_Mode") in [`UEFI Firmware Settings`](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot#Before_booting_the_OS).

:information_source: | ¹Set your UEFI password(s) and reboot.

:information_source: | Log into SYSUSER account and run:

```sh
~/post.sh |& tee "$(basename "${0}").log"
doas reboot
```

:information_source: | ¹Enable `Secure Boot` in [`UEFI Firmware Settings`](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot#Before_booting_the_OS).
