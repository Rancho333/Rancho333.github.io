---
layout: ccie
title: lab考题分析1.8与1.9
date: 2023-06-29 16:57:46
tags: CCIE
---

继续考题分析，1.8与1.9
<!--more-->

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

# 1.9 BGP between HQ-DQ and service provides

考题如下：
```
Configure the BGP peering between HQ/DC and global SP#1 and Global SP#2 according to these requirements：

1. Bring up the BGP peering between HQ r11 and SP1 r23

2. Bring up the BGP peering between DC r21 and SP1 r23

3. Bring up the BGP pering DC r22 and SP2

4. Ensure that the routes learned over eBGP sessions and further advertised in iBGP will be considered reachable even if the networks on inter-AS links are not advertised in OSPF. The configuration of this requirement must be completed exclusively with the "router bgp" context

5. On r11，r21，r22 perform mutual redistribution between OSPFv2 and BGP. Howevr, prevent routes that were injected into OSPF from BGP to be reinjected back into BGP. This requirement must be solved on r11,r21,r22 using only a single route0map on each of the routes andwithout any reference to ACLs,prefix lists or route-types

6. Prevent HQ and DC from ever communicating through SP1 r3. All communication between HQ and DC must occur only over the direct sw101/sw201 and sw102/sw202 interconnections. Any other communication must remain unaffected. This requirement must be solved on r11,r21 and r22 by route filtering based on a well-known mandatory attribute without the use of routemaps.

7. No command may be removed from configuration on r11 to accomplish this entire task

8. It is allowed to modify existing configuration commands inside router bgp 65002 on r21 and r22 to accomplish this entire task.

```

1.9的拓扑示意图如下：

![](https://rancho333.github.io/pictures/lab_1.9.png)

总共涉及到5台设备，其中sp1的r3和sp2都是预配好的，不需要动，只需要在r11,r21和r22三台设备进行配置。配置思路如下：

先完成BGP邻居的建立
- 配置r11，使其与r3建立eBGP
- 配置r21，使其与r3建立eBGP，使其与r22建立iBGP，并且下一跳为自身
- 配置r22，使其与r21建立iBGP，并且下一跳为自身

然后做双点双向重分布以及as-path
- r11上将bgp路由重分布进ospf，打上tag，创建route-map拒绝该tag
- 在r11上创建as-path拒绝65002的路由，并在bgp邻居中应用
- 在r11上将ospf的路由重分布进bgp，并应用route-map
- 在r21和r22上重复上诉操作

简要说明下拓扑，R11和R21处于两个路由域的边界，上方是ospf，下方是BGP，这就是一个典型的双点双向重分布环境。
- r3的bgp路由发布给R11, 然后被引入ospf域，r21通过ospf学到，重分布进bgp，又发布给r3，这样会形成路由环路
- r21将ospf域内的路由重发布进bgp，r11上通过bgp学到该路由，bgp AD比ospf小，所以r11会通过bgp到达r21，而不是之前的ospf，这样形成次优路径

关于双点双向充分布的分析可以参考这篇 [blog](https://rancho333.github.io/2022/07/12/%E5%8F%8C%E7%82%B9%E5%8F%8C%E5%90%91%E9%87%8D%E5%88%86%E5%B8%83/)。

下面是解法：
```
建立eBGP，iBGP邻居
r11:
    router bgp 65001
        bgp router-id 10.1.255.11           // 手动配置bgp router-id
        no bgp default ipv4-unicast         // 默认配置不激活ipv4单播邻居
        neighbor 100.3.11.1 remote-as 10000 
    address-family ipv4
        neighbor 100.3.11.1 active          // 在ipv4地址族下手动激活邻居

r21:
    router bgp 65002
        bgp router-id 10.2.255.21
        no bgp default ipv4-unicast
        neighbor 100.3.21.1 remote-as 10000
    address-family ipv4
        neighbor 100.3.21.1 active
        neighbor 10.2.255.22 active         // 预配已经指定as，激活即可
        neighbor 10.2.255.22 next-hop-self   // iBGP指定下一跳是自我

r22：
    router bgp 65002
        bgp router-id 10.2.255.22
        no bgp default ipv4-unicast
        neighbor 101.22.0.1 remote-as 10001
    address-family ipv4 
        neighbor 101.22.0.1 active
        neighbor 10.2.255.21 active         // 同r21
        neighbor 10.2.255.21 next-hop-self  
```
配置完成之后，正常建立bgp邻居关系：
![](https://rancho333.github.io/pictures/lab_1.9_bgp_neighbor.png)

```
按要求配置路由策略：

r11：
router ospf 1
    redistribute bgp 65001 subnets tag 123          // 在ospf中引入bgp的路由，打上tag

route-map O2B deny 10
    match tag 123
route-map O2B permit 20                // 基于tag做路由策略，拒绝有tag 123的路由

ip as-path access-list 100 deny _65002$     // 配置基于as-patch的ACL，拒绝通过bgp接收65002的路由
ip as-path access-list  100 permit .*       // 允许除65002之外的路由

router bgp 65001
    address family ipv4
        redistribute ospf 1 match internal external 1 external 2 route-map O2B // 在bgp中引入ospf路由，包含ospf外部路由，调用路由策略拒绝tag路由
        neighbor 100.3.11.1 filter-list 100 in          // 针对eBGP调用ACL

r22和r23上使用相同配置，注意下as number和 eBGP邻居地址即可

clear ip bgp * soft include     // 重置BGP路由表，使配置的策略生效
```

查看r11上的路由表, `10.2`即DC区域的路由都是通过ospf学到的，并且是`O IA`类型，DC是area 0，HQ是area 1。`10.6`，`10.7`网段的路由则是通过BGP学到的，注意这需要配置完后面的DMVPN才能看到。
![](https://rancho333.github.io/pictures/lab_1.9_r11_route.png)

对于r21和r22, `10.1`网段的路由也是通过ospf学到的。
![](https://rancho333.github.io/pictures/lab_1.9_r21_r22_route.png)

HQ和DC中的路由通过bgp通告给r3. SP1在这里起到一个连接的作用，后续HQ和br3,4之间的互通都要通过这里，一定要保证双方的路由都传递过去了。
![](https://rancho333.github.io/pictures/lab_1.9_r3_route.png)