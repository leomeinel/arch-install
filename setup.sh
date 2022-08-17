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
  echo "EDITOR=\"vim\""
} >> /etc/environment

# Add groups and users
groupadd -r sudo
groupadd -r libvirt
useradd -m -G sudo,wheel "$SYSUSER"
useradd -m -G libvirt "$VIRTUSER"
useradd -m "$HOMEUSER"
useradd -m "$GUESTUSER"
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
sed -i 's/#Color/Color/;s/#ParallelDownloads = 5/ParallelDownloads = 10/;s/#CacheDir/CacheDir/' /etc/pacman.conf
{
  echo ""
  echo "[options]"
  echo "Include = /etc/pacman.d/repo/aur.conf"
} >> /etc/pacman.conf
mkdir -p /etc/pacman.d/repo
{
  echo "[options]"
  echo "CacheDir = /var/cache/aur/pkg"
  echo ""
  echo "[aur]"
  echo "SigLevel = PackageOptional DatabaseOptional"
  echo "Server = file:///var/lib/repo/aur"
} > /etc/pacman.d/repo/aur.conf
mkdir -p /var/cache/aur/pkg
mkdir -p /var/lib/repo/aur
repo-add /var/lib/repo/aur/aur.db.tar.gz

# Install packages
reflector --save /etc/pacman.d/mirrorlist --country $MIRRORCOUNTRIES --protocol https --latest 20 --sort rate
pacman -Sy --noprogressbar --noconfirm --needed plasma-desktop plasma-wayland-session kgpg dolphin gwenview kalendar kmail kompare okular print-manager spectacle plasma-pa krunner kvantum powerdevil kinfocenter power-profiles-daemon arc-gtk-theme kde-gtk-config cantarell-fonts otf-font-awesome bleachbit sddm sddm-kcm plasma-nm ksystemlog neofetch htop mpv libreoffice-still rxvt-unicode zram-generator virt-manager qemu-desktop libvirt edk2-ovmf dnsmasq pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber rustup grub grub-btrfs efibootmgr mtools inetutils bluez bluez-utils ethtool iw cups hplip alsa-utils openssh rsync acpi acpi_call openbsd-netcat nss-mdns acpid ntfs-3g notepadqq intellij-idea-community-edition jdk17-openjdk jdk-openjdk jdk11-openjdk mariadb screen gradle arch-audit ark noto-fonts snapper lrzip lzop p7zip unarchiver unrar devtools pam-u2f lshw man-db sbsigntools

# Change ownership of /var/lib/repo/aur to $SYSUSER
chown -R "$SYSUSER": /var/lib/repo/aur

# Set default java
archlinux-java set java-17-openjdk

# Add wallpapers to /usr/share/wallpapers/Custom/content
mkdir -p /usr/share/wallpapers/Custom/content
git clone https://github.com/LeoMeinel/wallpapers.git /git/wallpapers
mv /git/wallpapers/*.jpg /git/wallpapers/*.png /usr/share/wallpapers/Custom/content/
chmod -R 755 /usr/share/wallpapers/Custom

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
echo "%sudo ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/sudo
chmod +x /git/mdadm-encrypted-btrfs/sysuser-setup.sh
su -c '/git/mdadm-encrypted-btrfs/sysuser-setup.sh' "$SYSUSER"
sed -i 's/#LocalRepo/LocalRepo/;s/#Chroot/Chroot/;s/#RemoveMake/RemoveMake/;s/#CleanAfter/CleanAfter/;s/#\[bin\]/\[bin\]/;s/#FileManager = vifm/FileManager = vim/' /etc/paru.conf
echo "%sudo ALL=(ALL:ALL) ALL" > /etc/sudoers.d/sudo

# Configure /etc/sddm.conf.d/kde_settings.conf
mkdir /etc/sddm.conf.d
{
  echo "[Theme]"
  echo "Current=Nordic-darker"
} > /etc/sddm.conf.d/kde_settings.conf

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
{
  echo "[zram0]"
  echo "zram-size = ram / 2"
  echo "compression-algorithm = zstd"
} > /etc/systemd/zram-generator.conf

# Configure /etc/mdadm.conf
mdadm --detail --scan >> /etc/mdadm.conf

# Configure autobackup of /boot in /etc/pacman.d/hooks/custom-bootbackup.hook
# FIXME: Find a way to detect both possible boot partitions after the system is installed 100% reliably!
mkdir -p /etc/pacman.d/hooks/scripts
{
  echo "#!/bin/sh"
  echo ""
  echo "/usr/bin/rsync -a --delete /.boot.bak/* /.boot.bak.old/"
  echo "/usr/bin/rsync -a --delete /boot/* /.boot.bak/"
  echo "/usr/bin/umount /boot"
  echo "/usr/bin/mount PARTUUID=\"\$DISK2P1_PARTUUID\" /boot/"
  echo "/usr/bin/rsync -a --delete /.boot.bak/* /boot/"
  echo "/usr/bin/umount /boot"
  echo "/usr/bin/mount PARTUUID=\"\$DISK1P1_PARTUUID\" /boot"
} > /etc/pacman.d/hooks/scripts/custom-bootbackup.sh
{
  echo "[Trigger]"
  echo "Operation = Upgrade"
  echo "Operation = Install"
  echo "Operation = Remove"
  echo "Type = Path"
  echo "Target = usr/lib/modules/*/vmlinuz"
  echo ""
  echo "[Action]"
  echo "Depends = rsync"
  echo "Description = Backing up /boot..."
  echo "When = PostTransaction"
  echo "Exec = /bin/sh -c '/etc/pacman.d/hooks/scripts/custom-bootbackup.sh'"
} > /etc/pacman.d/hooks/custom-bootbackup.hook

# Configure autogen of list of explicitly installed packages in /etc/pacman.d/hooks/custom-pkglists.hook
{
  echo "#!/bin/sh"
  echo ""
  echo "/usr/bin/pacman -Qqen > /etc/pkglist_explicit.txt"
  echo "/usr/bin/pacman -Qqem > /etc/pkglist_foreign.txt"
  echo "/usr/bin/pacman -Qqd > /etc/pkglist_deps.txt"
} > /etc/pacman.d/hooks/scripts/custom-pkglists.sh
{
  echo "[Trigger]"
  echo "Operation = Install"
  echo "Operation = Remove"
  echo "Type = Package"
  echo "Target = *"
  echo ""
  echo "[Action]"
  echo "Description = Generating pkglists..."
  echo "When = PostTransaction"
  echo "Exec = /bin/sh -c '/etc/pacman.d/hooks/scripts/custom-pkglists.sh'"
} > /etc/pacman.d/hooks/custom-pkglists.hook
chmod -R 700 /etc/pacman.d/hooks/scripts

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
systemctl enable nftables
systemctl enable sddm
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
