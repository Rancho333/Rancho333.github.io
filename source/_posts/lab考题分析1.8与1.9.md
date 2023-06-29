---
layout: ccie
title: lab考题分析1.8与1.9
date: 2023-06-29 16:57:46
tags: CCIE
---

继续考题分析，1.8与1.9

# 1.8 OSPFv2 in DC
考题如下：
```
Configure device in the DC according to these requirements：
1. Switches sw201 and sw202 must establish a stable OSPF adjacency in the Full state with vedge21 and vedge22 on interface vlan3999. Any configuration changes and corrections necessary to meet this requirement may be performed only on the switches and any mismatced parameters causing the issue must be changed to exactly match the configuration of the vedges

2. All OSPF speakers in the DC running Cisco IOS and IOS-XE software must be configured to keep the number of advertised internal routes to an absolute minimum while not impacting the reachability of the services. This include the reachability of ISE, DNA center，vManage，vBond，vSmart on their internal addresses as well as any existing and future in vlan4000 on sw201 and sw202. The configuration of this requirement must be completed exclusively within the 'router ospf' and 'interface vlan' context without causing any impact to existing OSPF adjacencies。

3. Router r24 must advertise two prefixes，10.6.0.0/15 and 10.200.0.0/24 as Type-5 LSAs in ODPFv2 to provide HQ and DC with the reachability to the DMVPN tunnel and Branch3,4. The configuration of this requirement must be completed exclusively within the 'router ospf' context.

4. Any route from 10.2.0.0/16 range that keeps being advertised in OSPF must continue being advertised an intra-area route.

5. It is not allowed to modify existing areas to accomplish this entire task.
```
1.8的拓扑示意如下：

![](https://rancho333.github.io/pictures/lab_1.8.png)

总共涉及到8台设备，分别是sw201,sw202,sw211,sw212,r21,r22,r23,r24. 其中sw201，sw202与vedge21，vedge22建立ospf邻居关系，示意如下：

![](https://rancho333.github.io/pictures/lab_1.8_vedge.png)

拓扑简要说明下：
- sw201,sw202与vedge相连的接口均为trunk，native vlan为4000, 对于vedge而言这是vpn0 underlay
- vedge上创建子接口与sw的vlan 3999对接，作为vpn999的接口
- vedge21上两个物理口分别与两台sw相连，sw201在201网段(再子网划分给vlan3999和4000),sw202在202网段，这是为了冗余吧
- sw101的vlan3999,vlan4000与vedge21的0/1, 0/1.3999分别建立ospf邻居，与vedge22同理，所以sw201上vlan3999有两个ospf零件，vlan4000中也是两个； sw202同理

解法如下：
```
sw201/sw202：
interface vlan3999 
    ip mtu 1496        // 修复与vedge子接口的ospf邻居，vedge子接口MTU需要减去4字节的vlan tag

router ospf 1
    prefix-suppression      // 开启ospf前缀抑制，减少路由器之间相连网段的路由

interface range vlan 3999-4000
    ip ospf prefix-supression disable       // 与vedge相连的接口不抑制
    shutdown 
    no shutdown             // 重新建立连接，否则DC区域可能无法正常学习到br1和br2的路由，直接导致br1，br2无法连接到DNAc，显示unreachreable

sw211：
    router ospf 1
        prefix-supression
        passive-interface gi1/1
        passive-interface gi1/2
        passive-interface gi1/3

sw212：
    router ospf 1
        prefix-supression
        passive-interface gi1/1
        passive-interface gi1/2     // 与DNAc等相连的不抑制

r21,r22,r23,r24：
    router ospf 1
        prefix-supression
    
```

配置完成之后，sw201与sw202上与vedge建立ospf邻居：
![](https://rancho333.github.io/pictures/1.8_ospf_neig.png)

sw201上查看路由抑制效果：
![](https://rancho333.github.io/pictures/lab_1.8_route.png)

ospf路由表说明如下：
- 总共另外7台设备`/32`的loopback路由，loopback接口不抑制
- 总共有5个`/24`网段路由，对应vManage，vsmart，vbond，DNAc和ISE
- 2个`/29`网段路由，分别从sw202和vedge22学到，所以ECMP

注意需求第三点中要求的路由汇聚在1.12中体现，只有在修复DMVPN之后，DC中才会有`10.6.0.0/15`网段的路由。
