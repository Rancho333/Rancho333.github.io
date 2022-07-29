---
title: SONiC中OSPF使用简述
date: 2021-04-23 15:32:20
tags: 
    - SONiC
    - 通信协议
---

## 写在前面

承接上文[SONiC路由协议简述](https://rancho333.github.io/2021/04/08/SONiC%E8%B7%AF%E7%94%B1%E5%8D%8F%E8%AE%AE%E7%AE%80%E8%BF%B0/)，这边文章记录SONiC上使能OSPF的过程。
<!--more-->
## 实验过程

### 拓扑说明
拓扑图如下：

![](https://rancho333.github.io/pictures/ospf-topology.png)

实验预期：
1. 三台设备上能建立ospf邻居，完成LSDB交换，建立ospf路由
2. `192.168.1.2`能够`ping`通`192.168.2.2`

### 启动OSPF

在`bgp`容器中启动`ospf`进程：
```
/usr/lib/frr/ospfd -A 127.0.0.1 -d
```
参照`bgpd`的启动过程，将ospf添加到supervisor中，并指定配置文件，在`/etc/supervisor/conf.d/supervisord.conf`中添加：
```
[program:ospfd]
command=/usr/lib/frr/ospfd -A 127.0.0.1 -f /etc/frr/ospfd.conf
priority=5
stopsignal=KILL
autostart=false
autorestart=false
startsecs=0
stdout_logfile=syslog
stderr_logfile=syslog
```
在`/usr/bin/start.sh`中添加：
```
supervisorctl start ospfd
```
创建ospf配置文件`/etc/frr/ospfd.conf`, 根据具体业务添加配置内容：
```
frr version 7.2.1-sonic
frr defaults traditional
hostname lambda
router ospf
 network 192.168.1.0/24 area 0
```

### 配置接口IP
在SONiC命令行中可配置接口ip，命令如下：
```
config interface ip add 192.168.2.1/24
```
zebra会通过netlink获取接口配置，反之在vty中配置接口ip不能同步到sonic。也可将配置写到配置文件中：
```
"INTERFACE": {              
        "Ethernet1|192.168.1.1/24": {},
        "Ethernet2|192.168.2.1/24": {}                                                                                                                                                                                                                                                                               
    },      
```

配置完成之后，在vty中可以看到使能了ospf的接口：

![](https://rancho333.github.io/pictures/ospf-interface.png)

注意将接口的mtu配置成1500或者在ospf中关闭mtu check。

### 配置ASIC
SONiC中默认ospf报文不送CPU，这可能和各家的SDK初始化实现有关。在broadcom下我们需要做一些配置：
```
fp qset add ipprotocol
fp group create 20 21				    (20是优先级， 21是group-id)
fp entry create 21 3000				    （3000是entry-id，这是一个全局的值，注意不能重叠）
fp qual  3000 ipprotocol 89 0xffff		(指定copy-to-cpu的协议特征)
fp action add 3000 CopyToCpu 0 0		（对匹配到特征的协议指定动作）
fp entry install 3000					（使能配置）
fp show entry 3000                        （验证配置）
```
应当在ASIC中看到使能的配置：

![](https://rancho333.github.io/pictures/ospf-asic.png)

sonic中提供了copp功能配置sdk下发这些报文上CPU等的控制操作，受当前实验版本限制暂不做这方面深入研究。

### 功能验证
查看邻居状态：

![](https://rancho333.github.io/pictures/ospf-neighbour.png)

查看数据库信息：

![](https://rancho333.github.io/pictures/ospf-database.png)

查看路由表：

![](https://rancho333.github.io/pictures/ospf-route.png)

ping测试：

![](https://rancho333.github.io/pictures/ospf-ping.png)

## 小结

当前SONiC上ospf功能使能需要做三方面的配置：
1. ospf自身，包括功能启用以及协议参数配置
2. 启用ospf协议的接口
3. 配置ASIC，协议报文上CPU