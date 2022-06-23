---
title: mpls学习
date: 2021-02-09 10:27:51
tags:
    - 通信协议
---

# MPLS简介
MPLS(multiprotocol label switching，多协议标签交换)起源于IPv4，最初是为了提高转发速度而提出的（早期路由是只能由软件处理的），其核心技术可扩展到多种网络协议，包括IPv6，IPX(internet packet exchange，网际报文交换)和CLNP(connectionless network protocol,无连接网络协议)等。MPLS中的*M*指的就是支持多种网络协议。

<!--more-->
# 概念说明

## 转发等价类
MPLS作为一种分类转发技术，将具有相同转发处理方式的分组归位一类，称为FEC(forwarding equivalence class，转发等价类)。相同FEC的分组在MPLS中将获得完全相同的处理。
FEC的划分方式非常灵活，可以是源地址、目的地址、源端口、目的端口、协议类型或VPN等为划分依据的任意组合。例如，在传统的采用最长匹配算法的IP转发中，到同一个目的地址的所有报文就是一个FEC。

## 标签
标签是一个长度固定，仅具有本地意义的短标识符，用于唯一标识一个分组所属的FEC。一个标签只能代表一个FEC。标签长度为4个字节，结构如下：

![](https://rancho333.gitee.io/pictures/mpls_packet.png)

字段解释如下：

| 字段 | 解释 |
| :--- | :--- |
| Label | 标签字段，长度为20bits，用来标识一个FEC |
| Exp | 3bits, 保留， 协议中没有明确规定， 通常用作CoS |
| S | 1bit, MPLS支持多重标签，值为1时表示为最底层标签 |
| TTL| 8bits, 和IP分组中的TTL意义相同，用来防止环路 |

如果链路层协议具有标签域，如ATM的VPI/VCI,则标签封装在这些域中；否则，标签封装在链路层头和网络层数据之间的一个垫层。这样，任意链路层都能够支持标签。下图是标签在分组中的封装位置。

![](https://rancho333.gitee.io/pictures/mpls_packet_location.png)

## 标签交换路由器
LSR(label switching router,标签交换路由器)是MPLS网络中的基本单元，所有LSR都支持MPLS技术。

## 标签交换路径
一个转发等价类在MPLS网络中经过的路径称为LSP(label switched path，标签交换路径)。在一条LSP上，沿数据传送的方向，相邻的LSR分别称为上游LSR和下游LSR。如下图所示，R2是R1的下游LSR，相应的R1是R2的上有LSR。

![](https://rancho333.gitee.io/pictures/mpls_lsr.png)
LSP在功能上与ATM和帧中继(frame relay)的虚电路相同，是从MPLS网络的入口到出口的一个单向路径，LSP中的每个节点由LSR组成。

## 标签分发协议
LDP(label distribution protocol，标签分发协议)是MPLS的控制协议，它相当于传统网络中的信令协议，负责FEC的分类、标签的分配以及LSP的建立和维护等一系列操作。MPLS可以使用多种标签发布协议，包括专为标签发布而制定的协议，例如：LDP、CR-LDP(constraint-based routing using LDP,基于约束路由的LDP)；也包括现有协议扩展后支持标签发布的，例如：BGP、RSVP(resource reservation protocol，资源预留协议)。同时，还可以手工配置静态LSP。
LDP有两个重要的作用：
1. 给本地路由信息分配标签，进行绑定生成LIB表
2. 传递LSR之间的绑定信息，生成LFIB表

## LSP隧道技术
MPLS支持LSP隧道技术。一条LSP的上游LSR和下游LSR，尽管他们之间的路径可能并不在路由协议所提供的路径上，但MPLS允许在他们之间建立一条新的LSP，这样，上游LSR和下游LSR分别就是这条LSP的起点和终点。这时，上游LSR和下游LSR间就是LSP隧道，它避免了采用传统的网络层封装隧道。如上图中LSP `R2->R21->R22->R3`就是R2、R3间的一条隧道。如果隧道经由的路由与逐跳从路由协议中取得的路由一致，这种隧道就称为逐跳路由隧道(Hop by Hop routed tunnel)，否则称为显示路由隧道(explicitly routed tunnel)。

## 多层标签栈
如果分组在超过一层的LSP隧道中传送，就会有多层标签，形成标签栈(label stack)。在每一隧道的入口和出口，进行标签的入栈(push)和出栈(pop)操作。标签按照`后进先出`(last-in-first-out)方式组织标签，MPLS从栈顶开始处理标签。
MPLS对标签栈的深度没有限制，若一个分组的标签深度为m，则位于栈底的标签为1级标签，位于栈顶的标签为m级标签。未压入标签的分组可看作标签栈为空(即标签栈深度为0)的分组。

# MPLS体系结构 

## MPLS网络结构
如下图所示，MPLS网络的基本构成单元是LSR，由LSR构成的网络称为MPLS域。位于MPLS域边缘、连接其它用户网络的LSR称为LER(label edge router, 边缘LSR)，区域内部的LSR称为核心LSR。核心LSR可以是支持MPLS的路由器，也可以是由ATM交换机等升级而成的ATM-LSR。域内部的LSR之间使用MPLS通信，MPLS域的边缘由LER与传统IP技术进行适配。
分组在入口LER被压入标签后，沿着由一系列LSR构成的LSP传送，其中，入口LER被称为ingress，出口LER被称为egress，中间的节点则称为transit。

![](https://rancho333.gitee.io/pictures/mpls_network.png)
结合上图简要介绍MPLS基本工作过程：
1. 首先，LDP和传统路由协议(如OSPF、ISIS等)一起，在各个LSR中为有业务需求的FEC建立路由表和LIB(label information base，标签信息表)
2. 入口LER接收分组，完成第三层功能，判定分组所属的FEC，并给分组加上标签，形成MPLS标签分组
3. 接下来，在LSR构成的网络中，LSR根据分组上的标签以及LFIB(label forwarding information base，标签转发表)进行转发，不对标签分组进行任何第三层处理
4. 最后，在MPLS出口LER去掉分组中的标签，继续进行后面的IP转发

MPLS并不是一种业务或者应用，它本质上是一种隧道技术，也是一种将标签交换转发和网络层路由技术集于一身的路由与交换技术平台，这个平台不仅支持多种高层协议与业务，而且，在一定程度上可以保证信息传输的安全性。

## MPLS节点结构

![](https://rancho333.gitee.io/pictures/mpls_node.png)

如上图所示，MPLS节点由两部分组成：
- 控制平面(control plane)：负责标签的分配、路由的选择、标签转发表的建立、标签交换路径的建立、拆除等工作
- 转发平面(forwarding plane)：依据标签转发表对收到的分组进行转发

对于普通的LSR，在转发平面只需要进行标签分组的转发，需要使用到LFIB。对于LER，在转发平面不仅需要进行标签分组的转发，也需要进行IP分组的转发，所以既会使用到LFIB，也会使用到FIB表。

## MPLS与路由协议
LDP通过逐跳方式建立LSP时，利用沿途各LSR路由转发表中的信息来确定下一跳，而路由转发表中的信息一般是通过IGP、BGP等路由协议收集的。LDP并不直接和各种路由协议关联，只是间接使用路由信息。另一方面，通过对BGP、RSVP等已有协议进行扩展，也可以支持标签的分发。
在MPLS的应用中，也可能需要对某些路由协议进行扩展。例如，基于MPLS的VPN应用需要对BGP进行扩展，使BGP能够传播VPN的路由信息；基于MPLS的TE(traffic engineering,流量工程)需要对OSPF或IS-IS协议进行扩展，以便携带链路状态信息。

## MPLS的应用
最初，MPLS技术结合了二层交换与三层路由技术，提高了路由查找速度。但随着ASIC的发展，路由查找速度已经不成为阻碍网络发展的瓶颈。这使得MPLS在提高转发速度方面不具备明显的优势。
但由于MPLS结合了IP网络强大的三层路由功能和传统二层网络高效的转发机制，在转发平面采用面向连接的方式，与现有二层网络转发方式非常相似，这些特点使得MPLS能够很容易的实现IP与ATM、帧中继等二层网络的无缝融合，并为QoS、TE、VPN等应用提供更好的解决方案。

### 基于MPLS的VPN
传统的VPN一般是通过GRE、L2TP、PPTP等隧道协议来实现私有网络间数据流在公网上的传送，LSP本身就是公网上的隧道，因此，用MPLS来实现VPN有天然的优势。基于MPLS的VPN就是通过LSP将私有网络的不同分支连接起来，形成一个同一的网络。基于MPLS的VPN还支持对不同的VPN间的互通控制。
![](https://rancho333.gitee.io/pictures/mpls_vpn.png)

上图是基于MPLS的VPN的基本结构
- CE可以是路由器，也可以是交换机或主机
- PE位于骨干网络
PE负责对VPN用户进行管理，建立各PE间的LSP连接，同一VPN用户各分支间路由分派，PE间的路由分派通常是用LDP或扩展的BGP协议实现。
基于MPLS的VPN支持不同分支间的IP地址复用，并支持不同VPN间互通。与传统的路由相比，VPN路由中需要增加分支和VPN的标识信息，这就需要对BGP协议进行扩展，以携带VPN路由信息。