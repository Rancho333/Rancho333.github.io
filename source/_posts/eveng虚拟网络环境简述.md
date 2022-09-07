---
title: eveng虚拟网络环境简述
date: 2022-09-06 16:13:55
tags: eveng
---

# 写在前面
本文主要分析下vmware三种网络模式的实现，然后说明eveng如何借助vmware虚拟网卡实现内部设备与外网的联通，最后分析下eveng lab中虚拟网络设备之间的连通性。
<!--more-->

# VMware的三种网络模式
vmware有桥接、NAT、host-only三种网络模式。其中NAT和host-only会默认在host上各创建一张虚拟网卡。其中VMnet1是host-only，VMnet8是NAT。我们在虚拟的配置hardware时，可以添加网络设备。
![](https://rancho333.github.io/pictures/eveng_vmware_network.png)
如果选择NAT、host-only、桥接则使用默认网卡。选择custome时，可以指定我们自己创建的其它网卡。注意，只能存在一个bridge和NAT的网络，即我们可以额外添加的虚拟网络类型只能是host-only。下面对三种网络模式做一个简单说明。

## 桥接模式
三种模式下只有桥接模式没有创建虚拟网卡，这种模式下虚拟机和主机相当于连接在同一个网桥上，网桥的出口是主机的物理出口网卡，虚拟机的ip和主机的ip由上游DHCP同一分配，两者在同一网段，虚拟机可以自由的访问同子网的主机(当然包括主机)，这种情况下虚拟没有和外部网络隔离，会消耗主机网络环境的ip。可以同时满足主机与虚拟机之间的网络连通，以及虚拟机与外部网络之间的网络连通。
![](https://rancho333.github.io/pictures/eveng_vmware_bridge.png)

简言之，桥接模式就是虚拟机和主机连接在同一个网桥上，网桥上连是出口，下连是虚拟机和主机。桥接模式和主机物理网卡是强相关的，在创建bridge虚拟网络时，选择auto选项，vmware会自动从主机多网卡中选择合适的进行桥接。

## NAT模式
NAT模式默认创建VMnet8虚拟网卡。虚拟机网卡与vmnet8相连，vmnet8在主机上是一块物理网卡，是直连网段，所以主机与虚拟机之间可以直接通过Vmnet8通信。vmnet8上开启dhcp服务，负责给虚拟机分配ip，在vmware设置中可以设置所需的网段。当虚拟机需要和主机外部通信时，vmnet8通过NAT服务将虚拟机ip映射主机某个物理网卡ip，从而实现和外网的连通性。模型如下图所示：
![](https://rancho333.github.io/pictures/eveng_vmware_nat.png)

这种场景下，虚拟机与主机通过vmnet8同网段通信，复用主机ip通过NAT与外网通信。在NAT模式的配置下并没有看到NAT转换的具体配置，关键是没看到转换后的ip, 这其实与主机的实际出口网卡相关，这难道和桥接模式一样，也是自动选择的？

## host-only模式
host-only模式默认创建VMnet1虚拟网卡。虚拟机网卡与vmnet1相连。该模式本质就是NAT模式阉割掉NAT功能，使得虚拟机只能与主机网络可达，而不能访问外部网络。这样可以有效的实现虚拟机与外部网络环境的隔离。

## 一些小结思考
真实的拓扑模型可能和上述的不一样，上述只是自己实验加理解的结果。在上面理解中，VMnet我其实是理解成三层交换机而不是网卡，因为它可以被多个虚拟机连接，但是网卡的一个端口在系统上会映射成一个网络设备，多个接口会映射成多个网络设备，所以在windows的视角中，vmnet就是一个单接口的网卡。
有些博客中提到：vmware会创建虚拟交换机和虚拟网卡，虚拟交换机互联虚拟机网卡，主机虚拟网卡，主机物理网卡。这是虚拟化实现的内部细节，可以暂不做细节研究，了解不同模式的特点，功能，及使用就好。
![](https://rancho333.github.io/pictures/eveng_vmware_blog.png)
这种拓扑是比较合理的，windows的视角下有一块网卡VMnet8，而虚拟机连接的是同名为VMnet8的网桥，所以多个虚拟机可以连接到VMnet8，这三者组成vmware虚拟网络环境，虚拟机和主机通过vmnet8同网段进行通信，vmnet8与物理NIC之间通过NAT与外网通信。给虚拟机设置网卡的配置界面如下：
![](https://rancho333.github.io/pictures/eveng_vmware_adapter.png)

在虚拟机的视角下，每添加一个network adapter就是在虚拟机上创建一个物理网卡，network connection选项则是虚拟机网卡连接vmware虚拟网络环境的模式，通过连接到指定的虚拟网桥来实现的，而不同的虚拟网桥连接着不同的windows虚拟网卡(bridge没有虚拟网卡)。

# eveng中镜像的连接实现
一个简单的eveng镜像连接如下所示：
![](https://rancho333.github.io/pictures/eveng_image_connection.png)

这里有三个对象，switch、vpc以及他们的连接线，switch和vpc由各自的镜像提供运算仿真逻辑，当我们需要仿真某种设备时，只需要将其镜像导入eveng，而镜像的运行则依赖于eveng的三大虚拟仿真组件：iol、qemu、dynamips。那么镜像之间的连接线是如何实现的呢？通过bridge来实现。在上图拓扑基础上我们进入eveng的CLI界面：
将lab中的image启动后查看bridge状态：
```
root@eve-ng5:~# brctl show
bridge name	bridge id		STP enabled	interfaces
pnet0		8000.000c297a7dde	no		eth0
pnet1		8000.000c297a7de8	no		eth1
...		
vnet0_1		8000.4e340b0134f2	no		vunl0_1_0
							            vunl0_2_0
```
vnet0_1仿真的就是S和vpc的连接线，bridge上有两个接口分别连接在S和vpc上。我们增加拓扑结构：
![](https://rancho333.github.io/pictures/eveng_image_connection_more.png)

再次查看bridge状态：
```
root@eve-ng5:~# brctl show
bridge name	bridge id		STP enabled	interfaces
pnet0		8000.000c297a7dde	no		eth0
...	
vnet0_1		8000.7a42880945b1	no		vunl0_1_0
							            vunl0_2_0
vnet0_2		8000.0ef8341d6178	no		vunl0_1_16
							            vunl0_3_0
vnet0_3		8000.6a2c8be29ff6	no		vunl0_1_32
							            vunl0_4_0
```
图中有3条连接线，所以这里有三个vnet_name命名模式的网桥，一个网桥模拟一个连接线，每个网桥上都有vun0_1_name命名模式的接口，可见这是S的接口，所以他们这件的真实的连接拓扑如图：
![](https://rancho333.github.io/pictures/eveng_image_connection_bridge.png)

当删除网元设备或关闭lab的时候，模拟他们连接线的网桥并不会自动删除，自由彻底关闭eveng虚拟机才会清除，但这对我们的使用并不会有什么影响。

# eveng虚拟机的网卡
eveng本身就是一台运行在linux中的虚拟机，在创建虚拟机的时候会指定网卡以及连接方式。在`一些小结思考`图示中我们给eveng添加了两块网卡。每块网卡以名为ethnum的模式命名：
```
root@eve-ng5:~# ifconfig 
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        ether 00:0c:29:7a:7d:de  txqueuelen 1000  (Ethernet)
        RX packets 390  bytes 73174 (73.1 KB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 552  bytes 75404 (75.4 KB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

eth1: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        ether 00:0c:29:7a:7d:e8  txqueuelen 1000  (Ethernet)
        RX packets 21  bytes 3432 (3.4 KB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 14  bytes 1136 (1.1 KB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
```
eth0对应的是Network Adapter，eth1对应的是Network Adapter2,其中eth0作为管理网卡，也就是我们通过web访问eveng的ip。注意eveng会为每块网卡创建一个bridge, 然后将网卡attach到brige上。
```
root@eve-ng5:~# brctl show
bridge name	bridge id		STP enabled	interfaces
pnet0		8000.000c297a7dde	no		eth0
pnet1		8000.000c297a7de8	no		eth1
pnet2		8000.000000000000	no		
pnet3		8000.000000000000	no		
pnet4		8000.000000000000	no		
pnet5		8000.000000000000	no		
pnet6		8000.000000000000	no		
pnet7		8000.000000000000	no		
pnet8		8000.000000000000	no		
pnet9		8000.000000000000	no	
```
网卡ethnum与网桥pnetnum一一对应，eveng最大支持10块网卡。eth0作为管理网口，一般选择host-only, 这样可以配置dhcp地址池，使其每次启动获得固定ip，并且和外网隔离。如果使用bridge模式eveng的管理ip则会随主机网络环境变换而发生变化。管理网口ip就是网桥pnet0的ip:
```
root@eve-ng5:~# ifconfig pnet0
pnet0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.183.134  netmask 255.255.255.0  broadcast 192.168.183.255
        inet6 fe80::20c:29ff:fe7a:7dde  prefixlen 64  scopeid 0x20<link>
        ether 00:0c:29:7a:7d:de  txqueuelen 1000  (Ethernet)
        RX packets 1064  bytes 196089 (196.0 KB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 1576  bytes 217466 (217.4 KB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
```

为什么要将网卡attach到bridge上呢？这是为了让lab中的镜像可以访问到主机网络和外部网络。bridge在lab的表现形式是cloudNum。
![](https://rancho333.github.io/pictures/eveng_network_cloud.png)

pnet0对应的是cloud0, pnet1对应的是cloud1，依次类推。lab中网元访问外部网络如图示：
![](https://rancho333.github.io/pictures/eveng_network_cloud0.png)

vpc可以向VMnet1请求dhcp, 获得和管理网口同网段的ip：
```
VPCS> ip dhcp
DDORA IP 192.168.183.143/24
```
其完整的网络连接拓扑如下图：
![](https://rancho333.github.io/pictures/eveng_network_lab_connection.png)

当vpc请求dhcp时，我们在windows上对VMnet1抓包可以看到dhcp交互报文。

lab中的网元连接到不同的cloud，就可以根据cloud所属网桥的网卡的连接方式(bridge, nat, host-only)获得对应的网络能力，实现lab与主机和外部网络的连通性。

总结一下，配置eveng时的network adapter对应eveng中的eth网卡，eth网卡attch到pnet网桥上，pnet网桥对应lab中的cloud，lab中的网元连接到对应cloud即可获得相应网络能力。

## 完整的eveng与vmware虚拟网络连接示意图
vmware是可以创建多张虚拟网卡的，默认有三种网络类型，bridge没有虚拟网卡，VMnet1对应host-only,VMnet8对应NAT。虽然允许创建额外的VMnet，`但是类型只能是host-only`，所以看起好像没什么创建的必要，默认的就已经够用了。我们需要做的也就是配置一下dhcp地址池(使用默认的也行)。
对于eveng的虚拟网络，由外网、windows、vmware、eveng、lab这些对象组成，完整的网络拓扑如下：
![](https://rancho333.github.io/pictures/eveng_network_topology.png)