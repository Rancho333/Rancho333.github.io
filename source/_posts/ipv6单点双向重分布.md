---
title: ipv6单点双向重分布
date: 2022-07-22 10:41:42
tags:
---

# 写在前面
简单介绍下ipv6单点双向重分布的配置细节，cisco IOS中某些细节与ipv4实现有一些差异。
<!--more-->

# 实验配置
实验拓扑如下：
![](https://rancho333.github.io/pictures/ipv6_redistribute_topology.png)

如图所示，R1-R2之间跑ospfv3，R2-R3之间跑eigrp。在R2上做单点双向重分布，是R1-R3上的lp0接口能相互ping通。

{% tabs tab,1 %}
<!-- tab R1-->
```
ipv6 unicast-routing                    // 全局开启ipv6路由功能
！
interface Loopback0
 no ip address
 ipv6 address 1111::1111/128                // 配置lp0 ipv6地址
 ospfv3 110 ipv6 area 0                     // 将接口加入ospfv3计算
！
interface Ethernet0/0
 no ip address
 duplex auto
 ipv6 address 2001::1/64
 ospfv3 110 ipv6 area 0
！
router ospfv3 110                   // 创建ospfv3进程
 !
 address-family ipv6 unicast        // 指名使用ipv6地址族
  router-id 1.1.1.1                 // 设置router id， 相较于ospfv2而言，没有这两项配置
 exit-address-family
```
<!-- endtab -->
<!-- tab R2-->
```
ipv6 unicast-routing
!
interface Ethernet0/0
 no ip address
 duplex auto
 ipv6 address 2001::2/64
 ospfv3 110 ipv6 area 0
!
interface Ethernet0/1
 no ip address
 duplex auto
 ipv6 address 2002::2/64
!
router eigrp rancho                         // 命名模式eigrp，支持ipv4&ipv6两种地址族
 !
 address-family ipv6 unicast autonomous-system 1        // 指定ipv6地址族，默认会将所有ipv6接口加入eigrp计算
  !
  topology base                                         // eigrp ipv6重定向需要到拓扑库中进行                     
   redistribute ospf 110 metric 10000 10 255 1 1500 include-connected       // 将ospf 110中的路由重定向到eigrp中，默认不包含直接路由，需要添加include-connected子命令
  exit-af-topology
  eigrp router-id 2.2.2.2                               // 指定router id
 exit-address-family
!
router ospfv3 110
 !
 address-family ipv6 unicast                // 指定ipv6地址族
  redistribute eigrp 1 include-connected       // 同样默认不包含直接路由，需要添加子命令
  router-id 2.2.2.2
 exit-address-family
```
<!-- endtab -->
<!-- tab R1-->
```
ipv6 unicast-routing
!
interface Loopback0
 no ip address
 ipv6 address 3333::3333/128
!
interface Loopback1
 no ip address
 ipv6 address 4444::4444/128
 !
 interface Ethernet0/0
 no ip address
 duplex auto
 ipv6 address 2002::3/64
!
router eigrp rancho
 !
 address-family ipv6 unicast autonomous-system 1
  !
  af-interface default                      // eigrp默认将所有ipv6接口加入eigrp计算
   shutdown                                 // 将所有接口移除eigrp
  exit-af-interface
  !
  af-interface Loopback0
   no shutdown                              // 指定的端口加入eigrp
  exit-af-interface
  !
  af-interface Ethernet0/0
   no shutdown                               // 指定的端口加入eigrp, 这样lp1就没有加入eigrp，R1上就没有对应的路由
  exit-af-interface
  !
  topology base
  exit-af-topology
  eigrp router-id 3.3.3.3
 exit-address-family
```
<!-- endtab -->
{% endtabs %}

查看R1上的ipv6路由表：
```
R1#show ipv6 route | begin 3333  
OE2 3333::3333/128 [110/20]
     via FE80::A8BB:CCFF:FE00:2000, Ethernet0/0
```
在R1上ping R3的lp0:
```
R1#ping 3333::3333 source 1111::1111
Type escape sequence to abort.
Sending 5, 100-byte ICMP Echos to 3333::3333, timeout is 2 seconds:
Packet sent with a source address of 1111::1111
!!!!!
Success rate is 100 percent (5/5), round-trip min/avg/max = 1/1/1 ms
```

有两点比较关键：
- ipv6动态路由协议重分布时，cisco体系中没有把直连路由包括进去，需要用子命令指名
- eigrp默认将所有ipv6接口加入eigrp计算，如果只想把指定端口加进去，需要做额外的操作