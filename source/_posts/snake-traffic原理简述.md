---
title: snake traffic原理简述
date: 2022-09-10 09:00:38
tags:
---

# 写在前面
前面写了一篇[使用ixia对sonic进行L2,3打流测试](https://rancho333.github.io/2022/09/02/%E4%BD%BF%E7%94%A8ixia%E5%AF%B9sonic%E8%BF%9B%E8%A1%8CL2-3%E6%89%93%E6%B5%81%E6%B5%8B%E8%AF%95/), 这种场景下仪表的一个端口发包，dut的一个端口与之相连收包，通过在vlan内转发到DUT另一个端口，该端口与仪表的收包端口相连。仪表的一个端口发包，一个收包验证，从而验证二层转发(配置ip，路由即可验证三层)。 
这种场景只能验证两个端口之间的数据转发，如果要一次验证所有端口的数据转发，那么需要用到snake traffic，将所有端口串起来，数据依次流经所有端口

# snake traffica
先说明基本转发原理，然后根据不同的测试方案做进一步的说明。

## 入-转-出理论基础
二层snake traffic依赖vlan对数据流进行方向控制，打流过程中有三个数据流的基础操作点。
- 入。所有端口都设置成untag, 所以Rx是untag报文，根据端口的pvid打上对应的vlan tag
- 转。根据打上的vlan tag, 将报文转发到同vlan的其它端口，让其转发出去。`实际就是将报文从该端口的Tx发出去`
- 出。出端口收到tag报文，剥离tag，从Tx发出出去。
![](https://rancho333.github.io/pictures/snake_traffic_basic.png)

## 全loopback snake traffic
这种场景下，交换机前面板口全部通过loopback环回，当然也可以phy/mac环回。拓扑图如下：
![](https://rancho333.github.io/pictures/snake_traffic_loopback.png)

左侧的拓扑图是配置原理，右侧的拓扑是数据流的走向。broadcome芯片sdk配置如下：
```
vlan clear              // 清除所有vlan
vlan remove 1 pbm=ce       // 将所有端口从默认vlan中移除
//pbm是port bitmap，ubm是untag bitmap
vlan create 100 pbm=ce1,ce2 ubm=ce1,ce2; pvlan set ce1 100          // 创建vlan100，vlan100的端口成员是ce1和ce2，不带tag；设置ce1的native vlan为100
vlan create 101 pbm=ce2,ce3 ubm=ce2,ce3; pvlan set ce2 101
vlan create 102 pbm=ce3,ce4 ubm=ce3,ce4; pvlan set ce3 102
vlan create 103 pbm=ce4,ce1 ubm=ce4,ce1; pvlan set ce4 103
ps ce            // 确认所有端口up
clear c                  // 清除端口统计数据
tx 800 pbm=ce0 vlan=100        // 生成数据流
port ce0 en=off            // 结束打流
port ce0 en=on            // 恢复端口
show c CDMIB_RPOK.ce      // 查看计数
```
每个端口属于两个vlan，`通过native vlan来控制数据流发往那个vlan，另一个vlan则用来接收数据, 这样就形成了一个固定方向的数据流`。

以下图来详细说明数据流的走向：
![](https://rancho333.github.io/pictures/snake_traffic_loopback_internal.png)

1. 初始状态下。cpu通过tx命令生成报文发送到ce1，ce1从tx将报文转发出去。实际上ASIC通过cpu0接口(asic上一个不可见的端口)与CPU连接，cpu将报文发送到cpu0，cpu0将报文转发给ce1. 所以看起来就是：cpu生成报文，ce1从tx将报文转发出去
2. ce1的端口是loopback，tx的报文会转到rx，rx收到报文打上100的vlan tag，转给vlan 100的成员端口ce2
3. ce2将报文untag之后从tx发送出去，因为是loopback，所以又会从rx回来，rx收到报文打上101的vlan tag, 转给vlan 101的成员端口
4. 同理ce3将报文转给ce4，ce4将报文转回给ce1
5. ce1将ce4转来的报文从Tx转发出去，重复步骤1的流程。这样就形成了loop的数据流，很快就会达到线速。

一点说明：这种场景下，因为有loopback的存在，所以端口的tx，rx都会参与到流量的转发。这就可以理解为双向打流。

## 端口通过DAC cable互联
这种场景下，交换机相邻的两个端口用cable先互联起来，相邻的两个没有用cable先互联的端口则配置在相同vlan中进行数据转发。可以这么理解，同一个vlan内的两个端口组成一个交换机，然后用cable线将这些交换机依次连接，组成一个环。拓扑如下：
![](https://rancho333.github.io/pictures/snake_traffic_dac.png)

端口2,3组成一台交换机，端口3,4组成一个交换机，互联成环。同样的道理，如果进行三层打流，并将所有的端口串在一起，可以用vrf，每两个端口在一个vrf中组成一个router，vrf之间通过cable互联，通过配置ip和路由就可实现snake traffic。

dac cable连接的snake traffic配置如下：
```
// 只贴出vlan配置，其它参考上面
vlan create 100 pbm=ce2,ce3 ubm=ce2,ce3; pvlan set ce2,ce3 100
vlan create 101 pbm=ce4,ce1 ubm=ce4,ce1; pvlan set ce4,ce1 101
```

这种场景下，一个端口只属于一个vlan(类似于上层的access端口)，端口所属的vlan就是native vlan, 不是很确定pvlan还需不需要配置。此时不需要native vlan来控制数据流的方向，所以两个端口pvlan都一样。

以下图来详细说明数据流的走向：
![](https://rancho333.github.io/pictures/snake_traffic_dac_internal.png)

1. 初始状态下。cpu生成报文让ce1从tx发送出去。报文通过cable先发送到ce2
2. ce2 rx到报文后，打上vlan tag 100，发送给vlan 100成员端口ce3
3. ce3收到报文之后将tag剥离从tx发出， 通过cable线到达ce4
4. ce4通过vlan将报文转给ce1，ce1从tx发出，重复步骤1的流程，形成loop数据流，很快就会达到线速

## dac和loopback混合测试
实验拓扑如图：
![](https://rancho333.github.io/pictures/snake_traffic_dac_loopback.png)

其中，12,34是dac方式，5,6,7,8是loopback方式。
需要注意下两种方式之间的流量衔接问题接口。
对于dac向loopback过度的节点，即4,5: 将4,5配置在同一个vlan中，并将4的native vlan设置成该值，这样dac方向的流量就可以从4转发到5，然后进入loopback方向。

对于loopback向dac过度的节点，将8，1配置在同一个vlan中，两者的native vlan都设置成该vlan，这样8 rx的流量就会转给1，进入dac方向。

如果不使用CPU发包，而是将一个端口与测试连接，拓扑如下：
![](https://rancho333.github.io/pictures/snake_traffic_ixia.png)

配置不需要做任何改变。理解报文的转发流程，拓扑怎么变都可以搞定。
ixia发出的报文对8来说是rx，8的native vlan是8,1共同所属的vlan，所以流量转发到1。
7转发给8的流量，8从tx发出到ixia，所以ixia从一个端口发出的报文，又从该端口收回来，查看ixia端口的丢包状态即可了解dut的丢包状态。