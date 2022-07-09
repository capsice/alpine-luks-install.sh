# alpine-luks-install.sh

A simple tool to install Alpine Linux with Full Disk Encryption (apart from the bootloader partition)

This script was based on the following article: https://wiki.alpinelinux.org/wiki/LVM_on_LUKS, and implements multiple functions from https://gitlab.alpinelinux.org/alpine/alpine-conf/-/blob/master/libalpine.sh.in

```
usage: alpine-luks-install.sh [-hs]

Setup Alpine Linux With Full Disk Encryption

options:
        -h  Show this message
        -s  Skip initial setup      
```

It depends on the following packages:

* udev
* lvm2
* cryptsetup
* e2fsprogs
* parted
* mkinitfs

Plus the following if your system supports UEFI:

* dosfstools
* grub 
* grub-efi 
* efibootmgr

This script has only been tested on x86_64-efi. It might not work on other devices with different architectures.