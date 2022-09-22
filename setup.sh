#!/bin/bash
###
# File: setup.sh
# Author: Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2022 Leopold Meinel & contributors
# SPDX ID: GPL-3.0-or-later
# URL: https://www.gnu.org/licenses/gpl-3.0-standalone.html
# -----
###

KEYMAP="de-latin1"
HOSTNAME="stellaris-15"
SYSUSER="systux"
VIRTUSER="virt"
HOMEUSER="leo"
GUESTUSER="guest"
TIMEZONE="Europe/Amsterdam"
DOMAIN="meinel.dev"
MIRRORCOUNTRIES="NL,DE,DK,FR"
GRUBRESOLUTION="2560x1440"

# Fail on error
set -eu

# Add groups and users
sed -i 's/^SHELL=.*/SHELL=\/bin\/bash/' /etc/default/useradd
groupadd -r usbguard
groupadd -r libvirt
groupadd -r sudo
useradd -ms /bin/bash -G sudo,usbguard,wheel "$SYSUSER"
useradd -ms /bin/bash -G libvirt "$VIRTUSER"
useradd -ms /bin/bash "$HOMEUSER"
useradd -ms /bin/bash "$GUESTUSER"
echo "Enter password for root"
passwd root
echo "Enter password for $SYSUSER"
passwd "$SYSUSER"
echo "Enter password for $VIRTUSER"
passwd "$VIRTUSER"
echo "Enter password for $HOMEUSER"
passwd "$HOMEUSER"
echo "Enter password for $GUESTUSER"
passwd "$GUESTUSER"

# Configure /etc/pacman.conf and /etc/xdg/reflector/reflector.conf
{
    echo "--save /etc/pacman.d/mirrorlist"
    echo "--country $MIRRORCOUNTRIES"
    echo "--protocol https"
    echo "--latest 20"
    echo "--sort rate"
} >/etc/xdg/reflector/reflector.conf
chmod -R 755 /etc/xdg
chmod 644 /etc/xdg/reflector/reflector.conf
sed -i 's/^#Color/Color/;s/^#ParallelDownloads =.*/ParallelDownloads = 10/;s/^#CacheDir/CacheDir/' /etc/pacman.conf
pacman-key --init

# Update mirrors
reflector --save /etc/pacman.d/mirrorlist --country $MIRRORCOUNTRIES --protocol https --latest 20 --sort rate

# Install packages
pacman -Syu --noprogressbar --noconfirm --needed - </git/mdadm-encrypted-btrfs/packages_setup.txt

