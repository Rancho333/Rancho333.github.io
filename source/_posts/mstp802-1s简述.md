---
title: mstp802.1s简述
date: 2022-07-07 16:22:19
tags: STP
---
# 写在前面
STP和RSTP无法实现负载均衡，cisco的PVST和PVRSTP虽然能够实现，但是每个vlan对应一个实例，在vlan较多的情况下，这对CPU以及内存资源会有极大的浪费。所以MSTP横空出世，其核心理念是：将一组vlan映射到一个实例中，每个实例运行一个stp树。MSTP的实现标准是802.1s.
<!--more-->

# MST中的几个概念

## 域(region)
具有`相同属性`的交换机在同一个域中：
- MST域名
- MST版本号
- MST中vlan与实例的映射关系

MST域名是给该域配置的名字，可以随便起。版本号也可以随便起(类似VTP中的版本号，只有一样才会同步)。映射到同一个实例中的vlan属于同一个stp树，有相同的根桥，转发路径，阻塞路径等。类似于端口与vlan的映射，所有的vlan最开始属于默认实例(cisco中是instance 0).

## IST
IST是internal spanning tree的缩写，表示默认实例。MST只会通过IST向其它域通告BPDU.

## CIST
CIST是common and internal spanning tree，公共和内部生成树，是整个大二层网络所有交换机组成的单生成树(所有域共同组成)，将每个域看做一台设备，CST(common spanning tree)就是由这些设备组成的树

## MSTI
MSTI是multi spanning tree instance的缩写，多实例生成树的实例

## 选举规则
MSTP中的选举规则和STP完全一致，快速收敛机制则和RSTP完全一致。

## MST的BPDU
区别于pvstp中每个vlan都会发送一个BPDU，MSTP中并不是每个实例发送一个BPDU，而是一台交换机只会发送一个BPDU，这一个BPDU中包含了所有的实例。具体到字段而言：
- protocol version字段是0x03
- BPDU type字段和rstp一样是0x02
- flags字段和rstp保持一致
- BID字段中的扩展ID则为0
其它字段简介如下：
![](https://github.com/Rancho333/pictures_hub/blob/master/non_auto/mstp_bpdu.png?raw=true)

MSTP配置比较复杂，特别是在多域使用尤其复杂，本文只通过单域对MSTP有一个简单的了解。

# 实验说明
经典的三角环形拓扑， 创建一个MSTP域，域内创建两个实例instance 1、2, vlan 10-15映射到实例1， vlan 16-20映射到实例2。实例0的根桥是S1，实例1的根桥是S2，实例2的根桥是S3. 拓扑图如下：

![](https://github.com/Rancho333/pictures_hub/blob/920baf1e40926adc604b727854fd10b7861dc24e/non_auto/mstp_topology.png?raw=true)

实验步骤如下：
创建Vlan 10-20
```
S1(config)#vlan 10-20
// S2和S3做相同配置
```

交换机之间配置trunk连接：
```
S1(config)#interface range ethernet 0/0-1
S1(config-if-range)#switchport trunk encapsulation dot1q
S1(config-if-range)#switchport mode trunk
// S2和S3做相同配置
```

配置stp版本为MSTP：
```
S1(config)#spanning-tree mode mst
// S2和S3做相同配置
```

配置MSTP域：
```
S1(config)#spanning-tree mst configuration      // 进入mst域配置视图
S1(config-mst)#name rancho                      // 设置域名
S1(config-mst)#instance 1 vlan 10-15            // 设置实例1与vlan的映射
S1(config-mst)#instance 2 vlan 16-20            // 设置实例2与vlan的映射
S1(config-mst)#revision 1                       // 设置版本号
// S2与S3做相同配置，注意：域名、vlan与实例的映射，版本号这三者必须一致
```

给实例配置不同的根桥：
```
S2(config)#spanning-tree mst 1 priority 4096    // 设置S2为实例1中最优BID
S3(config)#spanning-tree mst 2 priority 4096    // 设置S3为实例2中最优BID
// S1的mac地址最小，实例0中三台交换机优先级都是32768，所以实例0中S1是根桥
```

实验结果对比检查：
确认配置信息：
```
S1#show spanning-tree mst configuration 
Name      [rancho]
Revision  1     Instances configured 3

Instance  Vlans mapped
--------  ---------------------------------------------------------------------
0         1-9,21-4094
1         10-15
2         16-20
-------------------------------------------------------------------------------
// S2与S3中做相同检查
```

确认实例0中根桥及端口状态：
![](https://github.com/Rancho333/pictures_hub/blob/master/non_auto/mstp_instance_0.png?raw=true)

可以看到实例0中，S1是根桥，S3的eth0处于blocking状态。

确认实例1中根桥及端口状态：
![](https://github.com/Rancho333/pictures_hub/blob/master/non_auto/mstp_instance_1.png?raw=true)

可以看到实例1中，S2是根桥，S3的eth1处于blocking状态。

确认实例2中根桥及端口状态：
![](https://github.com/Rancho333/pictures_hub/blob/master/non_auto/mstp_instance_2.png?raw=true)

可以看到实例2中，S3是根桥，S2的eth0处于blocking状态。

三个实例中对应的转发路径如下图所示：
![](https://github.com/Rancho333/pictures_hub/blob/master/non_auto/mstp_instance_forward_path.png?raw=true)

可以看到不同实例的流量之间负载均衡。

# 兼容性说明
MSTP向下兼容RSTP和STP，不建议这么使用。
