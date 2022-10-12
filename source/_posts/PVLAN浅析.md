---
title: PVLAN浅析
date: 2022-10-12 10:34:00
tags:
---

# 写在前面
Vlan里面有两个常见的概念：透传与终结。所谓vlan透传就是某个vlan不仅在一台交换机上有效，它还要通过某种方法延伸到别的以太网交换机上，在别的设备上照样有效，vlan透传可以通过802.1Q技术实现。
终结的意思相对，某个vlan的有效域不能再延伸到别的设备，或者不能通过某条链路延伸到别的设备。vlan的终结可以使用PVLAN技术。

本文主要浅析下PVLAN的概念以及实验验证下。

# 基本概念
把vlan终结掉，也就是确定vlan的边界在哪里终止，pvlan技术可以很好的实现这个功能，同时达到节省vlan的目的。cisco的PVLAN意思是private vlan，华为的意思是primary vlan. 不同叫法，基本相同的实现。

PVLAN中的vlan分成两类：primary vlan和secondary vlan(子vlan)。实现了接入用户二层报文的隔离，同时上层交换机下发的报文可以被每一个用户接收到，简化了配置，节省了vlan资源。

本文用以下拓扑来实验说明：
![](https://rancho333.github.io/pictures/pvlan_topology.png)

pvlan中总是会有一个primary vlan，primary vlan中有promiscuous port。所有的端口都能和promiscuous port通信。在primary vlan中可以存在一个或多个secondary vlan，secondary vlan有两种类型：
- community vlan: community vlan中的成员端口可以相互通信，并且可以和promiscuous port通信
- isolated vlan：成员端口之间不能通信，但是可以和promiscuous port通信。

secondary vlan始终可以和promiscuous port通信，但是不同的secondary vlan之间是相互隔离的。

## 配置
实验拓扑如上所示。做一些简单说明：
- primary vlan的数值是100
- secondary community vlan的数值是101
- secondary isolated vlan的数值是102
- vpc3和vpc4在community vlan中可以相互通信，并且可以和连接到promiscuous port的vpc2通信
- vpc5和vpc6在isolated vlan中只能和vpc2通信
- vpc2可以和所有其它vpc通信

接下来就是配置了。

首先创建primary vlan和secondary vlan。
```
S(config)#vtp mode off                  // 首先关闭vtp，只有vtpv3支持pvlan，干脆关掉免得复杂
Setting device to VTP Off mode for VLANS.

S(config)#vlan 100              
S(config-vlan)#private-vlan primary             // 创建primary vlan
S(config-vlan)#private-vlan association add 101     // 与secondary vlan关联
S(config-vlan)#private-vlan association add 102

S(config)#vlan 101
S(config-vlan)#private-vlan community           // 创建secondary community vlan

S(config)#vlan 102
S(config-vlan)#private-vlan isolated            // 创建secondary isolated vlan
```

接下来配置接口所属的vlan.
```
S(config)#interface range ethernet 0/1-2        // community vlan所属的两个端口, 属于CV 101
S(config-if-range)#switchport mode private-vlan host    // 指明这些端口是主机端口，类似于access port
S(config-if-range)#switchport private-vlan host-association 100 101     // 指明端口所属的primary vlan是100，secondary vlan是101

S(config)#interface ethernet 0/0
S(config-if)#switchport mode private-vlan promiscuous           // 指明该端口是promiscuous port
S(config-if)#switchport private-vlan mapping 100 101            // 将primary vlan与secondary vlan映射

S(config)#interface ethernet 0/3 
S(config)#interface ethernet 1/0       
S(config-if)#switchport mode private-vlan host      // 配置端口属于secondary isolated vlan
S(config-if)#switchport private-vlan host-association 100 102
```

查看下配置的状态：
```
// 对于promiscuous port
S#show interfaces ethernet 0/0 switchport | include mapping     
Administrative private-vlan mapping: 100 (VLAN0100) 101 (VLAN0101) 102 (VLAN0102)

// 对于host端口
S#show interfaces ethernet 0/1 switchport | include host-association
Administrative private-vlan host-association: 100 (VLAN0100) 101 (VLAN0101) 

// 对于isolated端口
S#show interfaces ethernet 0/3 switchport | include host-association
Administrative private-vlan host-association: 100 (VLAN0100) 102 (VLAN0102)

// 查看primary vlan和secondary vlan，以及secondary的类型
S#show vlan private-vlan 

Primary Secondary Type              Ports
------- --------- ----------------- ------------------------------------------
100     101       community         Et0/0, Et0/1, Et0/2
100     102       isolated          Et0/3, Et1/0
```

接下来ping测试一下：
```
// 对于community vlan的成员
vpc3> ping  192.168.1.2 -c 1            // 可以ping通promiscuous port

84 bytes from 192.168.1.2 icmp_seq=1 ttl=64 time=1.775 ms

vpc3> ping  192.168.1.4 -c 1            // 可以ping通同secondary community的成员

84 bytes from 192.168.1.4 icmp_seq=1 ttl=64 time=1.159 ms

vpc3> ping  192.168.1.5 -c 1        // 不能ping通其它secondary vlan的成员

host (192.168.1.5) not reachable
```
vpc2同样可以ping通vpc3和vpc4，这里就不贴出来了。

```
// 对于isolated vlan的成员
vpc5> ping 192.168.1.6 -c 1         // 不能ping通同vlan的其它成员

host (192.168.1.6) not reachable

vpc5> ping 192.168.1.2 -c 1     // 可以ping通promiscuous port

84 bytes from 192.168.1.2 icmp_seq=1 ttl=64 time=0.815 ms

// promiscuous port则可以ping通isolated vlan内的所有成员
vpc2> ping 192.168.1.5 -c 1

84 bytes from 192.168.1.5 icmp_seq=1 ttl=64 time=1.050 ms

vpc2> ping 192.168.1.6 -c 1

84 bytes from 192.168.1.6 icmp_seq=1 ttl=64 time=0.475 ms
```

总结一下：
pvlan的实现：
1. 一定存在一个primary vlan, 里面有一个端口promiscuous port则可以ping通isolated
2. 可以存在多个secondary vlan，secondary vlan之间不能通信，但都可与promiscuous port通信
3. secondary vlan分为community vlan和isolated vlan与secondary
    - community vlan成员之间可以相互通信
    - isolated vlan成员之间不能相互通信
    - 所有secondary vlan成员都能与promiscuous port通信
4. pvlan作用域可以延伸到其它交换机，但是要保证交换机之间的链路是trunk，并允许primary vlan和secondary vlan通过 
5. 上行设备只关心primary vlan而不会感知secondary vlan，从而节省vlan资源

# 参考资料
[PVLAN技术白皮书](http://www.h3c.com/cn/d_201505/868804_30003_0.htm)