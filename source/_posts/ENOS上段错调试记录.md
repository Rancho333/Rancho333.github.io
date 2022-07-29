---
title: ENOS上段错调试记录
date: 2020-03-02 18:44:43
tags:
    - 段错误
---

# 写在前面

移植ENOS过程中发现某些系统编译生成的命令运行过程中报`segmentation fault`,报错信息如下。这里记录一下调试过程中遇到的问题，涉及到`weak`属性，`-pthread`，`strace`等。
<!--more-->
![](https://rancho333.github.io/pictures/fault.png)


## 段错调试手段记录

产生段错首先想到的自然是通过`gdb`进行错误分析，由于toolchain中并没有提供，所以自行下载了一个gdb源码，通过经典`configure, make, make install`三部曲后移到板子上，gdb调试信息如下：
![](https://rancho333.github.io/pictures/gdb.png)

gdb中并不能看出什么有效的信息，但看起来函数栈的调用还没有到ccs的main函数中（没有与ccs相关的打印），上一篇文章《关于动态库以及constructor属性的使用》中有提到。
通过`dmesg`查看内核报错信息：
![](https://rancho333.github.io/pictures/dmesg.png)
可以看到`pc`寄存器取址的地址为全0 ，这一般是因为空指针导致，我们知道cpu指令的执行顺序为取址，分析，执行三个步骤，没取到指令后续自然是啥都没有了。

通过`strace ccs`命令来查看ccs的详细调用过程关于动态库的调用过程就不表了，这里直接看报错的位置：
![](https://rancho333.github.io/pictures/strace.png)
发现执行完write指令之后就挂了，经过一番曲折之后定位到代码中：
![](https://rancho333.github.io/pictures/iv_signal.png)
`iv_fd_set_cloexec`中有两次`fnctl`的调用，与strace中的4次fnctl调用刚好对上，而函数`iv_signal_init`被`constructor`属性修饰，而该函数所在模块（libtask）是被编译成so供其它模块调用的，即所有调用该动态库的模块在执行main函数之前都会执行一遍`iv_signal_init`，进一步追查Makefile发现报错的命令全部都依赖与该动态库，一切都说通了，没有玄学。

在进一步排查，init中最可疑的就是`pthr_atfork`这个函数了，查看该函数定义，发现一个从没见过的用法`#pragma weak pthread_atfork`：
![](https://rancho333.github.io/pictures/atfork.png)
后面会再写一篇关于这个属性的用法，简单说就是被`weak`修饰的符号即使不存在编译也不会报错。

## weak之后的调试
这里发现libtask中既没有自己实现`pthread_atfork`,也没有在Makefile中链接`-pthread`，而是使用`ifdef HAVE_PRAGMA_WEAK`(后来我改成ifndef了)来进行屏蔽，在运行过程中自然会报错，在调用之前打印该函数的地址，不出意料的是`NULL`，维护人员最初的用意已经不可考证了，直接去掉`HAVE_PRAGMA_WEAK`,编译中加上`-pthread`。
![](https://rancho333.github.io/pictures/zhw_test.png)

这里有必要顺嘴提一下`-lpthread`和`-pthread`，如果使用`-lpthread`的时候会报一些`undefined reference to`的错误，错误原因可以自行百度，换成`-pthread`即可。
