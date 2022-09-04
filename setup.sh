#!/bin/bash

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
set -e

# Add groups and users
sed -i 's/^SHELL=.*/SHELL=\/bin\/bash/' /etc/default/useradd
groupadd -r sudo
groupadd -r libvirt
useradd -ms /bin/bash -G sudo,wheel "$SYSUSER"
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

# Configure /etc/pacman.conf, /etc/xdg/reflector/reflector.conf, /etc/pacman.d/repo/aur.conf and add local repo /var/lib/repo/aur/aur.db.tar.gz
{
  echo "--save /etc/pacman.d/mirrorlist"
  echo "--country $MIRRORCOUNTRIES"
  echo "--protocol https"
  echo "--latest 20"
  echo "--sort rate"
} > /etc/xdg/reflector/reflector.conf
chmod -R 755 /etc/xdg
chmod 644 /etc/xdg/reflector/reflector.conf
curl -s 'https://download.opensuse.org/repositories/home:/ungoogled_chromium/Arch/x86_64/home_ungoogled_chromium_Arch.key' | pacman-key -a -
mv /git/mdadm-encrypted-btrfs/etc/pacman.d/repo /etc/pacman.d/
chmod -R 755 /etc/pacman.d/repo
chmod 644 /etc/pacman.d/repo/*.conf
mkdir -p /var/cache/aur/pkg
mkdir -p /var/cache/home_ungoogled_chromium_Arch/pkg
mkdir -p /var/lib/repo/aur
repo-add /var/lib/repo/aur/aur.db.tar.gz
sed -i 's/^#Color/Color/;s/^#ParallelDownloads =.*/ParallelDownloads = 10/;s/^#CacheDir/CacheDir/' /etc/pacman.conf
{
  echo ""
  echo "[options]"
  echo "Include = /etc/pacman.d/repo/aur.conf"
  echo "Include = /etc/pacman.d/repo/home_ungoogled_chromium_Arch.conf"
} >> /etc/pacman.conf
pacman-key --init

# Update mirrors
reflector --save /etc/pacman.d/mirrorlist --country $MIRRORCOUNTRIES --protocol https --latest 20 --sort rate

# Configure $SYSUSER
## sudo
## FIXME: Sudo is mainly used for:
  ## - /usr/bin/mkarchroot
  ## - SETENV: /usr/bin/makechrootpkg
  ## - /usr/bin/arch-nspawn
  ## It shouldn't be enabled for ALL.
  ## However those scripts use different scripts/commands so it is very hard to tell which should actually be allowed.
    ## FUTURE GOAL: REPLACE sudo WITH doas
echo "%sudo ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/sudo

## opendoas
mv /git/mdadm-encrypted-btrfs/etc/doas.conf /etc/
chown -c root:root /etc/doas.conf
chmod -c 0400 /etc/doas.conf

## Install required aur packages
chmod +x /git/mdadm-encrypted-btrfs/sysuser-setup.sh
su -c '/git/mdadm-encrypted-btrfs/sysuser-setup.sh' "$SYSUSER"

## sudo
echo "%sudo ALL=(ALL:ALL) ALL" > /etc/sudoers.d/sudo

# Install packages
pacman -Syu --noprogressbar --noconfirm --needed - < /git/mdadm-encrypted-btrfs/packages_setup.txt

# Change ownership of /var/lib/repo/aur to $SYSUSER
chown -R "$SYSUSER": /var/lib/repo/aur

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
mkdir /usr/share/gruvbox
mv /git/mdadm-encrypted-btrfs/gruvbox.yml /usr/share/gruvbox/
chmod -R 755 /usr/share/gruvbox
chmod 644 /usr/share/gruvbox/gruvbox.yml

