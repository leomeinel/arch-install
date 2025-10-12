#!/usr/bin/env bash
###
# File: prepare.sh
# Author: Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2025 Leopold Meinel & contributors
# SPDX ID: MIT
# URL: https://opensource.org/licenses/MIT
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
sed_exit() {
    log_err "'sed' didn't replace, report this at https://github.com/leomeinel/arch-install/issues."
    exit 1
}

# Source config
SCRIPT_DIR="$(dirname -- "$(readlink -f -- "${0}")")"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}"/install.conf

# Unmount everything from /mnt
mountpoint -q /mnt &&
    umount -AR /mnt

# Prompt user for RAID
read -rp "Set up RAID? (Type 'yes' in capital letters): " choice
case "${choice}" in
"YES")
    ## Detect disks
    readarray -t DISKS < <(lsblk -drnpo NAME -I 259,8,254 | tr -d "[:blank:]")
    DISKS_LENGTH="${#DISKS[@]}"
    for ((i = 0; i < DISKS_LENGTH; i++)); do
        if udevadm info -q property --property=ID_BUS --value "${DISKS[${i}]}" | grep -q "usb"; then
            unset 'DISKS[${i}]'
            continue
        fi
        DISKS=("${DISKS[@]}")
    done
    if [[ "${#DISKS[@]}" -lt 2 ]]; then
        log_err "There are less than 2 disks attached."
        exit 1
    fi
    if [[ "${#DISKS[@]}" -gt 2 ]]; then
        log_warning "There are more than 2 disks attached."
        lsblk -drnpo SIZE,NAME,MODEL,LABEL -I 259,8,254
        ### Prompt user to select 2 RAID members
        read -rp "Which disk should be the first RAID member? (Type '/dev/sdX' fex.): " choice0
        read -rp "Which disk should be the second RAID member? (Type '/dev/sdY' fex.): " choice1
        if [[ "$(tr -d "[:space:]" <<<"${choice0}")" != "$(tr -d "[:space:]" <<<"${choice1}")" ]] && lsblk -drnpo SIZE,NAME,MODEL,LABEL -I 259,8,254 "${choice0}" "${choice1}"; then
            echo "Using '${choice0}' and '${choice1}' for installation."
            DISKS=(
                "${choice0}"
                "${choice1}"
            )
        else
            log_err "Drives not suitable for installation."
            exit 1
        fi
    fi
    ## Set size for partition of larger disk
    SIZE1="$(lsblk -drnbo SIZE "${DISKS[0]}" | tr -d "[:space:]")"
    SIZE2="$(lsblk -drnbo SIZE "${DISKS[1]}" | tr -d "[:space:]")"
    ### Check that both drives are over 10GiB
    if [[ "${SIZE1}" -lt 10737418240 ]] || [[ "${SIZE2}" -lt 10737418240 ]]; then
        log_err "Drive too small for installation."
        exit 1
    fi
    if [[ "${SIZE1}" -eq "${SIZE2}" ]]; then
        DISK1="${DISKS[0]}"
        DISK2="${DISKS[1]}"
        PART_SIZE=0
    else
        log_warning "The attached disks don't have the same size."
        log_warning "The larger disk will have unpartitioned space remaining."
        if [[ "${SIZE1}" -gt "${SIZE2}" ]]; then
            DISK1="${DISKS[0]}"
            DISK2="${DISKS[1]}"
            PART_SIZE="$((-(("${SIZE1}" - "${SIZE2}") / 1024)))K"
        else
            DISK1="${DISKS[1]}"
            DISK2="${DISKS[0]}"
            PART_SIZE="$((-(("${SIZE2}" - "${SIZE1}") / 1024)))K"
        fi
    fi
    ## Prompt user to confirm erasure
    read -rp "Erase '${DISK1}' and '${DISK2}'? (Type 'yes' in capital letters): " choice
    case "${choice}" in
    "YES")
        echo "Erasing '${DISK1}' and '${DISK2}'..."
        ;;
    *)
        log_err "User aborted erasing '${DISK1}' and '${DISK2}'."
        exit 1
        ;;
    esac
    ;;
