---
title: Linux系统移植简述
date: 2020-03-16 14:12:38
tags:
    - 系统移植
---

# 写在前面
之前也做过一些移植性的东西，不过都是别人搭好框架，自己填充一些模块，这次有机会完成系统级的移植，非常感谢张总以及胡老师的指点帮助，收获良多！

<!--more-->
# 移植总述
嵌入式系统移植分为四个大块，分别是构建交叉编译工具，rootfs的制作，kernel的配置、编译、移植，BootLoader的移植。需要移植的系统可以在MIPS上跑起来，我只需要顺着原有的编译框架完成ARM64的编译，之后再上板子做具体的调试。

## 构建交叉编译工具
toolchain一般芯片厂家会提供，当然自己通过buildroot构建也是可以的。
使用buildroot构建交叉编译工具，下载buildroot2015
```
wget http://buildroot.uclibc.org/downloads/buildroot-2015.08.tar.gz
```
`make menuconfig ARCH=arm64`配置buildroot，将target和toolchain两项配置成如下所示
![](https://rancho333.gitee.io/pictures/buildroot.png)
之后`make`等待完成即可，buildroot有些源码下载速度很慢，下载网站也不尽相同，比较麻烦，不像Linux发行版可以改成国内镜像软件源，有的可能会等待比较长的时间。
将生成的toolchain打包，释放到服务器docker编译环境中，如下所示：
![](https://rancho333.gitee.io/pictures/toolchain.png)
之后可以根据container构建image将编译环境发布出去，大家就可以直接使用了。

## kernel的配置、编译、移植
kernel的配置结果保存在`.config`文件中，根据实际的需求会选配一些内核选项，如开启nat以及veth相关的配置
![](https://rancho333.gitee.io/pictures/nat.png)
![](https://rancho333.gitee.io/pictures/veth.png)
这些配置实际上是系统构建完成后跑起来报错才知道需要的，只需要在`make menuconfig`中搜索对应关键字即可找到编译选项。
关于内核编译的一些说明，可以参考这篇文章
[kernel编译简述](https://rancho333.gitee.io/2020/03/11/kernel%E7%BC%96%E8%AF%91%E7%AE%80%E8%BF%B0/)

## rootfs的制作
在这一步其实花的时间是最多的，因为这里涉及到大量的上层应用模块的编译，然后这些模块的依赖库在交叉工具链中是不存在的，还有部分是需要编译一些独立的Linux命令。解决办法很简单，下载源码，编译出库，之后放到交叉工具链和文件系统中即可。
这里说下开源代码交叉编译的经典三部曲`configure, make, make install`，在configure中会指定交叉编译工具，编译生成文件的install路径,关于动态库的一些理解可以查看这篇文章
[关于动态库以及constructor属性的使用](https://rancho333.gitee.io/2020/02/26/%E5%85%B3%E4%BA%8E%E5%8A%A8%E6%80%81%E5%BA%93%E4%BB%A5%E5%8F%8Aconstructor%E5%B1%9E%E6%80%A7%E7%9A%84%E4%BD%BF%E7%94%A8/)
嗯，rootfs以前一直用buildroot来制作，这里发现一个不一样的方式
```
1. 使用mktemp命令创建一个临时文件
2. 使用shell命令构建文件系统，就是echo命令然后重定向到临时文件
3. 使用gen_init_cpio和压缩软件构建cpio格式的压缩包
4. 删除临时文件
```
![](https://rancho333.gitee.io/pictures/rootfs.png)

## BootLoader的移植
给的开发板上直接烧有uboot，所以这里不涉及自己构建bootloader了。在bring up的过程中遇到一个问题卡了很久：
![](https://rancho333.gitee.io/pictures/panic.png)
返回错误8的含义`文件没有可执行权限`,确认过busybox的执行权限，并且是静态编译，并且可以在同平台的其它机器上执行。
真实的错误是kernel在rootfs中没有找到文件系统，比较详细的描述见上文提到的`kernel编译简述`。


参考资料：
[linux init启动分析](https://www.cnblogs.com/kernel-style/p/3397705.html)