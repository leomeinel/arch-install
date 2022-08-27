#!/bin/bash

KEYMAP="de-latin1"
HOSTNAME="tux-stellaris-15"
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

# Detect partitions and set environment variables accordingly
{
  echo "DISK1P1_PARTUUID=\"$(blkid -t LABEL="BOOT" -s PARTUUID -o value | sed -n '1p' | tr -d "[:space:]")\""
  echo "DISK1P2_PARTUUID=\"$(blkid -t LABEL="any:md0" -s PARTUUID -o value | sed -n '1p' | tr -d "[:space:]")\""
  echo "DISK2P1_PARTUUID=\"$(blkid -t LABEL="BOOT" -s PARTUUID -o value | sed -n '2p' | tr -d "[:space:]")\""
  echo "DISK2P2_PARTUUID=\"$(blkid -t LABEL="any:md0" -s PARTUUID -o value | sed -n '2p' | tr -d "[:space:]")\""
  echo "EDITOR=\"/usr/bin/nvim\""
  echo "BROWSER=\"/usr/bin/chromium\""
} >> /etc/environment

# Add groups and users
sed -i 's/SHELL=.*/SHELL=\/bin\/bash/' /etc/default/useradd
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
sed -i 's/#Color/Color/;s/#ParallelDownloads = 5/ParallelDownloads = 10/;s/#CacheDir/CacheDir/' /etc/pacman.conf
{
  echo ""
  echo "[options]"
  echo "Include = /etc/pacman.d/repo/aur.conf"
  echo "Include = /etc/pacman.d/repo/home_ungoogled_chromium_Arch.conf"
} >> /etc/pacman.conf
pacman-key --init

# Install packages
reflector --save /etc/pacman.d/mirrorlist --country $MIRRORCOUNTRIES --protocol https --latest 20 --sort rate
pacman -Syu --noprogressbar --noconfirm --needed - < /git/mdadm-encrypted-btrfs/packages_setup.txt
mv /git/mdadm-encrypted-btrfs/packages_post-install.txt /packages_post-install.txt
chmod 644 /packages_post-install.txt

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
sed -i 's/ALLOW_GROUPS=""/ALLOW_GROUPS="sudo"/;s/TIMELINE_LIMIT_HOURLY="10"/TIMELINE_LIMIT_HOURLY="5"/;s/TIMELINE_LIMIT_DAILY="10"/TIMELINE_LIMIT_DAILY="7"/;s/TIMELINE_LIMIT_MONTHLY="10"/TIMELINE_LIMIT_MONTHLY="0"/;s/TIMELINE_LIMIT_YEARLY="10"/TIMELINE_LIMIT_YEARLY="0"/' /usr/share/snapper/config-templates/default
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

# Configure $SYSUSER
chmod +x /git/mdadm-encrypted-btrfs/sysuser-setup.sh

## sudo
echo "%sudo ALL=(ALL:ALL) /usr/bin/mkarchroot" > /etc/sudoers.d/sudo
echo "%sudo ALL=(ALL:ALL) /usr/bin/makechrootpkg" > /etc/sudoers.d/sudo

## opendoas
mv /git/mdadm-encrypted-btrfs/etc/doas.conf /etc/
chown -c root:root /etc/doas.conf
chmod -c 0400 /etc/doas.conf
sed -i 's/#PACMAN_AUTH=.*/PACMAN_AUTH=(doas)/' /etc/makepkg.conf

su -c '/git/mdadm-encrypted-btrfs/sysuser-setup.sh' "$SYSUSER"

# Configure symlinks
mv /git/mdadm-encrypted-btrfs/usr/bin/* /usr/bin/
ln -s /usr/bin/nvim /usr/bin/edit
ln -s /usr/bin/nvim /usr/bin/vedit
ln -s /usr/bin/nvim /usr/bin/vi
ln -s /usr/bin/nvim /usr/bin/vim
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
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/;s/#de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/;s/#fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/;s/#nl_NL.UTF-8 UTF-8/nl_NL.UTF-8 UTF-8/' /etc/locale.gen
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

# Configure pacman hooks in /etc/pacman.d/hooks
mv /git/mdadm-encrypted-btrfs/etc/pacman.d/hooks /etc/pacman.d/
chmod -R 755 /etc/pacman.d/hooks
chmod 644 /etc/pacman.d/hooks/*.hook
chmod 744 /etc/pacman.d/hooks/scripts/*.sh

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
pacman -Qq "nvidia-utils" &&
systemctl enable nvidia-resume.service &&
nvidia-xconfig

# Configure /etc/mkinitcpio.conf
sed -i 's/MODULES=()/MODULES=(btrfs)/;s/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect keyboard keymap consolefont modconf block mdadm_udev encrypt filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

# Configure /etc/default/grub and /boot/grub/grub.cfg
UUID="$(blkid -s UUID -o value /dev/md/md0)"
sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\"/GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet cryptdevice=UUID=$UUID:md0_crypt root=\/dev\/mapper\/md0_crypt video=$GRUBRESOLUTION\"/" /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# FIXME: Enable some systemd services later because of grub-install ERROR:
  # Detecting snapshots ...
  # mount: /tmp/grub-btrfs.<...>: special device /dev/disk/by-uuid/<UUID of /dev/mapper/md0_crypt> does not exist.
systemctl enable snapper-timeline.timer
systemctl enable snapper-cleanup.timer

# Remove repo
rm -rf /git
