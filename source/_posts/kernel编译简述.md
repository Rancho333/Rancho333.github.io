---
title: kernel编译简述
date: 2020-03-11 15:48:46
tags:
    - kernel
---

# 写在前面
在ENOS系统移植的过程中，对于Linux kernel，涉及到kernel的配置，编译，以及二进制镜像uImage的生成。这篇文章分为两块：
<!--more-->
1. 内核配置系统浅析
2. vmlinux,uImage,Image的关系或区别

# 内核配置系统浅析
Linux采用模块化的内核配置系统，保证了内核的可扩展性。Linux内核的配置系统由三个部分组成，分别是：
1. Makefile：分部在Linux内核源码中的Makefile，定义Linux内核的编译规则
2. 配置文件（.config, Kconfig等）
3. 配置工具
    1. 配置命令解释器，对配置脚本中使用的配置命令进行解释
    2. 配置用户界面，分为基于字符（make config）,基于Ncurses图形界面（make menuconfig），基于Xwindows图形界面（make xconfig）

## Makefile
Makefile的作用是根据配置的情况，构造出需要编译的源文件列表，然后分别编译，并把目标代码链接到一起，最终形成Linux内核二进制文件。kernel中Makefile相关的文件有：
1. 顶层Makefile，是整个内核配置、编译的总体控制文件，产生vmlinux文件和内核模块（module）
2. .config：内核配置文件，是执行完内核配置的结果，如果没有指定kernel根目录下没有.config，可以在make时指定特定的配置文件进行编译，之后也会在根目录下产生.config
3. arch/*/Makefile：不同CPU体系的Makefile，系统移植需要多关注一些这部分
4. 各子目录下的Makefile，如drivers下的，负责所在子目录下源代码的管理
5. Rules.make：规则文件，被所有的Makefile使用

用户通过make config后，这里实际就是收集各目录下的Kconfig/deconfig文件生成配置界面，供用户进行功能选择，最后产生`.config`，如果.config文件存在，则是直接通过.config生成配置界面。顶层Makefile读入.config中的配置选择进行具体模块的编译。顶层Makefiel中会包含具体arch的Makefile
![](https://rancho333.gitee.io/pictures/arch.png)
Rules.make其实就是不同模块之间会共用到的Makefile规则。

在ENOS中，系统架构人员将生成好的ARCH的config文件存放ARCH的目录下，上层开发人员编译时直接使用指定的config文件编译即可。
![](https://rancho333.gitee.io/pictures/config.png)
之后在指定的`O`目录下会生成编译过程中生成的文件，这样可以避免污染源码（make clean不能清除么），或者是更便于管理和模块化考虑。
如果需要进行kernel的二次配置，需要到`O`目录下去执行make menuconfig，之后将重新生成的`.config`拷回`ARCH`目录覆盖之前的配置文件。这是基于ARCH缺省配置的一种应用，在向内核代码增加了新的功能后，如果新功能对于这个ARCH是必需的，就需要修改此ARCH的缺省配置，修改方法如下：
1. 备份.config文件
2. cp arch/arm/deconfig .config
3. 修改.config
4. cp .config arch/arm/deconfig
5. 恢复.config

### 配置变量CONFIG_*
.config文件中用配置变量等式来说明用户的配置结果，等式左边是模块/功能,右侧是控制选项，有三种：
1. `y`表示后本编译选项对用的内核代码被静态编译进Linux内核
2. `m` 表示本编译选项对应的内核代码被编译成模块
3. `n`表示不选择此编译选项
如果根本没有选择某模块，该模块是被注释掉的

# vmlinux,uImage,Image的关系或区别
Linux内核有多种格式的镜像，包括vmlinux、Image、zImage、bzImage、uImage、xipImage、bootpImage等。
vmlinux是编译出来的最原始的内核文件，未经压缩，vm代表virtual memory Linux支持虚拟内存；
Image是经过objcopy处理的只包含二进制数据的内核代码，未经压缩，不是elf格式；objcopy的实质是将所有的符号和 重定位信息都抛弃，只剩下二进制数据。
zImage是vmlinux加上解压代码经gzip压缩而成，是ARM linux常用的一种压缩镜像文件。这种格式的Linux镜像多存放在NAND上。bzImage与之类似，只不过是采用了压缩率更高的算法。
uImage是uboot专用的镜像文件，它是在zImage之前加上一个长度为0x40的tag，里面包含了镜像文件的类型、加载位置、生成时间、大小等信息。通过mkimage命令可以制作uImage。
xipImage多放在NorFlash上直接运行。
这里只是一些简单的描述，有待在今后的项目中去加深理解各种格式的使用，存在肯定是有其对应的使用场景的！
![](https://rancho333.gitee.io/pictures/vmlinux.png)

# 对于文件系统的一点理解
加在这里可能不是很符合这篇文章的主题！
Linux下一切皆文件。Linux系统中任何文件系统的挂载必须满足两个条件：挂载点和文件系统。rootfs之所以存在，是因为需要在VFS机制下给系统提供最原始的挂载点。
rootfs其实就是文件系统顶层的`/`，使用pwd命令后看到的第一个字符，它有三个特点：
1. 它是系统自己创建并加载的第一个文件系统，是Linux内核自己创建的，并不是我们常说的外部根文件系统，将外部根文件系统解压或者说挂载到`/`后就是用户能看到的Linux文件系统，里面有很多的文件夹，如'etc'、'bin'等。*不能被unmount或者删除*，通过`cat /proc/mounts`也可以看出。下述的rootfs特指`/`
2. 该文件系统的挂载点就是它自己的根目录项对象
3. 该文件系统仅仅存在于内存中
VFS是Linux文件系统实现遵循的一种机制，rootfs是一种是一种具体实现的文件系统，Linux下所有文件系统的实现都必须符合VFS机制（符合VFS的接口），这是二者的真正关系。

Linux系统移植过程有一项是制作根文件系统，这里所谓的根文件系统实际上是外部根文件系统，用来释放到rootfs里面。有几个概念`ramfs initramfs`，ramfs是linux中的一个内存文件系统,initramfs是一种压缩（可以是lzma，zip等，看kernel的支持情况）的cpio格式的归档文件，initrd（initramdisk）也是一中ramfs镜像文件，它是用来在启动过程中初始化系统的，它可以被卸载。区别如下：
1. 它必须是和kernel分离的一种形式存在
2. 他只是一个zip压缩的文件系统，而不是cpio文件
3. initrd中的/initrd程序只是做一些setup操作并最后返回到kernel中执行，而initramfs中的/init执行完后不返回到kernel

对于initramfs，也就是系统移植时需要制作的文件系统。它存在于两处，一种是内核编译后自动生成的内部initramfs(在/usr目录下)，另一种是用户自己制作的，通过cmdline将地址传递给kernel的外部initramfs
对于内部initramfs，这个文件系统里面实际上啥也没有：
![](https://rancho333.gitee.io/pictures/initramfs_kernel.png)
rootfs挂载之后，首先会先释放这个内部的initramfs到rootfs（很显然啥也干不了！*没搞清楚为什么会存在，但肯定有原因！*）,然后kernel会尝试在rootfs中寻找/init，一旦找到就执行init，kernel也就完成了启动工作，之后init就会接管接下来的工作。如果kernel找不到，就会去找外部initramfs然后释放（uboot下通过initrd参数指定位置）或者按照标准做法解析参数`root=`（这里面是解压好到某个介质分区的文件系统），试图找到一个文件系统并挂载到rootfs，之后就init。

所以我们实际使用的肯定是外部文件系统了，对于外部的文件系统，我们可以通过不同的方法将它挂载到rootfs。
1. 制作一个独立的cpio.lzma包，然后告诉bootloader它的地址，通过cmdline将参数传递给kernel
2. 制作一个独立的包，通过mkimge(只针对于uboot)将kernel+initramfs+dtb打包成一个文件，在uboot下启动（实验过可行）
3. 用外部的initramfs替换kernel自动生成的initramfs，有两种方法：
    1. 先编译kernel，让它生成内部intramfs，然后制作外部initramfs，拷贝替换掉，最后重新编译内核。外部initramfs就会和kernel编成一个文件。ENOS里面使用的是这种方法。
    2. 使用内核编译选项CONFIG_INITRAMFS_SOURCE指定根文件系统路径，即kernel会根据给定的文件生成内部initramfs，这里面又有集中不同的给定方式，这里不表。
![](https://rancho333.gitee.io/pictures/kernel_initramfs.png)
    外部initramfs替换内部initramfs之后，kernel会在第一时间找到/init,所以`root=，initrd=`这些参数都不会起作用了。


参考资料：
[Linux内核配置系统浅析](https://www.ibm.com/developerworks/cn/linux/kernel/l-kerconf/)
[zImage和uImage的区别联系](https://blog.csdn.net/ultraman_hs/article/details/52838989)
[ramfs,rootfs,initramfs,initrd](https://blog.csdn.net/rikeyone/article/details/52048972)
[initramfs的使用方法](https://blog.csdn.net/sunjing_/article/details/53081306)
