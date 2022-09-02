---
title: vrf简述及仿真实验
date: 2021-10-20 13:14:53
tags:
    - vrf
---

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [什么是VRF](#%E4%BB%80%E4%B9%88%E6%98%AFvrf)
  - [vrf的作用](#vrf%E7%9A%84%E4%BD%9C%E7%94%A8)
- [VRF仿真实验](#vrf%E4%BB%BF%E7%9C%9F%E5%AE%9E%E9%AA%8C)
  - [VRF解决地址重叠 && IP隔离](#vrf%E8%A7%A3%E5%86%B3%E5%9C%B0%E5%9D%80%E9%87%8D%E5%8F%A0--ip%E9%9A%94%E7%A6%BB)
  - [VRF路由隔离以及路由泄露](#vrf%E8%B7%AF%E7%94%B1%E9%9A%94%E7%A6%BB%E4%BB%A5%E5%8F%8A%E8%B7%AF%E7%94%B1%E6%B3%84%E9%9C%B2)
    - [vrf路由泄露实验失败](#vrf%E8%B7%AF%E7%94%B1%E6%B3%84%E9%9C%B2%E5%AE%9E%E9%AA%8C%E5%A4%B1%E8%B4%A5)
- [参考资料](#%E5%8F%82%E8%80%83%E8%B5%84%E6%96%99)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->
<!--more-->

# 什么是VRF

VRF(virtual routing and forwarding)是一种允许在单台路由器上有多个路由表的技术。VRFs的典型使用是与MPLS VPNs结合。没有使用MPLS的VRFs称为VRF lite.

在Linux上，VRF设备通过与ip规则结合在Linux网络栈中提供创建虚拟路由和转发的能力。一个典型的应用场景就是多租户各自需要独立的路由表，少数场景下需要不同的默认路由。

程序通过socket与不同的VRF设备绑定感知VRF。数据包通过socket使用与VRF设备相关的路由表。VRF设备实现的一个重要特征就是它只影响L3而对L2工具（比如LLDP）没有影响(它们是全局的而不必运行在每一个VRF域中).这种设计允许使用更高优先级的ip rules(policy based routing, PBR)优先于VRF设备规则，根据需要引导特定流量。此外，VRF设备允许VRFs嵌套在namespace中。namespace提供物理层的接口隔离，vlan提供L2的隔离，vrf提供L3的隔离。VRF设备是使用关联的路由表创建的。

简而言之，VRF在逻辑上将一个路由器模拟成多台路由器，是一种网络虚拟化技术,VRF是路由器的虚拟化，VLAN是交换机的虚拟化，trunk是对网络连接的虚拟化。VDOM(virtual domain)是防火墙的虚拟化, VM是服务器的虚拟化。

注意：一个L3接口同一时间只能属于一个VRF域

## vrf的作用
两点：
    1. 流量隔离：隔离不同的vpn用户,解决地址重叠问题
    2. 网络虚拟化

# VRF仿真实验
针对vrf的路由隔离和解决地址重叠这两个特性，在GNS3上面做两个简单的仿真实验。

## VRF解决地址重叠 && IP隔离
实验拓扑如下：
![](https://rancho333.github.io/pictures/vrf_overlap_topo.png) 
其中，R1、R2、R4、R5模拟主机，R3上面创建两个`vrf`域, R1、R2属于`vrf-2`, R4、R5属于`vrf-1`。实验预期是R1可以ping通R2，R4可以ping通R5。
5台设备的配置如下：
```
R1/R3:
interface Ethernet0/1
 no shutdown
 ip address 192.168.1.2 255.255.255.0
ip route 0.0.0.0 0.0.0.0 192.168.1.1                # 模拟主机，配置网关

R2/R4:
interface Ethernet0/3
 no shutdown
 ip address 202.100.10.2 255.255.255.0
ip route 0.0.0.0 0.0.0.0 202.100.10.1

R3:
ip vrf vrf-1                                        # 创建vrf-1
!   
ip vrf vrf-2                                        # 创建vrf-2
!
interface Ethernet0/0
 no shutdown
 ip vrf forwarding vrf-1                            # 接口加入vrf-1
 ip address 192.168.1.1 255.255.255.0
!
interface Ethernet0/1
 no shutdown
 ip vrf forwarding vrf-2                            # 接口加入vrf-2
 ip address 192.168.1.1 255.255.255.0
!
interface Ethernet0/2
 no shutdown
 ip vrf forwarding vrf-1                            # 接口加入vrf-1
 ip address 202.100.10.1 255.255.255.0
!
interface Ethernet0/3
 no shutdown
 ip vrf forwarding vrf-2                            # 接口加入vrf-2
 ip address 202.100.10.1 255.255.255.0
```
查看R3的路由表：
![](https://rancho333.github.io/pictures/vrf_overlap_route.png)
路由表结果与预期相符，默认路由表中没有内容，vrf-1和vrf-2中分别是各自接口的直连路由。

同时在R2和R5上抓包，在R1和R3上ping 202.100.10.2，发现只有在相同的vrf域中才能收到icmp(即R1可以ping通R2，R4可以ping通R5)，实验结果符合预期。

## VRF路由隔离以及路由泄露
VRF可以隔离不同VPN用户之间的路由，即可以实现L3层级的隔离，同时通过vrf-leak可以实现不同vrf之间的互通。路由隔离与泄露使用相同的拓扑：
![](https://rancho333.github.io/pictures/vrf_separation_topo.png)
配置参照`VRF解决地址重叠`的实验，根据拓扑修改对应端口，以及模拟主机的4台路由器上修改默认网关即可。

查看R3上的路由表，默认路由表依然为空，这里就不看了：
![](https://rancho333.github.io/pictures/vrf_separation_route.png)
VRF分别包含各自网段的路由。

在R2上分别ping R1和R4，结果如下：
![](https://rancho333.github.io/pictures/r2_ping_separation.png)
R2可以ping通同一路由域中的R1，不能ping通其它路由域中的R4，实验结果符合预期。

### vrf路由泄露实验失败, 后面有机会再搞吧(大概率是配置错了)
vrf的路由泄露有三种方向，分别为：
- 默认vrf——>vrf
- vrf——>vrf
- vrf——>默认vrf
默认vrf即为全局路由表。

vrf-leak可以通过static和dynamic两种方式实现，在此进行static实验。修改配置进行vrf-leak实验，在R3上添加如下配置：
```
```

## RD & RT
RD(route distinguish)路由区分标识，因为不同的vrf中可能有相同地址，造成地址overlapping, 在ipv4地址之前加上64位的RD，形成全局唯一的地址，这个地址形成一个新的地址族address family vpnv4，在MP-BGP中有体现。每个vrf有全局唯一的RD。RD的本质是避免ip地址冲突。

RT(route target)路由目标，每个vrf会有import rt和export rt属性，从vrf中export的路由会打上export rt的标记，通过MP-BGP的扩展团体属性承载，对端接收到后，将本地vrf的import rt与MP-BGP中的rt做对比，如果相同则引入。每个vrf可以定义多个import rt和export rt. RT本质是标记路由，用以跨设备vrf中传递指定路由。

# F-Vrf
F-Vrf是front door VRF的简称。

在使用GRE隧道的场景下，隧道的物理接口是underlay，被封装的流量（私网）是overlay，隧道tunnel虚接口在两者直接起桥梁作用，将私网流量路由到tunnel接口后即可进行gre封装。为了传递隧道两端私网的路由，需要将私网接口及tunnel接口加入动态路由计算(比如eigrp)，同时underlay之间也会运行IGP(比如ospf)保证IP连通性。如果tunnel地址与隧道物理接口地址网段冲突，如tunnel是10.9.8.0/24，物理接口是10.204.12.0/24，但是在路由协议中通告的是10.0.0.0/8, 那么设备会同时从eigrp和ospf学到该网段路由，且是不同出口，tunnel接口会down掉。

将隧道物理接口从global路由表中移除就不会有这个问题了，隧道物理接口就是front door，从front door进来就是我们的私网，所以将隧道物理接口加入的vrf叫做fvrf。简言之，*fvrf用于将连接到外部网络的路由表与全局路由表分开*。
在实际配置上，将物理接口加入指定vrf，物理接口所属的IGP也要在该vrf中，在tunnel接口上通过`tunnel vrf vrf-name`指定隧道物理接口所属的vrf。

# SONiC test case of VRF

基本问题描述：test case场景下，单个VRF中存在12.8K(6.4K的IPv4和6.4K的IPv6)路由条目，删除VRF时，一定时间内需要删除大量路由。里面有两个问题：
  1. zebra的fpm client不能将所有数据同步给fpm server
  2. 删除VRF中默认路由时出错

## 创建VRF时需要关注的几个对象
![](https://rancho333.github.io/pictures/vrf_about_objects.png)

注意：
  1. 一个VRF中包含一个或多个L3 接口，创建接口会增加该VRF的reference count
  2. 一个L3 接口上包含一个或多个IP，创建IP会增加该接口的reference count
  3. 一个IP对应一个邻居，增加neighbour会增加该IP的reference count
  4. 有了neighbour之后，路由协议会创建路由条目(route entry)，增加route entry会增加对VRF的reference count
  5. route entry中的一个重要参数是next hop(可能会有多个next hop)，增加next hop会增加对route entry的reference count

当一个对象的reference count不为0时，是不能将其删除的，必须彻底的解决其依赖关系。

## SONiC数据同步机制的缺陷，以删除VRF为例
![](https://rancho333.github.io/pictures/vrf_del_vrf.png)
vrfmgrd会陷入loop等待vrforch删除数据库中stateobjectvrf条目，如果vrforch执行失败，vrfmgrd会陷入死循环。

## zebra到fpmsyncd(bgp)同步路由的过程以及之前版本的缺陷(以删除ip为例)
![](https://rancho333.github.io/pictures/vrf_del_ip.png)

基本流程：
1. SONiC通过Linux shell删除L3的IP
2. zebra通过netlink同步信息并通知给个路由进程
3. 路由进程决策路由信息通知给zebra
4. zebra决策路由信息，通过netlink同步给kernel，通过fpm同步给sonic端的fpmsyncd
5. zebra端fpm client写机制有缺陷(write buffer较小，有写次数的限制)，导致数据丢失
6. 修改方式，在步骤1中删除IP后添加时延，减少zebra单位时间内处理的路由信息，给frr添加如下patch，解决fpm client写缺陷
```
 zebra/zebra_fpm.c |    4 ++--
 1 file changed, 2 insertions(+), 2 deletions(-)
 
diff --git a/zebra/zebra_fpm.c b/zebra/zebra_fpm.c
index 7b0611bf9..4efa8c896 100644
--- a/zebra/zebra_fpm.c
+++ b/zebra/zebra_fpm.c
@@ -62,7 +62,7 @@ DEFINE_MTYPE_STATIC(ZEBRA, FPM_MAC_INFO, "FPM_MAC_INFO");
  * The maximum number of times the FPM socket write callback can call
  * 'write' before it yields.
  */
-#define ZFPM_MAX_WRITES_PER_RUN 10
+#define ZFPM_MAX_WRITES_PER_RUN 100
 
 /*
  * Interval over which we collect statistics.
@@ -929,7 +929,7 @@ enum {
    FPM_GOTO_NEXT_Q = 1 
 };
 
-#define FPM_QUEUE_PROCESS_LIMIT 10000
+#define FPM_QUEUE_PROCESS_LIMIT 50000
```
注意SONiC中frr的编译机制，sonic-frr目录下的Makefile会checkout到指定分支，所以直接修改的代码内容会被覆盖。

## 关于删除VRF中默认路由出错

alpm模式下，broadcom TH4芯片在创建VRF时会创建一条默认路由(只存在于ASIC中，上层协议不可见)
当VRF只存在默认路由时，删除VRF会自动删除默认路由，如果此时显示删除默认路由，可以成功；
当VRF中存在默认路由以及其它路由时，不能显示删除默路由

原有，SONiC上层逻辑SWSS中，当删除default VRF中的默认路由时，将其设置为blackhole路由，当删除VRF中的默认路由时，下发删除指令，由于VRF中还有其它路由信息，SDK报错

修改为：当SONiC下发删除VRF中默认路由指令时，在SAI中将其实际行为修改为：将该默认路由配置成黑洞路由
      如果修改SONiC中的删除指令为配置成黑洞路由，那么在该VRF中，依然存在一个route entry，那么该VRF就存在reference count，那么该VRF就无法删除

# 参考资料
[rfc2685](https://datatracker.ietf.org/doc/html/rfc2685)

[rfc4364](https://datatracker.ietf.org/doc/html/rfc4364)

[SONiC VRF support design spec draft](https://github.com/Azure/SONiC/blob/master/doc/vrf/sonic-vrf-hld.md)

[VPN and VRF of cisco](https://www.cisco.com/c/en/us/td/docs/net_mgmt/prime/network/3-8/reference/guide/vrf.html)

[Config vrf of cisco](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst4500/12-2/15-02SG/configuration/guide/config/vrf.html#85589)

[Vrf of linux kernel](https://www.kernel.org/doc/html/latest/networking/vrf.html)

[Tunnels and the Use of Front Door VRFs](https://networkingwithfish.com/tunnels-and-the-use-of-front-door-vrfs/)