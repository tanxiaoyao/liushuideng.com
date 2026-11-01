---
title: "荔枝派Nano内核编译"
published: 2023-05-25
description: "上文编译好uboot之后，想刷内核和根文件系统进去。其实官方的网盘里面，已经有打包好的系统镜像，包含所有的东西，可以直接烧录进flash或者TF卡，但是都是基于"
image: "https://wiki.sipeed.com/soft/Lichee/zh/Nano-Doc-Backup/static/lichee-nano.jpg"
tags: ["嵌入式-底软开发-Linux-lichee"]
category: ""
draft: false
---

上文编译好uboot之后，想刷内核和根文件系统进去。其实官方的网盘里面，已经有打包好的系统镜像，包含所有的东西，可以直接烧录进flash或者TF卡，但是都是基于winbond芯片的，国产的xt25f128b刷进去妥妥的`SF: unrecognized JEDEC id bytes: 0b, 40, 18`。所以没办法，只能自己再动手重新编译内核了。(PS：搞的我都想直接买一片w25q128换上了，有点麻烦，希望官方直接涨价或者出两版就行，不然对新手不友好啊)

# 分区规划表

之前烧录uboot的命令`sudo sunxi-fel -p spiflash-write 0 u-boot-sunxi-with-spl.bin`里面，参数0是直接指定从flash的0x00000000地址开始烧录，现在我们要烧内核了，要对16M的flash做个规划了，按照官方教程的规划如下：

| 分区序号 | 分区大小        | 分区作用   | 地址空间及分区名               |
| -------- | --------------- | ---------- | ------------------------------ |
| mtd0     | 1MB (0x100000)  | spl+uboot  | 0x0000000-0x0100000 : “uboot”  |
| mtd1     | 64KB (0x10000)  | dtb文件    | 0x0100000-0x0110000 : “dtb”    |
| mtd2     | 4MB (0x400000)  | linux内核  | 0x0110000-0x0510000 : “kernel” |
| mtd3     | 剩余 (0xAF0000) | 根文件系统 | 0x0510000-0x1000000 : “rootfs” |

这个其实就是大致划分了4段而已，我们照着官方教程操作就O了

# linux内核编译

官方教程地址:http://nano.lichee.pro/build_sys/kernel.html

果然没这么顺利，编译过程中报错

`scripts/extract-cert.c:21:25: fatal error: openssl/bio.h: No such file or directory`

因为没安装ssl，`sudo apt-get install libssl-dev`安装

继续报错`/bin/sh: 1: bc: not found`，通过`sudo apt install bc`安装

编译OK，但是教程最后一句

“生成的 zImage 在 arch ‣ arm ‣ boot 目录下；将其放入第一分区。”

这个让人摸不着头脑，怎么放？第一分区指的是mtd2？--------其实这个指的是使用TF卡的，spi flash的看这个：http://nano.lichee.pro/build_sys/build_flash.html#id3





