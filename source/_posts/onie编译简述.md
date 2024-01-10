---
title: onie编译简述
date: 2024-01-10 16:16:15
tags: onie
---

# 写在前面
简单记录下基于[DUE](https://github.com/CumulusNetworks/DUE/tree/master)环境编译onie镜像的过程。

<!--more-->

# 编译步骤
1. 下载DUE代码，构建编译环境
```
git clone https://github.com/CumulusNetworks/DUE.git    // 下载DUE代码  
```

执行`./due -c --help` 会显示当前可以自动构建的编译环境.
![](https://rancho333.github.io/pictures/due_create_help.png)

根据自己onie的源码选择对应的docker进行构建，这里选择debian10
```
./due  --create  --platform  linux/amd64    --name  onie-build-debian-10     --prompt  ONIE-10       --tag  onie-10                  --use-template  onie              --from  debian:10
```
等待完成构建之后使用`docker images | grep onie`检查一下。

2. 下载onie源码

3. 进入编译环境进行编译
```
./due -r --home-dir /projects/erzhu/build/rancho/              // 在DUE根目录下执行, 使用 --home-dir 修改mount路径，默认是/home/rancho，保证onie源码mount进去就行
```
进入onie的`build-config`目录，执行
```
make -j8 MACHINEROOT=../machine/celestica/ MACHINE=cel_ds2000 all            // 根据vender和hwsku填即可
```
当前代码使能了secure boot, 编译过程中需要输入密码(123456).

编译完成之后，生成的iso镜像在`build/images`, 使用dd制作启动盘即可。