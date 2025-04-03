#!/usr/bin/env bash
###
# File = post.sh
# Author = Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2025 Leopold Meinel & contributors
# SPDX ID = MIT
# URL = https://opensource.org/licenses/MIT
# -----
###

# Fail on error
set -e

# Define functions
log_err() {
    /usr/bin/logger -s -p local0.err <<<"$(basename "${0}"): ${*}"
}
log_warning() {
    /usr/bin/logger -s -p local0.warning <<<"$(basename "${0}"): ${*}"
}
var_invalid_err_exit() {
    log_err "'${1}' is invalid in '${2}'."
    exit 1
}

# Source config
SCRIPT_DIR="$(dirname -- "$(readlink -f -- "${0}")")"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}"/install.conf

# Replace doas.conf with option nopass
DOAS_CONF="$(doas cat /etc/doas.conf)"
for i in {1..5}; do
    [[ "${i}" -eq 5 ]] &&
        {
            log_err "Too many retries."
            exit 1
        }
    if doas /bin/sh -c 'echo "permit nopass setenv { LANG LC_ALL } :wheel" >/etc/doas.conf'; then
        break
    else
        log_warning "You have entered an incorrect password. Retrying now."
    fi
done

# Configure KEYMAP
doas localectl --no-convert set-keymap "${KEYMAP}"

# Configure clock
doas timedatectl set-ntp true

