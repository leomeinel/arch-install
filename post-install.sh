#!/bin/sh

KEYMAP="de-latin1"
KEYLAYOUT="de"

# Fail on error
set -e

# Configure custom-bootbackup.sh
doas sh -c '{
  DISK1P1_UUID="$(lsblk -rno LABEL,MOUNTPOINT,UUID | grep "BOOT /boot" | sed "s/BOOT \/boot//" | tr -d "[:space:]")"
  DISK2P1_UUID="$(lsblk -rno LABEL,MOUNTPOINT,UUID | grep "BOOT  " | sed "s/BOOT  //" | tr -d "[:space:]")"
  echo "#!/bin/sh"
  echo ""
  echo "/usr/bin/rsync -aq --delete --mkpath /.boot.bak/ /.boot.bak.old"
  echo "/usr/bin/rsync -aq --delete --mkpath /boot/ /.boot.bak"
  echo "if /usr/bin/mountpoint -q /boot"
  echo "then"
  echo "  /usr/bin/umount -AR /boot"
  echo "fi"
  echo "/usr/bin/mount UUID=$DISK2P1_UUID /boot"
  echo "/usr/bin/rsync -aq --delete --mkpath /.boot.bak/ /boot"
  echo "/usr/bin/umount /boot"
  echo "/usr/bin/mount UUID=$DISK1P1_UUID /boot"
} > /etc/pacman.d/hooks/scripts/custom-bootbackup.sh'
doas chmod 744 /etc/pacman.d/hooks/scripts/*.sh

# Configure clock
doas timedatectl set-ntp true

# Configure $KEYMAP
doas localectl set-keymap "$KEYMAP"
doas localectl set-x11-keymap "$KEYLAYOUT"

# Install paru
git clone https://aur.archlinux.org/paru.git ~/git/paru
cd ~/git/paru
makepkg -sri --noprogressbar --noconfirm --needed

# Configure paru.conf
doas sed -i 's/^#Chroot/Chroot/;s/^#LocalRepo/LocalRepo/;s/^#RemoveMake/RemoveMake/;s/^#CleanAfter/CleanAfter/;s/^#\[bin\]/\[bin\]/;s/^#FileManager =.*/FileManager = nvim/;s/^#Sudo =.*/Sudo = doas/' /etc/paru.conf
doas sh -c 'echo FileManagerFlags = '"\'"'-c,\"NvimTreeFocus\"'"\'"' >> /etc/paru.conf'

# Install packages
paru -S --noprogressbar --noconfirm --needed - < ~/packages_post-install.txt
paru --noprogressbar --noconfirm -Syu
paru -Scc

# Configure iptables
## FIXME: Replace with nftables

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
doas iptables -F
doas iptables -X

### Set up new chains
doas iptables -L | grep -q "Chain INPUT" ||
doas iptables -N INPUT
doas iptables -L | grep -q "Chain FORWARD" ||
doas iptables -N FORWARD
doas iptables -L | grep -q "Chain OUTPUT" ||
doas iptables -N OUTPUT

### Allow all connections on all chains to start
doas iptables -P INPUT ACCEPT
doas iptables -P FORWARD ACCEPT
doas iptables -P OUTPUT ACCEPT

### ACCEPT LOOPBACK
doas iptables -A INPUT -i lo -j ACCEPT

### FIRST PACKET HAS TO BE TCP SYN
doas iptables -A INPUT -p tcp ! --syn -m state --state NEW -j DROP

### DROP ALL INVALID PACKETS
doas iptables -A INPUT -m state --state INVALID -j DROP
doas iptables -A FORWARD -m state --state INVALID -j DROP
doas iptables -A OUTPUT -m state --state INVALID -j DROP

### Block packets with bogus TCP flags
doas iptables -A INPUT -p tcp --tcp-flags FIN,SYN FIN,SYN -j DROP
doas iptables -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
doas iptables -A INPUT -p tcp --tcp-flags FIN,RST FIN,RST -j DROP
doas iptables -A INPUT -p tcp --tcp-flags FIN,ACK FIN -j DROP
doas iptables -A INPUT -p tcp --tcp-flags ACK,URG URG -j DROP
doas iptables -A INPUT -p tcp --tcp-flags ACK,PSH PSH -j DROP

### Drop NULL packets
doas iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP

### DROP XMAS PACKETS
doas iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP

### DROP EXCESSIVE TCP RST PACKETS
doas iptables -A INPUT -p tcp --tcp-flags RST RST -m limit --limit 2/s --limit-burst 2 -j ACCEPT
doas iptables -A INPUT -p tcp --tcp-flags RST RST -j DROP

### DROP SYN-FLOOD PACKETS
doas iptables -A INPUT -p tcp -m state --state NEW -m limit --limit 2/second --limit-burst 2 -j ACCEPT
doas iptables -A INPUT -p tcp -m state --state NEW -j DROP

### Drop fragments
doas iptables -A INPUT -f -j DROP
doas iptables -A FORWARD -f -j DROP
doas iptables -A OUTPUT -f -j DROP

