# arch-install

My personal Arch Linux install script using LUKS2 encryption, LVM and btrfs. With optional RAID1.

Meant for general purpose systems with a GUI.

## Mixed license

This repository is not entirely licensed as MIT.

- [This](https://github.com/leomeinel/arch-install/blob/main/etc/audit/rules.d/50-arch-install.rules) file is taken from [this](https://gitlab.com/ndaal_open_source/ndaal_public_auditd/-/blob/main/dataset/audit_best_practices.rules) repository and is licensed under [Apache-2.0](https://gitlab.com/ndaal_open_source/ndaal_public_auditd/-/blob/6b4ae2d011286eaae92d32efa9361bbf1fa61bb4/LICENSE).

## Info

:warning: | All data on selected disks will be wiped!

:information_source: | Expect errors or warnings to occur during the installation. They only matter if any of the scripts don't finish successfully.

:information_source: | I recommend disks with at least 512GiB. change `DISK_ALLOCATION` in `install.conf` otherwise.

:information_source: | I recommend at least 16GiB of RAM. By specifying `TMPDIR` manually before running `post.sh` to force nix to not use the tmpfs, you might be able to circumvent this. Also see these issues: [(1)](https://github.com/NixOS/nixpkgs/issues/54707) and [(2)](https://github.com/NixOS/nix/issues/2098).

:exclamation: | Follow [these instructions](https://github.com/leomeinel/arch-install/blob/main/virt-manager-install.md) for installing to virt-manager.

:exclamation: | Follow [these instructions](https://github.com/leomeinel/arch-install/blob/main/ssh-install.md) for installing via ssh.

## Pre-installation

Follow the `Pre-installation` section of [this guide](https://wiki.archlinux.org/title/Installation_guide#Pre-installation) until (including) the `Connect to the internet` section.

## Installation

:information_source: | `|& tee [file]` will create a log file automatically. I would not recommend using it in a tty because it affects readability. Just skip any part after the `[...].sh`.

```sh
pacman -Sy git
# Instead of main, you can also use a tag
git clone -b 4.2.0 https://github.com/leomeinel/arch-install.git
chmod +x /root/arch-install/prepare.sh
# Modify install.conf before executing prepare.sh
vim /root/arch-install/install.conf
/root/arch-install/prepare.sh |& tee ./prepare.sh.log && mv ./prepare.sh.log /mnt
arch-chroot /mnt
/git/arch-install/setup.sh |& tee ./setup.sh.log
exit
umount -AR /mnt
reboot
```

## Post-installation

:information_source: | If installing to virt-manager skip ¹.

¹Enable `Secure Boot` [`Setup Mode`](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot#Putting_firmware_in_"Setup_Mode") in [`UEFI Firmware Settings`](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot#Before_booting_the_OS).

¹Set your UEFI password(s) and reboot.

Log into SYSUSER account and run:

```sh
~/post.sh |& tee ./post.sh.log
doas reboot
```

¹Enable `Secure Boot` in [`UEFI Firmware Settings`](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot#Before_booting_the_OS).
