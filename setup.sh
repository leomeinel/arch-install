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

# Add groups & users
sed -i 's/^SHELL=.*/SHELL=\/bin\/bash/' /etc/default/useradd
groupadd -r audit
groupadd -r libvirt
groupadd -r share
groupadd -r usbguard
useradd -ms /bin/bash -G adm,audit,log,rfkill,share,sys,systemd-journal,usbguard,wheel "$SYSUSER"
useradd -ms /bin/bash -G share,libvirt "$VIRTUSER"
useradd -ms /bin/bash -G share "$HOMEUSER"
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
sed -i 's/^#de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/;s/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/;s/^#en_DK.UTF-8 UTF-8/en_DK.UTF-8 UTF-8/;s/^#fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/;s/^#nl_NL.UTF-8 UTF-8/nl_NL.UTF-8 UTF-8/' /etc/locale.gen
chmod 644 /etc/locale.conf
locale-gen
## Configure /etc/doas.conf
chown -c root:root /etc/doas.conf
chmod -c 0400 /etc/doas.conf
## Configure random MAC address for WiFi in /etc/NetworkManager/conf.d/wifi-rand-mac.conf 
chmod 644 /etc/NetworkManager/conf.d/wifi-rand-mac.conf
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
            echo 'Description = Updating NVIDIA mkinitcpio...'
            echo 'Depends = mkinitcpio'
            echo 'When = PostTransaction'
            echo 'NeedsTargets'
            echo "Exec = /bin/sh -c '/etc/pacman.d/hooks/scripts/90-nvidia-gen-mkinitcpio.sh'"
            echo ''
        } >/etc/pacman.d/hooks/90-nvidia-gen-mkinitcpio.hook
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
            echo ''
        } >/etc/pacman.d/hooks/scripts/90-nvidia-gen-mkinitcpio.sh
        sed -i '/Target = linux-zen/a Target = nvidia-dkms' /etc/pacman.d/hooks/95-upgrade-grub.hook
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
## Configure /etc/firejail/whitelist-common.local
chmod 644 /etc/firejail/whitelist-common.local
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
sed -i 's/^#PACMAN_AUTH=.*/PACMAN_AUTH=(doas)/' /etc/makepkg.conf
sed -i 's/^#Color/Color/;s/^#ParallelDownloads =.*/ParallelDownloads = 10/;s/^#CacheDir/CacheDir/' /etc/pacman.conf
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
git clone https://github.com/LeoMeinel/cryptboot.git /git/cryptboot
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
sed -i 's/^TEMPLATES=.*/TEMPLATES=Documents\/Templates/;s/^PUBLICSHARE=.*/PUBLICSHARE=Documents\/Public/;s/^DESKTOP=.*/DESKTOP=Documents\/Desktop/;s/^MUSIC=.*/MUSIC=Documents\/Music/;s/^PICTURES=.*/PICTURES=Documents\/Pictures/;s/^VIDEOS=.*/VIDEOS=Documents\/Videos/' /etc/xdg/user-dirs.defaults
## Configure /etc/mdadm.conf
mdadm --detail --scan >>/etc/mdadm.conf
## Configure /etc/usbguard/usbguard-daemon.conf & /etc/usbguard/rules.conf
usbguard generate-policy >/etc/usbguard/rules.conf
usbguard add-user -g usbguard --devices=modify,list,listen --policy=list --exceptions=listen
## Configure /etc/pam.d/system-login, /etc/security/faillock.conf, /etc/pam.d/su & /etc/pam.d/su-l
echo "auth optional pam_faildelay.so delay=8000000" >>/etc/pam.d/system-login
sed -i 's/^#.*dir.*=.*/dir = \/var\/lib\/faillock/' /etc/security/faillock.conf
echo "auth required pam_wheel.so use_uid" >>/etc/pam.d/su
echo "auth required pam_wheel.so use_uid" >>/etc/pam.d/su-l
## Configure /etc/audit/auditd.conf
sed -i 's/^log_group.*=.*/log_group = audit/' /etc/audit/auditd.conf
## mDNS
### Configure /etc/systemd/resolved.conf
sed -i 's/^#MulticastDNS=.*/MulticastDNS=no/' /etc/systemd/resolved.conf
### Configure /etc/nsswitch.conf
sed -i 's/^hosts: mymachines/hosts: mymachines mdns_minimal [NOTFOUND=return]/' /etc/nsswitch.conf
## Configure /etc/luks/keys
mkdir -p /etc/luks/keys
dd bs=1024 count=4 if=/dev/urandom of=/etc/luks/keys/md0_crypt.key iflag=fullblock
chmod 000 /etc/luks/keys/md0_crypt.key
echo "Enter passphrase for /dev/md/md0"
cryptsetup -v luksAddKey /dev/disk/by-uuid/"$MD0UUID" /etc/luks/keys/md0_crypt.key
## Configure /etc/mkinitcpio.conf
sed -i 's/^FILES=.*/FILES=(\/etc\/luks\/keys\/md0_crypt.key)/;s/^MODULES=.*/MODULES=(btrfs)/;s/^HOOKS=.*/HOOKS=(base udev autodetect keyboard keymap consolefont modconf block mdadm_udev encrypt filesystems fsck)/' /etc/mkinitcpio.conf
### If on nvidia enable kernel modules: nvidia nvidia_modeset nvidia_uvm nvidia_drm
pacman -Qq "nvidia-dkms" &&
    sed -i '/^MODULES=.*/s/)$/ nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
