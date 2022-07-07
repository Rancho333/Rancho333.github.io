---
title: hsrp简述
date: 2022-07-07 17:09:02
tags:
---
# 写在前面
在介绍HSRP之前先简单说明一下FHRP(first hop redundancy protocol)，第一跳冗余协议。第一跳即网关，终端设备单网卡往往只能配置一个网关，所以会存在单点故障，传输网中则可以通过路由协议提供链路冗余。FHRP就是为了解决这一问题而出现的，需要注意的是FHRP更多的是一种场景的描述，并不是具体协议，真正的实现则是由HSRP、VRRP、GLBP、L3 mlag来完成的。类似于Ethernetchannel，其真正的实现则是由LACP、PAgP、static这些方式来完成。
<!--more-->
HSRP(hot standby routing protocol)和GLBP(gateway load balancing protocol)是cisco的私有协议，vrrp(virtual router redundancy protocol)是公有的。这里主要介绍HSRP的基本原理，然后做一个HSRP+PVSTP的实验来说明不同网段的负载均衡。

# 原理介绍
一组交换机(实际上是交换机的三层接口)加入一个group中，这个group向外提供虚拟ip作为网关。这些交换机通过交换hsrp hello报文选举出active和standby，其它的交换机是candidates，active网关进行数据转发，当active挂掉之后，standby成为新的active，并从candidate中选举出新的standby。注意，HSRP是单活的。

只有active才会对arp进行应答，standby忽略。选举出active后，active会立即向外发送免费ARP报文，在拓扑收敛场景下，这会立马环境中的arp缓存和旧的mac地址表。

## 简单配置说明
拓扑图如下：

