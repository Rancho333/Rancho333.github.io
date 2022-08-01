---
auth: Rancho
title: Linux下程序调试方法简述
date: 2020-08-05 14:58:02
tags: Linux
---

# 写在前面
本文旨在综合性的描述Linux下程序调试的方法和思路，不会过于细节的描述某种工具的使用，如gdb，这些方法通过man以及google都能找到答案。包含知识点：strip, addr2line, strace, gdb, readelf。

<!--more-->
## strip相关
嵌入式系统要求小巧精简，最大限度去除冗余数据。Linux下编译出来elf文件是带有符号表的，通过`nm`命令可以查看，如：
![](https://rancho333.github.io/pictures/nm.png)
这些符号表是进行程序调试的关键，例如通过`addr2line`进行地址和文件名或行数的转换，例如在`gdb`中通过`bt`显示函数调用栈信息，没有符号表这些工具都无法提供有价值信息。
`strip`命令可以去掉这些符号信息，进而减小文件大小，同时不会影响elf的正常执行。
![](https://rancho333.github.io/pictures/compare.png)
可以看到，`strip app`之后，app中没有符号表相关信息了。
在进行rootfs制作时，对于发行版本，我们进行`strip`操作，对于开发人员调试版本，我们保留符号表信息。
![](https://rancho333.github.io/pictures/strip.png)
 
## gdb简述
遇到`core dump`最常使用的就是`gdb`了，`gdb`的一般使用方法`gdb app core`。常见子命令如下：

| cmd | function |
| :----- | :----- |
| bt | 回溯显示app堆栈 |
| bt full | 不仅仅显示栈帧，还显示局部变量 |
| info reg | 显示寄存器内容 |
| run | 执行app |
| print val | 打印变量val的值 |
| break | 设置断点 |

gdb一般使用*断点*和*堆栈*进行程序调试，注意调试的程序一定要是`not stripped`的。
简单示例如下：
![](https://rancho333.github.io/pictures/gdb.png)

## strace介绍
strace可以跟踪app的`system call`和`signals`，一般使用方法`strace app`，常见参数如下：

| cmd | function |
| :----- | :----- |
|-tt | 在每行输出的前面，显示毫秒级别的时间 |
| -T | 显示每次系统调用所花费的时间 |
| -v | 对于某些相关调用，把完整的环境变量，文件stat结构等打出来 |
| -f | 跟踪目标进程，以及目标进程创建的所有子进程 |
| -e | 控制要跟踪的事件和跟踪行为,比如指定要跟踪的系统调用名称 |
| -o | 把strace的输出单独写到指定的文件 |
| -s | 当系统调用的某个参数是字符串时，最多输出指定长度的内容，默认是32个字节 |
| -p | 指定要跟踪的进程pid, 要同时跟踪多个pid, 重复多次-p选项即可 |
| -i | 在打印系统调用同时打印指令指针 |

举个之前在ENOS飞腾移植过程中的一个例子，先使用gdb做一个基本的错误定位
![](https://rancho333.github.io/pictures/strace1.png)
看起来像是没有进入main函数就已经挂了。
使用strace查看命令执行过程中的系统调用和信号：
![](https://rancho333.github.io/pictures/strace2.png)
找到源码中的对应位置：
![](https://rancho333.github.io/pictures/strace3.png)
iv_signal_init在main函数之前会执行并挂掉，将之注释掉测试通过。

## so库相关
使用`ldd`命令可以查看app的依赖库，`readelf`命令可以获取到更多的内容
![](https://rancho333.github.io/pictures/so.png)

如果app的依赖库找不到，报错格式一般如下：
![](https://rancho333.github.io/pictures/so_not_find.png)

这里面缺少一些动态库，二进制可执行文件，分3种情况：
1. 文件不存在
2. 文件存在但路径不对, /etc/ld.so.conf 此文件记录了编译时使用的动态库的路径
3. 有些文件不必须，可以注释掉，参考
根据不同的情况处理之。