# Configure /usr/share/snapper/config-templates/default and add snapper configs
umount /.snapshots
rm -rf /.snapshots
sed -i 's/^ALLOW_GROUPS=.*/ALLOW_GROUPS="sudo"/;s/^SPACE_LIMIT=.*/SPACE_LIMIT="0.1"/;s/^NUMBER_LIMIT=.*/NUMBER_LIMIT="10"/;s/^NUMBER_LIMIT_IMPORTANT=.*/NUMBER_LIMIT_IMPORTANT="10"/;s/^TIMELINE_CREATE=.*/TIMELINE_CREATE="yes"/;s/^TIMELINE_CLEANUP=.*/TIMELINE_CLEANUP="yes"/;s/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="4"/;s/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY="2"/;s/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY="0"/;s/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY="0"/' /usr/share/snapper/config-templates/default
snapper --no-dbus -c root create-config /
snapper --no-dbus -c var create-config /var
snapper --no-dbus -c home create-config /home
btrfs subvolume delete /.snapshots
mkdir /.snapshots
mount -a
chmod 750 /.snapshots
chmod a+rx /.snapshots
chown :sudo /.snapshots
chmod 750 /var/.snapshots
chmod a+rx /var/.snapshots
chown :sudo /var/.snapshots
chmod 750 /home/.snapshots
chmod a+rx /home/.snapshots
chown :sudo /home/.snapshots

# Configure symlinks
mv /git/mdadm-encrypted-btrfs/usr/bin/* /usr/bin/
ln -s "$(which nvim)" /usr/bin/edit
ln -s "$(which nvim)" /usr/bin/vedit
ln -s "$(which nvim)" /usr/bin/vi
ln -s "$(which nvim)" /usr/bin/vim
chmod 755 /usr/bin/ex
chmod 755 /usr/bin/view
chmod 755 /usr/bin/vimdiff
chmod 755 /usr/bin/edit
chmod 755 /usr/bin/vedit
chmod 755 /usr/bin/vi
chmod 755 /usr/bin/vim

# Configure /etc/sddm.conf.d/kde_settings.conf
mv /git/mdadm-encrypted-btrfs/etc/sddm.conf.d /etc/
chmod -R 755 /etc/sddm.conf.d
chmod 644 /etc/sddm.conf.d/kde_settings.conf

# Configure /etc/localtime, /etc/locale.conf, /etc/vconsole.conf, /etc/hostname and /etc/hosts
ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
hwclock --systohc
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/;s/^#de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/;s/^#fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/;s/^#nl_NL.UTF-8 UTF-8/nl_NL.UTF-8 UTF-8/' /etc/locale.gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
locale-gen
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf
echo "$HOSTNAME" > /etc/hostname
{
  echo "127.0.0.1  localhost"
  echo "127.0.1.1  $HOSTNAME.$DOMAIN	$HOSTNAME"
  echo "::1  ip6-localhost ip6-loopback"
  echo "ff02::1  ip6-allnodes"
  echo "ff02::2  ip6-allrouters"
} > /etc/hosts

# Configure /etc/systemd/zram-generator.conf
mv /git/mdadm-encrypted-btrfs/etc/systemd/zram-generator.conf /etc/systemd/
chmod 644 /etc/systemd/zram-generator.conf

# Configure /etc/mdadm.conf
mdadm --detail --scan >> /etc/mdadm.conf

# Configure dot-files
chmod +x /git/mdadm-encrypted-btrfs/dot-files.sh
su -c '/git/mdadm-encrypted-btrfs/dot-files.sh' "$SYSUSER"
su -c '/git/mdadm-encrypted-btrfs/dot-files.sh' "$VIRTUSER"
su -c '/git/mdadm-encrypted-btrfs/dot-files.sh' "$HOMEUSER"
su -c '/git/mdadm-encrypted-btrfs/dot-files.sh' "$GUESTUSER"

# Enable systemd services
systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable cups.service
systemctl enable avahi-daemon
systemctl enable power-profiles-daemon
systemctl enable reflector
systemctl enable reflector.timer
systemctl enable fstrim.timer
systemctl enable libvirtd
systemctl enable acpid

# Configure pacman hooks in /etc/pacman.d/hooks
mv /git/mdadm-encrypted-btrfs/etc/pacman.d/hooks /etc/pacman.d/

# Configure mDNS for Avahi
## Configure mDNS in /etc/systemd/resolved.conf
sed -i 's/^#MulticastDNS=.*/MulticastDNS=no/' /etc/systemd/resolved.conf

## Configure mDNS in /etc/nsswitch.conf
sed -i 's/^hosts: mymachines/hosts: mymachines mdns_minimal [NOTFOUND=return]/' /etc/nsswitch.conf

