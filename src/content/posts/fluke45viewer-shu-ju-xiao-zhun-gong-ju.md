---
title: "Fluke45Viewer数据校准工具"
published: 2023-07-14
description: "需求背景 Fluke45是一台我之前常用的数字式万用表，平时做东西的过程中经常使用它来帮助我进行数据校准工作。Fluke45精度为四位半，具有两个显示区域，可以"
image: "https://image.liushuideng.com/images/blog/fluke45_pic.png"
tags: ["效率工具-硬件工具"]
category: ""
draft: false
---

## 需求背景
Fluke45是一台我之前常用的数字式万用表，平时做东西的过程中经常使用它来帮助我进行数据校准工作。Fluke45精度为四位半，具有两个显示区域，可以同时进行电压电流的测量。在进行设计的过程中，数据校准往往很花费时间，而且一旦进行硬件电路的改动（尤其是采样部分电路的改动），往往意味着数据需要全盘重新校准，为了节省人力和时间，我开发和设计了一个简单的小工具Fluke45Viewer，协助我们进行校准。

![fluke45_pic](https://image.liushuideng.com/images/blog/fluke45_pic.png)
我们校准数据一般进行这样的操作，读取自己做的板子液晶屏上的测量数据，再读取万用表的数据，然后抄到EXCEL里面，如此反复。采集到足够多的数据以后进行直线拟合就行了，但是读取、记录数据的这个过程相当繁琐而且很浪费时间，这往往需要两个人的配合，在紧张的竞赛的比赛现场，这是很“奢侈”的浪费，所以如果能够使用工具解决，这样能少浪费很多时间。

## 框架设计

本工具设计的原理就是使用程序代替人去进行数据的读取、记录、计算这三个关键动作。

  **数据读取**：单片机方面采用串口对要监视的数据进行读取，万用表后面提供了串口，我们可以从这个地方下手。

  **数据记录**：自己在上位机中实现一个简单的界面存储显示数据。

  **数据计算**：线性拟合，实现一个简单的最小二乘法计算即可。

上述三个关键过程的简单流程框图如下：

![fluke45viewer_flow](https://image.liushuideng.com/images/blog/fluke45viewer_flow.png)

PC和单片机之间有两条路径，一个是直接USB转串口的线连接过去，一个是使用蓝牙模块无线连接。使用无线的目的是我们单片机在控制电力变化这样的板子的时候经常会碰到问题，经常出现主路上的大电压大电流串到单片机上来了，如果直连电脑，可能会烧毁电脑（这是有经验和教训的），所以使用无线方式更安全常见的串口线和蓝牙无线模块如下：

![adapter](https://image.liushuideng.com/images/blog/adapter.png)

## 上位机实现

上位机实现有几个要点：1、怎么把万用表的数据读出来？2、读出来了怎么存储、计算3、如何合适的设计单片机的下位机接口，让用户方便快捷的将要监视的数据发送出来。针对以上几点，我们一点点解决：

### 万用表读取

Fluke45背后提供了一个串口（很多高级的台表后面都有），我们可以通过这个串口把据读取出来，虽然每种表的读取方法不同，但是本文的思想都是通用的，大家按照实际情况发挥。Fluke官方网站很遗憾，翻了一下没找到相关的文档介绍怎么读取，可能在某个维修文档上面有吧，但是很幸运，我们在网上找到了下面这个东西：

http://www.pudn.com/downloads572/sourcecode/windows/csharp/detail2351554.html

里面介绍了使用C#读取这个万用表，那我们也可以这样读取。这个工程打开是这样的：

![project_view](https://image.liushuideng.com/images/blog/project_view.png)

Devices抽象了Fluke45的核心功能，VirtualInstrument介绍了怎么去使用读取等操作命令，这些该有的就都有了，我们可以开始我们自己的程序设计了。

![main_frame](https://image.liushuideng.com/images/blog/main_frame.png)

首先用VS的界面工具拖个简单的框架，然后开始写内部的工具。内部主要责任就是两块：读取万用表数据、读取下位机数据。读取万用表数据这里就不讲了，大致思路就是用C#开串口，按照万用表规定好的格式给它发读取指令，万用表就会吐出一个值。具体方法参照本工具的源码和VirtualInstrument的源码（其实这部分基本都是照抄VirtualInstrument），然后读取下位机我们接下来介绍。

### 单片机数据读取

单片机数据读取的方法怎么读都可以，这里使用串口。串口读取肯定由上位机来发起，我们设计的简单点，假定发送一个C字符是表示上位机要读取数据（为什么是C？那总得是一个值吧，如果C你不喜欢，其他都可以呀。。），然后我们在单片机的代码里设计一个串口中断，收到串口数据数据后判断是不是C，是的话就把监视的数据值通过串口返回出去。以MSP430为例，核心代码如下：

```c
/***************接收字符串*************************/
char *tempStr;
char buffer[32] = "";
void getStringFVT() {
	//判断上位机发送的请求验证符（为了加快速度及验证简便，仅用一个c字符验证）
	if (UCA1RXBUF != 'c') {				
		*tempStr = UCA1RXBUF;
		tempStr++;
	} else {
		sprintf(buffer, "%lf=>\n", *monitorData);	//double转string
		printStringFVT(buffer);
	}
}
```
串口中断这部分根据你使用的单片机不同自行编写，这个应该都不是问题。然后就是数据监视这一块了，这个东西处于简便快捷考虑，我设计了一个Bind函数，用户只需要调用这个函数指定你要监视那个数据就可以了。所以最简单的方法就是：指针直接指向你要看的内存，核心代码如下：

```c
//监视的数据，bind的时候将目标数的指针传过来就可以实现实时跟踪了
double *monitorData;
/*****************绑定要监视的数据***************************/
void bindDataFVT(double *sendData) {
	monitorData = sendData;
}
```

我们适配的代码里自己声明一个指针，然后用户告诉我这个指针指向谁就OK。以后收到上位机指定，我就把指针指向的值发出去，使用方法如下：

```c
int main(void) {
    WDTCTL = WDTPW | WDTHOLD;	// Stop watchdog timer
	
    double testValue = 0.1;

    initFVT();
    bindDataFVT(&testValue);

    while(1)
    {
    	if(testValue < 9999)
    		testValue += testValue;
    	else
    		testValue = 0.1;
    }

	return 0;
}
```

testValue是我要监视的数据，初始化FVT之后，bind一下它的地址就行。通过这个原理可以看到，这个工具使用的限制就是被监视的数据地址不能发生变化（换言之就是全局变量），当然这里的testValue不是全局变量，可以使用的原因是因为这是main程序，内部死循环永远不会退出，是函数的局部变量，申请在栈内存上，函数不退它不会失效，所以这里没失效，大家平时使用最好绑定到一个函数外的全局变量上。

## 使用效果及源码下载

![total_view](https://image.liushuideng.com/images/blog/total_view.png)

目前实现了MSP430和TIVA版本的下位机，其他单片机平台欢迎大家补充：

[源码下载地址](https://gitee.com/tanxiaoyao/FLUKE45_VIEWR_RELEASE)

