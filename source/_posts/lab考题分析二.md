---
layout: ccie
title: lab考题分析1.3与1.4
date: 2023-06-20 15:44:57
tags: CCIE
---

继续考题分析，1.3和1.4。
<!--more-->

# 1.3 First hop redundancy protocol in HQ
下面是考题
```
For ipv4, implement an FHRP mechanism on sw101 and sw102 for vlans 2000 and vlan 2001 according to these requiremnet:
1. Use group number 100 for vlan 2000 and group number 101 for vlan 2001
2. Use the first available ipv4 address in the subnet for the address of the virtual router
3. For vlan2000, sw101 must be the preferred gateway，for vlan2001，sw102 must be the preferred gateway. Do not rely on the ipv4 addresses of the switches as role tiebreakers. The role must be determined and explicit configuration on the intended preferred gateway.
4. Each preferred gateway must monitor the reachability of both routers r11 and r12 using the loopback ipv4 addresses of the routers by icmp echo. The reachability is to be verified every 5 seconds with a timeout of 400 msec. A router must be declared unreachable as soon as it does not respond to three probes in a row. If both r11 and r12 are declared unreachable from a preferred gateway，the other switch must be allow to assume the gateway role, only a single tracking command may be added to the appropriate SVI configuration to accomplish this requirement
5. Use the FHRP protocol that allows the virtual ipv4 address to match the ipv4 addresses of a member router
```

1.3的拓扑示意如下：

