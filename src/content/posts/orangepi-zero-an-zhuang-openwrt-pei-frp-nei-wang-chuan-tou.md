---
title: "OrangePi Zero安装openwrt配FRP内网穿透"
published: 2023-05-28
description: "由于家里的宽带没有公网IP，所以在外面访问自己的电脑就成了问题，虽然有TeamViewer，但是它经常性的断连更新密码，老是各种连不上，所以还是FRP内网穿透方"
image: "https://image.liushuideng.com/images/blog/orangepi_frp_server_view.png"
tags: ["嵌入式-底软开发-Linux-OrangePi"]
category: ""
draft: false
---

> 由于家里的宽带没有公网IP，所以在外面访问自己的电脑就成了问题，虽然有TeamViewer，但是它经常性的断连更新密码，老是各种连不上，所以还是FRP内网穿透方便，刚好手里有个OrangePi，正好可以利用起来。

# 原理介绍

内网穿透就是当你家的宽带没有公网IP的时候，你在外面想连接家里的电脑或者摄像头或者NAS什么的，就没有办法连接。此时一种办法就是和宽带的客服battle，看能不能给你提供一个公网IP。如果失败，另一个招就是使用FRP进行内网穿透。FRP就是需要你有一台具有公网IP的服务器，比如阿里云、腾讯云，然后利用这个VPS当跳板，这样就能利用VPS的公网IP访问到你的内网设备。

# 材料准备

1. VPS:从原理上我们知道需要准备一个带有公网IP的VPS，国内的阿里云、腾讯云等最好，国外的VPS也可以但是通常延迟会很大，搭好以后操作比较卡顿体验很差。我自己测试过国外的VPS延迟一般在280~300ms左右，国内的腾讯云在40~50ms左右，你自己可以ping一下他的公网IP试试，实际体验我认为20ms以内最好，最大不超过100ms。实际上，如果你哪个朋友家里有公网IP，利用他家里的电脑也可以作为服务端，不过这个很难满足，暂不讨论。
2. 本地客户端：家里的内网需要有个设备作为客户端，和服务端配合完成协议的中转，有些人动手能力比较强，可以把自己的路由器刷成openwrt的系统，用它作为客户端，有人直接运行在自己的windows电脑上作为客户端。我这里就是用的一个OragenPi做的，相信你能看到这个博客大概率是通过OrangePi搜索进来的，我们就只写这种情况，另外你需要准备读卡器，大于1G的TF卡。