# Configure nftables
# FIXME: I'm almost certain that netavark/podman do not support nftables.
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
### Accept established connections on NETAVARK_FORWARD
doas nft 'add chain ip filter NETAVARK_FORWARD'
doas nft 'add rule ip filter NETAVARK_FORWARD ip daddr 10.88.0.0/16 ct state related,established counter accept'
### First packet has to be TCP SYN
doas nft 'add rule ip filter input tcp flags != syn / fin,syn,rst,ack ct state new counter drop'
doas nft 'add rule ip filter NETAVARK_FORWARD tcp flags != syn / fin,syn,rst,ack ct state new counter drop'
### Drop all invalid packets
doas nft 'add rule ip filter input ct state invalid counter drop'
doas nft 'add rule ip filter forward ct state invalid counter drop'
doas nft 'add rule ip filter NETAVARK_FORWARD ct state invalid counter drop'
doas nft 'add rule ip filter output ct state invalid counter drop'
### Drop packets with bogus TCP flags
doas nft 'add rule ip filter input tcp flags fin,syn / fin,syn counter drop'
doas nft 'add rule ip filter input tcp flags syn,rst / syn,rst counter drop'
doas nft 'add rule ip filter input tcp flags fin,rst / fin,rst counter drop'
doas nft 'add rule ip filter input tcp flags fin / fin,ack counter drop'
doas nft 'add rule ip filter input tcp flags urg / ack,urg counter drop'
doas nft 'add rule ip filter input tcp flags psh / psh,ack counter drop'
doas nft 'add rule ip filter NETAVARK_FORWARD tcp flags fin,syn / fin,syn counter drop'
doas nft 'add rule ip filter NETAVARK_FORWARD tcp flags syn,rst / syn,rst counter drop'
doas nft 'add rule ip filter NETAVARK_FORWARD tcp flags fin,rst / fin,rst counter drop'
doas nft 'add rule ip filter NETAVARK_FORWARD tcp flags fin / fin,ack counter drop'
doas nft 'add rule ip filter NETAVARK_FORWARD tcp flags urg / ack,urg counter drop'
doas nft 'add rule ip filter NETAVARK_FORWARD tcp flags psh / psh,ack counter drop'
### Drop NULL packets
doas nft 'add rule ip filter input tcp flags 0x0 / fin,syn,rst,psh,ack,urg counter drop'
doas nft 'add rule ip filter NETAVARK_FORWARD tcp flags 0x0 / fin,syn,rst,psh,ack,urg counter drop'
### Drop XMAS packets
doas nft 'add rule ip filter input tcp flags fin,syn,rst,psh,ack,urg / fin,syn,rst,psh,ack,urg counter drop'
doas nft 'add rule ip filter NETAVARK_FORWARD tcp flags fin,syn,rst,psh,ack,urg / fin,syn,rst,psh,ack,urg counter drop'
### Drop fragments
doas nft 'add rule ip filter input ip frag-off & 0x1fff != 0 counter drop'
doas nft 'add rule ip filter forward ip frag-off & 0x1fff != 0 counter drop'
doas nft 'add rule ip filter NETAVARK_FORWARD ip frag-off & 0x1fff != 0 counter drop'
doas nft 'add rule ip filter output ip frag-off & 0x1fff != 0 counter drop'
### Drop SYN packets with suspicious MSS value
doas nft 'add rule ip filter input ip protocol tcp ct state new tcp option maxseg size != 536-65535 counter drop'
doas nft 'add rule ip filter NETAVARK_FORWARD ip protocol tcp ct state new tcp option maxseg size != 536-65535 counter drop'
### Drop spoofed packets
doas nft 'add rule ip filter input iifname != "lo" ip saddr 127.0.0.0/8 counter drop'
doas nft 'add rule ip filter NETAVARK_FORWARD iifname != "lo" ip saddr 127.0.0.0/8 counter drop'
### Drop ICMP
doas nft 'add rule ip filter input ip protocol icmp counter drop'
doas nft 'add rule ip filter NETAVARK_FORWARD ip protocol icmp counter drop'
### Drop excessive TCP RST packets
doas nft 'add chain ip filter input_prerouting'
doas nft 'add rule ip filter input tcp flags rst limit rate 2/second burst 2 packets counter jump input_prerouting'
doas nft 'add rule ip filter input tcp flags rst counter drop'
#### Accept established connections on NETAVARK_FORWARD_PREROUTING
doas nft 'add chain ip filter NETAVARK_FORWARD_PREROUTING'
doas nft 'add rule ip filter NETAVARK_FORWARD_PREROUTING ip daddr 10.88.0.0/16 ct state related,established counter accept'
doas nft 'add rule ip filter NETAVARK_FORWARD tcp flags rst limit rate 2/second burst 2 packets counter jump NETAVARK_FORWARD_PREROUTING'
doas nft 'add rule ip filter NETAVARK_FORWARD tcp flags rst counter drop'
### Drop SYN-FLOOD packets
doas nft 'add rule ip filter input ip protocol tcp ct state new limit rate 2/second burst 2 packets counter jump input_prerouting'
doas nft 'add rule ip filter input ip protocol tcp ct state new counter drop'
doas nft 'add rule ip filter NETAVARK_FORWARD ip protocol tcp ct state new limit rate 2/second burst 2 packets counter jump NETAVARK_FORWARD_PREROUTING'
doas nft 'add rule ip filter NETAVARK_FORWARD ip protocol tcp ct state new counter drop'
### Rate-limit UDP packets
doas nft 'add rule ip filter input ip protocol udp ct state new limit rate 2/second burst 2 packets counter jump input_prerouting'
doas nft 'add rule ip filter input ip protocol udp ct state new counter drop'
### Accept SSH from LOCAL_DOMAINS if it is enabled
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
            doas nft "add rule ip filter NETAVARK_FORWARD_PREROUTING ip saddr $local_domain tcp dport 22 counter accept"
        done
    }
