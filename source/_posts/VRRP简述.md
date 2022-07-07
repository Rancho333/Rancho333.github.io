---
title: VRRP简述
date: 2022-07-07 17:07:29
tags: VRRP
---

# 写在前面
VRRP(virtual router redundancy protocol)和`HSRP`非常相似，原理相同，只不过VRRP是公有的(RFC 3768)，HSRP是思科私有的。`《HSRP简述》`中对虚拟路由冗余协议做了基本的阐述和实验说明，这篇文章主要描述两者之间的差异，然后做个实验来验证下。
<!--more-->

# VRRP与HSRP的差异

| | HSRP | VRRP |
| :--- | :--- | :--- |
| protocol | cisco proprietary | IETF-RFC3768 |
| number of groups | 0-255,0是默认 | 1-255 |
| active/standby | 一个active, 一个standby，多个候选者 | 术语叫法不同，一个master，多个backups |
| Vip | 不能和三层接口ip相同 | 可以相同，如果相同，优先级直接变成最高 |
| Vmac | v1，v2有差异，见hsrp简述 | 00:00:5e:00:01:xx, xx是group id |
| multicast address | 224.0.0.2 | 224.0.0.18 |
| tracking | interfaces or objects, 触发后降低优先级或退出组 | objeects，触发后降低优先级，没有退出组 |
| timers | hello timer 3秒，hold time 10秒| hello 1秒，holdtime 3秒 |
| authentication | 支持 | rfc中不支持，厂家支持 |
| preempt | 默认不开启，可配置 | 默认开启抢占 |
| 报文封装 | UDP 1985 | 基于IP |
| version | 默认v1 | v2,v3两个版本，默认v2，v3才支持ipv6 |
| load balancing | 支持不同组之间 | 支持不同组之间 | 
| priority | 不支持辞职，优先级为0可以手动配置，没有特殊含义 | 优先级为0表示放弃master位置，优先级0不能手动配置 |

关于辞职，当master路由器接口shutdown时，会立即发送优先级为0的通告，vrrp中优先级为0表示不参与虚拟组计算，收到的backups之间会立即重新选举出新的master，否则就要等待3秒的报文超时再选举，这样可以加快收敛时间。优先级为0的报文如下：

![](![](https://github.com/Rancho333/pictures_hub/blob/master/non_auto/vrrp_packet_priority_0.png?raw=true)

在HSRP中，tracking中触发支持shutdown，如果active路由器接口shutdown，那么standby只能等待10秒超时后变成active. VRRP tracking中不支持shutdown，嗯，也就是说只有路由接口手动shutdown或物理线路挂掉才会触发优先级为0的报文，而上行链路挂掉tracking无法触发？

# 实验说明
实验拓扑图如下：

![](https://github.com/Rancho333/pictures_hub/blob/master/non_auto/vrrp_basic_topology.png?raw=true)

S2、S3、S4的interface vlan1加入虚拟组组成虚拟路由器，虚拟组对外提供网关服务。基本配置如下：
```
S2
    interface Vlan1
        ip address 192.168.1.1 255.255.255.0        // svi配置IP地址
        vrrp 1 ip 192.168.1.254                     // svi加入虚拟组1，虚拟ip为192.168.1.254
S3
    interface Vlan1
        ip address 192.168.1.2 255.255.255.0
        vrrp 1 ip 192.168.1.254
S4
    interface Vlan1
        ip address 192.168.1.3 255.255.255.0
        vrrp 1 ip 192.168.1.254
```

`show vrrp brief`查看vrrp状态
```
S4#show vrrp brief 
Interface          Grp Pri Time  Own Pre State   Master addr     Group addr
Vl1                1   100 3609       Y  Master  192.168.1.3     192.168.1.254
```
vrrp的默认优先级也是100，超期时间单位是毫秒，有计算公式，是hello的三倍多点，`own`表示是否是虚拟组的拥有者，当物理接口ip和虚拟组ip一致时成为owner, 通过将优先级置位最大值255实，如将S3设置成owner
```
S3(config-if)#ip address 192.168.1.254 255.255.255.0
S3#show vrrp brief 
Interface          Grp Pri Time  Own Pre State   Master addr     Group addr
Vl1                1   255 3003   Y   Y  Master  192.168.1.254   192.168.1.254
```
优先级为255的报文为：

![](https://github.com/Rancho333/pictures_hub/blob/master/non_auto/vrrp_packet_priority_255.png?raw=true)

owner不能被配置优先级。 vrrp默认开启preempt，所以`pre`是`Y`。注意vrrp组中除master外，其余都是backup，即master挂掉后，会从backup中重新选举出新的master。而hsrp中master挂掉后，standby接替，之后在candidate中选举出新的standby。

**所以VRRP中只有master发送announcement，backup监听。hsrp中active和backup都需要发送hello报文。**

当然，FHRP中一般搞两台路由器做网关冗余就行了。

## 其它实验
tracking上行链路故障，不同组之间的负载均衡，和HSRP没区别，这里就不重复了。

## 双活网关
HSRP/VRRP只能实现单活网关，只有active进行arp应答和转发业务流量，standby则完全闲置。结合MLAG则可实现双活网关:
1. active负责arp应答，standby会将arp中继给active
2. 控制面视角而言，依然是active/standby，数据面而言active/active转发
3. 接入交换机上mac地址表中vmac对应的端口是mlag聚合端口，所以active/standby都有可能收到报文，收到后按路由表正常转发即可。如果不是mlag场景，standby收到目的地址是vmac的报文。
4. eveng中不支持vpc模拟，vpc的peer-link需要10G端口才能运行，不然会后各种问题。

## 为甚vip不会冲突
在两台设备上部署了相同的vip+vmac，为什么不会冲突？
IP通信通过arp报文获取mac，主机请求网关vip时，只有active才会做出回应，所以除了active外，网络中并不会有其它设备感知到standby。
从另外一个角度来说？一般设备配置ip地址后会向外发送免费arp报文，一是避免ip冲突，而是主动告知其它设备自己arp信息。交换机变成active后也会主动发送免费arp，standby收到后也不会处理，所以就不冲突了。
从实际通信报文的角度来看，standby是收不到vmac的报文的，如果能收到，也能正常转发，这就是mlag+vrrp实现双活网关的原理。
