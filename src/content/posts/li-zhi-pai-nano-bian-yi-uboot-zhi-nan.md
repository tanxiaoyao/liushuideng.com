---
title: "荔枝派Nano编译Uboot指南"
published: 2023-05-25
description: "绝大部分基本操作都是按照官方教程走就可以了，碰到了一部分问题教程没有写的，记录备忘。 1. 系统安装按照教程指定16.04，不过我安装的是ubuntu serv"
image: "https://wiki.sipeed.com/soft/Lichee/zh/Nano-Doc-Backup/static/lichee-nano.jpg"
tags: ["嵌入式-底软开发-Linux-lichee"]
category: ""
draft: false
---

绝大部分基本操作都是按照官方教程走就可以了，碰到了一部分问题教程没有写的，记录备忘。

1. 系统安装按照教程指定16.04，不过我安装的是ubuntu server版本，只安装了基本的包，可能下面部分问题跟这个有关系。
2. `make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- licheepi_nano_spiflash_defconfig`步骤，报错`The program 'make' can be found in the following packages:`，可能就是系统包太精简，`sudo apt-get install make`即可。
3. 报错`scripts/kconfig/lxdialog/dialog.h:26:20: fatal error: curses.h: No such file or directory`，解决办法`sudo apt-get install libncurses5-dev`
4. `make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- -j2`报错`/bin/sh: 1: python: not found`，解决办法`sudo apt-get install python`，默认安装的是python2.7版本
5. 继续报错`unable to execute 'swig': No such file or directory`，解决办法`sudo apt install swig`
6. 继续报错`scripts/dtc/pylibfdt/libfdt_wrap.c:147:21: fatal error: Python.h: No such file or directory`，解决办法`sudo apt-get install python-dev`
7. 编译烧录工具sunxi-tools的时候，报错`fel.c:32:18: fatal error: zlib.h: No such file or directory`，解决办法`sudo apt-get install zlib1g-dev`
8. 继续报错`fel_lib.c:26:20: fatal error: libusb.h: No such file or directory`，官方给的`sudo apt-get install libusb-1.0-0-dev`不管用，`sudo apt-get install build-essential pkg-config`解决

OK，解决上述问题后，编译完成

