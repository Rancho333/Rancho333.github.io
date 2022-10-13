---
title: vrf lite route leaking
date: 2022-10-13 16:07:22
tags:
    - vrf
---

# 写在前面
之前在[vrf简述及仿真实验](https://rancho333.github.io/2021/10/20/vrf%E7%AE%80%E8%BF%B0%E5%8F%8A%E4%BB%BF%E7%9C%9F%E5%AE%9E%E9%AA%8C/)对vrf有了一个基本的了解，但是vrf lite route leaking实验失败了。现在补做回来。

vrf之间的路由泄漏有静态配置和MP-BGP两种方式，本文只做静态配置的实验。
<!--more-->

# 实验
之前的实验时是由于配置出的问题，参考cisco的[Route Leaking in MPLS/VPN Networks](https://www.cisco.com/c/en/us/support/docs/multiprotocol-label-switching-mpls/multiprotocol-label-switching-vpns-mpls-vpns/47807-routeleaking.html#diffvrfs), 两个vrf之间不能直接泄露路由，必须从global中转一下才行。

实验拓扑如下图所示：
![](https://rancho333.github.io/pictures/vrf_leaking_topology.png)

vpc2属于vrf 2, vpc3属于vrf 3, vpc4属于global. 通过配置使三者之间可以相互通信。
对于vrf -> global，在vrf中写到达global中prefix路由，在global中写到达vrf中prefix的路由。
对于vrf -> vrf，在vrf中写到达另一个vrf中prefix的路由(下一跳在global中)，在global中写到达该prefix的路由，对于另一个vrf，做相同的操作。

下面开始配置。基本的ip网段配置规则按设备名称来，这里不贴出来。
```
R1(config)#ip vrf 2             // 创建vrf2
R1(config)#ip vrf 3             // 创建vrf3

R1(config-if)#interface ethernet 0/0
R1(config-if)#ip vrf forwarding 2                   // 将eth0加入vrf 2
R1(config-if)#ip address 12.1.1.1 255.255.255.0

R1(config-if)#interface ethernet 0/1
R1(config-if)#ip vrf forwarding 3                   // 将eth1加入vrf 3
R1(config-if)#ip address 13.1.1.1 255.255.255.0
```

测试下基本的联通性：
```
vpc4> ping 14.1.1.1 -c 1                // 可以ping通自己的网关

84 bytes from 14.1.1.1 icmp_seq=1 ttl=255 time=0.335 ms

vpc4> ping 12.1.1.2 -c 1                // 不能和vrf 2通信

*14.1.1.1 icmp_seq=1 ttl=255 time=0.497 ms (ICMP type:3, code:1, Destination host unreachable)

vpc4> ping 13.1.1.3 -c 1                // 不能和vrf 3通信

*14.1.1.1 icmp_seq=1 ttl=255 time=0.492 ms (ICMP type:3, code:1, Destination host unreachable)
```
符合预期。

对于vrf 2与global之间的通信：
```
R1(config)#ip route vrf 2 14.1.1.0 255.255.255.0 14.1.1.4 global            // 在vrf 2中添加global中prefix的路由，global关键词表明：如果在vrf 2中收到prefix是14.1.1.0/24的报文时，到global路由表中找路由出去，由于14.1.1.0/24是global中的直连网段，所以报文可以转发
R1(config)#ip route 12.1.1.0 255.255.255.0 ethernet 0/0             // global中添加到vrf 2中prefix的路由，注意下一跳需要指定是物理接口，如果指定ip的话，不能正常路由

vpc4> ping 12.1.1.2 -c 1                // vrf 2与global之间三层可达

84 bytes from 12.1.1.2 icmp_seq=1 ttl=63 time=1.219 ms
```

vrf 3与global之间的通信类似配置。
对于vrf 2与vrf 3之间的通信：
```
R1(config)#ip route vrf 2 13.1.1.0 255.255.255.0 13.1.1.3 global            // 在vrf 2中添加vrf 3中prefix的路由，下一跳去global中找
R1(config)#ip route 13.1.1.0 255.255.255.0 ethernet 0/1                     // global中没有到vrf 3的路由，所以需要在global中添加到vrf 3中prefix的路由

R1(config)#ip route vrf 3 12.1.1.0 255.255.255.0 12.1.1.2 global            // 同理在vrf 3中添加到vrf 2中prefix的路由
R1(config)#ip route 12.1.1.0 255.255.255.0 ethernet 0/0        

vpc2> ping 13.1.1.3 -c 1                    // vrf 2与vrf 3之间三层可达

84 bytes from 13.1.1.3 icmp_seq=1 ttl=63 time=3.980 ms
```

由于global中已经有了到vrf 2和vrf 3的路由，所以对于vrf 3访问global，只需要添加一条：
```
R1(config)#ip route vrf 3 14.1.1.0 255.255.255.0 14.1.1.4 global

vpc4> ping 13.1.1.3 -c 1                // vrf 3与global之间三层可达

84 bytes from 13.1.1.3 icmp_seq=1 ttl=63 time=2.165 ms

```

这里面的一个基本思路是：如果一个vrf想要访问其它vrf的网段(无论是不是default vrf)
1. 下一跳都要指定到global中去找，global中如果没有对应的路由，就要在global中补上
2. 同时global中一定要有返回该vrf的路由
3. 网络是双向的，来回都需要有路由。

分析下一下路由表，这是最本质的东西了：
```
对于vrf 2的路由表:
R1#show ip route vrf 2 static         
      13.0.0.0/24 is subnetted, 1 subnets
S        13.1.1.0 [1/0] via 13.1.1.3                    // 去往vrf 3的路由，到global中找下一跳13.1.1.3  (路由表中好像并没有什么地方体现出到global去找)
      14.0.0.0/24 is subnetted, 1 subnets
S        14.1.1.0 [1/0] via 14.1.1.4                    // 去往global的路由

// 对于global路由表
R1#show ip route static 
      12.0.0.0/24 is subnetted, 1 subnets
S        12.1.1.0 is directly connected, Ethernet0/0
      13.0.0.0/24 is subnetted, 1 subnets
S        13.1.1.0 is directly connected, Ethernet0/1    // 指明13.1.1.0网段的出口

R1#show ip route vrf 3 static 
      12.0.0.0/24 is subnetted, 1 subnets
S        12.1.1.0 [1/0] via 12.1.1.2                    // 12.1.1.0的回程路由
      14.0.0.0/24 is subnetted, 1 subnets
S        14.1.1.0 [1/0] via 14.1.1.4                    

```

一张图来收尾吧：
![](https://rancho333.github.io/pictures/vrf_leaking_route.png)