---
title: Basic-L2-L3-test-for-CLS_VS_SONIC
date: 2023-09-07 10:11:13
tags: SONiC
---

# Environment setup

Firstly, we setup the test environment like below picture.

![](https://rancho333.github.io/pictures/vs-sonic-environment.png)

<!--more-->

vpc1 and vpc2 perform L2 basic test in vlan100. q2a-1 and q2a-2 establish eBGP neighbors to perform l3 basic test, so that vpc1,vpc2 and vpc3 can communicate.

# L2 basic test

We create vlan100 and create SVI as vlan100 gateway. Eth1 and Eth2 are the vlan100 member ports. Please pay attention to the mapping relationship between the port name of eveng and the port name of sonic.
```
q2a-1:
config vlan add 100                              // create vlan100
config vlan member add 100 Ethernet4 -u          // add vlan member, SONiC Ethernet4 mapping eveng Ethernet1
config vlan member add 100 Ethernet8 -u          // SONiC Ethernet8 mapping eveng Ethernet2
config interface ip add Vlan100 192.168.1.1/24   // create SVI
```

After vlan configuration done, check the vlan state like below picture.
![](https://rancho333.github.io/pictures/vs-sonic-vlan.png)

Config the vpc1 and vpc2 like below picture.
![](https://rancho333.github.io/pictures/vs-sonic-vlan-vpc.png)

Make sure that vpc1 can ping the gateway and vpc2. Same as vpc2.
![](https://rancho333.github.io/pictures/vs-sonic-vpc1-vpc2.png)

Check the mac address table and arp table on q2a-1 respectively.
![](https://rancho333.github.io/pictures/vs-sonic-mac-arp.png)

# L3 basic test
We create L3 interface on q2a-1 and q2a-2 respectively like below picture.
![](https://rancho333.github.io/pictures/vs-sonic-if-ip.png)

After that, We can configure eBGP to propagate routes. For q2a-1:
```
router bgp 100                          // Asign ASN 100 to q2a-1
 neighbor 192.168.2.2 remote-as 200     // Specify neighbor ip and ASN

address-family ipv4 unicast
  redistribute connected                // redistribute connected routes into BGP (subnet of 192.168.1.0)
```

For q2a-2, same as q2a-1:
```
router bgp 200
 neighbor 192.168.2.1 remote-as 100

address-family ipv4 unicast
  redistribute connected
```

Make sure q2a-1 and q2a-2 can establish BGP neighbor and send routes to each other.
![](https://rancho333.github.io/pictures/vs-sonic-bgp-neighbor.png)

Check q2a-1 can learn 192.168.3.0 from BGP and q2a-2 can learn 192.168.1.0 form BGP.
![](https://rancho333.github.io/pictures/vs-sonic-bgp-routes.png)

Finally, check vpc1-vpc3 and vpc2-vpc3 can communicate with each other.
![](https://rancho333.github.io/pictures/vs-sonic-ping-finally.png)

WindowsSensor.MaverickGyr.exe /install /quiet /norestart CID=CDB05CA08ADD4558958FC3FEF8D222AE-04