## Configure /etc/default/grub
sed -i "s/^#GRUB_ENABLE_CRYPTODISK=.*/GRUB_ENABLE_CRYPTODISK=y/;s/^#GRUB_TERMINAL_OUTPUT=.*/GRUB_TERMINAL_OUTPUT=\"gfxterm\"/;s/^GRUB_GFXPAYLOAD_LINUX=.*/GRUB_GFXPAYLOAD_LINUX=keep/;s/^GRUB_GFXMODE=.*/GRUB_GFXMODE=""$GRUBRESOLUTION""x32,auto/;s/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"quiet loglevel=3 audit=1 lsm=landlock,lockdown,yama,integrity,apparmor,bpf iommu=pt zswap.enabled=0 cryptdevice=UUID=$MD0UUID:md0_crypt cryptkey=rootfs:\/etc\/luks\/keys\/md0_crypt.key cryptdevice=UUID=$MD1UUID:md1_crypt root=\/dev\/mapper\/md1_crypt\"/;s/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX=\"quiet loglevel=3 audit=1 lsm=landlock,lockdown,yama,integrity,apparmor,bpf iommu=pt zswap.enabled=0 cryptdevice=UUID=$MD0UUID:md0_crypt cryptkey=rootfs:\/etc\/luks\/keys\/md0_crypt.key cryptdevice=UUID=$MD1UUID:md1_crypt root=\/dev\/mapper\/md1_crypt\"/;s/^#GRUB_DISABLE_SUBMENU=.*/GRUB_DISABLE_SUBMENU=y/;s/^GRUB_DEFAULT=.*/GRUB_DEFAULT=0/;s/^#GRUB_SAVEDEFAULT=.*/GRUB_SAVEDEFAULT=false/" /etc/default/grub
### If on nvidia set kernel parameter nvidia_drm.modeset=1
pacman -Qq "nvidia-dkms" &&
    sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=.*/s/"$/ nvidia_drm.modeset=1"/;/^GRUB_CMDLINE_LINUX=.*/s/"$/ nvidia_drm.modeset=1"/' /etc/default/grub
### If on intel set kernel parameter intel_iommu=on
pacman -Qq "intel-ucode" &&
    sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=.*/s/"$/ intel_iommu=on"/;/^GRUB_CMDLINE_LINUX=.*/s/"$/ intel_iommu=on"/' /etc/default/grub

