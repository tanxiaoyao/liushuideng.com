---
title: "通用数字滤波算法"
published: 2023-05-31
description: "不论你是做数字信号处理还是系统自动控制，只要系统中有模拟数据采集部分，就不可避免的存在噪声干扰的问题。应对噪声，一个方法就是利用硬件搭建模拟的滤波器，在前端采样"
image: "https://image.liushuideng.com/images/blog/algo_softfilter_ori_data.png"
tags: ["嵌入式-底软开发-软件-信号处理"]
category: ""
draft: false
---

> 不论你是做数字信号处理还是系统自动控制，只要系统中有模拟数据采集部分，就不可避免的存在噪声干扰的问题。应对噪声，一个方法就是利用硬件搭建模拟的滤波器，在前端采样电路滤除掉噪声；另一个方法，就是利用ADC采样，运行软件滤波算法，滤除掉信号中的噪声。
>> 特别声明：本文为个人在阅读《匠人笔记》的数字滤波篇后自己总结的输出成果，如果存在侵权，烦请留言告知处理。

# 背景知识

软件和硬件滤波两种方法各有优缺点，硬件滤波针对特定信号滤除效果好，能够有效提高系统的信噪比，但是硬件电路复杂，甚至需要引入运放增加物料成本，同时频带调整不够灵活，如果噪声信号频率是变动的通常无能为力。软件滤波则设置灵活，可以方便调整频带，在应对复杂的噪声信号时，甚至可以引入算法自动跟随噪声频率，但是软件滤波也有缺点，需要消耗大量的CPU能力进行运算，而且系统能够处理的信号带宽直接受ADC采样速率和CPU处理速度的限制，无法像硬件滤波器那样轻易设计出高频段的滤波器。

本文主要介绍软件滤波，因为在原型DEMO的开发中，为了快速滤除噪声，减少设计硬件滤波器的繁琐，我们直接就是用ADC采样前端信号，然后软件快速滤除噪声开始后续处理，加快我们的研究进度。

# 软件滤波介绍

软件滤波是利用CPU强大的计算运算功能，通过某种数值运算，达到改变输入信号中所含频率分量的相对比例、或滤除某些频率分量的目的。实验中往往会因为噪声、干扰、温度、环境以及元器件或者设备等诸多因素的影响，造成采集到的数据达不到预期效果，例如采集到的“坏点”数据会对数据的分析以及结果造成不利的影响。这个时候可以采用软件滤波的方法对采集到的数据进行处理，减小抖动偏差，使采集到的数据尽可能的准确。此外除了可使用(有源、无源)滤波器对信号或波形进行平滑处理外，还可以先将波形用A/D采集，然后使用软件滤波，最后通过D/A输出波形，同样可以起到对波形的平滑处理和消除毛刺等效果。
软件滤波的方法有很多种，下面介绍常用的几种，不同的滤波方法应用的场合和环境也不用，应根据具体情况选择使用。为了直观体现出这几种滤波方法对不同噪声的滤波效果，我们人为生成了几段基本信号的组合，然后在它们的波形上叠加上不同的噪声，测试这些滤波方法在不同信号、不同噪声下的输出结果，实验数据如下图所示：