# Move /git/mdadm-encrypted-btrfs/etc/* to /etc
mv /git/mdadm-encrypted-btrfs/etc/* /etc
## opendoas
chown -c root:root /etc/doas.conf
chmod -c 0400 /etc/doas.conf
## Configure random MAC address for WiFi
chmod 644 /etc/NetworkManager/conf.d/wifi_rand_mac.conf
## Configure pacman hooks in /etc/pacman.d/hooks
### If on nvidia add hooks
pacman -Qq "nvidia" &&
    {
        {
            echo '[Trigger]'
            echo 'Operation=Install'
            echo 'Operation=Upgrade'
            echo 'Operation=Remove'
            echo 'Type=Package'
            echo 'Target=linux'
            echo 'Target=linux-lts'
            echo 'Target=nvidia'
            echo 'Target=nvidia-lts'
            echo ''
            echo '[Action]'
            echo 'Description=Updating NVIDIA mkinitcpio...'
            echo 'Depends=mkinitcpio'
            echo 'When=PostTransaction'
            echo 'NeedsTargets'
            echo "Exec=/bin/sh -c '/etc/pacman.d/hooks/scripts/custom-nvidia-gen-mkinitcpio.sh'"
        } >/etc/pacman.d/hooks/custom-nvidia-gen-mkinitcpio.hook
        {
            echo '#!/bin/sh'
            echo ''
            echo 'while read -r target'
            echo 'do'
            echo '    case $target in'
            echo '        linux) exit 0'
            echo '    esac'
            echo 'done'
            echo '/usr/bin/mkinitcpio -P'
        } >/etc/pacman.d/hooks/scripts/custom-nvidia-gen-mkinitcpio.sh
    }
chmod -R 755 /etc/pacman.d/hooks
chmod 644 /etc/pacman.d/hooks/*.hook
chmod 744 /etc/pacman.d/hooks/scripts/*.sh
## Configure /etc/sddm.conf.d/kde_settings.conf
chmod -R 755 /etc/sddm.conf.d
chmod 644 /etc/sddm.conf.d/kde_settings.conf
## Configure /etc/systemd/zram-generator.conf
chmod 644 /etc/systemd/zram-generator.conf

# Configure $SYSUSER
## sudo
## FIXME: Sudo is mainly used for:
## - /usr/bin/mkarchroot
## - SETENV: /usr/bin/makechrootpkg
## - /usr/bin/arch-nspawn
## It shouldn't be enabled for ALL.
## However those scripts use different scripts/commands so it is very hard to tell which should actually be allowed.
## FUTURE GOAL: REPLACE sudo WITH doas
echo "%sudo ALL=(ALL:ALL) NOPASSWD:ALL" >/etc/sudoers.d/sudo

## Set up post-install.sh
chmod +x /git/mdadm-encrypted-btrfs/sysuser-setup.sh
su -c '/git/mdadm-encrypted-btrfs/sysuser-setup.sh '"$SYSUSER $VIRTUSER $HOMEUSER $GUESTUSER"'' "$SYSUSER"
echo "%sudo ALL=(ALL:ALL) ALL" >/etc/sudoers.d/sudo

# Configure /etc/crypttab
MD0UUID="$(blkid -s UUID -o value /dev/md/md0)"
MD1UUID="$(blkid -s UUID -o value /dev/md/md1)"
{
    echo "md0_crypt UUID=$MD0UUID /etc/luks/keys/md0_crypt.key luks,key-slot=1"
    echo "md1_crypt UUID=$MD1UUID none luks,key-slot=0"
} >/etc/crypttab

# Set default java
archlinux-java set java-17-openjdk

# Add wallpapers to /usr/share/wallpapers/Custom/content
mkdir -p /usr/share/wallpapers/Custom/content
git clone https://github.com/LeoMeinel/wallpapers.git /git/wallpapers
mv /git/wallpapers/*.jpg /git/wallpapers/*.png /usr/share/wallpapers/Custom/content/
chmod -R 755 /usr/share/wallpapers/Custom
chmod 644 /usr/share/wallpapers/Custom/content/*

# Add screenshot folder to /usr/share/screenshots/
mkdir /usr/share/screenshots
chmod -R 777 /usr/share/screenshots

# Add gruvbox.yml to /usr/share/gruvbox/gruvbox.yml
mv /git/mdadm-encrypted-btrfs/usr/share/gruvbox /usr/share/
chmod -R 755 /usr/share/gruvbox
chmod 644 /usr/share/gruvbox/gruvbox.yml

# Configure /usr/share/snapper/config-templates/default and add snapper configs
umount /.snapshots
rm -rf /.snapshots
sed -i 's/^ALLOW_GROUPS=.*/ALLOW_GROUPS="sudo"/;s/^SPACE_LIMIT=.*/SPACE_LIMIT="0.1"/;s/^NUMBER_LIMIT=.*/NUMBER_LIMIT="5"/;s/^NUMBER_LIMIT_IMPORTANT=.*/NUMBER_LIMIT_IMPORTANT="5"/;s/^TIMELINE_CREATE=.*/TIMELINE_CREATE="yes"/;s/^TIMELINE_CLEANUP=.*/TIMELINE_CLEANUP="yes"/;s/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="0"/;s/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY="2"/;s/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY="0"/;s/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY="0"/' /usr/share/snapper/config-templates/default
snapper --no-dbus -c root create-config /
snapper --no-dbus -c var_games create-config /var/games
snapper --no-dbus -c var_lib_libvirt create-config /var/lib/libvirt
snapper --no-dbus -c var_lib_mysql create-config /var/lib/mysql
snapper --no-dbus -c var_lib_xdg-ninja create-config /var/lib/xdg-ninja
snapper --no-dbus -c var_log create-config /var/log
snapper --no-dbus -c home create-config /home
btrfs subvolume delete /.snapshots
mkdir /.snapshots
mount -a
chmod 750 /.snapshots
chmod a+rx /.snapshots
chown :sudo /.snapshots
chmod 750 /var/games/.snapshots
chmod a+rx /var/games/.snapshots
chown :sudo /var/games/.snapshots
chmod 750 /var/lib/libvirt/.snapshots
chmod a+rx /var/lib/libvirt/.snapshots
chown :sudo /var/lib/libvirt/.snapshots
chmod 750 /var/lib/mysql/.snapshots
chmod a+rx /var/lib/mysql/.snapshots
chown :sudo /var/lib/mysql/.snapshots
chmod 750 /var/lib/xdg-ninja/.snapshots
chmod a+rx /var/lib/xdg-ninja/.snapshots
chown :sudo /var/lib/xdg-ninja/.snapshots
chmod 750 /var/log/.snapshots
chmod a+rx /var/log/.snapshots
chown :sudo /var/log/.snapshots
chmod 750 /home/.snapshots
chmod a+rx /home/.snapshots
chown :sudo /home/.snapshots

# Configure /etc/fwupd/uefi_capsule.conf
sed -i 's/^#OverrideESPMountPoint=.*/OverrideESPMountPoint=\/efi/' /etc/fwupd/uefi_capsule.conf