### Drop SYN packets with suspicious MSS value
doas iptables -A INPUT -p tcp -m state --state NEW -m tcpmss ! --mss 536:65535 -j DROP

### Block spoofed packets
doas iptables -A INPUT -s 127.0.0.0/8 ! -i lo -j DROP

### Drop ICMP
doas iptables -A INPUT -p icmp -j DROP

### Allow default ktorrent ports (Forard them if not using UPnP)
doas iptables -A INPUT -p tcp --dport 6881 -j ACCEPT
doas iptables -A INPUT -p udp --dport 7881 -j ACCEPT
doas iptables -A INPUT -p udp --dport 8881 -j ACCEPT

### ALLOW ESTABLISHED CONNECTIONS
doas iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

### Set default policies for chains
doas iptables -P INPUT DROP
doas iptables -P FORWARD ACCEPT
doas iptables -P OUTPUT ACCEPT

## ipv6

### Flush and delete all chains
doas ip6tables -F
doas ip6tables -X

### Set up new chains
doas ip6tables -L | grep -q "Chain INPUT" ||
doas ip6tables -N INPUT
doas ip6tables -L | grep -q "Chain INPUT" ||
doas ip6tables -N FORWARD
doas ip6tables -L | grep -q "Chain INPUT" ||
doas ip6tables -N OUTPUT

### Allow all connections on all chains to start
doas ip6tables -P INPUT ACCEPT
doas ip6tables -P FORWARD ACCEPT
doas ip6tables -P OUTPUT ACCEPT

### ACCEPT LOOPBACK
doas ip6tables -A INPUT -i lo -j ACCEPT

### FIRST PACKET HAS TO BE TCP SYN
doas ip6tables -A INPUT -p tcp ! --syn -m state --state NEW -j DROP

### DROP ALL INVALID PACKETS
doas ip6tables -A INPUT -m state --state INVALID -j DROP
doas ip6tables -A FORWARD -m state --state INVALID -j DROP
doas ip6tables -A OUTPUT -m state --state INVALID -j DROP

### Block packets with bogus TCP flags
doas ip6tables -A INPUT -p tcp --tcp-flags FIN,SYN FIN,SYN -j DROP
doas ip6tables -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
doas ip6tables -A INPUT -p tcp --tcp-flags FIN,RST FIN,RST -j DROP
doas ip6tables -A INPUT -p tcp --tcp-flags FIN,ACK FIN -j DROP
doas ip6tables -A INPUT -p tcp --tcp-flags ACK,URG URG -j DROP
doas ip6tables -A INPUT -p tcp --tcp-flags ACK,PSH PSH -j DROP

### Drop NULL packets
doas ip6tables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP

### DROP XMAS PACKETS
doas ip6tables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP

### DROP EXCESSIVE TCP RST PACKETS
doas ip6tables -A INPUT -p tcp --tcp-flags RST RST -m limit --limit 2/s --limit-burst 2 -j ACCEPT
doas ip6tables -A INPUT -p tcp --tcp-flags RST RST -j DROP

### DROP SYN-FLOOD PACKETS
doas ip6tables -A INPUT -p tcp -m state --state NEW -m limit --limit 2/second --limit-burst 2 -j ACCEPT
doas ip6tables -A INPUT -p tcp -m state --state NEW -j DROP

### Drop fragments
doas ip6tables -A INPUT -m frag -j DROP
doas ip6tables -A FORWARD -m frag -j DROP
doas ip6tables -A OUTPUT -m frag -j DROP

### Drop SYN packets with suspicious MSS value
doas ip6tables -A INPUT -p tcp -m state --state NEW -m tcpmss ! --mss 536:65535 -j DROP

### Block spoofed packets
doas ip6tables -A INPUT -s ::1/128 ! -i lo -j DROP

### Drop ICMP
doas ip6tables -A INPUT -p icmp -j DROP

### Allow default ktorrent ports (Forard them if not using UPnP)
doas ip6tables -A INPUT -p tcp --dport 6881 -j ACCEPT
doas ip6tables -A INPUT -p udp --dport 7881 -j ACCEPT
doas ip6tables -A INPUT -p udp --dport 8881 -j ACCEPT

### ALLOW ESTABLISHED CONNECTIONS
doas ip6tables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

### Set default policies for chains
doas ip6tables -P INPUT DROP
doas ip6tables -P FORWARD ACCEPT
doas ip6tables -P OUTPUT ACCEPT

### Save rules to /etc/iptables
doas sh -c 'iptables-save > /etc/iptables/iptables.rules'
doas sh -c 'ip6tables-save > /etc/iptables/ip6tables.rules'
doas chmod 644 /etc/iptables/*.rules

# Enable systemd services
doas systemctl enable laptop-mode.service
doas systemctl enable sddm
doas systemctl enable iptables
doas systemctl enable ip6tables

# Generate nvidia config if needed
pacman -Qq "nvidia-settings" &&
~/nvidia-install.sh

# Remove script
rm -f ~/post-install.sh
rm -f ~/packages_post-install.txt

# Remove repo
rm -rf ~/git
