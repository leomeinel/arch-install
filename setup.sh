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
# https://www.rfc-editor.org/rfc/rfc1178.html
## Network devices: elements
## Servers: colors
## Clients: flowers
HOSTNAME="tulip"
# https://www.rfc-editor.org/rfc/rfc8375.html
DOMAIN="home.arpa"
SYSUSER="systux"
VIRTUSER="virt"
HOMEUSER="leo"
GUESTUSER="guest"

# Fail on error
set -eu

# Define functions
sed_exit() {
    echo "ERROR: 'sed' didn't replace, report this @"
    echo "       https://github.com/leomeinel/arch-install/issues"
    exit 1
}

# Add groups & users
## START sed
FILE=/etc/default/useradd
STRING="^SHELL=.*"
grep -q "$STRING" "$FILE" || sed_exit
sed -i "s/$STRING/SHELL=\/bin\/bash/" "$FILE"
## END sed
groupadd -r audit
groupadd -r libvirt
groupadd -r usbguard
useradd -ms /bin/bash -G adm,audit,log,rfkill,sys,systemd-journal,usbguard,wheel "$SYSUSER"
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

# Setup /etc
rsync -rq /git/arch-install/etc/ /etc
## Configure locale in /etc/locale.gen & /etc/locale.conf
### START sed
FILE=/etc/locale.gen
STRING="^#de_DE.UTF-8 UTF-8"
grep -q "$STRING" "$FILE" || sed_exit
sed -i "s/$STRING/de_DE.UTF-8 UTF-8/" "$FILE"
STRING="^#en_US.UTF-8 UTF-8"
grep -q "$STRING" "$FILE" || sed_exit
sed -i "s/$STRING/en_US.UTF-8 UTF-8/" "$FILE"
STRING="^#en_DK.UTF-8 UTF-8"
grep -q "$STRING" "$FILE" || sed_exit
sed -i "s/$STRING/en_DK.UTF-8 UTF-8/" "$FILE"
STRING="^#fr_FR.UTF-8 UTF-8"
grep -q "$STRING" "$FILE" || sed_exit
sed -i "s/$STRING/fr_FR.UTF-8 UTF-8/" "$FILE"
STRING="^#nl_NL.UTF-8 UTF-8"
grep -q "$STRING" "$FILE" || sed_exit
sed -i "s/$STRING/nl_NL.UTF-8 UTF-8/" "$FILE"
### END sed
chmod 644 /etc/locale.conf
locale-gen
## Configure /etc/doas.conf
chown -c root:root /etc/doas.conf
chmod -c 0400 /etc/doas.conf
## Configure random MAC address for WiFi in /etc/NetworkManager/conf.d/50-mac-random.conf
chmod 644 /etc/NetworkManager/conf.d/50-mac-random.conf
## Configure pacman hooks in /etc/pacman.d/hooks
{
    echo '#!/bin/sh'
    echo ''
    echo '/usr/bin/firecfg >/dev/null 2>&1'
    echo "/usr/bin/su -c '/usr/bin/rm -rf ~/.local/share/applications/*' $SYSUSER"
    echo "/usr/bin/su -c '/usr/bin/rm -rf ~/.local/share/applications/*' $VIRTUSER"
    echo "/usr/bin/su -c '/usr/bin/rm -rf ~/.local/share/applications/*' $HOMEUSER"
    echo "/usr/bin/su -c '/usr/bin/rm -rf ~/.local/share/applications/*' $GUESTUSER"
    echo ''
} >/etc/pacman.d/hooks/scripts/70-firejail.sh
### Configure hooks for nvidia in /etc/pacman.d/hooks/
pacman -Qq "nvidia-dkms" &&
    {
        {
            echo '[Trigger]'
            echo 'Operation = Install'
            echo 'Operation = Upgrade'
            echo 'Operation = Remove'
            echo 'Type = Package'
            echo 'Target = linux'
            echo 'Target = linux-lts'
            echo 'Target = linux-zen'
            echo 'Target = nvidia-dkms'
            echo ''
            echo '[Action]'
            echo 'Description = Updating NVIDIA initcpio...'
            echo 'Depends = dracut'
            echo 'When = PostTransaction'
            echo 'NeedsTargets'
            echo "Exec = /bin/sh -c '/etc/pacman.d/hooks/scripts/90-dracut-nvidia.sh'"
            echo ''
        } >/etc/pacman.d/hooks/90-dracut-nvidia.hook
        {
            echo '#!/bin/sh'
            echo ''
            echo 'while read -r target'
            echo 'do'
            echo '    case $target in'
            echo '        linux) exit 0'
            echo '    esac'
            echo 'done'
            echo '/usr/bin/dracut --regenerate-all --force'
            echo ''
        } >/etc/pacman.d/hooks/scripts/90-dracut-nvidia.sh
        #### START sed
        FILE=/etc/pacman.d/hooks/96-systemd-boot-sign.hook
        STRING="^Target = linux-zen"
        grep -q "$STRING" "$FILE" || sed_exit
        sed -i "/$STRING/a Target = nvidia-dkms" "$FILE"
        #### END sed
    }
