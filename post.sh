#!/usr/bin/env bash
###
# File: post.sh
# Author: Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2025 Leopold Meinel & contributors
# SPDX ID: MIT
# URL: https://opensource.org/licenses/MIT
# -----
###

# Fail on error
set -e

# Source config
SCRIPT_DIR="$(dirname -- "$(readlink -f -- "${0}")")"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}"/install.conf

# Replace doas.conf with option nopass
DOAS_CONF="$(doas cat /etc/doas.conf)"
for i in {1..5}; do
    [[ "${i}" -eq 5 ]] &&
        {
            echo "ERROR: Too many retries. Exiting now."
            exit 1
        }
    doas /bin/sh -c 'echo "permit nopass setenv { LANG LC_ALL } :wheel" >/etc/doas.conf' && break ||
        echo "WARNING: You have entered an incorrect password. Retrying now."
done

# Configure KEYMAP
doas localectl --no-convert set-keymap "${KEYMAP}"
doas localectl --no-convert set-x11-keymap "${KEYLAYOUT}"

# Configure clock
doas timedatectl set-ntp true

# Set default java
doas archlinux-java set java-21-openjdk

# Configure nftables
# References
#
# https://networklessons.com/uncategorized/iptables-example-configuration
# https://linoxide.com/block-common-attacks-iptables/
# https://serverfault.com/questions/199421/how-to-prevent-ip-spoofing-within-iptables
# https://www.cyberciti.biz/tips/linux-iptables-10-how-to-block-common-attack.html
# https://javapipe.com/blog/iptables-ddos-protection/
# https://danielmiessler.com/study/iptables/
# https://inai.de/documents/Perfect_Ruleset.pdf
# https://unix.stackexchange.com/questions/108169/what-is-the-difference-between-m-conntrack-ctstate-and-m-state-state
# https://gist.github.com/jirutka/3742890
# https://www.ripe.net/publications/docs/ripe-431
# https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/security_guide/sect-security_guide-firewalls-malicious_software_and_spoofed_ip_addresses
#
## Flush & delete all chains
doas nft 'flush ruleset'
## ipv4
### Set up new tables
doas nft 'add table ip filter'
### Set up new chains
doas nft 'add chain ip filter input { type filter hook input priority 0; policy drop; }'
doas nft 'add chain ip filter forward { type filter hook forward priority 0; policy drop; }'
doas nft 'add chain ip filter output { type filter hook output priority 0; policy accept; }'
### Accept established connections
doas nft 'add rule ip filter input ct state related,established counter accept'
### Accept loopback
doas nft 'add rule ip filter input iifname "lo" counter accept'
### First packet has to be TCP SYN
doas nft 'add rule ip filter input tcp flags != syn / fin,syn,rst,ack ct state new counter drop'
### Drop all invalid packets
doas nft 'add rule ip filter input ct state invalid counter drop'
doas nft 'add rule ip filter forward ct state invalid counter drop'
doas nft 'add rule ip filter output ct state invalid counter drop'
### Drop packets with bogus TCP flags
doas nft 'add rule ip filter input tcp flags fin,syn / fin,syn counter drop'
doas nft 'add rule ip filter input tcp flags syn,rst / syn,rst counter drop'
doas nft 'add rule ip filter input tcp flags fin,rst / fin,rst counter drop'
doas nft 'add rule ip filter input tcp flags fin / fin,ack counter drop'
doas nft 'add rule ip filter input tcp flags urg / ack,urg counter drop'
doas nft 'add rule ip filter input tcp flags psh / psh,ack counter drop'
### Drop NULL packets
doas nft 'add rule ip filter input tcp flags 0x0 / fin,syn,rst,psh,ack,urg counter drop'
### Drop XMAS packets
doas nft 'add rule ip filter input tcp flags fin,syn,rst,psh,ack,urg / fin,syn,rst,psh,ack,urg counter drop'
### Drop fragments
doas nft 'add rule ip filter input ip frag-off & 0x1fff != 0 counter drop'
doas nft 'add rule ip filter forward ip frag-off & 0x1fff != 0 counter drop'
doas nft 'add rule ip filter output ip frag-off & 0x1fff != 0 counter drop'
### Drop SYN packets with suspicious MSS value
doas nft 'add rule ip filter input ip protocol tcp ct state new tcp option maxseg size != 536-65535 counter drop'
### Drop spoofed packets
doas nft 'add rule ip filter input iifname != "lo" ip saddr 127.0.0.0/8 counter drop'
### Drop ICMP
doas nft 'add rule ip filter input ip protocol icmp counter drop'
### Drop excessive TCP RST packets
doas nft 'add chain ip filter input_prerouting'
doas nft 'add rule ip filter input tcp flags rst limit rate 2/second burst 2 packets counter jump input_prerouting'
doas nft 'add rule ip filter input tcp flags rst counter drop'
### Drop SYN-FLOOD packets
doas nft 'add rule ip filter input ip protocol tcp ct state new limit rate 2/second burst 2 packets counter jump input_prerouting'
doas nft 'add rule ip filter input ip protocol tcp ct state new counter drop'
### Rate-limit UDP packets
doas nft 'add rule ip filter input ip protocol udp ct state new limit rate 2/second burst 2 packets counter jump input_prerouting'
doas nft 'add rule ip filter input ip protocol udp ct state new counter drop'
### Allow SSH from LOCAL_DOMAINS if it is enabled
LOCAL_DOMAINS="$(
    cat <<'EOF'