doas nft 'add rule ip filter input_prerouting tcp dport 9122 counter drop'
doas nft 'add rule ip filter NETAVARK_FORWARD_PREROUTING tcp dport 9122 counter drop'
### Accept custom wireguard
doas nft 'add rule ip filter input_prerouting udp dport 65398 counter accept'
### Jump to nixos-fw
doas nft 'add chain ip filter nixos-fw' || true
doas nft 'add rule ip filter input_prerouting counter jump nixos-fw'
#### FIXME: This is not part of nixos explicit config; These rules are created implicitly; Remove if migrating to nix
doas nft 'add chain ip filter nixos-fw-accept'
doas nft 'add chain ip filter nixos-fw-log-refuse'
doas nft 'add chain ip filter nixos-fw-refuse'
doas nft 'add rule ip filter nixos-fw iifname "lo" counter jump nixos-fw-accept'
doas nft 'add rule ip filter nixos-fw ct state related,established counter jump nixos-fw-accept'
doas nft 'add rule ip filter nixos-fw iifname "podman0" udp dport 53 counter jump nixos-fw-accept'
doas nft 'add rule ip filter nixos-fw counter jump nixos-fw-log-refuse'
doas nft 'add rule ip filter nixos-fw-accept counter accept'
doas nft 'add rule ip filter nixos-fw-log-refuse tcp flags syn / fin,syn,rst,ack counter log prefix "refused connection: " level info'
doas nft 'add rule ip filter nixos-fw-log-refuse pkttype != unicast counter jump nixos-fw-refuse'
doas nft 'add rule ip filter nixos-fw-log-refuse counter jump nixos-fw-refuse'
doas nft 'add rule ip filter nixos-fw-refuse counter drop'
### Accept http & https
#### Remote
DOMAINS="$(curl -s -X GET --url https://api.cloudflare.com/client/v4/ips -H 'Content-Type: application/json' | jq -r '.result.ipv4_cidrs[]' 2>/dev/null)"
if [[ -z "$DOMAINS" ]]; then
    DOMAINS="$(
        cat <<'EOF'
173.245.48.0/20
103.21.244.0/22
103.22.200.0/22
103.31.4.0/22
141.101.64.0/18
108.162.192.0/18
190.93.240.0/20
188.114.96.0/20
197.234.240.0/22
198.41.128.0/17
162.158.0.0/15
104.16.0.0/13
104.24.0.0/14
172.64.0.0/13
131.0.72.0/22
EOF
    )"
fi
for domain in $DOMAINS; do
    doas nft "add rule ip filter NETAVARK_FORWARD_PREROUTING ip saddr $domain ip daddr 10.88.0.0/16 tcp dport 80 counter accept"
    doas nft "add rule ip filter NETAVARK_FORWARD_PREROUTING ip saddr $domain ip daddr 10.88.0.0/16 tcp dport 443 counter accept"
done
#### Local
for local_domain in $LOCAL_DOMAINS; do
    doas nft "add rule ip filter NETAVARK_FORWARD_PREROUTING ip saddr $local_domain ip daddr 10.88.0.0/16 tcp dport 80 counter accept"
    doas nft "add rule ip filter NETAVARK_FORWARD_PREROUTING ip saddr $local_domain ip daddr 10.88.0.0/16 tcp dport 443 counter accept"
