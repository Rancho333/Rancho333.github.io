---
title: 关于Ubuntu的软件源source.list学习
date: 2019-07-25 03:02:19
categories: 
- Linux相关
tags:
- Linux
- 软件源
---

## 背景说明
最近参与到公司的白盒交换机项目中，需要编译ONL和sonic，其中软件源的设置让我非常头疼，编译依赖有很大的问题。决定深入学习一下Linux软件源.主机环境为ubuntu16.04.  
<!--more-->

## 软件库存储文件*.list  
ubuntu使用apt来管理软件包，apt将软件库存储在如下文件中:  

```
/etc/apt/sources.list
/etc/apt/sources.list.d/目录中带.list后缀的文件
```
 
可以通过man sources.lis来查看apt的完整存储机制。  

## sources.list格式和写法  
1. 以`#`开头的行是注释行  
2. 以deb或deb-src开头的是`apt respository`，具体格式为：  
  1. deb：二进制包仓库  
  2. deb-src：二进制包的源码库,不自己看程序或者编译，deb-src可以不要。  
  3. URI: 库所在的地址，可以是网络地址，也可以是本地的镜像地址  
  4. codename：ubuntu版本的代号，可以通过命令`lsb_release -a`来查看当前系统的代号  
  5. components：软件的性质(free或non-free等)  

### ubuntu系统代号
codename是ubuntu不同版本的代号

| 版本号 | 代号(codename) |  
| :----: | :--: |  
| 10.04 | lucid |  
| 12.04 | precise |  
| 14.04 | trusty |  
| 14.10 | utopic |  
| 16.04 | xenial |  
| 18.04 | bionic |    

