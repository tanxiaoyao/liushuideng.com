---
title: "MSP430时钟树"
published: 2023-05-23
description: "本文从电路级的角度讲解了430的三种时钟源的来源及内部分频使用过程，有助于深入了解常见单片机片上系统时钟的基本构造。如果是初学者，建议不着急看这部分内容，根据例"
image: "https://image.liushuideng.com/images/blog/430_clock_tree_schme.png"
tags: ["嵌入式-底软开发-单片机-MSP430"]
category: ""
draft: false
---

> 本文从电路级的角度讲解了430的三种时钟源的来源及内部分频使用过程，有助于深入了解常见单片机片上系统时钟的基本构造。如果是初学者，建议不着急看这部分内容，根据例程照写即可，先学功能，熟练后在学原理。
>> 本文主要内容，来源于官方[MSP430x2xx Family User's Guide](http://www.ti.com.cn/cn/lit/ug/slau144j/slau144j.pdf)文档Basic Clock Module章节。

# MSP430的时钟

MSP430有四种时钟源和三种时钟，分别介绍：

## 时钟源

- LFXT1CLK，默认可以接一个标准低频(32.768kHz)的钟表上的晶振，用于计时等应用，也可以通过外接 400kHz～16MHz 的高速晶体振荡器或谐振器工作在高频模式（根据单片机的型号不同，最高有的只能到8M）。  
- XT2CLK，外接高频晶振（400kHz～16MHz）。  
- DCOCLK，内部数控 RC 振荡器，由内部的一个RC电路振荡产生。  
- VLOCLK，内部的超低频超低功耗振荡时钟，一般只有12kHz左右（实际不准）。

是不是有点懵，怎么这么多，其实他们各有特点，我们一般选择其中一种或者两种来使用，一般不会全用到他们。这四种模式，LFXT1CLK和XT2CLK记住都是要外界晶振的，**很多新手代码配置使用这两种时钟但是电路不接晶振，后果就是CPU不能运行，感觉代码没往下走，仿真器调试也走不动**，LFXT1CLK接的是低频晶振（你接个上MHz高频的也可以，不超过范围就可以），XT2CLK接的是高频晶振，在高级一些的430上的接法一般如下：

![430_two_clock_oscillator](https://image.liushuideng.com/images/blog/430_two_clock_oscillator.png)

圆柱形的就是低频晶振，椭圆形的就是高频的。在Launchpad上，位置在这里：

![430_two_clock_position](https://image.liushuideng.com/images/blog/430_two_clock_position.png)

看到没，这两个位置是重叠的，引脚也连在一起，说明只能二选一，而且新买的板子开箱是没有帮你焊接晶振的，所以这也是为什么很多人代码跑不起来的原因，箱子里自带的一个小袋子里有个很小的金黄色晶振，可以自己焊上（引脚很细，不会焊接的同学考验你们动手能力的时候来了）。

![430_launchpad_osc](https://image.liushuideng.com/images/blog/430_launchpad_osc.png)

DCOCLK和VLOCLK是内部振荡电路产生的时钟，所以不需要外接晶振。学过模拟电路的会知道RC电路可以产生振荡，振荡的频率跟所用的电阻和电容有关。而材料的电阻和电容一般情况下会有"温漂"，温度变化会导致电阻和电容变化。所以，这两种时钟跟前面两种相比**最大的特点就是不稳定**，夏天和冬天出来的频率值可能就差很多，或者用手摸一下，把单片机摸热，频率就漂了。如果你需要产生精准的定时、波形频率或者CPU频率，**请使用晶振**。（有些特殊场景下，还有恒温晶振，也就是说晶振也有温漂，只不过比较小而已，工业军工场景要求更严苛，恒温晶振内部有恒温电路保持晶振温度不变来减小这种偏差，不过430这种level的芯片一般用不上，FPGA用的多）。另外，VLOCLK是固定的，DCOCLK可以通过调节内部直流电压控制产生的频率。

## 时钟类型

MSP430上有三种时钟，辅助时钟ACLK（Auxillary Clock），系统主时钟MCLK(Main Clock)，子系统时钟SMCLK(Sub-System Clock)。他们的来源无外乎从上面几种时钟源里选择，区别主要在于用途不同，ACLK一般用于低速的外设，比如低速的定时器、串口等；MCLK可以理解为主要用在CPU运行上，当然也可以输送给一些高速外设使用；SMCLK则是专门给高速外设准备的了，比如高速的定时器（这里不是说有高低速两个定时器，而是定时器工作在高速时钟还是低速时钟），SPI接口等。

如果这种解释还不清晰，画个图就明白了：

![430_osc2clock](https://image.liushuideng.com/images/blog/430_osc2clock.png)

可以看到TI限制了ACLK只能从低频的两个时钟源里面选择，MCLK和SMCLK的可以随便选择。实际电路中肯定不是这里直接用线连接这么简单，中间有一坨电路主要有两个功能：1、实现图中箭头所示的选择功能。2、分频。具体要讲就要上电路图了，推荐看之前有了解一些基本的数字电路知识（了解下图中那个梯形的复用器就行了，就是个选择开关）。

![430_clock_tree_schme](https://image.liushuideng.com/images/blog/430_clock_tree_schme.png)

讲电路之前，简单介绍下复用器的基本知识，不然不知道下面图里面是什么，以及写代码那一大堆的XXX = BIT0在干啥。截一个复用器如下：

![430_clock_mux](https://image.liushuideng.com/images/blog/430_clock_mux.png)

这玩意其实就是一个开关，上面有两个输入，这里用的寄存器SELMx表示，我们知道二进制两位可以表示4种情况00 01 10 11，看到没，它有四个输入引线，一个输出，每种数字就代表把一种数据接到输出去，SELMx就是这个起决定作用的东西。所以，我们编程看到文档里面对于寄存器经常是这么介绍的：

![430_clock_mux_reg](https://image.liushuideng.com/images/blog/430_clock_mux_reg.png)

弄个8位或者32位寄存器的表格，然后列表告诉你某种功能怎么配，初学者不用了解原理，按照表格弄就可以了。稍微深入一点的就会知道，这就是在折腾上面那一坨选择开关，把电路组成我们想要的功能。

## 时钟产生

好，言归正传，看看四种时钟：  
- 先看VLOCLK，第一个画红框的，产生画的很简单，内部低功耗低频振荡器(Internal LP/LF Oscillator)，至于内部什么结构做到低功耗的，那就是TI的黑科技了。  
- 再来看LFXT1CLK，看起来很复杂，就是外部晶振(XIN和XOUT接的)接到起振电路(黑框里的，有负载电容和正反馈电路，里面每个英文单词引脚就是一个寄存器，软件可以配置，先不管)，起振后信号从XIN那里的连线输出到放大和滤波器(Min Pulse Filter)就得到了这个时钟。  
- 再看XT2CLK，他说到底也是晶振，只不过频率高，所以黑框里的起振电路出来后经过滤波就到了箭头所指的地方，成为时钟源信号。  
- DCOCLK的产生是最复杂的，它是个压控电路，首先是VCC经过DCOR选择后通过，进入直流发生器(DC Generator，我估计内部是个电阻分压电路，或者再带个稳压，通过RSELx可以调出16种电压)，调节后的电压到达DCO，产生特定频率的振荡，MODx这里先不细讲，然后信号形成DCOCLK。

## 选择与分频

信号是怎么从晶振开始形成的将完了，第二个功能就是选择和分频。看到三个梯形没有，分别是LFXT1Sx、SELMx、SELS控制，这几个就控制ACLK、MCLK、SMCLK选啥，看过上面复用器的介绍应该就能看明白。选好后，进入Divider分频，这就是分频器，可以吧比如8M的时钟分成4M或者2M或者1M等（也可以不分频）。分频器的内部实现是触发器，这个学过数字电路的就知道，立个flag，后面专门开个分类讲数字电路。最后在过个SCG1控制的开关就OK了，SCG0可以控制直流源不产生直流电压，在不使用DCO的时候用到。（有人问用SCG1不选DCO不就搞定了，这当然是为了低功耗呀，源头不产生直流就能减小系统的电流消耗，430的低功耗是需要软件设计的，不是天生硬件就低功耗，软件随便折腾）。

好，到这里时钟树就讲完了。430比51的要复杂，51的内部就是起振和12分频电路，但是比ARM又要简单。但是这三种基本原理是一模一样的，下面是STM32的时钟图，可以看懂吗？

![430_clock_tree_stm32](https://image.liushuideng.com/images/blog/430_clock_tree_stm32.png)

## 代码实现

理解了上面的电路之后，代码就是小意思了，找下官方G2553的[code example](http://www.ti.com.cn/general/cn/docs/lit/getliterature.tsp?baseLiteratureNumber=slac485&fileType=zip)

打开\MSP430G2xx3_Code_Examples\C\msp430g2xx3_clks.c，可以看到官方写的一个时钟使用例程如下：

![430_clock_code_intro](https://image.liushuideng.com/images/blog/430_clock_code_intro.png)

示例程序的使用方法都会写在注释里，外界32kHz时钟晶振要焊接，然后P1.0输出ACLK，P1.4输出SMCLK，P1.1输出MCLK/10。C代码如下：

```c
#include <msp430.h>

int main(void)
{
  WDTCTL = WDTPW +WDTHOLD;                  // Stop Watchdog Timer
  P1DIR |= BIT0 + BIT1 + BIT4;              // P1.0,1 and P1.4 outputs
  P1SEL |= BIT0 + BIT4;                     // P1.0,4 ACLK, SMCLK output

  while(1)
  {
    P1OUT |= BIT1;    	                    // P1.1 = 1
    P1OUT &= ~BIT1;                         // P1.1 = 0
  }
}
```

纠正官方的错误，P1.1是采用在代码里面死循环反转引脚电压实现的，所以肯定也不是MCLK/10这个频率，具体多少大家可以用板子自己测试一下（可能需要示波器或者频率计或者逻辑分析仪观察）。我手上板子没有晶振，所以用PROTEUS简单新建了一个仿真工程如下：

![430_clock_simu](https://image.liushuideng.com/images/blog/430_clock_simu.png)

用虚拟示波器观察波形如图：


![430_clock_wave](https://image.liushuideng.com/images/blog/430_clock_wave.png)

仿真软件的实时性是不可靠的，但是也可以简单的看到P1.4明显不是P1.1的频率的10倍。因为仿真软件的问题，32.768kHZ的晶振不起振，所以ACLK的那跟黄色波形看不到效果。