done
### Accept local network traffic on NETAVARK_FORWARD chains
doas nft 'add rule ip filter NETAVARK_FORWARD ip saddr 10.88.0.0/16 counter accept'
doas nft 'add rule ip filter NETAVARK_FORWARD_PREROUTING ip saddr 10.88.0.0/16 counter accept'
### Drop other traffic on NETAVARK_FORWARD chains
doas nft 'add rule ip filter NETAVARK_FORWARD counter drop'
doas nft 'add rule ip filter NETAVARK_FORWARD_PREROUTING counter drop'
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
### Accept established connections on NETAVARK_FORWARD
doas nft 'add chain ip6 filter NETAVARK_FORWARD'
doas nft 'add rule ip6 filter NETAVARK_FORWARD ip daddr fe80::/10 ct state related,established counter accept'
### First packet has to be TCP SYN
doas nft 'add rule ip6 filter input tcp flags != syn / fin,syn,rst,ack ct state new counter drop'
doas nft 'add rule ip6 filter NETAVARK_FORWARD tcp flags != syn / fin,syn,rst,ack ct state new counter drop'
### Drop all invalid packets
doas nft 'add rule ip6 filter input ct state invalid counter drop'
doas nft 'add rule ip6 filter forward ct state invalid counter drop'
doas nft 'add rule ip6 filter NETAVARK_FORWARD ct state invalid counter drop'
doas nft 'add rule ip6 filter output ct state invalid counter drop'
### Drop packets with bogus TCP flags
doas nft 'add rule ip6 filter input tcp flags fin,syn / fin,syn counter drop'
doas nft 'add rule ip6 filter input tcp flags syn,rst / syn,rst counter drop'
doas nft 'add rule ip6 filter input tcp flags fin,rst / fin,rst counter drop'
doas nft 'add rule ip6 filter input tcp flags fin / fin,ack counter drop'
doas nft 'add rule ip6 filter input tcp flags urg / ack,urg counter drop'
doas nft 'add rule ip6 filter input tcp flags psh / psh,ack counter drop'
doas nft 'add rule ip6 filter NETAVARK_FORWARD tcp flags fin,syn / fin,syn counter drop'
doas nft 'add rule ip6 filter NETAVARK_FORWARD tcp flags syn,rst / syn,rst counter drop'
doas nft 'add rule ip6 filter NETAVARK_FORWARD tcp flags fin,rst / fin,rst counter drop'
doas nft 'add rule ip6 filter NETAVARK_FORWARD tcp flags fin / fin,ack counter drop'
doas nft 'add rule ip6 filter NETAVARK_FORWARD tcp flags urg / ack,urg counter drop'
doas nft 'add rule ip6 filter NETAVARK_FORWARD tcp flags psh / psh,ack counter drop'
### Drop NULL packets
doas nft 'add rule ip6 filter input tcp flags 0x0 / fin,syn,rst,psh,ack,urg counter drop'
doas nft 'add rule ip6 filter NETAVARK_FORWARD tcp flags 0x0 / fin,syn,rst,psh,ack,urg counter drop'
### Drop XMAS packets
doas nft 'add rule ip6 filter input tcp flags fin,syn,rst,psh,ack,urg / fin,syn,rst,psh,ack,urg counter drop'
doas nft 'add rule ip6 filter NETAVARK_FORWARD tcp flags fin,syn,rst,psh,ack,urg / fin,syn,rst,psh,ack,urg counter drop'
### Drop SYN packets with suspicious MSS value
doas nft 'add rule ip6 filter input meta l4proto tcp ct state new tcp option maxseg size != 536-65535 counter drop'
doas nft 'add rule ip6 filter NETAVARK_FORWARD meta l4proto tcp ct state new tcp option maxseg size != 536-65535 counter drop'
### Drop spoofed packets
doas nft 'add rule ip6 filter input iifname != "lo" ip6 saddr ::1/128 counter drop'
doas nft 'add rule ip6 filter NETAVARK_FORWARD iifname != "lo" ip6 saddr ::1/128 counter drop'
### Drop ICMP
doas nft 'add rule ip6 filter input meta l4proto icmp counter drop'
doas nft 'add rule ip6 filter NETAVARK_FORWARD meta l4proto icmp counter drop'
### Drop excessive TCP RST packets
doas nft 'add chain ip6 filter input_prerouting'
doas nft 'add rule ip6 filter input tcp flags rst limit rate 2/second burst 2 packets counter jump input_prerouting'
doas nft 'add rule ip6 filter input tcp flags rst counter drop'
#### Accept established connections on NETAVARK_FORWARD_PREROUTING
doas nft 'add chain ip6 filter NETAVARK_FORWARD_PREROUTING'
doas nft 'add rule ip6 filter NETAVARK_FORWARD_PREROUTING ip daddr fe80::/10 ct state related,established counter accept'
doas nft 'add rule ip6 filter NETAVARK_FORWARD tcp flags rst limit rate 2/second burst 2 packets counter jump NETAVARK_FORWARD_PREROUTING'
doas nft 'add rule ip6 filter NETAVARK_FORWARD tcp flags rst counter drop'
### Drop SYN-FLOOD packets
doas nft 'add rule ip6 filter input meta l4proto tcp ct state new limit rate 2/second burst 2 packets counter jump input_prerouting'
doas nft 'add rule ip6 filter input meta l4proto tcp ct state new counter drop'
doas nft 'add rule ip6 filter NETAVARK_FORWARD meta l4proto tcp ct state new limit rate 2/second burst 2 packets counter jump NETAVARK_FORWARD_PREROUTING'
doas nft 'add rule ip6 filter NETAVARK_FORWARD meta l4proto tcp ct state new counter drop'
### Rate-limit UDP packets
doas nft 'add rule ip6 filter input meta l4proto udp ct state new limit rate 2/second burst 2 packets counter jump input_prerouting'
doas nft 'add rule ip6 filter input meta l4proto udp ct state new counter drop'
### Accept SSH from LOCAL_DOMAINS if it is enabled
LOCAL_DOMAINS="$(
    cat <<'EOF'