![algo_softfilter_ori_data](https://image.liushuideng.com/images/blog/algo_softfilter_ori_data.png)

在这段长度为800点,最大值为65535的测试样本中，组合了以下几种情况：

1. 起始阶段是一段表达式近似为$\sqrt{x}$的数据，用来模拟大多数系统从0开始启动的采样波形，该段信号受到了约为信号本身1/5强度的随机噪声的干扰，用以测试滤波函数对噪声的过滤程度。
2. 第二段是一段长度为200点的方波信号，其上叠加了幅度为信号本身1/10的毛刺噪声，测试函数对直流采样过程中毛刺的过滤效果以及对阶跃信号的响应速度。
3. 第三段为一段均匀上升的斜坡信号，但是叠加了几个三角形的噪声信号，用来模拟一些高惯性系统受到脉冲冲击后产生的周期较长的干扰杂波。
4. 第四段是一段混有信号本身1/10强度的随机噪声与1/4强度的毛刺噪声，模拟了平时在正弦逆变类题目中常常碰到的系统底噪与周期性开关噪声。
5. 最后一段是直流信号上叠加了一个长周期的小幅正弦纹波，同时伴有一定的毛刺，用来模拟DC-DC类题目中常出现的输出伴纹波信号。

上面列出的组合大致涵盖了电子设计竞赛中电源类常见的几种情况，由于涉及到PID闭环调节，因此精确的采样与滤波对实现高精度的输出控制与快速反馈至关重要。下面我们就分别介绍这些算法的实现过程与应用效果。

## 限幅滤波

限幅滤波又称为程序判断滤波，根据多次采集到的数据，如果当前采集值与前一次采集的数值相差一般维持在一定的偏差$\Delta{D}$内，则将每次采集到的数据和前一次的数据进行比较，如果他们的差的绝对值小于$\Delta{D}$则本次采集到的数据有效，否则无效舍弃。

### 示例代码

```c
#include <stdlib.h>
/*********************限幅滤波***********************
/*   sampleValue:当前采样值
/*   return 滤波输出值
/***************************************************/
#define AMPLIMIT 8192
int lastValue = -1;
unsigned int AmpLimitFilter(unsigned int sampleValue)
{
    if(-1 == lastValue)
        lastValue = sampleValue;
	//限幅判断
    if(abs(sampleValue - lastValue) > AMPLIMIT)
    {
        return lastValue;
    }else{
        lastValue = sampleValue;
        return sampleValue;
    }
}
```

### 滤波效果
![algo_softfilter_amplimit](https://image.liushuideng.com/images/blog/algo_softfilter_amplimit.png)

### 适用分析

限幅滤波程序设计简单、运算速度快、占用RAM少，是一种最简单的基本滤波方法。能够克服偶然因素引入的脉冲干扰，也可以消除波形上的尖峰毛刺，但是不能抑制周期性的干扰，而且其完全削除大幅度的阶跃信号，容易造成控制失调，一般不适用于开关电源这类变化剧烈，需要迅速反馈的场景，适用于水温控制等变化缓慢，安全性高的应用。

## 中值滤波

将原来的采样间隔$\Delta{T}$进行细分，也就是在原来的采样间隔$\Delta{T}$内采样N次，然后把N次采样值按照大小排序，取中间值为本次采样值。

### 示例代码

```c
/*********************中值滤波***********************
/*   *sampleGet():采样函数指针，返回unsigned int类型
/*   return 滤波输出值
/***************************************************/
#define MID_NUM 5
unsigned int MidFilter(unsigned int *sampleGet())
{
  unsigned char i;
  unsigned int value_buf[MID_NUM]={0};
  for (i=0;i < MID_NUM;i++)
  {
    value_buf[i] = sampleGet();
  }
  unsigned int mid;
  //冒泡排序
  for(i=0;i<MID_NUM;i++)
  {
	int j;
    for(j=i+1;j<MID_NUM;j++)
    {
      if(value_buf[i]>value_buf[j])
      {
        mid=value_buf[i];
        value_buf[i]=value_buf[j];
        value_buf[j]=mid;
      }
    }
  }
  mid=value_buf[MID_NUM/2];
  return mid;
} 
```

### 滤波效果

![algo_softfilter_midfilter](https://image.liushuideng.com/images/blog/algo_softfilter_midfilter.png)

### 适用分析

这种滤波方法能够有效的克服偶然因素引起的波动干扰，特别是对于像温度、液位等变化缓慢的被测参数有良好的滤波效果，但是对于流量、速度或者其他快速变化的信号参数则不适合使用这种方法。中值滤波法的程序设计要稍复杂一些，排序可以使用冒泡法或者选择排序法等，由于引入了排序算法，所以该方法不能处理速度要求很高的信号。其运算处理速度和占用的RAM直接受所选择的数值N决定。

## 算术平均滤波

该方法也是先将原来设计要求的采样间隔$\Delta{T}$进行细分，在$\Delta{T}$内采样N次，但是对于采集进来的数据不是进行排序，而是进行算术平均，算术平均的结果作为本次采样值。N值的选取比较关键，N值较大者处理信号的平滑度会较高，但是灵敏度降低；相反，N值较小者处理信号的灵敏度提高，但是平滑度降低。

### 示例代码

```c
/*********************均值滤波***********************
/*   *sampleGet():采样函数指针，返回unsigned int类型
/*   return 滤波输出值
/***************************************************/
#define AVG_NUM 5
unsigned int AvgFilter(unsigned int *sampleGet())
{
  unsigned char i;
  unsigned long int sum=0;
  for (i=0;i < AVG_NUM;i++)
  {
    sum += (unsigned int)sampleGet();
  }
  return (sum / AVG_NUM);
}
```

### 滤波效果

![algo_softfilter_avgfilter](https://image.liushuideng.com/images/blog/algo_softfilter_avgfilter.png)

### 适用分析

这种滤波方法是适用于对具有随机干扰的信号进行处理，并且被处理的信号必须具有一个平均值，信号在这个平均值上下波动。该方法对于高速信号并不适用。对于毛刺信号，可以看到均值滤波将其分担到了周围的采样点上，不如中值滤波那样能够完全去除。但是对于随机噪声信号，由于其理论均值为0，均值滤波对第一段噪声有良好的滤除效果。该滤波方法运算处理速度和RAM的占用率也受所选择的数值N决定，可以使用时间复杂度较低的排序方法降低运算开销。

## 递推平均滤波

递推平均滤波又称为滑动平均滤波，是将连续N个采样值设为一个先入先出的队列，队列的长度为N，每次采样得到的新数据加入队尾，并扔掉原队列的队首，然后对队列中的N个数据进行算术平均，获得的结果作为此次采样值。

### 示例代码

```c
/*******************递推均值滤波*********************
/*   sampleQueue[SLIDE_AVG_NUM]:采样队列
/*   sampleValue:当前采样值
/*   return 滤波输出值
/***************************************************/
#define SLIDE_AVG_NUM 5
unsigned int sampleQueue[SLIDE_AVG_NUM] = {0};
unsigned int SlideAvgFilter(unsigned int sampleValue)
{
    unsigned int i;
    unsigned long int sum=0;
    for(i = 0; i < SLIDE_AVG_NUM - 1; i ++) //刷新队列
    {
        sampleQueue[i] = sampleQueue[i + 1];
    }
    sampleQueue[i] = sampleValue;
    for (i=0;i < SLIDE_AVG_NUM;i++) //求和
    {
        sum += sampleQueue[i];
    }
    return (sum / SLIDE_AVG_NUM);//取平均
}
```

### 滤波效果
![algo_softfilter_slideavgfilter](https://image.liushuideng.com/images/blog/algo_softfilter_slideavgfilter.png)

### 适用分析

上图为滤波长度为5的输出波形，下图为滤波长度为20的输出波形。可以看到长度为20的波形更好但延迟也更大。可见该方法对于周期性干扰有良好的抑制作用，平滑度也很高。但是灵敏度较低，对于偶然出现的脉冲干扰的抑制作用较差，不适用于脉冲干扰比较严重的场合，其运算处理速度和RAM的占用率也直接受N值影响。

另外，这种方法还有一个特殊用法：制作成软件陷波器，滤除某个单一频率信号的干扰(如工频干扰)。具体实现方法介绍如下：由于正弦波一个周期内任取N个等分点的幅值和为零，其它周期波形的N等分点的幅值和为常数C，设每次采样值为${X_i}$，采样的平均值为${Y=\frac{1}{N}\sum_{i=0}^{N-1}}{X_i}$。若取$N=\frac{S}{f}$(其中S为每秒的采样次数即采样率；f是要消除的波形的频率，S和N都取整数)，这样最终的结果就是Y－C，对于50Hz的工频干扰，C为零，只要选择合适的N和S就可以直接将其消除，构成一个陷波器。
对于本测试样例，我们针对最后一段的纹波设计滤波器，由于这里是测试的一组数组，没有采样率概念，但是根据前面的关系换算，设置滤波点数为100点，对最后一段纹波进行了较好的滤除，由于这一段数据较少，加之前面数据的相移影响，读者可自己构造一段足够长的纹波信号验证，效果将更加明显。

![algo_softfilter_freqcutfilter](https://image.liushuideng.com/images/blog/algo_softfilter_freqcutfilter.png)

## 中值平均滤波

中值平均滤波也称为防脉冲干扰平均滤波，相当于中值滤波和算术平均滤波思想的结合。连续采样N个数据，去掉其中的最大值和最小值，求剩下的N－2个数据的算术平均作为一次采样值。

### 示例代码

```c
/*******************中值平均滤波*********************
/*   *sampleGet():采样函数指针，返回unsigned int类型
/*   return 滤波输出值
/***************************************************/
#define MID_AVG_NUM 5
unsigned int MidAvgFilter(unsigned int *sampleGet())
{
  unsigned char i;
  unsigned int value_buf[MID_AVG_NUM]={0};
  unsigned int max,min;
  unsigned long int sum=0;
  for (i=0;i < MID_AVG_NUM;i++)
  {
    value_buf[i] = sampleGet();
  }
  max=0;
  min=0xffffffff;
  for(i=0;i<MID_AVG_NUM;i++)
  {
    sum += value_buf[i];//求和
    if(value_buf[i]>max)
    {
      max=value_buf[i];	//找出最大值
    }
    if(value_buf[i]<min)
    {
      min=value_buf[i];	//找出最小值
    }
  }
  return (sum-min-max)/(MID_AVG_NUM-2);//去掉最大最小值，取平均
}
```

### 滤波效果
![algo_softfilter_midavgfilter](https://image.liushuideng.com/images/blog/algo_softfilter_midavgfilter.png)

### 适用分析

此法综合了两种滤波法的优点，可以有效抑制、消除脉冲干扰，同时相对于纯中值滤波更加平滑，但由于计算开销加上均值的延迟作用，它也只能用在速度比较慢的场合，不适合高速环境，运算处理速度和RAM占有率由N决定。

## 递推中值平均滤波

递推中值平均滤波也称为滑动中值平均滤波，与上一种不同的是采用滑动方法对序列采样，不降低系统采样率与采样速度。设定一个长度为N的先进先出队列，同时为了方便排序同时构造一个同样长度为N的已排序数组，每个周期采样一个新的数值，插入采样队列队尾并移除队首的旧值。对这个队列进行插入排序（其他快速排序方法均可），然后去掉用户指定个数的较大值与较小值，取中间剩下值的平均数作为最终结果。

## 示例代码

```c
/*******************中值平均滤波*********************
/*   SLIDE_MID_AVG:数据存储结构体，每路信号对应一个
/*   *sma：本路信号对应结构体指针
/*   newValue:本次采样值
/*   cutNum:排序队列头尾要舍弃的数量
/*   return 滤波输出值
/***************************************************/
#define SLIDE_MID_AVG_NUM 32
typedef struct SLIDE_MID_AVG{
	volatile unsigned int sample_queue[SLIDE_MID_AVG_NUM];
	volatile unsigned int sort_queue[SLIDE_MID_AVG_NUM];
} SLIDE_MID_AVG;

SLIDE_MID_AVG sma;
unsigned int SlideMidAvgFilter(SLIDE_MID_AVG *sma,unsigned int newValue,unsigned int cutNum)
{
	unsigned int i;
	unsigned int sum = 0;
	unsigned int insert_value = newValue;
	//在排序序列中移除采样序列中最早的值
	for(i = 0;i < SLIDE_MID_AVG_NUM;i ++)
	{
		if(sma->sort_queue[i] == sma->sample_queue[0])
		{
			unsigned int j;
			for(j = i;j< SLIDE_MID_AVG_NUM - 1;j ++)
			{
				//排序序列向前缩进
				sma->sort_queue[j] = sma->sort_queue[j + 1];
			}
			break;
		}
	}
	//在排序序列中插入新的采样值（插入排序加快运算）
	for(i = 0;i < SLIDE_MID_AVG_NUM - 1;i ++)
	{
		if(insert_value < sma->sort_queue[i])
		{
			unsigned int j;
			for(j = SLIDE_MID_AVG_NUM - 1;j > i;j --)
			{
				//排序序列向后缩进
				sma->sort_queue[j] = sma->sort_queue[j - 1]; 
			}
			sma->sort_queue[i] = insert_value;
			break;
		}else{
			if(i == SLIDE_MID_AVG_NUM - 2)
			{
				sma->sort_queue[SLIDE_MID_AVG_NUM - 1] = insert_value;
			}
		}
	}
	//记录新的值到采样队列末尾
	for(i = 0;i < SLIDE_MID_AVG_NUM - 1;i ++)
	{
		sma->sample_queue[i] = sma->sample_queue[i + 1];		//移位刷新
	}
	sma->sample_queue[SLIDE_MID_AVG_NUM - 1] = insert_value;	//采样新值
	//计算中间数的平均值
	for(i = cutNum; i < (SLIDE_MID_AVG_NUM - cutNum);i ++)
	{
		sum += sma->sort_queue[i];
	}
	return sum / (SLIDE_MID_AVG_NUM - (cutNum << 1));
}
```

### 滤波效果
![algo_softfilter_slidemidavgfilter](https://image.liushuideng.com/images/blog/algo_softfilter_slidemidavgfilter.png)

### 适用分析
上图采用了32点滤波长度，首尾去除8个点，波形平滑，没有突变的噪声与毛刺现象，对各种噪声适应性比较均衡，是我们电子竞赛实际中应用的最多的一种滤波方法。但是细心的读者可以发现，波形向后的延迟很高，差不多与滤波长度相当，这也是此方法的弊端。所以我们经常使用32点或者64点甚至更长的滑动中值平均滤波进行数据校准阶段的信号滤波，在恒压恒流等达到准确的稳态值后换用前面的中值滤波等高灵敏度方法进行PID的整定与调节，获得系统高速的动态响应。

## 限幅平均滤波

顾名思义，限幅平均滤波就是将限幅滤波和递推平均滤波的思想结合起来，每次采样得到的数据先进行限幅处理，再送入队列进行递推平均滤波处理。
该法也是结合两种滤波法的优点，有效抑制偶然出现的脉冲干扰、可消除由此而引起的采样偏差，但不适用于高速信号的处理，其运算处理和RAM的占用率直接受N值影响。

## 一阶滞后滤波
取一个比例常数k(其中0<k<1)，本次输出的结果＝k×本次采样值＋(1－k)×前一次输出值，当前的输出值不仅受当前采样值的影响还受前次的输出值影响，影响的程度由k值决定。
该滤波方法适用于波动频率较高的场合，对于周期性干扰具有良好的抑制作用且运算量不大。但是该方法会造成相位滞后，滞后程度取决于k值，灵敏度低，并且不能消除频率高于采样频率一半的干扰信号。

## 加权递推平均滤波
该方法是递推平均滤波的一种改进，在不同时刻采样进来的数据具有不同的权重。通常情况是距离当前时刻越近的采样值的权重越大(特殊情况除外)。赋予刚刚采样得到的数据的权重越大，则灵敏度越高，但是信号的平滑度降低。
此法适用于有较大纯滞后时间常数的对象和采样周期短的情况。对于变化缓慢、采样周期长的情况，则不能迅速反映系统当前所受干扰的严重程度。该方法占用RAM较多。

## 消抖滤波
设置一个滤波计数器，将每次采样值与当前的有效值比较，如果采样值等于当前有效值，计数器清零；反之，计数器加一，并确判断滤波计数器是否达到设定的溢出上限。如果计数器溢出，将本次的值替换当前有效值，并清零计数器。
此法对变化缓慢的被测参数有较好的滤波效果，并可避免系统在临界值附近时显示器上数值的抖动和控制器的反复开关跳动。但此法不适用于快速变化的参数测量控制。

## 限幅消抖滤波
限幅消抖滤波为限幅滤波和消抖滤波的结合：先进行限幅处理，再进行消抖滤波处理。

此方法综合了限幅滤波和消抖滤波的优点，改进了消抖滤波中的一些不足，避免了将干扰值导入系统，但不适用于快速变化的参数。

基本的软件滤波方法如上所述，(数字滤波器也属于软件滤波，也有其应用的场合，但是消耗的资源会更大些，)这些软件滤波的方法适用场合不同，要根据不同的环境和被测参数的特征来选择不同的滤波方法，也可以几种方法混合使用，以达到抑制、消除干扰，平滑波形，消除抖动，稳定控制和输出结果的目的。

# 用法小结
上面对于几种常见的滤波方法进行了详细的分析验证，后面几种滤波方法实际上是前面基本滤波的组合，在此不做赘述，读者可以按照前面的过程自行编写代码验证。本书验证在32位平台下运行，在实际的单片机平台运行时，读者若参照上面示例代码运行，请注意平台的数据字长，防止数据溢出的现象发生。

从上述分析过程我们可以大致得出：中值滤波适用于去除信号中的突发毛刺，均值滤波适用于去除信号中的白噪声以及系统底噪等。普通的滤波若使用多个采样点计算出一个最终结果，会通过牺牲采样率来获得较准确的数据结果。递推的数据滤波不会降低数据采样的速率，随着队列长度的增加，输出会越来越平滑。但是信号对阶跃信号的响应会越来越慢，系统的时延会越来越大。所以实际应用中使用者应根据实际信号的类型及噪声的状态选取合适的滤波方法，合适的滤波参数。对于电子设计竞赛的电源部分，建议是在数据校准的过程中使用高精确度的滤波来对电压电流等进行精确校准，然后在PID调节时再换用响应快、灵敏度高的滤波算法，这样往往可以同时获得电源输出高精确度、高反馈调节速度的效果。

