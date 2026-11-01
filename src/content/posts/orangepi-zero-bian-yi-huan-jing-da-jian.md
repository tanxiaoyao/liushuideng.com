---
title: "OrangePi Zero编译环境搭建"
published: 2023-05-28
description: "PS:别看orange pi zero这块板子便宜，但实际上相关的资料非常少，社区和论坛的讨论也少之又少，所以不推荐完全没有linux基础的新手使用这块板子上手"
image: "http://www.orangepi.org/img/img4/banner-ZRO-LTS.jpg"
tags: ["嵌入式-底软开发-Linux-OrangePi"]
category: ""
draft: false
---

> PS:别看orange pi zero这块板子便宜，但实际上相关的资料非常少，社区和论坛的讨论也少之又少，所以不推荐完全没有linux基础的新手使用这块板子上手。恰好我手中有一块树莓派3B，下面搭建编译环境光前面6步我就遇到了重重阻力，等利用树莓派上手熟悉之后再更新吧。


# 环境准备
编译环境 Ubuntu 16.04 64位

# 搭建步骤
1. git下载git@github.com:orangepi-xunlong/OrangePi_Build.git。
2. sudo apt-get install unzip curl，安装所需要的curl和unzip程序。
3. 进入OrangePi_Build，运行Build_OrangePi.sh脚本，按照指示下载源码。
4. 进入OrangePiH2/scripts目录，修改make_kernel函数的下列两处：

```sh
make -j ARCH=arm CROSS_COMPILE=${cross_comp}- uImage
修改为
make -j 4 ARCH=arm CROSS_COMPILE=${cross_comp}- uImage

make -j ARCH=arm CROSS_COMPILE=${cross_comp}- modules
修改为
make -j 4 ARCH=arm CROSS_COMPILE=${cross_comp}- modules
```

添加一个4限制编译最大任务数，可根据CPU核数修改，否则会在编译kernel的时候内存占用率直接占满导致电脑卡死，官方到目前还没有勘误。uboot的编译脚本没有这个问题。

5. 同样该目录下，修改Prepare_toolchain.sh，将lib32stdc++修改为lib32stdc++6，否则在我的机器上会出现下列错误:
```c
The following packages have unmet dependencies:
lib32stdc++6-4.8-dbg : Conflicts: lib32stdc++6-4.7-dbg but 4.7.4-3ubuntu12 is to be installed
lib32stdc++6-4.9-dbg : Conflicts: lib32stdc++6-4.7-dbg but 4.7.4-3ubuntu12 is to be installed
Conflicts: lib32stdc++6-4.8-dbg but 4.8.5-4ubuntu4 is to be installed
lib32stdc++6-5-dbg : Conflicts: lib32stdc++6-4.7-dbg but 4.7.4-3ubuntu12 is to be installed
Conflicts: lib32stdc++6-4.8-dbg but 4.8.5-4ubuntu4 is to be installed
Conflicts: lib32stdc++6-4.9-dbg but 4.9.4-2ubuntu1 is to be installed
lib32stdc++6-5-dbg-s390x-cross : Conflicts: lib32stdc++6-4.9-dbg-s390x-cross but 4.9.3-13ubuntu2cross1 is to be installed
lib32stdc++6-6-dbg : Conflicts: lib32stdc++6-4.7-dbg but 4.7.4-3ubuntu12 is to be installed
Conflicts: lib32stdc++6-4.8-dbg but 4.8.5-4ubuntu4 is to be installed
Conflicts: lib32stdc++6-4.9-dbg but 4.9.4-2ubuntu1 is to be installed
Conflicts: lib32stdc++6-5-dbg but 5.4.1-8ubuntu1 is to be installed
lib32stdc++6-6-dbg-mips64-cross : Conflicts: lib32stdc++6-5-dbg-mips64-cross but 5.4.1-2ubuntu2cross1 is to be installed
lib32stdc++6-6-dbg-mips64el-cross : Conflicts: lib32stdc++6-5-dbg-mips64el-cross but 5.4.1-2ubuntu2cross1 is to be installed
lib32stdc++6-6-dbg-ppc64-cross : Conflicts: lib32stdc++6-5-dbg-ppc64-cross but 5.4.1-2ubuntu2cross1 is to be installed
lib32stdc++6-6-dbg-s390x-cross : Conflicts: lib32stdc++6-4.9-dbg-s390x-cross but 4.9.3-13ubuntu2cross1 is to be installed
Conflicts: lib32stdc++6-5-dbg-s390x-cross but 5.4.1-8ubuntu1cross1 is to be installed
lib32stdc++6-6-dbg-sparc64-cross : Conflicts: lib32stdc++6-5-dbg-sparc64-cross but 5.4.1-2ubuntu2cross1 is to be installed
E: Unable to correct problems, you have held broken packages.
```

是否官方错误不确定，经验所得。这些坑挺容易浪费新手大量时间。


6. 准备工作完毕，OrangePiH2下执行./build.sh即可编译相关模块。

