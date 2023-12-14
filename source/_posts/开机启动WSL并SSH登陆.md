---
title: 开机启动WSL并SSH登陆
date: 2023-12-14 14:25:05
tags: - WSL
---

# 背景说明
windows的WSL功能让ubuntu作为windows的子系统，这种双系统对linux开发非常友好。一般使用远程工具如Xshell登陆Linux，对windows和WSL做一些配置，实现开启windows之后：
- 自动启动WSL
- WSL中开启sshd服务

<!--more-->

# 实现方法

1. 创建开机启动脚本，名称为`linux-start-ssh.vbs`, 里面的内容为：
```
Set ws = WScript.CreateObject("WScript.Shell")        ' 创建windows shell对象
ws.run "wsl -d ubuntu -u root /etc/init.wsl"          ' 在shell中启动wsl，wsl启动加载 init.wsl脚本
```

`init.wsl`脚本的内容如下：
```
#! /bin/sh
/etc/init.d/ssh start           # 在wsl中启动sshd服务，这样wsl启动时就会自动开机sshd
```

2. 将`linux-start-ssh.vbs`脚本加入到开机启动项中，直接将该文件拷贝到`C:\Users\Rancho\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup`路径下即可

3. 在task manager中确认enable服务，设置好后状态如下图：
![](https://rancho333.github.io/pictures/wsl_init_script.png)

windows启动后自动运行`linux-start-ssh.vbs`, wsl启动后自动运行`init.wsl`.

4. 使用`ssh rancho@localhost`即可在windows上ssh登陆wsl