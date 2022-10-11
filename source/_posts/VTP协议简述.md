---
title: VTP协议简述
date: 2022-10-11 15:05:08
tags:
---

# 写在前面
本文简要介绍写cisco的私有vlan中继协议VTP(vlan trunking protocol)，然后使用eveng环境做一些简单实验。
<!--more-->
当二层环境中有多台交换机，并且需要配置多个vlan的时候，这是一个繁琐且无聊的配置行为。VTP协议可以让我们只用在一台交换机上创建vlan，其它交换机则会同步创建的vlan。

# 了解VTP
VTP设备有三种角色：
1. VTP server：可以修改vlan配置，生成VTP通告
2. VTP  client：不可以通过CLI修改vlan配置，只能通过同步VTP通告修改vlan配置
3. VTP transparent：透传VTP通告但是不同步，可以修改本地vlan，修改也只在本地生效

VTP三种吗模式的能力概要如下：

| | VTP server| VTP Client | VTP transparent |
| :--- | :--- | :--- | :--- |
| 创建/修改/删除 vlans| yes | no | only local |
| 同步 | yes | yes | no |
| 透传 | yes | yes | yes |

通过下面几条说明来简单了解下VTP：
1. VTP可以自动添加，修改，删除vlans
2. 对于每一次改动，`revision`编号会增加
3. 最近一次的通告会被发送给所有的VTP clients
4. VTP clients会同步接收到的通告

VTP虽然可以减少vlan配置的工作量，但是会存在一些风险。根本原因是：
  VTP server同时也是VTP client, 而VTP client会同步接收到的revision号比自己大的通告。

如果我们在现有的网络环境中添加一台VTP server，而这台VTP server上的revision号比现有环境中设备的都大，那么新设备上的vlan配置会覆盖所有设备。本质就是环境中可能会有非预期设备的revision最大，覆盖环境的vlan配置。

