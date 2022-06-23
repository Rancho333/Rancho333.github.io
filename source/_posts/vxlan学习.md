---
title: vxlan学习
date: 2021-02-03 10:24:44
tags:
    - vxlan
    - 通信协议
---

# 写在前面

vxlan是overlay层的应用，vlan是underlay层的应用。这篇文档是vxlan的学习文档，在学习vxlan之前，会简单介绍下vlan，之后进入vxlan学习。学习完成后，应该搞明白以下的几个问题：
<!--more-->
- 什么是vxlan
- vxlan解决了什么问题，应用场景是什么
- vxlan报文的封装格式是什么样的
- 什么是VTEP和VNI
- 哪些VTEP之间需要建立vxlan隧道
    - 什么是`同一大二层域`
- vxlan隧道是如何建立的
    - 如何确定报文属于那个BD，哪些报文进入vxlan隧道
    - 如何确定报文走那条隧道
- 什么是vxlan二层网关和三层网关
- 什么是vxlan集中式网关与分布式网关
    - 集中式网关中同子网互通流程是怎样的
    - 集中式网关中不同子网互通流程是怎样的
- 什么是BGP EVPN
    - 分布式网关中报文的转发流程是怎样的

# vlan介绍

VLAN(virtual local area network)即虚拟局域网，是将一个物理的LAN在逻辑上划分多个广播域的通信技术。根据IEEE 802.1Q协议规定，在以太网数据帧的目的MAC地址和源MAC地址字段之后、协议字段之前加入4个字节的VLAN tag，用以标识VLAN信息，VLAN数据帧格式如下图所示。