10.0.0.0/8
172.16.0.0/12
192.168.0.0/16
127.0.0.0/8
EOF
)"
[[ -n "${SYSUSER_PUBKEY}" ]] &&
    {
        for local_domain in $LOCAL_DOMAINS; do
            doas nft "add rule ip filter input_prerouting ip saddr $local_domain tcp dport 9122 counter accept"
        done
    }
doas nft 'add rule ip filter input_prerouting tcp dport 9122 counter drop'
### Accept interface virbr0 (input_prerouting)
doas nft 'add rule ip filter input_prerouting iifname "virbr0" udp dport 53 counter accept'
doas nft 'add rule ip filter input_prerouting iifname "virbr0" udp dport 67 counter accept'
### Accept SMTP
doas nft 'add rule ip filter input_prerouting tcp dport 25 counter accept'
doas nft 'add rule ip filter input_prerouting tcp dport 587 counter accept'
### Accept POP & POPS
doas nft 'add rule ip filter input_prerouting tcp dport 110 counter accept'
doas nft 'add rule ip filter input_prerouting tcp dport 995 counter accept'
### Accept IMAP & IMAPS
doas nft 'add rule ip filter input_prerouting tcp dport 143 counter accept'
doas nft 'add rule ip filter input_prerouting tcp dport 993 counter accept'
### Accept mDNS
doas nft 'add rule ip filter input_prerouting udp dport 5353 counter accept'
### Accept http & https (for wget)
doas nft 'add rule ip filter input_prerouting tcp dport 80 counter accept'
doas nft 'add rule ip filter input_prerouting tcp dport 443 counter accept'
### Accept Transmission
doas nft 'add rule ip filter input_prerouting udp dport 51413 counter accept'
### Accept custom wireguard
doas nft 'add rule ip filter input_prerouting udp dport 62990 counter accept'
### Accept interface virbr0 (forward)
doas nft 'add rule ip filter forward iifname "virbr0" counter accept'
doas nft 'add rule ip filter forward oifname "virbr0" counter accept'
## ipv6
### Set up new tables
doas nft 'add table ip6 filter'
### Set up new chains
doas nft 'add chain ip6 filter input { type filter hook input priority 0; policy drop; }'
doas nft 'add chain ip6 filter forward { type filter hook forward priority 0; policy drop; }'
doas nft 'add chain ip6 filter output { type filter hook output priority 0; policy accept; }'
### Accept established connections
doas nft 'add rule ip6 filter input ct state related,established counter accept'
### Accept loopback
doas nft 'add rule ip6 filter input iifname "lo" counter accept'
### First packet has to be TCP SYN
doas nft 'add rule ip6 filter input tcp flags != syn / fin,syn,rst,ack ct state new counter drop'
### Drop all invalid packets
doas nft 'add rule ip6 filter input ct state invalid counter drop'
doas nft 'add rule ip6 filter forward ct state invalid counter drop'
doas nft 'add rule ip6 filter output ct state invalid counter drop'
### Drop packets with bogus TCP flags
doas nft 'add rule ip6 filter input tcp flags fin,syn / fin,syn counter drop'
doas nft 'add rule ip6 filter input tcp flags syn,rst / syn,rst counter drop'
doas nft 'add rule ip6 filter input tcp flags fin,rst / fin,rst counter drop'
doas nft 'add rule ip6 filter input tcp flags fin / fin,ack counter drop'
doas nft 'add rule ip6 filter input tcp flags urg / ack,urg counter drop'
doas nft 'add rule ip6 filter input tcp flags psh / psh,ack counter drop'
### Drop NULL packets
doas nft 'add rule ip6 filter input tcp flags 0x0 / fin,syn,rst,psh,ack,urg counter drop'
### Drop XMAS packets
doas nft 'add rule ip6 filter input tcp flags fin,syn,rst,psh,ack,urg / fin,syn,rst,psh,ack,urg counter drop'
### Drop SYN packets with suspicious MSS value
doas nft 'add rule ip6 filter input meta l4proto tcp ct state new tcp option maxseg size != 536-65535 counter drop'
### Drop spoofed packets
doas nft 'add rule ip6 filter input iifname != "lo" ip6 saddr ::1 counter drop'
### Drop ICMP
doas nft 'add rule ip6 filter input meta l4proto icmp counter drop'
### Drop excessive TCP RST packets
doas nft 'add chain ip6 filter input_prerouting'
doas nft 'add rule ip6 filter input tcp flags rst limit rate 2/second burst 2 packets counter jump input_prerouting'
doas nft 'add rule ip6 filter input tcp flags rst counter drop'
### Drop SYN-FLOOD packets
doas nft 'add rule ip6 filter input meta l4proto tcp ct state new limit rate 2/second burst 2 packets counter jump input_prerouting'
doas nft 'add rule ip6 filter input meta l4proto tcp ct state new counter drop'
### Rate-limit UDP packets
doas nft 'add rule ip6 filter input meta l4proto udp ct state new limit rate 2/second burst 2 packets counter jump input_prerouting'
doas nft 'add rule ip6 filter input meta l4proto udp ct state new counter drop'
### Allow SSH from LOCAL_DOMAINS if it is enabled
LOCAL_DOMAINS="$(
    cat <<'EOF'
