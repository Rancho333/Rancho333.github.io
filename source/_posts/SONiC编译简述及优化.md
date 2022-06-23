---
title: SONiC编译简述及优化
date: 2020-12-15 09:58:41
categories: SONiC
tags: 
    - SONiC
    - 编译
---

# 写在前面
SONiC在docker中完成编译，docker image基于debian(jessie, stretch, buster)完成构建。201807及其之前的版本使用的是jessie, 202006及其之后的版本使用的是buster, 我们现阶段主要使用stretch。SONiC的编译大致分成三个阶段。
<!--more-->
```
1. git submodules初始化。对应make init
2. 编译环境构建。对应的是Makefile.work中的DOCKER_BASE_BUILD与DOCKER_BUILD，编译环境只需要在第一次使用时进行构建。
3. 主目标编译（sonic-platform.bin）。这里面可以分为kernel编译，外部功能编译（platform, src等），根文件系统的构建。对应的是make target/sonic-platform.bin.
```

# submodules初始化优化建议
执行`make init`之前，项目文件大小
```
[rancho git]$ du -h --max-depth=1
76M     ./bytedance-sonic
```
执行之后的项目文件大小
```
[rancho git]$ du -h --max-depth=1
1.9G     ./bytedance-sonic
```
整个过程耗时约22分钟（网络环境不同会有差异），总共27个外部modules。只会在第一次编译项目时进行构建。基于项目管控以及子模块自开发的角度，后续可以将modules迁移到内部gitlab上。字节项目中的sonic-platform-common模块现在就是这样管理的。


# 编译环境构建的优化
SONiC通过Dockerfile对每个用户都构建一个编译环境，对于单用户环境这种方式合适，对于使用Linux服务器的**多用户环境**而言，这种方式很不合适，docker image应该给所有用户复用，而不是针对每个用户构建一个内容相同只是名字不同的image。

## 缺点说明

```
1. 消耗大量存储资源。可使用docker images | grep sonic 查看。
2. 消耗大量网络资源，构建时下载重复数据
3. 消耗大量时间，通过源码完成编译环境的构建大概需要一小时，使用优化后的方法只需要一分钟乃至更少
```

## 解决方法
复用相同版本的docker镜像进行编译

## 如何操作
### 对于复用docker镜像搭建编译环境的用户
1. `docker images`查看服务器上是否有所需版本的image, image命名规则为:sonic-version-debian_version, tag为public，例如:sonic-201911-stretch:public，如果有了,跳过步骤2；
2. 获取对应版本image的tar.gz文件
    1. 我在10.204.112.46上搭建了一个文件服务器，201911-stretch的编译镜像存放在上面，可以通过该链接`http://10.204.112.46:8081/sonic-201911/sonic-201911-stretch.tar.gz`获取
    2. `gzip -d sonic-version-debian_version.tar.gz`
    3. `docker load --input sonic-version-debian_version.tar`
