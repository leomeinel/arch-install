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
mkdir -p /etc/pacman.d/repo
mkdir -p /var/cache/aur/pkg
mkdir -p /var/lib/repo/aur
repo-add /var/lib/repo/aur/aur.db.tar.gz
{
  echo "[options]"
  echo "CacheDir = /var/cache/aur/pkg"
  echo ""
  echo "[aur]"
  echo "SigLevel = PackageOptional DatabaseOptional"
  echo "Server = file:///var/lib/repo/aur"
} > /etc/pacman.d/repo/aur.conf
mkdir -p /var/cache/home_ungoogled_chromium_Arch/pkg
curl -s 'https://download.opensuse.org/repositories/home:/ungoogled_chromium/Arch/x86_64/home_ungoogled_chromium_Arch.key' | sudo pacman-key -a -
{
  echo "[options]"
  echo "CacheDir = /var/cache/home_ungoogled_chromium_Arch/pkg"
  echo ""
  echo "[home_ungoogled_chromium_Arch]"
  echo "SigLevel = Required TrustAll"
  echo 'Server = https://download.opensuse.org/repositories/home:/ungoogled_chromium/Arch/$arch'
} > /etc/pacman.d/repo/home_ungoogled_chromium_Arch.conf
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
{
  echo "plasma-desktop"
  echo "plasma-wayland-session"
  echo "kgpg"
  echo "dolphin"
  echo "gwenview"
  echo "kalendar"
  echo "kmail"
  echo "kompare"
  echo "okular"
  echo "print-manager"
  echo "spectacle"
  echo "plasma-pa"
  echo "krunner"
  echo "powerdevil"
  echo "kinfocenter"
  echo "power-profiles-daemon"
  echo "plasma-nm"
  echo "wmctrl"
  echo "kde-gtk-config"
  echo "arc-gtk-theme"
  echo "cantarell-fonts"
  echo "ttf-nerd-fonts-symbols-mono"
  echo "sddm"
  echo "sddm-kcm"
  echo "ksystemlog"
  echo "bleachbit"
  echo "htop"
  echo "mpv"
  echo "libreoffice-still"
  echo "alacritty"
  echo "zram-generator"
  echo "virt-manager"
  echo "qemu-desktop"
  echo "libvirt"
  echo "edk2-ovmf"
  echo "dnsmasq"
  echo "pipewire"
  echo "pipewire-alsa"
  echo "pipewire-pulse"
  echo "pipewire-jack"
  echo "wireplumber"
  echo "rustup"
  echo "grub"
  echo "grub-btrfs"
  echo "efibootmgr"
  echo "mtools"
  echo "inetutils"
  echo "bluez"
  echo "bluez-utils"
  echo "ethtool"
  echo "iw"
  echo "cups"
  echo "hplip"
  echo "alsa-utils"
  echo "openssh"
  echo "rsync"
  echo "acpi"
  echo "acpi_call"
  echo "openbsd-netcat"
  echo "nss-mdns"
  echo "acpid"
  echo "ntfs-3g"
  echo "intellij-idea-community-edition"
  echo "jdk11-openjdk"
  echo "jdk17-openjdk"
  echo "jdk-openjdk"
  echo "mariadb"
  echo "screen"
  echo "gradle"
  echo "arch-audit"
  echo "ark"
  echo "noto-fonts"
  echo "snapper"
  echo "lrzip"
  echo "lzop"
  echo "p7zip"
  echo "unarchiver"
  echo "unrar"
  echo "devtools"
  echo "pam-u2f"
  echo "lshw"
  echo "man-db"
  echo "sbsigntools"
  echo "bat"
  echo "exa"
  echo "ripgrep"
  echo "fd"
  echo "dust"
  echo "procs"
  echo "tokei"
  echo "grex"
  echo "git-delta"
  echo "hyperfine"
  echo "starship"
  echo "notepadqq"
  echo "mathjax2"
  echo "xclip"
  echo "wl-clipboard"
  echo "ungoogled-chromium"
  echo "gimp"
  echo "sshfs"
  echo "jpegoptim"
  echo "oxipng"
  echo "lldb"
  echo "quilt"
  echo "make"
  echo "automake"
  echo "gcc"
} > /git/packages.txt
pacman -Sy --noprogressbar --noconfirm --needed - < /git/packages.txt

