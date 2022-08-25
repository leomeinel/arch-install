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
sudo iptables -F
sudo iptables -X

### Set up new chains
sudo iptables -L | grep -q "Chain INPUT" ||
sudo iptables -N INPUT
sudo iptables -L | grep -q "Chain FORWARD" ||
sudo iptables -N FORWARD
sudo iptables -L | grep -q "Chain OUTPUT" ||
sudo iptables -N OUTPUT

### Allow all connections on all chains to start
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT

### ACCEPT LOOPBACK
sudo iptables -A INPUT -i lo -j ACCEPT

### FIRST PACKET HAS TO BE TCP SYN
sudo iptables -A INPUT -p tcp ! --syn -m state --state NEW -j DROP

### DROP ALL INVALID PACKETS
sudo iptables -A INPUT -m state --state INVALID -j DROP
sudo iptables -A FORWARD -m state --state INVALID -j DROP
sudo iptables -A OUTPUT -m state --state INVALID -j DROP

### Block packets with bogus TCP flags
sudo iptables -A INPUT -p tcp --tcp-flags FIN,SYN FIN,SYN -j DROP
sudo iptables -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
sudo iptables -A INPUT -p tcp --tcp-flags FIN,RST FIN,RST -j DROP
sudo iptables -A INPUT -p tcp --tcp-flags FIN,ACK FIN -j DROP
sudo iptables -A INPUT -p tcp --tcp-flags ACK,URG URG -j DROP
sudo iptables -A INPUT -p tcp --tcp-flags ACK,PSH PSH -j DROP

### Drop NULL packets
sudo iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP

### DROP XMAS PACKETS
sudo iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP

### DROP EXCESSIVE TCP RST PACKETS
sudo iptables -A INPUT -p tcp --tcp-flags RST RST -m limit --limit 2/s --limit-burst 2 -j ACCEPT
sudo iptables -A INPUT -p tcp --tcp-flags RST RST -j DROP

### DROP SYN-FLOOD PACKETS
sudo iptables -A INPUT -p tcp -m state --state NEW -m limit --limit 2/second --limit-burst 2 -j ACCEPT
sudo iptables -A INPUT -p tcp -m state --state NEW -j DROP

### Drop fragments
sudo iptables -A INPUT -f -j DROP
sudo iptables -A FORWARD -f -j DROP
sudo iptables -A OUTPUT -f -j DROP

### Drop SYN packets with suspicious MSS value
sudo iptables -A INPUT -p tcp -m state --state NEW -m tcpmss ! --mss 536:65535 -j DROP

### Block spoofed packets
sudo iptables -A INPUT -s 224.0.0.0/3 -j DROP
sudo iptables -A INPUT -s 169.254.0.0/16 -j DROP
sudo iptables -A INPUT -s 172.16.0.0/12 -j DROP
sudo iptables -A INPUT -s 192.0.2.0/24 -j DROP
sudo iptables -A INPUT -s 192.168.0.0/16 -j DROP
sudo iptables -A INPUT -s 10.0.0.0/8 -j DROP
sudo iptables -A INPUT -s 0.0.0.0/8 -j DROP
sudo iptables -A INPUT -s 240.0.0.0/5 -j DROP
sudo iptables -A INPUT -s 127.0.0.0/8 ! -i lo -j DROP

### Drop ICMP
sudo iptables -A INPUT -p icmp -j DROP

### Allow default ktorrent ports (They still need to be forwarded)
sudo iptables -A INPUT -p tcp --dport 6881 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 7881 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 8881 -j ACCEPT

### ALLOW ESTABLISHED CONNECTIONS
sudo iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

### Set default policies for chains
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT

## ipv6

### Flush and delete all chains
sudo ip6tables -F
sudo ip6tables -X

### Set up new chains
sudo ip6tables -L | grep -q "Chain INPUT" ||
sudo ip6tables -N INPUT
sudo ip6tables -L | grep -q "Chain INPUT" ||
sudo ip6tables -N FORWARD
sudo ip6tables -L | grep -q "Chain INPUT" ||
sudo ip6tables -N OUTPUT

