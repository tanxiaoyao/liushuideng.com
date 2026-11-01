---
title: "MSP430之定时器"
published: 2023-05-23
description: "上一节之所以先介绍了枯燥而且没什么对外效果的时钟部分，就是给本章定时器做铺垫的。不论是MCU还是操作系统内的软定时器，实质上都是时钟+计数器实现的，430的计数"
image: "https://image.liushuideng.com/images/blog/430_timer_updown_mode.png"
tags: ["嵌入式-底软开发-单片机-MSP430"]
category: ""
draft: false
---

> 上一节之所以先介绍了枯燥而且没什么对外效果的时钟部分，就是给本章定时器做铺垫的。不论是MCU还是操作系统内的软定时器，实质上都是时钟+计数器实现的，430的计数器有好几种模式，如果理解了它本质上就是一个简单的计数这个点，所有的模式用起来就得心应手了。

如果一块MCU没有定时器，可不可以用呢？完全可以，前面的那些博客都没有用到定时器。但是，没有定时器，那么和其他一票外设齐全的MCU相比就存在硬伤了，再某些场景下用起来会很不方便。举个例子，前面做了个呼吸灯，按照前面的代码可以顺利作出效果来。现在别人要求，有呼吸灯的同时还要做个其他计算的任务。这个可以做吗？前面我们试过，呼吸灯里面有一个sin的计算，光是计算这个，呼吸灯都卡的一闪一闪的，明显就不行。如果使用定时器，我们可以用定时器更优雅的实现前面的呼吸灯，把CPU解放出来，做其他需要处理的事情。

总结来说，在实际应用中，需要对外部事件进行计数、定时控制、PWM等定制波形输出、脉冲宽度测量、速度测量、周期/频率测量、事件发生时刻的捕捉……，这些测量与控制功能均可借助定时器/计数器来实现。

## 430定时器介绍