![](https://rancho333.gitee.io/pictures/vlan_frame.png)

对于交换机而言，其内部处理的数据帧都带有VLAN tag，现网中交换机连接的设备只会接收Untagged帧。交换机需要有识别Untagged帧并在收发时给帧添加、剥离VLAN标签的能力，交换机间的接口需要有同时识别和发送多个vlan数据帧的能力。

根据接口对象和收发数据帧处理的不同，下面介绍4中链路类型，用以适应不同的连接和组网：

- Access接口：一般用于交换机与用户终端相连。Access接口大部分情况只能收发Untagged帧，且只能为Untagged帧添加唯一的VLAN tag。
- Trunk接口：一般用于交换机之间相连。允许多个VLAN的帧带tag通过，但只允许一个VLAN的帧(默认vlan)从该类型接口上发出时不带tag。
- Hybridd接口：Access和Trunk的混合。
- 使用QinQ(802.1Q-in-802.1Q)协议，一般用于私网与公网之间的连接，也被称为Dot1q-tunnel接口，它可以给vlan加上双层Tag，最多支持4094*4094个VLAN。

下面介绍一下vlan划分的方式及使用场景：

| 划分方式 | 简介 | 适用场景 |
| :--- | :--- | :--- |
| 基于接口 | 根据交换机的接口来划分vlan | 使用与任何大小但是位置比较固定的网络 |
| 基于MAC地址 | 根据数据帧的源MAC地址来划分VLAN | 适用于位置经常移动但网卡不经常更换的小型网络 |
| 基于子网 | 根据数据帧中的源IP地址和子网掩码来划分VLAN| 适用于安全需求不高、对移动性和简易管理需求比较高的场景 |
| 基于网络层协议 | 根据数据帧所属的协议(族)类型及封装格式 | 适用于需要同时运行多协议的网络 |
| 基于匹配策略 | 根据配置的策略划分VLAN,能实现上述的多种组合 | 使用与需求比较复杂的环境 | 

两个概念，vlan的透传和终结，vlan的透传就是某个vlan不仅在一台交换机上有效，它还要通过某种方式延伸到别的以太网交换机上，在别的设备上照样有效，vlan的透传可以使用802.1Q协议，trunk链路上使用。vlan的终结意思相对，某个vlan的有效域不能再延伸到别的设备，或者不能通过某条链路延伸到别的设备，可以使用pvlan技术实现，主要在vlan数据出端口到终端设备，或者上三层转发时剥离。这两者的本质就是保留vlan tag和去除vlan tag。

# vxlan学习

## 什么是vxlan

vxlan(virtual extensible local area network)虚拟扩展局域网，是有IETF定义的NVO3(network virtualization over layer 3)标准技术之一。vxlan的本质是一种隧道技术，将L2的以太帧封装到UDP报文中在L3网络中传输。虽然从名字上看，vxlan是vlan的一种扩展协议，但是vxlan构建虚拟隧道的本领已经和vlan迥然不同了。vxlan报文格式如下图所示。

![](https://rancho333.gitee.io/pictures/vxlan_tag.png)

如上图所示，VTEP对VM发送的原始以太帧（original L2 frame）进行了如下的封装：

| 封装 | 说明 |
| :--- | :--- |
| vxaln header | 增加vxlan头(8字节),其中24bits的VNI用来标识vxlan|
| udp header | vxlan头和原始以太帧一起作为UDP的数据。UDP中，目的端口号(vxlan port)固定为4789 |
| outer ip header | src ip为源VM所属VTEP的IP地址，目的IP地址为目的VM所属VTEP的IP地址 |
| outer mac header | src mac为源VM所属VTEP的mac地址，目的mac地址为到达VTEP的路径的下一跳设备的mac地址 |

## vxlan的应用场景

vxlan的主要应用场景是数据中心。vxlan可以满足数据中心的三个关键需求：
1. 数据中心服务器侧虚拟化后出现了虚拟机动态迁移，要求提供一个无障碍接入的网络
2. 数据中心规模庞大，租户数量激增，要求网络提供隔离海量租户的能力
3. 针对虚拟机规模受网络规格限制的解决方案。对接入交换机，MAC地址规格需求极大降低，但是对核心网关要求极高。两个vxlan可以具有相同的MAC地址，但在一个vxlan内不能有重复的mac地址

对于虚拟机动态迁移，不仅虚拟机的IP地址不变，而且虚拟机的运行状态也必须保持原状（如TCP会话状态），所以虚拟机动态迁移只能在一个二层域中进行。vxlan可以将整个数据中心基础网络虚拟化成一台巨大的“二层交换机”，所有的服务器都连结在这台二层交换机上。underlay网路具体如何转发，服务器完全无需关心。将虚拟机从“二层交换机”的一个端口换到另一个端口，完全无需变更IP地址。
使用这种理念的技术协议，除了vxlan外，还有NVGRE、STT等。

传统网络中，vlan数量只有4000个左右，vxlan理论上可以支持16M的vxlan段，从而满足大规模不同网络之间的标识、隔离需求。

## vxlan的隧道是如何建立的

### vxlan中的VTEP和VNI

下面了解一下vxlan网络模型以及一些常见的概念，如下图所示，两台服务器之间通过vxlan的网络进行通信。

![](https://rancho333.gitee.io/pictures/vxlan_network_module.png)

如上图所示，vxlan报文在vtep两端有一个封装和解封装的操作。

VTEP(vxlan tunnel endpoints, vxlan隧道端点)是vxlan网络的边缘设备，是vxlan隧道的起点个终点，vxlan对用户原始数据帧的封装和解封装均在VTEP上进行。VTEP既可以是一台独立的网络设备，也可以是服务器中的虚拟交换机。

VNI(vxlan network identifier, vxlan网络标识符)是一种类似VLAN ID的用户标识，一个VNI代表了一个租户，属于不同的VNI虚拟机之间不能直接进行二层通信。在分布式网关的部署场景下，VNI可以分为二层VNI和三层VNI：
- 二层VNI是普通VNI，以1:1方式映射到广播域BD，实现vxlan报文同子网的转发
- 三层VNI和VPN实例进行关联，用于vxlan报文跨子网的转发，参见EVPN相关

### 那些VTEP之间需要建立vxlan隧道

连接在不同的VTEP上的VM之间如果有“大二层”互通的需求，这两个VTEP之间就需要建立vxlan隧道。换言之，同一个大二层域内的VTEP之间都需要建立VTEP隧道。

`同一个大二层域`类似于传统网络中VLAN(虚拟局域网)的概念，在vxlan中它有另一个名字，叫做Bridge-Domain，简称BD。vlan是通过vlan id来标识的，BD则是通过VNI来标识的，BD与VNI是1:1的映射关系。以华为CloudEngine系列交换机而言，可以如下配置：
```
bridge-domain 10        #表示创建一个大二层广播域，编号是10
  vxlan vni 5000        #表示在BD下，指定与之关联的VNI是5000
```
有了映射之后，进入VTEP的报文就可以根据自己所属的BD来确定报文封装时添加的VNI。那么怎么确定报文属于那个BD呢？

VTEP只是交换机承担的一个角色，只是交换机功能的一部分。并非所有进入交换机的报文都会走Vxlan隧道（也可能报文就是走普通二三层转发流程）。

在vlan的接口对报文处理的流程是：
1. 根据配置来检查哪些报文时允许通过的
2. 判断对检查通过的报文做怎样的处理

在vxlan网络中，VTEP上的接口承担类似的任务，这个接口是个叫做`二层子接口`的逻辑接口。二层子接口对报文的处理流程是：
1. 根据配置来检查哪些报文需要进入vxlan隧道
2. 判断对检查通过的报文做怎样的处理

在二层子接口上，可以根据需要定义不同的流封装类型（类似传统网络中不同的接口类型），一般有dot1q、untag、qinq和default四种类型：
- dot1q:对于带一层vlan tag的报文，该类型的接口只接受与指定vlan tag匹配的报文；对于带有两层vlan tag的报文，该类型接口只接收外层vlan tag与指定VLAN tag匹配的报文
- untag：只接收不带vlan tag的报文
- qinq：只接收带有指定两层vlan tag的报文
- default: 允许接口接收所有的报文，不区分报文中是否带有vlan tag。不论是对原始报文进行vxlan封装还是解封装，该类型接口都不会对原始报文进行任何vlan tag处理，包括添加、替换和剥离。

vxlan隧道两端二层子接口的配置并不一定是完全相等的。正因为这样，才可能实现属于同一网段但是不同vlan的两个vm通过vxlan隧道进行通信。

除二层子接口外，还可以将vlan作为业务接入点。将vlan绑定到BD后，加入该vlan的接口即为vxlan业务接入点，进入接口的报文由vxlan隧道处理。

只要将二层子接口加入指定的BD，然后根据二层子接口上的配置，设备就可以确定报文属于那个BD啦！

### vxlan隧道是怎么建立的

两种方式，手动或自动。

#### 手动建立

这种方式需要用户手动指定vxlan隧道源IP为本端VTEP的IP、目的IP为对端VTEP的IP，也就是人为在本端VTEP和对端VTEP之间建立静态VXLAN隧道。

以华为CloudEngine系列交换机为例，在NVE(network virtualization edge)接口下完成配置，配置举例如下：
```
interface Nve1          #创建逻辑接口NVE 1
    source 1.1.1.1          #配置源VTEP的IP地址（推荐使用Loopback接口的IP地址）
    vni 5000 head-end peer-list 2.2.2.2
    vni 5000 head-end peer-list 2.2.2.3
```
两条vni命令表示VNI 5000的对端VTEP有两个。根据这两条配置，VTEP上会生成如下所示的一张表：
```
<HUAWEI> display vxlan vni 5000 verbose
BD ID : 10
State : up
NVE : 288
Source Address : 1.1.1.1
Source IPv6 Address : -
UDP Port : 4789
BUM Mode : head-end
Group Address : -
Peer List : 2.2.2.2 2.2.2.3
IPv6 Peer List : -
```
根据这张表的Peer List，本端VTEP就可以知道属于同一BD的对端VTEP有哪些，这也决定了同一大二层广播域的范围。当VTEP收到BUM(broadcast&unknown-unicast&multicast)报文时，会将报文复制并发送给peer list中所列的所有对端VTEP（类似广播报文在VLAn内广播）。因此，这张表也被称为"头端复制列表"。当VTEP收到一致单播报文时，会根据VTEP上的MAC表来确定报文要从那条vxlan隧道走。而此时Peer List中所列出的对端，则充当了MAC表中"出接口"的角色。

#### 自动建立

自动建立则需要借助EVPN(Ethernet VPN)协议。

#### 如何确定报文走那条隧道

参见`vxlan网络中报文时如何转发的`章节。

## vxlan网关有哪些种类

### vxlan二层网关与三层网关

和vlan类似，不同VNI之间的主机，以及vxlan网络和非vxlan网络中的主机不能直接相互通信，为了满足这些通信需求，vxlan引入了vxlan网关的概念。vxlan网关分为二层网关和三层网关：
- 二层网关：用于终端接入vxlan网络，也可用于同一vxlan网络的子网通信
- 三层网关：用于vxlan网络中跨子网通信以及访问外部网络

具体说明下。
vxlan三层网关。用于终结vxlan网络，将vxlan报文转换成传统三层报文发送至IP网络，适用于vxlan网络内服务器与远端之间的三层互访；同时也作不同vxlan网络互通，如下图所示.当服务器访问外部网络时，vxlan三层网关剥离对应vxlan报文封装，送入IP网络；当外部终端访问vxlan内的服务器时，vxlan根据目的IP地址所属vxlan及所属的VTEP，加上对应的vxlan报文头封装进入vxlan网络。vxlan之间的互访流量与此类似，vxlan网关剥离vxlan报文头，并基于目的IP地址所属vxlan及所属的VTEP，重新封装后送入另外的vxlan网络。
![](https://rancho333.gitee.io/pictures/vxlan_l3_gateway.png)

vxlan二层网关。用于终结vxlan网络。将vxlan报文转换成对应的传统二层网络送到传统以太网路，适用于vxlan网络内服务器与远端终端或远端服务器的二层互联。如在不同网络中做虚拟机迁移时，当业务需要传统网络中服务器与vxlan网络中服务器在同一个二层中，此时需要使用vxlan二层网关打通vxlan网络和二层网络。如下图所示。vxlan10网络中的服务器要和IP网络中vlan100的业务二层互通，此时就需要通过vxlan的二层网关进行互联。vxlan10的报文进入IP网络的流量，剥离vxlan报文头，根据vxlan的标签查询对应的vlan网络，并据此在二层报文中加入vlan的802.1Q报文送入IP网络；相反vlan100的业务流量进入vxlan也需要根据vlan获知对应的vxlan的vni，根据目的mac地址获知远端vtep的IP地址，基于以上信息进行vxlan封装后送入对应的vxlan网络。

![](https://rancho333.gitee.io/pictures/vxlan_l2_gateway.png)

### vxlan集中式网关与分布式网关

集中式网关指将三层网关集中部署在一台设备上,如下图所示，所有跨子网的流量都经过这个三层网关转发，实现流量的集中管理。

![](https://rancho333.gitee.io/pictures/vxlan_gateway.png)

集中式网关的优点和缺点如下：
- 优点：对跨子网流量进行集中管理，网关部署和管理比较简单
- 缺点：
    - 转发路径不是最优
    - ARP表项规格瓶颈。通过三层网关转发的终端的ARP表项都需要在三层网关上生成。

vxlan分布式网关是指在典型的"spine-leaf"组网结构下，将leaf节点作为vxlan隧道断点VTEP，每个leaf节点都可作为vxlan三层网关(同时也是vxlan二层网关)，spine节点不感知vxlan隧道，只作为vxlan报文的转发节点。如下图所示

![](https://rancho333.gitee.io/pictures/vxlan_gateway_2.png)

部署分布式网关时：
- spine节点：关注于高速IP转发，强调的是设备的高速转发能力
- leaf节点：
    - 作为vxlan网络的二层网关，与物理服务器或vm对接，用于解决终端租户接入vxlan虚拟网络的问题
    - 作为vxlan网络的三层网关，进行vxlan报文封装与解封装，实现跨子网的终端租户通信，以及外部网络的访问

vxlan分布式网关具有如下特点：
- 同一个leaf节点既可以做vxlan二层网关，也可以做vxlan三层网关
- leaf节点只需要学习自身连接服务器的ARP表项，而不必像集中三层网关一样，需要学习所有服务器的ARP表项，解决了集中式三层网关带来的ARP表项瓶颈问题，网络规模扩展能力强

## vxlan网络中报文时如何转发的

这里介绍集中式vxlan中相同子网内、不同子网间是如何进行通信的。对于分布式vxlan网络，在EVPN中介绍。
对于二三层转发通信细节不是很清楚的同学，建议学习下二层与三层ping中arp与icmp报文的交互细节。

### 集中式vxlan中同子网互通流程

![](https://rancho333.gitee.io/pictures/vxlan_l2_ct.png)

如上图所示，VM_A、VM_B、VM_C属于相同网段，且同属VNI 5000。C要与A进行通信，对于首次通信，需要通过ARP获取对方MAC。在vlan子网通信中，arp报文在vlan内广播。在vxlan相同子网中，ARP请求报文转发流程见下图

![](https://rancho333.gitee.io/pictures/vxlan_l2_arp_request.png)

A向C进行MAC请求的过程如下：
1. A发送ARP请求报文请求C的MAC
2. VTEP_1收到ARP请求后
    1. 根据二层子接口上的配置判断报文需要进入vxlan隧道，确定报文所属BD，VNI
    2. VTEP_1学习A的MAC、VNI和报文入接口的对应关系，记录到MAC地址表中
    3. VTEP_1根据头端复制列表对报文进行复制，并分别进行封装，其中：
        1. 外层源IP为本地VTEP_1的IP地址，外层目的IP地址为对端VTEP(VTEP_2、VTEP_3)的IP地址
        2. 外层源MAC地址为本地VTEP的mac地址，外层目的mac地址为去往目的IP网络的下一跳设备mac地址
        3. 封装完成之后就是在underlay网络中将vxlan报文传送到对端VTEP
3. VTEP_2和VTEP_3收到报文后，对报文进行解封装，得到A发送的原始报文
    1. VTEP_2和VTEP_3学习A的MAC地址、VNI和远端VTEP_1IP地址的对应关系，并记录在本地MAC表中
    2. VTEP_2和VTEP_3根据二层子接口上的配置进行相应的处理并在对应的二层域内广播
4. B和C收到arp报文后，按照arp报文处理方式进行丢弃或应答。这里C向A发送ARP应答。

ARP应答报文转发流程见下图

![](https://rancho333.gitee.io/pictures/vxlan_l2_arp_reply.png)

C向A发送ARP 应答报文的过程如下：
1. A向C发送ARP应答报文
2. VTEP_3收到ARP应答报文后
    1. 确定报文所属的BD、VNI
    2. VTEP_3学习C的MAC、VNI和报文入接口的对应关系，记录到MAC地址表中
    3. VTEP_3对报文进行封装，其中：
        1. 外层源IP为本地VTEP_3的IP地址，外层目的IP地址为对端VTEP_1的IP地址
        2. 外层源MAC地址为本地VTEP的mac地址，外层目的mac地址为去往目的IP网络的下一跳设备mac地址
        3. 封装完成之后就是在underlay网络中将vxlan报文传送到对端VTEP
3. VTEP_1收到报文后，对报文进行解封装，得到C发送的原始报文
    1. VTEP_1学习C的MAC地址、VNI和远端VTEP_3IP地址的对应关系，并记录在本地MAC表中
    2. VTE_1将解封后的报文发送给A

至此，A和C均已学习到了对方的MAC地址。

### 集中式vxlan不同子网互通流程

![](https://rancho333.gitee.io/pictures/vxlan_l3_ct.png)

A、B分属不同网段，且分别属于VNI 5000和VNI 6000。A、B对应的三层网关分别是VTEP_3上的BDIF 10和BDIF 20的IP地址。VTEP_3上存在到两个网段的路由。

BDIF接口的功能与VLAN IF接口类似，是基于BD创建的三层逻辑接口，用以实现不同子网之间的通信，或vxlan网络与非vxlan网络之间的通信。

对于首次通信，类比与underlay网络中跨网段通信。A请求网关BDIF 10 MAC，然后将数据包发送给网关BDIF 10，BDIF 10将数据包路由至BDIF 20，BDIF 20请求B的MAC，然后将数据包发送给B。具体流程如下：

![](https://rancho333.gitee.io/pictures/vxlan_l3_arp.png)

数据报文转发流程如下：
1. A将数据报文发送给网关。报文的源MAC是A MAC，目的MAC是网管BDIF 10的MAC；报文的源IP是A的IP，目的IP是B的IP
2. VTEP_1收到数据报文之后，识别报文所属的VNI，并根据MAC表项对报文进行封装
    1. 外层源IP地址为本地VTEP的IP，外层目的IP地址为对端VTEP的IP
    2. 外层源MAC地址为本地VTEP的MAC地址，外层目的MAC地址为下一跳设备的IP地址
    3. 封装之后再underlay网络中传送至目的VTEP
3. VTEP_3收到报文之后，对报文进行解封装。得到A发送的原始报文，VTEP_3会报文会做如下处理：
    1. VTEP_3发现该报文的目的MAC为本机BDIF 10接口的MAC，而目的IP为B的IP，所以会根据路由表查找B的下一跳
    2. 发现下一跳的出接口为BDIF 20。VETP_3查询ARP表项，将原始报文的源MAC修改为BDIF 20接口的MAC，将目的MAC修改为B的MAC
    3. 报文到BDIF 20后，识别需要进入vxlan隧道，所以根据MAC表对报文进行封装。
        1. 外层源IP为本地VTEP的IP，外层目的IP地址为对端VTEP的IP
        2. 外层源MAC地址为本地VTEP的MAC，外层目的MAC为去往目的IP网络的下一跳设备的MAC地址
        3. 封装之后再underlay网络中传送至目的VTEP
4. VETP_2收到报文之后，对报文进行解封装，将overlay报文发送给B

vxlan网络与非vxlan网络之间的互通，也需要借助三层网关，但是不同在于：报文在vxlan网络侧会进行封装，而在非vxlan网络侧不需要进行封装。报文从vxlan侧进入网关并解封后，就按照普通单播报文的发送方式进行转发。

## overlay网络的三种构建模式

在数据中心，部分业务不适合进行虚拟化(如小机服务器，高性能数据库服务器),这些服务器会直接与物理交换机互联；对于服务器(虚拟机)，接入的可以是虚拟交换机(OpenvSwitch),也可以是物理交换机，因此存在如下图所示的三种接入模型。

![](https://rancho333.gitee.io/pictures/vxlan_network_module_2.png)

以上，在network overlay方案中，所有终端均采用物理交换机作为VTEP节点；host overlay方案中，所有终端均采用虚拟交换机作为VTEP节点；hybird overlay方案中，既有物理交换机接入，又有虚拟交换机接入，且软件VTEP和硬件VTEP之间可以基于标准协议互通。

## vxlan与SDN

vxlan只定义了转发平面的流程，对于控制平面还没有规范，一般采取三种方式：
1. 组播。由物理网络的组播协议形成组播表项，通过手工方式将不同的vxlan与组播组一一绑定。vxlan的报文通过绑定的组播组在组播对应的范围内进行泛洪
2. 自定义协议。通过自定义的邻居发现协议学习overlay网络的拓扑结构并建立隧道管理机制，比如现在广泛应用的BGP-EVPN
3. SDN控制器。通过SDN控制器集中控制vxlan的转发，经由openflow协议下发表项是目前业界的主流方式

# EVPN学习

## EVPN的作用

最初的vxlan方案(RFC7348)中没有定义控制平面，是手工配置隧道，然后通过流量泛洪的方式进行主机地址的学习。这会导致网络中存在很多泛洪流量、网络扩展起来很难。
