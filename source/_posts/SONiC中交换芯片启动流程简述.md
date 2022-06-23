---
title: SONiC中交换芯片启动流程简述
date: 2021-07-21 17:15:56
tags: SONiC
---

# 写在前面
本文基于SONiC 202012分支进行交换芯片启动流程的分析。源码部分主要涉及`sonic-swss`和`sonic-sairedis`以及`ocp-sai`. 一句话说明所有流程：swss模块通知syncd模块进行ASIC初始化。
<!--more-->

## 模块主要功能说明

docker swss中的模块主要可以分为三类:
1. 收集信息写往APP_DB，如portsyncd, intfsyncd（*syncd）
2. 订阅APP_DB将数据写往ASIC_DB，如orchagent（是APP_DB的consumer，同时也是ASIC_DB的producer）
3. 收集数据写往kernel， IntfMgrd和VlanMgrd

docker syncd中主要是syncd模块，该模块订阅ASIC_DB,之后调用sai api操作sdk, 完成数据的下发。

# 从swss开始

搞清楚ASIC的启动流程，实际上上就是弄清楚orchagent和syncd这两个进程的初始化和通信的过程。

在docker syncd的启动脚本中，我们可以看到其依赖关系。
![](https://rancho333.github.io/pictures/syncd_service.png)

docker swss中orchagent负责通知syncd进行ASIC初始化， 对于orchagent主要理解下面两行代码：
![](https://rancho333.github.io/pictures/orchagent_init.png)

这里简要说明一下`OCP SAI`的工作方式，对应的源码在`src/sonic-sairedis/SAI`, 这里面定义了sai的data以及functions，还有一些metadata操作方式，而数据的初始化以及函数的实现由芯片厂商实现，通过动态库的方式提供。syncd编译时会链接到libsai，这样我们在syncd中就可以调用sai api完成对SDK的控制。

与此类似的，在`sonic-sairedis`中提供一个libsairedis的动态库(源码在`src/sonic-sairedis/lib`)，这里面同样对ocp sai进行实现，不过实现的对象是redis，这样在orchagent中就可以调用sai api完成对redis的操作。

对于`initSaiApi`：
![](https://rancho333.github.io/pictures/saiapi_init.png)

对于`sai_api_query`, 在`src/sonic-sairedis/SAI/inc/sai.h`中是对其的定义，在`src/sonic-sairedis/lib/src/sai_redis_interfacequery.cpp`中是对其的实现。借用`API`宏完成对其初始化。
![](https://rancho333.github.io/pictures/saiapi_query.png)

注意`sai_apis_t`结构体是`src/sonic-sairedis/SAI/meta/parse.pl`perl脚本自动生成的，生成的文件名为`saimetadata.h`,结构体成员为各功能模块的结构体指针。

以`sai_switch_api`为例：
![](https://rancho333.github.io/pictures/sai_switch_api.png)
到这里就完成了对OCP SAI的封装调用，而最后对redis的操作，201911之后的版本，实际的redis操作函数都使用宏来生成。
```
REDIS_GENERIC_QUAD
REDIS_CREATE
```

这部分操作的就是将`create_switch`的信息写到`ASIC_DB`, `syncd`进程收到发布的消息之后进行真正的SDK初始化操作。
![](https://rancho333.github.io/pictures/syslog.png)

## create_switch分析

`redis_create_switch`函数由宏定义展开：
```
REDIS_GENERIC_QUAD(OT,ot)        sai_redis.h
REDIS_CREATE(OT,ot)              sai_redis.h
```
![](https://rancho333.github.io/pictures/define_redis_create.png)

`redis_sai`的定义如下：
```
std::shared_ptr<SaiInterface> redis_sai = std::make_shared<ClientServerSai>();    sai_redis_interfacequery.cpp

SaiInterface是父类， ClientServerSai是其子类
                    RemoteSaiInterface同样是SaiInterface子类
                        RedisRemoteSaiInterface又是RemoteSaiInterface的子类
```
`redis_sai`的指针类型是`SaiInterface`，根据C++的多态特性，`redis_sai->create`的最终实现在：
![](https://rancho333.github.io/pictures/redis_sai_create.png)

# syncd初始化ASIC

直接从初始化sai api开始(由于201911之后的版本syncd模块重构了，变得更加难看，下面的分析基于201911版本，基本流程都差不多)：
![](https://rancho333.github.io/pictures/syncd_saiapi_init.png)

在mainloop里面进入`processEvent`流程，里面进入`initviewmode`:
![](https://rancho333.github.io/pictures/initview_mode.png)

之后：
![](https://rancho333.github.io/pictures/on_switch_create.png)

然后调用sai api完成交换芯片初始化指令的下发：
![](https://rancho333.github.io/pictures/create_switch.png)

最后就是sai模块中厂商对应的实现：
![](https://rancho333.github.io/pictures/brcm_sai.png)