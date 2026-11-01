---
title: "荔枝派Nano烧录Uboot指南"
published: 2023-05-25
description: "荔枝派Uboot编译好之后，下载基本按照教程，但是还是碰到了不少问题官方教程没提到的。 1. 首先教程竟然没说下载要用数据线直接连接下载，并且先要在连接串口线擦"
image: "https://wiki.sipeed.com/soft/Lichee/zh/Nano-Doc-Backup/static/lichee-nano.jpg"
tags: ["嵌入式-底软开发-Linux-lichee"]
category: ""
draft: false
---

荔枝派Uboot编译好之后，下载基本按照教程，但是还是碰到了不少问题官方教程没提到的。

1. 首先教程竟然没说下载要用数据线直接连接下载，并且先要在连接串口线擦除先SPI Flash，我研究了好久才整清楚。

2. 如果按照教程操作，首先碰到USB连接开发板之后，输入`sunxi-fel uboot u-boot-sunxi-with-spl.bin`报错`ERROR: Allwinner USB FEL device not found!`，这个时候短接Flash芯片的CS脚(1脚)到GND重新上电启动可以进入FEL模式，或者擦除Flash也行，操作如下：

   1. 串口连接开发板上电，波特率115200，出现如下`Hit any key to stop autoboot`时，敲回车终止启动

      ![image-20210418124317112](https://image.liushuideng.com/images/blog/image-20210418124317112.png)

   2. 命令擦除flash

      ```bash
      sf probe 0
      sf erase 0 0x100000
      reset
      ```

   3. 然后重新插拔下USB线，注意这里有个坑，如果开发板上插了TF卡，一定要先拔下来，否则没有反应。插上后，lsusb命令看到`Onda (unverified) V972 tablet in flashing mode`字样说明USB连接没问题。

      ```shell
      txy@ubuntu:~/nano/u-boot$ lsusb
      Bus 002 Device 002: ID 8087:0020 Intel Corp. Integrated Rate Matching Hub
      Bus 002 Device 001: ID 1d6b:0002 Linux Foundation 2.0 root hub
      Bus 001 Device 006: ID 17ef:4816 Lenovo Integrated Webcam
      Bus 001 Device 005: ID 0a5c:217f Broadcom Corp. BCM2045B (BDC-2.1)
      Bus 001 Device 027: ID 0925:3881 Lakeview Research Saleae Logic
      Bus 001 Device 036: ID 0451:f432 Texas Instruments, Inc. eZ430 Development Tool
      Bus 001 Device 038: ID 1f3a:efe8 Onda (unverified) V972 tablet in flashing mode
      Bus 001 Device 011: ID 05e3:0610 Genesys Logic, Inc. 4-port hub
      Bus 001 Device 002: ID 8087:0020 Intel Corp. Integrated Rate Matching Hub
      Bus 001 Device 001: ID 1d6b:0002 Linux Foundation 2.0 root hub
      ```

   4. 然后下载工具可以识别即可

      ```shell
      txy@ubuntu:~/nano/u-boot$ sudo sunxi-fel ver
      AWUSBFEX soc=00001663(F1C100s) 00000001 ver=0001 44 08 scratchpad=00007e00 00000000 00000000
      ```

      OK，烧录完成

      ```shell
      txy@ubuntu:~/nano/u-boot$ sudo sunxi-fel -p spiflash-write 0 u-boot-sunxi-with-spl.bin
      100% [================================================]  1008 kB,   98.6 kB/s
      ```

   5. 重新插拔USB线启动，结果报错如下：

      ```shell
      SF: unrecognized JEDEC id bytes: 0b, 40, 18                                     
      *** Warning - spi_flash_probe_bus_cs() failed, using default environment        
      ```

      这个问题再另起一个帖子记录吧