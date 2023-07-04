---
layout: ccie
title: lab考题分析1.15与1.16
date: 2023-07-04 09:32:39
tags: CCIE
---

继续考题分析，1.15与1.16。1.15比较杂，是将HQ和IaaS通过SP1l连通，1.16主要是NAT。

# 1.15  Extending connectivity to IaaS
下面是考题。
```
Extend ipv4,ipv6 connectivity from HQ through the SP into the giosk VRF on the IaaS site according to these requirements：

set up global ipv6 addressing on the link between r11 and r3
    on r11， assign 2001:2710:311::2/64 to ge0/0
    on r3，assing 2001:2710:311::1/64 to g1

Enable the existing ipv4 BGP session between r11 and r3 to also advertise ipv6 prefixes. DO not configure a standalone ipv6 BGP session between these two routers.

Perform bidirectional route redistribute between the ipv6 eigrp and bgp processes on r11。

Ensure that all current and future ipv6 prefix advertised between r11 and r3 will be installed into the RIB of these routers with the next hop address set to the proper global unicast address on their interconnection. Any policy that accomplish this requirement must be applied in the inbound direction.

The giosk VRF on r4 that extends the IPv6 connectivity from r4 to r30 on the IaaS site is a separate VRF independent of fabd2 VRF. Any route leaking from fabd2 VRF into giosk VRF must be done on a per-site basis and only for those fabd2 sites that need connectivity with the IaaS site.

By configureing r3 and r4 only，ensure that the HQ FABD2 site will have mutual visibility with the IaaS site while preventing.

Any other fabd2 site from possibly learning about the routes on the IaaS site
The IaaS site from possibly learning about the routes on any other fabd2 sites

Use the minimum amount of commands necessary to accomplish this requirement. Do not remove any existing configuration. If necessary，you are allowed to use additional route target with the value of 10000:3681.

verify that host11 and host12 can ping 2001:db8:4:14::1 located at the IaaS site. It is permitted to modify one existing configuration command on one of the SP routers to meet this requirement.
```

1.15的拓扑如下：
![](https://rancho333.github.io/pictures/lab_1.15.png)

总共涉及到三台设备r11,,r3,r4, r11与r3建立eBGP，传递ipv6路由，r11上ipv6 eigrp和bgp之间做单点双向重发布，r4上修复mpls, 最终使得HQ可以访问R30的lo0. 配置思路如下：
- 配置ipv6地址
- 建立eBGP，配置route-map
- r11单点双向重发布
- r4修复mpls

配置如下：
1. 配置ipv6地址
```
r11：
int gi0/0
    ipv6 address 2001:2710:311::2/64

r3：
vrf definition fabd2
    address-family ipv6         // 必须现在vrf下激活ipv6，才可以在vrf下配置ipv6地址
    route-target 10000:3681     // 配置RT，与R4的vrf giosk的ipv6 RT一致。题目如果要求是只扩展ipv6，那么就在ipv6地址族下配置，如果扩展ipv4和ipv6，就在fabd2下配置
int gi1
    ipv6 address 2001:2710:311::1/64    
```
配置完成之后，ipv6可以ping通：
![](https://rancho333.github.io/pictures/lab_1.15_ipv6_ping.png)

2. 建立eBGP
```
r11：
router bgp 65001
    address-family ipv6
        neighbor 100.3.11.1 activate        // 使用ipv4地址传递ipv6路由
        neighbor 100.3.11.1 route-map IPV6NH in     //应用route-map修改ipv6下一跳

route-map IPV6NH permit 10
    set ipv6 next-hop 2001:2710:311::1      // 创建路由策略，修改下一跳为ipv6全局地址，否则是link-local地址

r3:
router bgp 10000
    address-family ipv6 vrf fabd2  
        neighbor 100.3.11.2 remote-as 65001    // 在ipv6地址族的vrf实例中指定邻居，使用ipv4地址；会自动激活
        neighbor 100.3.11.2 route-map IPV6NH in

route-map IPV6NH permit 10
    set ipv6 next-hop 2001:2710:311::2
```

3. r11单点双向重发布
```
r11：
router eigrp ccie
    address-family ipv6 unicast autonomous-system   65001
    topology base
        redistribute bgp 65001 metric 1000000 10 255 1 1500

router bgp 65001
    address-family ipv6
    redistribute eigrp 65001 include-connected      // 包含r11上eigrp的直连(环回口)
```

4. 修复mpls
```
R4：
vrf definition giosk
    address-family ipv6 
        route-target 10000:3681         // 这是只扩展ipv6, 如果要同时扩展ipv4和ipv6，在giosk下配置RT，同时作用于ipv4和ipv6地址族

interface lo0
    ip address 100.255.254.4 255.255.255.255
//原始r4的环回口掩码是31，ospf协议会以32为路由发布，这样会导致MPLS的LSP断裂，host11 ping不通r30的lo0上的ipv6地址
// 需要修复为32位掩码，修复MPLS VPN转发层面R4分配标签的问题
```

下面是验证：
r11与r3建立eBGP邻居：
![](https://rancho333.github.io/pictures/lab_1.15_bgp_neighbor.png)

route-map设置前后的路由下一跳如图所示：
![](https://rancho333.github.io/pictures/lab_1.15_r11_route.png)
r3只传递一条ipv6路由给HQ，就是`2001:db8:14::1`，r11上同样需要设置ipv6下一跳：
![](https://rancho333.github.io/pictures/lab_1.15_r11_route.png)


sw101上有r30 lo0的路由，r4上也有HQ内的ipv6路由：
![](https://rancho333.github.io/pictures/lab_1.15_14_route.png)

最后HQ内的host可以ping通r30的lo0：
![](https://rancho333.github.io/pictures/lab_1.15_ping_r30.png)

排错思路：
- 如果sw101上有lo0的路由但是ping不通，检查r4上有没有HQ的路由，是不是r11上双向重定向没做好

# 1.16 Enableing internet access for fabd2
下面是考题：
```
Enable highly available internet access for the fabd2 company network according to these requirements：

1. On routers r11,r23 and r24,bring up ipv4 bgp peering with the ISP，make sure that a default route is received over these peering.

2. On routers r12 and r23 inject default route into OSPF if it is present in the routing table from a different routing source than the ospfv2 process 1. On each router,this requirement must be completed using minimum possible number of commands.
```