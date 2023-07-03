---
layout: ccie
title: lab考题分析1.11和1.12
date: 2023-07-03 11:54:32
tags: CCIE
---

继续考题分析，1.11和1.12. 主要是DMVPN相关。简单概括下，1.11是修复DMVPN；1.12是通过隧道建立eigrp下发默认路由.
<!--more-->

# 1.11 Fixing broken DMVPN between DC and Branch3&4
下面是考题：
```
Correct the configuration issues resulting in Broken DMVPN tunnel connectivity between DC, branch3 and branch4 according to these requirements：

1. The DMVPN must operate ip IPsec-protected Phase 3 mode

2. Using the FVRF approach,safeguard the DMVPN operation against any potential recursive

3. Do not create any new vrfs

4. Do not change the tunnel source commands on tunnel interfaces

5. On spoken do not add new BGP neighbors；reuse those that currently up while changing their VRF members as needed

6. It is not allowed to modify configuration on DC r24 to complete this entire task.
```

1.11的拓扑如下所示：
![](https://rancho333.github.io/pictures/lab_1.11.png)

共涉及到4台设备，分别是r24,r61,r62,r70，其中r24作为hub已经预配好，不能做配置改动。r61,r62，r70作为spoken，与r24一同组成DMVPN网络。配置思路如下：
- 将r61,r62的对应接口加入vrf WAN中，并修改为正确的BGP邻居配置
- 配置tunnel0接口，配置加密信息

下面是具体配置：
1. 配置接口信息及BGP
```
r61:
int gi0/0
    vrf forwarding WAN              // 实现F-VRF配置
    ip address 100.5.61.2 255.255.255.252
int lo0
    vrf forwading WAN
    ip add 10.6.255.61 255.255.255.255      // 将lo0也加入vrf中，用于做tunnel的源地址

router bgp 65006
    bgp router-id 10.6.255.61
    no neighbor 100.5.61.1 remote-as 10000
    no network 10.6.255.61 mask 255.255.255.255   // 删除预配的无用信息
    address-family ipv4 vrf WAN中
        neighbor 100.5.61.1 remote-as 10000         // 在vrf地址族下配置邻居并通告路由，邻居会自动激活
        network 10.6.255.61 mask 255.255.255.255

r62:
    int gi0/0
        vrf forwarding WAN
        ip address 100.6.62.2 255.255.255.252
    int lo0
        vrf forwarding WAN
        ip address 10.6.255.62 mask 255.255.255.255
    
    router bgp 65006 
        bgp router-id 10.6.255.62
        no neighbor 100.6.62.1 remote-as 10000
        no network 10.6.255.62 mask 255.255.255.255
        address-family ipv4 vrf WAN
            neighbor 100.6.62.1 remote-as 10000
            network 10.6.255.62 mask 255.255.255.255
```

配置完成之后，r61与r5建立eBGP邻居，r62与r6建立eBGP邻居。
![](https://rancho333.github.io/pictures/lab_1.11_bgp_neighbor.png)


HQ中通过BGP学到r61和r62的lo0路由, 可以ping通。
![](https://rancho333.github.io/pictures/lab_1.11_ping_r61_r62.png)

2. 配置tunnel信息以及加密信息：
```
r61/62/70:
int t0
    ip nhrp nhs 10.200.0.1                  // spoken配置nhs服务端为10.200.0.1
    ip nhrp map multicast 10.2.255.24       // 配置nhs组播映射为10.2.255.24
    ip nhrp map 10.200.0.1 10.2.255.24      // 配置单播映射10.200.0.1为10.2.255.24
    ip nhrp network-id 1010                    // 配置netwoek-id为1010，与hub保持一致
    tunnel source lo0                           // 隧道源为lo0
    tunnel mode gre multipoint                  // 隧道模式为mgre
    tunnel protection ipsec profile profile     // 加载ipsec配置文件prof
    ip nhrp shortcut                            // 开启NHRP最短路径切换
    no ip nhrp redirect                     // spoken上关闭nhrp重定向
    ip mtu 1440                             // 保持与hub相同的接口参数属性
    tunnel vrf WAN                          // NHRP在进行单播和组播映射时，隧道的公网由10.2.255.24在VRF路由表WAN中查找
    no ip nhrp map multicast dynamic        // spoken站点不需要配置动态组播，hub才需要

加密相关配置从r70 copy即可，注意修改
hash sha 就行
```

配置完成之后，在r24上检查ipsec会话时候正常建立,如果没有正常建立，尝试将对应的t0接口关闭再开启。
![](https://rancho333.github.io/pictures/lab_1.11_crypto.png)

验证spoken站点的单播和组播映射：
![](https://rancho333.github.io/pictures/lab_1.11_nhrp.png)

至此，说明DMVPN就建立成功了。实际的配置过程中，可以以r70的配置为模板，增减一些配置，然后贴到r61和r62上去，此外r61上需要去除错误的nhrp单播映射配置。

如果没有正常建立, 排查思路如下：
- 路由是否正常，r24上需要有三个spoken的lo0路由，spoken上需要有hub的lo0路由（隧道的underlay是要三层可达的）
- t0接口配置是否正常
- 加密相关配置是否正常

对于DMVPN的phase3, 简单描述即：spoken之间的第一次会话是通过hub转发的，之后就是spoken之间直接建立tunnel进行会话，通过tracroute根据两次会话的路径可以看到现象。

# 1.12 Tuning EIGRP on DMVPN and DMVPN-enabled sites
下面是考题。
```
Optimize the DMVPN operation according to these requirements
1. Ensure that branch3&4 can receive only a default route over EIGRP in DMVPN

2. The default route originate must be done on r24 without the use of any static routes，redistribute，or route filtering

3. It is not allowed to modify the configuration of r61 and r62 in branch3 to accomplish this task

4. It is allowed to add commands on the configuration of r70 in branch4 to accomplish this task； none of existing configuration on r70 may be removed to accomplish this task

configure sw601 and sw602 at branch3 according to these requirements:
1. routers r61 and r62 must not send EIGRP queries to sw601 and sw602

2. switches sw601 and sw602 must allow advertising any current or future directly connected network to r61 and r62 after the network is added to EIGRP

3. switches sw601 and sw602 must continue to propagate the default route received from r61 and r62 to each other. To select the default route ，use a prefix list with a 'permit' type entry only

4. Switches sw601 and sw602 must not propagate the default route back to r61 and r62

5. If the prefix list that allows the propagation of selected EIGRP learned networks between sw601 and sw602 is modified in the future，the same set of networks must be disallowed from being advertised back to r61 and r62 automatically，without any additional configuration。
```
1.12的拓扑如下图所示
![](https://rancho333.github.io/pictures/lab_1.12.png)

总共涉及到4台设备，分别是r24,s601,s602,r70, r24没在拓扑中体现出来。在1.11构建好的DMVPN基础上，基于tunnel0接口建立EIGRP邻居，hub通过eigrp下发默认路由，s601和s602上做路由策略对默认路由做相应控制。配置思路如下：
- 建立EIGRP邻居，r24下发默认路由
- s601和s602上创建两个route-map，LEAKMAP用于相互泄漏默认路由，DIS用于给r61，62泄漏除默认路由之外的路由
- 完成1.8的部分需求，泄漏10.6和10.200网段路由到ospf中

下面是解法。
1. EIGRP邻居及默认路由
```
r24:
ruter eigrp ccie    
    address-family ipv4 unicast autonomous-system 65006
    af-interface t0
        no passive-interface            // r24和r70的t0被配置为passive-if, 无法建立eigrp邻居, r70上也需要做该操作
        
        summary-address 0.0.0.0 0.0.0.0     // 在隧道接口进行路由汇总，给spoken下发默认路由
    topology base
        summary-metric 0.0.0.0/0 distance 125
    // eigrp手动汇总后，本地生产一条AD为5的默认路由指向null0，用于防环
    // 修改这条默认路由的AD为125, 在1.16中ISP会下发默认路由，不然会有冲突
```

配置完成后，r24上可以看到3个eigrp邻居
![](https://rancho333.github.io/pictures/lab_1.12_eigrp_tunnel_neighbor.png)

在spoken上可以看到hub通过eigrp下发的默认路由：
![](https://rancho333.github.io/pictures/lab_1.12_dis_default.png)

2. 路由泄漏
```
sw601/602:
ip prefix-list DEFAULT permit 0.0.0.0/0     // 前缀列表匹配默认路由

route-map LEAKMAP permit 10
    match ip address prefix-list DEFAULT    // 创建route-map LEAKMAP只允许默认路由通过

route-map DIS deny 10 
    match ip address prefix-list DEFAULT
route-map DIS permit 20                 // 创建route-map过滤sw601/602传递给r61,62的路由。当前是传递除了默认路由之外的所有路由，将来即使修改了prefix-list, 匹配的路由依然不会传递给r61,62

ruter eigrp ccie    
    address-family ipv4 unicast autonomous-system 65006
    af-interface vlan2000
        passive-if
    af-interface vlan2001
        passive-if          // 末节设备连接主机的L3接口配置成被动接口，不建立邻居，和1.4中的ospf是一个意思
    
    eigrp stub          // 配置sw601和sw602为末节路由器
    eigrp stub connected leak-map LEAKMAP   // 使用route-map对末节路由器进行路由泄漏

    topology base
        distribute-list route-map DIS out gi0/1
        distribute-list route-map DIS out gi0/2        // 配置出方向分发列表，防止将来s601,602修改前缀列表将路由回馈给61，62
```

对于leakmap进行测试验证，正常情况下s601的默认路由从r61,62走ecmp：
![](https://rancho333.github.io/pictures/lab_1.12_601_route.png)

将s601的上行接口关闭，此时通过leakmap从s602泄漏过来的默认路由将被优选：
![](https://rancho333.github.io/pictures/lab_1.12_leakmap.png)

对于distribte-list进行测试验证，对于r61和62, 将上行接口均关闭，不会接收到从s601和s602回馈的默认路由即为成功.
![](https://rancho333.github.io/pictures/lab_1.12_no_default.png)

3. 1.8的路由
```
R24：
ip prefix-list DMVPN seq 5 permit 10.6.0.0/15 le 32
ip prefix-list DMVPN seq 10 permit 10.200.0.0/24            // 创建前缀列表匹配需求中的路由，10.6是br3中的，10.200是tunnel的

route-map DMVPN permit 10
    match ip addpress prefix-list DMVPN

router ospf 1
    redistribute eigrp 65006 subnets route-map DMVPN     // 从eigrp中导入指定范围的路由
    summary-address 10.6.0.0 255.254.0.0 tag 123
    summary-address 10.200.0.0 255.255.255.0 tag 123        // ASBR上进行路由汇总，避免路由过多。同时打上tag，避免路由这些路由通过r11到r3回到DC，过滤的动作在1.9中做了
```
在DC中的设备上可以看到汇总后的两个网段的路由：
![](https://rancho333.github.io/pictures/lab_1.12_ospf_summary.png)

注意，此时s601和s602的vlan2000,2001应该可以ping通dhcp server
![](https://rancho333.github.io/pictures/lab_1.12_vlan2000_dhcp.png)

如果不能ping通，后续的DHCP不会成功。如果通，分别在：
- r61上检查vlan2000的路由，没有则是route-map配置有问题
- sw211上检查vlan2000的路由，没有则是ospf重分发或者eigrp上的问题

干到这里，基本上为host61,62,71,72从DHCP server拿ip打下了基础。