# Configure /etc/cryptboot.conf
git clone https://github.com/LeoMeinel/cryptboot.git /git/cryptboot
mv /git/cryptboot/cryptboot.conf /etc/
chmod 644 /etc/cryptboot.conf

# Configure /etc/ssh/sshd_config
{
    echo ""
    echo "# Override"
    echo "PasswordAuthentication no"
    echo "AuthenticationMethods publickey"
    echo "PermitRootLogin no"
} >>/etc/ssh/sshd_config

# Configure symlinks
mv /git/cryptboot/grub-install /usr/local/bin/
mv /git/cryptboot/cryptboot /usr/bin/
mv /git/cryptboot/cryptboot-efikeys /usr/bin/
mv /git/mdadm-encrypted-btrfs/usr/bin/ex /usr/bin/
mv /git/mdadm-encrypted-btrfs/usr/bin/view /usr/bin/
mv /git/mdadm-encrypted-btrfs/usr/bin/vimdiff /usr/bin/
ln -s "$(which nvim)" /usr/bin/edit
ln -s "$(which nvim)" /usr/bin/vedit
ln -s "$(which nvim)" /usr/bin/vi
ln -s "$(which nvim)" /usr/bin/vim
chmod 755 /usr/bin/cryptboot
chmod 755 /usr/bin/cryptboot-efikeys
chmod 755 /usr/local/bin/grub-install
chmod 755 /usr/bin/ex
chmod 755 /usr/bin/view
chmod 755 /usr/bin/vimdiff
chmod 755 /usr/bin/edit
chmod 755 /usr/bin/vedit
chmod 755 /usr/bin/vi
chmod 755 /usr/bin/vim

# Configure /etc/localtime, /etc/locale.conf, /etc/vconsole.conf, /etc/hostname and /etc/hosts
ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
hwclock --systohc
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/;s/^#de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/;s/^#fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/;s/^#nl_NL.UTF-8 UTF-8/nl_NL.UTF-8 UTF-8/' /etc/locale.gen
echo "LANG=en_US.UTF-8" >/etc/locale.conf
locale-gen
echo "KEYMAP=$KEYMAP" >/etc/vconsole.conf
echo "$HOSTNAME" >/etc/hostname
{
    echo "127.0.0.1  localhost"
    echo "127.0.1.1  $HOSTNAME.$DOMAIN	$HOSTNAME"
    echo "::1  ip6-localhost ip6-loopback"
    echo "ff02::1  ip6-allnodes"
    echo "ff02::2  ip6-allrouters"
} >/etc/hosts

# Configure /etc/xdg/user-dirs.defaults
sed -i 's/^TEMPLATES=.*/TEMPLATES=Documents\/Templates/;s/^PUBLICSHARE=.*/PUBLICSHARE=Documents\/Public/;s/^DESKTOP=.*/DESKTOP=Documents\/Desktop/;s/^MUSIC=.*/MUSIC=Documents\/Music/;s/^PICTURES=.*/PICTURES=Documents\/Pictures/;s/^VIDEOS=.*/VIDEOS=Documents\/Videos/' /etc/xdg/user-dirs.defaults

# Configure /etc/mdadm.conf
mdadm --detail --scan >>/etc/mdadm.conf

# Configure /etc/usbguard/usbguard-daemon.conf and /etc/usbguard/rules.conf
usbguard generate-policy >/etc/usbguard/rules.conf
usbguard add-user -g usbguard --devices=modify,list,listen --policy=list --exceptions=listen

# Configure /etc/pam.d/system-login, /etc/security/faillock.conf, /etc/pam.d/su and /etc/pam.d/su-l
echo "auth optional pam_faildelay.so delay=8000000" >>/etc/pam.d/system-login
sed -i 's/^#.*dir.*=.*/dir = \/var\/lib\/faillock/' /etc/security/faillock.conf
echo "auth required pam_wheel.so use_uid" >>/etc/pam.d/su
echo "auth required pam_wheel.so use_uid" >>/etc/pam.d/su-l

# Enable systemd services
pacman -Qq "acpi" &&
    systemctl enable acpid
pacman -Qq "apparmor" &&
    {
        systemctl enable apparmor.service
        systemctl enable auditd.service
    }
pacman -Qq "avahi" &&
    systemctl enable avahi-daemon
pacman -Qq "bluez" &&
    systemctl enable bluetooth
pacman -Qq "cups" &&
    systemctl enable cups.service
pacman -Qq "util-linux" &&
    systemctl enable fstrim.timer
pacman -Qq "libvirt" &&
    systemctl enable libvirtd
pacman -Qq "networkmanager" &&
    systemctl enable NetworkManager
pacman -Qq "power-profiles-daemon" &&
    systemctl enable power-profiles-daemon
