---
title: Linux双网卡设置-内外网
date: 2021-01-26 10:39:15
tags: 网络
---

# 写在前面
搞了一台树莓派4B来玩，想通过ssh来进行管理。由于公司网络管控，考虑通过内网（eth0）来进行ssh管理，通过外网(wlan0)进行上网。
<!--more-->

# 网络配置

有线网和无线网都连接好后，通过DHCP获取ip，`ip route`状态如下：
```
default via 10.204.123.1 dev eth0 proto dhcp src 10.204.123.145 metric 202 
default via 192.168.3.254 dev wlan0 proto dhcp src 192.168.3.38 metric 303 
10.204.123.0/24 dev eth0 proto dhcp scope link src 10.204.123.145 metric 202 
192.168.0.0/22 dev wlan0 proto dhcp scope link src 192.168.3.38 metric 303
```
其中10.204.0.0/16网段是内网，设备没有通过认证，不能通过内网上外网。考虑通过该网段与自己的主机相连，其余网络连接走192.168网段。
先将默认路由删除，这里需要连接显示器。
```
route del default
```
因为有两条默认理由，该命令执行两次。

之后添加默认路由和默认网关，可以写到`/etc/rc.local`中：
```
#foreign net
route add -net 0.0.0.0/0 wlan0
route add -net 0.0.0.0/0 gw 192.168.3.254

#local net
route add -net 10.204.123.0/16 eth0
route add -net 10.204.123.0/16 gw 10.204.123.1
```
使能之后，`ip route`状态如下：
```
default via 10.204.123.1 dev eth0 proto dhcp src 10.204.123.145 metric 202 
default via 192.168.3.254 dev wlan0 proto dhcp src 192.168.3.38 metric 303 
10.204.0.0/16 via 10.204.123.1 dev eth0 
10.204.0.0/16 dev eth0 scope link 
10.204.123.0/24 dev eth0 proto dhcp scope link src 10.204.123.145 metric 202 
192.168.0.0/22 dev wlan0 proto dhcp scope link src 192.168.3.38 metric 303 
```
`route -n`状态如下：
```
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         192.168.3.254   0.0.0.0         UG    303    0        0 wlan0
10.204.0.0      10.204.123.1    255.255.0.0     UG    0      0        0 eth0
10.204.0.0      0.0.0.0         255.255.0.0     U     0      0        0 eth0
10.204.123.0    0.0.0.0         255.255.255.0   U     202    0        0 eth0
192.168.0.0     0.0.0.0         255.255.252.0   U     303    0        0 wlan0
```
可以看到10.204网段走的是10.204.123.1网关，其余的网段走的都是外网192.168.3.254网关。

如果设备上使能了dhcpcd功能，则需要在获取到ip、路由之后手动配置路由。可以通过wlan0网络（外网）配置eth0（内网）的路由。