# Change ownership of /var/lib/repo/aur to $SYSUSER
chown -R "$SYSUSER": /var/lib/repo/aur

# Configure nftables
mv /git/mdadm-encrypted-btrfs/nftables.conf /etc/nftables.conf
chmod 744 /etc/nftables.conf

# Configure iptables-nft

##
## References
## https://networklessons.com/uncategorized/iptables-example-configuration
## https://linoxide.com/block-common-attacks-iptables/
## https://serverfault.com/questions/199421/how-to-prevent-ip-spoofing-within-iptables
## https://www.cyberciti.biz/tips/linux-iptables-10-how-to-block-common-attack.html
## https://javapipe.com/blog/iptables-ddos-protection/
## https://danielmiessler.com/study/iptables/
## https://inai.de/documents/Perfect_Ruleset.pdf
## https://unix.stackexchange.com/questions/108169/what-is-the-difference-between-m-conntrack-ctstate-and-m-state-state
## https://gist.github.com/jirutka/3742890
## https://www.ripe.net/publications/docs/ripe-431
## https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/security_guide/sect-security_guide-firewalls-malicious_software_and_spoofed_ip_addresses
##

## ipv4

### Flush and delete all chains
iptables -F
iptables -X

### Set up new chains
iptables -L | grep -q "Chain INPUT" ||
iptables -N INPUT
iptables -L | grep -q "Chain INPUT" ||
iptables -N FORWARD
iptables -L | grep -q "Chain INPUT" ||
iptables -N OUTPUT

### Allow all connections on all chains to start
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

### ACCEPT LOOPBACK
iptables -A INPUT -i lo -j ACCEPT

### FIRST PACKET HAS TO BE TCP SYN
iptables -A INPUT -p tcp ! --syn -m state --state NEW -j DROP

### DROP ALL INVALID PACKETS
iptables -A INPUT -m state --state INVALID -j DROP
iptables -A FORWARD -m state --state INVALID -j DROP
iptables -A OUTPUT -m state --state INVALID -j DROP

### Block packets with bogus TCP flags
iptables -A INPUT -p tcp --tcp-flags FIN,SYN FIN,SYN -j DROP
iptables -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
iptables -A INPUT -p tcp --tcp-flags FIN,RST FIN,RST -j DROP
iptables -A INPUT -p tcp --tcp-flags FIN,ACK FIN -j DROP
iptables -A INPUT -p tcp --tcp-flags ACK,URG URG -j DROP
iptables -A INPUT -p tcp --tcp-flags ACK,PSH PSH -j DROP

### Drop NULL packets
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP

### DROP XMAS PACKETS
iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP

### DROP EXCESSIVE TCP RST PACKETS
iptables -A INPUT -p tcp --tcp-flags RST RST -m limit --limit 2/s --limit-burst 2 -j ACCEPT
iptables -A INPUT -p tcp --tcp-flags RST RST -j DROP

### DROP SYN-FLOOD PACKETS
iptables -A INPUT -p tcp -m state --state NEW -m limit --limit 2/second --limit-burst 2 -j ACCEPT
iptables -A INPUT -p tcp -m state --state NEW -j DROP

### Drop fragments
iptables -A INPUT -f -j DROP
iptables -A FORWARD -f -j DROP
iptables -A OUTPUT -f -j DROP

### Drop SYN packets with suspicious MSS value
iptables -A INPUT -p tcp -m state --state NEW -m tcpmss ! --mss 536:65535 -j DROP

