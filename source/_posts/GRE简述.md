---
title: GRE简述
date: 2022-07-29 10:12:43
tags: vpn
---

# 写在前面
承接上文[vpn技术简述](https://rancho333.github.io/2022/07/28/vpn%E6%8A%80%E6%9C%AF%E7%AE%80%E8%BF%B0/)，本文探讨下GRE(general routing encapsulation),通用路由封装技术， GRE是VPN的一种简单实现。
<!--more-->

# GRE介绍
在探讨一种网络技术之前，必然需要了解该技术的应用背景，解决什么问题。internet虽然统一了今天的网络世界，但是私有网络，异构网络依然存在，他们有着通过internet互联的需求，这就是GRE需要解决的问题。
- 私有网络无法通过internet互通
- 异构网络(IPX、AppleTalk)之间无法通过internet进行通信
- 私网之间部署的动态路由无法跨越internet
好比送快递，比如某快递公司只有北京上海的分部，没有两地之间互通的能力，这时把需要互通的包裹给顺丰，顺丰就是internet, 某快递就是私有网络或异构网络。

GRE可以把某种网络的报文封装在以太网上进行传输，1994年GRE问世，RFC编号是RFC1701和RFC1702.

任何一种封装技术，其基本构成要素都可以分成三个部分：乘客协议、封装协议、传输协议。GRE中乘客协议可以是ip/ipx, 封装协议自然就是GRE自身，传输协议是ip。

gre的封装过程可以分成两步，第一步是在乘客协议之前加上gre报文头，第二步是在第一步的基础上添加新的ip报文头。

在产品实现的角度，上述的封装过程是通过一个逻辑接口来实现的，这个逻辑接口是tunnel接口，在下文的实验中会讲到。封装的基本过程如下图所示：
![](https://rancho333.github.io/pictures/gre_encapsulation.png)

- 私网流量到达路由器入接口，路由器查询路由表对此流量进行转发
- 路由器根据路由查找结果，将此流量引导到tunnel接口进行gre封装
- 封装后的gre报文再次查找路由表进行流量转发
- 路由器根据路由查找结果，找到出接口，将流量转发到internet

对于解封装，需要注意的是，当gre报文到达隧道终点时，tunnel通过判断运输协议(IP报文)的protocol字段是否为47来判定报文是不是gre报文，如果是，解封装，然后转发或路由。

## GRE报文说明
gre报文如图所示。
![](https://rancho333.github.io/pictures/gre_packet.png)

GRE的报文很简单，注意其中`recursion`字段，该字段表示GRE封装的层数，完成一次GRE封装加1,如果大于3则丢弃报文，这是为了防止对GRE报文的无限封装。

# GRE实验
实验拓扑如下：
![](https://rancho333.github.io/pictures/gre_topology.png)

R1和R3上分别创建loopback接口，它们之间通过gre进行通信。隧道的逻辑端口分别是R1和R2上创建的`tunnel 0`, 对于需要通过GRE进行封装的报文，需要保证目的ip的下一跳是`tunnel 0`；隧道物理端口分别是R1和R2的eth0接口，需要保证两者之间路由可达。具体配置如下：
{% tabs tab,1 %}
<!-- tab R1-->
```
interface Loopback0
 ip address 1.1.1.1 255.255.255.0           // 创建lp0接口
!
interface Tunnel0                              // 创建tunnel逻辑端口
 ip address 13.1.1.1 255.255.255.0              // 配置tunnel ip地址
 tunnel source Ethernet0/0                      // 配置tunnel源
 tunnel destination 23.1.1.3                    // 配置tunnel目的
!
interface Ethernet0/0
 ip address 12.1.1.1 255.255.255.0
!
ip route 3.3.3.3 255.255.255.255 Tunnel0        // 静态路由，乘客报文与逻辑隧道之间路由可达
ip route 23.1.1.0 255.255.255.0 12.1.1.2        // 静态路由，隧道物理端口之间路由可达
!
```
<!-- endtab -->
<!-- tab R2-->
```
interface Ethernet0/0
 ip address 12.1.1.2 255.255.255.0
!
interface Ethernet0/1
 ip address 23.1.1.2 255.255.255.0
!
```
<!-- endtab -->
<!-- tab R3-->
```
interface Loopback0                             // 说明如R1
 ip address 3.3.3.3 255.255.255.255
!
interface Tunnel0
 ip address 13.1.1.3 255.255.255.0
 tunnel source Ethernet0/0
 tunnel destination 12.1.1.1
!
interface Ethernet0/0
 ip address 23.1.1.3 255.255.255.0
!
ip route 1.1.1.1 255.255.255.255 Tunnel0
ip route 12.1.1.0 255.255.255.0 23.1.1.2
```
<!-- endtab -->
{% endtabs %}
配置的关键在于将需要进入隧道的流量引导到隧道逻辑端口`tunnel 0`(路由下一跳是tunnel), 然后保证隧道物理端口之间的路由可达。对于`tunnel 0`的路由，使用ospf来代替则是：
{% tabs tab,1 %}
<!-- tab R1-->
```
router ospf 110
 network 1.1.1.1 0.0.0.0 area 0         // 将需要gre封装的流量加入ospf计算
 network 13.1.1.0 0.0.0.255 area 0      // 将tunnel 0将入ospf计算
```
<!-- endtab -->
<!-- tab R3-->
```
router ospf 110
 network 3.3.3.3 0.0.0.0 area 0
 network 13.1.1.0 0.0.0.255 area 0
```
<!-- endtab -->
{% endtabs %}

注意此时tunnel两端需要配置成一个网段。查看一下ospf的邻居状态及路由表：
```
R3#show ip ospf neighbor 

Neighbor ID     Pri   State           Dead Time   Address         Interface
1.1.1.1           0   FULL/  -        00:00:35    13.1.1.1        Tunnel0

R3#show ip route ospf | begin 1.1.1.1
O        1.1.1.1 [110/1001] via 13.1.1.1, 00:03:32, Tunnel0
```

对于ospf报文的gre封装：
![](https://rancho333.github.io/pictures/gre_ospf.png)

可以看到传输协议的源目地址就是隧道物理端口的地址，ospf hello报文的源地址是隧道逻辑端口tunnel的地址。

测试两个loopback接口之间的连通性：
```
R3#ping 1.1.1.1 source 3.3.3.3
Type escape sequence to abort.
Sending 5, 100-byte ICMP Echos to 1.1.1.1, timeout is 2 seconds:
Packet sent with a source address of 3.3.3.3 
!!!!!
Success rate is 100 percent (5/5), round-trip min/avg/max = 1/1/1 ms
```
对于icmp报文的gre封装：
![](https://rancho333.github.io/pictures/gre_ping.png)

## gre实验的几个问题
cisco的tunnel默认封装类型就是gre，不用特殊指定。华为tunnel的封装类型需要指定。

tunnel接口的IP地址是否必须要配置？隧道两端的tunnel接口ip地址是否有所关联？tunnel接口使用的公网ip还是私网ip?

tunnel接口是一个三层接口，需要路由，所以必须配置ip地址，否则不能up. 从上面的抓包来看，只有使用ospf协议时，tunnel的ip才会体现到乘客协议中，走静态路由时则没有任何存在感，考虑到将tunnel看成一个虚拟的直连链接，建议tunnel两端配置成同一网段(否则ospf时邻居无法建立)；tunnel的ip不会出现在传输协议中，所以设置成私网ip即可。

tunnel是一个无状态的隧道，怎么感知对方的状态呢？否则会造成数据黑洞的问题。可以在tunnel接口下开启`keepalive`功能，tunnel会发送一个保活报文给对端，解封装后再路由回来，这样就可以检测链路以及对端设备是否正常。保活报文抓包如下：
![](https://rancho333.github.io/pictures/gre_keepalive.png)

可以看到传输协议与乘客协议的报文源目地址刚好是相反的，即R3的eth0发出的keepalive，R1的eth0收到之后解封装再路由，又会重新发送给R3的eth0。假设R1上的tunnel down(或者ip没配)，那么就无法完成解封装。

最后一个问题是安全性的问题。我们在抓包过程中可以直接看到乘客协议的报文内容，比如我们知道乘客协议是icmp还是ospf等，这是不安全。GRE over IPSec可以解决这个问题。后面会接续研究。

参考资料：
[强叔侃墙 VPN篇 GRE](https://forum.huawei.com/enterprise/zh/thread-256801.html)