fe80::/10
::1/128
EOF
)"
[[ -n "${SYSUSER_PUBKEY}" ]] &&
    {
        for local_domain in $LOCAL_DOMAINS; do
            doas nft "add rule ip6 filter input_prerouting ip6 saddr $local_domain tcp dport 9122 counter accept"
            doas nft "add rule ip filter NETAVARK_FORWARD_PREROUTING ip6 saddr $local_domain tcp dport 22 counter accept"
        done
    }
doas nft 'add rule ip filter input_prerouting tcp dport 9122 counter drop'
### Accept custom wireguard
doas nft 'add rule ip6 filter input_prerouting udp dport 65398 counter accept'
### Jump to nixos-fw
doas nft 'add chain ip6 filter nixos-fw' || true
doas nft 'add rule ip6 filter input_prerouting counter jump nixos-fw'
#### FIXME: This is not part of nixos explicit config; These rules are created implicitly; Remove if migrating to nix
doas nft 'add chain ip6 filter nixos-fw-accept'
doas nft 'add chain ip6 filter nixos-fw-log-refuse'
doas nft 'add chain ip6 filter nixos-fw-refuse'
doas nft 'add rule ip6 filter nixos-fw iifname "lo" counter jump nixos-fw-accept'
doas nft 'add rule ip6 filter nixos-fw ct state related,established counter jump nixos-fw-accept'
doas nft 'add rule ip6 filter nixos-fw iifname "podman0" udp dport 53 counter jump nixos-fw-accept'
doas nft 'add rule ip6 filter nixos-fw meta l4proto ipv6-icmp icmpv6 type nd-redirect counter drop'
doas nft 'add rule ip6 filter nixos-fw meta l4proto ipv6-icmp counter jump nixos-fw-accept'
doas nft 'add rule ip6 filter nixos-fw ip6 daddr fe80::/64 udp dport 546 counter jump nixos-fw-accept'
doas nft 'add rule ip6 filter nixos-fw counter jump nixos-fw-log-refuse'
doas nft 'add rule ip6 filter nixos-fw-accept counter accept'
doas nft 'add rule ip6 filter nixos-fw-log-refuse tcp flags syn / fin,syn,rst,ack counter log prefix "refused connection: " level info'
doas nft 'add rule ip6 filter nixos-fw-log-refuse pkttype != unicast counter jump nixos-fw-refuse'
doas nft 'add rule ip6 filter nixos-fw-log-refuse counter jump nixos-fw-refuse'
doas nft 'add rule ip6 filter nixos-fw-refuse counter drop'
### Accept http & https
#### Remote
DOMAINS="$(curl -s -X GET --url https://api.cloudflare.com/client/v4/ips -H 'Content-Type: application/json' | jq -r '.result.ipv6_cidrs[]' 2>/dev/null)"
if [[ -z "$DOMAINS" ]]; then
    read -rd '\0' DOMAINS <<EOF
    2400:cb00::/32
    2606:4700::/32
    2803:f800::/32
    2405:b500::/32
    2405:8100::/32
    2a06:98c0::/29
    2c0f:f248::/32
    \0
EOF
fi
for domain in $DOMAINS; do
    doas nft "add rule ip6 filter NETAVARK_FORWARD_PREROUTING ip6 saddr $domain ip6 daddr fe80::/10 tcp dport 80 counter accept"
    doas nft "add rule ip6 filter NETAVARK_FORWARD_PREROUTING ip6 saddr $domain ip6 daddr fe80::/10 tcp dport 443 counter accept"
