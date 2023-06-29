---
layout: ccie
title: lab考题分析1.6与1.7
date: 2023-06-28 15:51:16
tags: CCIE
---

继续考题分析，1.6与1.7。 这两题是ipv6相关，很简单。
<!--more-->

# 1.6 IPv6 in HQ
下面是考题。
```
Implement IPv6 on sw101 and sw102 for switch virtual interface(SVIs) vlan2000 and vlan2001 according to these requirements：

sw101:
    interface vlan2000: 2001:db8:1:100::1/64
    interface vlan2001: 2001:db8:1:101::1/64

sw102:
    interface vlan2000: 2001:db8:1:100::2/64
    interface vlan2001: 2001:db8:1:101::2/64

The configuration must enable hosts in these Vlans to obtain their IPv6 configuration via SLAAC and keep a stable connectivity with their IPv6 networks.

Use native IPv6 means to provide gateway redundancy, with sw101 being the preferred gateway in vlan2000 and sw102 being the preferred gateway in vlan2001. The role must be determined by explicit configuration on their intended preferred gateway.

Hosts must be able to detect the preferred gateway in as little as 3 seconds.
```

1.6的拓扑示意图如下：

![](https://rancho333.github.io/pictures/lab_1.6.png)

和1.3一样，只涉及到sw101和sw102这两台交换机，配置很简单，就是在SVI上配置ipv6地址，再做RA一些属性配置即可. 配置如下：
```
ipv6 unicast-routing        // 确保开启ipv6单播功能，这样RA通告才可以发送，客户端才可以通过SLAAC无状态获取ipv6地址

sw101:
    inter vlan2000 
        ipv6 addr 2001:db8:1:100::1/64
        ipv6 nd ra internal msec 2000
        ipv6 nd ra lifetime 3
        ipv6 nd router-preference High
    inter vlan2001 
        ipv6 addr 2001:db8:1:101::1/64
        ipv6 nd ra internal msec 2000
        ipv6 nd ra lifetime 3
sw102:
    inter vlan2000 
        ipv6 addr 2001:db8:1:100::2/64
        ipv6 nd ra internal msec 2000
        ipv6 nd ra lifetime 3
    inter vlan2001 
        ipv6 addr 2001:db8:1:101::2/64
        ipv6 nd ra internal msec 2000
        ipv6 nd ra lifetime 3
        ipv6 nd router-preference High
// 先配置RA通告间隔，在配置RA产生默认路由的生命周期，否则会报错
// RA的lifetime时间不应该小于RA通告时间
```

保证对应vlan配置`High`即可，试验台上主机上貌似看不到现象；或者在sw110上创建svi来模拟。
在主机上通过`ifconfig`查看ipv6地址，`ip -6 route`查看路由，检查网关优先级。

![](https://rancho333.github.io/pictures/lab_1.6_ipv6.png)


# 1.7 Ipv6 Eigrp in HQ

下面是题目。
```
In HQ enable EIGRP for ipv6 on r11,r12,sw101 and sw102 according to these requirements:

1. Use process name "ccie" (without the quotes) and AS number 65001

2. Do not configure any additional IPv6 addresses

3. IPv6 EIGRP may form adjacencies only over the physical Layer3 interface between r11,r12,sw101 and sw102

4. Prevent IPv6 EIGRP from automatically running on, or advertising attached prefixes from new ipv6-enabled interfaces in the future unless allowed explicitly

5. Ensure that the attached ipv6 prefixes on SVI‘s vlan2000 and vlan2001 on sw101 and sw102 are advertised in ip6 EIGRP and learned on r11 and r12

6. No route filtering is allowed to accomplish this entire task
```

1.7的拓扑示意示意如下：

![](https://rancho333.github.io/pictures/lab_1.7.png)

总共涉及到四台设备，分别是sw101,sw102,r11和r12。 基本思路如下：
- 将eigrp接口默认行为改为passive和shutdown
- 只在物理三层接口上开启eigrp邻居
- sw101和sw102的svi，r11和r12的loopback只通告路由，不建立eigrp邻居

配置如下：
```
ipv6 unicast-routing            // 先全局开启ipv6单播功能，否则无法启动eigrp的ipv6

sw101/sw102:
    router eigrp ccie
    address-family ipv6 unicat autonomous-system 65001        // 创建eigrp实例ccie，as为65001
    af-interface default
        shutdown
        passive-interface        // 所有ipv6接口不宣告进eigrp，并且默认全为被动接口
    af-interface gi0/0
        no shutdown
        no passive-interface
    af-interface e0/1
        no shutdown
        no passive-interface        // 与r11和r12互联的三层接口打开ipv6 eigrp
    af-interface vlan2000
        no shutdown
    af-interface vlan2001
        no shutdown            // 末节svi没有必要建立eigrp邻居，但所在网段需要通过eigrp传递路由

r11/r12:
router eigrp ccie
        address-family ipv6 unicast autonomous-system 65001
        af-interface default
            shutdown
            passive-interface            // 默认所有接口不宣告进eigrp，并且默认全为被动接口
        af-interface e0/1
            no shutdown
            no passive-interface
        af-interface e0/2
            no shutdown
            no passive-interface
        af-interface e0/3
            no shutdown
            no passive-interface            // R11&R12正常宣告三层物理接口进eigrp
        af-interface loopback0
            no shutdown                // 环回口只需要no shutdown, 不用no passive
            exit-af-interface
```

配置完成之后，sw101和sw102应该各有两个ipv6 eigrp邻居,分别是r11和r12
![](https://rancho333.github.io/pictures/lab_1.7_eigrp_neighbor_1.png)

r11和r12各有三个eigrp邻居，分别是sw101,sw102与r11/12
![](https://rancho333.github.io/pictures/lab_1.7_eigrp_neighbor_2.png)

r11，r12上对于sw101和sw102的SVI ipv6网段路由应用是ECMP：
![](https://rancho333.github.io/pictures/lab_1.7_eigrp_ecmp.png)

在主机上对r11或r12的lo0 ipv6地址进行traceroute测试，host11应该优先走sw101, 挂了后则走sw102。host12同理。这里就只做一个ping测试了。
![](https://rancho333.github.io/pictures/lab_1.7_eigrp_ping.png)