pacman -Qq "reflector" &&
    {
        systemctl enable reflector
        systemctl enable reflector.timer
    }
pacman -Qq "usbguard" &&
    systemctl enable usbguard.service

# Configure mDNS for Avahi
## Configure mDNS in /etc/systemd/resolved.conf
sed -i 's/^#MulticastDNS=.*/MulticastDNS=no/' /etc/systemd/resolved.conf
## Configure mDNS in /etc/nsswitch.conf
sed -i 's/^hosts: mymachines/hosts: mymachines mdns_minimal [NOTFOUND=return]/' /etc/nsswitch.conf

# Add key for /dev/mapper/md0_crypt
mkdir -p /etc/luks/keys
dd bs=1024 count=4 if=/dev/urandom of=/etc/luks/keys/md0_crypt.key iflag=fullblock
chmod 000 /etc/luks/keys/md0_crypt.key
echo "Enter passphrase for /dev/md/md0"
cryptsetup -v luksAddKey /dev/disk/by-uuid/"$MD0UUID" /etc/luks/keys/md0_crypt.key

# Configure /etc/mkinitcpio.conf
sed -i 's/^FILES=.*/FILES=(\/etc\/luks\/keys\/md0_crypt.key)/;s/^MODULES=.*/MODULES=(btrfs)/;s/^HOOKS=.*/HOOKS=(base udev autodetect keyboard keymap consolefont modconf block mdadm_udev encrypt filesystems fsck)/' /etc/mkinitcpio.conf

## If on nvidia add nvidia nvidia_modeset nvidia_uvm nvidia_drm
pacman -Qq "nvidia" &&
    sed -i '/^MODULES=.*/s/)$/ nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
mkinitcpio -P
chmod 600 /boot/initramfs-linux*

# Configure /etc/default/grub
sed -i "s/^#GRUB_ENABLE_CRYPTODISK=.*/GRUB_ENABLE_CRYPTODISK=y/;s/^#GRUB_TERMINAL_OUTPUT=.*/GRUB_TERMINAL_OUTPUT=\"gfxterm\"/;s/^GRUB_GFXPAYLOAD_LINUX=.*/GRUB_GFXPAYLOAD_LINUX=keep/;s/^GRUB_GFXMODE=.*/GRUB_GFXMODE=""$GRUBRESOLUTION""x32,auto/;s/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"quiet loglevel=3 audit=1 lsm=landlock,lockdown,yama,integrity,apparmor,bpf module.sig_enforce=1 lockdown=integrity iommu=pt zswap.enabled=0 cryptdevice=UUID=$MD0UUID:md0_crypt cryptkey=rootfs:\/etc\/luks\/keys\/md0_crypt.key cryptdevice=UUID=$MD1UUID:md1_crypt root=\/dev\/mapper\/md1_crypt\"/;s/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX=\"quiet loglevel=3 audit=1 lsm=landlock,lockdown,yama,integrity,apparmor,bpf module.sig_enforce=1 lockdown=integrity iommu=pt zswap.enabled=0 cryptdevice=UUID=$MD0UUID:md0_crypt cryptkey=rootfs:\/etc\/luks\/keys\/md0_crypt.key cryptdevice=UUID=$MD1UUID:md1_crypt root=\/dev\/mapper\/md1_crypt\"/;s/^#GRUB_DISABLE_SUBMENU=.*/GRUB_DISABLE_SUBMENU=y/;s/^GRUB_DEFAULT=.*/GRUB_DEFAULT=0/;s/^#GRUB_SAVEDEFAULT=.*/GRUB_SAVEDEFAULT=false/" /etc/default/grub

## If on nvidia add nvidia_drm.modeset=1 and set linux as default kernel
pacman -Qq "nvidia" &&
    sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=.*/s/"$/ nvidia_drm.modeset=1"/;/^GRUB_CMDLINE_LINUX=.*/s/"$/ nvidia_drm.modeset=1"/;s/^GRUB_DEFAULT=.*/GRUB_DEFAULT=2/' /etc/default/grub
pacman -Qq "intel-ucode" &&
    sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=.*/s/"$/ intel_iommu=on"/;/^GRUB_CMDLINE_LINUX=.*/s/"$/ intel_iommu=on"/' /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# FIXME: Enable some systemd services later because of grub-install ERROR:
# Detecting snapshots ...
# mount: /tmp/grub-btrfs.<...>: special device /dev/disk/by-uuid/<UUID of /dev/mapper/md1_crypt> does not exist.
pacman -Qq "snapper" &&
    {
        systemctl enable snapper-cleanup.timer
        systemctl enable snapper-timeline.timer
    }

# Run snapshot cleanup every hour
sed -i 's/^OnUnitActiveSec=.*/OnUnitActiveSec=1h/' /usr/lib/systemd/system/snapper-cleanup.timer

# Remove repo
rm -rf /git