## If on nvidia add hooks
pacman -Qq "nvidia-dkms" &&
{
  {
    echo '[Trigger]'
    echo 'Operation=Install'
    echo 'Operation=Upgrade'
    echo 'Operation=Remove'
    echo 'Type=Package'
    echo 'Target=nvidia-dkms'
    echo 'Target=linux'
    echo 'Target=linux-lts'
    echo 'Target=linux-hardened'
    echo 'Target=linux-zen'
    echo ''
    echo '[Action]'
    echo 'Description=Updating NVIDIA mkinitcpio...'
    echo 'Depends=mkinitcpio'
    echo 'When=PostTransaction'
    echo 'NeedsTargets'
    echo "Exec=/bin/sh -c '/etc/pacman.d/hooks/scripts/custom-nvidia-gen-mkinitcpio.sh'"
  } > /etc/pacman.d/hooks/custom-nvidia-gen-mkinitcpio.hook
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
  } > /etc/pacman.d/hooks/scripts/custom-nvidia-gen-mkinitcpio.sh
}
chmod -R 755 /etc/pacman.d/hooks
chmod 644 /etc/pacman.d/hooks/*.hook

# Add key for /dev/mapper/md0_crypt
dd bs=1024 count=4 if=/dev/urandom of=/root/md0_crypt.keyfile iflag=fullblock
chmod 000 /root/md0_crypt.keyfile
MD0UUID="$(blkid -s UUID -o value /dev/md/md0)"
echo "Enter password for /dev/md/md0"
cryptsetup -v luksAddKey /dev/disk/by-uuid/"$MD0UUID" /root/md0_crypt.keyfile

# Configure /etc/mkinitcpio.conf
sed -i 's/^FILES=.*/FILES=(\/root\/md0_crypt.keyfile)/;s/^MODULES=.*/MODULES=(btrfs)/;s/^HOOKS=.*/HOOKS=(base udev autodetect keyboard keymap consolefont modconf block mdadm_udev encrypt filesystems fsck)/' /etc/mkinitcpio.conf

## If on nvidia add nvidia nvidia_modeset nvidia_uvm nvidia_drm
pacman -Qq "nvidia-dkms" &&
sed -i '/^MODULES=.*/s/)$/ nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
mkinitcpio -P
chmod 600 /boot/initramfs-linux*

# Configure /etc/default/grub
MD0CRYPTUUID="$(blkid -s UUID -o value /dev/mapper/md0_crypt)"
MD1CRYPTUUID="$(blkid -s UUID -o value /dev/mapper/md1_crypt)"
sed -i "s/^#GRUB_ENABLE_CRYPTODISK=.*/GRUB_ENABLE_CRYPTODISK=y/;s/^#GRUB_TERMINAL_OUTPUT=.*/GRUB_TERMINAL_OUTPUT=\"gfxterm\"/;s/^GRUB_GFXPAYLOAD_LINUX=.*/GRUB_GFXPAYLOAD_LINUX=keep/;s/^GRUB_GFXMODE=.*/GRUB_GFXMODE=""$GRUBRESOLUTION""x32,auto/;s/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet cryptdevice=UUID=$MD0UUID:md0_crypt cryptkey=rootfs:\/root\/md0_crypt.keyfile cryptdevice=UUID=$MD1UUID:md1_crypt root=UUID=$MD1CRYPTUUID\"/;s/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX=\"loglevel=3 quiet cryptdevice=UUID=$MD0UUID:md0_crypt cryptkey=rootfs:\/root\/md0_crypt.keyfile cryptdevice=UUID=$MD1UUID:md1_crypt root=UUID=$MD1CRYPTUUID\"/;s/^#GRUB_DISABLE_SUBMENU=.*/GRUB_DISABLE_SUBMENU=y/;s/^GRUB_DEFAULT=.*/GRUB_DEFAULT=0/;s/^#GRUB_SAVEDEFAULT=.*/GRUB_SAVEDEFAULT=false/" /etc/default/grub

## If on nvidia add nvidia_drm.modeset=1
pacman -Qq "nvidia-dkms" &&
sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=.*/s/"$/ nvidia_drm.modeset=1"/' /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# FIXME: Enable some systemd services later because of grub-install ERROR:
  # Detecting snapshots ...
  # mount: /tmp/grub-btrfs.<...>: special device /dev/disk/by-uuid/<UUID of /dev/mapper/md1_crypt> does not exist.
systemctl enable snapper-timeline.timer
systemctl enable snapper-cleanup.timer

# Remove repo
rm -rf /git
