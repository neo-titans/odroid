# Install Minimal Ubuntu16.04

Here is my memo which are steps to install Ubuntu16.04 and replace kernel with zswap.

## Flash image

Get ubuntu image from http://odroid.com/dokuwiki/doku.php?id=en:c2_release_linux_ubuntu

```
    ubuntu64-16.04-minimal-odroid-c2-20160803.img.xz
```

And flash to EMMC on PC with reference to http://odroid.com/dokuwiki/doku.php?id=en:odroid_flashing_tools

```shell
$ xz -d ubuntu64-16.04-minimal-odroid-c2-20160803.img.xz
$ sudo dd if=ubuntu64-16.04-minimal-odroid-c2-20160803.img of=/dev/sdX bs=16M # sdX should be read
```

after flash, extend Linux partition and create swap partition manually by gparted. I used 32GB EMMC.

```
Device         Boot    Start      End  Sectors  Size Id Type
/dev/mmcblk0p1          2048   264191   262144  128M  c W95 FAT32 (LBA)
/dev/mmcblk0p2        264192 56877055 56612864   27G 83 Linux
/dev/mmcblk0p3      56877056 61071359  4194304    2G 82 Linux swap / Solaris
```

```shell
$ sudo mkswap /dev/mmcblk0p3
$ sudo blkid
```

append swap info into  /etc/fstab like below

```
UUID=aebedc67-47df-4446-81c2-5408687c4900 swap swap defaults 0 0
```

Finally, enable swap

```shell
$ sudo swapon -a
```

## Build Kernel

Reference with to  http://odroid.com/dokuwiki/doku.php?id=en:c2_building_kernel

```shell
$ sudo apt-get install git
$ sudo apt-get install gcc-4.9
$ sudo apt-get install libncurses-dev
$ sudo apt-get install bc
$ git clone --depth 1 https://github.com/hardkernel/linux.git -b odroidc2-3.14.y
$ CC=/usr/bin/gcc-4.9 make odroidc2_defconfig
$ CC=/usr/bin/gcc-4.9 make menuconfig
```

Then check options to enable ZSWAP

```
Kernel Features ->
   [*] Enable frontswap to cache swap pages if tmem is present
   [*] Compressed cache for swap pages (EXPERIMENTAL)  

Cryptographic API ->
   <*> LZ4 compression algorithm
   <*>   LZ4HC compression algorithm
```

Build and install

```shell
$ CC=/usr/bin/gcc-4.9 make -j4 Image dtbs modules
$ sudo make modules_install
$ sudo cp -f arch/arm64/boot/Image arch/arm64/boot/dts/meson64_odroidc2.dtb /media/boot/
```

And edit boot option /media/boot/boot.ini and zswap option.
It is able to use lz4. But it seemed to be unstable ?

nographics "1" makes 300M free memory.
```
setenv nographics "1"

setenv bootargs " ... snip ... elevator=noop disablehpd=${hpd} zswap.enabled=1 zswap.max_pool_percent=25 zswap.compressor=lzo"
```

Finally reboot
