---
layout: ccie
title: lab考题分析三
date: 2023-06-21 16:58:18
tags: CCIE
---

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





# 1.6 dhcp