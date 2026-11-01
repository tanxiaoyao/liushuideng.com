---
title: "MSP430之ADC"
published: 2023-05-23
description: "ADC在涉及到控制和采样的系统中，是个十分重要的组件，因为这里作为430的一个特性描述，所以通过430片上自带的ADC8来简单介绍ADC相关知识。关于ADC的详"
image: "https://image.liushuideng.com/images/blog/430_adc_struct.png"
tags: ["嵌入式-底软开发-单片机-MSP430"]
category: ""
draft: false
---

> ADC在涉及到控制和采样的系统中，是个十分重要的组件，因为这里作为430的一个特性描述，所以通过430片上自带的ADC8来简单介绍ADC相关知识。关于ADC的详细原理，各种类型，计划以后专门总结一下。

# 为什么要有ADC？

单纯的CPU是一个数字系统，内部只有0101，如果这个系统压根不跟我们现实世界打交道，完全“自娱自乐”，那就是我们常见的软件玩法。例如PC上应用软件、网页、服务器后端程序等等，。

但是比如智能手机需要通过前置光线感应器知道环境光线如何来决定是否需要提高屏幕亮度；空调需要知道室温从而精准的为你制冷或制热。这些场景则需要数字系统和模拟世界打交道了。

那ADC全称为（Analog Digital Convertor）,我的理解就是模拟世界到数字世界的转换器。反过来，DAC（Digital Analog Convertor）则是数字到模拟的转换器。

# 430 2553上的ADC模块

查看G2553的dataheet，可以看到它内置的是AD10模块，也就是一个10位精度的ADC，datasheet中只是对配置进行了简单的介绍，要看到ADC10的详细信息，我们还是要到family user guide中，找到第534页的ADC10的介绍。这里我们可以看到，ADC10具有如下特性：

- 最大200k(20万次)每秒的采样速率
- 10位采样精度无误码
- 可编程选择的内置参考源(1.5V或者2.5V)
- 8个外部采样脚
- 内部自带一个温度采样

上面只挑选了文档中几个重要的特性，200k采样速率指该ADC可以每秒钟转换20W次，这个速率已经很快了，可以满足我们大部分的需求。10位精度指ADC在将模拟量转换为数字量的时候可以达到的精度；比如ADC10的采样范围是0~3.3V，那10位精度则指可以将0～3.3V等分为2的10次方即1024等分，精度可以达到3mv左右，这也是为什么这个内置模块叫做ADC10的原因，位数越大，精度越高。内置参考源存在的意义是可以帮我们省去搭建外部参考源的麻烦，上手就用。最大8个外部采样脚可以允许我们同时采样8个外部的采样点（当然内部是公用一个ADC的，需要一个一个排队依次采样，同时采是不可能的）。最后内部自带的温度采样可以实现温度计的功能，可以做一个气温计或者跟电脑CPU温度显示一样的功能，不过这个温度采样的精度比较低，想作为精确温度采样是不行的（不过也不会有人这么做）。

# ADC10的内部结构

