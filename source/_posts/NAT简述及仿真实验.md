---
title: NAT简述及仿真实验
date: 2021-09-29 13:52:24
tags: 
    - NAT
---

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [关于NAT的一些基本问题](#%E5%85%B3%E4%BA%8Enat%E7%9A%84%E4%B8%80%E4%BA%9B%E5%9F%BA%E6%9C%AC%E9%97%AE%E9%A2%98)
  - [什么是NAT?](#%E4%BB%80%E4%B9%88%E6%98%AFnat)
  - [NAT的工作方式](#nat%E7%9A%84%E5%B7%A5%E4%BD%9C%E6%96%B9%E5%BC%8F)
  - [NAT的弊端及处理方式](#nat%E7%9A%84%E5%BC%8A%E7%AB%AF%E5%8F%8A%E5%A4%84%E7%90%86%E6%96%B9%E5%BC%8F)
    - [ALG](#alg)
    - [ICMP报文的特殊处理](#icmp%E6%8A%A5%E6%96%87%E7%9A%84%E7%89%B9%E6%AE%8A%E5%A4%84%E7%90%86)
    - [IP分片的特殊处理](#ip%E5%88%86%E7%89%87%E7%9A%84%E7%89%B9%E6%AE%8A%E5%A4%84%E7%90%86)
<!--more-->
- [NAT的基本工作模型](#nat%E7%9A%84%E5%9F%BA%E6%9C%AC%E5%B7%A5%E4%BD%9C%E6%A8%A1%E5%9E%8B)
  - [传统NAT](#%E4%BC%A0%E7%BB%9Fnat)
    - [基本地址转换(Basic NAT)](#%E5%9F%BA%E6%9C%AC%E5%9C%B0%E5%9D%80%E8%BD%AC%E6%8D%A2basic-nat)
    - [NAPT(network address port translation)](#naptnetwork-address-port-translation)
    - [关于静态NAT和动态NAT](#%E5%85%B3%E4%BA%8E%E9%9D%99%E6%80%81nat%E5%92%8C%E5%8A%A8%E6%80%81nat)
  - [Bi-directional NAT or Two-Way NAT](#bi-directional-nat-or-two-way-nat)
  - [Twice NAT](#twice-nat)
- [NAT的一些应用方案](#nat%E7%9A%84%E4%B8%80%E4%BA%9B%E5%BA%94%E7%94%A8%E6%96%B9%E6%A1%88)
  - [NAT的双热机备份/NAT多出口策略](#nat%E7%9A%84%E5%8F%8C%E7%83%AD%E6%9C%BA%E5%A4%87%E4%BB%BDnat%E5%A4%9A%E5%87%BA%E5%8F%A3%E7%AD%96%E7%95%A5)
  - [NAT穿越技术](#nat%E7%A9%BF%E8%B6%8A%E6%8A%80%E6%9C%AF)
  - [NAT与VPN](#nat%E4%B8%8Evpn)
  - [NAT与路由的关系及一些处理细节](#nat%E4%B8%8E%E8%B7%AF%E7%94%B1%E7%9A%84%E5%85%B3%E7%B3%BB%E5%8F%8A%E4%B8%80%E4%BA%9B%E5%A4%84%E7%90%86%E7%BB%86%E8%8A%82)
  - [SONiC中NAT的实现](#sonic%E4%B8%ADnat%E7%9A%84%E5%AE%9E%E7%8E%B0)
  - [NAT-PT(V4/V6地址转换)](#nat-ptv4v6%E5%9C%B0%E5%9D%80%E8%BD%AC%E6%8D%A2)
- [GNS3上NAT的基本实验](#gns3%E4%B8%8Anat%E7%9A%84%E5%9F%BA%E6%9C%AC%E5%AE%9E%E9%AA%8C)
  - [静态NAT实验](#%E9%9D%99%E6%80%81nat%E5%AE%9E%E9%AA%8C)
  - [动态NAT实验](#%E5%8A%A8%E6%80%81nat%E5%AE%9E%E9%AA%8C)
  - [PAT实验](#pat%E5%AE%9E%E9%AA%8C)
- [参考资料](#%E5%8F%82%E8%80%83%E8%B5%84%E6%96%99)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# 关于NAT的一些基本问题
本文旨在对NAT有一个全局的了解，包括NAT技术的起因，技术的实现方式以及应用场景，技术存在的缺点以及解决方式，最后以几个基本的实验进行验证收尾，对于某些复杂的应用场景或技术细节，会简述而不深究，这些等到真实的应用中去打磨。

## 什么是NAT?
NAT的名字很准确，Network Address Translator(网络地址转换)，就是替换私网IP报文头部的地址信息，从而提供公网可达性和上层协议的连接能力。按照rfc2663的说法，NAT是从一个IP地址范围映射到另一个范围的方法，很显然，这种说法更加概括
NAT的使用场景：
- 私网到公网的翻译
- 重叠地址之间的翻译
- 保护内网IP设备

关于私网，RFC1918规定了三个保留地址段落：10.0.0.0-10.255.255.255；172.16.0.0-172.31.255.255；192.168.0.0-192.168.255.255。

## NAT的工作方式
NAT功能在网络出口路由器上使能，在报文离开私网进入公网时，将源IP替换为公网IP，报文从公网进入私网时，做相反的替换。NAT处理报文的几个关键特点：
- 网络被分为私网和公网两个部分，NAT网关设置在私网到公网的路由出口位置，双向流量必须都经过NAT网关
- NAT网关在两个访问方向上完成两次地址转换，出方向上做源信息替换，入方向上做目的地址替换
- *NAT网关的存在对通信双方是透明的*(这是NAT致力于达到的，但做的不好，因为有些上层协议会在内部携带IP地址信息)
- NAT网关为了实现双向翻译，需要维护一张关联表，把会话信息记录下来

## NAT的弊端及处理方式

NAT缓解公网IP不够用的同时带来了一些不好的影响，需要通过另一些技术去解决。
- NAT无法做到透明传输，ALG技术来解决
- NAT破环了IP协议架构端到端的通信模型，破坏了节点在通讯中的对等地位。NAT穿透技术进行解决
- NAT使IP会话的时效变短，因为IP和端口资源有限，而通信的需求无限，NAT网关会对关联表进行老化操作(特别是UDP通信)，这可能会导致用户可感知的连接中断，通过上层协议设置连接保活机制来解决
- 使依赖IP进行主机跟踪的机制失效，如：基于用户行为的日志分析，基于IP的用户授权，服务器连接设置同一时间只接收同一IP的有限访问，总之NAT屏蔽了通信的一端，把简单的事情复杂化了
- ICMP复用和解复用需要特殊处理，如果ICMP payload无法提供足够信息，解复用会失败
- IP分片，因为只有第一个分片有传输层信息，NAT很难识别后续分片与关联表的对应关系，需要特殊处理

### ALG
NAT工作在L3和L4，ALG(application level gateways)是用以解决NAT对应用层无感知的常用方式。NAT网关基于传输层端口信息来识别连接是否为已知的应用类型，在识别为已知应用时，会对其报文内容进行检查，当发现任何形式表达的IP地址和端口时，会把这些信息同步转换。

但是，应用层协议很多而且在不断变化，而设备中的ALG都是针对特定协议特定版本开发的，尽管Linux允许动态加载ALG特性，其管理维护成本依然很高。因此，ALG只能解决常用的用户需求，而且，有些报文从源端发出就已经加密，ALG也无能为力。

### ICMP报文的特殊处理
NAT网关通常采用五元组进行NAT映射，即源地址、源端口、IP协议类型、目的地址、目的端口。ICMP报文直接承载在IP报文之上，没有L4信息。以ping为例，对于ICMP请求报文，TYPE+CODE字段作为源端口，identifier作为目的端口记录，反之亦然。windows上发出的ICMP报文identifier字段全部是0x0400，处理上有些差别。
这段话来自华三的《NAT专题》，在思科的c3600上实验时，发现其只使用identifier标识一个ICMP会话，即ICMP的src port和dst port都是identifier的值。这里表示理解，只要NAT设备能够区别出不同内部主机发的报文即可，具体实现厂家可能有所差异。

### IP分片的特殊处理
当进行IP分片时，这些信息只有首片报文会携带(只有首片中有端口号，只有首片中有icmp的identifier)，后续分片报文依靠报文ID、分片标志位、分片偏移量依次关联到前一个分片。在PAT转换类型中，除了对IP地址进行处理，还会处理L4的端口号，ICMP报文头中的identifier字段信息。因此，除首片外的报文无法进行转换，需要特殊处理，有两种方式：
- 先缓存，等所有报文到达后，进行虚拟重组，再进行NAT转换，将转换后的报文再顺序发出
- 在首片到达并转换后，保存转换首片使用的IP以及identifier信息，在后续分片到达后使用同样表项进行转换。

# NAT的基本工作模型
NAT是网络地址转换的总称，基于不同的应用场景它有不同的配置。大的分类上可以分为传统NAT和two-way NAT以及twice NAT。

## 传统NAT
传统NAT只能由内网主机发起通信，是单向的。传统NAT有两种实现。

### 基本地址转换(Basic NAT)
NAT设备拥有多个公网ip，数量远少于内网主机的数量，当有内网主机访问外网时分配公网ip，访问结束时释放。NAT设备拥有公网IP地址的数目，应该根据网络高峰可能访问外网的内网主机数目的统计值来确定。

上面这段话是对rfc2663 4.1.1章节的一个翻译，结合实际的应用，Basic NAT就是只进行IP地址转换的NAT模式。

### NAPT(network address port translation)
一个外网地址可以同时分配给多个内网地址公用。该模式下，NAPT会转换源IP，源端口以及相关的ip，tcp/udp和icmp的header checksums.转换的id可以是 tcp/udp的端口号或者icmp的query ID。其转换的基本原理可形容为：
(iAddr;iPort) <——> (eAddr; ePort)
与此相关可称之为PAT(port address translation)模式，NAT使用最多的模式就是PAT模式。相反的不使用port进行地址转换称为NO-PAT(not port address translation)，而NAPT根据是否关心对端的信息可以分为下面两种：

1. endpoint-independent mapping(不关心对端地址和端口的转换模式)
NAT设备通过建立三元组(源地址、源端口号、协议类型)表项来进行地址分配和报文过滤。即，只要来自相同源地址和源端口号的报文，不论其目的地址是否相同，通过NAPT映射后，其源地址和源端口号都被转换成同一个外部地址和端口号，并且NAT设备允许外部网络的主机通过该转换后的地址和端口来访问这些内部网络的主机。这种模式可以很好的支持位于不同NAT设备之后的主机进行互访。

2. address and port-dependent mapping(关心对端地址和端口转换模式)
NAT设备通过建立五元组(源地址、源端口号、协议类型、目的地址、目的端口号)进行地址分配和报文过滤。即，对于来自相同源地址和源端口号的报文，若其目的地址和目的端口号不同，通过NAPT映射后，会被转换成不同的外部地址和端口号，并且NAT设备只允许这些目的地址对应的外部网络的主机才可以访问对应的内部主机。这种模式安全性好，但是不便于位于不同NAT设备之后的主机间的互访。

而通过对外部主机地址+端口的限制，又可以分为：
- 全锥形：对于inbound,只要NAT表项中存在，不关心src ip
- 限制锥形：对于inbound, 关心src ip
- 端口限制锥形: 对于inbound, 关心src ip + src port
- 对称形: 对于outbound和inbound, 只有src ip, src port, dst ip, dst port完全一致才认为是一个会话，否则创建新的表项
这些都是本质是NAT的应用，更加细粒度的进行控制过滤，是NAT的一种工作方式, 可以称之为*policy NAT*。

### 关于静态NAT和动态NAT
这是另一种分类方式，静态NAT即内外网地址信息静态绑定，是一一映射，这种很少使用，可用来隐藏私网ip和重叠地址网络的通信。动态NAT则是使用外网地址池，有资源回收机制，这种用法也少，地主家也不能买这么多公网IP地址。

## Bi-directional NAT or Two-Way NAT
外部网络能够有主动访问内网主机的机会，如给外网提供一台Web服务器，或是一台FTP服务器。实现双向NAT的关键在于DNS-ALG的引入，借助DNS-ALG,实现处于不同网络中的主机直接通过域名来相互访问。
静态NAT一般就是双向NAT.

## Twice NAT
相对于traditional NAT和bi-directional NAT中NAT设备只会对报文的源或者目的进行修改，twice NAT则对报文的src/dst同时进行修改。例如当外网主机使用的外网的ip已经分配给别的组织地址，这时需要将dst也改掉。这种方式常用于支持内网用户主动访问与之地址重叠(overlap)的外网资源。

当内网主机A向外网主机B发起通信时，但是内网中有主机D使用的是和B一样的IP地址（如之前ISP分配的，现在收回了；如同一公司的异地组网），如果A直接和B进行通信，那么报文会转发给D。A 通过发送DNS请求B的ip，DNS-ALG接收到之后给其分配一个可路由的内网地址C，现在A向C通信，NAT设备收到之后，对于src ip,按传统NAT转换，对于dest ip，将地址C改为B的地址，发给外网，收到之后，反之亦然。
Twice NAT would not be allowed to advertise local networks to the external network or vice versa.

NAT可分为SNAT、DNAT和twice NAT, 对于inside——>outside的流量，做SNAT，对于outside——>inside的流量，做DNAT。

# NAT的一些应用方案

## NAT的双热机备份/NAT多出口策略
与出口网关一样，NAT存在单点故障的问题。进行双热机备份当然是很好的方式。双热机备份分为对称式和非对称式，对称式即进出流量只能走相同的设备，非对称式则没有这个要求，可以进行负载均衡。这里简单列举一下对称式的实现方式：
- 利用VRRP实现流量切换
- 利用动态路由实现流量切换

## NAT穿越技术
这里只是插个眼，不做深入研究，NAT穿越技术有：
- ALG
- 探针技术STUN与TURN
- 中间件技术
- 中继代理技术
- 特定协议的自穿越技术

## NAT与VPN
常见的VPN有：GRE、L2TP、IPsec、SSL VPN等。NAT在工作过程中会修改L3和L4的信息，在分析VPN与NAT共存时，首先需要分析该VPN隧道的封装方式，看有没有传输层端口，其次要分析VPN隧道的协商过程中是否使用报文的IP地址。具体分析在这里不展开了，说个结论：SSL VPN与L2TP VPN与NAT可以天然共存，IPsec VPN在部分模式下可与NAT共存，而GRE无法穿越NAT.

## NAT与路由的关系及一些处理细节
对cisco的实现，参见下图：
![](https://rancho333.github.io/pictures/cisco_nat_seq.png)
对于inside->outside的流量，NAT转化发生在routing之后；对于outside->inside的流量，NAT转换发生在路由之前.所以自cisco的实现中，NAT与路由的关系只取决于流量的方向，通过inside/outside修饰接口分割出两个区域，通过source/dest表明流量的方向。

Cisco会在特定的时间将“一条NAT映射策略”安装到系统的inside NAT表或者outside NAT表中，对于从网口进入的数据包，会根据网口是inside还是outside去匹配inside NAT表或者outside NAT表中的NAT规则，仅此而已。不管是inside NAT表还是outside NAT表，都各有两张，一张是SNAT表，另一张是DNAT表。对于每一个数据包，都要用源IP地址去查询SNAT表，用目标IP地址去查询DNAT表。这在下面的静态NAT实验中将有很好的体现。

对Linux的实现，参见下图：
![](https://rancho333.github.io/pictures/linux_nat_seq.jpg)
Linux中并没有将NAT应用于接口的说法，NAT的配置是全局的。此时接口就是一个match，写match/target去匹配执行就好。SNAT位于post-routing域，DNAT位于pre-routing域。SNAT指的是内网发往外网的流量修改src ip, DNAT指的是外网发往内网的流量修改dest ip。Linux中的NAT是基于五元组的，也就是NAT结果和一个流(conntrack)关联在一起。

Linux的nat中，待转换的IP地址是一个match，因此不管是一对一的转换还是一对多的转换，原理都是一样的。Linux并不区分静态转换和动态转换。在内核中，永远都不会出现所谓的NAT映射表，iptables添加的NAT规则不会生成映射，数据包进入匹配nat成功，也不会生成映射，nat结果仅仅存在于conntrack中作为tuple的一部分体现。

Linux的nat查询对于第一个包是逐条匹配iptables nat表规则，对于后续的包，则转化为针对五元组的conntrack哈希查询。

借用一下SONiC中对NAT的配置：
![](https://rancho333.github.io/pictures/sonic_nat_config.png)
命令行里面默认的NAT类型是dnat，这里不理解，等待后续使用去验证。这个NAT条目只有外网发到内网的流量才会触发呀？这不符合NAT使用最多的场景呀！

思科强调使用者得使用域，Linux强调技术本身的合理性.

## SONiC中NAT的实现
[SONiC中NAT](https://github.com/Azure/SONiC/blob/master/doc/nat/nat_design_spec.md)是SONiC对NAT的设计文档。鉴于TH4不支持NAT，SONiC的上NAT的实验后续再进行。

## NAT-PT(V4/V6地址转换)
IPv4与IPv6的过渡技术有双栈、隧道和翻译。其中翻译就是使用的NAT-PT技术。这里插个眼，后续有需要在深入。

# GNS3上NAT的基本实验
以上都是看的一些文档资料，实验看看效果才好，实验环境为GNS3+c3600，做三个基本场景的实验：
- 静态NAT实验
- 动态NAT实验
- PAT实验

## 静态NAT实验
基本命令为`ip nat inside static a b`, 系统会将a——>b的源地址转换加入到inside的SNAT表中，同时将b——>a的目的地址转换加入到outside的DNAT表中。针对后面所有的数据包，不管是内部发起的，还是外部发起的，都会根据接口使能的inside nat还是outside nat来查表匹配。
拓扑图如下：
![](https://rancho333.github.io/pictures/topo_nat.png)
配置如下：
```
R1:
interface Ethernet0/0
 ip address 192.168.1.2 255.255.255.0
router ospf 1
 network 192.168.1.0 0.0.0.255 area 0

R2:
interface Ethernet0/0
 ip address 192.168.1.1 255.255.255.0
 ip nat inside
interface Ethernet0/1
 ip address 202.100.10.1 255.255.255.0
 ip nat outside
router ospf 1
 network 192.168.1.0 0.0.0.255 area 0
 network 202.100.10.0 0.0.0.255 area 0
ip nat inside source static 192.168.1.2 202.100.10.3

R3:
interface Ethernet0/1
 ip address 202.100.10.2 255.255.255.0
router ospf 1
 network 202.100.10.0 0.0.0.255 area 0
```
在R1上ping R3，分别在R2的左右两侧进行抓包，左侧为NAT之前的报文：
![](https://rancho333.github.io/pictures/before_nat.png)
右侧为NAT之后的报文，发现src ip已经发生改变：
![](https://rancho333.github.io/pictures/after_nat.png)

注意我们只配置了`ip nat inside source`, 即我们只在inside接口上使能了SNAT，但是对于R4返回的数据包，是在outside接口上做DNAT，我们并没有做这个配置，这是因为cisco自动进行了这种关联，在命令行中我们也会发现cisco在outside上只有`ip nat outside source`。从NAT转换表中我们也可以看出这种自动关联的动作。
![](https://rancho333.github.io/pictures/inside_source.png)
在ping动作之前，表中其实只有第二行，第一行的icmp是ping之后流量触发时建立，发现多了outside global和outside local字段。

`ip nat outside source`表示从outside发往inside的报文做SNAT。进一步的总结下，cisco NAT的四种类型：
1. 从inside到outside时做SNAT
2. 从inside到outside时做DNAT
3. 从outside到inside时做SNAT
4. 从outside到inside时做DNAT
其中1,4是成对的，2,3是成对的。即配1了4会自动部署，配3了2会自动部署，验证一下2,3的成对关系：
```
ip nat outside source static 202.100.10.2 192.168.1.3
```
然后使用R3 ping R1，抓包结果为：
![](https://rancho333.github.io/pictures/outside_ping.png)
可以看到R1给192.168.1.3回了icmp reply报文，但是R3并没有收到地址转换后的报文。

NAT表项转换为：
![](https://rancho333.github.io/pictures/outside_dest.png)
同样第一行为我们配置的，第二行为流量触发的，可以发现增加了`inside local`和`inside local`

这里需要结合cisco中NAT与路由的关系来回答这个问题：
显然这里是步骤`2`出了问题，inside->outside流量是在路由之后完成的，即R1给R3的icmp reply报文是针对192.168.1.3做的路由，R3自然收不到报文
所以需要在R2上配置一条静态路由：
```
ip route 192.168.1.3 255.255.255.255 202.100.10.2
```
或者在outside上面配置source时添加add-route选项：
```
ip nat outside source static 202.100.10.2 192.168.1.3 add-route # add-route会给prefix 192.168.1.3添加next-hop为202.100.10.2
```
*说明一下：这里的SNAT单纯表示替换source ip，DNAT单纯表示替换dest ip，SNAT和DNAT在Linux中与路由的关系在这里不适用*

## 动态NAT实验

对于动态NAT，配置完命令后系统不会添加任何NAT规则只有当某一个包匹配到了ACL，要引发NAT时，系统会动态的从pool中选取一个要转换的IP地址，加入到inside的SNAT表项中，同时针对反方向的目的地址转换规则将其加入到outside的DNAT表项中。
因此，cisco的动态NAT是单向的，因为反向的数据包进入时不会匹配到ACL，不会引发NAT规则，也就不会生成任何NAT表项。在此例中，如果R3先ping R1是不通的，必须先让R1 ping R3生成NAT表项后，双方才能互通。

实验拓扑图如下：
![](https://rancho333.github.io/pictures/topo_d_nat.png)

本次实验通过配置一个NAT地址池，让R1、R4与R3通信时发生NAT转换。设备配置如下：
```
R1：
interface Ethernet0/0
 ip address 192.168.1.2 255.255.255.0
ip route 0.0.0.0 0.0.0.0 192.168.1.1            #R1模拟私网主机，配置网关

R2:
interface Ethernet0/0
 ip address 192.168.1.1 255.255.255.0
 ip nat inside                  # 配置NAT inside域
interface Ethernet0/1
 ip address 202.100.10.1 255.255.255.0
 ip nat outside                 # 配置NAT outside域
interface Ethernet0/2
 ip address 192.168.2.1 255.255.255.0
 ip nat inside                  # 配置NAT inside域
ip nat pool rancho-test 202.100.10.3 202.100.10.10 prefix-length 24   # 设置NAT地址池
ip nat inside source list 1 pool rancho-test                          # 设置地址池与ACL的映射  
access-list 1 permit 192.168.2.2                                      # 设置ACL规则，标准acl只匹配source
access-list 1 permit 192.168.1.2                                    
access-list 1 deny any

R3：
interface Ethernet0/1
 ip address 202.100.10.2 255.255.255.0
ip route 0.0.0.0 0.0.0.0 202.100.10.1

R4:
interface Ethernet0/2
 ip address 192.168.2.2 255.255.255.0
ip route 0.0.0.0 0.0.0.0 192.168.2.1
```

在R2左右两侧抓包，对应为NAT转换前后的包，对于R1 ping R3的抓包：
![](https://rancho333.github.io/pictures/r1_d_nat.png)
配置的NAT地址池从202.100.10.3开始，第一个命中NAT规则的分配start ip。

对于R4 ping R3的抓包：
![](https://rancho333.github.io/pictures/r4_d_nat.png)
后续命中NAT规则的依次分配，对于192.168.2.2分配外网IP：202.100.10.4

在R2上查看生成的NAT转换表项(在ping之前为空，只有当命中ACL规则，触发NAT转换才会生成，这是和静态NAT表项的区别)：
![](https://rancho333.github.io/pictures/nat_tran.png)
转换表项和抓包的对比是吻合的。

查看下R2上关于NAT的统计数据以及使能的NAT的配置：
![](https://rancho333.github.io/pictures/nat_stat.png)

## PAT实验
复用`动态NAt实验`的拓扑和基本配置，只需要将`R2`上的NAT配置做一些修改，使R1、R4访问R3时使用R2上右侧端口的IP。R2上的配置修改如下：
```
- ip nat pool rancho-test 202.100.10.3 202.100.10.10 prefix-length 24   # 设置NAT地址池
- ip nat inside source list 1 pool rancho-test                          # 设置地址池与ACL的映射
+ ip nat inside source list 1 interface Ethernet0/1 overload            # ACL 1的流量复用 0/1端口的IP地址
```
同样在R2左右两侧抓包，对应PAT转换前后的包，对于R1 telnet R3，发出去的包为：
![](https://rancho333.github.io/pictures/r1_pat_to.png)
R3对R1的返回包为：
![](https://rancho333.github.io/pictures/r1_pat_from.png)

对于R4 telnet R3, 发出去的包为:
![](https://rancho333.github.io/pictures/r4_pat_to.png)
R3对R4的返回包为：
![](https://rancho333.github.io/pictures/r4_pat_from.png)

查看R2上的NAT转换表，与抓包内容符合：
![](https://rancho333.github.io/pictures/pat_tran.png)

这里可以发现PAT转换前后src port并没有发生改变(直接使用的就是源TCP包中的port)，在命令里面也没有看到配置port范围的命令，不知道这是不是思科的特殊实现, 如果NAT设备发现相同的端口再处理？*此处存疑，思科肯定会有处理的方式*

对于ICMP报文的特殊处理，以R1 ping R3为例，ICMP request报文为：
![](https://rancho333.github.io/pictures/r1_pat_ping_to.png)
ICMP reply报文为：
![](https://rancho333.github.io/pictures/r1_pat_ping_from.png)
R2上的NAT转换表为：
![](https://rancho333.github.io/pictures/pat_tran_ping.png)
这里这看到在PAT模式中，NAT设备通过ICMP报文中的identifier字段来标识一个ICMP的NAT转换。

# 参考资料
[rfc2663](https://datatracker.ietf.org/doc/html/rfc2663)
[rfc3022](https://datatracker.ietf.org/doc/html/rfc3022)
[rfc4787](https://datatracker.ietf.org/doc/html/rfc4787)
[彻底理解Cisco NAT内部的一些事](https://blog.csdn.net/armlinuxww/article/details/113541634)
[H3C NAT配置](http://www.h3c.com/cn/d_201904/1175248_30005_0.htm#_Toc7355633)
[CONFIGURING NAT OVERLOAD ON A CISCO ROUTER](https://www.firewall.cx/cisco-technical-knowledgebase/cisco-routers/260-cisco-router-nat-overload.html)
[SONiC NAT design](https://github.com/Azure/SONiC/blob/master/doc/nat/nat_design_spec.md#221-snat-and-dnat)