*)
    ## Prompt user for disk
    ## NOTE: USB will be valid to allow external SSDs
    lsblk -drnpo SIZE,NAME,MODEL,LABEL -I 259,8,254
    read -rp "Which disk do you want to erase? (Type '/dev/sdX' fex.): " choice
    if lsblk -drnpo SIZE,NAME,MODEL,LABEL -I 259,8,254 "${choice}"; then
        ### Set DISK1
        DISK1="${choice}"
        ### Check that the drive is over 10GiB
        SIZE1="$(lsblk -drnbo SIZE "${DISK1}" | tr -d "[:space:]")"
        if [[ "${SIZE1}" -lt 10737418240 ]]; then
            log_err "Drive too small for installation."
            exit 1
        fi
        echo "Erasing '${DISK1}'..."
    else
        log_err "Drive not suitable for installation."
        exit 1
    fi
    ;;
esac

# Install packages that are dependencies for this script
mkdir -p /etc/pacman.conf.d/
cp "${SCRIPT_DIR}"/etc/pacman.conf.d/*.conf /etc/pacman.conf.d/
{
    echo ""
    echo "# arch-install"
    echo "Include = /etc/pacman.conf.d/*.conf"
} >>/etc/pacman.conf
reflector --save /etc/pacman.d/mirrorlist --country "${MIRRORCOUNTRIES}" --protocol https --latest 20 --sort rate
pacman -Syy
pacman -S --noprogressbar --noconfirm --needed lshw

# Erase disks
## Deactivate all vgs
vgchange -an || true
## Close all crypt volumes
dmsetup ls | awk '{print "/dev/mapper/"$1}' | xargs -n 1 cryptsetup close || true
## Stop all mdadm RAIDs
mdadm -Ss || true
## Use dd, sgdisk and wipefs to wipe the header and more to make sure that it is erased
sgdisk -o "${DISK1}" || true
sgdisk -Z "${DISK1}" || true
wipefs -a "${DISK1}"
dd if=/dev/zero of="${DISK1}" bs=1M conv=fsync count=8192 status=progress
if [[ -n "${DISK2}" ]]; then
    sgdisk -o "${DISK2}" || true
    sgdisk -Z "${DISK2}" || true
    wipefs -a "${DISK2}"
    dd if=/dev/zero of="${DISK2}" bs=1M conv=fsync count=8192 status=progress
fi
## Prompt user if they want to secure wipe the whole disk
if [[ -n "${DISK2}" ]]; then
    read -rp "Secure wipe '${DISK1}' and '${DISK2}'? (Type 'yes' in capital letters): " choice
    if [[ "${choice}" == "YES" ]]; then
        dd if=/dev/urandom of="${DISK1}" bs="$(stat -c "%o" "${DISK1}")" conv=fsync status=progress || true
        dd if=/dev/urandom of="${DISK2}" bs="$(stat -c "%o" "${DISK2}")" conv=fsync status=progress || true
    fi
else
    read -rp "Secure wipe '${DISK1}'? (Type 'yes' in capital letters): " choice
    if [[ "${choice}" == "YES" ]]; then
        dd if=/dev/urandom of="${DISK1}" bs="$(stat -c "%o" "${DISK1}")" conv=fsync status=progress || true
    fi
fi

# Load KEYMAP & set time
loadkeys "${KEYMAP}"
timedatectl set-ntp true
timedatectl set-timezone "${TIMEZONE}"

# Partition disks
sgdisk -n 0:0:+1G -t 1:ef00 "${DISK1}"
if [[ -n "${DISK2}" ]]; then
    sgdisk -n 0:0:"${PART_SIZE}" -t 2:fd00 "${DISK1}"
    sgdisk -n 0:0:+1G -t 1:ef00 "${DISK2}"
    sgdisk -n 0:0:0 -t 2:fd00 "${DISK2}"
else
    sgdisk -n 0:0:0 -t 2:8300 "${DISK1}"
fi

# Configure raid and encryption
DISK1P1="$(lsblk -rnpo TYPE,NAME "${DISK1}" | grep "part" | sed 's/part//g' | sed -n '1p' | tr -d "[:space:]")"
DISK1P2="$(lsblk -rnpo TYPE,NAME "${DISK1}" | grep "part" | sed 's/part//g' | sed -n '2p' | tr -d "[:space:]")"
if [[ -n "${DISK2}" ]]; then
    DISK2P1="$(lsblk -rnpo TYPE,NAME "${DISK2}" | grep "part" | sed 's/part//g' | sed -n '1p' | tr -d "[:space:]")"
    DISK2P2="$(lsblk -rnpo TYPE,NAME "${DISK2}" | grep "part" | sed 's/part//g' | sed -n '2p' | tr -d "[:space:]")"
    ## Configure raid1
    RAID_DEVICE=/dev/md/md0
    mdadm -Cv --homehost=any -N md0 -l 1 -n 2 -e default -b internal "${RAID_DEVICE}" "${DISK1P2}" "${DISK2P2}"
    ## Configure encryption
    for i in {1..5}; do
        if [[ "${i}" -eq 5 ]]; then
            log_err "Too many retries."
            exit 1
        fi
        if cryptsetup -y -v luksFormat "${RAID_DEVICE}"; then
            break
        else
            log_warning "You have entered an incorrect password. Retrying now."
        fi
    done
    for i in {1..5}; do
        if [[ "${i}" -eq 5 ]]; then
            log_err "Too many retries."
            exit 1
        fi
        if cryptsetup open "${RAID_DEVICE}" md0_crypt; then
            break
        else
            log_warning "You have entered an incorrect password. Retrying now."
        fi
    done
else
    ## Configure encryption
    for i in {1..5}; do
        if [[ "${i}" -eq 5 ]]; then
            log_err "Too many retries."
            exit 1
        fi
        if cryptsetup -y -v luksFormat "${DISK1P2}"; then
            break
        else
            log_warning "You have entered an incorrect password. Retrying now."
        fi
    done
    for i in {1..5}; do
        if [[ "${i}" -eq 5 ]]; then
            log_err "Too many retries."
            exit 1
        fi
        if cryptsetup open "${DISK1P2}" md0_crypt; then
            break
        else
            log_warning "You have entered an incorrect password. Retrying now."
        fi
    done
fi

# Configure lvm
pvcreate /dev/mapper/md0_crypt
vgcreate vg0 /dev/mapper/md0_crypt
lvcreate -l "${DISK_ALLOCATION[0]}" vg0 -n lv0
lvcreate -l "${DISK_ALLOCATION[1]}" vg0 -n lv1
lvcreate -l "${DISK_ALLOCATION[2]}" vg0 -n lv2
lvcreate -l "${DISK_ALLOCATION[3]}" vg0 -n lv3
lvcreate -l "${DISK_ALLOCATION[4]}" vg0 -n lv4

# Format efi
mkfs.fat -n EFI -F32 "${DISK1P1}"
[[ -n "${DISK2}" ]] &&
    mkfs.fat -n EFI -F32 "${DISK2P1}"

# Configure mounts
## Create subvolumes
SUBVOLUMES_LENGTH="${#SUBVOLUMES[@]}"
create_subs0() {
    mkfs.btrfs -L "${3}" "${4}"
    mount "${4}" /mnt
    btrfs subvolume create /mnt/@"${2}"
    btrfs subvolume create /mnt/@"${2}"_snapshots
    create_subs1 "${1}"
    umount /mnt
}
create_subs1() {
    for ((a = 0; a < SUBVOLUMES_LENGTH; a++)); do
        if [[ "${SUBVOLUMES[${a}]}" != "${1}" ]] && grep -q "^${1}" <<<"${SUBVOLUMES[${a}]}"; then
            btrfs subvolume create /mnt/@"${CONFIGS[${a}]}"
            btrfs subvolume create /mnt/@"${CONFIGS[${a}]}"_snapshots
        fi
    done
}
LV0=/dev/mapper/vg0-lv0
LV1=/dev/mapper/vg0-lv1
LV2=/dev/mapper/vg0-lv2
LV3=/dev/mapper/vg0-lv3
LV4=/dev/mapper/vg0-lv4
for ((i = 0; i < SUBVOLUMES_LENGTH; i++)); do
    case "${SUBVOLUMES[${i}]}" in
    /)
        mkfs.btrfs -L ROOT "${LV0}"
        mount "${LV0}" /mnt
        btrfs subvolume create /mnt/@
        btrfs subvolume create /mnt/@snapshots
        umount /mnt
        ;;
    /usr/)
        create_subs0 "${SUBVOLUMES[${i}]}" "${CONFIGS[${i}]}" "USR" "${LV1}"
        ;;
    /nix/)
        create_subs0 "${SUBVOLUMES[${i}]}" "${CONFIGS[${i}]}" "NIX" "${LV2}"
        ;;
    /var/)
        create_subs0 "${SUBVOLUMES[${i}]}" "${CONFIGS[${i}]}" "VAR" "${LV3}"
        ;;
    /home/)
        create_subs0 "${SUBVOLUMES[${i}]}" "${CONFIGS[${i}]}" "HOME" "${LV4}"
        ;;
    esac
done
## Mount subvolumes
OPTIONS0="noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvol=/@"
OPTIONS1="nodev,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvol=/@"
OPTIONS2="nodev,nosuid,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvol=/@"
OPTIONS3="noexec,nodev,nosuid,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvol=/@"
mount_subs0() {
    mount -m -o "${3}${2}" -t btrfs "${4}" /mnt"${1}"
    mount -m -o "${OPTIONS3}${2}_snapshots" -t btrfs "${4}" /mnt"${1}".snapshots
    mount_subs1 "${1}" "${3}" "${4}"
}
mount_subs1() {
    for ((a = 0; a < SUBVOLUMES_LENGTH; a++)); do
        if [[ "${SUBVOLUMES[${a}]}" != "${1}" ]] && grep -q "^${1}" <<<"${SUBVOLUMES[${a}]}"; then
            if { grep -q "^${1}log/" <<<"${SUBVOLUMES[${a}]}"; } || { grep -q "^${1}lib/" <<<"${SUBVOLUMES[${a}]}" && ! grep -q "^${1}lib/flatpak/" <<<"${SUBVOLUMES[${a}]}"; }; then
                mount -m -o "${OPTIONS3}${CONFIGS[${a}]}" -t btrfs "${3}" /mnt"${SUBVOLUMES[${a}]}"
            else
                mount -m -o "${2}${CONFIGS[${a}]}" -t btrfs "${3}" /mnt"${SUBVOLUMES[${a}]}"
            fi
            mount -m -o "${OPTIONS3}${CONFIGS[${a}]}_snapshots" -t btrfs "${3}" /mnt"${SUBVOLUMES[${a}]}".snapshots
        fi
    done
}
for ((i = 0; i < SUBVOLUMES_LENGTH; i++)); do
    case "${SUBVOLUMES[${i}]}" in
    /)
        mount -m -o "${OPTIONS0}" -t btrfs "${LV0}" /mnt"${SUBVOLUMES[${i}]}"
        mount -m -o "${OPTIONS3}snapshots" -t btrfs "${LV0}" /mnt"${SUBVOLUMES[${i}]}".snapshots
        ;;
    /usr/)
        mount_subs0 "${SUBVOLUMES[${i}]}" "${CONFIGS[${i}]}" "${OPTIONS1}" "${LV1}"
        ;;
    /nix/)
        mount_subs0 "${SUBVOLUMES[${i}]}" "${CONFIGS[${i}]}" "${OPTIONS1}" "${LV2}"
        ;;
    /var/)
        mount_subs0 "${SUBVOLUMES[${i}]}" "${CONFIGS[${i}]}" "${OPTIONS2}" "${LV3}"
        ;;
    /home/)
        mount_subs0 "${SUBVOLUMES[${i}]}" "${CONFIGS[${i}]}" "${OPTIONS2}" "${LV4}"
        ;;
    esac
done
## tmpfs
mount -m -o "noexec,nodev,nosuid,size=80%" -t tmpfs tmpfs /mnt/dev/shm
### FIXME: Ideally, /tmp should be noexec; See: https://github.com/NixOS/nix/issues/10492
mount -m -o "nodev,nosuid,mode=1700,size=80%" -t tmpfs tmpfs /mnt/tmp
## proc
mount -m -o "noexec,nodev,nosuid,gid=proc,hidepid=2" -t proc proc /mnt/proc
## /efi
OPTIONS4="noexec,nodev,nosuid,noatime,fmask=0077,dmask=0077"
mount -m -o "${OPTIONS4}" -t vfat "${DISK1P1}" /mnt/efi
[[ -n "${DISK2}" ]] &&
    mount -m -o "${OPTIONS4}" -t vfat "${DISK2P1}" /mnt/efi.bak
## Configure bind mounts
### /boot
mount -m -B /mnt/efi /mnt/boot
## Modify perms
chmod 775 /mnt/var/games

# Disable 90-dracut-install.hook
# See: https://wiki.archlinux.org/title/Dracut#Generate_a_new_initramfs_on_kernel_upgrade
touch /mnt/etc/pacman.d/hooks/60-dracut-remove.hook
touch /mnt/etc/pacman.d/hooks/90-dracut-install.hook

# Append system packages
[[ -n "${DISK2}" ]] &&
    echo "mdadm" >>"${SCRIPT_DIR}/pkgs-prepare.txt"
[[ -d /proc/acpi/button/lid ]] &&
    {
        echo "tlp"
        echo "tlp-rdw"
    } >>"${SCRIPT_DIR}/pkgs-prepare.txt"
lscpu | grep "Vendor ID:" | grep -q "GenuineIntel" &&
    echo "intel-ucode" >>"${SCRIPT_DIR}/pkgs-prepare.txt"
lscpu | grep "Vendor ID:" | grep -q "AuthenticAMD" &&
    echo "amd-ucode" >>"${SCRIPT_DIR}/pkgs-prepare.txt"
case "$(systemd-detect-virt -v)" in
"kvm" | "qemu")
    {
        echo "qemu-guest-agent"
        echo "spice-vdagent"
    } >>"${SCRIPT_DIR}/pkgs-prepare.txt"
    ;;
"oracle")
    echo "virtualbox-guest-utils" >>"${SCRIPT_DIR}/pkgs-prepare.txt"
    ;;
"vmware")
    {
        echo "open-vm-tools"
        echo "xf86-input-vmmouse"
        echo "xf86-video-vmware"
    } >>"${SCRIPT_DIR}/pkgs-prepare.txt"
    ;;
esac
lshw -C display | grep "vendor:" | grep -q "Advanced Micro Devices, Inc." &&
    {
        echo "vulkan-radeon"
        echo "xf86-video-amdgpu"
    } >>"${SCRIPT_DIR}/pkgs-prepare.txt"
lshw -C display | grep "vendor:" | grep -q "Intel Corporation" &&
    {
        echo "intel-media-driver"
        echo "vulkan-intel"
        echo "xf86-video-intel"
    } >>"${SCRIPT_DIR}"/pkgs-prepare.txt
for i in {1..5}; do
    if [[ "${i}" -eq 5 ]]; then
        log_err "Too many retries."
        exit 1
    fi
    if pacstrap -K /mnt - <"${SCRIPT_DIR}/pkgs-prepare.txt"; then
        break
    else
        log_warning "'pacstrap' failed. Retrying now."
    fi
done

# Unmount bind mounts to not include wrong mountpoints in /mnt/etc/fstab
umount /mnt/boot

# Generate /mnt/etc/fstab
genfstab -UP /mnt >>/mnt/etc/fstab
if [[ -n "${DISK2}" ]]; then
    ## START sed
    FILE=/mnt/etc/fstab
    STRING0="/efi.bak.*vfat"
    grep -q "${STRING0}" "${FILE}" || sed_exit
    STRING1="rw"
    grep -q "${STRING1}" "${FILE}" || sed_exit
    sed -i "/\\${STRING0}/s/${STRING1}/${STRING1},noauto/" "${FILE}"
    ## END sed
fi

# Copy /mnt/etc/fstab to /mnt/etc/fstab.sys for dracut
cp /mnt/etc/fstab /mnt/etc/fstab.sys

# Append /mnt/etc/fstab
{
    echo ""
    echo "# arch-install"
    echo "## bind"
    echo "/efi /boot none bind 0 0"
} >>/mnt/etc/fstab

# Configure /mnt/etc/resolv.conf
ln -sf ../run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf

# Prepare /mnt/git/arch-install
mkdir -p /mnt/git
mv "${SCRIPT_DIR}" /mnt/git/
chmod 755 /mnt/git/arch-install/setup.sh

# Notify user if script has finished successfully
echo "'$(basename "${0}")' has finished successfully."
