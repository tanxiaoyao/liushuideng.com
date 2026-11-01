---
title: "OrangePi Zero安装Armbian"
published: 2023-05-28
description: "最近又把OrangePi折腾起来了，这次是给它换一个Armbian的系统，记录备忘。 1. Armbian官网下载系统烧写到SD卡，启动后用户名root，密码1"
image: "https://cdn.armbian.com/wp-content/uploads/2018/03/logo2.png"
tags: ["嵌入式-底软开发-Linux-OrangePi"]
category: ""
draft: false
---

最近又把OrangePi折腾起来了，这次是给它换一个Armbian的系统，记录备忘。

1. Armbian官网下载系统烧写到SD卡，启动后用户名root，密码1234，根据提示更改密码，创建用户。
2. 更改apt源为国内源
```json
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ buster main contrib non-free
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ buster main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ buster-updates main contrib non-free
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ buster-updates main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ buster-backports main contrib non-free
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ buster-backports main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security buster/updates main contrib non-free
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian-security buster/updates main contrib non-free
```
3. 修改wifi网络连接，首先备份interface
```sh
sudo cp /etc/network/interfaces /etc/network/interfaces_bak
```
4. 修改interfaces文件为以下内容
```sh
auto lo
iface lo inet loopback

auto eth0
allow-hotplug eth0
iface eth0 inet dhcp

auto wlan0
allow-hotplug wlan0
iface wlan0 inet manual
wpa-roam /etc/wpa_supplicant/wpa_supplicant.conf
iface default inet dhcp
   ```
5. 在/etc/wpa_supplicant/目录下创建wpa_supplicant.conf，`sudo vim /etc/wpa_supplicant/wpa_supplicant.conf`，写入如下内容：
```sh
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
network={
ssid="wifi名称"
psk="xxxxxxx"
}
   ```
其中network这一块，使用`wpa_passphrase wifi名称 wifi密码`即可生成。

6. 重启即可，ssh等其他配置可以使用armbian-config设置。
