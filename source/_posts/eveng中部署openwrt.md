---
title: eveng中部署openwrt
date: 2025-11-19 01:52:26
tags:
  - eveng
  - openwrt
---

## 实验需求

在eveng中添加OpenWrt镜像, 在Openwrt中使能OpenClash服务，使得lab环境中所有连接到openwrt的节点能够访问google服务。
<!--more-->

实验拓扑如下图所示：
![](https://rancho333.github.io/pictures/eveng_openwrt-topology.png)

其中Net是lab的出口网关，本质是Vmware中的虚拟网卡VMnet8(NAT模式), Router1是Openwrt，wan口与Net连接。Client作为终端设备，与Openwrt的lan口连接。

## Openwrt部署

在[github](https://github.com/Emerosn/OpenWrt-Eve-ng)上找到一个openwrt的qemu镜像，直接按照readme中的方式集成到eveng中，注意需要关闭windows中hyper-v功能。

之后就可以通过网页配置openwrt.
![](https://rancho333.github.io/pictures/eveng_openwrt-control.png)

简单配置lan口上的dhcp，使client能够获取到ip.
```
root@client:/# ifconfig eth0
eth0      Link encap:Ethernet  HWaddr 50:00:00:03:00:00  
          inet addr:192.168.0.11  Bcast:192.168.0.255  Mask:255.255.255.0
          inet6 addr: fe80::5200:ff:fe03:0/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:1265 errors:0 dropped:0 overruns:0 frame:0
          TX packets:1245 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000 
          RX bytes:2892497 (2.7 MiB)  TX bytes:105530 (103.0 KiB)

```

此时client可以正常访问`www.baidu.com`, 但是无法访问google.

## OpenClash部署

这个版本的openwrt中并没有直接集成Openwrt, 按照下面的命令进行安装。

安装iptables及依赖。也可以使用nftables.
```
opkg update
opkg install bash iptables dnsmasq-full curl ca-bundle ipset ip-full iptables-mod-tproxy iptables-mod-extra ruby ruby-yaml kmod-tun kmod-inet-diag unzip luci-compat luci luci-base
```

下载openclash安装包并安装
```
wget https://github.com/vernesong/OpenClash/releases/download/v0.47.028/luci-app-openclash_0.47.028_all.ipk -O openclash.ipk
opkg install openclash.ipk
```
注意去github上下载最新的版本，不然安装好还要更新。

之后就可以在网页上看到openclash服务。
![](https://rancho333.github.io/pictures/eveng_openwrt-openclash.png)

在配置订阅中添加自己的机场订阅链接.
![](https://rancho333.github.io/pictures/eveng_openclash-subscribe.png)

之后做几处设置：`Plugin Setting  ——>  DNS setting` 中关闭 `Redirect Local DNS Setting`
确保`Traffic Control`中的`Wan interface name`列表式空。

## 外网测试

配置完成之后，openclash页面中的Access Check可以全部pass.
![](https://rancho333.github.io/pictures/eveng_openclash-access.png)

在client上测试能够正常访问google.
![](https://rancho333.github.io/pictures/eveng_openclash-google.png)