done
#### Local
doas nft 'add rule ip6 filter NETAVARK_FORWARD_PREROUTING ip6 saddr fe80::/10 ip6 daddr fe80::/10 tcp dport 80 counter accept'
doas nft 'add rule ip6 filter NETAVARK_FORWARD_PREROUTING ip6 saddr fe80::/10 ip6 daddr fe80::/10 tcp dport 443 counter accept'
### Accept local network traffic on NETAVARK_FORWARD chains
doas nft 'add rule ip6 filter NETAVARK_FORWARD ip6 saddr fe80::/10 counter accept'
doas nft 'add rule ip6 filter NETAVARK_FORWARD_PREROUTING ip6 saddr fe80::/10 counter accept'
### Drop other traffic on NETAVARK_FORWARD chains
doas nft 'add rule ip6 filter NETAVARK_FORWARD counter drop'
doas nft 'add rule ip6 filter NETAVARK_FORWARD_PREROUTING counter drop'
### Save rules to /etc/nftables.conf
doas /bin/sh -c 'nft -s list ruleset >/etc/nftables.conf'

# Configure secureboot
# Prompt user
# This prompt prevents unwanted overrides of already enrolled keys
echo "To deploy your own keys, don't confirm the next prompt."
# shellcheck source=/dev/null
. /etc/cryptboot.conf
read -rp "Overwrite secureboot keys? (Type 'yes' in capital letters): " choice
case "${choice}" in
"YES")
    rm -f ~/secureboot.sh
    if mountpoint -q /efi; then
        doas umount -AR /efi
    fi
    if mountpoint -q /boot; then
        doas umount -AR /boot
    fi
    doas mount /efi
    doas mount /boot
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
    log_warning "User aborted enrolling secureboot keys."
    log_warning "Deploy your own keys in '${EFI_KEYS_DIR:?}/keys' and run '~/secureboot.sh' to sign your bootloader."
    ;;
esac

# Install nix
doas /bin/sh -c "/bin/sh <(curl -L https://nixos.org/nix/install) --daemon --yes --nix-extra-conf-file ${SCRIPT_DIR}/nix.conf"

# Configure dot-files
doas systemd-run -P --wait --system -E HOME=/root -M root@ /bin/sh -c '. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh && ~/dot-files.sh'
# shellcheck source=/dev/null
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh && ~/dot-files.sh
TMP_USERS=("${GUESTUSER}" "${HOMEUSER}" "${VIRTUSER}" "${WORKUSER}")
for user in "${TMP_USERS[@]}"; do
    [[ -n "${user}" ]] ||
        continue
    id "${user}" >/dev/null 2>&1 ||
        var_invalid_err_exit "${user}" "TMP_USERS"
    doas systemd-run -P --wait --user -M "${user}"@ /bin/sh -c '. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh && ~/dot-files.sh'
done

# Source ~/.bash_profile
# shellcheck source=/dev/null
. ~/.bash_profile

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
for user in "${USERS[@]}"; do
    [[ -n "${user}" ]] ||
        continue
    id "${user}" >/dev/null 2>&1 ||
        var_invalid_err_exit "${user}" "USERS"
    for tmp_file in "${FILES[@]}"; do
        file="$(eval echo ~"${user}")"/"${tmp_file}"
        doas /bin/sh -c "[[ -f ${file} ]] || continue"
        doas rm -f "${file}"
    done
    for tmp_dir in "${DIRS[@]}"; do
        dir="$(eval echo ~"${user}")"/"${tmp_dir}"
        doas /bin/sh -c "[[ -d ${dir} ]] || continue"
        doas rm -rf "${dir}"
    done
    doas runuser -l "${user}" -c "rm -f ~/.*.bak"
done

# Set correct permissions on /nix/.snapshots; the install script also modifies the .snapshots dir
doas chown :wheel /nix/.snapshots

# Replace doas.conf with default
doas /bin/sh -c 'echo '"${DOAS_CONF}"' >/etc/doas.conf'

# Notify user if script has finished successfully
echo "'$(basename "${0}")' has finished successfully."
