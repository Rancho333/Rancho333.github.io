---
title: Linux查找so文件所在pkg
date: 2019-07-14 20:17:03
categories: 
- Linux相关
tags:
- Linux
- so文件
---

## 问题描述
在Ubuntu16.04 server上安装typora时报错：`Typora: error while loading shared libraries: libnss3.so`  
<!--more-->
![](https://rancho333.gitee.io/pictures/error.png)
使用find在机器上的确没有找到该so文件，一般情况下对于name.so，安装一个name包就行了(so文件与pkg文件名相同)，但有的时候是不相同的，这时需要利用apt-file查找so文件所属的pkg.
![](https://rancho333.gitee.io/pictures/diff.png)

## 安装apt-file
安装命令：`sudo apt-get install apt-file`  
update：`apt-file update`,当/etc/apt/source.list文件发生变化时，需要重新update   
![](https://rancho333.gitee.io/pictures/update.png)

## 查找软件所依赖的so文件并安装依赖包
查看软件位置：`whereis typora`  
![](https://rancho333.gitee.io/pictures/where.png)

查找软件依赖so：`ldd /usr/bin/typora`  
![](https://rancho333.gitee.io/pictures/not_found.png)

对每一个标有`not found`的so文件执行如下：  
![](https://rancho333.gitee.io/pictures/search.png)

找到pkg名称后，使用`sudo apt-get install pkg-name`安装即可。
