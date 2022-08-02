#!/bin/sh

DISK1="vda"
DISK2="vdb"
SYSUSER="systux"
VIRTUSER="virt"
HOMEUSER="leo"
KEYMAP="de-latin1"
TIMEZONE="Europe/Paris"
HOSTNAME="tux-stellaris-15"
DOMAIN="meinel.dev"
MIRRORCOUNTRIES="France,Germany"
GRUBRESOLUTION="2560x1440"

pacman -Syu
pacman -S plasma-desktop plasma-wayland-session kgpg dolphin gwenview kalendar kmail kmix kompare ksystemlog okular print-manager spectacle sweeper sddm sddm-kcm plasma-nm neofetch htop mpv libreoffice-still rxvt-unicode chromium zram-generator virt-manager qemu-desktop libvirt edk2-ovmf dnsmasq iptables-nft pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber rustup grub grub-btrfs efibootmgr mtools inetutils bluez bluez-utils cups hplip alsa-utils openssh rsync reflector acpi acpi_call tlp qemu-arch-extra bridge-utils openbsd-netcat sof-firmware nss-mdns acpid ntfs-3g nvidia-settings
groupadd sudo
echo "%sudo ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/sudo
useradd -m -G sudo "$SYSUSER"
useradd -m -G libvirt "$VIRTUSER"
useradd -m "$HOMEUSER"
passwd root
passwd "$SYSUSER"
passwd "$VIRTUSER"
passwd "$HOMEUSER"
su -c '/git/mdadm-encrypted-btrfs/sysuser-setup.sh' "$SYSUSER"
mkdir /etc/sddm.conf.d
echo "[Theme]" > /etc/sddm.conf.d/kde_settings.conf
echo "Current=Sweet" >> /etc/sddm.conf.d/kde_settings.conf
echo "%sudo ALL=(ALL:ALL) ALL" > /etc/sudoers.d/sudo
cd /
ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
timedatectl set-ntp true
hwclock --systohc
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/#de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/#fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/' /etc/locale.gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
locale-gen
echo "--save /etc/pacman.d/mirrorlist" > /etc/xdg/reflector/reflector.conf
echo "--country $MIRRORCOUNTRIES" >> /etc/xdg/reflector/reflector.conf
echo "--protocol https" >> /etc/xdg/reflector/reflector.conf
echo "--latest 5" >> /etc/xdg/reflector/reflector.conf
echo "--sort age" /etc/pacman.d/mirrorlist >> /etc/xdg/reflector/reflector.conf
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1  localhost" > /etc/hosts
echo "127.0.1.1  $HOSTNAME.$DOMAIN	$HOSTNAME" >> /etc/hosts
echo "::1  ip6-localhost ip6-loopback" >> /etc/hosts
echo "ff02::1  ip6-allnodes" >> /etc/hosts
echo "ff02::2  ip6-allrouters" >> /etc/hosts
echo "[zram0]" > /etc/systemd/zram-generator.conf
echo "zram-size = ram / 2" >> /etc/systemd/zram-generator.conf
echo "compression-algorithm = zstd" >> /etc/systemd/zram-generator.conf
systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable cups
systemctl enable avahi-daemon
systemctl enable tlp
systemctl enable reflector
systemctl enable reflector.timer
systemctl enable fstrim.timer
systemctl enable libvirtd
systemctl enable acpid
systemctl enable nftables
systemctl enable sddm
sed -i 's/MODULES=()/MODULES=(btrfs)/' /etc/mkinitcpio.conf
sed -i 's/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect keyboard keymap consolefont modconf block mdadm_udev encrypt filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -p linux
UUID="$(blkid -s UUID -o value /dev/md/md0)"
sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\"/GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet cryptdevice=UUID=$UUID:md0_crypt root=\/dev\/mapper\/md0_crypt video=$GRUBRESOLUTION\"/" /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
cp -r /boot /boot.bak
umount /boot
mount /dev/"$DISK1"1 /boot
cp -r /boot.bak/* /boot/
umount /boot
mount /dev/"$DISK1"1 /boot
mdadm --detail --scan >> /etc/mdadm.conf
sed -i 's/name=archiso:0 //' /etc/mdadm.conf
rm -rf /git
