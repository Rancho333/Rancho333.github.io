---
title: ip_sla
date: 2022-07-14 17:08:32
tags: 
---

# 写在前面
IP sla(service level agreement)服务等级协议，可以实时的收集ip网络的各种信息，包括latency、jitter、packet loss，连通性等。本文主要介绍sla在connectivity上的应用。在连通性检查上，可以说是BFD的升级版，BFD只能检测同一网段内的链路联通行，sla则可以跨网段。IP-SLA是思科私有协议，华为NQA与之对标。
<!--more-->

# sla实验
IP sla可以用来和track联动监控某个ip是否可达。实验拓扑如下：

![](https://rancho333.github.io/pictures/sla_topology.png)
拓扑说明如下：
S1作为接入层交换机，vpc在vlan10中，S2，S3作为汇聚层交换机，跑vrrp提高网关可靠性，其中S2在vlan10中既是stp的根桥也是vrrp的master，这样可以提高链路的利用率。同理，如果增加vlan20,可将根桥和vrrp的角色给S3. R4上跑NAT做地址转换。S2上通过sla监控R4上loopback0的可达性，R7, R4, S2,S3,S5之间跑ospf，最终实现vpc与R7的互通。当S2的上行链路不可达时，S3成为vrrp的master接管vpc的流量。

## 配置说明
本实验的配置分为几块进行，分别是基础配置(vlan,stp,ip,routing)，vrrp配置，NAT配置，sla配置(sla,track,vrrp)。

基础配置(vlan,stp,ip,routing)如下：
{% tabs tab,1 %}
<!-- tab vpc-->
```
ip 192.168.1.10/24 192.168.1.1
```
<!-- endtab -->
<!-- tab S1-->
```
interface Ethernet0/0
 switchport access vlan 10
!
interface Ethernet0/1
 switchport trunk encapsulation dot1q
 switchport mode trunk
!
interface Ethernet0/2
 switchport trunk encapsulation dot1q
 switchport mode trunk

```
<!-- endtab -->
<!-- tab S2-->
```
interface Loopback0
 ip address 2.2.2.2 255.255.255.0
 ip ospf 110 area 0
!
interface Ethernet0/0
 switchport trunk encapsulation dot1q
 switchport mode trunk
!
interface Ethernet0/1
 no switchport
 ip address 24.1.1.2 255.255.255.0
 ip ospf 110 area 0
!
interface Ethernet0/2
 switchport trunk encapsulation dot1q
 switchport mode trunk
!
interface Vlan10
 ip address 192.168.1.2 255.255.255.0
 ip ospf 110 area 0
!
router ospf 110

```
<!-- endtab -->
<!-- tab S3-->
```
interface Loopback3
 ip address 3.3.3.3 255.255.255.0
 ip ospf 110 area 0
！
interface Ethernet0/0
 switchport trunk encapsulation dot1q
 switchport mode trunk
!
interface Ethernet0/1
 no switchport
 ip address 35.1.1.3 255.255.255.0
 ip ospf 110 area 0
!
interface Ethernet0/2
 switchport trunk encapsulation dot1q
 switchport mode trunk
!
interface Vlan10
 ip address 192.168.1.3 255.255.255.0
 ip ospf 110 area 0
!
router ospf 110
```
<!-- endtab -->
<!-- tab R4-->
```
interface Loopback0
 ip address 4.4.4.4 255.255.255.255
 ip ospf 110 area 0
!
interface Ethernet0/0
 ip address 24.1.1.4 255.255.255.0
 ip ospf 110 area 0
 duplex auto
!
interface Ethernet0/1
 ip address 47.1.1.4 255.255.255.0
 ip ospf 110 area 0
 duplex auto
 ```
<!-- endtab -->
<!-- tab R5-->
```
interface Loopback0
 ip address 5.5.5.5 255.255.255.255
 ip ospf 110 area 0
!
interface Ethernet0/0
 ip address 35.1.1.5 255.255.255.0
 ip ospf 110 area 0
 duplex auto
!
interface Ethernet0/1
 ip address 57.1.1.5 255.255.255.0
 ip ospf 110 area 0
 duplex auto
 ```
<!-- endtab -->
<!-- tab R7-->
```
interface Loopback0
 ip address 7.7.7.7 255.255.255.0
 ip ospf 110 area 0
!
interface Ethernet0/0
 ip address 47.1.1.7 255.255.255.0
 ip ospf 110 area 0
 duplex auto
!
interface Ethernet0/1
 ip address 57.1.1.7 255.255.255.0
 ip ospf 110 area 0
 duplex auto
```
<!-- endtab -->
{% endtabs %}

基础配置很简单，就是vlan，ip，ospf的基本配置。接下来在S2、S3上面配置vrrp。
{% tabs tab,1 %}
<!-- tab S2-->
```
interface Vlan10
 vrrp 1 ip 192.168.1.1          // 创建vrrp，虚拟网关ip为192。168.1.1
 vrrp 1 priority 150            // 增加s2的vrrp优先级，使其成为master
```
<!-- endtab -->
<!-- tab R1-->
```
interface Vlan10
 vrrp 1 ip 192.168.1.1          // S3上面配置vrrp，使其成为backup
```
<!-- endtab -->
{% endtabs %}
 
查看vrrp的基本信息：
```
S2#show vrrp brief 
Interface          Grp Pri Time  Own Pre State   Master addr     Group addr
Vl10               1   150 3414       Y  Master  192.168.1.2     192.168.1.1    

在vpc上测试网关是否可达：
VPCS> ping 192.168.1.1 -c 1
84 bytes from 192.168.1.1 icmp_seq=1 ttl=255 time=0.435 ms
```

NAT配置如下，这里做一个简单的nat配置，复用出端口ip。
```
ip access-list standard NAT
 permit 192.168.1.0 0.0.0.255          // 创建acl，匹配192.168.1.0网段的ip

ip nat inside source list NAT interface Ethernet0/1 overload //创建nat，转换source，匹配NAT的acl，复用eth0/0的IP地址

interface Ethernet0/0
 ip nat inside              // 确定source，dest

interface Ethernet0/1
 ip nat outside              // 确定source，dest
```
R5上的NAT配置和R4一模一样，完成之后vpc就可以ping通`7.7.7.7`了。
```
VPCS> ping 7.7.7.7 -c 1
84 bytes from 7.7.7.7 icmp_seq=1 ttl=253 time=1.043 ms

在R4上查看NAT转换：
R4#show ip nat translations 
Pro Inside global      Inside local       Outside local      Outside global
icmp 47.1.1.4:36346    192.168.1.10:36346 7.7.7.7:36346      7.7.7.7:36346
```

此时一切都还顺利，但是当我们将R4关机后，会发现vpc ping不通7.7.7.7，这是因为S2，S3无法感知上游链路的故障，所以依然认为S2是vrrp master，ospf的收敛时间比较久，所以S2上到7.7.7.7的下一跳依然是eth0/1，自然不通。我们创建sla来感知上游链路故障，分别在S2、S3上配置：
```
// 创建sla
ip sla 1                                        // 创建sla 1
 icmp-echo 4.4.4.4 source-ip 2.2.2.2            // sla的监控事项是：源2.2.2.2与dest4.4.4.4的联通性
 frequency 5                                    // 评率是5秒一次
ip sla schedule 1 life forever start-time now   // sla 1的时间表，从现在开始，生命周期为永远

// sla与track的联动
track 1 ip sla 1                                // track监控sla的结果

// track与vrrp的联动
interface Vlan10
 vrrp 1 track 1 decrement 60                    // 如果track失败，vrrp优先级降低60
```
S3上镜像S2的sla配置，查看sla的状态信息：
```
S2#show ip sla summary | begin ID       
ID           Type        Destination       Stats       Return      Last
                                           (ms)        Code        Run 
-----------------------------------------------------------------------
*1           icmp-echo   4.4.4.4           RTT=1       OK          1 second ago

S2#show track 1 
Track 1
  IP SLA 1 state
  State is Up
    7 changes, last change 00:08:26
  Latest operation return code: OK
  Latest RTT (millisecs) 1
  Tracked by:
    VRRP Vlan10 1
```

现在将R4关机，查看sla的状态信息以及vrrp的状态信息：
```
S2#show ip sla summary | begin ID  
ID           Type        Destination       Stats       Return      Last
                                           (ms)        Code        Run 
-----------------------------------------------------------------------
*1           icmp-echo   4.4.4.4           -           Timeout     12 seconds ag

S2#show vrrp brief 
Interface          Grp Pri Time  Own Pre State   Master addr     Group addr
Vl10               1   90  3414       Y  Backup  192.168.1.3     192.168.1.1    
```
可以看到S2的优先级现在是90，S3是master了。track interface可以实现类似的效果，但当R4的eth1 down掉之后，S2和R4之间端口都是up，无法检测出故障，sla直接检测ip的联通性适用性更广，我们设置可以在s2上直接检测到7.7.7.7的连通性。

将R4开机后，S2重新成为vrrp master, 故障恢复。