### Allow all connections on all chains to start
sudo ip6tables -P INPUT ACCEPT
sudo ip6tables -P FORWARD ACCEPT
sudo ip6tables -P OUTPUT ACCEPT

### ACCEPT LOOPBACK
sudo ip6tables -A INPUT -i lo -j ACCEPT

### FIRST PACKET HAS TO BE TCP SYN
sudo ip6tables -A INPUT -p tcp ! --syn -m state --state NEW -j DROP

### DROP ALL INVALID PACKETS
sudo ip6tables -A INPUT -m state --state INVALID -j DROP
sudo ip6tables -A FORWARD -m state --state INVALID -j DROP
sudo ip6tables -A OUTPUT -m state --state INVALID -j DROP

### Block packets with bogus TCP flags
sudo ip6tables -A INPUT -p tcp --tcp-flags FIN,SYN FIN,SYN -j DROP
sudo ip6tables -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
sudo ip6tables -A INPUT -p tcp --tcp-flags FIN,RST FIN,RST -j DROP
sudo ip6tables -A INPUT -p tcp --tcp-flags FIN,ACK FIN -j DROP
sudo ip6tables -A INPUT -p tcp --tcp-flags ACK,URG URG -j DROP
sudo ip6tables -A INPUT -p tcp --tcp-flags ACK,PSH PSH -j DROP

### Drop NULL packets
sudo ip6tables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP

### DROP XMAS PACKETS
sudo ip6tables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP

### DROP EXCESSIVE TCP RST PACKETS
sudo ip6tables -A INPUT -p tcp --tcp-flags RST RST -m limit --limit 2/s --limit-burst 2 -j ACCEPT
sudo ip6tables -A INPUT -p tcp --tcp-flags RST RST -j DROP

### DROP SYN-FLOOD PACKETS
sudo ip6tables -A INPUT -p tcp -m state --state NEW -m limit --limit 2/second --limit-burst 2 -j ACCEPT
sudo ip6tables -A INPUT -p tcp -m state --state NEW -j DROP

### Drop fragments
sudo ip6tables -A INPUT -m frag -j DROP
sudo ip6tables -A FORWARD -m frag -j DROP
sudo ip6tables -A OUTPUT -m frag -j DROP

### Drop SYN packets with suspicious MSS value
sudo ip6tables -A INPUT -p tcp -m state --state NEW -m tcpmss ! --mss 536:65535 -j DROP

### Block spoofed packets
### FIXME: This needs to be expanded
sudo ip6tables -A INPUT -s ::1/128 ! -i lo -j DROP

### Drop ICMP
sudo ip6tables -A INPUT -p icmp -j DROP

### Allow default ktorrent ports (They still need to be forwarded)
sudo ip6tables -A INPUT -p tcp --dport 6881 -j ACCEPT
sudo ip6tables -A INPUT -p udp --dport 7881 -j ACCEPT
sudo ip6tables -A INPUT -p udp --dport 8881 -j ACCEPT

### ALLOW ESTABLISHED CONNECTIONS
sudo ip6tables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

### Set default policies for chains
sudo ip6tables -P INPUT DROP
sudo ip6tables -P FORWARD ACCEPT
sudo ip6tables -P OUTPUT ACCEPT

### Save rules to /etc/iptables
sudo sh -c 'iptables-save > /etc/iptables/iptables.rules'
sudo sh -c 'ip6tables-save > /etc/iptables/ip6tables.rules'
sudo chmod -R 744 /etc/iptables

# Enable systemd services
sudo systemctl enable laptop-mode.service
sudo systemctl enable sddm
sudo systemctl enable iptables
sudo systemctl enable ip6tables

# Generate nvidia config if needed
pacman -Qq "nvidia-settings" &&
~/nvidia-install.sh &&
rm -f ~/nvidia-install.sh

# Remove script
rm -f ~/post-install.sh
rm -f ~/packages.txt
