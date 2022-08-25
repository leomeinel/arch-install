#!/bin/sh

KEYMAP="de-latin1"
KEYLAYOUT="de"

# Fail on error
set -e

# Configure clock
sudo timedatectl set-ntp true

# Configure $KEYMAP
sudo localectl set-keymap "$KEYMAP"
sudo localectl set-x11-keymap "$KEYLAYOUT"

# Install packages
{
  echo "librewolf-bin"
  echo "chromium-extension-web-store"
  echo "snap-pac-grub"
  echo "snapper-gui-git"
  echo "laptop-mode-tools"
  echo "macchina"
  echo "arc-kde-git"
  echo "papirus-icon-theme-stripped"
  echo "sddm-nordic-theme-git"
} > ~/packages.txt
paru -Sy --needed - < ~/packages.txt
paru -Scc
paru -Syu


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

# Enable systemd services
sudo systemctl enable laptop-mode.service
sudo systemctl enable sddm

# Generate nvidia config if needed
pacman -Qq "nvidia-settings" &&
~/nvidia-install.sh &&
rm -f ~/nvidia-install.sh

# Remove script
rm -f ~/post-install.sh
rm -f ~/packages.txt
