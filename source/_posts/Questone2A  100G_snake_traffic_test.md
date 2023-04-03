# environment description
The experimental topology is shown in the figure:

![](https://rancho333.github.io/pictures/questone2a_100G_snake_traffic_topology.png)
<!--more-->

After the line is connected, do some configuration on ixia to make the port up. On sonic, link training and auto negotiation are disabled by default, and FEC is enabled. Set the corresponding interface on ixia to match it.

Make sure the port is up:
```
root@sonic:/home/admin# show interfaces status Ethernet49-56
  Interface        Lanes    Speed    MTU    FEC    Alias    Vlan    Oper    Admin             Type    Asym PFC
-----------  -----------  -------  -----  -----  -------  ------  ------  -------  ---------------  ----------
 Ethernet49  41,42,43,44     100G   9100     rs   100GE1  routed      up       up  QSFP28 or later         N/A
 Ethernet50  45,46,47,48     100G   9100     rs   100GE2  routed      up       up  QSFP28 or later         N/A
 Ethernet51  73,74,75,76     100G   9100     rs   100GE3  routed      up       up          Unknown         N/A
 Ethernet52  77,78,79,80     100G   9100     rs   100GE4  routed      up       up  QSFP28 or later         N/A
 Ethernet53      1,2,3,4     100G   9100     rs   100GE5  routed      up       up  QSFP28 or later         N/A
 Ethernet54  21,22,23,24     100G   9100     rs   100GE6  routed      up       up  QSFP28 or later         N/A
 Ethernet55     5,6,7,8,     100G   9100     rs   100GE7  routed      up       up  QSFP28 or later         N/A
 Ethernet56  25,26,27,28     100G   9100     rs   100GE8  routed      up       up  QSFP28 or later         N/A
```

# snake traffic test for 100G

The ixia eth7 port sends out Layer 2 packets, the two sonic ports are in the same vlan, and the ixia eth8 port receives packets for statistics to check whether packets are lost. Similarly, eth8 sends packets, and eth7 receives packets. In this way, the bidirectional Layer 2 wire-speed streaming test is realized. The detailed steps are as follows:

sonic configuration:
```
drivshell>vlan clear
vlan clear
drivshell>vlan remove 1 pbm=ce
vlan remove 1 pbm=ce
drivshell>


drivshell>vlan create 100 pbm=ce1,ce2 ubm=ce1,ce2; pvlan set ce1,ce2 100
vlan create 101 pbm=ce3,ce4 ubm=ce3,ce4; pvlan set ce3,ce4 101
vlan create 102 pbm=ce5,ce7 ubm=ce5,ce7; pvlan set ce5,ce7 102
vlan create 100 pbm=ce1,ce2 ubm=ce1,ce2; pvlan set ce1,ce2 100
vlan create 102 pbm=ce5,ce7 ubm=ce5,ce7; pvlan set ce5,ce7 102
vlan create 103 pbm=ce0,ce6 ubm=ce0,ce6; pvlan set ce0,ce6 103
drivshell>vlan create 101 pbm=ce3,ce4 ubm=ce3,ce4; pvlan set ce3,ce4 101
drivshell>vlan create 102 pbm=ce5,ce7 ubm=ce5,ce7; pvlan set ce5,ce7 102
drivshell>vlan create 103 pbm=ce0,ce6 ubm=ce0,ce6; pvlan set ce0,ce6 103
drivshell>


drivshell>vlan show
vlan show
vlan 1	ports none (0x000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000), untagged none (0x000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000) MCAST_FLOOD_UNKNOWN
vlan 100	ports ce1-ce2 (0x000000000000000000000000000000000000000000000000000000000000000000000000000000000800000400000000), untagged ce1-ce2 (0x000000000000000000000000000000000000000000000000000000000000000000000000000000000800000400000000) MCAST_FLOOD_UNKNOWN
vlan 101	ports ce3-ce4 (0x000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000002), untagged ce3-ce4 (0x000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000002) MCAST_FLOOD_UNKNOWN
vlan 102	ports ce5,ce7 (0x000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018000), untagged ce5,ce7 (0x000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018000) MCAST_FLOOD_UNKNOWN
vlan 103	ports ce0,ce6 (0x000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000004), untagged ce0,ce6 (0x000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000004) MCAST_FLOOD_UNKNOWN
drivshell>
```


Then create two Layer 2 stream:
![](https://rancho333.github.io/pictures/questone2a_100G_snake_traffic_traffic.png)

The picture shows eth7 sending and eth8 receiving and checking. Similarly, reverse flow is created to realize bidirectional streaming test. Note that it is better to modify the source and destination MAC addresses of Layer 2 packets.

Final streaming test:
![](https://rancho333.github.io/pictures/questone2a_snake_traffic_100G_result.png)

As you can see， no packet loss.

Check the packets counters in Bcmsh.
```
drivshell>show c CLMIB_RPOK.ce
show c CLMIB_RPOK.ce
CLMIB_RPOK.ce0		    :	     23,803,850,505		    +13 	      1/s
CLMIB_RPOK.ce1		    :	     30,512,888,521		    +13 	      1/s
CLMIB_RPOK.ce2		    :	     23,803,849,548		     +8
CLMIB_RPOK.ce3		    :	     30,512,889,476		     +8
CLMIB_RPOK.ce4		    :	     23,803,848,543		    +11 	      1/s
CLMIB_RPOK.ce5		    :	     30,512,890,437		    +11 	      1/s
drivshell>show c CLMIB_RFCS
show c CLMIB_RFCS
drivshell>
```

# snake traffic test for 25G

Ixia don't have 25G ports, so i use 100G of ixia connet to 100G port of Questone2A and just send 25% line rate to test 25G port of Questone2A. The test environment tpology is show as below picture.
![](https://rancho333.github.io/pictures/questone2a_snake_traffic_25G_topology.png)

sonic configuration:
```
drivshell>vlan clear
vlan clear
drivshell>vlan remove 1 pbm=ce
vlan remove 1 pbm=ce
drivshell>vlan remove 1 pbm=xe
vlan remove 1 pbm=xe

drivshell>vlan create 100 pbm=xe1,xe2 ubm=xe1,xe2; pvlan set xe1,xe2 100
23,xe24; pvlan set xe23,xe24 111
vlan create 112 pbm=xe25,xe26 ubm=xe25,xe26; pvlan set xe25,xe26 112
vlan create 113 pbm=xe27,xe28 ubm=xe27,xe28; pvlan set xe27,xe28 113
vlan create 114 pbm=xe29,xe30 ubm=xe29,xe30; pvlan set xe29,xe30 114
pbm=xe31,xe32 ubm=xe31,xe32; pvlan set xe31,xe32 115
vlan create 116 pbm=xe33,xe34 ubm=xe33,xe34; pvlan set xe33,xe34 116
vlan create 117 pbm=xe35,xe36 ubm=xe35,xe36; pvlan set xe35,xe36 117
vlan create 118 pbm=xe37,xe38 ubm=xe37,xe38; pvlan set xe37,xe38 vlan create 101 pbm=xe3,xe4 ubm=xe3,xe4; pvlan set xe3,xe4 101
vlan create 102 pbm=xe5,xe6 ubm=xe5,xe6; pvlan set xe5,xe6 102
vlan create 100 pbm=xe1,xe2 ubm=xe1,xe2; pvlan set xe1,xe2 100
vlan create 101 pbm=xe3,xe4 ubm=xe3,xe4; pvlan set xe3,xe4 101
vlan create 102 pbm=xe5,xe6 ubm=xe5,xe6; pvlan set xe5,xe6 102
vlan create 103 pbm=xe7,xe8 ubm=xe7,xe8; pvlan set xe7,xe8 103
drivshell>vlan create 101 pbm=xe3,xevlan create 104 pbm=xe9,xe10 ubm=xe9,xe10; pvlan set xe9,xe10 104
4 ubm=xe3,xe4; pvlan set xe3,xe4 101
vlan create 104 pbm=xe9,xe10 ubm=xe9,xe10; pvlan set xe9,xe10 104
vlan create 105 pbm=xe11,xe12 ubm=xe11,xe12; pvlan set xe11,xe12 105
vlan create 106 pbm=xe13,xe14 ubm=xe13,xe14; pvlan set xe13,xe14 106
vlan create 105 pbm=xe11,xe12 ubm=xe11,xe12; pvlan set xe11,xe12 105
drivshell>vlan create 102vlan create 107 pbm=xe15,xe16 ubm=xe15,xe16; pvlan set xe15,xe16 107
 pbm=xe5,xe6 ubm=xe5,xe6; pvlan set vlan create 108 pbm=xe17,xe18 ubm=xe17,xe18; pvlan set xe17,xe18 108
vlan create 109 pbm=xe19,xe20 ubm=xe19,xe20; pvlan set xe19,xe20 109
xe5,xe6 102
vlan create 108 pbm=xe17,xe18 ubm=xe17,xe18; pvlan set xe17,xe18 108
drivshell>vlan create 103 pbm=xe7,xe8 ubm=xe7,xe8; pvlan set xe7,xe8 103
vlan create 109 pbm=xe19,xe20 ubm=xe19,xe20; pvlan set xe19,xe20 109
vlan create 110 pbm=xe21,xe22 ubm=xe21,xe22; pvlan set xe21,xe22 110
vlan create 111 pbm=xe23,xe24 ubm=xe23,xe24; pvlan set xe23,xe24 111
vlan create 110 pbm=xe21,xe22 ubm=xe21,xe22; pvlan set xe21,xe22 110
vlan create 111 pbm=xe23,xe24 ubm=xe23,xe24; pvlan set xe23,xe24 111
vlan create 112 pbm=xe25,xe26 ubm=xe25,xe26; pvlan set xe25,xe26 112
vlan create 113 pbm=xe27,xe28 ubm=xe27,xe28; pvlan set xe27,xe28 113
drivshell>vlan create 104 pbm=xe9,xe10 ubm=xe9,xe10; pvlan set xe9,xe10 104
vlan create 112 pbm=xe25,xe26 ubm=xe25,xe26; pvlan set xe25,xe26 112
drivshell>vlan create 105 pbm=xe11,xe12 ubm=xe11,xe12; pvlan set xe11,xe12 105
vlan create 113 pbm=xe27,xe28 ubm=xe27,xe28; pvlan set xe27,xe28 113
vlan create 114 pbm=xe29,xe30 ubm=xe29,xe30; pvlan set xe29,xe30 114
vlan create 115 pbm=xe31,xe32 ubm=xe31,xe32; pvlan set xe31,xe32 115
vlan create 114 pbm=xe29,xe30 ubm=xe29,xe30; pvlan set xe29,xe30 114
vlan create 115 pbm=xe31,xe32 ubm=xe31,xe32; pvlan set xe31,xe32 115
vlan create 116 pbm=xe33,xe34 ubm=xe33,xe34; pvlan set xe33,xe34 116
vlan create 117 pbm=xe35,xe36 ubm=xe35,xe36; pvlan set xe35,xe36 117
vlan create 116 pbm=xe33,xe34 ubm=xe33,xe34; pvlan set xe33,xe34 116
vlan create 117 pbm=xe35,xe36 ubm=xe35,xe36; pvlan set xe35,xe36 117
vlan create 118 pbm=xe37,xe38 ubm=xe37,xe38; pvlan set xe37,xe38 118
vlan create 119 pbm=xe39,xe40 ubm=xe39,xe40; pvlan set xe39,xe40 119
vlan create 118 pbm=xe37,xe38 ubm=xe37,xe38; pvlan set xe37,xe38 118
drivshell>vlan create 106 pbm=xe13,xe14 ubm=xe13,xe14; pvlan set xe13,xe14 106
vlan create 119 pbm=xe39,xe40 ubm=xe39,xe40; pvlan set xe39,xe40 119
vlan create 120 pbm=xe41,xe42 ubm=xe41,xe42; pvlan set xe41,xe42 120
vlan create 121 pbm=xe43,xe44 ubm=xe43,xe44; pvlan set xe43,xe44 121
vlan create 120 pbm=xe41,xe42 ubm=xe41,xe42; pvlan set xe41,xe42 120
drivshell>vlan vlan create 122 pbm=xe45,xe46 ubm=xe45,xe46; pvlan set xe45,xe46 122
create 107 pbm=xe15,xe16 ubm=xe15,xe16; pvlan set xe15,xe16 107
drivshell>vlan create 108 pbm=xe17,xe18 ubm=xe17,xe18; pvlan set xe17,xe18 108
drivshell>vlan create 109 pbm=xe19,xe20 ubm=xe19,xe20; pvlan set xe19,xe20 109
vlan create 122 pbm=xe45,xe46 ubm=xe45,xe46; pvlan set xe45,xe46 122
vlan create 123 pbm=ce6,xe0 ubm=ce6,xe0; pvlan set ce6,xe0 123
vlan create 124 pbm=ce7,xe47 ubm=ce7,xe47; pvlan set ce7,xe47 124
vlan create 123 pbm=ce6,xe0 ubm=ce6,xe0; pvlan set ce6,xe0 123
drivshell>vlan create 110 pbm=xe21,xe22 ubm=xe21,xe22; pvlan set xe21,xe22 110
drivshell>vlan create 111 pbm=xe23,xe24 ubm=xe23,xe24; pvlan set xe23,xe24 111
drivshell>vlan create 112 pbm=xe25,xe26 ubm=xe25,xe26; pvlan set xe25,xe26 112
drivshell>vlan create 113 pbm=xe27,xe28 ubm=xe27,xe28; pvlan set xe27,xe28 113
drivshell>vlan create 114 pbm=xe29,xe30 ubm=xe29,xe30; pvlan set xe29,xe30 114
drivshell>vlan create 115 pbm=xe31,xe32 ubm=xe31,xe32; pvlan set xe31,xe32 115
drivshell>vlan create 116 pbm=xe33,xe34 ubm=xe33,xe34; pvlan set xe33,xe34 116
drivshell>vlan create 117 pbm=xe35,xe36 ubm=xe35,xe36; pvlan set xe35,xe36 117
drivshell>vlan create 118 pbm=xe37,xe38 ubm=xe37,xe38; pvlan set xe37,xe38 118
drivshell>vlan create 119 pbm=xe39,xe40 ubm=xe39,xe40; pvlan set xe39,xe40 119
drivshell>vlan create 120 pbm=xe41,xe42 ubm=xe41,xe42; pvlan set xe41,xe42 120
drivshell>vlan create 121 pbm=xe43,xe44 ubm=xe43,xe44; pvlan set xe43,xe44 121
drivshell>vlan create 122 pbm=xe45,xe46 ubm=xe45,xe46; pvlan set xe45,xe46 122
drivshell>vlan create 123 pbm=ce6,xe0 ubm=ce6,xe0; pvlan set ce6,xe0 123
drivshell>vlan create 124 pbm=ce7,xe47 ubm=ce7,xe47; pvlan set ce7,xe47 124
drivshell>
```

ixia is configured as follows:
![](https://rancho333.github.io/pictures/questone2a_snake_traffic_25G_ixia.png)

Finally, start the test to check the packet loss:
![](https://rancho333.github.io/pictures/questone2a_snake_traffic_25G_result.png)

Check the packets counters in Bcmsh.
```
drivshell>show c CLMIB_TPKT.xe
show c CLMIB_TPKT.xe
CLMIB_TPKT.xe0		    :	      1,347,751,223		     +6
CLMIB_TPKT.xe1		    :	      1,347,716,171		   +154 	      8/s
CLMIB_TPKT.xe2		    :	      1,347,683,168		    +12
CLMIB_TPKT.xe3		    :	      1,347,660,881		   +148 	      8/s
CLMIB_TPKT.xe4		    :	      1,347,633,886		    +18
CLMIB_TPKT.xe5		    :	      1,347,611,124		   +142 	      8/s
CLMIB_TPKT.xe6		    :	      1,347,585,268		    +24
CLMIB_TPKT.xe7		    :	      1,347,562,390		   +136 	      8/s
CLMIB_TPKT.xe8		    :	      1,347,536,351		    +30
CLMIB_TPKT.xe9		    :	      1,347,513,095		   +130 	      8/s
CLMIB_TPKT.xe10 	    :	      1,347,486,710		    +38 	      1/s
CLMIB_TPKT.xe11 	    :	      1,347,463,552		   +125 	      8/s
CLMIB_TPKT.xe12 	    :	      1,347,389,466		    +45 	      2/s
CLMIB_TPKT.xe13 	    :	      1,347,366,188		   +118 	      7/s
CLMIB_TPKT.xe14 	    :	      1,347,341,022		    +50 	      2/s
CLMIB_TPKT.xe15 	    :	      1,347,317,516		   +109 	      5/s
CLMIB_TPKT.xe16 	    :	      1,347,292,618		    +57 	      3/s
CLMIB_TPKT.xe17 	    :	      1,347,269,117		   +102 	      4/s
CLMIB_TPKT.xe18 	    :	      1,347,243,912		    +64 	      3/s
CLMIB_TPKT.xe19 	    :	      1,347,215,748		    +95 	      3/s
CLMIB_TPKT.xe20 	    :	      1,347,191,194		    +69 	      3/s
CLMIB_TPKT.xe21 	    :	      1,347,166,549		    +88 	      3/s
CLMIB_TPKT.xe22 	    :	      1,347,141,524		    +78 	      4/s
CLMIB_TPKT.xe23 	    :	      1,347,116,886		    +83 	      3/s
CLMIB_TPKT.xe24 	    :	      1,348,186,469		    +83 	      4/s
CLMIB_TPKT.xe25 	    :	      1,348,161,948		    +74 	      1/s
CLMIB_TPKT.xe26 	    :	      1,348,136,316		    +90 	      4/s
CLMIB_TPKT.xe27 	    :	      1,348,106,807		    +69 	      1/s
CLMIB_TPKT.xe28 	    :	      1,348,079,919		    +95 	      4/s
CLMIB_TPKT.xe29 	    :	      1,348,048,460		    +62 	      1/s
CLMIB_TPKT.xe30 	    :	      1,348,018,298		   +102 	      4/s
CLMIB_TPKT.xe31 	    :	      1,347,983,062		    +57 	      1/s
CLMIB_TPKT.xe32 	    :	      1,347,951,303		   +107 	      4/s
CLMIB_TPKT.xe33 	    :	      1,347,917,231		    +50 	      1/s
CLMIB_TPKT.xe34 	    :	      1,347,886,358		   +116 	      5/s
CLMIB_TPKT.xe35 	    :	      1,347,853,385		    +45 	      1/s
CLMIB_TPKT.xe36 	    :	      1,347,092,884		   +121 	      5/s
CLMIB_TPKT.xe37 	    :	      1,347,067,278		    +38 	      1/s
CLMIB_TPKT.xe38 	    :	      1,347,043,968		   +127 	      5/s
CLMIB_TPKT.xe39 	    :	      1,347,017,351		    +32 	      1/s
CLMIB_TPKT.xe40 	    :	      1,346,994,279		   +135 	      6/s
CLMIB_TPKT.xe41 	    :	      1,346,968,532		    +26 	      1/s
CLMIB_TPKT.xe42 	    :	      1,346,946,104		   +142 	      6/s
CLMIB_TPKT.xe43 	    :	      1,346,917,004		    +19
CLMIB_TPKT.xe44 	    :	      1,346,894,475		   +148 	      7/s
CLMIB_TPKT.xe45 	    :	      1,346,866,979		    +12
CLMIB_TPKT.xe46 	    :	      1,346,843,674		   +154 	      7/s
CLMIB_TPKT.xe47 	    :	      1,346,816,974		     +6
drivshell>
drivshell>show c CLMIB_RFCS
show c CLMIB_RFCS
drivshell>
```