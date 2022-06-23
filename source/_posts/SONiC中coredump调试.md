---
title: SONiC中coredump调试
date: 2021-08-23 10:01:28
tags: 
    - SONiC
    - coredump
---

# 写在前面

在进行`sonic-testbed`中的`process monitor`用例调试的时候，发现`swss`容器中的`orchagent`进程产生coredump导致测试失败。本文将简单介绍coredump以及如何编译debug版本SONiC进行coredump调试。
<!--more-->

# SONiC中coredump的一些配置

由于SONiC中的服务基本上都是运行在docker中，所以需要使能docker产生coredump。需要做两件事：
1. 在host上配置`/proc/sys/kernel/core_pattern`, 配置core文件路径以及名称
2. 在docker中配置core文件大小限制`ulimit -c unlimited`

下面是SONiC对core文件路径及名称的配置：
```
root@cel-brixia2-01:/home/admin# cat /proc/sys/kernel/core_pattern 
|/usr/local/bin/coredump-compress %e %t %p %P
root@cel-brixia2-01:/home/admin# 
root@cel-brixia2-01:/home/admin# cat /usr/local/bin/coredump-compress
#!/bin/bash

# Collect all parameters in order and build a file name prefix
PREFIX=""
while [[ $# > 1 ]]; do
    PREFIX=${PREFIX}$1.
    shift
done

if [ $# > 0 ]; then
    ns=`xargs -0 -L1 -a /proc/${1}/environ | grep -e "^NAMESPACE_ID" | cut -f2 -d'='`
    if [ ! -z ${ns} ]; then
        PREFIX=${PREFIX}${ns}.
    fi
fi

/bin/gzip -1 - > /var/core/${PREFIX}core.gz
```
即当产生core文件时，我们可以在`/var/core/`路径下找到.

# SONiC中core文件调试

普通的SONiC版本中是不带`gdb`工具的，`elf`文件也都是`stripped`。在编译debug版本的时候，需要做两件事：
1. 在docker中安装gdb工具
2. 对`elf` not stripped或者主动添加`symbols`信息

SONiC的编译系统提供了很方便的方法供用户编译debug版本，以`swss`为例做步骤说明。

1. 修改`rules/config`中的字段如下：
```
-# INSTALL_DEBUG_TOOLS = y
+INSTALL_DEBUG_TOOLS = y

-#SONIC_DEBUGGING_ON = y
-#SONIC_PROFILING_ON = y
+SONIC_DEBUGGING_ON = y
+SONIC_PROFILING_ON = y
```

2. 使用`make list`找到需要对应的target，如
```
target/docker-orchagent-dbg.gz
```
之后`make target/docker-orchagent-dbg.gz`生成debug版本的容器，然后拷贝到设备上。

3. 加载镜像，生成debug版的容器
    - 使用`docker load -i docker-orchagent-dbg.gz`载入编译好的debug版镜像
    - 删除原来的容器`docker rm swss`
    - 修改`/usr/bin/swss.sh` 文件`--name=$DOCKERNAME docker-orchagent-dbg:latest`，指定使用debug版镜像生成容器
    - `service swss stop` && `service swss start` 生成新的容器

4. 对core文件进行调试
将`/var/core`下的core文件拷到docker中，可以参见`/usr/bin/swss.sh`中`create docker`时挂载的目录，一般host上的`/etc/sonic`会以只读的方式挂载到docker中。

使用`gdb /usr/bin/orchagent core.file`进行调试的时候，我们会发现gdb是从`/usr/lib/debug/.build-id/`下面读取symbols信息的。SONiC采用模块化增量的方式进行编译，原有的`elf`文件依然是`stripped`状态，但是在debug版本中会将里面的symbols信息提取出来放到一个deb包中，如`swss-dbg_1.0.0_amd64.deb`。

5. 这是针对某一具体的debug容器替换说明，如果对整个SONiC编译debug版本,修改完`rules/config`后，直接`make target/sonic-broadcom.bin`即可。