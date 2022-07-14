---
title: offset_list_and_pbr
date: 2022-07-14 14:06:00
tags: routing
---

# 写在前面
路由控制的方式有很多，比如route-map，distribute-list。今天主要了解下offset-list(偏移列表)和pbr(policy based routing, 策略路由).

# offset-list简述
offset-list非常简单，理论特点可以概括为下面几条：
- 只能在距离矢量路由协议上使用(rip，eigrp)，ospf中直接使用cost控制
- 支支持ACL不支持prefix-list
- 只可以增大metric不可以减小metric(eigrp中是metric，rip中是hop-count)
- 在调用方向上，可以在in/out上调用，作用对象不同，效果自然有所差异

## offset-list实验
拓扑图如下：

![](https://rancho333.github.io/pictures/offset_list_topology.png)

在R2、R4上的lp0上设置相同的ip地址4.4.4.4(仅实验效果)，三台路由器均运行eigrp, 则R1上对4.4.4.4有两个下一跳。基本配置如下：
{% tabs tab,1 %}
<!-- tab R1-->
```
interface Ethernet0/0
 ip address 12.1.1.1 255.255.255.0
!
interface Ethernet0/1
 ip address 13.1.1.1 255.255.255.0
!
router eigrp 90
 network 12.1.1.0 0.0.0.255
 network 13.1.1.0 0.0.0.255
```
<!-- endtab -->
<!-- tab R2-->
```
interface Loopback0
 ip address 4.4.4.4 255.255.255.255
!
interface Ethernet0/0
 ip address 12.1.1.2 255.255.255.0
!
router eigrp 90
 network 4.4.4.4 0.0.0.0
 network 12.1.1.0 0.0.0.255
```
<!-- endtab -->
<!-- tab R1-->
interface Loopback0
 ip address 4.4.4.4 255.255.255.255
!
interface Ethernet0/0
 ip address 13.1.1.3 255.255.255.0
!
router eigrp 90
 network 4.4.4.4 0.0.0.0
 network 13.1.1.0 0.0.0.255
<!-- endtab -->
{% endtabs %}

查看R1上的路由表：
```
R1#show ip route eigrp | begin 4.4.4.4
D        4.4.4.4 [90/409600] via 13.1.1.3, 00:00:10, Ethernet0/1
                 [90/409600] via 12.1.1.2, 00:00:10, Ethernet0/0
```
可以发现`4.4.4.4`的两个下一跳有相同的metric值，所以现在是ecmp。我们在R1的eth0 in方向上做一个offset-list来修改R2通告过来的路由metric。
```
R1(config)#ip access-list standard 12           // 创建标准acl，编号12
R1(config-std-nacl)#permit 4.4.4.4              // 匹配4.4.4.4的路由
R1(config)#router eigrp 90
R1(config-router)#offset-list 12 in 1 ethernet 0/0          // 在eth0/0的in方向上调用acl 12, 匹配上后将metric增加1
```

分别查看R1上eigrp的拓扑信息和路由信息：
```
R1#show ip eigrp topology | begin 4.4.4.4
P 4.4.4.4/32, 1 successors, FD is 409600
        via 13.1.1.3 (409600/128256), Ethernet0/1
        via 12.1.1.2 (409601/128256), Ethernet0/0           // 发现R2传来的4.4.4.4路由的metric加1

R1#show ip route eigrp | begin 4.4.4.4
D        4.4.4.4 [90/409600] via 13.1.1.3, 00:05:44, Ethernet0/1        // 4.4.4.4只有R3一个下一跳
```
同样的原理，在R2,R3的eth上配置out方向的offset-list可以达到同样的控制效果。

# pbr简述
pbr是route-map的一种应用，pbr是可以按照管理员思想去实现的路由, 我想让你往哪走，你就往哪走。pbr的优先级高于路由表，内容不会出现在路由表中。

## pbr实验
沿用上面offset-list的拓扑图，在R2上创建lp1:5.5.5.5，在R1上创建pbr使得R1到5.5.5.5路由可达。
```
R1(config)#ip access-list extended 100              // 创建扩展acl 100
R1(config-ext-nacl)#permit ip any 5.5.5.5 255.255.255.255       // 匹配5.5.5.5的路由
R1(config)#route-map pbr permit 10                      // 创建route-map
R1(config-route-map)#match ip address 100               // 匹配acl 100
R1(config-route-map)#set ip next-hop 12.1.1.2           // 设置下一跳ip
R1(config)#ip local policy route-map pbr                // 开启本地route-map转发，对本设备始发的流量开启pbr

// R1(config-if)#ip policy route-map pbr           如果是本地转发的流量，需要在收到流量的接口下开启pbr
```

此时查看本地路由表：
```
R1#show ip route | include 5.5.5.5
R1#
R1#ping 5.5.5.5
Type escape sequence to abort.
Sending 5, 100-byte ICMP Echos to 5.5.5.5, timeout is 2 seconds:
!!!!!
Success rate is 100 percent (5/5), round-trip min/avg/max = 1/1/1 ms
R1#
```
发现路由表中是没有5.5.5.5的路由，但是可以ping通。可通过下面方式查看本地pbr策略：
```
R1#show ip local policy 
Local policy routing is enabled, using route map pbr
route-map pbr, permit, sequence 10
  Match clauses:
    ip address (access-lists): 100 
  Set clauses:
    ip next-hop 12.1.1.2
  Policy routing matches: 20 packets, 2000 bytes
```

为了验证pbr的优先级高于路由表，我们在R3上同样创建lp1:5.5.5.5, 并宣告进eigrp，此时R1的路由表中：
```
R1#show ip route | include 5.5.5.5
D        5.5.5.5 [90/409600] via 13.1.1.3, 00:00:21, Ethernet0/1

R1#trace 5.5.5.5
Type escape sequence to abort.
Tracing the route to 5.5.5.5
VRF info: (vrf in name/id, vrf out name/id)
  1 12.1.1.2 0 msec 1 msec * 
R1#
```
发现R1上到5.5.5.5的下一跳是按照pbr走的，并不是按照路由表做的。