fe80::/10
::1
EOF
)"
[[ -n "${SYSUSER_PUBKEY}" ]] &&
    {
        for local_domain in $LOCAL_DOMAINS; do
            doas nft "add rule ip6 filter input_prerouting ip6 saddr $local_domain tcp dport 9122 counter accept"
        done
    }
doas nft 'add rule ip filter input_prerouting tcp dport 9122 counter drop'
### Accept interface virbr0 (input_prerouting)
doas nft 'add rule ip6 filter input_prerouting iifname "virbr0" udp dport 53 counter accept'
doas nft 'add rule ip6 filter input_prerouting iifname "virbr0" udp dport 67 counter accept'
### Accept SMTP
doas nft 'add rule ip6 filter input_prerouting tcp dport 25 counter accept'
doas nft 'add rule ip6 filter input_prerouting tcp dport 587 counter accept'
### Accept POP & POPS
doas nft 'add rule ip6 filter input_prerouting tcp dport 110 counter accept'
doas nft 'add rule ip6 filter input_prerouting tcp dport 995 counter accept'
### Accept IMAP & IMAPS
doas nft 'add rule ip6 filter input_prerouting tcp dport 143 counter accept'
doas nft 'add rule ip6 filter input_prerouting tcp dport 993 counter accept'
### Accept mDNS
doas nft 'add rule ip6 filter input_prerouting udp dport 5353 counter accept'
### Accept http & https (for wget)
doas nft 'add rule ip6 filter input_prerouting tcp dport 80 counter accept'
doas nft 'add rule ip6 filter input_prerouting tcp dport 443 counter accept'
### Accept Transmission
doas nft 'add rule ip6 filter input_prerouting udp dport 51413 counter accept'
### Accept custom wireguard
doas nft 'add rule ip6 filter input_prerouting udp dport 62990 counter accept'
### Accept interface virbr0 (forward)
doas nft 'add rule ip6 filter forward iifname "virbr0" counter accept'
doas nft 'add rule ip6 filter forward oifname "virbr0" counter accept'
### Save rules to /etc/nftables.conf
doas /bin/sh -c 'nft -s list ruleset >/etc/nftables.conf'

