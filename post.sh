#!/usr/bin/env bash
###
# File: post.sh
# Author: Leopold Johannes Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2026 Leopold Johannes Meinel & contributors
# SPDX ID: Apache-2.0
# URL: https://www.apache.org/licenses/LICENSE-2.0
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
script_fail_err_exit() {
    log_err "Script failed for '${1}'."
    exit 1
}

# Source config
SCRIPT_DIR="$(dirname -- "$(readlink -f -- "${0}")")"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}"/install.conf

# Replace doas.conf with option nopass
DOAS_CONF="$(doas cat /etc/doas.conf)"
for i in {1..5}; do
    if [[ "${i}" -eq 5 ]]; then
        log_err "Too many retries."
        exit 1
    fi
    if doas /bin/sh -c "echo ${DOAS_CONF/"persist"/"nopass"} >/etc/doas.conf"; then
        break
    else
        log_warning "You have entered an incorrect password. Retrying now."
    fi
done

# Configure KEYMAP
doas localectl --no-convert set-keymap "${KEYMAP}"
doas localectl --no-convert set-x11-keymap "${KEYLAYOUT}"

# Configure clock
doas timedatectl set-ntp true

# Set default java
doas archlinux-java set java-17-openjdk

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
### Accept SSH from LOCAL_DOMAINS if it is enabled
LOCAL_DOMAINS="$(
    cat <<'EOF'
10.0.0.0/8
172.16.0.0/12
192.168.0.0/16
127.0.0.0/8
EOF
)"
if [[ -n "${SYSUSER_PUBKEY}" ]]; then
    for local_domain in $LOCAL_DOMAINS; do
        doas nft "add rule ip filter input_prerouting ip saddr $local_domain tcp dport 9122 counter accept"
    done
fi
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
doas nft 'add rule ip6 filter input iifname != "lo" ip6 saddr ::1/128 counter drop'
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
### Accept SSH from LOCAL_DOMAINS if it is enabled
LOCAL_DOMAINS="$(
    cat <<'EOF'
fe80::/10
::1/128
EOF
)"
if [[ -n "${SYSUSER_PUBKEY}" ]]; then
    for local_domain in $LOCAL_DOMAINS; do
        doas nft "add rule ip6 filter input_prerouting ip6 saddr $local_domain tcp dport 9122 counter accept"
    done
fi
doas nft 'add rule ip6 filter input_prerouting tcp dport 9122 counter drop'
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
## Download nix upstream installation script
tmpfile="$(mktemp /tmp/arch-install-nixos-XXXXXX.sh)"
curl --proto '=https' --tlsv1.2 -sSfL https://nixos.org/nix/install -o "${tmpfile}"
read -rp "Skip confirmation of nix upstream installation script? (Type 'yes' in capital letters): " choice
case "${choice}" in
"YES") ;;
*)
    ## View nix upstream installation script
    echo "To exit confirmation hit 'q'."
    sleep 5
    bat --decorations auto --color auto "${tmpfile}"
    read -rp "Execute nix upstream installation script? (Type 'yes' in capital letters): " choice
    ;;
esac
case "${choice}" in
"YES")
    ## Execute nix upstream installation script
    chmod +x "${tmpfile}"
    doas "${tmpfile}" --daemon --yes --nix-extra-conf-file "${SCRIPT_DIR}"/nix.conf
    ;;
*)
    log_err "User aborted executing nix upstream installation script."
    exit 1
    ;;
esac

# Configure dot-files
SCRIPT="$(
    cat <<'EOF'
# Fail on error
set -e

# shellcheck source=/dev/null
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
~/dot-files.sh
EOF
)"
for user in "${USERS[@]}"; do
    ## Check if "${user}" is valid
    [[ -n "${user}" ]] ||
        continue
    id "${user}" >/dev/null 2>&1 ||
        var_invalid_err_exit "${user}" "USERS"

    case "$(id -u "${user}")" in
    0)
        doas systemd-run -P --wait --system -E HOME=/"${user}" -M "${user}"@ /bin/sh -c "${SCRIPT}" || script_fail_err_exit "${user}"
        ;;
    "${UID}")
        /bin/sh -c "${SCRIPT}" || script_fail_err_exit "${user}"
        ;;
    *)
        doas systemd-run -P --wait --user -M "${user}"@ /bin/sh -c "${SCRIPT}" || script_fail_err_exit "${user}"
        ;;
    esac
done

# Source ~/.bash_profile
# shellcheck source=/dev/null
. ~/.bash_profile

# Install flatpaks
command -v flatpak >/dev/null 2>&1 &&
    xargs -n 1 doas flatpak install --system -y --noninteractive <"${SCRIPT_DIR}/pkgs-flatpak.txt"

# Install paru
git clone https://aur.archlinux.org/paru.git ~/git/paru
cd ~/git/paru
makepkg -sri --noprogressbar --noconfirm --needed

# Configure paru.conf
doas /bin/sh -c '{
    echo ""
    echo "# arch-install"
    echo "Include = /etc/paru.conf.d/50-arch-install.conf"
} >>/etc/paru.conf'

# AUR packages
paru -S --noprogressbar --noconfirm --needed - <"$SCRIPT_DIR/pkgs-post.txt"

# Clear package cache
paru -Scc
doas /bin/sh -c 'pacman -Qtdq | pacman -Rns -' || true

# Run upgrade-home
# FIXME: This should not be necessary but we are doing it to also copy theme files from AUR packages
/usr/local/bin/upgrade-home

# Enable systemd services
pacman -Qq "nftables" >/dev/null 2>&1 &&
    doas systemctl enable nftables.service

# Remove user files
FILES=(
    ".bash_history"
    ".nix-channels"
    "dot-files.sh"
    "install.conf"
    "nix.conf"
    "pkgs-flatpak.txt"
    "pkgs-post.txt"
    "post.sh"
)
DIRS=(
    ".gnupg"
    ".nix-defexpr"
    ".nix-profile"
    "git"
)
for user in "${USERS[@]}"; do
    ## Check if "${user}" is valid
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
