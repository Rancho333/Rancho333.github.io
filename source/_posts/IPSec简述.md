---
title: IPSec简述
date: 2022-08-01 14:26:57
tags: vpn
---
# 写在前面
在[GRE简述](https://rancho333.github.io/2022/07/29/GRE%E7%AE%80%E8%BF%B0/)中描述了一种vpn的实现，但是GRE没有认证，加密，数据完整性验证等特性，是一个不安全的封装协议，所以实际使用中都是结合IPSec一起。本文介绍VPN的第二种常见实现——IPSec.

# IPSec简介
IPSec通过认证头AH(authentication header, 协议号51)和封装安全载荷ESP(encapsulating security payload)这两个安全协议来实现。此外可以通过IKE完成密钥交换。IPSec由这三个协议组成。

IPSec有两种封装模式：
- 传输模式：在传输模式下，AH或ESP被插入到IP头之后但在所有传输层协议之前，或所有其它IPSec协议之前。
- 隧道模式：在隧道模式下，AH或ESP插在原始IP头之前，另外生成一个新的IP头放在AH或ESP之前。

传输模式用于两台主机之间的通讯，或者一台主机和一个安全网关之间的通讯。在传输模式下，对报文加密和解密的两台设备本身必须是报文的原始发送者和最终接收者。

通常，在两个安全网关之间的数据流量，绝大部分都不是安全网关本身的流量，因此安全网关之间一般不使用传输模式，而是使用隧道模式。在一个安全网关被加密的报文，只有另一个安全网关才能被解密。

IPSec的两大核心功能分别是*加密*和*认证*，ipsec使用对称加密算法，主要包括DES、3DES和AES。对于认证，在发送消息之前会先使用验证算法和验证密钥对消息进行处理，得到数字签名；另一方收到消息后同样计算签名，然后对比两端的签名，如果相同则消息没有被篡改。常用的验证算法有MD5和SHA系列。

AH(IP协议号51)可提供数据源验证和数据完整性校验功能；
ESP(IP协议号50)除提供数据源验证和数据完整性校验功能外，还提供对IP报文的加密功能。ESP的工作原理是在每一个数据包的标准IP包头后面添加一个ESP报文头，并在数据包后面追加一个ESP尾。与AH协议不同的是，ESP将需要保护的报文进行加密后再封装到IP包中，以保证数据的机密性。

两者均可单独使用，也可一起配合使用。各自作用范围如下图所示：
![](https://rancho333.github.io/pictures/ipsec_range.png)

可见，AH提供的认证服务要强于ESP，同时使用AH和ESP时，设备支持的AH和ESP联合使用方式为：先对报文进行ESP封装，再对报文进行AH封装，封装之后的报文从内到外一次是原始IP报文，ESP报文头，AH报文头和外部IP头。

IPSec除了能为其它隧道协议提供数据保护外，IPSec也可自己单独作为隧道协议来提供隧道的建立。如果IPSec自己单独作为隧道协议来使用，那么IPsec就不需要任何其它隧道协议就能独立实现VPN功能。这两种使用方式由管理员的配置来决定。需要注意的是，IPSec目前只支持ipv4单播。

IPSec通过定义一些方法来保护特定的IP数据报，这些流量如何被保护，还有流量发给谁。

### 安全联盟
IPSec在两个端点之间提供安全通信，端点被称为IPSec对等体。
IPSec中通信双方建立的连接叫做安全联盟(security association)，顾名思义，通信双方结成盟友，使用相同的协议(AH、ESP还是两者结合)、封装模式(传输模式还是隧道模式)、加密算法(DES、3DES、AES)、加密密钥、验证算法、验证密钥、密钥周期。SA是IPSec的基础，也是IPSec的*本质*. SA并不是隧道，形象的说是一份合约，协商双方共同遵守的合约。

建立SA的方式有两种，手工配置和IKE自动协商。

安全联盟是单向的逻辑连接，在两个对等体之间的双向通信，最少需要两个SA来分别对两个方向的数据流进行安全保护。同时，如果两个对等体希望同时使用AH和ESP来进行安全通信，则每个对等体都会针对每一种协议来构建一个独立的SA。如下图所示：
![](https://rancho333.github.io/pictures/ipsec_security.png)

SA由一个三元组来唯一标识，这个三元组包括SPI(security parameter index, 安全参数索引)、目的IP地址、安全协议号(AH或ESP)。

SPI是用于唯一标识SA的一个32比特数值，他在AH和ESP头中传输。在手工配置SA时，需要手工指定SPI的取值。使用IKE协商产生SA时，SPI将随机生成。

通过IKE协商建立的SA具有生存周期，手工方式建立的SA永不老化。IKE协商建立的SA的生存周期有两种定义方式：
- 基于时间的生存周期，定义了一个SA从建立到失效的时间
- 基于流量的生存周期，定义了一个SA允许处理的最大流量
生存周期到达指定的时间或指定的流量，SA就会失效。SA失效前，IKE将为IPSec协商建立新的SA，这样，在旧的SA失效前新的SA就已经准备好了。

建立安全联盟最直接的方式就是分别在两端认为设定好封装模式、加密算法、加密密钥、验证算法、验证密钥。

### IPSec虚拟隧道接口
IPSec虚拟隧道接口是一种支持路由的三层逻辑接口，它可以支持动态路由协议，所有路由到IPSec虚拟隧道接口的报文都将进行IPSec保护，同时还可以支持对组播流量的保护，和实现GRE的tunnel接口类似。使用虚拟隧道接口有以下优点：
- 简化配置：通过路由来确定那些数据流进行IPSec保护。
- 减少开销：在保护远程接入用户流量的组网应用中，在IPSec虚拟隧道接口处进行报文封装，与IPSec over GRE或者IPSec over L2TP方式的隧道封装相比，无需额外为入隧道流量加封装GRE或者L2TP头，减少了报文封装层次，节省了带宽。
- 业务应用更加灵活：IPsec虚拟隧道接口在实施过程中明确地区分出“加密前”和“加密后”两个阶段，用户可以根据不同的组网需求灵活选择其它业务（例如NAT、QoS）实施的阶段。例如，如果用户希望对IPsec封装前的报文应用QoS，则可以在IPsec虚拟隧道接口上应用QoS策略；如果希望对IPsec封装后的报文应用QoS，则可以在物理接口上应用QoS策略。

使用IPSec虚拟隧道口封装解封装报文如图所示：
![](https://rancho333.github.io/pictures/ipsec_enca.png)

### IKE
在实施IPSec的过程中，可以使用IKE(internet key exchange)协议来建立SA
IKE是个混个协议，其中包含部分Oakley协议，内置在ISAKMP(internet security association and key management protocol)协议中的部分SKEME协议，所以IKE也可以写为ISAKMP/Oakley，它是针对密钥安全，用来保证密钥的安全传输、交换以及存储，主要是对密钥进行操作，并不对用户的实际数据进行操作。

IKE不是在网络上直接传输密钥，而是通过一系列数据的交换，最终计算出双方共享的密钥，并且即使第三者截获了双方用于计算密钥的所有交换数据，也不足以计算出真正的密钥。

IKE具有一套自保护机制，可以在不安全的网络上安全的认证身份、分发密钥、建立IPSec SA。

数据认证有如下两方面概念：
- 身份认证：身份认证确认通信双方的身份。支持两种认证方法：预共享密钥(pre-shared-key)认证基于PKI的数字签名(rsa-signature)认证。
- 身份保护：身份数据在密钥产生之后加密传送，实现了对身份数据的保护。

DH(Diffie-Hellman，交换及密钥分发)算法是一种公共密钥算法。通信双方在不传输密钥的情况下通过交换一些数据，计算出共享的密钥。即使第三者截获了双方用于计算密钥的所有交换数据，由于其复杂度很高，不足以计算出真正的密钥。所以，DH交换技术可以保证双方能够安全地获得公有信息。

PFS(perfect forward secrecy，完善的前向安全性)特性是一种安全特性，指一个密钥被破解，并不影响其它密钥的安全性，因为这些密钥之间没有派生关系。对于IPSec，是通过在IKE阶段2协商中增加一次密钥交换来实现的。PFS特性时DH算法保障的。

IKE的交换过程：
通过IKE方式建立的SA实际有两组，分别为IKE SA和IPSec SA, 两个SA分别定义了如何保护密钥及如何保护数据，其实这两个SA都是IKE建立起来的，所以IKE的整个运行过程拆分成两个phase。
- phase one：通信各方彼此间建立一个已通过身份认证和安全保护的通道，即建立一个ISAKMP SA。第一阶段有主模式(main mode)和野蛮模式(aggressive mode)两种IKE交换方式。协商的安全策略包括：
    - 认证方式(authentication)：pre-shard keys, public key infrastructure，RSA encrypted nonce，默认是PKI
    - 加密算法：加密数据
    - Hash算法(HMAC)：生成摘要，完整性认证
    - 密钥算法：计算密钥的方式
    - lifetime
    - NAT穿越(NAT traversal): 默认开启，无须手工配置

- phase two：用在第一阶段建立的安全隧道为IPSec协商安全服务，即为IPSec协商具体的SA，建立最终的IP数据安全传输的IPSec SA。同样需要协商出一套安全策略，包括：
    - 加密算法
    - hash算法(HMAC)
    - lifetime
    - IPSec mode：tunnel mode和transport mode，默认是tunnel mode和transport

从上可看出IPSec SA中没有协商认证方式和密钥算法，因为IKE SA中已经认证过了，所以后面不需要再认证，并且密钥是在IKE SA已经完成的。

IPSec与IKE的关系如下：
![](https://rancho333.github.io/pictures/ipsec_ike.png)

- IKE是UDP之上的一个应用层协议，是IPSec的信令协议
- IKE为IPSec协商建立SA，并把建立的参数及生成的密钥交给IPSec
- IPSec使用IKE建立的SA对IP报文加密或认证处理

# IPSec实验
## IOS中关于IPSec的一些配置概念
- transform set
transform set是一组算法集合，通过它来定义使用怎样的算法来封装数据包，比如之前所说的ESP封装，AH封装都需要通过transform set来定义，还可以定义其它一些加密算法以及HMAC算法。通过transform set，就可以让用户来选择保护数据的强度，因此transform set就是定义数据包是受到怎样的保护。

- crypto isakmp
    定义IKE SA的协商参数

- crypto map
Crypto map是思科的IOS中配置IPSec的组件，执行两个主要功能：
1. 选择需要加密处理的数据（通过ACL匹配）
2. 定义数据加密的策略以及数据发往的对端
3. 定义IPSec的mode

crypto map中的策略是分组存放的，以序号区分，如果一个crypto map有多个策略组，则最低号码的组有限。当配置完crypto map后，需要应用到接口上才能生效，并且一个接口只能应用一个crypto map.

crypto map还分为静态map和动态map，简单区分，就是数据发往的对端是否固定，如果是动态map，那么对端是不固定的，在存在隧道时，也就表示隧道的终点时不固定的，但源始终是自己。

## eveng仿真实验
IPSec vpn配置时，有如下几个重要步骤：
- 配置IKE(ISAKMP)策略
- 定义认证标识
- 配置IPSec transform
- 定义感兴趣流量
- 创建crypto map
- 将crypto map应用于接口

实验拓扑如图所示(lan-to-lan)：
![](https://rancho333.github.io/pictures/ipsec_topology.png)

拓扑说明如下：
vpc4和vpc5分别属于两个私网，网关分别指向R1和R3, R2仿真internet, R2上不配置任何路由，只负责和R1、R3之间直连链路的通信。R1和R3上配置默认路由指向R2。因为R2上没有VPC4、VPC5网段的路由，所以两者之间不通。

基础网络环境配置如下(ip和默认路由)：
{% tabs tab,1 %}
<!-- tab VPC4-->
```
VPC4> show

NAME   IP/MASK              GATEWAY                             GATEWAY
VPC4   14.1.1.4/24          14.1.1.1
```
<!-- endtab -->
<!-- tab R1-->
```
interface Ethernet0/0
 ip address 12.1.1.1 255.255.255.0
!
interface Ethernet0/1
 ip address 14.1.1.1 255.255.255.0
!
ip route 0.0.0.0 0.0.0.0 12.1.1.2       // 默认路由指向internet
```
<!-- endtab -->
<!-- tab R2-->
```
interface Ethernet0/0
 ip address 12.1.1.2 255.255.255.0
!
interface Ethernet0/1
 ip address 23.1.1.2 255.255.255.0
!
```
<!-- endtab -->
<!-- tab R3-->
```
interface Ethernet0/0
 ip address 23.1.1.3 255.255.255.0
!
interface Ethernet0/1
 ip address 35.1.1.3 255.255.255.0
!
ip route 0.0.0.0 0.0.0.0 23.1.1.2       // 默认路由指向internet
``` 
<!-- endtab -->
<!-- tab VPC5-->
```
VPC5> show

NAME   IP/MASK              GATEWAY                             GATEWAY
VPC5   35.1.1.5/24          35.1.1.3
```
<!-- endtab -->
{% endtabs %}

检测网络的连通性：
```
VPC5> ping 35.1.1.3 -c 1

84 bytes from 35.1.1.3 icmp_seq=1 ttl=255 time=0.356 ms

VPC5> ping 23.1.1.2 -c 1

23.1.1.2 icmp_seq=1 timeout         // R2上没有VPC5的回程路由，所以不通
```

接下来配置IPSec vpn：
{% tabs tab,1 %}
<!-- tab R1-->
```
// 配置IKE SA策略
crypto isakmp policy 1            // 策略优先级
 encr 3des                         // 加密方式
 hash md5                           // 报文摘要算法，报文完整性验证
 authentication pre-share           // 认证方式
 group 2                            // 密钥算法

// 定义认证标识
crypto isakmp key 0 rancho address 23.1.1.3       // 因为认证方式为pre-share, 所以需要定义认证密码，此处密码为`rancho`， 对端地址为23.1.1.3，双方密码必须一致。0表示密码在show run中明文显示

//  定义 ipsec transform
crypto ipsec transform-set rancho esp-3des esp-sha-hmac     // transform组名字为`rancho`，只采用esp协议加密认证，加密方式为3des，校验方式为sha-hmac
 mode tunnel            // IPSec默认模式就是tunnel，不需要配置

// 定义感兴趣的数据流
access-list 100 permit ip 14.1.1.0 0.0.0.255 35.1.1.0 0.0.0.255     // 两端的私网网段

 // 定义crypto map
crypto map rancho 1 ipsec-isakmp    // map名字叫`rancho`，序号为1，可以有多个，越小越优
 set peer 23.1.1.3                  // 隧道对端为23.1.1.3
 set transform-set rancho           // 调用名为rancho的transform 组
 match address 100                  // 指定ACL 100为保护的流量
 
 // 将crypto应用在接口上
interface Ethernet0/0
 crypto map rancho                  // 在eth0/0上应用名为rancho的crypto map
```
<!-- endtab -->
<!-- tab R3-->
```
crypto isakmp policy 1
 encr 3des
 hash md5
 authentication pre-share
 group 2
crypto isakmp key rancho address 12.1.1.1       
!
crypto ipsec transform-set rancho esp-3des esp-sha-hmac 
 mode tunnel
!
crypto map rancho 1 ipsec-isakmp 
 set peer 12.1.1.1
 set transform-set rancho 
 match address 100
!
interface Ethernet0/0
 crypto map rancho
!
access-list 100 permit ip 35.1.1.0 0.0.0.255 14.1.1.0 0.0.0.255
```
<!-- endtab -->
{% endtabs %}

至此，IPSec隧道两端的配置就完成了。但是IKE SA并没有建立：
```
R1#show crypto isakmp peers 
R1#show crypto isakmp sa    
IPv4 Crypto ISAKMP SA
dst             src             state          conn-id status

IPv6 Crypto ISAKMP SA

R1#
```
需要业务流量来触发IKE SA的建立：
```
VPC4> ping 35.1.1.5
35.1.1.5 icmp_seq=1 timeout
84 bytes from 35.1.1.5 icmp_seq=2 ttl=62 time=2.828 ms
```
在R2的eth0上抓包：
![](https://rancho333.github.io/pictures/ipsec_esp_packet.png)

可以看到先通过IKE建立SA，之后的ICMP报文封装在ESP报文中，在隧道两端传递。

最后查看一下配置和状态：
```
// 查看isakmp policy策略
R1#show crypto isakmp policy 

Global IKE policy
Protection suite of priority 1
	encryption algorithm:	Three key triple DES
	hash algorithm:		Message Digest 5
	authentication method:	Pre-Shared Key
	Diffie-Hellman group:	#2 (1024 bit)
	lifetime:		86400 seconds, no volume limit

R1#show crypto isakmp key           // 查看phase one认证密码
R1#show crypto isakmp sa            // 查看IKE SA
R1#show crypto isakmp peers         // 查看IKE peers
R1#show crypto ipsec transform-set      // 查看IPSec transform
R1#show crypto ipsec sa                 // 查看IPSec SA
R1#show crypto map                  // 查看crypto map
```