![430_adc_struct](https://image.liushuideng.com/images/blog/430_adc_struct.png)

看过前面430时钟那一章的理解这张图应该不难，橙色框中的是ADC10的核心，是一个SAR类型的ADC（什么是SAR后面在ADC通用介绍中细说），ADC的输入接的是一个选择开关（MUX），这个就是我们为什么可以有8个输入采样引脚以及为什么要排队采样的原因。绿色框是控制采样的，位长是4位意味着最大可以支持16个输入引脚选择，2553最大只有8个，其他型号会有更多。

信号进入ADC转换前需要经过一个叫采样保持的电路，就是橙色框sample and hoid部分，因为外部输入的信号是模拟量，所以电压是不断波动的，这样的信号不行直接进行转换，需要使用一个电路对电路瞬间采样，然后把当时的电压大小记住保持不变，再输入ADC进行转换。简单的采样保持电路内部示意图如下：

![430_adc_sh](https://image.liushuideng.com/images/blog/430_adc_sh.png)

电路前面有一个开关和电容，采样的时候，开关接通，外部电压进入给电容充电，完成后断开，进入保持阶段，电容上面的电压不变，经过后面的射集跟随器，进入ADC转换。

信号进入ADC核心进行转化时，需要标准的参考源才能正常转换，图片的左上角就是内置的1.5V或2.5V参考源，通过各种选择最终可以进入ADC的VR+引脚使用。ADC内部数字电路工作需要提供时钟，所以右边蓝色框的就是时钟选择电路，在SMCLK等各种时钟中选择一个使用。

最后，我们终于将模拟量转成了数字量，数字信号可以进入灰色的框部分，供单片机软件调用就行了。

# ADC10的软件例程

老规矩，一切基于code example，打开G2553的code example(看到这里不知道啥是code example的看下我前面的文章)，找到msp430g2x33_adc10_03.c这个例程。

```
//******************************************************************************
//  MSP430G2x33/G2x53 Demo - ADC10, Sample A10 Temp, Set P1.0 if Temp ++ ~2C
//
//  Description: se ADC10 and the integrated temperature sensor to detect
//  temperature gradients. The temperature sensor output voltage is sampled
//  ~ every 120ms and compared with the defined delta values using an ISR.
//  (ADC10OSC/4)/64 determines sample time which needs to be greater than
//  30us for temperature sensor.
//  ADC10 is operated in repeat-single channel mode with the sample and
//  convert trigger sourced from Timer_A CCR1. The ADC10IFG at the end
//  of each converstion will trigger an ISR.
//  ACLK = n/a, MCLK = SMCLK = default DCO ~ 1.2MHz, ADC10CLK = ADC10OSC
//
//                MSP430G2x33/G2x53
//             -----------------
//         /|\|              XIN|-
//          | |                 |
//          --|RST          XOUT|-
//            |                 |
//            |A10          P1.0|-->LED
//
//  D. Dang
//  Texas Instruments Inc.
//  December 2010
//   Built with CCS Version 4.2.0 and IAR Embedded Workbench Version: 5.10
//******************************************************************************
```

看例程中的注释，ADC10将会每120ms采样测量一次温度，如果温度比程序启动时高了超过2度，红色LED灯将会亮起，否则熄灭。我们将这段程序下到launchpad中，效果如下：

下面是对程序的解释：
```
#include <msp430.h>

static unsigned int FirstADCVal;            // 缓存程序启动时的温度初始值

#define ADCDeltaOn       3                  // 温度上升超过大约2度时翻转LED灯

int main(void)
{
  // 关闭看门狗
  WDTCTL = WDTPW + WDTHOLD;                 
  // ADC10DIV_3:输入时钟三分频 INCH_10:结构图可知，通道10连接着温度电阻 SHS_1:TA3 OUT1触发采样保持 CONSEQ_2:单通道重复采样
  ADC10CTL1 = ADC10DIV_3 + INCH_10 + SHS_1 + CONSEQ_2;
  // 内部参考源，64个ADC时钟一次采样，2.5V参考源，使能ADC中断，开启参考源，开启ADC10
  ADC10CTL0 = SREF_1 + ADC10SHT_3 + REF2_5V + ADC10IE + REFON + ADC10ON;
  // 使能全局中断
  __enable_interrupt();
  TACCR0 = 30;                              // Delay to allow Ref to settle
  TACCTL0 |= CCIE;                          // Compare-mode interrupt.
  TACTL = TASSEL_2 | MC_1;                  // TACLK = SMCLK, Up mode.
  LPM0;                                     // Wait for delay.
  TACCTL0 &= ~CCIE;                         // Disable timer Interrupt
  __disable_interrupt();
  ADC10CTL0 |= ENC;
  TACCTL1 = OUTMOD_4;                       // Toggle on EQU1 (TAR = 0)
  TACTL = TASSEL_2 + MC_2;                  // SMCLK, cont-mode
  while (!(ADC10IFG & ADC10CTL0));          // First conversion?
  FirstADCVal = ADC10MEM;                   // Read out 1st ADC value
  P1OUT = 0x00;                             // Clear P1
  P1DIR = 0x01;                             // P1.0 as output
  __bis_SR_register(LPM0_bits + GIE);       // Enter LPM0 w/ interrupt
}


#pragma vector=ADC10_VECTOR
__interrupt void ADC10_ISR (void)
{
  if (ADC10MEM >= FirstADCVal + ADCDeltaOn)
    P1OUT |= 0x01;                          // LED on
  else
    P1OUT &= ~0x01;                         // LED off
}


#pragma vector=TIMER0_A0_VECTOR
__interrupt void ta0_isr(void)
{
  TACTL = 0;
  LPM0_EXIT;                                // Exit LPM0 on return
}

```

上面只挑选了重点的寄存器进行了注释，具体寄存器的含义，有两种方法可以看到是什么意思，其他的可以举一反三。一种如果使用的是CCS，按住CTRL+左键单击寄存器，可以跳到宏定义的头文件，官方对每个取值进行了注释。第二种就是参看《MSP430x2xx Family User's Guide》文档，搜索寄存器，查看字段解释。