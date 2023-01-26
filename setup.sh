#!/bin/bash
###
# File: setup.sh
# Author: Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2023 Leopold Meinel & contributors
# SPDX ID: GPL-3.0-or-later
# URL: https://www.gnu.org/licenses/gpl-3.0-standalone.html
# -----
###

KEYMAP="de-latin1"
MIRRORCOUNTRIES="NL,DE,DK,FR"
TIMEZONE="Europe/Amsterdam"
GRUBRESOLUTION="2560x1440"
# https://www.rfc-editor.org/rfc/rfc1178.html
## Network devices: elements
## Servers: colors
## Clients: flowers
HOSTNAME="cyan"
# https://www.rfc-editor.org/rfc/rfc8375.html
DOMAIN="home.arpa"
SYSUSER="sysdock"
DOCKUSER="dock"
HOMEUSER="leo"

# Fail on error
set -eu

# Define functions
sed_exit() {
    echo "ERROR: 'sed' didn't replace, report this @"
    echo "       https://github.com/LeoMeinel/arch-install/issues"
    exit 1
}

# Add groups & users
## START sed
FILE=/etc/default/useradd
STRING="^SHELL=.*"
grep -q "$STRING" "$FILE" &&
    sed -i "s/$STRING/SHELL=\/bin\/bash/" "$FILE" || sed_exit
## END sed
groupadd -r audit
groupadd -r usbguard
useradd -ms /bin/bash -G adm,audit,log,rfkill,sys,systemd-journal,usbguard,wheel "$SYSUSER"
useradd -ms /bin/bash -G docker "$DOCKUSER"
useradd -ms /bin/bash "$HOMEUSER"
echo "Enter password for root"
passwd root
echo "Enter password for $SYSUSER"
passwd "$SYSUSER"
echo "Enter password for $DOCKUSER"
passwd "$DOCKUSER"
echo "Enter password for $HOMEUSER"
passwd "$HOMEUSER"

# Setup /etc
rsync -rq /git/arch-install/etc/ /etc
## Configure locale in /etc/locale.gen & /etc/locale.conf
### START sed
FILE=/etc/locale.gen
STRING="^#de_DE.UTF-8 UTF-8"
grep -q "$STRING" "$FILE" &&
    sed -i "s/$STRING/de_DE.UTF-8 UTF-8/" "$FILE" || sed_exit
STRING="^#en_US.UTF-8 UTF-8"
grep -q "$STRING" "$FILE" &&
    sed -i "s/$STRING/en_US.UTF-8 UTF-8/" "$FILE" || sed_exit
STRING="^#en_DK.UTF-8 UTF-8"
grep -q "$STRING" "$FILE" &&
    sed -i "s/$STRING/en_DK.UTF-8 UTF-8/" "$FILE" || sed_exit
STRING="^#fr_FR.UTF-8 UTF-8"
grep -q "$STRING" "$FILE" &&
    sed -i "s/$STRING/fr_FR.UTF-8 UTF-8/" "$FILE" || sed_exit
STRING="^#nl_NL.UTF-8 UTF-8"
grep -q "$STRING" "$FILE" &&
    sed -i "s/$STRING/nl_NL.UTF-8 UTF-8/" "$FILE" || sed_exit