此外还需要了解VTP的另一个知识点：VTP pruning.
![](https://rancho333.github.io/pictures/vtp_pruning.png)

如图，交换机之间通过trunk互联。当左侧vlan10中的PC发送一个广播报文后，所有交换机都会收到泛洪的消息，而中间交换机的下联口中并没有vlan10，上联交换机泛洪流量就是在浪费带宽了。
在非VTP环境下，泛洪流量会发送给所有的trunk端口(trunk允许该vlan通过)，因为交换机并不知道trunk对端是否有在该vlan的成员。
在VTP环境下，交换机知道trunk对端配置了那些vlan，所以不在这些vlan范围的内泛洪流量就可以不发送给对端。这就是VTP pruning.


# VTP的配置
使用如下的拓扑来进行VTP的配置实验：
![](https://rancho333.github.io/pictures/vtp_topology.png)

将交换机之间的互联接口全部配置成trunk。

```
S3#show vtp status 
VTP Version capable             : 1 to 3
VTP version running             : 1
VTP Domain Name                 : 
VTP Pruning Mode                : Disabled
VTP Traps Generation            : Disabled
Device ID                       : aabb.cc80.3000
Configuration last modified by 0.0.0.0 at 0-0-00 00:00:00
Local updater ID is 0.0.0.0 (no valid interface found)

Feature VLAN:
--------------
VTP Operating Mode                : Server
Maximum VLANs supported locally   : 1005
Number of existing VLANs          : 5
Configuration Revision            : 0
MD5 digest                        : 0x57 0xCD 0x40 0x65 0x63 0x59 0x47 0xBD 
                                    0x56 0x9D 0x4A 0x3E 0xA5 0x69 0x35 0xBC 
```
S4、S5的VTP信息和S3基本一致，对显示的信息做一个简单的说明：
- `Configuration Revision 0`: 每一次修改vlan该数值都会加1. 0是初始值，没有任何vlan操作
- `VTP Operating Mode` : 默认的模式是server模式
- `VTP Pruning Mode` : 防止不必要的流量通过trunk链路
-  `VTP version running` : 当前运行的vtp版本，默认是v1. v2与v1的差别不大，v2上主要引入对令牌环vlan的支持。

```
S3(config)#vlan 10
S3(config-vlan)#name first_vlan

S3#show vlan brief 

VLAN Name                             Status    Ports
---- -------------------------------- --------- -------------------------------
1    default                          active    Et0/0, Et0/1, Et0/2, Et0/3
10   first_vlan                       active    

S3#show vtp status | include Revision
Configuration Revision            : 1
```
在S3上创建名为first_vlan的vlan10, 可以看到revision号增加了1. 但是在S4、S5上并没有任何同步动作：
```
S4#show vtp status | begin existing
Number of existing VLANs          : 5
Configuration Revision            : 0

S5#show vtp status | begin existing   
Number of existing VLANs          : 5
Configuration Revision            : 0
```
这是因为必须要配置VTP domain才能正常同步。

在S4、S5上开启VTP debug。
```
S4#debug sw-vlan vtp events 
vtp events debugging is on

S5#debug sw-vlan vtp events 
vtp events debugging is on
```

在S3上配置vtp domain:
```
S3(config)#vtp domain rancho                   // 配置vtp domain
Changing VTP domain name from NULL to rancho
S3(config)#
*Oct 11 08:02:34.648: %SW_VLAN-6-VTP_DOMAIN_NAME_CHG: VTP domain name changed to rancho.
```

可以在S4、S5看到vtp domain会自动同步过来。
```
S5#
*Oct 11 08:14:23.822: VTP LOG RUNTIME: Summary packet received in NULL domain state
*Oct 11 08:14:23.822: VTP LOG RUNTIME: Summary packet received, domain = rancho, rev = 1, followers = 0, length 77, trunk Et0/1
*Oct 11 08:14:23.822: VTP LOG RUNTIME: Transitioning from NULL to rancho domain
*Oct 11 08:14:23.822: VTP LOG RUNTIME: Summary packet rev 1 greater than domain rancho rev 0
```
我们可以看到两件有意思的事：
- S5收到来自domain为`rancho`的VTP报文，并且决定将自己的domain从`NULL`改成`rancho`。这只会存在于设备没有配置domain的时候
- S5发现VTP报文中revision(1)比自己当前(0)的高，同步报文中的vlan信息

```
S5#no debug all                        // 关闭debug功能

S5#show vtp status | begin existing
Number of existing VLANs          : 6
Configuration Revision            : 1       // revision数值增减了，同步了S3的vlan配置

S5#show vlan brief                         // 确认配置信息同步，vlan10有了

VLAN Name                             Status    Ports
---- -------------------------------- --------- -------------------------------
1    default                          active    Et0/2, Et0/3
10   first_vlan                       active    

S4#show vlan brief 

VLAN Name                             Status    Ports
---- -------------------------------- --------- -------------------------------
1    default                          active    Et0/2, Et0/3
10   first_vlan                       active    
```

分别在S4、S5上各创建一个vlan
```
S4(config)#vlan 40
S4(config-vlan)#name second_vlan

S5(config)#vlan 50
S5(config-vlan)#name third_vlan
```
在S3上可以正常同步到：
```
S3#show vlan brief 

VLAN Name                             Status    Ports
---- -------------------------------- --------- -------------------------------
1    default                          active    Et0/2, Et0/3
10   first_vlan                       active    
40   second_vlan                      active    
50   third_vlan                       active    

S3#show vtp status | include Revision
Configuration Revision            : 3            // 同步两次，revision从1增加到3
```

修改S3的模式为client：
```
S3(config)#vtp mode client 
S3#show vtp status | include Mode
VTP Pruning Mode                : Disabled
VTP Operating Mode                : Client

S3(config)#vlan  100
VTP VLAN configuration not allowed when device is in CLIENT mode.
// client模式就不能配置valn了
```

修改S3的模式为透传模式：
```
S3(config)#vtp mode transparent 
Setting device to VTP Transparent mode for VLANS.
// 可以本地修改vlan信息，但是不会影响其它的vtp设备

S4(config)#vlan 70
S5#show spanning-tree | include Altn
Et0/0               Altn BLK 100       128.1    P2p    // S4,5之间的直连链路被block了
S5#show vlan brief 

VLAN Name                             Status    Ports
---- -------------------------------- --------- -------------------------------
1    default                          active    Et0/2, Et0/3
10   first_vlan                       active    
40   second_vlan                      active    
50   third_vlan                       active    
70   VLAN0070                         active           //但是S5依然能学到S4的vlan, 走的是S3的透传

S3#show vlan brief                  // 透传模式的S3并没有学到vlan70

VLAN Name                             Status    Ports
---- -------------------------------- --------- -------------------------------
1    default                          active    Et0/2, Et0/3
10   first_vlan                       active    
40   second_vlan                      active    
50   third_vlan                       active    
60   VLAN0060                         active    
```

最后一个小的知识点就是关于vlan的配置文件。只要开启vtp功能，vlan的配置信息是独立存放在vlan.data文件中的
```
S3#dir unix: | include vlan
917755  -rw-         796  Oct 11 2022 08:34:46 +00:00  vlan.dat-00048
// 不同的设备存放的路径可能不一样
```
并且vlan的配置信息在show run中是查看不到的，当关闭vtp时，vlan的配置信息就可以在show run中看到了。
```
S3(config)#vtp mode off 

S3#show running-config | include vlan
vlan 10
 name first_vlan
vlan 40
 name second_vlan
vlan 50
 name third_vlan
vlan 60 
```

最最后关于VTPv3, V3和V2兼容，和v1兼容。有比较大的差异，主要在：
- VTP primary Server
- Extended vlanss
- private vlanss
- rspan vlanss
- mst support
- authentication improvements
这里不做深入研究了，了解点VTPv2的皮毛先, 凑合用下吧。

为了严谨点，附上一个VTP报文截图吧, 创建vlan50时抓的，看来vtp会携带所有的vlan信息。
![](https://rancho333.github.io/pictures/vtp_packet.png)

# 参考资料
[了解 VLAN 中继协议 (VTP)](https://www.cisco.com/c/zh_cn/support/docs/lan-switching/vtp/10558-21.html)