### deb说明
deb后面的内容有三大部分：deb URI section1 section2  
以`deb http://us.archive.ubuntu.com/ubuntu/ xenial main restricted`为例进行说明。  
URI是库所在的地址，支持http，fpt以及本地路径,访问`http://us.archive.ubuntu.com/ubuntu/`可以看到如下信息：
![](https://rancho333.gitee.io/pictures/ubuntu.png)
`dists`和`pool`这两个目录比较重要。`dists`目录包含了当前库的所有软件包的索引。这些索引通过codename分布在不同的文件夹中。例如`xenial`所在的目录。  
![](https://rancho333.gitee.io/pictures/xenial.png)
上图中的文件夹名其实就是对应了section1，我们可以根据需要填写不同的section1.
这里面的文件都是用以下格式命名的：  

```
codename
codename-backports    #unsupported updates
codename-proposed	  #pre-released updates
codename-security	  #important security updates
codename-updates	  #recommanded updates
```

打开其中一个任一文件夹，例如`xenial-updates`:  
![](https://rancho333.gitee.io/pictures/xenial.png)
里面有`main,multiverse,restricted,universe`文件夹，这些文件夹对应deb后面的section2,里面包含了不同软件包的索引。它们的区别在于：  

```
main：完全的自由软件
restricted: 不完全的自由软件
universe: ubuntu官方不提供支持与补丁，全靠社区支持
multiverse: 非自由软件，完全不提供支持和补丁
```

打开main目录下的binary-i386子目录下的Packages.gz文件，可以看到如下内容：  
![](https://rancho333.gitee.io/pictures/packages.png)
说明：Packages.gz这个文件其实就是一个“索引”文件,里面记录了各种包的包名(Package)、运行平台(Architecture)、版本号（Version）、依赖关系(Depends)、deb包地址(Filename)等。Filename指向的是源服务器pool目录下的某个deb。猜测：`apt-get install`某个软件是，其实就是基于这些Packages.gz来计算依赖关系，然后根据其中的filename地址来下载所需的deb，最后执行`dpkg -i pacckage.deb`来完成软件包的安装。  

## 替换源
先将默认的sources.list进行备份，然后仿照下表修改源：  

```
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb https://mirrors.aliyun.com/ubuntu/ bionic main restricted universe multiverse
# deb-src https://mirrors.aliyun.com/ubuntu/ bionic main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ bionic-updates main restricted universe multiverse
# deb-src https://mirrors.aliyun.com/ubuntu/ bionic-updates main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ bionic-backports main restricted universe multiverse
# deb-src https://mirrors.aliyun.com/ bionic-backports main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ bionic-security main restricted universe multiverse
# deb-src https://mirrors.aliyun.com/ubuntu/ bionic-security main restricted universe multiverse

# 预发布软件源，不建议启用
# deb https://mirrors.aliyun.com/ubuntu/ bionic-proposed main restricted universe multiverse
# deb-src https://mirrors.aliyun.com/ubuntu/ bionic-proposed main restricted universe multiverse
```

## 国内镜像网站
这里推荐两个国内镜像网站，一个是[清华源](http://mirrors.tuna.tsinghua.edu.cn/)，一个是[阿里源](https://mirrors.aliyun.com/)
找到对应的源后，清华源可以点击源名称后的问号获取源路径，阿里源可以点击源名称所在行的帮助获取源路径。
注意事项：
	清华源中源路径默认使用https,需要安装apt-transport-https软件包，否则修改为http进行使用

## unmet dependencies
在执行命令`apt-get -y build-dep linux`时出现`unmet dependencies`错误，如下图所示：
{% asset_image unmet_dep.png unmet_dep %}
解决方法：
	在镜像服务器上可以查询到2.99版本存在，将`apt-get`命令换成`aptitude`命令，使用`apt-get install -y apt-utils aptitude`安装`aptitude`

## Hash Sum Mismatch
在使用阿里源编译sonic源码的时候(debian:stretch)，出现`Hash Sum Mismatch`的报错。如下图所示：
{% asset_image hash_mismatch.png hash_mismatch %}

有些网络服务商，特别是一些小区网络的服务商，为了减少流量费用和提高对常见网络资源的访问速度，很多都搞了这么个东西出来
但是他们的缓存策略有问题，只比对文件路径，不考虑域名/IP地址，也没怎么考虑过文件内容更新后的同步，即缓存服务器上的内容和实际文件的内容可能不一致。
即对于http://example.com/a/b/c.dat这么一个文件，如果被收入缓存，那么你访问其他任意域名下的/a/b/c.dat文件都会去读取被缓存的文件。如果http://example.com/a/b/c.dat有了改变，缓存服务器上的对应文件不一定能跟着更新。
而ubuntu大部分源的文件路径是一致的，所以如果163源中的 http://mirrors.163.com/ubuntu/dists/tru ... ources.bz2 被收入缓存，那么你访问官方源 http://archive.ubuntu.com/ubuntu/dists/ ... ources.bz2 时，由于路径都是/ubuntu/dists/trusty/main/source/Sources.bz2，还是获取的是缓存服务器上的缓存文件。这个可用wget验证。如果缓存服务器上文件过时了，就会出现Hash Sum Mismatch。
解决方法：
	1.更换源，换成清华源就没问题了
	2.使用https协议

## 关于pypi国内源
哈，顺便在这里提一下pip的国内源啦，就不单独写篇文章了。
python使用pip作为包管理工具，类似于debian/ubuntu的apt-get/aptitude和redhat的yum。国内镜像网站可以在上面找到。替换方法如下：
临时使用：
	`pip install -i https://pypi.tuna.tsinghua.edu.cn/simple some-package`
设为默认：
升级 pip 到最新的版本 (>=10.0.0) 后进行配置：
```
	pip install pip -U
	pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
```
如果您到 pip 默认源的网络连接较差，临时使用本镜像站来升级 pip：
`pip install -i https://pypi.tuna.tsinghua.edu.cn/simple pip -U`

如果不升级pip,那么可以修改pip的配置文件：
修改 ~/.pip/pip.conf (没有就创建一个文件夹及文件)
内容如下：
```
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
[install]
trusted-host = https://pypi.tuna.tsinghua.edu.cn
```

**参考资料：**
[ubuntu论坛](https://forum.ubuntu.org.cn/viewtopic.php?t=465499)

