---
layout: ccie
title: lab考试基本介绍及考题分析
date: 2023-06-19 16:18:42
tags: CCIE
---

# lab基本介绍

在22年9月份考过CCNP(350-408)的笔试后就一直在约lab的考试，终于在今年(23)4月份约了一个北京考场的位置，5月初开始正式备考。EI CCIE lab考试总共分为两个部分，第一部分是design，全部是笔试，共计39题(第一题介绍，最后一题say goodby)，3小时内完成；第二部分是DOO(deploy，operate，optimize)，共计5小时。design做完可以提前交卷，3小时中剩下的时间则直接作废，不会加给DOO使用。DOO就是lab实操了，主要分为三块，一是传统网络，二是SDN网络，三是自动化。传统网络共计16个小题，SDN网络共计6个小题，自动化共计三个小题，每个部分中都有一个选择题。
<!--more-->

这个系列的blog主要用来对当前版本lab的网络做一个基本分析，注意在2023年9月之后lab会改版。

# lab 拓扑全景

整个lab的所有设备及连接如下图所示：

![](https://rancho333.github.io/pictures/lab1.1_topology.drawio.png)

这个图实际上还是很复杂的，总共由10个sites组成，分别是：
* HQ(head quarter)：主要跑ospf, eigrp v6，bgp等，虽然r12和ISP互联，但是默认从DC访问互联网
* DC(data center)：整个网络的中心，跑ospf, dmvpn，eigrp等，DHCP server, DMVPN hub, viptela，DNAc都部署在里面
* IaaS(Infrastructure as a service) 主要用来做自动化，以及ping通R30的ipv6 loopback
* ISP(Internet service provider) 提供8.8.8.8，并且会通过BGP下发默认路由
* SP1(service provider 1) 主要跑mpls,bgp，起到连接各个sites的作用
* SP2 同SP1，上面只跑BGP
* Branch1 分支1，跑SDN，viptela的overlay是DNAc的underlay，viptela在vedge之间构建好vpn通道，DNAc基于此对物理交换机进行纳管，注意SW400是border/edge两种角色一体
* Branch2 分支2，跑SDN，大部分同branch1, sw501和sw502是border角色，sw510是edge
* Branch3 分支3，跑DMVPN，作为spoken
* Branch4 分支4，跑DMVPN，作为spoken

最终的目的其实很简单，就是使用L2，L3，SDN等网络技术使所有主机都获取到ip地址，并能访问ISP中的8.8.8.8(google DNS服务器)，当然，HQ,DC,IaaS，branch1,branch2,branch3,branch4之间也是互联互通的，即这些sites中的主机都可以ping通的，guest vpn除外。

## 传统1.2
1.1是introduction，直接pass了。下面是1.2的题目。
```
layer 2 technologies in HQ

Complete and correct the etherchannel configuration between switches sw101,sw102,sw110 according to these requirements：
1. At the end of the task，all ethernetchannels between switches sw101, sw102 must be up and operational including all their physical member links
2. Do not create new port-channel interfaces; reuse that already exist on the switches
3. When resolving existing issues，do not change the preconfigured negotiation protocol（if any）
4. On ethernetchannel that use a negotiation protocol，tune its mode of operation for the shortest link bunding time possible

Configure VTP version 3 on these switches as follows:
1. VTP domain must be set to CCIE
2. VTP password must be cc1E@fab
3. When displayed, the VTP password must be shown as 32-character hexadecimal string
4. sw101 must be configured as VTP server for the MST feature
5. sw102 & sw110 must be configured as VTP client for the MST feature

These switches must run MST and maintain 3 instances including the default instance 0 as follows：
1. Associate vlans 1001-2000 in instance 1
2. Associate vlans 2001-4094 in instance 2
3. sw101 must be root for the default instance 0 and instance 1
4. sw102 must be root for instance 2
```

1.2的拓扑示意如下：

![](https://rancho333.github.io/pictures/lab_1.2.png)

结构很简单，涉及到三台设备：sw101,sw102,sw110，三台交换机之间通过portchannel连接，其中sw101和sw110之间走staic，其它两条走LACP。配置思路如下
- 修复portchannel配置，打通二层连接
- 配置VTP，其中sw101作为VTP server, 另外两台作为vtp client
- 配置mst，其中sw101作为instance 0-1的根，sw102作为instance 2的根

下面是实际配置：
1. 修复portchannel配置
```
sw101：
int range gi 1/2-3
    channel-group 1 mode on
sw102:
int range gi 1/2-3
    channel-group 2 mode active
sw110:
int range gi 1/2-3
    channel-group 2 mode active
int port-channel 1
    shutdown
    no shutdown             // po1是静态lag，对端修改配置后，本地down/up使其获取最新状态
```
配置完成之后，检查pc端口状态, pc全部都是`SU`状态，物理成员端口全部都是`P`状态，字母含义在show中有说明。

sw101 pc端口状态

![](https://rancho333.github.io/pictures/lab_1.2_pc_101.png)

sw102 pc端口状态

![](https://rancho333.github.io/pictures/lab_1.2_pc_102.png)

三角拓扑检查两台设备即可确认所有pc端口状态

2. 配置VTP
```
sw101:
vtp domain CCIE
vtp version 3
vtp password cc1E@fab hidden
vtp mode server MST
vtp primary mst force           // 特权模式下强制指定mst primary server, 需要输密码

sw102/sw110:
vtp domain CCIE
vtp version 3
vtp password cc1E@fab hidden
vtp mode client MST                 // 注意sw102和sw110的vtp工作在client模式 
```
配置完成之后检查vtp状态：

sw101的vtp状态如下：

![](https://rancho333.github.io/pictures/lab_1.2_vtp_101.png)

密码是hidden所以看不到明文：

![](https://rancho333.github.io/pictures/lab_1.2_vtp_password_101.png)

sw102的vtp状态如下：

![](https://rancho333.github.io/pictures/lab_1.2_vtp_102.png)

3. 配置mst
```
sw101： 
spanning-tree mode mst              指定spanning tree模式为mst
spanning-tree mst configuration
    name CCIE
    revision 1
    instance 1 vlan 1001-2000
    instance 2 vlan 2001-4094       // mst的具体配置只需要在sw101上配置，之后会通过vtp同步给sw102和sw110
spanning-tree mst 0-1 root primary      // 指定sw101是instance 0-1的根

sw102：
spanning-tree mode mst              
spanning-tree mst 2 root primary        // 指定sw102是instance 2的根

sw103:
spaaning-tree mode mst
```
配置完成之后检查mst状态，sw101作为instance 0-1根桥，sw102作为instance 2的根桥
sw101 spt状态

![](https://rancho333.github.io/pictures/lab_1.2_spt_101.png)

sw102 spt状态

![](https://rancho333.github.io/pictures/lab_1.2_spt_102.png)

tips: sw102和sw110的VTP配置相同，spt配置基本相同，只是sw102多一个instance 2的根桥配置。复制粘贴配置即可。

后面的blog会按顺序逐题进行分析。