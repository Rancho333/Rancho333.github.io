---
layout: ccie
title: lab考题分析1.5
date: 2023-06-21 16:58:18
tags: CCIE
---

继续考题分析，1.5
<!--more-->

# 1.5 DHCP ipv4 service for HQ
下面是考题：
```
Enable hosts in HQ vlan2000 and vlan2001 to obtain their IP configuration via DHCP according to these requirements.

1. On sw211,create ipv4 DHCP pools name hq_v2000 and hq_v2001 for HQ vlans 2000 and 2001 respectively. In each subnet assign addresses from .101 up to .254 inclusively and the appropriate gateway to clients.

2. In addition to this make sure host11 get ip address 10.1.100.150 and host12 ge ip address 10.1.101.150

3. Enable DHCP snooping on sw110 in vlans 2000 and 2001 to protect against DHCP related attacks。ALso apply rate limit on edge devices "15 packets per second" and unlimited at the switches(portchannel)

4. Place host11 into vlan2000; Pleace host12 into vlan2001

5. Perform the necessary configuration on switches sw101, sw102, sw110 to enable hosts in vlans 2000 and 2001 to obtain ipv4 configuration through DHCP. The DHCP server running at sw211 in the DC must be referred to by its ipv4 address 10.2.255.211. Do not disable the option 82 insertion，and do not enable DHCP snooping on other switches。

6. Verify that host11 and host12 have the IP connectivity to the Cisco DNA center,vManage, ISE running in the DC using their internal(in Band connectivity) address
```

1.5的拓扑示意如下：
![](https://rancho333.github.io/pictures/lab_1.5.png)

涉及到6台设备，分别是host11,host12,sw110,sw101,sw102,sw211.
1.2,1.3,1.4都是为了1.5做铺垫，1.2是打通二层链路，1.3是配置冗余网关，1.4是解决主机，网关到DHCP server的路由。1.6就是做DHCP配置，使host11，host12拿到ip。基本思路如下：
- sw211作为dhcp server，分别给HQ的vlan2000,vlan2001配置dhcp pool，并添加relay信任
- sw101和sw102上面做dhcp relay配置并添加relay信任
- sw110上做dhcp snooping相关配置
- host11和host12通过dhcp获取ip
- 通过client-id给指定设备分配固定ip

1. 配置DHCP server
```
sw211：
    ip dhcp pool hq_v2000
        network 10.1.100.0 /24
        default-router 10.1.100.1
    ip dhcp pool hq_v2001
        network 10.1.101.0 /24
        default-router 10.1.101.1     // 配置地址池
    ip dhcp exclude-address 10.1.100.0 10.1.100.100
    ip dhcp exclude-address 10.1.101.0 10.1.101.100     // 预留地址，从101开始分配
    ip dhcp relay information trust-all                 // sw101/102中继后，option82里面不应该有内容了吗                
```

2. 配置DHCP relay
```
sw101/sw102:
    int ran vlan 2000-2001
        ip helper-address 10.2.255.211
    ip dhcp relay information trust-all         // 全局开启，信任sw110嗅探后插入的option82为空的dhcp报文
    // 经过relay的dhcp报文，会插入option82字段，表明设备所在的物理位置，从而让DHCP从对应的地址池分配ip
```
配置结果如下：

![](https://rancho333.github.io/pictures/lab_1.5_dhcp_relay.png)

3. 配置DHCP snooping相关
```
sw110：
    ip dhcp snooping        // 首先开启全局dhcp嗅探
    ip dhcp snooping vlan 2000-2001         // 指定dhcp嗅探的vlan
    ip dhcp snooping information option        // 嗅探后的DHCP报文插入option82字段，表明该dhcp报文被嗅探过(默认是开启的),但是option82中是无效ip 0.0.0.0

    inter gi0/0
        switchport mode access
        switchport access vlan 2000
        ip dhcp snooping limit rate 15
    inter gi0/1
        switchport mode access
        switchport access vlan 2001
        ip dhcp snooping limit rate 15      // 将接口加入指定vlan，并限制dhcp报文速度
    inter range port-c 1-2
        ip dhcp snooping trust          // 信任上行链路dhcp，不做限制
```
dhcp snooping配置结果现象如下：

![](https://rancho333.github.io/pictures/lab_1.5_dhcp_snooping.png)

4. 主机获取ip
之后使host11和host12通过dhcp获取ip，结果如下：

![](https://rancho333.github.io/pictures/lab_1.5_dhcp.png)

host12上误操作多次获取ip，正确结果应该是10.1.101.101, 重启host12结果即可正常，这里不操作了。

5. 指定固定ip
将client-id与ip地址进行绑定，从而给主机分配指定ip，client-id是`01`加mac地址组成的，配置如下：
```
ip dhcp client client-id gi0/1          // 如果client-id过长，使用该命令指定client-id格式，linux主机不需要配置

sw211:
    show ip dhcp binding        // 查看dhcp分配
    clear ip dhcp binding *     // 清除分配信息

    ip dhcp pool hq_v2000
        address 10.1.100.150 client-id xx
    ip dhcp pool hq_v2001
        address 10.1.101.150 client-id xx       // 地址绑定
```
使host重新获取ip地址，结果如下；
![](https://rancho333.github.io/pictures/lab_1.5_dhcp_client-id.png)

注意state的状态是`Active`，如果server上看不到分配的ip，说明主机报文无法到达server，如果state状态是`Selecting`，表明主机没有收到server的offer报文，server到主机方向的路由有问题。

host获取到指定ip，最后测试host到DC中几个关键服务器的可达性：
```
host11/12:
    ping 10.2.250.11
    ping 10.2.251.11
    ping 10.2.252.11    
    ping 10.2.253.11
    ping 10.2.254.11
```

lab考试中有两个DHCP服务器，一个是sw211，另外一个是r23。r23只是给br1和br2的guest vpn提供DHCP服务，而sw211则给HQ中的host11,host12; br3中的host61，host62, br4中的host71,host72; br1/2中的IoT vpn、Employee vpn提供dhcp服务。我们可以在1.5中将sw211上的DHCP pool都配置掉。