# Setup /usr
rsync -rq /git/arch-install/usr/ /usr
cp /git/cryptboot/grub-install /usr/local/bin/
cp /git/cryptboot/cryptboot /usr/local/bin/
cp /git/cryptboot/cryptboot-efikeys /usr/local/bin/
## Configure /usr/share/gruvbox/gruvbox.yml
chmod 755 /usr/share/gruvbox
chmod 644 /usr/share/gruvbox/gruvbox.yml
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
cp /usr/share/snapper/config-templates/default /usr/share/snapper/config-templates/var_lib_libvirt
cp /usr/share/snapper/config-templates/default /usr/share/snapper/config-templates/var_lib_mysql
cp /usr/share/snapper/config-templates/default /usr/share/snapper/config-templates/var_log
cp /usr/share/snapper/config-templates/default /usr/share/snapper/config-templates/home
cp /usr/share/snapper/config-templates/default /usr/share/snapper/config-templates/share
sed -i 's/^ALLOW_GROUPS=.*/ALLOW_GROUPS="wheel"/;s/^SPACE_LIMIT=.*/SPACE_LIMIT="0.2"/;s/^NUMBER_LIMIT=.*/NUMBER_LIMIT="5"/;s/^NUMBER_LIMIT_IMPORTANT=.*/NUMBER_LIMIT_IMPORTANT="5"/;s/^TIMELINE_CREATE=.*/TIMELINE_CREATE="yes"/;s/^TIMELINE_CLEANUP=.*/TIMELINE_CLEANUP="yes"/;s/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="1"/;s/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY="3"/;s/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY="0"/;s/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY="0"/' /usr/share/snapper/config-templates/root
sed -i 's/^ALLOW_GROUPS=.*/ALLOW_GROUPS="wheel"/;s/^SPACE_LIMIT=.*/SPACE_LIMIT="0.05"/;s/^NUMBER_LIMIT=.*/NUMBER_LIMIT="5"/;s/^NUMBER_LIMIT_IMPORTANT=.*/NUMBER_LIMIT_IMPORTANT="5"/;s/^TIMELINE_CREATE=.*/TIMELINE_CREATE="yes"/;s/^TIMELINE_CLEANUP=.*/TIMELINE_CLEANUP="yes"/;s/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="1"/;s/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY="1"/;s/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY="0"/;s/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY="0"/' /usr/share/snapper/config-templates/var_lib_libvirt
sed -i 's/^ALLOW_GROUPS=.*/ALLOW_GROUPS="wheel"/;s/^SPACE_LIMIT=.*/SPACE_LIMIT="0.2"/;s/^NUMBER_LIMIT=.*/NUMBER_LIMIT="5"/;s/^NUMBER_LIMIT_IMPORTANT=.*/NUMBER_LIMIT_IMPORTANT="5"/;s/^TIMELINE_CREATE=.*/TIMELINE_CREATE="yes"/;s/^TIMELINE_CLEANUP=.*/TIMELINE_CLEANUP="yes"/;s/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="3"/;s/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY="2"/;s/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY="0"/;s/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY="0"/' /usr/share/snapper/config-templates/var_lib_mysql
sed -i 's/^ALLOW_GROUPS=.*/ALLOW_GROUPS="wheel"/;s/^SPACE_LIMIT=.*/SPACE_LIMIT="0.02"/;s/^NUMBER_LIMIT=.*/NUMBER_LIMIT="5"/;s/^NUMBER_LIMIT_IMPORTANT=.*/NUMBER_LIMIT_IMPORTANT="5"/;s/^TIMELINE_CREATE=.*/TIMELINE_CREATE="yes"/;s/^TIMELINE_CLEANUP=.*/TIMELINE_CLEANUP="yes"/;s/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="1"/;s/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY="1"/;s/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY="0"/;s/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY="0"/' /usr/share/snapper/config-templates/var_log
sed -i 's/^ALLOW_GROUPS=.*/ALLOW_GROUPS="wheel"/;s/^SPACE_LIMIT=.*/SPACE_LIMIT="0.2"/;s/^NUMBER_LIMIT=.*/NUMBER_LIMIT="5"/;s/^NUMBER_LIMIT_IMPORTANT=.*/NUMBER_LIMIT_IMPORTANT="5"/;s/^TIMELINE_CREATE=.*/TIMELINE_CREATE="yes"/;s/^TIMELINE_CLEANUP=.*/TIMELINE_CLEANUP="yes"/;s/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="3"/;s/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY="3"/;s/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY="0"/;s/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY="0"/' /usr/share/snapper/config-templates/home
sed -i 's/^ALLOW_GROUPS=.*/ALLOW_GROUPS="wheel"/;s/^SPACE_LIMIT=.*/SPACE_LIMIT="0.05"/;s/^NUMBER_LIMIT=.*/NUMBER_LIMIT="5"/;s/^NUMBER_LIMIT_IMPORTANT=.*/NUMBER_LIMIT_IMPORTANT="5"/;s/^TIMELINE_CREATE=.*/TIMELINE_CREATE="yes"/;s/^TIMELINE_CLEANUP=.*/TIMELINE_CLEANUP="yes"/;s/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="1"/;s/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY="1"/;s/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY="0"/;s/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY="0"/' /usr/share/snapper/config-templates/share
chmod 644 /usr/share/snapper/config-templates/root
chmod 644 /usr/share/snapper/config-templates/var_lib_libvirt
chmod 644 /usr/share/snapper/config-templates/var_lib_mysql
chmod 644 /usr/share/snapper/config-templates/var_log
chmod 644 /usr/share/snapper/config-templates/home
chmod 644 /usr/share/snapper/config-templates/share
snapper --no-dbus -c root create-config -t root /
snapper --no-dbus -c var_lib_libvirt create-config -t var_lib_libvirt /var/lib/libvirt
snapper --no-dbus -c var_lib_mysql create-config -t var_lib_mysql /var/lib/mysql
snapper --no-dbus -c var_log create-config -t var_log /var/log
snapper --no-dbus -c home create-config -t home /home
snapper --no-dbus -c share create-config -t share /share
btrfs subvolume delete /.snapshots
mkdir /.snapshots
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
chmod 750 /share/.snapshots
chmod a+rx /share/.snapshots
chown :wheel /share/.snapshots
## Configure /usr/share/wallpapers/Custom/content
mkdir -p /usr/share/wallpapers/Custom/content
git clone https://github.com/LeoMeinel/wallpapers.git /git/wallpapers
cp /git/wallpapers/*.jpg /git/wallpapers/*.png /usr/share/wallpapers/Custom/content/
chmod 755 /usr/share/wallpapers/Custom
chmod 755 /usr/share/wallpapers/Custom/content
chmod 644 /usr/share/wallpapers/Custom/content/*

# Configure /var
## Configure /var/games
chown :games /var/games

# Configure /share
mkdir /share/screenshots
chmod 3775 /share/screenshots
chown -R :share /share

# Set default java
archlinux-java set java-17-openjdk

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
