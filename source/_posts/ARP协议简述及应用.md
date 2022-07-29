---
title: ARP协议简述及应用
date: 2020-12-25 13:22:08
tags: 
    - 通信协议
---

# 写在前面
这篇文章分为两个部分ARP协议简介以及ARP协议的实际应用。

<!--more-->
# ARP协议简介

## ARP的作用

ARP(Address Resolution Protocol，地址解析协议)是将IP地址解析为以太网MAC地址的协议。与之相对的，将MAC地址解析为IP地址的协议称为RARP。

在局域网中，当终端设备需要将数据发送给另一个终端设备时，它必须知道对方网络的IP地址。但是仅仅有IP地址是不够的，因为IP数据必须封装成帧才能通过物理网络发送，因此发送端还必须有接收端的MAC地址，所以需要一个从IP地址到物理地址的映射。ARP就是实现这个功能的协议。

## ARP报文的结构

![](https://rancho333.github.io/pictures/arp_protocol.png) 

对于各个字段的解释如下

| 字段 | 长度（bit）| 含义 |
| :--- | :--- | :--- |
| Ethernet Address of destination| 48 | 目的以太网地址。发送ARP请求时，为广播MAC地址，0xFF.FF.FF.FF.FF.FF |
| Ethernet Address of sneder | 48 | 源以太网地址 |
| Frame Type | 16 | 表示报文类型。对于ARP请求或应答，该字段为0x0806 |
| Hardware Type | 16 | 表示硬件地址的类型。对于以太网，该字段为1 |
| Protocol Type | 16 | 表示发送方要映射的协议地址类型。对于IP地址，该值为0x0800 |
| Hardware Length | 8 | 表示硬件地址的长度，单位是字节。对于ARP请求或应答来说，该值为6 | 
| Protocol Length | 8 | 表示协议地址的长度，单位是字节。对于ARP请求或应答来说，该值为4 |
| OP | 16 | 表示操作类型。1 表示ARP请求，2 表示ARP应答，3表示RARP请求，4表示RARP应答 |
| Ethernet Address of sneder | 48 | 发送方以太网地址。这个字段和ARP报文首部的源以太网地址字段是重复信息 | 
| IP Address of sender | 32 | 发送方IP地址 |
| Ethernet Address of destination| 48 | 接收方以太网地址，发送ARP请求时，该处填充全0 |
| IP Address of destination | 32 | 接收方IP地址 | 

在Linux上可以通过tcpdump工具抓取ARP包

![](https://rancho333.github.io/pictures/arp_data_raw.png)
使用wireshark工具可以更为方便的查看报文中的各个字段：

![](https://rancho333.github.io/pictures/arp_data.png) 

## ARP地址解析过程

假设主机A和B在同一个网段，主机A要向主机B发送信息，解析过程如下：
- 主机A查看自己的ARP表，找到则直接使用
- 如果A在ARP表中没有找到B，则
    - 缓存IP数据报文
    - 发送ARP请求报文，请求B的MAC地址
- 主机B比较自己的IP地址与ARP请求报文中的IP地址，两者相同则：
    - 将A的IP与MAC地址缓存到自己的ARP表中
    - 单播发送ARP应答报文给主机A，其中包含自己的MAC地址
- 主机A收到ARP响应后，缓存B的MAC到ARP表中，之后发送IP数据报文

当主机A和B不在同一网段时，主机A会向网关发送ARP请求。如果网关有主机B的ARP表项，则直接应答A；否则网关广播ARP请求，目标IP地址为主机B的IP地址，网关收到响应报文之后再应答B。

## ARP表

ARP表分为动态ARP表和静态ARP表。
```
Address                  HWtype  HWaddress           Flags Mask            Iface
10.204.113.138           ether   00:00:00:00:00:01   C                     ens160
10.204.113.151                   (incomplete)                              ens160
172.17.0.7               ether   02:42:ac:11:00:07   C                     docker0
10.204.112.11            ether   00:e0:ec:47:33:1a   C                     ens160
openbmc-develop.asia.ad  ether   00:e0:4c:06:00:95   C                     ens160
10.204.112.44            ether   6c:b3:11:32:7f:12   C                     ens160
172.17.0.2               ether   02:42:ac:11:00:02   C                     docker0
sonic.asia.ad.celestica  ether   aa:ad:40:03:ba:19   C                     ens160
```

### 动态ARP表

动态ARP表由ARP协议通过ARP报文自动生成与维护，可以被老化，可以被新的ARP报文更新，可以被静态ARP表项覆盖。当到达老化时间、接口down时会删除相应的动态ARP表项。

### 静态ARP表项

静态ARP表项通过手工配置和维护，不会被老化，不会被动态ARP表项覆盖。

配置静态ARP表项可以增加通信的安全性。静态ARP表项可以限制和指定IP地址的设备通信时使用指定的MAC地址，此时攻击报文无法修改此表项的IP地址和MAC地址的映射关系，
从而保护了本设备和指定设备间的正常通信。

静态ARP表项分为短静态ARP表项和长静态ARP表项。
- 长静态ARP表项必须配置IP地址、MAC地址、所在VLAN和出接口。长静态ARP表项可直接用于报文转发。
- 短静态ARP表项只需要配置IP地址和MAC地址。
    - 如果出接口是三层口，直接用于报文转发
    - 如果出接口是VLAN虚接口，短静态ARP表项不能直接用于报文转发，当要发送IP数据包时，先发送ARP请求报文，如果收到的response中的
    源IP和源MAC与所配置的相同，则将收到response的接口加入该静态ARP中，之后用于IP数据包转发。

当希望设备和指定用户只能使用某个固定的IP地址和MAC地址通信时，可以配置短静态ARP表项，当进一步希望这个用户只在某个VLAN内的某个特定接口上连接时就可以配置长静态ARP表项

## 免费ARP

免费ARP是一种特殊的ARP报文，该报文中携带的发送端与目的端IP都是本机IP，发送端MAC是本机MAC，接收端MAC是全f。其本质是keep alive保活/心跳报文的应用。
免费ARP报文有以下功能:
- IP地址冲突检测。如果有冲突，冲突设备会给本机发送一个ARP应答，告知IP地址冲突
- 设备改变MAC地址，发送免费ARP更新其它设备中的ARP表项

定时发送免费ARP的应用场景：
- 防止仿冒网关的ARP攻击（ARP欺骗）
    - 如果攻击者仿冒网关发送免费ARP报文，可以将原本发送到网关的流量重定向到一个错误的MAC地址，导致用户无法正常访问网络。网关接口上使能免费ARP功能后，主机可以学习到正确的网关。
- 防止ARP表项老化
- 防止VRRP虚拟IP地址冲突
- 及时更新模糊终结VLAN内设备的MAC地址表

# ARP协议应用
ARP协议的状态机比较简单，但是应用起来是比较有意思的，一些基础网络问题也是值得思考的。

## 二层通信与三层通信中ARP的应用
二三层设备互通中arp是怎样工作的？

![](https://rancho333.github.io/pictures/ping_arp.png)
如图所示，两个vlan通过interface vlan路由接口实现互通。下文说明中，交换机和终端设备均为初始状态，不含有arp表项。

### A和B之间的互通(二层)
以A向B发起ping请求为例。
1. A检查报文的目的IP地址发现和自己在同一个网段；
2. A---->B ARP请求报文，该报文在VLAN1内广播
    1. 报文的dst mac是广播mac，src mac是A mac
    2. 报文的sender MAC是A mac, sender ip是A ip; target mac是全0，target ip是B ip
3. B---->A  ARP回应报文
    1. 报文的dst mac是A mac, src mac是B mac
    2. 报文的sender MAC是B mac(A请求的mac), sender ip是B ip; target mac是A mac，taaget ip是A ip
4. A---->B  icmp request
5. B---->A  icmp reply

### A和C之间的互通(三层)
以A向C发起ping请求为例。
1. A检查报文的目的IP地址，发现和自己不在同一个网段
2. A---->switch(int vlan 1) ARP请求报文，该报文在vlan1内广播
    1. 报文的dst mac是广播mac，src mac是A mac
    2. 报文的sender MAC是A mac, sender ip是A ip; target mac是全0，target ip是int vlan 1 ip
3. 网关----> A ARP回应报文
    1. 报文的dst mac是A mac, src mac是int vlan 1 mac
    2. 报文的sender MAC是int vlan 1 mac(A请求的mac), sender ip是int vlan 1 ip; target mac是A mac，taaget ip是A ip
4. A---->C icmp request
    1. 报文dst mac是int vlan 1的mac，src mac是A的mac; dst ip是C ip，src ip是A ip
5. switch收到报文后判断出是三层报文，检查报文的目的IP地址，发现是在自己的直连网段
6. switch(int vlan 2)---->C ARP请求报文，该报文在vlan2内广播
7. C---->switch(int vlan 2) ARP回应报文
8. switch(int vlan 2)---->C icmp request
    1. 报文的dst mac是C的mac, src mac是int vlan 2的mac; dst ip是C ip, src ip是A ip
9. C---->A icmp reply, 这以后的处理同前面icmp request的过程基本相同。

对报文路由，会对报文的MAC头进行重新封装，而IP层以上的字段基本不变。通过说明报文dst/src MAC的变化，注意ARP在二三层通信中起的作用。后续设备中ARP表有了相应的条目之后，则不会给对方发送ARP请求报文。

## ARP代理
如果ARP请求是从一个网络的主机发往同一网段却不在同一物理网络上的另一台主机，那么连接它们的具有代理ARP功能的设备就可以回答该请求，这个过程称作代理ARP（Proxy ARP）
代理ARP功能屏蔽分离的物理网络这一事实，使用户使用起来，好像在同一物理网络上。
代理ARP分为普通代理ARP和本地代理ARP，二者的应用场景有所区别。
- 普通代理ARP的应用场景：想要互通的主机分别连接到设备的不同的三层接口上，且这些主机不在同一个广播域中
- 本地代理ARP的应用环境为：想要互通的主机连接到设备的同一个三层接口在，且这些主机不在同一个广播域中

### 普通代理ARP
处于同一网段内的主机，当连接到设备的不同三层接口时，可以利用设备的代理ARP功能，通过三层转发实现互通。
拓扑如下图所示。设备Router通过两个三层接口Eth1/1和Eth1/2连接两个网络，两个三层接口的IP地址不在同一个网段，但是两个网络内的主机Host A和Host B的地址通过掩码的控制，既与相连设备的接口地址在同一网段，同时二者也处于同一个网段。
![](https://rancho333.github.io/pictures/general_arp_agent.png)
这种组网场景下，当Host A需要与Host B通信时，由于dst ip与src ip在同一网段，因此Host A会直接对Host B进行ARP请求。但是，两台主机不在同一个广播域中，Host B无法收到Host A的ARP请求报文，当然也就无法应答。
通过在Router上启用代理ARP功能，可以解决此问题。启用代理ARP后,Router可以应答Host A的ARP请求。同时，Router相当于Host B的代理，把从其它主机发送过来的报文转发给它。
代理ARP的优点是，它可以只被应用在一个设备上（此时设备的作用相当于网关），不会影响到网络中其它设备的路由表。代理ARP功能可以在IP主机没有配置缺省网关或者IP主机没有任何路由能力的情况下使用。

### 本地代理ARP
拓扑如图所示。Host A与Host B属于同一个VLAN 2,但他们分别连接到被二层隔离的端口Eth1/3和Eth1/1上，通过在Router上启用本地代理ARP功能，可以实现Host A和Host B的三层互通。
![](https://rancho333.github.io/pictures/local_arp_agent.png)

本地代理ARP可以在下列三种情况下实现主机之间的三层互通：
- 想要互通的主机分别连接到同一个VLAN中的不同的二层隔离端口下
- 使能Super VLAN功能后，想要互通的主机属于不同的Sub VLAN
- 使能Lsolate-user-vlan功能后，想要互通的主机属于不同的Secondary VLAN

## ARP Snooping
ARP snooping功能是一个用于二层交换网络环境的特性，通过侦听ARP报文建立ARP Snooping表项，从而提供给ARP快速应答和MFF手动方式等使用。
设备上的一个VLAN使能ARP Snooping后，该VLAN内所有端口接收的ARP报文会被重定向到CPu。CPU对重定向上送的ARP报文进行分析，获取ARP报文的src ip, src mac, src vlan和入端口信息，建立记录用户信息的ARP Snooping表项。

## ARP快速应答
在无线产品组网中，AC与AP会建立隧道连接，Client通过AP连接到AC，通过AC，client可以与网关建立连接。当Client发起ARP广播请求时，需要通过AC向所有的AP复制ARP请求，这样会导致ARP广播占用隧道的大量资源，导致性能下降。为了减少ARP广播占用的隧道资源，可以在AC上启用ARP快速应答功能，减少ARP广播报文的影响。

ARP快速应答功能就是根据AC设备收集的用户信息（DHCP Snooping表项或者ARP Snooping表项），在指定的VLAN内，尽可能的对ARP请求进行应答，从而减少ARP广播报文。

### ARP快速应答工作机制
ARP快速应答的工作机制如下：
1. 设备接收到ARP请求报文时，如果请求报文的目的IP地址是设备的VLAN虚接口的IP地址，则由ARP特性进行处理
2. 如果不是，则根据报文中的目的IP地址查找DHCP Snooping表项
    1. 如果查找成功，但是查找到的表项的接口和收到请求报文的接口一致，并且接口是以太网接口，则不进行应答，否则立即进行应答
    2. 如果查找失败，则继续查找ARP Snooping表项。如果查找成功，但是查找到的表项的接口和收到请求报文的接口一致，并且接口是以太网接口，则不进行应答，否则立即进行应答。
    3. 如果两个表项均查找失败，则直接转发请求报文或将报文交于其它特性处理。

##  ARP防御攻击
ARP协议有简单、易用的优点，但是也因为没有任何安全机制而容易被攻击发起者利用。
- 攻击者可以仿冒用户、仿冒网关发送伪造的ARP报文，使网关或主机的ARP表项不正确，从而对网络进行攻击
- 攻击者通过向设备发送大量目标IP地址不能解析的IP报文，使得设备试图反复地对目标IP地址进行解析，导致CPU负荷过重及网络流量过大
- 攻击者向设备发送大量的ARP报文，对设备的CPU形成冲击。
目前ARP攻击和ARP病毒已经成为局域网安全的一大威胁。下面简单说明一下ARP攻防原理。

### ARP防止IP报文攻击功能简介
如果网络中有主机通过向设备发送大量目标IP地址不能解析的IP报文来攻击设备，则会造成下面的危害：
- 设备向目的网段发送大量的ARP请求报文，加重目的网段的负载
- 设备会试图反复地对目标IP地址进行解析，增加了CPU的负担

为了避免这种IP报文攻击所带来的危害，设备提供了下列两个功能：
- 如果发送攻击报文的源是固定的，可以采用ARP源抑制功能。开启该功能后，如果网络中某主机向设备某端口连续发送目标IP地址不能解析的IP报文，当每5秒内此主机发出IP报文出发ARP请求报文的流量超过设置的阈值，那么对于由此主机发出的IP报文，设备不允许其触发ARP请求，直至5秒后再处理，从而避免了恶意攻击所造成的危害。
-如果发送攻击报文的源不固定，设备立即产生一个黑洞路由，使得设备在一段时间内将去往该地址的报文直接丢弃。等待黑洞路由老化时间过后，如有报文触发则再次发起解析，如果解析成功则进行转发，否则仍然产生一个黑洞路由将去往改地址的报文丢弃。这种方式能够有效的防止IP报文的攻击，减轻CPU的负担。

### ARP报文限速功能
ARP报文限速功能是指对上送CPU的ARP报文进行限速，可以防止大量ARP报文对CPU进行冲击。例如，在配置了ARP Detection功能后，设备会将收到的ARP报文重定向到CPU进行检查，这样会引入新的问题：如果攻击者恶意构造大量ARP报文发往设备，会导致设备的CPU负担过重，从而造成其它功能无法正常运行甚至设备瘫痪，这个时候可以启用ARP报文限速功能来控制上送CPU的ARP报文的速率。

推荐用户在配置了ARP Detection、ARP Snooping、ARP快速应答、MFF，或者发现有ARP泛洪攻击的情况下，使用ARP报文限速功能。

### 源MAC地址固定的ARP攻击检测功能
本特性根据ARP报文的源MAC地址进行统计，在5秒内，如果收到同一源MAC地址的ARP报文超过一定的阈值，则认为存在攻击，系统会将此MAC地址添加到攻击检测表项中。在该攻击检测表项老化之前，如果设置的检查模式为过滤模式，则会打印告警信息并将该源MAC地址发送的ARP报文过滤掉。如果设置为监控模式，则只打印告警信息，不会将源MAC地址发送的ARP报文过滤掉。
对于网关或一些重要的服务器，可能会发送大量的ARP报文，为了使这些ARP报文不被过滤掉，可以将这类设备的MAC地址配置成保护MAC，这样，即使该MAC存在攻击也不会被检测过滤。只对上送CPU的ARP报文进行统计。

### ARP报文源MAC一致性检查功能简介
ARP报文源MAC一致性检查功能主要应用于网关设备上，防御以太网数据帧首部中的源MAC地址和ARP报文中sender mac地址不同的ARP攻击。

在配置被特性后，网关设备在进行ARP学习前将对ARP报文进行检查。如果以太网数据帧首部中的源MAC地址和ARP报文中sender mac地址不同，则认为是攻击报文，将其丢弃，否则，继续进行ARP学习。

### ARP主动确认功能
ARP的主动确认功能主要应用于网关设备上，防止攻击者仿冒用户欺骗网关设备。

启用ARP主动确认功能后，设备在新建或更新ARP表项前需进行主动确认，防止产生错误的ARP表项。

## MLAG结合VARP实现VRRP
VRRP(virtual router redundancy protocol，虚拟路由器冗余协议)将可以承担网关功能的一组路由器加入到备份组中，形成一台虚拟路由器，局域网内的终端设备只需将虚拟路由器配置为缺省网关即可。VRRP有两个版本，VRRPv2基于IPv4, VRRPv3基于IPv6。正统的VRRP实现起来可能有些复杂，通过MLAG结合VARP可以较为简单的实现VRRP的功能。拓扑如下。
![](https://rancho333.github.io/pictures/varp_mlag_vrrp.png)

原理说明：device作为leaf switch, 下行接host，上行通过mlag连接到两台网关。策略配置之后，host发往网关的流量只会通过mlag中的一个端口发往switch A或switch B, 当mlag中一条线路down掉时，通过另一条线路通信，在switch A和switch B上运行VARP协议，通过配置相同的VIP和VMAC实现网关虚拟化。这里面有两个关键点。
- 主机流量同一时间只会发往一台物理网关
- 物理网关上配置相同的VIP和VMAC实现网关虚拟化

对于VARP说明，可以通过ip地址/mac地址确定唯一三层接口，但是三层接口可以被多个ip地址/mac地址定位到。对于虚拟网关，物理网关除了正常配置的ip与mac地址，还会配置一组相同的vip/vmac，主机将vip作为网关ip。对于物理网关：
- 只有当主机请求vip时才回复vmac
- 主动发送arp或者转发三层报文时，src mac使用的都是自己真实的router mac

对于主机而言，网关是虚拟的，所以使用虚拟网关ip进行通信
对于交换机而言，自己与外界通信需要使用自己真实的ip和mac, 这样对方才能根据真实的ip和mac定位到自己。

当MLAG交换机配置了VARP之后，host通过arp去请求VARP虚拟网关ip的mac地址，则MLAG-VARP交换机回应的自然是虚拟网关的mac;host发送icmp request给虚拟网关，虚拟网关使用真实的router-mac去回复。