### Block spoofed packets
iptables -A INPUT -s 224.0.0.0/3 -j DROP
iptables -A INPUT -s 169.254.0.0/16 -j DROP
iptables -A INPUT -s 172.16.0.0/12 -j DROP
iptables -A INPUT -s 192.0.2.0/24 -j DROP
iptables -A INPUT -s 192.168.0.0/16 -j DROP
iptables -A INPUT -s 10.0.0.0/8 -j DROP
iptables -A INPUT -s 0.0.0.0/8 -j DROP
iptables -A INPUT -s 240.0.0.0/5 -j DROP
iptables -A INPUT -s 127.0.0.0/8 ! -i lo -j DROP

### Drop ICMP
iptables -A INPUT -p icmp -j DROP

### ALLOW ESTABLISHED CONNECTIONS
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

### Set default policies for chains
iptables -P INPUT DROP
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

## ipv6

### Flush and delete all chains
ip6tables -F
ip6tables -X

### Set up new chains
ip6tables -L | grep -q "Chain INPUT" ||
ip6tables -N INPUT
ip6tables -L | grep -q "Chain INPUT" ||
ip6tables -N FORWARD
ip6tables -L | grep -q "Chain INPUT" ||
ip6tables -N OUTPUT

### Allow all connections on all chains to start
ip6tables -P INPUT ACCEPT
ip6tables -P FORWARD ACCEPT
ip6tables -P OUTPUT ACCEPT

### ACCEPT LOOPBACK
ip6tables -A INPUT -i lo -j ACCEPT

### FIRST PACKET HAS TO BE TCP SYN
ip6tables -A INPUT -p tcp ! --syn -m state --state NEW -j DROP

### DROP ALL INVALID PACKETS
ip6tables -A INPUT -m state --state INVALID -j DROP
ip6tables -A FORWARD -m state --state INVALID -j DROP
ip6tables -A OUTPUT -m state --state INVALID -j DROP

### Block packets with bogus TCP flags
ip6tables -A INPUT -p tcp --tcp-flags FIN,SYN FIN,SYN -j DROP
ip6tables -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
ip6tables -A INPUT -p tcp --tcp-flags FIN,RST FIN,RST -j DROP
ip6tables -A INPUT -p tcp --tcp-flags FIN,ACK FIN -j DROP
ip6tables -A INPUT -p tcp --tcp-flags ACK,URG URG -j DROP
ip6tables -A INPUT -p tcp --tcp-flags ACK,PSH PSH -j DROP

### Drop NULL packets
ip6tables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP

### DROP XMAS PACKETS
ip6tables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP

### DROP EXCESSIVE TCP RST PACKETS
ip6tables -A INPUT -p tcp --tcp-flags RST RST -m limit --limit 2/s --limit-burst 2 -j ACCEPT
ip6tables -A INPUT -p tcp --tcp-flags RST RST -j DROP

### DROP SYN-FLOOD PACKETS
ip6tables -A INPUT -p tcp -m state --state NEW -m limit --limit 2/second --limit-burst 2 -j ACCEPT
ip6tables -A INPUT -p tcp -m state --state NEW -j DROP

### Drop fragments
ip6tables -A INPUT -m frag -j DROP
ip6tables -A FORWARD -m frag -j DROP
ip6tables -A OUTPUT -m frag -j DROP

### Drop SYN packets with suspicious MSS value
ip6tables -A INPUT -p tcp -m state --state NEW -m tcpmss ! --mss 536:65535 -j DROP

### Block spoofed packets
### FIXME: This needs to be expanded
ip6tables -A INPUT -s ::1/128 ! -i lo -j DROP

### Drop ICMP
ip6tables -A INPUT -p icmp -j DROP

### ALLOW ESTABLISHED CONNECTIONS
ip6tables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

### Set default policies for chains
ip6tables -P INPUT DROP
ip6tables -P FORWARD ACCEPT
ip6tables -P OUTPUT ACCEPT

### Save rules to /etc/iptables
iptables-save > /etc/iptables/iptables.rules
ip6tables-save > /etc/iptables/ip6tables.rules
chmod -R 744 /etc/iptables

# Configure symlinks
{
  echo '#!/bin/sh'
  echo ''
  echo 'exec nvim -e "$@"'
} > /usr/bin/ex
{
  echo '#!/bin/sh'
  echo ''
  echo 'exec nvim -R "$@"'
} > /usr/bin/view
{
  echo '#!/bin/sh'
  echo ''
  echo 'exec nvim -d "$@"'
} > /usr/bin/vimdiff
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

