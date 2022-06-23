---
title: SONiC路由协议简述
date: 2021-04-08 17:38:53
tags: SONiC
---

## 写在前面
本文通过研究SONiC中已支持的路由协议BGP，了解SONiC中路由模块的工作流程，进而为支持SONiC中暂未支持的路由协议（ospf、rip、pim）的porting打下基础。以协议栈收包，协议栈状态机运转，协议栈表项生成下发至SDK为方向进行研究。

<!--more-->
## SONiC中支持的协议
SONiC中支持BGP、ECMP、LLDP、QoS、SNMP、NTP、DHCP、VxLAN、NAT、ARP等协议。其中，使用FRR作为默认路由协议栈。运行在`bdp`容器中。

## 初步了解FRR
对于FRR的框架不做过多赘述，可以参见《FRR开源代码研究》，其脱胎于quagga。SONiC中FRR运行在`bgp`容器中，运行`docker exec -it bgp bash`进入该容器，但是SONiC中现在只支持BGP协议。执行`vtysh`进入FRR命令行，如下所示：
```
root@sonic:/# vtysh 

Hello, this is FRRouting (version 7.2.1-sonic).
Copyright 1996-2005 Kunihiro Ishiguro, et al.
```

在`201911`分支上使用的是7.2.1, 在`~/rules/frr.mk`中可以看到。SONiC的master分支使用的FRR版本是7.5.1(sonic基于此进行porting),与FRR官方最新的[release](https://github.com/FRRouting/frr/releases)保持一致。

在进行FRR模块调试的过程中，我们可以单独更新FRR模块。
```
[rancho sonic-buildimage]$ make list | grep frr
"ROUTING_STACK"                   : "frr"
target/debs/stretch/frr_7.2.1-sonic-0_amd64.deb
target/debs/stretch/frr-pythontools_7.2.1-sonic-0_all.deb
target/debs/stretch/frr-dbgsym_7.2.1-sonic-0_amd64.deb
target/debs/stretch/frr-snmp_7.2.1-sonic-0_amd64.deb
target/debs/stretch/frr-snmp-dbgsym_7.2.1-sonic-0_amd64.deb
target/docker-fpm-frr.gz
target/docker-fpm-frr-dbg.gz
```

## SONiC中路由模块的交互
SONiC中路由模块交互如下图所示：

![](https://rancho333.gitee.io/pictures/frr-sonic.png) 

1. 在BGP容器初始化时， zebra通过TCP socket连接到`fpmsyncd`。在稳定状态下，zebra、linux kernel、APPL_DB、ASIC_DB、ASIC中的路由表应该是完全一致的。
这里做一点说明，OSPF、BGP等路由进程会将自己选择出的路由发送给zebra，zebra通过计算筛选之后会通过netlink将之同步给kernel，同时zebra通过FPM(forwarding plane manger)将之同步给ASIC。zebra中运行FPM client，通过TCP socket与FPM server进行通信。FPM client端代码如下：
``` c
    //zebra_fpm.c
    serv.sin_family = AF_INET;
    serv.sin_port = htons(zfpm_g->fpm_port);                    //fpm默认使用2620端口
#ifdef HAVE_STRUCT_SOCKADDR_IN_SIN_LEN
    serv.sin_len = sizeof(struct sockaddr_in);                                     
#endif /* HAVE_STRUCT_SOCKADDR_IN_SIN_LEN */
    if (!zfpm_g->fpm_server)
        serv.sin_addr.s_addr = htonl(INADDR_LOOPBACK);          //FPM server一般部署在本机上
    else
        serv.sin_addr.s_addr = (zfpm_g->fpm_server);
```

FRR定义了FPM的数据格式，类似于协议报文，用户自己实现FPM server，解析出client发送过来的路由数据，然后进行相应的处理。

2. Bgpd处理收到的协议报文，以bgp-update报文为例，将计算得到的路由信息发送给zebra

3. zebra根据自身的计算策略过滤该路由，如果通过zebra则生成route-netlink信息将路由信息发送给kernel

4. 同时，zebra通过FPM接口将route-netlink信息发送给`fpmsyncd`，2,3,4的大致流程参见下图：
![](https://rancho333.gitee.io/pictures/frr-bgpd.png) 

5. Fpmsyncd处理该信息并将之放入`APPL_DB`
SONiC中FPM server在`fpmsyncd`中实现，源码在`sonic-swss`中：
``` c
    //fpmsyncd.cpp  连接redis APPL_DB
    DBConnector db("APPL_DB", 0); 
    RedisPipeline pipeline(&db);
    RouteSync sync(&pipeline);

    //fpmlink.cpp  创建socket，做为FPM server
    addr.sin_family = AF_INET;                          
    addr.sin_port = htons(port);                        //port为2620, 在fpm/fpm.h中定义
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);      //部署在本地
```

编译过程中会打包到`swss_1.0.0_amd64.deb`，在`dockers/docker-fpm-frr/Dockerfile.j2`会将其安装到`docker-fpm-frr`镜像中。在BGP进程中可以看到该进程。在`/etc/supervisor/conf.d/supervisord.conf`中可以看到各服务的启动控制：
```
[program:bgpd]
command=/usr/lib/frr/bgpd -M bmp -A 127.0.0.1
priority=6

[program:fpmsyncd]
command=fpmsyncd
priority=8
```

6. `orchagentd`作为APPL_DB的订阅者，它会收到fpmsyncd发布的信息

7. orchagentd作为一个中转站，会调用sairedis的APIs将信息发布到ASIC_DB

8. `syncd`作为ASIC_DB的订阅者，它会收到orchagend发布的信息

9. Syncd调用SAI APIs将路由信息下发到SDK

10. 最终新的路由规则在ASIC中生效

FRR与SONiC的完整交互流程图示如下：

![](https://rancho333.gitee.io/pictures/route-flow.png)

## 静态路由的实现
基于以上的SONiC路由实现流程，我们可以实现一个`FPM client`，按照ZAPI的格式封装netlink路由数据发送给`fpmsyncd`，之后在各个数据中转节点验证路由是否按设定的流程转发最终生效到ASIC。这样可以脱离`FRR`的协议栈逻辑，只借用FPM模块。

当然，我们可以直接通过FRR的配置文件或者`vtysh`来下发静态路由，有一个进程`staticd`用来处理静态路由。
路由下发的命令：
```
ip route 192.168.2.0/24 PortChannel0001
```
验证一下命令是否生效：

![](https://rancho333.gitee.io/pictures/show-ip-route.png)

看下在kernel中是否生效：

![](https://rancho333.gitee.io/pictures/ip-route-show.png)

查看是否同步到`APPL_DB`中：

![](https://rancho333.gitee.io/pictures/appl-db.png)

查看是否同步到`ASIC_DB`中：

![](https://rancho333.gitee.io/pictures/asic-db.png)

查看是否下发到`ASIC`中：

![](https://rancho333.gitee.io/pictures/asic-route.png)

可以看到路由信息按照`SONiC中路由模块的交互`中描述的进行处理下发。

## 对于单播(OSPF、RIP)以及组播(PIM)的支持

对于支持上述协议，需要回答几个问题：
1. 从哪里获取信息（端口状态变化、控制报文、数据报文是怎么送到协议栈的）
2. 协议状态机变化 (问题怎么定位以及功能的支持程度, 至于测试，需要专业协议测试人员介入)
3. 控制面信息如何生效到转发面 (协议栈控制信息同步到kernel与ASIC)

SONiC默认只启动了`bgpd`和`staticd`这两个路由进程，尝试手动开启`ospf`、`rip`、`pim`并为发现异常：

![](https://rancho333.gitee.io/pictures/frr-routes.png)

SONIC本身并未对FRR做什么修改，只是增加了一个FPM server模块，整个路由通路是没有问题的，理论上是*完全可以支持FRR中的其它路由协议*的，很好奇为什么微软不顺手把这些做了？
难道是因为数据中心中只要BGP+ECMP+VxLAN?

下面做一个工作量的评估（基于单个协议）
1. 协议学习2周

2. OSPF、PIM基于IP，使用protocol创建socket与keenel进行通信，RIP基于UDP，BGP基于TCP。ospf创建socket如下：

![](https://rancho333.gitee.io/pictures/ospf-sock.png)
控制报文调试1周，这玩意要是顺利应该就几分钟，大概率没啥问题。

3. 看代码，了解协议状态机，了解常见的测试拓扑，搭建测试拓扑，生成路由信息，2周

4. 打通路由下发，1周

5. 协议维护，解bug，不定

其实，从技术上说，很可能SONiC是已经支持上述路由协议了，只要开启相应进程，所以测试吧！说不定有惊喜！