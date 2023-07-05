---
layout: ccie
title: lab考题分析1.15与1.16
date: 2023-07-04 09:32:39
tags: CCIE
---

继续考题分析，1.15与1.16。1.15比较杂，是将HQ和IaaS通过SP1l连通，1.16主要是NAT。
<!--more-->

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

注意考场上r30的lo0地址是`2001:db8:4:14::1`, 实验台预配有点小问题。

排错思路：
- 如果sw101上有lo0的路由但是ping不通，检查r4上有没有HQ的路由，是不是r11上双向重定向没做好

# 1.16 Enableing internet access for fabd2
下面是考题：
```
Enable highly available internet access for the fabd2 company network according to these requirements：

1. On routers r11,r23 and r24,bring up ipv4 bgp peering with the ISP，make sure that a default route is received over these peering.

2. On routers r12 and r23 inject default route into OSPF if it is present in the routing table from a different routing source than the ospfv2 process 1. On each router,this requirement must be completed using minimum possible number of commands.

3. On router r24 inject a default route into ospf if and only if it is learned from ISP over BGP. To accomplish this requirement, it is allowded to use a route-map that references both a prefix-list and a tag. This requirement must be completed using minimum possible number of commands.

4. Router r12 may be used as an internet exit for the fabd2 company network if neither r23 nor r24 are advertising a default route in OSPF. This requirement must be accomplish exclusively in 'router ospf' mode on router r12 without changing the default parameters on router r23 and r24.

5. On routers r12,r23 and r24 configure PAT and translate the entire fabd2 internal network 10.0.0.0/8 to the router address on the link towards the ISP. Create a standard ACL named NAT for this purpose. Do not use NAT pools.

6. Ensure that the internet connectivity of the fabd2 company network makes use of high availability provided by r12,r23 and r24.
```
下面是1.16的拓扑：
![](https://rancho333.github.io/pictures/lab_1.16.png)

总共涉及到三台设备，分别是r12，r23和r24。三台设备均与ISP建立eBGP邻居，ISP会向三台设备都下发默认路由，通过ospf将默认路由引入IGP中，最后配置NAT，是所有设备可以访问`8.8.8.8`。配置思路如下：
- 配置eBGP
- 配置默认路由
- 配置NAT

1. 配置eBGP
```
r12：
router bgp 65001
    no bgp default ipv4-unicast
    bgp router-id 10.1.255.12
    neighbor 200.99.12.1 remote-as 19999
    address-family ipv4
        neighbor 200.99.12.1 activate

r23:
router bgp 65002
    no bgp default ipv4-unicast
    bgp router-id 10.2.255.23
    neighbor 200.99.23.1 remote-as 19999
    address-family ipv4
        neighbor 200.99.23.1 activate

r24：
router bgp 65002
    no bgp default ipv4-unicast
    bgp router-id 10.2.255.24
    neighbor 200.99.24.1 remote-as 19999
    address-family ipv4
        neighbor 200.99.24.1 activate
```
检查正常建立eBGP邻居：
![](https://rancho333.github.io/pictures/lab_1.16_ebgp_neighbor.png)

ISP上已经预配下发默认路由：
![](https://rancho333.github.io/pictures/lab_1.16_r24_default.png)

2. 默认路由配置
```
r24：
ip prefix-list DEFAULT permit 0.0.0.0/0         // 定义前缀列表匹配默认路由
route-map DEFAULT permit 10
    match ip address prefix-list DEFAULT       // 定义route-map匹配前缀列表
    match tag 19999                             // ebgp下发的路由带有AS tag；这两条限制语句就可以精确匹配bgp下发的默认路由。不然可能匹配上eigrp的默认路由，注意eigrp的默认路由是指向null 0的
router ospf 1
    default-information originate route-map DEFAULT     // 产生默认路由再IGP中传递。ospf需要在路由表中存在默认路由才能产生默认路由的LSA

r23:
router ospf 1
    router-id 10.2.255.23           // 设置ospf router-id，用于在r12上匹配
    default-information originate

r12：
router ospf 1
    default-information originate metric 200        // 增加其它设备通过r12到达默认路由的开销，这样HQ中的其它设备就会通过r23和r24的默认路由上网；但是对于r12自身而言，依然是通过bgp的默认路由上网的

access-list 10 permit 0.0.0.0      // 创建ACL匹配默认路由
router ospf 1
    distance 15 10.2.255.23 0.0.0.0 10      
    distance 15 10.2.255.24 0.0.0.0 10      // 对于10.2.255.23/24通过ospf传递过来的默认路由，将其AD改成15. eBGP的AD是20, 所以两者传递过来的默认路由更优，即r12走默认路由通过r23和r24, 并且default-infor也不会发出type5的LSA(因为此时r12路由表中的默认路由就是ospf来的)
```
至此HQ和DC中都有默认路由，且通过r23,r24走ecmp。在r12上没有配置`distance`之前，三台设备都会产生Type 5的默认路由LSA，配置之后只有r23和r24会产生：
![](https://rancho333.github.io/pictures/lab_1.16_ospf_type5.png)

r12的默认路由通过sw101到达r23或r24:
![](https://rancho333.github.io/pictures/lab_1.16_r12_default_route.png)

3. 配置NAT
```
r12/r23/r24
ip access-list standard NAT
    permit 10.0.0.0 0.255.255.255       // 标准ACL名称为NAT匹配源地址10.0.0.0/8

ip nat inside source list NAT interface gi0/0 overload    //r23和r24上是gi1

r12:
int gi0/0
    ip nat outside
int range gi 0/1-3,lo0
    ip nat inside            // 配置nat inside与outside 域

r23:
int gi1
    ip nat outside
int range gi2-3,lo0
    ip nat inside

r24:
int gi1
    ip nat outside
int range  gi2-3,lo0,t0             // 加上隧道口
    ip nat inside
```

配置完成之后，HQ，br3和br4的所有主机可以访问`8.8.8.8`, 默认情况走r23或r24，ecmp
![](https://rancho333.github.io/pictures/lab_1.16_ping8.png)

分别关闭r24,r23的上行接口，traceroute跟踪如下：
![](https://rancho333.github.io/pictures/lab_1.16_traceroute_8.png)
可以看到当r23和r24都不可达后，从r12可以访问到。

到这里，传统部分的配置就已经全部完成了。HQ和Br3,Br4里面的主机都可以通过DHCP拿到IP，并可以访问到ISP中的`8.8.8.8`。后面就是SDN和自动化这两个部分的内容了。