# Set default java
archlinux-java set java-17-openjdk

# Add wallpapers to /usr/share/wallpapers/Custom/content
mkdir -p /usr/share/wallpapers/Custom/content
git clone https://github.com/LeoMeinel/wallpapers.git /git/wallpapers
mv /git/wallpapers/*.jpg /git/wallpapers/*.png /usr/share/wallpapers/Custom/content/
chmod -R 755 /usr/share/wallpapers/Custom

# Add screenshot folder to /usr/share/screenshots/
mkdir /usr/share/screenshots
chmod -R 777 /usr/share/screenshots

# Add gruvbox.yml to /usr/share/gruvbox/gruvbox.yml
mkdir /usr/share/gruvbox
mv /git/mdadm-encrypted-btrfs/gruvbox.yml /usr/share/gruvbox/
chmod -R 755 /usr/share/gruvbox

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
sed -i 's/#Chroot/Chroot/;s/#\[bin\]/\[bin\]/;s/#FileManager = vifm/FileManager=nvim/;s/#LocalRepo/LocalRepo/;s/#RemoveMake/RemoveMake/;s/#CleanAfter/CleanAfter/' /etc/paru.conf
echo "FileManagerFlags = '-c,\"NvimTreeFocus\"'" >> /etc/paru.conf
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
mkdir -p /etc/pacman.d/hooks/scripts
{
  echo '#!/bin/sh'
  echo ''
  echo '/usr/bin/rsync -a --delete /.boot.bak/* /.boot.bak.old/'
  echo '/usr/bin/rsync -a --delete /boot/* /.boot.bak/'
  echo '/usr/bin/umount /boot'
  echo '/usr/bin/mount PARTUUID="$DISK2P1_PARTUUID" /boot/'
  echo '/usr/bin/rsync -a --delete /.boot.bak/* /boot/'
  echo '/usr/bin/umount /boot'
  echo '/usr/bin/mount PARTUUID="$DISK1P1_PARTUUID" /boot'
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

# Configure logging installed packages from /etc/pacman.d/hooks/custom-pkglists.hook
{
  echo '#!/bin/sh'
  echo ''
  echo '/usr/bin/pacman -Qqen > /var/log/pkglist_explicit.pacman.log'
  echo '/usr/bin/chmod 644 /var/log/pkglist_explicit.pacman.log'
  echo '/usr/bin/pacman -Qqem > /var/log/pkglist_foreign.pacman.log'
  echo '/usr/bin/chmod 644 /var/log/pkglist_foreign.pacman.log'
  echo '/usr/bin/pacman -Qqd > /var/log/pkglist_deps.pacman.log'
  echo '/usr/bin/chmod 644 /var/log/pkglist_deps.pacman.log'
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

# Configure logging orphans from /etc/pacman.d/hooks/custom-log-orphans.hook
{
  echo '#!/bin/sh'
  echo 'pkgs="$(pacman -Qtdq)"'
  echo '[ -n "$pkgs" ] &&'
  echo '/usr/bin/echo "The following packages are installed but not required (anymore):"'
  echo '/usr/bin/echo "$pkgs"'
  echo '/usr/bin/echo "You can remove them all using '"'"'pacman -Qtdq | pacman -Rns -'"'"'"'
} > /etc/pacman.d/hooks/scripts/custom-log-orphans.sh
{
  echo "[Trigger]"
  echo "Operation = Install"
  echo "Operation = Upgrade"
  echo "Operation = Remove"
  echo "Type = Package"
  echo "Target = *"
  echo ""
  echo "[Action]"
  echo "Description = Logging orphans..."
  echo "When = PostTransaction"
  echo "Exec = /bin/sh -c '/etc/pacman.d/hooks/scripts/custom-log-orphans.sh'"
} > /etc/pacman.d/hooks/custom-log-orphans.hook
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
systemctl enable iptables
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
