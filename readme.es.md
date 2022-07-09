# alpine-luks-install.sh

Una herramienta simple para instalar Alpine Linux con cifrado de disco completo (excluyendo el bootloader)

Este script está basado en el siguiente artículo: https://wiki.alpinelinux.org/wiki/LVM_on_LUKS, e implementa varias funciones de https://gitlab.alpinelinux.org/alpine/alpine-conf/-/blob/master/libalpine.sh.in

Depende en los siguientes programas:

* udev
* lvm2
* cryptsetup
* e2fsprogs
* parted
* mkinitfs

Más los siguientes si tu dispositivo es compatible con UEFI:

* dosfstools
* grub 
* grub-efi 
* efibootmgr

Este script solo ha sido testeado para x86_64-efi. Puede que no funcione para otros dispositivos con distintas arquitecturas.