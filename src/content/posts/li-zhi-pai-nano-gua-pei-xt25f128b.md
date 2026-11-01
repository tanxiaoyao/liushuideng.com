---
title: "荔枝派Nano适配xt25f128b"
published: 2023-05-25
description: "早期购买Nano的人，板子上用的是Winbond的Flash芯片，后来Winbond芯片涨价，后买的板子上换成了国产的xt25f128b，大小规格一样，但是！官"
image: "http://www.xtxtech.com/u_file/photo/20200708/06b7aeb391.png"
tags: ["嵌入式-底软开发-Linux-lichee"]
category: ""
draft: false
---

早期购买Nano的人，板子上用的是Winbond的Flash芯片，后来Winbond芯片涨价，后买的板子上换成了国产的xt25f128b，大小规格一样，但是！官方的教程竟然不提这个事情，所以按照教程一路默认下来的操作启动后就报如下的错误：

```shell
SF: unrecognized JEDEC id bytes: 0b, 40, 18                                     
*** Warning - spi_flash_probe_bus_cs() failed, using default environment        
```

Flash型号不识别，这得改uboot代码的dts设备树文件，经过一通百度操作如下：

1. 修改驱动文件./drivers/mtd/spi/spi_flash_ids.c

   ```c
   {"w25q128fw",      INFO(0xef6018, 0x0,  64 * 1024,   256, RD_FULL | WR_QPP | SECT_4K) },
   ```

   之后添加一行

   ```c
   {"xt25f128b",      INFO(0x0b4018, 0x0,  64 * 1024,   256, RD_FULL | WR_QPP | SECT_4K) },
   ```

2. 修改dts设备树文件./arch/arm/dts/suniv-f1c100s-licheepi-nano.dts

   ```c
   compatible = "winbond,w25q128", "jedec,spi-nor";
   ```

   修改为

   ```c
   compatible = "winbond,xt25f128b", "jedec,spi-nor";
   ```

3. 然后重新编译uboot `make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- -j2`

4. 重新下载uboot，因为这个时候不能正常识别spi flash，所以之前博客中介绍的命令行擦除flash进入fel模式的方法行不通了，只能通过短接1脚上电的方式进，然后`sudo sunxi-fel -p spiflash-write 0 u-boot-sunxi-with-spl.bin`下载uboot

5. 重新启动后进入uboot，测试bdinfo命令正常

   ```bash
   => bdinfo                                                                       
   arch_number = 0x00000000                                                        
   boot_params = 0x80000100                                                        
   DRAM bank   = 0x00000000                                                        
   -> start    = 0x80000000                                                        
   -> size     = 0x02000000                                                        
   baudrate    = 115200 bps                                                        
   TLB addr    = 0x81FF0000                                                        
   relocaddr   = 0x81F75000                                                        
   reloc off   = 0x00875000                                                        
   irq_sp      = 0x81E6AD50                                                        
   sp start    = 0x81E6AD40                                                        
   Early malloc usage: 118 / 400                                                   
   fdt_blob = 81e6ad68                                                             
   ```



为什么没有进linux命令行？因为这里我们只烧录了uboot，内核和根文件系统烧了才能进linux，下篇博客继续。