![](https://github.com/Rancho333/pictures_hub/blob/master/non_auto/hsrp_basic_topology.png?raw=true)

S8做接入交换机，网关设置在汇聚层，由S7和S9形成的虚拟IP`192.168.1.254`承担。配置如下：
```
S7
interface Vlan1
 ip address 192.168.1.1 255.255.255.0          // 配置三层接口地址，hsrp报文原地址
 standby 1 ip 192.168.1.254                    // 加入虚拟组1，虚拟ip为192.168.1.254

S9
interface Vlan1
 ip address 192.168.1.2 255.255.255.0
 standby 1 ip 192.168.1.254
```
通过`show standby brief`可以查看hsrp状态。
```
S7#show standby brief 
                     P indicates configured to preempt.
                     |
Interface   Grp  Pri P State   Active          Standby         Virtual IP
Vl1         1    101 P Active  local           192.168.1.2     192.168.1.254
```

hsrp的配置非常简单，实际上就一条命令。注意standby命令的配置一定要加上group id，如果不加默认是给group 0做配置。如`standby ip 192.168.1.56`，表示端口加入虚拟组0，虚拟ip是192.168.1.56. 一个三层接口可以加入多个虚拟组。

## HSRP报文说明
HSRP hello报文格式如下

![](https://github.com/Rancho333/pictures_hub/blob/master/non_auto/hsrp_hello_packet.png?raw=true)

- version: 0表示HSRP v1, 1表示HSRP v2
- op code: 0表示hello报文，1表示coup报文，3表示advertise报文
- state：端口状态，见下表
- hellotime: active周期性发送hello报文，standby通过监听hello报文确定active的状态。默认3秒
- holdtime：active超时时间，standby在holdtime时间内没有收到active的hello报文，重新选举active。默认10秒
- priority：端口优先级，优先最大的选举成为active，如果优先级一致，IP地址越大越优
- group：虚拟组，三层接口加入相同虚拟组，之后选举出active/standby，虚拟组对外提供网关服务
- authentication: 认证方式，可以设置认证口令，如果group相同，认证不通过，那么不能参与到虚拟组中
- virtual ip add: 虚拟网关的ip. 虚拟组中的成员端口需要配置相同的vip。

端口状态如下：

|状态|说明|
| :--- | :--- |
| initial | HSRP启动的初始状态 |
| listen | 路由器知道了vip，开启侦听其它HSRP路由器发送的hello报文，candidates处于该状态 |
| speak | 发送hello报文，参与选举 |
| standby | 备用网关，继续发送hello报文，**源mac是发送接口的mac** |
| active | 作为网关转发数据流量，继续发送hello报文，**源mac是虚拟MAC** |

## Vip与Vmac
加入同一个虚拟组的三层接口下配置相同的vip，这个ip作为终端的网关。
vmac是根据虚拟组ID构造出来的一个mac地址：
- 在v1中是0000.0c07.acXX (XX = group number)
- 在v2中是0000.0c9f.fxxx (XXX = group number)

## preempt抢占
HSRP默认不开启抢占机制，即active/standby角色确定后，即使改变优先级比active大，也不会发生抢占。可以通过`S3(config-if)#standby 10 preempt`命令开启抢占功能。

状态稳定后，只有修改优先级才会发生抢占。不会根据IP地址的大小做出改变。

## md5认证
HSRP支持认证，可以选择明文或md5. md5配置方式如下：
`S2(config-if)#standby 10 authentication md5 key-string rancho`
这可以避免未经授权的交换机参与HSRP计算。

## HSRP Version 1 和 2
HSRP有两个版本，呃，貌似没什么太大区别，简单过下吧：
|| V1 | V2 |
| :--- | :--- | :--- |
| group nums | 0-255 | 0-4096 |
| vmac | 0000.0c07.acXX (XX = group number) | 0000.0c9f.fxxx (XXX = group number)|
| multicast add | 224.0.0.2 | 224.0.0.102 |
注意两个版本是不兼容的，都同时支持ipv4和ipv6.

## object tracking
沿用`简单配置说明`中的拓扑图。当前环境下，S7是active，如果eth1链路故障或者S7挂掉或者interface vlan1挂掉，那么S9在10秒内没有收到active的hello报文后会成为新的active。但是如果是S7的eth2挂掉，即S7没有了上行链路，eth1依然会周期性发送hello，S9并不会感知到active网关不能正常工作。

S7会向vpc发送`icmp redirect`报文让其修改默认网关，但更好的方式是让S9成为active网关。(实验时将S7上eth2 shutdown，vpc上ping R6的loopback1, 可以ping通，发现S7依然是active，S8发送的icmp报文依然是送到S7，S7将icmp的src mac改成自己mac，目的mac改成S9的mac，进而到达R6)

这种场景下需要使用`object tracking`功能来追踪S7上eth2的状态，如果上行链路故障，就降低本地hsrp优先级，使standby转换成active工作。

HSRP提供端口追踪的特性，我们可以选取一个端口进行追踪，如果挂了，就可以降低设备hsrp优先级，使其它的standby变成active。配置如下：
```
S7(config)#track 1 interface ethernet 0/2 line-protocol    // 创建track object 1, track内容是ethernet 0/2的状态，如果down就触发
S7(config-if)#standby 1 track 1 decrement 50    // 在group 1上关联track object 1，如果触发将优先级降低50
```

将S7的eth2 shutdown之后，发现优先级降低，active变了。
```
S7#show standby brief 
                     P indicates configured to preempt.
                     |
Interface   Grp  Pri P State   Active          Standby         Virtual IP
Vl1         1    50  P Speak   192.168.1.2     unknown         192.168.1.254
```

另外一种方式是关联`ip sla`. 配置如下：
```
S7(config)#ip sla 1                 // 创建一条sla，id是1
S7(config-ip-sla)#icmp-echo 192.168.4.1       // 测试与192.168.4.1的连通性
S7(config-ip-sla-echo)#frequency 5            //每5秒ping一次
S7(config)#ip sla schedule 1 start-time now life forever     // sla 1从现在开始运行并且一直运行下去

S7(config)#track 1 ip sla 1         // 创建track object 1, 与ip sla 1关联
S7(config-if)#standby 1 track 1 decrement 80     // 将track 1与group 1关联
```
这种方式下发现S7 ping 192.168.4.1的吓一跳变成S9，因为他们之间跑了ospf。但是没关系，原理是这么个原理，把ospf关了就可以触发了。

### track list特性
当有多个track对象，最终的结果是依赖这些对象跟踪结果时，可以使用`track list`特性。
沿用`简单配置说明`中的图：
```
track 2 interface Ethernet0/1 line-protocol             // 创建track object 2，跟踪eth1的链路状态
!
track 3 interface Ethernet0/2 line-protocol             // 创建track object 3，跟踪eth2的链路状态
!
track 4 list boolean and                                // 创建track list 4, list中的对象逻辑与结果是track 4的最终结果
 object 2                                               // 给track list 4添加list监控对象2
 object 3                                               // 给track list 4添加list监控对象3
// 当eth2和eth3都是up的时候，track 4结果是up，否则down
```
结果如下：
```
S7#show track brief 
Track Type        Instance                   Parameter        State Last Change
1     ip sla      1                          state            Down  00:09:17
2     interface   Ethernet0/1                line-protocol    Up    00:07:55
3     interface   Ethernet0/2                line-protocol    Up    00:06:38
4     list                                   boolean          Up    00:05:08
```
当HSRP有两个上行链路时，track 2、3分别监控两个上行链路，只用在hsrp中关联track4就行，减少关联对象。

## HSRP结合PVSTP做不同网段流量的负载均衡
实验拓扑如下：

![](https://github.com/Rancho333/pictures_hub/blob/master/non_auto/hsrp_pvstp.png?raw=true)

HSRP与PVSTP同时使用时，做不同网段的负载均衡，应注意该网段(vlan)HSRP的active与PVSTP的根桥应在同一设备上，不然流量会集中到某一台设备上，导致该设备负载过大，而另一台没有流量需要转发。配置思路如下：
1. 划分vlan，配置交换机互联trunk
```
S1
    vlan 10,20
    interface Ethernet0/0
        switchport access vlan 10
    interface Ethernet0/1
         switchport trunk encapsulation dot1q
         switchport mode trunk
    interface Ethernet0/2
         switchport trunk encapsulation dot1q
         switchport mode trunk
    interface Ethernet0/3
         switchport access vlan 20
S2, S3做类似配置
```
2. 设置vlan的根桥，S2是vlan10的根桥，S3是vlan20的根桥
```
S2
    spanning-tree vlan 10 priority 4096
S3
    spanning-tree vlan 20 priority 4096
```
3. 创建interface vlan; 设置hsrp，S2是vlan10所在网段的active，S3是vlan20所在网段 的active
```
S2
    interface Vlan10
        ip address 192.168.1.1 255.255.255.0
        standby 10 ip 192.168.1.254
        standby 10 priority 101
        standby 10 preempt
S3
    interface Vlan10
        ip address 192.168.1.3 255.255.255.0
        standby 10 ip 192.168.1.254
        standby 20 preempt
//S2作为vlan10网段的active

S2
    interface Vlan20
       ip address 192.168.2.1 255.255.255.0
       standby 20 ip 192.168.2.254
       standby 10 preempt
S3
    interface Vlan20
       ip address 192.168.2.3 255.255.255.0
       standby 20 ip 192.168.2.254
       standby 20 priority 101
       standby 20 preempt
// S3作为vlan20网段的active
```
完成后的流量路径如下图所示：

![](https://github.com/Rancho333/pictures_hub/blob/master/non_auto/hsrp_pvstp_1.png?raw=true)

在多实例中我们将不同vlan的根桥放置在不同的设备上，这样可以让不同实例的流量路径不一致，从而最大限度的利用带宽，减少流量拥塞，避免带宽浪费，同时也避免单一设备负载过高。

网关一般设置在汇聚层，我们假象下，如果vlan的根桥是S2，而active是S3，那么vpc4的流量需要经过S1到S2再转到S3(S3的eth2是block的)，无疑多了一次转发，这是不必要的，我们应当避免。