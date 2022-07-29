---
title: glbp简述
date: 2022-07-07 17:09:31
tags:
---
# 写在前面
GLBP(gateway load balancing protocol)是FHRP的一种实现，思科私有协议。HSRP和VRRP都只能做到单活网关，而GLBP可以实现多活网关。
VRRP/HSRP中的负载均衡是将不同网段的active放在不同的设备上，即互为对方网段的backup，这是一种伪负载均衡。而GLBP通过vip与多vmac的映射可以实现同一网段流量的负载均衡。
<!--more-->
## 几个概念

AVG(active virtual gateway): 一个虚拟组中只有一个AVG，选举产生。AVG给虚拟组中其它交换机分配vmac。只有AVG响应ARP报文。选举和抢占规则和HSRP一致，高优先级或ip地址大的成为AVG，次优的成为standby，剩下的处于listen阶段，不同于hsrp只有active和standby发送hello，glbp中所有交换机都发送hello。

AVF(active virtual forward)：相同的vip，不同的vmac，都作为网关转发流量。通过权值进行选举，最多有4个AVF，也就是5台路由器组成虚拟组，其中一台是闲置的，当然这样没必要，一般两三台就够了。

AVG就是整个虚拟组的控制面，负责vmac的分配，avf是数据面，根据vmac进行转发。

GLBAP虚拟组所有成员每隔3秒发送hello报文用以保活，目的地址是224.0.0.102。承载在UDP之后，端口号是3222(source和dest一样)。

load balancing的三种模式：
- round-robin：根据收到arp的先后顺序，依次响应AVF1、AVF2、AVF3的vmac，然后再循环1,2,3
- host-dependent：基于arp中请求者的mac地址做分配，相同的请求者始终分配相同的vmac
- weighted：不同的avfs分配不同的权重值，基于此响应arp
AVG对ARP回应vmac的策略就是GLBP上负载均衡的策略。

*GLBP的一个先决条件：一个物理端口支持配置多个mac地址(一般交换芯片都支持)*，hsrp、vrrp、glbp本质上都是一个三层接口可以配置多个ip/mac。通过ip/mac可以定位到唯一的端口，但是端口并不一定只能通过唯一的ip、mac找到。类似于一辆车上有多个车牌。

### vmac分配
每个虚拟组最多有4个vmac. AVG负责虚拟组内vmac分配。组成员发现AVG后通过hello消息请求vmac。通过AVG分配vmac的成为primary virtual forwarder(即通过该vmac作为网关进行数据转发)。通过hello报文学到其它forwarder的vmac的称为secondary virtual forwarder(组内的任一forwarder会学到其它所有forwarder对应的vmac)。

`0007.b400.XXYY`是vmac的组成形式，XX是group id，YY是组内vmac的序列号，`show glbp brief`中`Fwd`字段可以看到。

### glbp优先级
优先级最高的成为AVG，次之的成为standby，其它的是listen状态。如果优先级一致，ip越大越优。
AVG抢占默认关闭，需要手动开启。

### glbp权重
用权重来表示avf的数据转发能力。权重可以决定avf是否转发流量
可以设置一个权重阈值，当到该值值时不转发流量
也可以设置到指定值转发流量的阈值，可以和tracking进行联动。

### AVG冗余
AVG挂掉后，standby接替，然后从listen状态的交换机中选举出新的standby.

### AVF冗余
当AVF挂掉后，会从其它的secondary virtual forwarder中选出一个继续使用挂掉avf的vmac，这样用户的流量就不会中断。
AVF默认开启抢占。

### GLBP存在的问题
GLBP原本是思科私有协议，现在开源了，但是用的人并不多，因为glbp天生与stp不对付，glbp中需要各avf链路才有LB的效果，但是stp却极有可能阻塞其中的一些链路。

## 实验说明
实验拓扑图如下：

![](https://rancho333.github.io/pictures/glbp_basic_topology.png)

S2、S3、S4在一个虚拟组内，通过interface vlan1为vlan1所在网段提供网关服务，虚拟网关ip为`192.168.1.254`，VPC5、VPC6、VPC7都在vlan1中。

配置如下：
```
S2:
interface Vlan1
 ip address 192.168.1.2 255.255.255.0
 glbp 1 ip 192.168.1.254

S3:
interface Vlan1
 ip address 192.168.1.3 255.255.255.0
 glbp 1 ip 192.168.1.254

S4:
interface Vlan1
 ip address 192.168.1.4 255.255.255.0
 glbp 1 ip 192.168.1.254
```
通过`show glbp brief`查看glbp的状态：

![](https://rancho333.github.io/pictures/glbp_show_brief.png)

对show的状态做一个简单说明：
- `Grp`表示接口所在的glbp组id
- `Fwd`表示avf编号，注意第一行没有编号，显示的是AVG信息，图中可以看到AVG是S4，standby avg是S3，S2则出于listen状态。站在avf的视角下，每个avf都分配到一个vmac，对应一个fwd编号，那么他就是这个fwd编号的active，其它avf在这个编号中都是listen，当active挂掉后，从listen中选出一个继续为该fwd编号对应的vmac服务。forwarder恢复后，会收回该vmac的使用权。

GLBP默认使用的LB方式是round-robin, 即根据收到arp报文的顺序，依次循环分配fwd1、2、3对应的vmac，在VPC5、6、7上依次ping网关，查看arp表项：
```
VPC5> show arp

00:07:b4:00:01:01  192.168.1.254 expires in 37 seconds

VPC6> show arp

00:07:b4:00:01:02  192.168.1.254 expires in 115 seconds

VPC7> show arp

00:07:b4:00:01:03  192.168.1.254 expires in 113 seconds
```
在VPC7上清除arp信息，重新ping网关：
```
VPC7> clear arp
VPC7> show arp
arp table is emptys
VPC7> ping 192.168.1.254

84 bytes from 192.168.1.254 icmp_seq=1 ttl=255 time=0.409 ms
^C0
VPC7> show arp

00:07:b4:00:01:01  192.168.1.254 expires in 116 seconds
```
和预期一致，重新分配fwd1的vmac。此外，LB还可以基于主机，基于avf权重。这里就不一一尝试了。