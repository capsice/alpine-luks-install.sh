# alpine-luks-install.sh

Una herramienta simple para instalar Alpine Linux con Cifrado de Disco Completo (excluyendo el bootloader)

Este script está basado en el siguiente artículo: https://wiki.alpinelinux.org/wiki/LVM_on_LUKS, e implementa varias funciones de https://gitlab.alpinelinux.org/alpine/alpine-conf/-/blob/master/libalpine.sh.in

```
uso: alpine-luks-install.sh [-hs]

Instala Alpine Linux Con Cifrado De Disco Completo

opciones:
        -h  Mostrar este mensaje
        -s  Saltarse la configuración inicial 
```

Depende de los siguientes programas:

* udev
* lvm2
* cryptsetup
* e2fsprogs
* parted
* mkinitfs

Más los siguientes si tu sistema es compatible con UEFI:

* dosfstools
* grub 
* grub-efi 
* efibootmgr

Este script solo ha sido testeado para x86_64-efi. Puede que no funcione para otros sistemas con distintas arquitecturas.
