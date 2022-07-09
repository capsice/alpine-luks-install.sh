#!/bin/sh

_OIFS=$IFS

###############################################################################
# General output functions
###############################################################################

usage() {
  printf "usage: alpine-luks-install.sh [-hs]\n\nSetup Alpine Linux With Full Disk Encryption\n\noptions:\n\t-h  Show this message\n\t-s  Skip initial setup\n\n"
  exit $1
}

eecho() {
  echo $1 >&2
}

die() {
  eecho $1
  exit 1
}

###############################################################################
# Disk functions
###############################################################################

# Get a disk name from its by-id path
by_id_to_diskname() {
  local resolved_path=$(readlink $1)
  printf "${resolved_path##*/}\n"
}

# Returns the /dev/disk/by-id path of a disk ($1)
get_disk_id() {
  for disk in /dev/disk/by-id/*; do
    local diskname=$(by_id_to_diskname $disk)
    if [ "$diskname" == "$1" ]; then
      local diskpath=$disk
      break
    fi
  done

  printf "%s\n" $diskpath
  unset disk 
}


# Returns the /dev/xxx path of a partition $1 on a disk $2
get_partition() {
  local partition=$(
    realpath /dev/disk/by-id/$(readlink "$2-part$1")
  )
  
  [ -b "$partition" ] && printf "%s\n" $partition
}

# Lists all disks (I'm sure there's a better way to do this)
all_disks() {
  local disks=""

  for disk in /dev/disk/by-id/*; do
    [ -z "${disk##*-part[0-9]}" ] && continue;

    local diskname=$(by_id_to_diskname $disk)

    if [ -z "$disks" ]; then
      disks="$diskname"
    else
      disks="$disks $diskname"
    fi
  done

  printf "$disks\n"
}

###############################################################################
# General input functions
###############################################################################

# Ask for a password and save it in _resp
ask_pass() {
  echo -n "$1: "
  set -o noglob
  read -rs _resp
  set +o noglob
  echo
}

# Ask for a password twice, similar to the passwd prompt
ask_pass_twice() {
  IFS=
  while :; do
    ask_pass "$1 (will not echo)"

    [ -z "$_resp" ] && \
      eecho "password is empty" && \
      continue
      
    local _password=$_resp
    ask_pass "$1 (again)"

    [ "$_resp" == "$_password" ] && break
    eecho "passwords do not match, try again"
  done
  IFS=$_OIFS
}

# Ask the user to select a disk
ask_disk() {
  while :; do
    echo -n "select a disk [$(all_disks)]: "

    read -r _resp

    local disk_id=$(get_disk_id $_resp)

    [ -n "$disk_id" ] && break

    eecho "disk not found, try again"
  done

  _resp=$(get_disk_id $_resp)
}

###############################################################################
# Utils
###############################################################################

is_efi() {
  [ -d "/sys/firmware/efi" ] && printf "1\n"
}

setup_hosts() {
  local tail="localhost localhost.localdomain"

  local DOMAIN=$(hostname)

  [ "$(hostname)" != "localhost" ] && \
    echo "127.0.0.1 $(hostname) $tail\n::1 $(hostname) $tail" > /etc/hosts
}

# Normalize the terminal on exit in case user quits mid prompt
normalize() {
  set +o noglob
  IFS=$_OIFS
  exit 0
}

###############################################################################
# Setup functions
###############################################################################

# Initial setup of Alpine Linux
setup_initial() {
  setup-keymap
  setup-hostname
  setup-hosts
  setup-interfaces
  rc-service networking start
  passwd
  setup-timezone
  rc-update add networking boot
  rc-update add urandom boot
  rc-update add acpid default
  rc-service acpid start
  setup-ntp
  setup-apkrepos
  apk update
}

setup_dos_part() {
  parted -s $1 mklabel msdos
  parted -s -a optimal $1 mkpart primary ext4 0% 100M
  parted -s $1 name 1 boot
  parted -s $1 set 1 boot on
  parted -s -a optimal $1 mkpart primary ext4 100M 100%
  parted -s $1 name 2 crypto-luks
}

setup_gpt_part() {
  parted -s $1 mklabel gpt
  parted -s -a optimal $1 mkpart primary fat32 0% 200M
  parted -s $1 name 1 esp
  parted -s $1 set 1 esp on
  parted -s -a optimal $1 mkpart primary ext4 200M 100%
  parted -s $1 name 2 crypto-luks
}

setup_dos_volumes() {
  lvcreate -L 2G $1 -n swap
  lvcreate -l 100%FREE $1 -n root
}

setup_gpt_volumes() {
  lvcreate -L 2G $1 -n swap
  lvcreate -L 2G $1 -n boot
  lvcreate -l 100%FREE $1 -n root
}

###############################################################################
# Main logic
###############################################################################

while getopts "hso" opt ; do
  case $opt in 
    h) usage 0;;
    s) SKIP_INITIAL_SETUP=1;;
    '?') usage 1 >&2;;
  esac
done

trap normalize 1 2 3 6

[ -z "$SKIP_INITIAL_SETUP" ] && \
  setup_initial

# Install required packages
apk add --quiet udev lvm2 cryptsetup e2fsprogs parted mkinitfs 2> /dev/null || \
  die "failed to install dependencies"
  
setup-udev

ask_disk
DISK=$_resp


# Partition disks
[ -n "$(is_efi)" ] && setup_gpt_part $DISK || setup_dos_part $DISK

BOOT_PART=$(get_partition 1 $DISK)
LUKS_PART=$(get_partition 2 $DISK)

ask_pass_twice "encryption password?"
ENCPWD=$_resp

printf "$ENCPWD" | cryptsetup -v -c serpent-xts-plain64 -s 512 --hash whirlpool \
  --iter-time 5000 --use-random luksFormat --type luks1 $LUKS_PART -d -

printf "$ENCPWD" | cryptsetup luksOpen $LUKS_PART lvmcrypt -d -

pvcreate /dev/mapper/lvmcrypt
vgcreate vg0 /dev/mapper/lvmcrypt

if [ -n "$(is_efi)" ]; then 
  setup_gpt_volumes vg0

  mkfs.ext4 /dev/vg0/root
  mkswap /dev/vg0/swap
  mount -t ext4 /dev/vg0/root /mnt

  apk add dosfstools
  mkfs.fat -F32 $BOOT_PART
  mkfs.ext4 /dev/vg0/boot
  mkdir -v /mnt/boot
  mount -t ext4 /dev/vg0/boot /mnt/boot
  mkdir -v /mnt/boot/efi
  mount -t vfat $BOOT_PART /mnt/boot/efi
  swapon /dev/vg0/swap
else 
  setup_dos_volumes vg0

  mkfs.ext4 /dev/vg0/root
  mkswap /dev/vg0/swap
  mount -t ext4 /dev/vg0/root /mnt

  mkfs.ext4 $BOOT_PART
  mkdir -v /mnt/boot
  mount -t ext4 $BOOT_PART /mnt/boot
  swapon /dev/vg0/swap
fi

setup-disk -m sys /mnt/ 2> /dev/null 

echo "/dev/vg0/swap swap swap defaults 0 0" >> /etc/fstab

sed -i 's/cryptsetup/cryptsetup cryptkey/' /mnt/etc/mkinitfs/mkinitfs.conf

mkinitfs -c /mnt/etc/mkinitfs/mkinitfs.conf -b /mnt/ $(ls /mnt/lib/modules)

if [ -n "$(is_efi)" ]; then
  dd bs=512 count=4 if=/dev/urandom of=/mnt/crypto_keyfile.bin
  printf "$ENCPWD" | cryptsetup luksAddKey $LUKS_PART /mnt/crypto_keyfile.bin -d -

  mount -t proc /proc /mnt/proc
  mount --rbind /dev /mnt/dev
  mount --make-rslave /mnt/dev
  mount --rbind /sys /mnt/sys

  chroot /mnt/ /bin/sh -x <<-EOF
    apk add --quiet grub grub-efi efibootmgr
    apk del --quiet syslinux
    sed -i 's/cryptdm=root/cryptdm=lvmcrypt cryptkey/' /etc/default/grub
    echo "GRUB_PRELOAD_MODULES=\"luks cryptodisk part_gpt lvm\"" \
      >> /etc/default/grub
    echo "GRUB_ENABLE_CRYPTODISK=y" >> /etc/default/grub

    grub-install --target=$(arch)-efi --efi-directory=/boot/efi
    grub-mkconfig -o /boot/grub/grub.cfg
EOF
# ^ This is somewhat ugly but it was the only way, since I use space indentation
else
  apk add syslinux
  sed -i 's/cryptdm=root/cryptdm=lvmcrypt/' /mnt/etc/update-extlinux.conf
  
  chroot /mnt/ /bin/sh -x <<-EOF 
    update-extlinux
EOF
# ^ Here too

  dd bs=440 count=1 conv=notrunc \
    if=/mnt/usr/share/syslinux/mbr.bin of=$BOOT_PART
fi
