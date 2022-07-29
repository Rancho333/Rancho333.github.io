---
title: Linux科学上网记录
date: 2019-09-06 05:52:04
tags:
- Linux
- 科学上网
categories:
- Linux
---

## 写在前面

之前在AWS部署了自己的shadowsocks的服务端，这个比较简单，参见ss的[github](https://github.com/shadowsocks/shadowsocks/tree/master)上面介绍就可以很容易的部署起来了，之后在windows上Android安装了对应的客户端，可以顺利科学上网，此处对这一部分就不多做说明了。最近做SONiC（哈，又是SONiC），编译过程中需要在google上下载一些资源，那么就需要在Linux服务器上翻墙，并且在docker中可以访问google。
<!--more-->

## 在linux上安装ss

Linux环境是ubuntu 16.04 server，没有图形界面，纯命令行。
使用pip安装
```
sudo apt-get update
sudo apt-get install python-pip
sudo apt-get install python-setuptools m2crypto
pip install shadowsocks
```
或者直接用apt安装
```
sudo apt-get install shadowsocks
```
中间可能会提示需要安装一些依赖，按提示安装即可。

## 启动ss

ss的服务端和客户端的程序其实是同一个（找ss的客户端找了半天），只是启动的命令不一样。客户端是sslocal命令，服务端是ssserver命令。有兴趣的同学可以`sslocal --help`看一下，这是一个很好的习惯。

这里我们直接使用配置文件的方式启动客户端，配置如下：
```
{                                                                                                     
    "server":"x.x.x.x",
    "server_port":443,
    "local_address":"127.0.0.1",
    "local_port":1080,
    "password":"xxxx123456",
    "timeout":300,
    "method":"aes-256-cfb",
    "fast_open":false
}
server  服务端vps的公网IP地址
server_port     服务端的端口
local_address   本地ip，一般localhost
local_port      本地端口
password        服务端密码
timeout         超时时间，应和服务端一致
method          加密方式，和服务端一致
```
这里一定注意配置文件的信息，请参照服务端配置文件，之后可以启动客户端：
```
sslocal -c /home/mudao/shadowsocks.json -d -start
```

## 配置privoxy代理

ss是sock5代理，需要在local配置privoxy将http、https转换成sock5流量才能走到vps。
* 安装privoxy
```
apt-get install privoxy
```

* 配置privoxy
```
vi /etc/privoxy/config
forward-socks5t / 127.0.0.1:1080 .
listen-address 127.0.0.1:8118
确保这两行的存在
```

* 启动privoxy
    * 开启privoxy服务
    ```
    sudo service privoxy start
    ```
    * 设置http和https全局代理
    ```
    export http_proxy='http://localhost:8118'
    export https_proxy='https://localhost:8118'
    ```

* 测试
```
curl cip.cc
```
会显示出你配置文件中vps的地址：
```
IP      : x.x.x.x
地址    : 日本  东京都  东京
运营商  : amazon.com

数据二  : 美国 | Amazon数据中心

数据三  : 日本东京都东京 | 亚马逊

URL     : http://www.cip.cc/x.x.x.x
```

然后再可以这样玩下：
```
curl "http://pv.sohu.com/cityjson?ie=utf-8"
```
搜狐的这个接口可以返回你的IP地址

## 配置PAC

很明显的，我们不想没被墙的网站也走代理，这时就需要PAC了。

* 安装GFWList2Privoxy
```
pip install --user gfwlist2privoxy
```

* 获取gfwlist文件，生成actionsfile
```
cd /tmp
wget https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt
~/.local/bin/gfwlist2privoxy -i gfwlist.txt -f gfwlist.action -p 127.0.0.1:1080 -t socks5
sudo cp gfwlist.action /etc/privoxy/
```
哈，可以在gfwlist.action中找一下google，很多，是不是。恩，大名鼎鼎的facebook，youtube，netflix都在里面哦，天朝的GFW将这些全部墙了。
如果访问某些国外网站速度慢的话（比如时常抽疯的github），就将它加到里面去吧！

有了配置文件之后，在`/etc/privoxy/config`文件中加上`actionsfile gfwlist.action`就可以了

* 重启Privoxy，测试代理是否走pac模式
    * 是否能google
    ```
        wget www.google.com
    ```
    * 是否能pac(显示自己ip)
    ```
    curl "http://pv.sohu.com/cityjson?ie=utf-8"
    ```
* 注意
如果还是显示代理服务器的IP，则把/etc/privoxy/config中的forward-socks5 / 127.0.0.1:1080 .这一行注释了，然后重启privoxy
如果不注释这行，所有的流量都走代理，我们刚才做的pac模式，它就不走了。

## docker中使用代理流量

嗯嗯，我的初心是为了在docker中编译sonic，自然需要让docker也能科学上网了。
创建docker的配置文件：
```
vim  ~/.docker/config.json
{                  
"proxies":
{
   "default":
   {
     "httpProxy": "http://localhost:8118",
     "httpsProxy": "http://localhost:8118",
     "noProxy": "localhost"
   }
}
}
```
或者使用`docker run -e "http_proxy=http://localhost:8118" -e "https_proxy=http://localhost:8118"`

docker默认是bridge的网络模式，端口是需要做转发映射的。为了直接用宿主机的ip和端口，我们换成用host的网络模式，让她和宿主机可以用同一个Network Namespace
也就是使用`docker run -e "http_proxy=http://localhost:8118" -e "https_proxy=http://localhost:8118" --net host`来启动一个container

注意到上面`https_proxy`使用的代理和`http_proxy`是一样的，这是因为我在使用中发现有如下报错：
![](https://rancho333.github.io/pictures/timeout.png)
更改完之后就好了，原理暂时不清楚，看机缘更新吧！

参考资料：

[Linux 使用 ShadowSocks + Privoxy 实现 PAC 代理](https://huangweitong.com/229.html)

[Ubuntu18.04安装shadowsocks客户端](https://blog.diosfun.com/2018/09/21/Ubuntu18-04%E5%AE%89%E8%A3%85shadowsocks%E5%AE%A2%E6%88%B7%E7%AB%AF/)

[docker 容器内使用宿主机的代理配置](https://kebingzao.com/2019/02/22/docker-container-proxy/)