# 操作步骤
## 服务端安装
下载FRP服务端，一般大家申请的VPS都是linux系统的，到FRP的[GITHUB地址](https://github.com/fatedier/frp/releases)下载最新的版本，linux服务器下载下图中的386或者64版本，视你的系统是32还是64位系统而定，不清楚的统一选择386即可。

![](https://image.liushuideng.com/images/blog/orangepi_frp_download.png)

解压下载的压缩包，因为做服务端，所以我们只需要里面的frps和frps.ini两个文件，把它上传到你VPS的/usr/local/frp目录中，修改frps.ini文件内容如下：

```ini
[common]
bind_port = 17000

dashboard_port = 17500
dashboard_user = 网页控制台用户名
dashboard_pwd = 网页控制台密码


vhost_http_port = 4000
vhost_https_port = 4001
max_pool_count = 50


token = xxxxxxxxxxxxxxxxxxx

tcp_mux = true


log_file = ./frps.log
log_level = info
log_max_days = 3

authentication_timeout = 0
privilege_mode = true

```
上面的17000是你服务器和客户端通信使用的端口，17500是网页查看服务器状态的时候使用的端口，下面的用户名密码这些都可以根据你自己的喜好配置。token是服务端和客户端通信认证用的，到时候两个必须要填的一样。其他的选项保持不动即可。

## 开放服务器的防火墙端口
刚才我们配置使用了17000 17500 4000 4001这些端口，我们要在服务器上开放这些端口，否则访问不了，我的是centos系统，操作如下，其他的发行版自己搜索对应的防火墙添加端口命令。
```sh
# 列出系统当前开放的端口号
firewall-cmd --list-port
# 添加端口，其他的端口类似操作即可
firewall-cmd --zone=public --add-port=17000/tcp --permanent
# 重启防火墙使规则生效
firewall-cmd --reload
# 再次查看对应端口好是否打开
firewall-cmd --list-port
```

## 开启服务器
执行下列操作确定FRP服务器
```sh
cd /usr/local/frp
chmod +x *
nohup ./frps -c frps.ini > /dev/null   2>&1  &
```
最后一句是通过nohup命令后台运行frp，服务器重启后需要重新执行，嫌麻烦的可以搜索怎么添加到linux的开机启动中，这里不啰嗦了。
启动完成后，访问你的公网IP：端口号测试服务器是否可以访问，比如： 123.123.123.123:17500，如果配置正常应该如下图：
![orangepi_frp_server_view](https://image.liushuideng.com/images/blog/orangepi_frp_server_view.png)

## OrangePi安装OpenWRT系统
网上已经有人专门发布基于OrangePi Zero打包的OpenWRT系统了，直接点击[pulpstone](http://pulpstone.pw/)网站下载对应的版本。网站有可能改版，需要你自己找下下图所示的链接下载：

![orangepi_openwrt_img](https://image.liushuideng.com/images/blog/orangepi_openwrt_img.png)

下载之后解压，用软件把解压出的img镜像文件烧写到SD卡中，烧写软件我用的是树莓派官方推荐的[imager.exe](https://downloads.raspberrypi.org/imager/imager.exe)。

安装后启动，默认用户名密码是root,root

## OrangePi安装frp客户端
同样从上面的GITHUB地址中下载arm的压缩包，解压后我们只需要frpc和frpc.ini文件，同样上传到OrangePi的/usr/local/frp中，frpc.ini修改如下：

```ini
[common]
server_addr = xxx.xxx.xxx.xxx
server_port = 17000
log_file = ./frpc.log
token = xxxxxxxxxxxxxxxxxxx
login_fail_exit = false

[ssh]
type = tcp
local_ip = 192.168.124.8
local_port = 22
remote_port = 17522

[mstsc]
type = tcp
local_ip = 192.168.124.6
local_port = 3389
remote_port = 17589
use_encryption = true
use_compression = true
```
修改上面的xxx字样部分为你自己服务器的ip、端口以及token，然后下面的我映射了我自己OrangePi的ssh端口和我windows电脑的远程桌面3389端口，分别映射到远程服务器的17522和17589端口，因此，我们需要到远程VPS的机器上，再把17522和17589端口打开防火墙，操作和上面一样。

## 启动客户端并设置开启自启

手动启动测试下，命令如下：

```bash
cd /usr/frpc
./frpc -c frpc.ini
```

操作完成后，既可以测试内网穿透效果了，比如ssh端口测试如下：

![orangepi_frp_ssh_view](https://image.liushuideng.com/images/blog/orangepi_frp_ssh_view.png)

远程桌面测试如下：

![orangepi_frp_mstsc_view](https://image.liushuideng.com/images/blog/orangepi_frp_mstsc_view.png)

测试完成没问题可以通之后，可以登陆frp的网页管理端，在浏览器输入openwrt的IP地址，弹出登陆界面：

![orangepi_frp_web_view](https://image.liushuideng.com/images/blog/orangepi_frp_web_view.png)

输入root密码之后，在系统-启动项里面，填入如下命令：

```bash
cd /usr/frpc
./frpc -c frpc.ini &
```

![orangepi_frp_bootscript](https://image.liushuideng.com/images/blog/orangepi_frp_bootscript.png)

这样在orangepi断电重启之后，会自动在后台启动frp服务，不用手动起了。

OK，到此就可以完成内网穿透了，买了独立域名的还可以配置域名跳转到服务器IP，这样就可以使用域名+端口号访问了，不用记IP。不过我这里个人感觉意义不大没有试，感兴趣的可以自行google试试。