---
title: '使用ixia对sonic进行L2,3打流测试'
date: 2022-09-02 15:22:01
tags:
---

# 环境说明
实验拓扑如图：

![](https://rancho333.github.io/pictures/ixia_sonic_topology.png)

线连接好后，ixia上做些配置使端口up。sonic上link training和auto negotiation默认关闭，FEC开启。在ixia上对应接口做设置与之匹配。

![](https://rancho333.github.io/pictures/ixia_port_up.png)

确认端口up:
```
root@localhost:/home/admin# show interfaces status Ethernet49
  Interface        Lanes    Speed    MTU    FEC    Alias    Vlan    Oper    Admin             Type    Asym PFC
-----------  -----------  -------  -----  -----  -------  ------  ------  -------  ---------------  ----------
 Ethernet49  41,42,43,44     100G   9216     rs    etp49  routed      up       up  QSFP28 or later         N/A
root@localhost:/home/admin# show interfaces status Ethernet50
  Interface        Lanes    Speed    MTU    FEC    Alias    Vlan    Oper    Admin             Type    Asym PFC
-----------  -----------  -------  -----  -----  -------  ------  ------  -------  ---------------  ----------
 Ethernet50  45,46,47,48     100G   9216     rs    etp50  routed      up       up  QSFP28 or later         N/A=
```

# 二层打流

ixia eth7端口发出二层报文，sonic两个端口在同一vlan，ixia eth8端口接收报文进行数据统计，检查是否丢包。同理eth8发包，eth7收包。这样就实现双向二层线速打流测试。详细步骤如下：

sonic配置：
```
config vlan add 78
config vlan member add -u 78 Ethernet49
config vlan member add -u 78 Ethernet50

确认vlan配置：
root@localhost:/home/admin# show vlan brief 
+-----------+--------------+------------+----------------+-------------+-----------------------+
|   VLAN ID | IP Address   | Ports      | Port Tagging   | Proxy ARP   | DHCP Helper Address   |
+===========+==============+============+================+=============+=======================+
|        78 |              | Ethernet49 | untagged       | disabled    |                       |
|           |              | Ethernet50 | untagged       |             |                       |
```

ixia进行如下配置：
如图分别将eth7, eth8创建成L2接口：
![](https://rancho333.github.io/pictures/ixia_l2_port.png)

之后创建二层流：
![](https://rancho333.github.io/pictures/ixia_l2_traffic.png)

图示是eth7发送，eth8接收检查，同理创建反向流，实现双向打流测试。注意最好修改二层报文的源目mac地址。

最后打流测试：
![](https://rancho333.github.io/pictures/ixia_l2_traffic_loss.png)

# 三层打流

ixia eth7,8设置为三层接口，网关指向sonic，创建两条流分别：src为eth7，dst为eth8； src为eth8,dst为eth7.这样就实现双向三层线速打流测试。详细步骤如下：

sonic配置：
```
config interface ip add Ethernet49 10.1.1.2/24 
config interface ip add Ethernet50 10.1.2.2/24

确认配置：
root@localhost:/home/admin# show ip interfaces 
Interface    Master    IPv4 address/mask    Admin/Oper    BGP Neighbor    Neighbor IP
-----------  --------  -------------------  ------------  --------------  -------------
Ethernet49             10.1.1.2/24          up/up         N/A             N/A
Ethernet50             10.1.2.2/24          up/up         N/A             N/A
```

ixia进行如下配置：
如图所示分别将eth7,eth8创建成L3接口：
![](https://rancho333.github.io/pictures/ixia_l3_port.png)

然后依次为两个接口配置ip地址和gateway:
![](https://rancho333.github.io/pictures/ixia_l3_port_ip.png)

将拓扑使能之后，测试网络的连通性：
![](https://rancho333.github.io/pictures/ixia_l3_port_ping.png)

之后创建L3流，图上所示是eth7到eth8的流，同理创建eth8到eth7的流：
![](https://rancho333.github.io/pictures/ixia_l3_traffic.png)

注意和L2的数据流不同，L3不需要手动修改报文的src mac，dst mac等字段，会自动配置。

最后打流测试，查看丢包情况：
![](https://rancho333.github.io/pictures/ixia_l3_traffic_loss.png)