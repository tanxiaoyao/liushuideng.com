---
title: "使用python统计git仓库中频繁修改的热点函数"
published: 2023-08-22
description: "本篇博客以开源代码RT Thread为例，描述了如何使用python扫描统计代码中频繁修改的函数，帮助我们发现系统中需求变化和BUG制造的重灾区。 需求背景 最"
image: ""
tags: ["效率工具-软件工具"]
category: ""
draft: false
---

> 本篇博客以开源代码[RT-Thread](https://gitee.com/rtthread/rt-thread)为例，描述了如何使用python扫描统计代码中频繁修改的函数，帮助我们发现系统中需求变化和BUG制造的重灾区。

## 需求背景

最近在学习设计模式时，印象深刻的一句话就是“要将设计模式应用在不稳定、频繁修改的地方，在变化处应用招式”，那么什么样的地方是频繁变化的？找出变化点最好的办法就是模块或者系统的架构师可以根据经验预测识别出系统的需求热点、发展趋势，指导我们进行重构。但是我想有没有其他办法，统计出我们可能注意不到的潜在变化热点呢？这些函数可能预示着我们的代码质量不佳、频繁出现BUG，或者这块代码需求经常变更，面临剧烈的修改冲击。这样的代码，我们要把它找出来，主动思考进行合理的架构设计来抵御需求变化或者BUG产生。

## 关键技术

要实现上面的功能，我们要摸底下面的几个关键信息能不能搞定：

1. 代码修改记录，有了修改记录才能统计热点。
2. 代码修改记录筛选，我们只需要精确到函数级别，精确到某一行代码是否频繁修改没有意义，一般修改不会只改一行。
3. 自动化统计手段，依靠人工统计是不现实的。

上面的三个问题，提前尝试了一下解决方法如下：

1. 代码记录自然想到从git获取，git一般查询git log命令获取修改记录，尝试了一下如下：

    ```c
    $ git log
    commit cc2d54ff9fa0b4e958d4a46dacc1106abac9432e (HEAD -> master, origin/master)
    Merge: 31b6533ba f94ffe28e
    Author: Bernard Xiong <bernard.xiong@gmail.com>
    Date:   Thu Jun 27 15:47:17 2019 +0800

        Merge pull request #2781 from jinsheng20/Timer

        增加基础定时器驱动

    commit 31b6533baa1d52f070ce43fecaf0183af9ef7299
    Merge: ef6a4aee9 7d0907185
    Author: Bernard Xiong <bernard.xiong@gmail.com>
    Date:   Thu Jun 27 13:49:16 2019 +0800

        Merge pull request #2811 from enkiller/nfs

        [components][dfs][nfs] 修复连接 Linux NFS服务器认证错误的问题

    ```
    可以看到，git log可以看到提交的修改记录，每个修改记录都有一个独一无二的commit id。但是不幸的是，我们并不能从这里面看出具体修改了什么，没关系，使用git show即可，git show commit_id filename还可以指定特定文件。
    ```c
    $ git show 7d0907185837152b918bd4a4b749d453171f6a9f
    commit 7d0907185837152b918bd4a4b749d453171f6a9f
    Author: tangyuxin <462747508@qq.com>
    Date:   Wed Jun 26 11:33:41 2019 +0800

        [components][dfs][nfs] ÐÞ¸´Linux NFS·þÎñÆ÷ÈÏÖ¤ÎÊÌâ

    diff --git a/components/dfs/filesystems/nfs/SConscript b/components/dfs/filesystems/nfs/SConscript
    ems/nfs/SConscript
    index 8f1e6defc..f830dfc75 100644
    --- a/components/dfs/filesystems/nfs/SConscript
    +++ b/components/dfs/filesystems/nfs/SConscript
    @@ -6,6 +6,8 @@ cwd = GetCurrentDir()
    src = Glob('*.c') + Glob('rpc/*.c')
    CPPPATH = [cwd]

    +SrcRemove(src, ['rpc/auth_none.c'])
    +
    group = DefineGroup('Filesystem', src, depend = ['RT_USING_DFS', 'RT_USING_DFS_NFS'], CPPPATH = CPPPATH)

    Return('group')
    diff --git a/components/dfs/filesystems/nfs/dfs_nfs.c b/components/dfs/filesystems/nfs/dfs_nfs.c
    index f36531456..e60f6f98c 100644
    --- a/components/dfs/filesystems/nfs/dfs_nfs.c
    +++ b/components/dfs/filesystems/nfs/dfs_nfs.c
    @@ -225,7 +225,7 @@ static nfs_fh3 *get_dir_handle(nfs_filesystem *nfs, const char *name)
            copy_handle(handle, &nfs->current_handle);
        }

    -    while ((file = strtok_r(NULL, "/", &path)) != NULL && path[0] != 0)
    +    while ((file = strtok_r(NULL, "/", &path)) != NULL && path && path[0] != 0)

    ```

2. 有了记录之后，我们要从中筛选出我们感兴趣的函数名，准确从文本中识别出函数名个人感觉不是一件容易的事情，函数名字的形式和参数都多变，不过仔细观察上面的比较记录，会发现git自己能够识别出函数名，并专门使用@@标示出来了，如下的void SystemClock_Config(void)函数，我们只需要筛选符合@@的行就可以了。例子里给了一个`@@.*@@\s((\w+)\s+)+[\*,&]*\s*(\w+)\s*\(`，效果不是特别好，你可以自己根据函数特点修改，修改后可能需要重新改下最后拼接res_str的地方。
   ```c
    @@ -160,14 +165,14 @@ void SystemClock_Config(void)
    RCC_ClkInitTypeDef RCC_ClkInitStruct = {0};
    RCC_PeriphCLKInitTypeDef PeriphClkInitStruct = {0};

    -  /**Configure LSE Drive Capability
    +  /** Configure LSE Drive Capability
    */
    HAL_PWR_EnableBkUpAccess();
    -  /**Configure the main internal regulator output voltage
    +  /** Configure the main internal regulator output voltage
    */
    __HAL_RCC_PWR_CLK_ENABLE();
    __HAL_PWR_VOLTAGESCALING_CONFIG(PWR_REGULATOR_VOLTAGE_SCALE1);
    -  /**Initializes the CPU, AHB and APB busses clocks
    +  /** Initializes the CPU, AHB and APB busses clocks
    */
    RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_LSI|RCC_OSCILLATORTYPE_HSE;
    RCC_OscInitStruct.HSEState = RCC_HSE_ON;
    ```
3. 自动化工具方面这种文本处理的肯定使用python是最快的，git可以使用gitpython库，使用pip install gitpython安装即可，避免使用原生git命令行的繁琐。文本筛选肯定使用正则表达式最方便，可以实现我们想要的功能。

## 具体脚本

```python
# -- coding: utf-8 --

# author: tanxiaoyao
# date:2019.06.29
import thread

import git
import re
import sys
import threading
import time

reload(sys)
sys.setdefaultencoding("utf-8")

# 全局变量定义
thread_num = 10 # 使用的CPU线程数
commit_num = 1000 # 需要遍历的commit数量
repo = git.Repo.init("D:\\02.Code\\02.Reference\\02.OS\\rt-thread") # 仓库路径，根据自己的实际填写
folder_path = "." # 需要扫描的子文件夹路径
diff_regex = r"@@.*@@\s((\w+)\s+)+[\*,&]*\s*(\w+)\s*\(" # 修改函数名匹配正则表达式，根据自己的需要修改
max_modified_filenum = 30 # 允许的单次提交修改的最大文件数，排除分支合并的commit

# 正则匹配
commit_regex = r"commit\s(\w{40})" # commit匹配正则表达式，当前简单匹配40个hash码


# 全局线程互斥变量
fun_dict= {}
lock = threading.Lock()
global final_thread_count
final_thread_count = 0


# 获取正则匹配结果
def get_regex_match(src_str, regex_str):
    partten = re.compile(regex_str)
    match = partten.findall(src_str)
    return match

# 获取小于特定修改文件数的commit，支持多线程
def get_commit_lessthan(match, thread_id):
    fo = open("fo" + str(thread_id) + ".txt", "w")
    ok_list = []
    count = 0

    # 筛选修改文件数符合要求的commit
    for commit in match:
        filelist_str = repo.git.show(commit, stat=True)
        name_patt = re.compile(commit_regex)
        name_match = name_patt.findall(filelist_str)
        if len(name_match) <= max_modified_filenum:
            ok_list.append(commit)

    # 获取每个commit的具体修改内容
    for commit in ok_list:
        if commit is "":
            continue
        diff_str = get_commit_content(commit,"*")
        # 从内容中提取修改的函数
        change_fun_list = get_change_funcs(diff_str)
        fo.write(diff_str)
        count += 1

        lock.acquire()
        try:
            # 添加到全局数组
            add_funlist2dict(change_fun_list)
            print "Thd" + str(thread_id) + "\t" + commit + "_" + str(count) + "/" + str(len(ok_list))
        finally:
            lock.release()

    fo.close()
    global final_thread_count
    final_thread_count += 1

# 按指定数量拆分数组
def chunks(l, n):
    for i in xrange(0, len(l), n):
        yield l[i:i+n]

# 获取commit列表
def get_commit_list():
    log = repo.git.log(folder_path)
    all_commit = get_regex_match(log, commit_regex)
    commit_groups = list(chunks(all_commit, commit_num / thread_num))
    print commit_groups

    # 开始多个线程扫描修改commit，修改函数名
    try:
        for index in range(0, min(thread_num, len(commit_groups))):
            thread.start_new_thread(get_commit_lessthan, (commit_groups[index], index,) )
    except:
        print "start thread fail!"

    return

# 获取COMMIT中文件的修改内容
def get_commit_content(commit_id, file_name):
    return repo.git.show(commit_id, file_name)

# 提取差异中的函数
def get_change_funcs(diff_log):
    return get_regex_match(diff_log, diff_regex)


# 将函数加入全局dict
def add_funlist2dict(list):
    for fun in list:
        if fun_dict.has_key(fun):
            fun_dict[fun] = fun_dict[fun] + 1
        else:
            fun_dict[fun] = 1


# dict按照value值排序
def sort_funcdict(dict):
    items = dict.items()
    backitems = [[v[1], v[0]] for v in items]
    backitems.sort(None, None, True)
    return [[v[1], v[0]] for v in backitems]


if __name__ == '__main__':
    # 开始处理
    get_commit_list()
    # 等待所有线程处理完毕
    while(final_thread_count < thread_num):
        time.sleep(1)

    # 输出结果
    resfile = open("result.txt", "w")
    sorted_list = sort_funcdict(fun_dict)
    for func_name, times in sorted_list:
        res_str = " times:" + str(times) + "\t" + func_name[1].strip() + " " + func_name[2].strip() + "\n"
        resfile.write(res_str)
    resfile.close()
```

## 运行效果

提示：依赖gitpython库，使用pip install gitpython安装。运行后结果输出在脚本同级目录的result.txt中

```c
 times:77	void SystemClock_Config
 times:50	if GetDepend
 times:36	int main
 times:19	void MX_GPIO_Init
 times:18	void stm32_dma_config
 times:18	typedef void
 times:18	HAL_StatusTypeDef HAL_RCC_OscConfig
 times:17	void HAL_MspInit
 times:16	typedef struct
 times:14	rt_err_t es32f0x_configure
 times:14	int rt_hw_spi_bus_init
 times:13	void rt_schedule
 times:13	void HAL_UART_MspDeInit
 times:13	void HAL_SMARTCARD_IRQHandler
 times:13	rt_err_t drv_control
 times:12	void uart_isr
 times:12	HAL_StatusTypeDef SMBUS_Slave_ISR
 times:11	void phy_monitor_thread_entry
 times:11	void MX_USART1_UART_Init
 times:11	def PrepareBuilding
 times:11	HAL_StatusTypeDef HAL_SPI_TransmitReceive
 times:10	void HAL_UART_MspInit
 times:10	void HAL_CAN_IRQHandler
 times:10	rt_err_t rt_sensor_open
 times:10	rt_err_t rt1052_pin_irq_enable
```

如果仓库修改记录很多，运行时间会比较长，可以在脚本中限制一下统计次数，运行速度主要消耗在git比较两个commit上。