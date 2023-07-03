---
layout: ccie
title: lab考题分析1.13和1.14
date: 2023-07-03 15:59:39
tags: CCIE
---

继续考题分析，1.13和1.14。 1.13是让主机拿ip，1.14是选择题。
<!--more-->

# 1.13 IPv4 networks on legacy Branchs
下面是题目。
```
On sw211 in DC, complete the DHCP server configuration according to these requirements：
1. Create ipv4 DHCP pools named br3_v2000 and br3_v2001 for branch3 vlan2000(10.6.100.0/24) and 2001(10.6.101.0/24), respectively

2. Create IPv4 DHCP pool named br4_v1 for the subnet 10.7.1.0/24 on branch4.

3. In each subnet assign addresser from .101 up to .254 inclusively and the appropriate gateway to clients

On branch3 complete and correct the configuration on switches s601，s602 and s610 to allow HSRP and DHCPrelay operation in vlans 2000 and 2001 according to these requirements：
1. HSRP must implicitly usr the vMAC address range of 0000.0c9f.f000 through 0000.0c9f.ffff

2. The group number must be 100 for vlan200 and 101 for vlan2001

3. s601 must be active gateway for vlan2000 with a priority of 110; the active role ownership must be deterministic

4. sw602 must be active gateway for vlan2001 with a priority of 110; the active role ownership must be deterministic

5. each active switch must track its uplink interface g0/1 and gi0/2. If either of these interface goes down, the active switch must allow the other switch to become active. However，it is not allowed for the tracking ro modify the HSRP priority to accomplish this requirements. You must use only one tracking statement when configuring the vlan interfaces for tracking。

6. Both sw601 and sw602 must be configured as DHCP relay agent in both vlans 2000 and 2001,pointing toward the DHCP server 10.2.255.211 at sw211. however， at anytime， only the active router in the particular vlan should relay the DHCP messages

7. place host61 and host62 into vlans 2000 and 2001 respectively and make sure they are assigned their correct ipv4 configuration

8. It is not permitted to use any kind of scripting to complete this task

On branch4 complete the configuration of the router r70 according to these requirements：
1. assign ip address 10.7.1.1/24 to ge0/2

2. enable dhcp relay on this interface and point it to the dhcp server 10.2.255.211 at sw211

3. It is allowed to add one additional missing command to the r70 configuration to allow clients connected to g0/2 obtain their ipv4 configuration

4. Make sure that host r71 and r72 are assigned their correct ipv4 configuration
```

1.13的拓扑如下所示，其中dhcp server sw211没有在图中展示出来：
![](https://rancho333.github.io/pictures/lab_1.13.png)

1.13很简单，HQ中使用的VRRP，这里使用cisco私有的HSRP做冗余网关，然后jiushi DHCP拿地址。配置思路如下：
- sw211上配置dhcp pool
- sw610配置vlan
- sw601和sw602配置HSRP和dhcp relay

下面是具体配置：

1. dhcp pool配置
```
sw211：
ip dhcp pool br3_v2000
    network 10.6.100.0 255.255.255.0
    default-router 10.6.100.1
ip dhcp pool br3_v2001
    network 10.6.101.0 255.255.255.0
    default-router 10.6.101.1
ip dhcp pool br4_v1
    network 10.7.1.0 255.255.255.0
    default-router 10.7.1.1
ip dhcp exclude-address 10.6.100.0 10.6.100.100
ip dhcp exclude-address 10.6.101.0 10.6.101.100
ip dhcp exclude-address 10.7.1.0 10.7.1.100         // 按要求做DHCP配置
```

2. sw610的vlan配置
```
vlan 2000                   // 预配中只有vlan2001, 补上缺少的vlan 2000
interfac gi0/0
    switchport mode access
    switchport access vlan 2000
interface gi0/1
    switchport mode access
    switchport access vlan 2001
interface rang gi2/0-1
    switchport mode trunk 
    switchport trunk all vlan 1,2000-2001
```

3. HSRP配置
```
sw601：
interface vlan2000
    standby version2                        // 版本必须是2
    standby 100 ip 10.6.100.1
    standby 100 name V2000
    ip helper address 10.2.255.211 redundancy V2000     // dhcp 中继配置，关联名称V2000,只有active的路由器发送DHCP请求
    // 上面这部分的配置可以直接复制给sw602的vlan 2000

    standby 100 priority 110
    standby 100 preempt                     // hsrp必须开启抢占才能保证优先级大的为active
    standby 100 track 3 shutdown            // 任一上行链路down掉，关闭hsrp组，让对端成为active

sw602：
interface vlan2001
    standby version2
    standby 100 ip 10.6.101.1
    standby 100 name V2001
    ip helper address 10.2.255.211 redundancy V2001     
    上面// 这部分的配置可以直接复制给sw601的vlan 2001

    standby 101 priority 110
    standby 101 preempt
    standby 101 track 3 shutdown        

// 考场上需要检查每个vlan的预配，如果有standby 0的配置要全部清除掉

sw601/sw602：
track 1 interface gi0/1 line-protocol
track 2 int gi0/2 line-protocol
track 3 list bool and           // 1和2同时up，3才是up
    object 1
    object 2

// r70上缺少网关，dhcp中继，以及网关路由的配置，就在这里补吧
r70：
interface gi0/2
    ip address 10.7.1.1 255.255.255.0 
    ip help-address 10.2.255.211
    no shutdown 
router eigrp ccie
    address-family ipv4 unicast autonomous-system 65006
        network 10.7.1.0 0.0.0.255              // 在eigrp中通过网关路由
```

配置完成之后，sw211为4台host分配ip：
![](https://rancho333.github.io/pictures/lab_1.13_dhcp.png)

验证HSRP的配置，sw601在vlan2000中是active，在vlan2001中是standby
![](https://rancho333.github.io/pictures/lab_1.13_stanby.png)

验证track，将sw601的上行口关闭，sw601上standby 100关闭，sw602成为vlan2000的active。其实只用关闭一个上行口就行，这里关了两个。
![](https://rancho333.github.io/pictures/lab_1.13_track.png)

# 1.14 Multicast in fabd2
考题如下：
```
Fabd2 is preparing to enable PIM sparse mode multicast routing in its network. As a port of validating the runbooks，fabd2 requies a sanity check to prevent inappropriate use of multicast related configuration commands on different router types.

First hop routers: routers where multicast source are connected
Last hop routers：routers where multicast receivers(subscribers) are connected
Intermediary Hop Routers - routers on the path between first hop and last hop routers

In the table below，for each configuration command，select all router types where the use of the command is appropriate.(select all that apply)
```
| | last hop router | first hop router | intermediary hop router |
| :-- | :-- | :-- | :-- |
| ip pim spt-threshold | | | |
| ip igmp version | | | |
| ip pim register-source | | | |
| ip pim sparse-mode | | | |
| ip pim rp-address | | | |
| ip pim passive | | | |

解法如下：
| | last hop router | first hop router | intermediary hop router |
| :-- | :-- | :-- | :-- |
| ip pim spt-threshold | Y | | |
| ip igmp version | Y | | |
| ip pim register-source | | Y | |
| ip pim sparse-mode | Y | Y | Y |
| ip pim rp-address | Y | Y | Y |
| ip pim passive | Y | Y | |