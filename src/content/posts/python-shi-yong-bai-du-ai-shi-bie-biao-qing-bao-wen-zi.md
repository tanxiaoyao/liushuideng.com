---
title: "python使用百度AI识别表情包文字"
published: 2023-08-23
description: "从网络上下载表情包，下载的图片名称都是随机的字符串，不利于我们对表情包分类管理，现在我们想利用表情包里的文字命名图片，便于我们搜索和整理，记录下python实现"
image: "https://image.liushuideng.com/images/blog/202308222214933.PNG"
tags: []
category: ""
draft: false
---

> 从网络上下载表情包，下载的图片名称都是随机的字符串，不利于我们对表情包分类管理，现在我们想利用表情包里的文字命名图片，便于我们搜索和整理，记录下python实现过程。刚写完这篇帖子发现把表情包图片都放在手机里，微信有个自带搜索功能可以搜索图片内的文字，我枯了

# 实现效果
![](https://image.liushuideng.com/images/blog/202308222214933.PNG)

# 背景知识

识别图像中文字的技术叫OCR，指利用图像光学上的特征进行文字或者图形识别。早期的OCR技术主要是使用图形特征的技巧进行识别的，后来OCR主要由AI算法进行。

这次的实践搜索了下，python上传统的OCR识别库主要是Tesseract，这个库很早就开发了，主要是使用上不是pip库而是安装文件，需要配置环境变量，而且还担心识别效果泛华不好的问题，所以我选择了另外一种方案就是调用百度AI提供的文字识别接口进行处理。

# 方案原理

百度AI把识别的接口通过SDK提供给我们，所以我们需要做的就非常简单了，直接把文件丢给百度AI，返回识别结果重命名文件就可以了。这里图片识别的模型啥的对我们都是不可见的，我们发动“调包侠”技能就能快速完成这个需求。

# 操作步骤

## 注册百度AI账号和应用

类似大多数在线平台，需要先注册账号和应用以便百度提供对应的接口的用户ID给你，打开链接：[百度AI](https://ai.baidu.com/)

注册账号，登陆，然后点击右上角控制台，然后产品服务里面提供了非常多AI的功能，选择人工智能下面的文字识别

![python_emoti_baiduai_textrec](https://image.liushuideng.com/images/blog/python_emoti_baiduai_textrec.png)

选择创建应用，然后填写一下描述即可。然后你会得到一个app id如下图：

![](https://image.liushuideng.com/images/blog/python_emoti_baiduai_appid.png)

有了这个ID之后就可以在python脚本里面调用了。

## 安装python百度AI工具包

```shell
  pip install baidu-aip
```

## 撸代码

本来是准备用SDK的方式调用的，试了下demo代码没有调通，最后用了web api版本，代码里面指定图片文件夹就可以了，脚本会依次遍历所有的图片并转换。因为图片是从知乎的帖子爬的，所以代码里会有特殊判断去掉知乎相关的字样。因为AI识别稳定性的原因，部分识别不出来的图片可以挑出来多跑几次，基本可以全部识别。

```python
# encoding:utf-8
import os

from aip import AipOcr
import re


def validateTitle(title):
    rstr = r"[\/\\\:\*\?\"\<\>\|]"
    new_title = re.sub(rstr, "_", title)
    return new_title

def get_file_content(filePath):
    with open(filePath, 'rb') as fp:
        return fp.read()


def RecOnePic(client, filePath):
    image = get_file_content(filePath)
    """ 如果有可选参数 """
    options = {}
    options["detect_direction"] = "true"
    options["detect_language"] = "true"

    """ 带参数调用通用文字识别, 图片参数为本地图片 """
    msg = client.basicGeneral(image, options)
    result = ''
    for item in msg.get('words_result', 'None'):
        if ('words' in item):
           if ('知' not in item['words'] and '乎' not in item['words'] and '@' not in item['words']):
                result += item['words']

        else:
            result = '无法识别'
            return
    if (result != ''):
        result = validateTitle(result)
        try:
            os.rename(os.path.join(filePath), os.path.join(os.path.dirname(filePath), result + ".jpg"))
            print(result)
        except IOError:
            print("Error: 没有找到文件或读取文件失败")

'''
网络图片文字识别
'''
def walkFile(file):
    filePaths = []
    for root, dirs, files in os.walk(file):

        # root 表示当前正在访问的文件夹路径
        # dirs 表示该文件夹下的子目录名list
        # files 表示该文件夹下的文件list

        # 遍历文件
        for f in files:
            filePaths.append(os.path.join(root, f))

    return  filePaths

if __name__ == '__main__':


    """ 你的 APPID AK SK """
    APP_ID = '这里填你的APP_ID数字'
    API_KEY = '这里填你的API_KEY'
    SECRET_KEY = '这里填你的SECRET_KEY'

    client = AipOcr(APP_ID, API_KEY, SECRET_KEY)

    filePaths = walkFile('D:\\04.Code\\test\\zhihu_pic')
    for filePath in filePaths:
        print(filePath)
        RecOnePic(client, filePath)
```