chmod 755 /etc/pacman.d/hooks
chmod 755 /etc/pacman.d/hooks/scripts
chmod 644 /etc/pacman.d/hooks/*.hook
chmod 744 /etc/pacman.d/hooks/scripts/*.sh
## Configure /etc/sddm.conf.d/kde_settings.conf
chmod 755 /etc/sddm.conf.d
chmod 644 /etc/sddm.conf.d/kde_settings.conf
## Configure /etc/systemd/zram-generator.conf
chmod 644 /etc/systemd/zram-generator.conf
## Configure /etc/sysctl.d
chmod 755 /etc/sysctl.d
chmod 644 /etc/sysctl.d/*
## Configure /etc/systemd/system/snapper-cleanup.timer.d/override.conf
chmod 644 /etc/systemd/system/snapper-cleanup.timer.d/override.conf
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
grep -q "$STRING" "$FILE" || sed_exit
sed -i "s/$STRING/PACMAN_AUTH=(doas)/" "$FILE"
###
FILE=/etc/pacman.conf
STRING="^#Color"
grep -q "$STRING" "$FILE" || sed_exit
sed -i "s/$STRING/Color/" "$FILE"
STRING="^#ParallelDownloads =.*"
grep -q "$STRING" "$FILE" || sed_exit
sed -i "s/$STRING/ParallelDownloads = 10/" "$FILE"
STRING="^#CacheDir"
grep -q "$STRING" "$FILE" || sed_exit
sed -i "s/$STRING/CacheDir/" "$FILE"
### END sed
pacman-key --init
## Update mirrors
reflector --save /etc/pacman.d/mirrorlist --country $MIRRORCOUNTRIES --protocol https --latest 20 --sort rate

# Install packages
pacman -Syu --noprogressbar --noconfirm --needed - </git/arch-install/pkgs-setup.txt

# Configure $SYSUSER
## Run sysuser.sh
chmod +x /git/arch-install/sysuser.sh
su -c '/git/arch-install/sysuser.sh '"$SYSUSER $VIRTUSER $HOMEUSER $GUESTUSER"'' "$SYSUSER"
cp /git/arch-install/dot-files.sh /
chmod 777 /dot-files.sh

# Configure /etc
## Configure /etc/crypttab
MD0UUID="$(blkid -s UUID -o value /dev/md/md0)"
{
    echo "md0_crypt UUID=$MD0UUID none initramfs,luks,key-slot=0"
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
git clone -b systemd-boot https://github.com/leomeinel/cryptboot.git /git/cryptboot
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
## Configure /etc/xdg/user-dirs.defaults
### START sed
FILE=/etc/xdg/user-dirs.defaults
STRING="^TEMPLATES=.*"
grep -q "$STRING" "$FILE" || sed_exit
sed -i "s|$STRING|TEMPLATES=Documents/Templates|" "$FILE"
STRING="^PUBLICSHARE=.*"
grep -q "$STRING" "$FILE" || sed_exit
sed -i "s|$STRING|PUBLICSHARE=Documents/Public|" "$FILE"
STRING="^DESKTOP=.*"
grep -q "$STRING" "$FILE" || sed_exit
sed -i "s|$STRING|DESKTOP=Desktop|" "$FILE"
STRING="^MUSIC=.*"
grep -q "$STRING" "$FILE" || sed_exit
sed -i "s|$STRING|MUSIC=Documents/Music|" "$FILE"
STRING="^PICTURES=.*"
grep -q "$STRING" "$FILE" || sed_exit
sed -i "s|$STRING|PICTURES=Documents/Pictures|" "$FILE"
STRING="^VIDEOS=.*"
grep -q "$STRING" "$FILE" || sed_exit
sed -i "s|$STRING|VIDEOS=Documents/Videos|" "$FILE"
### END sed
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
grep -q "$STRING" "$FILE" || sed_exit
sed -i "s|$STRING|dir = /var/lib/faillock|" "$FILE"
### END sed
echo "auth required pam_wheel.so use_uid" >>/etc/pam.d/su
echo "auth required pam_wheel.so use_uid" >>/etc/pam.d/su-l
## Configure /etc/audit/auditd.conf
### START sed
FILE=/etc/audit/auditd.conf
STRING="^log_group.*=.*"
grep -q "$STRING" "$FILE" || sed_exit
sed -i "s/$STRING/log_group = audit/" "$FILE"
### END sed
## mDNS
### Configure /etc/systemd/resolved.conf
### START sed
FILE=/etc/systemd/resolved.conf
STRING="^#MulticastDNS=.*"
grep -q "$STRING" "$FILE" || sed_exit
sed -i "s/$STRING/MulticastDNS=no/" "$FILE"
### END sed
### Configure /etc/nsswitch.conf
### START sed
FILE=/etc/nsswitch.conf
STRING="^hosts: mymachines"
grep -q "$STRING" "$FILE" || sed_exit
sed -i "s/$STRING/hosts: mymachines mdns_minimal [NOTFOUND=return]/" "$FILE"
### END sed
## Configure /etc/bluetooth/main.conf
### START sed
FILE=/etc/bluetooth/main.conf
STRING="^#AutoEnable=.*"
grep -q "$STRING" "$FILE" || sed_exit
sed -i "s/$STRING/AutoEnable=true/" "$FILE"
### END sed
## Configure /etc/dracut.conf.d/modules.conf
{
    echo "add_dracutmodules+=\" lvm btrfs mdraid crypt \""
    echo "add_drivers+=\" raid1 \""
    echo "filesystems+=\" btrfs \""
} >/etc/dracut.conf.d/modules.conf
## If on nvidia add kernel modules: nvidia nvidia_modeset nvidia_uvm nvidia_drm
pacman -Qq "nvidia-dkms" &&
    echo "force_drivers+=\" nvidia nvidia_modeset nvidia_uvm nvidia_drm \"" >/etc/dracut.conf.d/modules.conf
## Configure /etc/dracut.conf.d/cmdline.conf
DISK1="$(lsblk -npo PKNAME $(findmnt -no SOURCE --target /efi) | tr -d "[:space:]")"
DISK1P2="$(lsblk -rnpo TYPE,NAME "$DISK1" | grep "part" | sed 's/part//' | sed -n '2p' | tr -d "[:space:]")"
DISK1P2UUID="$(blkid -s UUID -o value $DISK1P2)"
DISK2="$(lsblk -npo PKNAME $(findmnt -no SOURCE --target /.efi.bak) | tr -d "[:space:]")"
DISK2P2="$(lsblk -rnpo TYPE,NAME "$DISK2" | grep "part" | sed 's/part//' | sed -n '2p' | tr -d "[:space:]")"
DISK2P2UUID="$(blkid -s UUID -o value $DISK2P2)"
LV0UUID="$(blkid -s UUID -o value /dev/mapper/vg0-lv0)"
echo "kernel_cmdline=\"rd.auto=1 rd.lvm=1 rd.dm=1 rd.md=1 rd.luks=1 rd.md.uuid=$MD0UUID rd.md.waitclean=1 rd.luks.uuid=$MD0UUID rd.lvm.vg=vg0 rd.lvm.lv=vg0/lv0 rd.lvm.lv=vg0/lv1 root=UUID=$LV0UUID rootfstype=btrfs rootflags=rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvolid=256,subvol=/@ rd.luks.allow-discards=$DISK1P2UUID rd.luks.allow-discards=$DISK2P2UUID\"" >/etc/dracut.conf.d/cmdline.conf
chmod 644 /etc/dracut.conf.d/*.conf
## Configure /etc/kernel/commandline
PARAMETERS="quiet loglevel=3 cryptdevice=UUID=$MD0UUID bgrt_disable audit=1 lsm=landlock,lockdown,yama,integrity,apparmor,bpf iommu=pt zswap.enabled=0"
#### If on nvidia set kernel parameter nvidia_drm.modeset=1
pacman -Qq "nvidia-dkms" &&
    PARAMETERS="${PARAMETERS} nvidia_drm.modeset=1"
#### If on intel set kernel parameter intel_iommu=on
pacman -Qq "intel-ucode" &&
    PARAMETERS="${PARAMETERS} intel_iommu=on"
mkdir -p /etc/kernel
echo "$PARAMETERS" >/etc/kernel/commandline

# Setup /usr
rsync -rq /git/arch-install/usr/ /usr
cp /git/cryptboot/systemd-boot-sign /usr/local/bin/
cp /git/cryptboot/cryptboot /usr/local/bin/
cp /git/cryptboot/cryptboot-efikeys /usr/local/bin/
## Configure /usr/share/gruvbox/gruvbox.yml
chmod 755 /usr/share/gruvbox
chmod 644 /usr/share/gruvbox/gruvbox.yml
## Configure /usr/local/bin
chmod 755 /usr/local/bin/cryptboot
chmod 755 /usr/local/bin/cryptboot-efikeys
chmod 755 /usr/local/bin/systemd-boot-sign
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
grep -q "$STRING0" "$FILE" || sed_exit
sed -i "s/$STRING0/ALLOW_GROUPS=\"wheel\"/" "$FILE"
grep -q "$STRING1" "$FILE" || sed_exit
sed -i "s/$STRING1/SPACE_LIMIT=\"0.2\"/" "$FILE"
grep -q "$STRING2" "$FILE" || sed_exit
sed -i "s/$STRING2/NUMBER_LIMIT=\"5\"/" "$FILE"
grep -q "$STRING3" "$FILE" || sed_exit
sed -i "s/$STRING3/NUMBER_LIMIT_IMPORTANT=\"5\"/" "$FILE"
grep -q "$STRING4" "$FILE" || sed_exit
sed -i "s/$STRING4/TIMELINE_CREATE=\"yes\"/" "$FILE"
grep -q "$STRING5" "$FILE" || sed_exit
sed -i "s/$STRING5/TIMELINE_CLEANUP=\"yes\"/" "$FILE"
grep -q "$STRING6" "$FILE" || sed_exit
sed -i "s/$STRING6/TIMELINE_LIMIT_HOURLY=\"1\"/" "$FILE"
grep -q "$STRING7" "$FILE" || sed_exit
sed -i "s/$STRING7/TIMELINE_LIMIT_DAILY=\"3\"/" "$FILE"
grep -q "$STRING8" "$FILE" || sed_exit
sed -i "s/$STRING8/TIMELINE_LIMIT_MONTHLY=\"0\"/" "$FILE"
grep -q "$STRING9" "$FILE" || sed_exit
sed -i "s/$STRING9/TIMELINE_LIMIT_YEARLY=\"0\"/" "$FILE"
###
FILE=/usr/share/snapper/config-templates/var_lib_libvirt
grep -q "$STRING0" "$FILE" || sed_exit
sed -i "s/$STRING0/ALLOW_GROUPS=\"wheel\"/" "$FILE"
grep -q "$STRING1" "$FILE" || sed_exit
sed -i "s/$STRING1/SPACE_LIMIT=\"0.05\"/" "$FILE"
grep -q "$STRING2" "$FILE" || sed_exit
sed -i "s/$STRING2/NUMBER_LIMIT=\"5\"/" "$FILE"
grep -q "$STRING3" "$FILE" || sed_exit
sed -i "s/$STRING3/NUMBER_LIMIT_IMPORTANT=\"5\"/" "$FILE"
grep -q "$STRING4" "$FILE" || sed_exit
sed -i "s/$STRING4/TIMELINE_CREATE=\"yes\"/" "$FILE"
grep -q "$STRING5" "$FILE" || sed_exit
sed -i "s/$STRING5/TIMELINE_CLEANUP=\"yes\"/" "$FILE"
grep -q "$STRING6" "$FILE" || sed_exit
sed -i "s/$STRING6/TIMELINE_LIMIT_HOURLY=\"1\"/" "$FILE"
grep -q "$STRING7" "$FILE" || sed_exit
sed -i "s/$STRING7/TIMELINE_LIMIT_DAILY=\"1\"/" "$FILE"
grep -q "$STRING8" "$FILE" || sed_exit
sed -i "s/$STRING8/TIMELINE_LIMIT_MONTHLY=\"0\"/" "$FILE"
grep -q "$STRING9" "$FILE" || sed_exit
sed -i "s/$STRING9/TIMELINE_LIMIT_YEARLY=\"0\"/" "$FILE"
###
FILE=/usr/share/snapper/config-templates/var_lib_mysql
grep -q "$STRING0" "$FILE" || sed_exit
sed -i "s/$STRING0/ALLOW_GROUPS=\"wheel\"/" "$FILE"
grep -q "$STRING1" "$FILE" || sed_exit
sed -i "s/$STRING1/SPACE_LIMIT=\"0.2\"/" "$FILE"
grep -q "$STRING2" "$FILE" || sed_exit
sed -i "s/$STRING2/NUMBER_LIMIT=\"5\"/" "$FILE"
grep -q "$STRING3" "$FILE" || sed_exit
sed -i "s/$STRING3/NUMBER_LIMIT_IMPORTANT=\"5\"/" "$FILE"
grep -q "$STRING4" "$FILE" || sed_exit
sed -i "s/$STRING4/TIMELINE_CREATE=\"yes\"/" "$FILE"
grep -q "$STRING5" "$FILE" || sed_exit
sed -i "s/$STRING5/TIMELINE_CLEANUP=\"yes\"/" "$FILE"
grep -q "$STRING6" "$FILE" || sed_exit
sed -i "s/$STRING6/TIMELINE_LIMIT_HOURLY=\"3\"/" "$FILE"
grep -q "$STRING7" "$FILE" || sed_exit
sed -i "s/$STRING7/TIMELINE_LIMIT_DAILY=\"2\"/" "$FILE"
grep -q "$STRING8" "$FILE" || sed_exit
sed -i "s/$STRING8/TIMELINE_LIMIT_MONTHLY=\"0\"/" "$FILE"
grep -q "$STRING9" "$FILE" || sed_exit
sed -i "s/$STRING9/TIMELINE_LIMIT_YEARLY=\"0\"/" "$FILE"
###
FILE=/usr/share/snapper/config-templates/var_log
grep -q "$STRING0" "$FILE" || sed_exit
sed -i "s/$STRING0/ALLOW_GROUPS=\"wheel\"/" "$FILE"
grep -q "$STRING1" "$FILE" || sed_exit
sed -i "s/$STRING1/SPACE_LIMIT=\"0.02\"/" "$FILE"
grep -q "$STRING2" "$FILE" || sed_exit
sed -i "s/$STRING2/NUMBER_LIMIT=\"5\"/" "$FILE"
grep -q "$STRING3" "$FILE" || sed_exit
sed -i "s/$STRING3/NUMBER_LIMIT_IMPORTANT=\"5\"/" "$FILE"
grep -q "$STRING4" "$FILE" || sed_exit
sed -i "s/$STRING4/TIMELINE_CREATE=\"yes\"/" "$FILE"
grep -q "$STRING5" "$FILE" || sed_exit
sed -i "s/$STRING5/TIMELINE_CLEANUP=\"yes\"/" "$FILE"
grep -q "$STRING6" "$FILE" || sed_exit
sed -i "s/$STRING6/TIMELINE_LIMIT_HOURLY=\"1\"/" "$FILE"
grep -q "$STRING7" "$FILE" || sed_exit
sed -i "s/$STRING7/TIMELINE_LIMIT_DAILY=\"1\"/" "$FILE"
grep -q "$STRING8" "$FILE" || sed_exit
sed -i "s/$STRING8/TIMELINE_LIMIT_MONTHLY=\"0\"/" "$FILE"
grep -q "$STRING9" "$FILE" || sed_exit
sed -i "s/$STRING9/TIMELINE_LIMIT_YEARLY=\"0\"/" "$FILE"
###
FILE=/usr/share/snapper/config-templates/home
grep -q "$STRING0" "$FILE" || sed_exit
sed -i "s/$STRING0/ALLOW_GROUPS=\"wheel\"/" "$FILE"
grep -q "$STRING1" "$FILE" || sed_exit
sed -i "s/$STRING1/SPACE_LIMIT=\"0.2\"/" "$FILE"
grep -q "$STRING2" "$FILE" || sed_exit
sed -i "s/$STRING2/NUMBER_LIMIT=\"5\"/" "$FILE"
grep -q "$STRING3" "$FILE" || sed_exit
sed -i "s/$STRING3/NUMBER_LIMIT_IMPORTANT=\"5\"/" "$FILE"
grep -q "$STRING4" "$FILE" || sed_exit
sed -i "s/$STRING4/TIMELINE_CREATE=\"yes\"/" "$FILE"
grep -q "$STRING5" "$FILE" || sed_exit
sed -i "s/$STRING5/TIMELINE_CLEANUP=\"yes\"/" "$FILE"
grep -q "$STRING6" "$FILE" || sed_exit
sed -i "s/$STRING6/TIMELINE_LIMIT_HOURLY=\"3\"/" "$FILE"
grep -q "$STRING7" "$FILE" || sed_exit
sed -i "s/$STRING7/TIMELINE_LIMIT_DAILY=\"3\"/" "$FILE"
grep -q "$STRING8" "$FILE" || sed_exit
sed -i "s/$STRING8/TIMELINE_LIMIT_MONTHLY=\"0\"/" "$FILE"
grep -q "$STRING9" "$FILE" || sed_exit
sed -i "s/$STRING9/TIMELINE_LIMIT_YEARLY=\"0\"/" "$FILE"
### END sed
chmod 644 /usr/share/snapper/config-templates/root
chmod 644 /usr/share/snapper/config-templates/var_lib_libvirt
chmod 644 /usr/share/snapper/config-templates/var_lib_mysql
chmod 644 /usr/share/snapper/config-templates/var_log
chmod 644 /usr/share/snapper/config-templates/home
snapper --no-dbus -c root create-config -t root /
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
## Configure /usr/share/wallpapers/Custom/content
mkdir -p /usr/share/wallpapers/Custom/content
git clone https://github.com/leomeinel/wallpapers.git /git/wallpapers
cp /git/wallpapers/*.jpg /git/wallpapers/*.png /usr/share/wallpapers/Custom/content/
chmod 755 /usr/share/wallpapers/Custom
chmod 755 /usr/share/wallpapers/Custom/content
chmod 644 /usr/share/wallpapers/Custom/content/*

# Configure /var
## Configure /var/games
chown :games /var/games

# Setup /efi
rsync -rq /git/arch-install/efi/ /efi
chmod 644 /efi/loader/loader.conf

# Enable systemd services
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
pacman -Qq "snapper" &&
    {
        systemctl enable snapper-cleanup.timer
        systemctl enable snapper-timeline.timer
    }
pacman -Qq "systemd" &&
    systemctl enable systemd-boot-update.service
pacman -Qq "usbguard" &&
    systemctl enable usbguard.service

# Setup /boot & /efi
if udevadm info -q property --property=ID_BUS --value "$DISK1" | grep -q "usb"; then
    bootctl --esp-path=/efi --no-variables install
else
    bootctl --esp-path=/efi install
fi
dracut --regenerate-all --uefi

# Remove repo
rm -rf /git