![430_2553_diagram](https://image.liushuideng.com/images/blog/430_2553_diagram.png)

MCU根据型号不同一般会有多个定时器，上面是2553的内部框图，有Timer0和Timer1两个定时器，不过还有个看门狗，也是一个特殊的定时器。(我就碰到过定时器资源实在是不够用了，把看门狗临时拿来当普通定时器用。不过工业级应用肯定不会这么用，硬件看门狗是保证系统可靠性的重要部件，后面可以好好研究一下)。

430内部配备的是一个16位的定时器（位数大小有什么关系？位数越大，可以计的数越多，在CPU频率一样的情况下，一个计数到最大的时间就越长，用起来方便），结构如下图：

![430_16bit_timer](https://image.liushuideng.com/images/blog/430_16bit_timer.png)

### 定时器结构------时钟源选择

上面时钟部分介绍过一些基本的框图组成元素，所以这张图应该看起来不陌生吧。前面输入是时钟的选择，可以选择不同频率的时钟源，时钟越快，能计时的周期越短，不过计时的精度越高哦。例如，1MHz的时钟输入，计时的精度是1/1000000秒，但计时器一个周期只能计数65535/1000000秒，如果我们用32.768kHz的时钟，我们计时的精度就是1/32768秒，一个周期就是65535/32768秒。（以前做过开关电源PWM波生成，对波形生成的精度要求很高，430最高频率32MHz都达不到，所以用400MHz的FPGA来达到。现在STM32的部分型号，专门为高精度PWM定时器设计，可以达到的精度更高，这里就可以看出来定时器参数的影响作用了）

### 定时器结构------分频器

再往后面看是分频器，分频器的作用就是把输入的频率一分为二、四、八，降低频率值，前面频率越高精度越高，但周期也越短。周期短有什么弊端？举个例子，如果你有个指示灯想1s闪烁一次，如果CPU主频是1M，16位定时器的周期我们算了是65535/1000000秒，这不到一秒啊。定时器计满之后，我还要写代码记着，再接着定时，直到满1s为止，这样就太麻烦了。

解决办法有三个：

一个是降低定时器的输入时钟频率，例如从高频的SMCLK换成ACLK。

二是提高计数器的位数，如果将16位定时器换成32位，那周期就是2^32/1000000秒，远远够1s了，但430内部固定就是16位了，没法改。

三就是分频了，把计数频率降低的同时，又不影响性能。

将1M主频8分频，已经很接近0.5s了，如果非要单次周期1s的话，就要配合方法一，把输入频率改成低频的32768Hz时钟源即可。

### 定时器结构------计数器

这个就是定时器的核心，16位的计数器，它的内部实现感兴趣的可以搜索数字电路16位计数器的结构，这个我们可以用分立的基本逻辑单元搭出来。我们这里可以先不关心这么细的，看下外部的几个线，一个是CLEAR清零，左边有个向上的箭头，表示输入波形的上升沿会让计数清零，又从0开始计数。这个信号的来源不是外部引脚输入的，而是来自寄存器，我们把TACLR寄存器用代码(c也好汇编也好)从0改成1,信号就会从0到1有个上升沿(寄存器的模型我们前面也简单介绍过哦)。然后右边，有个溢出脚，通向TAIFG寄存器。这里有两点要提的：

一个是这里的溢出不一定要16位计满，从0数到65535才算溢出，我们可以指定计数的上限，比如我们设定上限是50000,到50000也会触发溢出。上限可设是很方便的，因为65535不能被整除，用起来很麻烦。

二是这里溢出之后，除了将TAIFG置位，从0变成1之外。这个TAIFG上升沿还会触发定时器的中断，不然内部只是偷偷将TAIFG置位，用户是不知道的。（中断前面讲过，翻翻中断源那张表你就能找到定时器的TAIFG中断，当然定时器还不止这一个中断哦，仔细看）。

### 定时器结构------输出模式选择

这个可以决定输出波形在计数器到达各种特定的中断值后是置1还是归0还是翻转，内部结构具体也不做揣测，预计应该是寄存器控制简单的反相电路实现，但几种模式的区别和用法，介绍完下面的计数器工作模式后，我贴出官方文档各种输出模式下的波形图，大家一看便知其间的区别。

## 定时器工作模式

定时器的几种工作模式的详细介绍，可以参见官方文档MSP430x2xx Family User's Guide.pdf的第12章节，官方事无巨细地介绍了各种模式下的一切信息，包括各种中断到底再第n个还是n+1个周期触发的等。

![430_timer_mode](https://image.liushuideng.com/images/blog/430_timer_mode.png)

这里从简单快速理解的角度，概要的介绍几种工作模式的特点及典型用法，如果决定使用某种模式并对实现细节很关注的话，建议阅读官方文档。

### 定时器工作模式------向上计数模式

![430_timer_up_mode](https://image.liushuideng.com/images/blog/430_timer_up_mode.png)

这是最简单的一个模式，存在的意义就是方便我们自定义计数的周期。前面介绍部分的倒数第二段，我们说过要设置一个50000的上限，这样方便我们按整数时间定时。那这里的上限说的就是向上计数模式中的TACCR0，我们写代码`TACCR0=50000;`就可以设置这个值，当工作在向上计数模式时，计数器就会像图中画的一样从0开始计数，到指定上限后归0重新计数。

![430_timer_up_mode_timing](https://image.liushuideng.com/images/blog/430_timer_up_mode_timing.png)

上面这张图描述了计数器计数并出发中断的细节，如果我们要计数50000个周期，我们使用的是TAIFG这个中断，那我们的TACCR0应该是49999而不是50000,因为TAIFG是从0开始到第CCR0个周期触发，是CCR0+1个周期，TACCR0 CCIFG中断才是正好CCR0个周期出发。不过平常我们见到的大部分例程都习惯使用TAIFG中断，所以要注意这里的区别，在CCR0比较大时可能不易察觉出来这个差距，但如果是几十个甚至几个时钟周期，这个差距就比较明显了。官方文档里还介绍了如果在定时器运行的过程中，如果修改定时器模式或者CCR0的值，计数器会如何工作，是立即归零重新计数还是接着计完当前周期，都有介绍。如果你设计的是精密的电源、电机、高压大电流的控制系统，请务必仔细研究官方文档这些细节上的差异。下面的几个模式都是这样去理解，我就只贴图不解释了。

### 定时器工作模式------持续计数模式

![430_timer_continue_mode](https://image.liushuideng.com/images/blog/430_timer_continue_mode.png)

该模式简单粗暴的直接从0计数到65535然后重新计数，并在计数完成后出发TAIFG中断，所以计数周期就是65536个时钟周期。

这种工作模式一般用来固定的产生一些定时频率输出，设置好后可以完全让硬件持续计数，不需要CPU额外干预。

### 定时器工作模式------向上向下计数模式

![430_timer_updown_mode](https://image.liushuideng.com/images/blog/430_timer_updown_mode.png)

UP DOWN模式可以用在带死区的SPWM波产生上，PWM波就是占空比可变化的方波，SPWM波就是占空比按照正弦规律变化的方波，在开关电源的控制中，SPWM波的两个互相相反的波形上升沿和下降沿需要带有一定的间隔，这就是死区。SPWM波和死区在开关电源、电机控制上有用，建议需要用到时再详细了解，本小结简单介绍下，知道存在这么一个模式即可。

如图中所画，UP/DOWM模式是计数到TACCR0再向下计数到0为一个周期。如果设置了TACCR1和TACCR2，则分别可以在430特定的两个引脚上输出两个对应的波形。TACCR1和TACCR2的差值就可以控制死区的大小。

不过值得一提的是，受限于430的主控频率较低，不能产生频率变化和死区控制很精密的SPWM波，这两点均会影响到开关电源的工作效率和谐波分量，相信如果你真的正在研究开关电源，实验一下也可以知道这个差距，详细的内容，我会在后面开关电源专门的文章中介绍，430也不是万能的，会有其他可替代的解决方案。

### 定时器工作模式------捕获模式

430的定时器还有一个捕获模式和比较模式之分，比较模式就是上面讲的东西，捕获模式则是另一种430支持的工作模式。简单讲可以这么理解，比较模式是定时器跑到一定的周期数，触发一个中断进行相应处理。而捕获模式则是反过来，定时器正常计数，外部的输入信号来触发定时器停止计数。

由输入信号触发不就是相当于捕获了外部信号的变化吗？这就是捕获模式的名称由来。这个功能可以用来测量两个事件的时间间隔、测量信号频率，测量电机的转速等等。

![430_timer_cap_mode](https://image.liushuideng.com/images/blog/430_timer_cap_mode.png)

上图是430捕获模式下的时序图，Capture表示输入信号，当设置上升沿捕获的时候，输入信号上升沿会触发CCIFG中断，并把当前的计数器值N读到寄存器中。读取N我们就能知道定时器计时的时间长度了。

## 用法示例

### 简单的周期定时

产生周期为1s的定时器中断，在中断中翻转板上的红灯状态。

```c
void TimerWave()
{
  WDTCTL = WDTPW + WDTHOLD;                 // Stop WDT
  if (CALBC1_1MHZ==0xFF)					// If calibration constant erased
  {											
    while(1);                               // do not load, trap CPU!!	
  }
  DCOCTL = 0;                               // Select lowest DCOx and MODx settings
  BCSCTL1 = CALBC1_1MHZ;                    // Set DCO to 8MHz
  DCOCTL = CALDCO_1MHZ;
  P1DIR |= BIT0;                            // P1.0 output
  CCTL0 = CCIE;                             // CCR0 interrupt enabled
  CCR0 = 50000;
  TACTL = TASSEL_2 + MC_2;                  // SMCLK, contmode
}

// Timer A0 interrupt service routine
#if defined(__TI_COMPILER_VERSION__) || defined(__IAR_SYSTEMS_ICC__)
#pragma vector=TIMER0_A0_VECTOR
__interrupt void Timer_A (void)
#elif defined(__GNUC__)
void __attribute__ ((interrupt(TIMER0_A0_VECTOR))) Timer_A (void)
#else
#error Compiler not supported!
#endif
{
  counter++;
  if(counter%20 == 0)
    P1OUT ^= BIT0;
}
```

### PWM波产生与占空比调节

产生周期为100K，占空比为30%的PWM波

```c
void TM1()
{
  WDTCTL = WDTPW + WDTHOLD;                 // Stop WDT
  if (CALBC1_1MHZ==0xFF)					// If calibration constant erased
  {											
    while(1);                               // do not load, trap CPU!!	
  }
  DCOCTL = 0;                               // Select lowest DCOx and MODx settings
  BCSCTL1 = CALBC1_1MHZ;                    // Set DCO to 8MHz
  DCOCTL = CALDCO_1MHZ;
  P1DIR |= BIT2;                            // P1.2 and P1.3 output
  P1SEL |= BIT2;                            // P1.2 and P1.3 TA1/2 options
  CCR0 = 20-1;                             // PWM Period
  CCTL1 = OUTMOD_7;                         // CCR1 reset/set
  CCR1 = 6;                               // CCR1 PWM duty cycle
  TACTL = TASSEL_2 + MC_1;                  // SMCLK, up mode
  CCTL0 &= ~CCIE;
}
```

### 较高频率高精度PWM波产生

产生周期为400K，占空比为50%的方波
```c
void TM2()
{
  WDTCTL = WDTPW + WDTHOLD;                 // Stop WDT
  if (CALBC1_16MHZ==0xFF)					// If calibration constant erased
  {											
    while(1);                               // do not load, trap CPU!!	
  }
  DCOCTL = 0;                               // Select lowest DCOx and MODx settings
  BCSCTL1 = CALBC1_16MHZ;                    // Set DCO to 8MHz
  DCOCTL = CALDCO_16MHZ;
  P1DIR |= BIT2;                            // P1.2 and P1.3 output
  P1SEL |= BIT2;                            // P1.2 and P1.3 TA1/2 options
  CCR0 = 80-1;                             // PWM Period
  CCTL1 = OUTMOD_7;                         // CCR1 reset/set
  CCR1 = 40;                               // CCR1 PWM duty cycle
  TACTL = TASSEL_2 + MC_1;                  // SMCLK, up mode
  CCTL0 &= ~CCIE;
}
```

### 看门狗作为普通定时器用法

利用G2系列单片机片上看门狗定时器，产生0.25s周期的中断，翻转板上绿灯状态

```c
void WDT()
{
  if (CALBC1_1MHZ==0xFF)					// If calibration constant erased
  {											
    while(1);                               // do not load, trap CPU!!	
  }
  DCOCTL = 0;                               // Select lowest DCOx and MODx settings
  BCSCTL1 = CALBC1_1MHZ;                    // Set DCO to 8MHz
  DCOCTL = CALDCO_1MHZ;
  WDTCTL = WDT_MDLY_32;                     // Set Watchdog Timer interval to ~30ms
  IE1 |= WDTIE;                             // Enable WDT interrupt
  P1DIR |= BIT0;                            // Set P1.0 to output direction
}

// Watchdog Timer interrupt service routine
#if defined(__TI_COMPILER_VERSION__) || defined(__IAR_SYSTEMS_ICC__)
#pragma vector=WDT_VECTOR
__interrupt void watchdog_timer(void)
#elif defined(__GNUC__)
void __attribute__ ((interrupt(WDT_VECTOR))) watchdog_timer (void)
#else
#error Compiler not supported!
#endif
{
  P1OUT ^= BIT6;                            // Toggle P1.0 using exclusive-OR
}
```

### 组合：按键中断+定时器

上述功能1、2、3、4通过板上按键依次切换，按键通过扫描或者IO口中断实现均可

```c

#include "msp430g2553.h"

unsigned int counter = 0;
unsigned char state = 0;

void TimerWave()
{
  WDTCTL = WDTPW + WDTHOLD;                 // Stop WDT
  if (CALBC1_1MHZ==0xFF)					// If calibration constant erased
  {											
    while(1);                               // do not load, trap CPU!!	
  }
  DCOCTL = 0;                               // Select lowest DCOx and MODx settings
  BCSCTL1 = CALBC1_1MHZ;                    // Set DCO to 8MHz
  DCOCTL = CALDCO_1MHZ;
  P1DIR |= BIT0;                            // P1.0 output
  CCTL0 = CCIE;                             // CCR0 interrupt enabled
  CCR0 = 50000;
  TACTL = TASSEL_2 + MC_2;                  // SMCLK, contmode
}

void WDT()
{
  if (CALBC1_1MHZ==0xFF)					// If calibration constant erased
  {											
    while(1);                               // do not load, trap CPU!!	
  }
  DCOCTL = 0;                               // Select lowest DCOx and MODx settings
  BCSCTL1 = CALBC1_1MHZ;                    // Set DCO to 8MHz
  DCOCTL = CALDCO_1MHZ;
  WDTCTL = WDT_MDLY_32;                     // Set Watchdog Timer interval to ~30ms
  IE1 |= WDTIE;                             // Enable WDT interrupt
  P1DIR |= BIT0;                            // Set P1.0 to output direction
}

void TM1()
{
  WDTCTL = WDTPW + WDTHOLD;                 // Stop WDT
  if (CALBC1_1MHZ==0xFF)					// If calibration constant erased
  {											
    while(1);                               // do not load, trap CPU!!	
  }
  DCOCTL = 0;                               // Select lowest DCOx and MODx settings
  BCSCTL1 = CALBC1_1MHZ;                    // Set DCO to 8MHz
  DCOCTL = CALDCO_1MHZ;
  P1DIR |= BIT2;                            // P1.2 and P1.3 output
  P1SEL |= BIT2;                            // P1.2 and P1.3 TA1/2 options
  CCR0 = 20-1;                             // PWM Period
  CCTL1 = OUTMOD_7;                         // CCR1 reset/set
  CCR1 = 6;                               // CCR1 PWM duty cycle
  TACTL = TASSEL_2 + MC_1;                  // SMCLK, up mode
  CCTL0 &= ~CCIE;
}

void TM2()
{
  WDTCTL = WDTPW + WDTHOLD;                 // Stop WDT
  if (CALBC1_16MHZ==0xFF)					// If calibration constant erased
  {											
    while(1);                               // do not load, trap CPU!!	
  }
  DCOCTL = 0;                               // Select lowest DCOx and MODx settings
  BCSCTL1 = CALBC1_16MHZ;                    // Set DCO to 8MHz
  DCOCTL = CALDCO_16MHZ;
  P1DIR |= BIT2;                            // P1.2 and P1.3 output
  P1SEL |= BIT2;                            // P1.2 and P1.3 TA1/2 options
  CCR0 = 80-1;                             // PWM Period
  CCTL1 = OUTMOD_7;                         // CCR1 reset/set
  CCR1 = 40;                               // CCR1 PWM duty cycle
  TACTL = TASSEL_2 + MC_1;                  // SMCLK, up mode
  CCTL0 &= ~CCIE;
}

int main(void)
{
  WDTCTL = WDTPW + WDTHOLD;                 // Stop WDT
  P1DIR |= BIT0 + BIT6;
  P1OUT &= ~(BIT0 + BIT6);
  P1DIR &= ~BIT3;
  P1REN |= BIT3;
  P1OUT |= BIT3;
  P1IES |= BIT3;
  P1IE |= BIT3;
  P1IFG = 0;
  //while(1);
  __bis_SR_register(LPM0_bits + GIE);       // Enter LPM0 w/ interrupt
}

// Timer A0 interrupt service routine
#if defined(__TI_COMPILER_VERSION__) || defined(__IAR_SYSTEMS_ICC__)
#pragma vector=TIMER0_A0_VECTOR
__interrupt void Timer_A (void)
#elif defined(__GNUC__)
void __attribute__ ((interrupt(TIMER0_A0_VECTOR))) Timer_A (void)
#else
#error Compiler not supported!
#endif
{
  counter++;
  if(counter%20 == 0)
    P1OUT ^= BIT0;
}

// Port 1 interrupt service routine
#if defined(__TI_COMPILER_VERSION__) || defined(__IAR_SYSTEMS_ICC__)
#pragma vector=PORT1_VECTOR
__interrupt void Port_1(void)
#elif defined(__GNUC__)
void __attribute__ ((interrupt(PORT1_VECTOR))) Port_1 (void)
#else
#error Compiler not supported!
#endif
{
  if(P1IFG&BIT3)
  {
    __delay_cycles(10000);
    if((P1IN&BIT3) == 0)
    {
      state++;
      switch(state)
      {
      case 1:
        TimerWave();
        break;
      case 2:
        WDT();
        break;
      case 3:
        TM1();
        break;
      case 4:
        TM2();
        break;
      default:break;
      }
      if(state == 4)
      {
        state = 0;
      }
    }
  }
  P1IFG = 0;
}


// Watchdog Timer interrupt service routine
#if defined(__TI_COMPILER_VERSION__) || defined(__IAR_SYSTEMS_ICC__)
#pragma vector=WDT_VECTOR
__interrupt void watchdog_timer(void)
#elif defined(__GNUC__)
void __attribute__ ((interrupt(WDT_VECTOR))) watchdog_timer (void)
#else
#error Compiler not supported!
#endif
{
  P1OUT ^= BIT6;                            // Toggle P1.0 using exclusive-OR
}
```