# Configure secureboot
# Prompt user
# This prompt prevents unwanted overrides of already enrolled keys
echo "INFO: To deploy your own keys, don't confirm the next prompt. Make sure the keys are already enrolled."
# shellcheck source=/dev/null
. /etc/cryptboot.conf
read -rp "Overwrite secureboot keys? (Type 'yes' in capital letters): " choice
case "${choice}" in
YES)
    rm -f ~/secureboot.sh
    if mountpoint -q /efi; then
        doas umount -AR /efi
    fi
    doas mount /efi
    doas cryptboot-efikeys create
    doas cryptboot-efikeys enroll "${EFI_KEYS_DIR:?}"/keys/PK.key "${EFI_KEYS_DIR:?}"/keys/KEK.key
    doas cryptboot systemd-boot-sign
    doas /bin/sh -c '{
        echo "uefi_secureboot_cert='\""${EFI_KEYS_DIR:?}"/keys\"'/db.crt"
        echo "uefi_secureboot_key='\""${EFI_KEYS_DIR:?}"/keys\"'/db.key"
    } >/etc/dracut.conf.d/50-arch-install-secureboot.conf'
    ;;
*)
    doas mkdir -p "${EFI_KEYS_DIR:?}"/keys
    doas chmod 700 "${EFI_KEYS_DIR:?}"/keys
    chmod 755 ~/secureboot.sh
    echo "WARNING: User aborted enrolling secureboot keys"
    echo "         Deploy your own keys in ${EFI_KEYS_DIR:?}/keys and run ~/secureboot.sh to sign your bootloader"
    ;;
esac

# Install nix
doas /bin/sh -c "sh <(curl -L https://nixos.org/nix/install) --daemon --yes --nix-extra-conf-file ${SCRIPT_DIR}/nix.conf"

# Configure dot-files
doas systemd-run -P --wait --user -M "${GUESTUSER}"@ /bin/sh -c '. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh && ~/dot-files.sh'
doas systemd-run -P --wait --user -M "${HOMEUSER}"@ /bin/sh -c '. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh && ~/dot-files.sh'
doas systemd-run -P --wait --system -E HOME=/root -M root@ /bin/sh -c '. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh && ~/dot-files.sh'
# shellcheck source=/dev/null
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh && ~/dot-files.sh
doas systemd-run -P --wait --user -M "${VIRTUSER}"@ /bin/sh -c '. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh && ~/dot-files.sh'
doas systemd-run -P --wait --user -M "${WORKUSER}"@ /bin/sh -c '. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh && ~/dot-files.sh'

# Source ~/.bash_profile
# shellcheck source=/dev/null
. ~/.bash_profile

# Install flatpaks
[[ -n "$(which flatpak)" ]] >/dev/null 2>&1 &&
    xargs -n 1 doas flatpak install --system -y --noninteractive <"${SCRIPT_DIR}/pkgs-flatpak.txt"

# Install paru-bin
git clone https://aur.archlinux.org/paru-bin.git ~/git/paru-bin
cd ~/git/paru-bin
makepkg -sri --noprogressbar --noconfirm --needed

# Configure paru.conf
doas /bin/sh -c '{
    echo ""
    echo "# arch-install"
    echo "Include = /etc/paru.conf.d/50-arch-install.conf"
} >>/etc/paru.conf'

# Clear package cache
paru -Scc
doas /bin/sh -c 'pacman -Qtdq | pacman -Rns -' || true

# Enable systemd services
pacman -Qq "nftables" >/dev/null 2>&1 &&
    doas systemctl enable nftables.service

# Remove user files
FILES=("dot-files.sh" "install.conf" "nix.conf" "pkgs-flatpak.txt" "post.sh" ".bash_history" ".nix-channels")
DIRS=(".gnupg" ".nix-defexpr" ".nix-profile" "git")
USERS=("${GUESTUSER}" "${HOMEUSER}" "root" "${SYSUSER}" "${VIRTUSER}" "${WORKUSER}")
for user in "${USERS[@]}"; do
    for file in "${FILES[@]}"; do
        doas rm -f "$(eval echo ~"${user}")"/"${file}"
    done
    for dir in "${DIRS[@]}"; do
        doas rm -rf "$(eval echo ~"${user}")"/"${dir}"
    done
    doas runuser -l "${user}" -c "rm -f ~/.*.bak"
done

# Set correct permissions on /nix/.snapshots; the install script also modifies the .snapshots dir
doas chown :wheel /nix/.snapshots

# Replace doas.conf with default
doas /bin/sh -c 'echo '"${DOAS_CONF}"' >/etc/doas.conf'

# Notify user if script has finished successfully
echo "INFO: $(basename "${0}") has finished successfully."
