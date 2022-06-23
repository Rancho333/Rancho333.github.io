---
title: 对SONiC项目的认识
date: 2021-02-25 13:36:57
tags: SONiC
---

# SONiC简介
不做过多赘述，SONiC本质就是一个Linux交换机网络操作系统，它有两个特点。

<!--more-->
第一，它是基于SAI的，在没有SAI之前所有的芯片都要通过自己的SDK与上层软件进行通信，相当于用自己的“方言”与上层操作系统通信，SAI把这个“方言”标准化，大家的芯片用同样的语言同上层的控制软件交流，因为有了SAI，所以才能建立一个操作系统。有了SAI之后，适配ASIC的工作由芯片厂商完成，白盒交换机厂商推出一款新产品所花费的时间大大缩短。

第二，基于Docker，Sonic有丰富的扩展性。依托于Linux,Docker生态，Sonic孕育了丰富的管理软件和解决方案。而其自身也于Redis, Quagga, LLDP等开源技术碰撞出更多火花。

2016年，SONiC的理念就是将传统交换机OS拆分成多个容器化组件的解决方案，进而也定义了控制面的容器化架构，囊括了组件和编程接口。

2017年微软对SONiC的性能进行了大幅升级，全面支持IDV，并且融合了更多的容器特性。

2018年微软又在管理性上下了大力气（如ConfigDB）

# 对SONiC项目的学习
相比于传统Linux交换机操作系统几十M的镜像大小，SONiC镜像动辄几百M甚至超1G，这也说明了里面包含的内容极其庞杂。如果有比较深厚的Linux功底，上手会很快。因为里面大多是Linux本质性、不变性和可复用性的东西。以自己对SONiC项目的认知，将其划分为5个大块比较合适。分别是：
- SONiC的编译
- SONiC的安装
- SONiC的bring up
- SONiC的上层应用
- TestBed自动化测试

## SONiC的编译
这一步本身就是一个庞大的源码编译出Linux安装镜像的过程，类比于LFS。这里可以借用嵌入式操作系统移植的4个步骤用来辅助说明。

1. 交叉编译环境的制作。一般而言，SONiC的宿主机与目标机都是x86，所以没有交叉编译这种说法，但是sonic是支持ARM和ARM64的，只是现阶段我没玩过。值得关注的是，SONiC在编译之前会制作一个docker用来打包编译环境，之后所有的编译在里面完成。
2. kernel的配置、编译、移植。SONiC在kernel编译时会指定config，参见kernel的Makefile，我们可以按需修改。
3. 根文件系统的制作。SONiC使用debootstrap完成文件系统的基础架构，之后会将编译好的deb包，whl包等target释放或拷贝到rootfs中去，最终生成的sonic-platform.bin是一个fs.zip、fs.squashfa、docker.tar.gz以及初始化脚本的打包可执行文件。
4. bootloader的移植。裸机装bios没有玩过，SONiC盒子需要在bios之上安装一个ONIE，ONIE本质是一个小的Linux，提供SONiC安装环境

对于这一部分，如果有一个比较全面的概览，当有porting或任何需要修改源码的需求时，将会有一定方向性。SONiC的编译框架主要由shell脚本，Makefile，Dockefile以及j2模板文件构成，需要有一定的Makefile、shell脚本基础。

## SONiC的安装
SONiC的安装是某种程度上是生成镜像的一个逆向过程。sonic-asic.bin是一个shell脚本，可以在shell下直接执行一下看看会发生什么事情。SONiC安装的本质其实就是bash ./sonic-asic.bin的执行过程。

SONiC可以在ONIE和SONiC环境下完成安装，这里面会调用两个脚本sharch_body.sh和install.sh。SONiC的安装时会有一些打印，参照打印与shell脚本可以发现里面做了什么,关注一下`/boot`目录。在此处简单说明一下：
- 在sharch_body.sh中
    - 对image文件进行hash校验
    - 为install.sh准备运行环境并执行install.sh
- 在install.sh中
    - 确定安装环境（ONIE、SONiC、build）
    - 调用machine.conf，准备platform相关环境变量，配置console，默认是ttyS0和9600。参数设置不匹配将导致SONiC bring up失败。新安装的onie，需要在onie下修改eeprom以及machine.conf(这个可以在onie编译的时候指定)。需要关注修改三个字段：onie_switch_asic、onie_machine、onie_platform。
    - 安排安装os的分区（uefi+gpt）
    - 解压fs.zip(boot+platform+docker+fs.squashfs)至分区，onie和SONiC安装会有一些细微差别。这里将创建boot和platform文件夹（在sonic的/host/image*下面，不是根目录），将驱动放到对应文件夹下，在rc.local中会释放出来。
    - 配置grub，安装完成 
    - 重启之后会按照安装时设置的grud启动新的操作系统

## SONiC的bring up
SONiC基于SAI可以： 一个镜像适配相同ASIC厂家的不同设备型号，每一个款设备都有自己的差异性配置文件，如端口，led，波特率等。SONiC是如何正确加载对应设备型号的配置文件的？这里留个问题可以自己查查。

SONiC是Linux, 所以遵循Linux的启动过程。
 1. bootloader + onie阶段
我们可以在onie下安装sonic，grub将cmdline参数传递给kernel，kernel启动，加载驱动

2. kernel启动之后systemd初始化阶段这里面可以细分
    - systemd相关，使用`systemctl list-dependencies graphical.target`查看当前加载的服务 
    - rc.local，这里面有一些启动后执行的动作，自己瞅瞅吧

需要关注一下SONiC的文件系统
- fdisk -l 	查看有哪些分区,以及分区大小。那么如何调整分区大小？改那个配置文件？
- df 查看下那些文件夹挂载在物理硬盘分区上
- cat /proc/cmdline	查看内核启动参数
- blkid			查看分区对应的PARTUUID

## SONiC的上层应用
SONiC的服务跑在docker中，如PMON、syncd、frr等。关于这些服务是如何启动的？可以参见《SONIC中docker运行服务的单分析》，源码中注意下`docker_image_ctl.j2`文件，这是docker的启动管理模板。

SONiC核心的功能就是交换路由，所以交换路由协议在里面是很重要的，与传统交换机相比，SONiC中的服务运行在docker中，使用redis集中式进行数据管理，其它并没有什么本质区别。

后续考虑以vxlan为切入点，深入了解学习SONiC的系统架构，对于vxlan，参见[vxlan学习](https://rancho333.gitee.io/2021/02/03/vxlan%E5%AD%A6%E4%B9%A0/)。

如何配置管理SONiC呢？传统的交换机会做一个命令行程序，指定用户登录后执行该程序，可以称之为CLI，在里面可以进入shell，也可以从shell退回CLI。社区版SONiC登录之后运行bash，用python做了一套简单的命令行，可以进行配置管理，这玩意解析速度极慢，使用体验极差。除此之外，还可以通过修改`config_db.json`然后重新加载或者直接使用`redis`命令行进行配置。当然SONiC支持SDN，可以通过openflow方式集中式管理配置。阿里在SONiC上面做了一套传统CLI，称之为`lambda-cli`，比社区版SONiC的命令行好用多了。

## TestBed自动化测试
TBD