3. 修改Makefile, 文件位于项目根目录下
    1. 修改Makefile文件如下所示
    ```
    diff --git a/Makefile b/Makefile
    index 13a3f247..542f4077 100644--- a/Makefile+++ b/Makefile
    @@ -1,6 +1,6 @@ 
    # SONiC make file 
    -NOJESSIE ?= 0
    +NOJESSIE ?= 1
    ```
    如果是202006及其之后的版本，将stretch也注释掉。我们只需要用于编译的环境。
    
    2. 修改Makefile.work文件如下所示
    ```
    diff --git a/Makefile.work b/Makefile.work
    index 14c433e4..e7232264 100644
    --- a/Makefile.work
    +++ b/Makefile.work
    @@ -78,10 +78,12 @@ SLAVE_DIR = sonic-slave-stretch
    endif
    -   SLAVE_BASE_TAG = $(shell CONFIGURED_ARCH=$(CONFIGURED_ARCH) j2 $(SLAVE_DIR)/Dockerfile.j2 > $(SLAVE_DIR)/Dockerfile && sha1sum $(SLAVE_DIR)/Dockerfile | awk '{print substr($$1,0,11);}')
    -   SLAVE_TAG = $(shell cat $(SLAVE_DIR)/Dockerfile.user $(SLAVE_DIR)/Dockerfile | sha1sum | awk '{print substr($$1,0,11);}')
    -   SLAVE_BASE_IMAGE = $(SLAVE_DIR)
    -   SLAVE_IMAGE = $(SLAVE_BASE_IMAGE)-$(USER)
    +   #SLAVE_BASE_TAG = $(shell CONFIGURED_ARCH=$(CONFIGURED_ARCH) j2 $(SLAVE_DIR)/Dockerfile.j2 > $     (SLAVE_DIR)/Dockerfile && sha1sum $(SLAVE_DIR)/Dockerfile | awk '{print substr($$1,0,11);}')
    +   #SLAVE_TAG = $(shell cat $(SLAVE_DIR)/Dockerfile.user $(SLAVE_DIR)/Dockerfile | sha1sum | awk '{print substr($$1,0,11);}')
    +   SLAVE_TAG = public
    +   #SLAVE_BASE_IMAGE = $(SLAVE_DIR)
    +   #SLAVE_IMAGE = $(SLAVE_BASE_IMAGE)-$(USER)
    +   SLAVE_IMAGE = sonic-201911-stretch
 
    OVERLAY_MODULE_CHECK := \
     lsmod | grep -q "^overlay " &>/dev/null || \
    @@ -113,6 +115,7 @@ DOCKER_RUN := docker run --rm=true --privileged \
     -w $(DOCKER_BUILDER_WORKDIR) \
     -e "http_proxy=$(http_proxy)" \
     -e "https_proxy=$(https_proxy)" \
    +   -u root \
     -i$(if $(TERM),t,)

    @@ -200,9 +202,9 @@ endif
        @$(OVERLAY_MODULE_CHECK)
        
    -       @docker inspect --type image $(SLAVE_BASE_IMAGE):$(SLAVE_BASE_TAG) &> /dev/null || \
    -           { echo Image $(SLAVE_BASE_IMAGE):$(SLAVE_BASE_TAG) not found. Building... ; \
    -           $(DOCKER_BASE_BUILD) ; }
    +       #@docker inspect --type image $(SLAVE_BASE_IMAGE):$(SLAVE_BASE_TAG) &> /dev/null || \
    +           #{ echo Image $(SLAVE_BASE_IMAGE):$(SLAVE_BASE_TAG) not found. Building... ; \
    +           #$(DOCKER_BASE_BUILD) ; }
            @docker inspect --type image $(SLAVE_IMAGE):$(SLAVE_TAG) &> /dev/null || \
                { echo Image $(SLAVE_IMAGE):$(SLAVE_TAG) not found. Building... ; \
                $(DOCKER_BUILD) ; }
    @@ -222,9 +224,9 @@ sonic-slave-build :
 
    sonic-slave-bash :
            @$(OVERLAY_MODULE_CHECK)
    -       @docker inspect --type image $(SLAVE_BASE_IMAGE):$(SLAVE_BASE_TAG) &> /dev/null || \
    -           { echo Image $(SLAVE_BASE_IMAGE):$(SLAVE_BASE_TAG) not found. Building... ; \
    -           $(DOCKER_BASE_BUILD) ; }
    +       #@docker inspect --type image $(SLAVE_BASE_IMAGE):$(SLAVE_BASE_TAG) &> /dev/null || \
    +           #{ echo Image $(SLAVE_BASE_IMAGE):$(SLAVE_BASE_TAG) not found. Building... ; \
    +           #$(DOCKER_BASE_BUILD) ; }
            @docker inspect --type image $(SLAVE_IMAGE):$(SLAVE_TAG) &> /dev/null || \
                { echo Image $(SLAVE_IMAGE):$(SLAVE_TAG) not found. Building... ; \
                $(DOCKER_BUILD) ; }
    @@ -232,7 +234,7 @@ sonic-slave-bash :
 
    showtag:
            @echo $(SLAVE_IMAGE):$(SLAVE_TAG)
    -       @echo $(SLAVE_BASE_IMAGE):$(SLAVE_BASE_TAG)
    +       #@echo $(SLAVE_BASE_IMAGE):$(SLAVE_BASE_TAG)

    ```
    将SLAVE_IMAGE和SLAVE_TAG修改为复用image及其tag，抛弃SLAVE_BASE_IMAGE的使用。

    3. 通过`make showtag`检查编译环境是否加载正确
    ```
    +++ Making showtag +++
    BLDENV=stretch make -f Makefile.work showtag
    make[1]: Entering directory '/home/rancho/workdir/SONIC-DEV/sonic-buildimage'
    sonic-201911-stretch:public
    make[1]: Leaving directory '/home/rancho/workdir/SONIC-DEV/sonic-buildimage'
    ```

### 对于发布docker编译环境供大家使用的用户
1. 按照原有的方式完成编译环境的构建

2. 发布编译环境
    1. 使用`docker tag image-id sonic-version-debian_version:tag`进行规法镜像命名
    2. 使用`docker rmi old_name:old_tag`删除生成的镜像tag
    3. 使用`docker save -o ~/sonic-version-debian_version.tar sonic-version-debian_version:public`提取镜像
    4. 使用`gzip sonic-version-debian_version.tar`压缩
    5. 将sonic-version-debian_version.tar.gz文件放到文件服务器上供大家使用

# 对于主目标编译
这里面有个`target groups`的概念, 在slave.mk里面定义了很多目标组，如SONIC_MAKE_DEBS, SONIC_MAKE_FILES，这些目标组在具体的功能模块中被填充，之后被该组的cmd所执行。参见README.buildsystem.md将会有更好的理解。
对于根文件系统的构建，时间很久，主要是每次都会删除之前构建的rootfs然后使用`debootstrap`重新构建，后续如果需要进行上层功能调试这明显效率很低。这里可以通过替换调试功能所在docker完成快速版本迭代。以路由协议frr举例。

    1. make list | grep frr 找到 target/docker-fpm-frr.gz
    2. 修改src/sonic-frr中的代码
    3. make target/docker-fpm-frr.gz生成新的frr镜像
    4. 在SONiC设备上`service bgp stop`停止docker-fpm-frr，并删除该container，删除docker-fpm-frr:latest镜像
    5. 将新的镜像拷贝到设备中`docker load -i docker-fpm-frr.gz`，并为之打上latest的tag
    6. `service bgp start`重启frr服务，进行代码验证
    7. service bgp如果找不到对应的container，则会根据docker-fpm-frr:latest重新创建一个，所以如果需要版本回退，重4,5,6的动作即可
