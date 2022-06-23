---
title: broadcom_sdk_cmd
date: 2021-01-19 14:58:33
tags:
---

# BCMShell简介
BCMShell是Broadcom公司对于ASIC的SDK命令解释器。利用该工具可以对ASIC所有的寄存器和内存进行读写操作，还可以利用脚本在ASIC上搭建各种复杂的网络环境。
<!--more-->

# BCMShell的几种模式

## BCMshell模式
拿到Broadcom源码后，根据OS上的kernel版本选择对应的内核头文件编译SDK，之后会得到几个文件
```
bcm.user  bcm.user.dbg  linux-bcm-knet.ko  linux-kernel-bde.ko  linux-user-bde.ko  netserve
```
参考SDK包运行环境中的`auto_load_user.sh`，安装对应驱动，启动`bcm.user`即可进入BCMShell命令行，提示如下：
```
BCM.0> 
BCM.0> exit
```
`exit`退回到shell。
如果OS是SONiC，执行`bcmsh`也可进入，通过`bcmcmd cmd`可以在shell下在BCMShell中执行命令。


## 回退到shell模式
在BCMShell模式中通过命令`shell`可以进入shell里面执行命令，应该是将bcmshell放到后台运行，在shell中exit即可再次回到bcmshell。
```
BCM.0> 
BCM.0> shell
root@sonic:/home/admin/R1241-M0150-01_V0.0.2_Questone2F_SDK# exit
exit
BCM.0> exit
root@sonic:/home/admin/R1241-M0150-01_V0.0.2_Questone2F_SDK# 
```

## cint模式
在BCMShell模式中通过命令`cint`可以进入到C interpreter模式，可以在里面执行C函数，如gearbox的一些操作可以在里面完成，`exit;`回退道bcmshell。
```
BCM.0> 
BCM.0> cint
Entering C Interpreter. Type 'exit;' to quit.

cint> exit;
BCM.0> 
```

# BCMShell的一些特点

1. 不区分大小写
2. 支持缩写

`?`可以显示所有命令。以`PortStat`为例：PortStat和portstat等效，缩写规则是大写字母是可缩写项，PortStat可缩写为ps

# 命令说明
BCMShell命令可以分为五类：
1. 帮助命令
2. show命令
3. 低级命令：对寄存器/RAM进行读写的命令
4. 端口命令：与端口相关的命令
5. 芯片MAC学习，通信协议相关的命令

## 帮助命令
总共有五种帮助命令使用方法，使用一种即可`cmd + ?`，如：
```
BCM.0> ps ?
Usage (PortStat): Display info about port status in table format.
    Link scan modes:
        SW = software
        HW = hardware
    Learn operations (source lookup failure control):
        F = SLF packets are forwarded
        C = SLF packets are sent to the CPU
        A = SLF packets are learned in L2 table
        D = SLF packets are discarded.
    Pause:
        TX = Switch will transmit pause packets
        RX = Switch will obey pause packets
```

## show命令
常用show命令如下：
```
show c                  查看ASIC各个端口收发包情况，可以加子命令过滤
show ip                 查看ip报文统计计数
show icmp               查看icmp报文统计计数
show arp                查看arp报文统计计数
show udp   
show tcp
show routes             查看子网路由表和主机路由表

show unit               查看芯片信息
show params             查看当前芯片驱动配置参数
show features           查看当前芯片的特性
```

## 低级命令

低级命令的作用主要是对寄存器和RAM进行读写。

### 对寄存器进行读写

| 寄存器类别 | 含义 |
| :--- | :--- |
| PCIC | PCI配置寄存器 |
| PCIM | PCI内存映射寄存器 |
| SOC | 交换芯片寄存器与内存 |
| PHY | PHY寄存器 |

寄存器常用命令如下：
```
getreg          获取寄存器的值
listreg         显示所支持的寄存器信息
setreg          设置寄存器的值
```

### 对内存表进行读写
内存表读操作： dump
内存表写操作： write

## 端口命令
端口命令主要是端口设置`PORT`命令和端口显示`PortStat`命令。举例如下：
设置xe0 loopback：
```
BCM.0> port xe0 lb=phy
```

## 高级命令
高级命令可以对协议等复杂功能进行设置，如ACL，OAM等。
```
l2 show                                             显示mac地址表
l2 add port=ge2 macaddress=0x000000000001 vlan=1   在ge2端口静态添加mac地址
```
