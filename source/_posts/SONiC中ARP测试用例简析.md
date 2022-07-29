---
title: SONiC中ARP测试用例简析
date: 2021-04-26 16:08:45
tags: SONiC
---

## 写在前面
本文简要分析SONiC testbed中ARP测试用例的实现，作为对[ARP协议简述及应用](https://rancho333.github.io/2020/12/25/ARP%E5%8D%8F%E8%AE%AE%E7%AE%80%E8%BF%B0%E5%8F%8A%E5%BA%94%E7%94%A8/)的补充。

<!--more-->
## 背景知识简述
ARP直接基于以太帧进行封装，`type`类型为`0x0806`，报文很简单，只有两类：ARP request报文和ARP reply报文。其中request报文可分为三类：
    1. 单播request，参考rfc1122，一种arp缓存刷新机制
    2. 广播request，这也是常见的arp请求报文
    3. 免费arp报文，sender ip和destination ip相同

## 测试用例简析
在`sonic-mgmt/tests/arp`下共有4个测试文件：
```
test_arpall.py
test_neighbor_mac_noptf.py
test_neighbor_mac.py
test_wr_arp.py
```
本文会分析`test_arpall.py`文件，对于其它三个文件会简要说明一下，最后对测试失败的`test_wr_arp.py`做一个分析。

`test_arpall.py`中设计了5种测试用例：
1. 发送单播arp request
2. 发送广播arp request
3. 发送不同网段的arp request(sender ip字段异常)
4. 免费arp测试

### 单播arp request测试
测试代码在`sonic-mgmt/tests/arp/test_arpall.py`文件中，对该模块代码截取简析如下：

![](https://rancho333.github.io/pictures/arp_unicast_reply.png)

报文构造代码在`sonic-mgmt/ansible/roles/test/files/ptftests/arptest.py`文件中，对应的ARP包构造函数内容如下：

![](https://rancho333.github.io/pictures/verifyunicastarpreply.png)

基本流程就是构造单播arp request报文，之后获取dut的arp表，看发送arp request的端口arp条目是否存在。根据rfc1122，这是unicast poo(单播轮询)：定时向ARP缓存条目中的主机发送点到点的ARP请求报文，假如在N次连续超时时间过后，没有收到对应主机的ARP响应报文，则将此条目从ARP缓存中删除。

其实这样测试并不能测试出unicast poll的定义，和普通ARP 请求没啥区别。

### 广播arp request测试
测试代码如下：

![](https://rancho333.github.io/pictures/arp_expect_reply.png)

对应的ARP包构造函数内容如下：

![](https://rancho333.github.io/pictures/expectreply.png)

如上面的分析，和单播arp请求没啥区别，虽然ser intf1的mac改了一下，但无关紧要。

### 收到的arp报文请求的不是本接口mac

测试代码如下：

![](https://rancho333.github.io/pictures/arp_no_reply_other_intf.png)
这里asset判断的ip错了，应该是不等于10.10.1.22才对。

对应的ARP包构造函数内容如下：

![](https://rancho333.github.io/pictures/srcoutrangenoreply.png)

### 收到的arp请求中的sender ip与本接口不在同一网段
和上面`收到的arp报文请求的不是本接口mac`的流程基本一致，只是将相同的arp request报文发给dut intf1。

### 免费arp报文测试
免费arp的测试分为两块，如果免费arp中的信息之前没有解析过，那么不应该响应免费arp报文，反之响应。

不响应的代码如下：

![](https://rancho333.github.io/pictures/garp_no_update.png)

对应的ARP包构造函数内容如下：

![](https://rancho333.github.io/pictures/garpnoupdate.png)

此时即使dut收到了免费arp报文，但是`10.10.1.7`的信息并不在dut的arp表中，所以不应该有响应动作。

响应的代码如下：

![](https://rancho333.github.io/pictures/garp_update.png)
可以看到先调用`ExpectReply`让`10.10.1.3`存在于dut的arp表中，之后再调用`GarpUpdate`更新mac，MAC地址由`00:06:07:08:09:0a`更新为`00:00:07:08:09:0a`。

对应的ARP包构造函数内容如下：

![](https://rancho333.github.io/pictures/garpupdate.png)
这里面修改了`10.10.1.3`对应的MAC地址。

## 其它三个测试文件说明
对于`test_neighbor_mac_noptf.py`，ptf作为dut的邻居，针对ipv4和ipv6两种场景，分别测试在DUT的redis中和arp表中能不能找到另据的arp entry。
对于`test_neighbor_mac.py`，ptf作为dut的邻居，使用相同的ip(ipv4)，映射两个不同的mac地址，分别测试这两个mac在redis中存不存在。
对于`test_wr_arp.py`测试热重启过程中的arp功能，首先在ptf上开启ferret server，之后让dut进入warm-reboot，在此过程中，ptf发送arp request，25秒内没有收到arp reply测试失败。

## 测试结果说明
以`10.204.112.27:8080`上的`seastone-t0`为例说明，测试结果如下：

![](https://rancho333.github.io/pictures/testbed_wrarp_seastone.png)

可以看到`test_wr_arp.py`测试失败了，结果不符合预期。wr_arp首先在ptf host上开启ferret服务，之后在dut上启动warm-reboot程序，当dut处于warm-reboot阶段时，向其vlan成员发送arp请求报文，25秒内任一vlan成没有响应则测试失败。

而在`seastone2-t0`上面，该项测试失败，但是原因不一样：

![](https://rancho333.github.io/pictures/testbed_wrarp_seastone2.png)
此处是没有获取到ptf宣告的ip，这个网段应该由zebra下发到kernel，src字段为dut的loopback。