![](https://rancho333.github.io/pictures/lab_1.3.png)

涉及到4台设备，但是只用配置sw101和sw102这两台设备，基本思路：
- 配置vrrp，使sw101成为vlan2000的active，使sw102成为vlan2001的active
- 配置ip sla和track，作用在active的SVI上

1. 配置vrrp
```
sw101
inter vlan2000
    vrrp 100 ip 10.1.100.1
    vrrp 100 priority 105
inter vlan2001
    vrrp 101 ip 10.1.101.1
sw102：
inter vlan2000
    vrrp 100 ip 10.1.100.1
inter vlan2001
    vrrp 101 ip 10.1.101.1
    vrrp 101 priority 105
```
配置完成后，验证sw101和sw102互为主备：

![](https://rancho333.github.io/pictures/lab_1.3_vrrp.png)

2. 配置ip sla和track
```
sw101/sw102
ip sla 11
    icmp-echo 10.1.255.11         // track r11的可达性
    frequency 5
    threshold 80
    timeout 400
ip sla 12
    icmp-echo 10.1.255.12       // track r12的可达性
    frequency 5
    threshold 80
    timeout 400
ip sla schedule 11 start-time now life forever
ip sla schedule 12 start-time now life forever
track 1 ip sla reachability
    delay down 10
track 2 ip sla reachability
    delay down 10
track 3 list boolean or
    object 1
    object 2

// 分别在两个active的gateway下添加track
sw101:
interface vlan2000             
    vrrp 100 track 3 decrement 15
sw102：
interface vlan2001
    vrrp 101 track 3 decrement 15
```
配置完成之后验证：

![](https://rancho333.github.io/pictures/lab_1.3_sla.png)

![](https://rancho333.github.io/pictures/lab_1.3_track.png)

验证vrrp与track的联动：
将r11和r12的lo0 shutdown，sw101和sw102上vrrp原本active的优先级将为90, 100的成为新的active
![](https://rancho333.github.io/pictures/lab_1.3_track_verify.png)


# 1.4 Ospfv2 between HQ and DC
下面是考题。
```
Complete and correct the ospf configuration on the switches sw101,sw102,sw201 and sw202 according to these requirements.

1. Enable ospfv2 on the redundant interconnections between the DC and HQ sites. Make sure that ospf establishes adjacencies on these interconnection and exchange routing information between the DC and HQ sites.

2. HQ must be configured in ospf area 1 and DC in ospf area 0

3. The primary traffic path must be the link between sw101&sw201 and the link between sw102&sw202 must become primary path during primary link failover。 For achieving this requirement you are not allowed to configure on sw201&sw202

4. All DC ospf speakers must see 10.1.0.0/16 for any HQ subnets

5. Protect the authenticity and integrity of the ospfv2 sessions on the redundant interconnections between DC and HQ with the SHA-384 mechanism. Use key ID 1 and a shared secret of "cci3"（without quotes）

6. Improve the detection of unreachable ospfv2 neighbors on the redundant interconnections between DC and HQ that ospf can detect the losses of a neighbor with 300 msec, eith the probes being sent every 100 msec. It is not allowed to modify ospf timers to accomplish this requirements.
```  
1.4的拓扑图如下所示：

![](https://rancho333.github.io/pictures/lab_1.4.png)

总共涉及到6台设备，其中r11和r12在are 1中，sw201和sw202在area 0中，sw101和sw102作为ABR。配置思路如下：
- sw101和sw102上将vlan2000和vlan2001，它们作为末节路由器的主机网关，配置为passive if, 只通告路由而不参与ospf邻居建立
- 根据所在区域，将6台路由器相应的接口加入到对应的ospf区域，并在sw202上取消错误的passive if配置
- 在sw101,sw102,sw201,sw202四台交换机上配置key chain, 作为接口安全认证; 创建bfd邻居，减少ospf收敛时间
- 路由规划，创建virtual link以及配置接口ospf cost

解法配置如下：

1. 配置passive if
```
sw101&sw102：
router ospf 1
    passive-interface vlan2000
    passive-interface vlan2001
```

2. 建立ospf邻居
```
sw101&sw102:
int range gi0/0-1,vlan2000-2001,lo0         // 默认都在area 0中，考场上check下与sw201,sw201接口的配置(确保在area 0中)
    ip ospf 1 area 1

r11&r12:
int range gi0/1-3，lo0
    ip ospf 1 area 1

sw202:
router ospf 1
    no passive-interface gi1/2          // 考场上注意下sw201的对应配置
```

3. 配置key chain 与 bfd
```
sw101&sw102&sw201&sw202：
key chain cisco
    key 1
        key string cci3
        cryptographic-algorithm hmac-sha-384     
interface gi 0/2  1/2:
    ip ospf authentication key-chain cisco
    ip ospf bfd                             // 使能接口bfd功能
    bfd internal 100 min_rx 100 multiplier  // 根据要求配置bfd参数
```
接口下的key chain配置必须一模一样，否则会导致ospf邻居down掉。配置完成后检查bfd邻居状态：

![](https://rancho333.github.io/pictures/lab_1.4_bfd.png)

4. 路由规划
```
sw101：
router ospf 1
    area 1 virtual-link 10.1.255.102        // 与sw102建立v-link
    area 1 range 10.1.0.0 255.255.0.0       // 路由汇聚

sw102:
router ospf 1
    area 1 virtual-link 10.1.255.102        // 与sw102建立v-link，这样可以从sw101接收到从area 0发送来的路由
    area 1 range 10.1.0.0 255.255.0.0  cost 200    // 增加宣告给sw202的汇聚路由的cost，使sw202从sw201访问HQ
    interface gi 0/2
        ip ospf cost 200       // 增大接口ospf的cost，使sw102访问DC的流量走sw101
```
配置完成之后，检查ospf邻居状态：

![](https://rancho333.github.io/pictures/lab_1.4_ospf.png)

sw101与sw102上面有四个邻居，r11与r12上有3个邻居。

检查路由规划效果，sw102通过sw101到DC，注意sw102可以ecmp r11和r12到达sw101, 所以有两个下一跳。

![](https://rancho333.github.io/pictures/lab_1.4_ospf_route.png)

对于sw202，通过sw101到达HQ。

![](https://rancho333.github.io/pictures/lab_1.4_ospf_route_2.png)