### END sed
chmod 644 /etc/locale.conf
locale-gen
## Configure /etc/doas.conf
chown -c root:root /etc/doas.conf
chmod -c 0400 /etc/doas.conf
## Configure pacman hooks in /etc/pacman.d/hooks
{
    echo '#!/bin/sh'
    echo ''
    echo '/usr/bin/firecfg >/dev/null 2>&1'
    echo "/usr/bin/su -c '/usr/bin/rm -rf ~/.local/share/applications/*' $SYSUSER"
    echo "/usr/bin/su -c '/usr/bin/rm -rf ~/.local/share/applications/*' $DOCKUSER"
    echo "/usr/bin/su -c '/usr/bin/rm -rf ~/.local/share/applications/*' $HOMEUSER"
    echo ''
} >/etc/pacman.d/hooks/scripts/70-firejail.sh
chmod 755 /etc/pacman.d/hooks
chmod 755 /etc/pacman.d/hooks/scripts
chmod 644 /etc/pacman.d/hooks/*.hook
chmod 744 /etc/pacman.d/hooks/scripts/*.sh
## Configure /etc/systemd/zram-generator.conf
chmod 644 /etc/systemd/zram-generator.conf
## Configure /etc/sysctl.d
chmod 755 /etc/sysctl.d
chmod 644 /etc/sysctl.d/*
## Configure /etc/systemd/system/snapper-cleanup.timer.d/override.conf
chmod 644 /etc/systemd/system/snapper-cleanup.timer.d/override.conf
## Configure /etc/systemd/system/systemd-networkd-wait-online.service.d/override.conf
chmod 644 /etc/systemd/system/systemd-networkd-wait-online.service.d/override.conf
## Configure /etc/systemd/network/10-en.network
chmod 644 /etc/systemd/network/10-en.network
## Configure /etc/pacman.conf , /etc/makepkg.conf & /etc/xdg/reflector/reflector.conf
{
    echo "--save /etc/pacman.d/mirrorlist"
    echo "--country $MIRRORCOUNTRIES"
    echo "--protocol https"
    echo "--latest 20"
    echo "--sort rate"
} >/etc/xdg/reflector/reflector.conf
chmod 644 /etc/xdg/reflector/reflector.conf
### START sed
FILE=/etc/makepkg.conf
STRING="^#PACMAN_AUTH=.*"
grep -q "$STRING" "$FILE" &&
    sed -i "s/$STRING/PACMAN_AUTH=(doas)/" "$FILE" || sed_exit
###
FILE=/etc/pacman.conf
STRING="^#Color"
grep -q "$STRING" "$FILE" &&
    sed -i "s/$STRING/Color/" "$FILE" || sed_exit
STRING="^#ParallelDownloads =.*"
grep -q "$STRING" "$FILE" &&
    sed -i "s/$STRING/ParallelDownloads = 10/" "$FILE" || sed_exit
STRING="^#CacheDir"
grep -q "$STRING" "$FILE" &&
    sed -i "s/$STRING/CacheDir/" "$FILE" || sed_exit
### END sed
pacman-key --init
## Update mirrors
reflector --save /etc/pacman.d/mirrorlist --country $MIRRORCOUNTRIES --protocol https --latest 20 --sort rate

# Install packages
pacman -Syu --noprogressbar --noconfirm --needed - </git/arch-install/pkgs-setup.txt

# Configure $SYSUSER
## Run sysuser.sh
chmod +x /git/arch-install/sysuser.sh
su -c '/git/arch-install/sysuser.sh '"$SYSUSER $DOCKUSER $HOMEUSER"'' "$SYSUSER"
cp /git/arch-install/dot-files.sh /
chmod 777 /dot-files.sh

# Configure /etc
## Configure /etc/crypttab
MD0UUID="$(blkid -s UUID -o value /dev/md/md0)"
MD1UUID="$(blkid -s UUID -o value /dev/md/md1)"
{
    echo "md0_crypt UUID=$MD0UUID /etc/luks/keys/md0_crypt.key luks,key-slot=1"
    echo "md1_crypt UUID=$MD1UUID none luks,key-slot=0"
} >/etc/crypttab
## Configure /etc/localtime, /etc/vconsole.conf, /etc/hostname & /etc/hosts
ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
hwclock --systohc
echo "KEYMAP=$KEYMAP" >/etc/vconsole.conf
echo "$HOSTNAME" >/etc/hostname
{
    echo "127.0.0.1  localhost"
    echo "127.0.1.1  $HOSTNAME.$DOMAIN	$HOSTNAME"
    echo "::1  ip6-localhost ip6-loopback"
    echo "ff02::1  ip6-allnodes"
    echo "ff02::2  ip6-allrouters"
} >/etc/hosts
## Configure /etc/fwupd/uefi_capsule.conf
{
    echo ""
    echo "# Custom"
    echo "## Set /efi as mountpoint"
    echo "OverrideESPMountPoint=/efi"
} >>/etc/fwupd/uefi_capsule.conf
## Configure /etc/cryptboot.conf
git clone -b server https://github.com/LeoMeinel/cryptboot.git /git/cryptboot
cp /git/cryptboot/cryptboot.conf /etc/
chmod 644 /etc/cryptboot.conf
## Configure /etc/ssh/sshd_config
{
    echo ""
    echo "# Override"
    echo "PasswordAuthentication no"
    echo "AuthenticationMethods publickey"
    echo "PermitRootLogin no"
} >>/etc/ssh/sshd_config
## Configure /etc/mdadm.conf
mdadm --detail --scan >>/etc/mdadm.conf
## Configure /etc/usbguard/usbguard-daemon.conf & /etc/usbguard/rules.conf
usbguard generate-policy >/etc/usbguard/rules.conf
usbguard add-user -g usbguard --devices=modify,list,listen --policy=list --exceptions=listen
## Configure /etc/pam.d/system-login, /etc/security/faillock.conf, /etc/pam.d/su & /etc/pam.d/su-l
echo "auth optional pam_faildelay.so delay=8000000" >>/etc/pam.d/system-login
### START sed
FILE=/etc/security/faillock.conf
STRING="^#.*dir.*=.*"
grep -q "$STRING" "$FILE" &&
    sed -i "s|$STRING|dir = /var/lib/faillock|" "$FILE" || sed_exit
### END sed
echo "auth required pam_wheel.so use_uid" >>/etc/pam.d/su
echo "auth required pam_wheel.so use_uid" >>/etc/pam.d/su-l
## Configure /etc/audit/auditd.conf
### START sed
FILE=/etc/audit/auditd.conf
STRING="^log_group.*=.*"
grep -q "$STRING" "$FILE" &&
    sed -i "s/$STRING/log_group = audit/" "$FILE" || sed_exit
### END sed
## Configure /etc/luks/keys
mkdir -p /etc/luks/keys
dd bs=1024 count=4 if=/dev/urandom of=/etc/luks/keys/md0_crypt.key iflag=fullblock
chmod 000 /etc/luks/keys/md0_crypt.key
echo "Enter passphrase for /dev/md/md0"
cryptsetup -v luksAddKey /dev/disk/by-uuid/"$MD0UUID" /etc/luks/keys/md0_crypt.key
## Configure /etc/mkinitcpio.conf
### START sed
FILE=/etc/mkinitcpio.conf
STRING="^FILES=.*"
grep -q "$STRING" "$FILE" &&
    sed -i "s|$STRING|FILES=(/etc/luks/keys/md0_crypt.key)|" "$FILE" || sed_exit
STRING="^MODULES=.*"
grep -q "$STRING" "$FILE" &&
    sed -i "s/$STRING/MODULES=(btrfs)/" "$FILE" || sed_exit
STRING="^HOOKS=.*"
grep -q "$STRING" "$FILE" &&
    sed -i "s/$STRING/HOOKS=(base udev autodetect keyboard keymap consolefont modconf block mdadm_udev encrypt filesystems fsck)/" "$FILE" || sed_exit
### END sed
## Configure /etc/default/grub
### START sed
FILE=/etc/default/grub
STRING="^#GRUB_ENABLE_CRYPTODISK=.*"
grep -q "$STRING" "$FILE" &&
    sed -i "s/$STRING/GRUB_ENABLE_CRYPTODISK=y/" "$FILE" || sed_exit
STRING="^#GRUB_TERMINAL_OUTPUT=.*"
grep -q "$STRING" "$FILE" &&
    sed -i "s/$STRING/GRUB_TERMINAL_OUTPUT=\"gfxterm\"/" "$FILE" || sed_exit
STRING="^GRUB_GFXPAYLOAD_LINUX=.*"
grep -q "$STRING" "$FILE" &&
    sed -i "s/$STRING/GRUB_GFXPAYLOAD_LINUX=keep/" "$FILE" || sed_exit
STRING="^GRUB_GFXMODE=.*"
grep -q "$STRING" "$FILE" &&
    sed -i "s/$STRING/GRUB_GFXMODE=""$GRUBRESOLUTION""x32,auto/" "$FILE" || sed_exit
PARAMETERS="\"quiet loglevel=3 audit=1 lsm=landlock,lockdown,yama,integrity,apparmor,bpf lockdown=integrity module.sig_enforce=1 iommu=pt zswap.enabled=0 cryptdevice=UUID=$MD0UUID:md0_crypt cryptkey=rootfs:\/etc\/luks\/keys\/md0_crypt.key cryptdevice=UUID=$MD1UUID:md1_crypt root=\/dev\/mapper\/md1_crypt\""
STRING="^GRUB_CMDLINE_LINUX_DEFAULT=.*"
grep -q "$STRING" "$FILE" &&
    {
        sed -i "s/$STRING/GRUB_CMDLINE_LINUX_DEFAULT=$PARAMETERS/" "$FILE"
        #### If on intel set kernel parameter intel_iommu=on
        pacman -Qq "intel-ucode" &&
            sed -i "/$STRING/s/\"$/ intel_iommu=on\"/" "$FILE"
    } || sed_exit
STRING="^GRUB_CMDLINE_LINUX=.*"
grep -q "$STRING" "$FILE" &&
    {
        sed -i "s/$STRING/GRUB_CMDLINE_LINUX=$PARAMETERS/" "$FILE"
        pacman -Qq "intel-ucode" &&
            #### If on intel set kernel parameter intel_iommu=on
            sed -i "/$STRING/s/\"$/ intel_iommu=on\"/" "$FILE"
    } || sed_exit
STRING="^#GRUB_DISABLE_SUBMENU=.*"
grep -q "$STRING" "$FILE" &&
    sed -i "s/$STRING/GRUB_DISABLE_SUBMENU=y/" "$FILE" || sed_exit
STRING="^GRUB_DEFAULT=.*"
grep -q "$STRING" "$FILE" &&
    sed -i "s/$STRING/GRUB_DEFAULT=2/" "$FILE" || sed_exit
STRING="^#GRUB_SAVEDEFAULT=.*"
grep -q "$STRING" "$FILE" &&
    sed -i "s/$STRING/GRUB_SAVEDEFAULT=false/" "$FILE" || sed_exit
### END sed

# Setup /usr
rsync -rq /git/arch-install/usr/ /usr
cp /git/cryptboot/grub-install /usr/local/bin/
cp /git/cryptboot/cryptboot /usr/local/bin/
cp /git/cryptboot/cryptboot-efikeys /usr/local/bin/
## Configure /usr/local/bin
chmod 755 /usr/local/bin/cryptboot
chmod 755 /usr/local/bin/cryptboot-efikeys
chmod 755 /usr/local/bin/grub-install
ln -s "$(which nvim)" /usr/local/bin/edit
ln -s "$(which nvim)" /usr/local/bin/vedit
ln -s "$(which nvim)" /usr/local/bin/vi
ln -s "$(which nvim)" /usr/local/bin/vim
chmod 755 /usr/local/bin/ex
chmod 755 /usr/local/bin/view
chmod 755 /usr/local/bin/vimdiff
chmod 755 /usr/local/bin/edit
chmod 755 /usr/local/bin/vedit
chmod 755 /usr/local/bin/vi
chmod 755 /usr/local/bin/vim

# Configure /usr
## Configure /usr/share/snapper/config-templates/default & configure snapper configs
umount /.snapshots
rm -rf /.snapshots
cp /usr/share/snapper/config-templates/default /usr/share/snapper/config-templates/root
cp /usr/share/snapper/config-templates/default /usr/share/snapper/config-templates/var_lib_docker
cp /usr/share/snapper/config-templates/default /usr/share/snapper/config-templates/var_lib_libvirt
cp /usr/share/snapper/config-templates/default /usr/share/snapper/config-templates/var_lib_mysql
cp /usr/share/snapper/config-templates/default /usr/share/snapper/config-templates/var_log
cp /usr/share/snapper/config-templates/default /usr/share/snapper/config-templates/home
### START sed
STRING0="^ALLOW_GROUPS=.*"
STRING1="^SPACE_LIMIT=.*"
STRING2="^NUMBER_LIMIT=.*"
STRING3="^NUMBER_LIMIT_IMPORTANT=.*"
STRING4="^TIMELINE_CREATE=.*"
STRING5="^TIMELINE_CLEANUP=.*"
STRING6="^TIMELINE_LIMIT_HOURLY=.*"
STRING7="^TIMELINE_LIMIT_DAILY=.*"
STRING8="^TIMELINE_LIMIT_MONTHLY=.*"
STRING9="^TIMELINE_LIMIT_YEARLY=.*"
###
FILE=/usr/share/snapper/config-templates/root
grep -q "$STRING0" "$FILE" &&
    sed -i "s/$STRING0/ALLOW_GROUPS=\"wheel\"/" "$FILE" || sed_exit
grep -q "$STRING1" "$FILE" &&
    sed -i "s/$STRING1/SPACE_LIMIT=\"0.1\"/" "$FILE" || sed_exit
grep -q "$STRING2" "$FILE" &&
    sed -i "s/$STRING2/NUMBER_LIMIT=\"5\"/" "$FILE" || sed_exit
grep -q "$STRING3" "$FILE" &&
    sed -i "s/$STRING3/NUMBER_LIMIT_IMPORTANT=\"5\"/" "$FILE" || sed_exit
grep -q "$STRING4" "$FILE" &&
    sed -i "s/$STRING4/TIMELINE_CREATE=\"yes\"/" "$FILE" || sed_exit
grep -q "$STRING5" "$FILE" &&
    sed -i "s/$STRING5/TIMELINE_CLEANUP=\"yes\"/" "$FILE" || sed_exit
grep -q "$STRING6" "$FILE" &&
    sed -i "s/$STRING6/TIMELINE_LIMIT_HOURLY=\"2\"/" "$FILE" || sed_exit
grep -q "$STRING7" "$FILE" &&
    sed -i "s/$STRING7/TIMELINE_LIMIT_DAILY=\"4\"/" "$FILE" || sed_exit
grep -q "$STRING8" "$FILE" &&
    sed -i "s/$STRING8/TIMELINE_LIMIT_MONTHLY=\"0\"/" "$FILE" || sed_exit
grep -q "$STRING9" "$FILE" &&
    sed -i "s/$STRING9/TIMELINE_LIMIT_YEARLY=\"0\"/" "$FILE" || sed_exit
###
FILE="/usr/share/snapper/config-templates/var_lib_docker"
grep -q "$STRING0" "$FILE" &&
    sed -i "s/$STRING0/ALLOW_GROUPS=\"wheel\"/" "$FILE" || sed_exit
grep -q "$STRING1" "$FILE" &&
    sed -i "s/$STRING1/SPACE_LIMIT=\"0.1\"/" "$FILE" || sed_exit
grep -q "$STRING2" "$FILE" &&
    sed -i "s/$STRING2/NUMBER_LIMIT=\"5\"/" "$FILE" || sed_exit
grep -q "$STRING3" "$FILE" &&
    sed -i "s/$STRING3/NUMBER_LIMIT_IMPORTANT=\"5\"/" "$FILE" || sed_exit
grep -q "$STRING4" "$FILE" &&
    sed -i "s/$STRING4/TIMELINE_CREATE=\"yes\"/" "$FILE" || sed_exit
grep -q "$STRING5" "$FILE" &&
    sed -i "s/$STRING5/TIMELINE_CLEANUP=\"yes\"/" "$FILE" || sed_exit
grep -q "$STRING6" "$FILE" &&
    sed -i "s/$STRING6/TIMELINE_LIMIT_HOURLY=\"4\"/" "$FILE" || sed_exit
grep -q "$STRING7" "$FILE" &&
    sed -i "s/$STRING7/TIMELINE_LIMIT_DAILY=\"4\"/" "$FILE" || sed_exit
grep -q "$STRING8" "$FILE" &&
    sed -i "s/$STRING8/TIMELINE_LIMIT_MONTHLY=\"0\"/" "$FILE" || sed_exit
grep -q "$STRING9" "$FILE" &&
    sed -i "s/$STRING9/TIMELINE_LIMIT_YEARLY=\"0\"/" "$FILE" || sed_exit
###
FILE=/usr/share/snapper/config-templates/var_lib_libvirt
grep -q "$STRING0" "$FILE" &&
    sed -i "s/$STRING0/ALLOW_GROUPS=\"wheel\"/" "$FILE" || sed_exit
grep -q "$STRING1" "$FILE" &&
    sed -i "s/$STRING1/SPACE_LIMIT=\"0.1\"/" "$FILE" || sed_exit
grep -q "$STRING2" "$FILE" &&
    sed -i "s/$STRING2/NUMBER_LIMIT=\"5\"/" "$FILE" || sed_exit
grep -q "$STRING3" "$FILE" &&
    sed -i "s/$STRING3/NUMBER_LIMIT_IMPORTANT=\"5\"/" "$FILE" || sed_exit
grep -q "$STRING4" "$FILE" &&
    sed -i "s/$STRING4/TIMELINE_CREATE=\"yes\"/" "$FILE" || sed_exit
grep -q "$STRING5" "$FILE" &&
    sed -i "s/$STRING5/TIMELINE_CLEANUP=\"yes\"/" "$FILE" || sed_exit
grep -q "$STRING6" "$FILE" &&
    sed -i "s/$STRING6/TIMELINE_LIMIT_HOURLY=\"2\"/" "$FILE" || sed_exit
grep -q "$STRING7" "$FILE" &&
    sed -i "s/$STRING7/TIMELINE_LIMIT_DAILY=\"5\"/" "$FILE" || sed_exit
grep -q "$STRING8" "$FILE" &&
    sed -i "s/$STRING8/TIMELINE_LIMIT_MONTHLY=\"0\"/" "$FILE" || sed_exit
grep -q "$STRING9" "$FILE" &&
    sed -i "s/$STRING9/TIMELINE_LIMIT_YEARLY=\"0\"/" "$FILE" || sed_exit
###
FILE=/usr/share/snapper/config-templates/var_lib_mysql
grep -q "$STRING0" "$FILE" &&
    sed -i "s/$STRING0/ALLOW_GROUPS=\"wheel\"/" "$FILE" || sed_exit
grep -q "$STRING1" "$FILE" &&
    sed -i "s/$STRING1/SPACE_LIMIT=\"0.1\"/" "$FILE" || sed_exit
grep -q "$STRING2" "$FILE" &&
    sed -i "s/$STRING2/NUMBER_LIMIT=\"5\"/" "$FILE" || sed_exit
grep -q "$STRING3" "$FILE" &&
    sed -i "s/$STRING3/NUMBER_LIMIT_IMPORTANT=\"5\"/" "$FILE" || sed_exit
grep -q "$STRING4" "$FILE" &&
    sed -i "s/$STRING4/TIMELINE_CREATE=\"yes\"/" "$FILE" || sed_exit
grep -q "$STRING5" "$FILE" &&
    sed -i "s/$STRING5/TIMELINE_CLEANUP=\"yes\"/" "$FILE" || sed_exit
grep -q "$STRING6" "$FILE" &&
    sed -i "s/$STRING6/TIMELINE_LIMIT_HOURLY=\"2\"/" "$FILE" || sed_exit
grep -q "$STRING7" "$FILE" &&
    sed -i "s/$STRING7/TIMELINE_LIMIT_DAILY=\"5\"/" "$FILE" || sed_exit
grep -q "$STRING8" "$FILE" &&
    sed -i "s/$STRING8/TIMELINE_LIMIT_MONTHLY=\"0\"/" "$FILE" || sed_exit
grep -q "$STRING9" "$FILE" &&
    sed -i "s/$STRING9/TIMELINE_LIMIT_YEARLY=\"0\"/" "$FILE" || sed_exit
###
FILE=/usr/share/snapper/config-templates/var_log
grep -q "$STRING0" "$FILE" &&
    sed -i "s/$STRING0/ALLOW_GROUPS=\"wheel\"/" "$FILE" || sed_exit
grep -q "$STRING1" "$FILE" &&
    sed -i "s/$STRING1/SPACE_LIMIT=\"0.1\"/" "$FILE" || sed_exit
grep -q "$STRING2" "$FILE" &&
    sed -i "s/$STRING2/NUMBER_LIMIT=\"5\"/" "$FILE" || sed_exit
grep -q "$STRING3" "$FILE" &&
    sed -i "s/$STRING3/NUMBER_LIMIT_IMPORTANT=\"5\"/" "$FILE" || sed_exit
grep -q "$STRING4" "$FILE" &&
    sed -i "s/$STRING4/TIMELINE_CREATE=\"yes\"/" "$FILE" || sed_exit
grep -q "$STRING5" "$FILE" &&
    sed -i "s/$STRING5/TIMELINE_CLEANUP=\"yes\"/" "$FILE" || sed_exit
grep -q "$STRING6" "$FILE" &&
    sed -i "s/$STRING6/TIMELINE_LIMIT_HOURLY=\"1\"/" "$FILE" || sed_exit
grep -q "$STRING7" "$FILE" &&
    sed -i "s/$STRING7/TIMELINE_LIMIT_DAILY=\"1\"/" "$FILE" || sed_exit
grep -q "$STRING8" "$FILE" &&
    sed -i "s/$STRING8/TIMELINE_LIMIT_MONTHLY=\"0\"/" "$FILE" || sed_exit
grep -q "$STRING9" "$FILE" &&
    sed -i "s/$STRING9/TIMELINE_LIMIT_YEARLY=\"0\"/" "$FILE" || sed_exit
###
FILE=/usr/share/snapper/config-templates/home
grep -q "$STRING0" "$FILE" &&
    sed -i "s/$STRING0/ALLOW_GROUPS=\"wheel\"/" "$FILE" || sed_exit
grep -q "$STRING1" "$FILE" &&
    sed -i "s/$STRING1/SPACE_LIMIT=\"0.2\"/" "$FILE" || sed_exit
grep -q "$STRING2" "$FILE" &&
    sed -i "s/$STRING2/NUMBER_LIMIT=\"5\"/" "$FILE" || sed_exit
grep -q "$STRING3" "$FILE" &&
    sed -i "s/$STRING3/NUMBER_LIMIT_IMPORTANT=\"5\"/" "$FILE" || sed_exit
grep -q "$STRING4" "$FILE" &&
    sed -i "s/$STRING4/TIMELINE_CREATE=\"yes\"/" "$FILE" || sed_exit
grep -q "$STRING5" "$FILE" &&
    sed -i "s/$STRING5/TIMELINE_CLEANUP=\"yes\"/" "$FILE" || sed_exit
grep -q "$STRING6" "$FILE" &&
    sed -i "s/$STRING6/TIMELINE_LIMIT_HOURLY=\"2\"/" "$FILE" || sed_exit
grep -q "$STRING7" "$FILE" &&
    sed -i "s/$STRING7/TIMELINE_LIMIT_DAILY=\"5\"/" "$FILE" || sed_exit
grep -q "$STRING8" "$FILE" &&
    sed -i "s/$STRING8/TIMELINE_LIMIT_MONTHLY=\"0\"/" "$FILE" || sed_exit
grep -q "$STRING9" "$FILE" &&
    sed -i "s/$STRING9/TIMELINE_LIMIT_YEARLY=\"0\"/" "$FILE" || sed_exit
### END sed
chmod 644 /usr/share/snapper/config-templates/root
chmod 644 /usr/share/snapper/config-templates/var_lib_docker
chmod 644 /usr/share/snapper/config-templates/var_lib_libvirt
chmod 644 /usr/share/snapper/config-templates/var_lib_mysql
chmod 644 /usr/share/snapper/config-templates/var_log
chmod 644 /usr/share/snapper/config-templates/home
snapper --no-dbus -c root create-config -t root /
snapper --no-dbus -c var_lib_docker create-config -t var_lib_docker /var/lib/docker
snapper --no-dbus -c var_lib_libvirt create-config -t var_lib_libvirt /var/lib/libvirt
snapper --no-dbus -c var_lib_mysql create-config -t var_lib_mysql /var/lib/mysql
snapper --no-dbus -c var_log create-config -t var_log /var/log
snapper --no-dbus -c home create-config -t home /home
btrfs subvolume delete /.snapshots
mkdir -p /.snapshots
mount -a
chmod 750 /.snapshots
chmod a+rx /.snapshots
chown :wheel /.snapshots
chmod 750 /var/lib/docker/.snapshots
chmod a+rx /var/lib/docker/.snapshots
chown :wheel /var/lib/docker/.snapshots
chmod 750 /var/lib/libvirt/.snapshots
chmod a+rx /var/lib/libvirt/.snapshots
chown :wheel /var/lib/libvirt/.snapshots
chmod 750 /var/lib/mysql/.snapshots
chmod a+rx /var/lib/mysql/.snapshots
chown :wheel /var/lib/mysql/.snapshots
chmod 750 /var/log/.snapshots
chmod a+rx /var/log/.snapshots
chown :wheel /var/log/.snapshots
chmod 750 /home/.snapshots
chmod a+rx /home/.snapshots
chown :wheel /home/.snapshots

# Enable systemd services
pacman -Qq "apparmor" &&
    {
        systemctl enable apparmor.service
        systemctl enable auditd.service
    }
pacman -Qq "containerd" &&
    systemctl enable containerd.service
pacman -Qq "cronie" &&
    systemctl enable cronie.service
pacman -Qq "docker" &&
    systemctl enable docker.service
pacman -Qq "openssh" &&
    systemctl enable sshd.service
pacman -Qq "systemd" &&
    {
        systemctl enable systemd-resolved.service
        systemctl enable systemd-networkd.service
    }
pacman -Qq "util-linux" &&
    systemctl enable fstrim.timer
pacman -Qq "reflector" &&
    {
        systemctl enable reflector
        systemctl enable reflector.timer
    }
pacman -Qq "usbguard" &&
    systemctl enable usbguard.service

# Setup /boot & /efi
mkinitcpio -P
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Enable systemd services later that cause problems with `grub-install`
pacman -Qq "snapper" &&
    {
        systemctl enable snapper-cleanup.timer
        systemctl enable snapper-timeline.timer
    }

# Remove repo
rm -rf /git
