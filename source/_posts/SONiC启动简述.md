---
title: SONiC启动简述
date: 2021-01-29 10:28:18
tags: SONiC
---

# 写在前面
sonic在初始化的时候是怎样识别platform的，
/host/machine.conf
/etc/sonic/config_db.json
<!--more-->
/etc/rc.local

## platform相关

在`device_info.py`中会通过读取`/host/machine.conf`配置文件来获取platform的名称

## hwsku相关

在`device_info.py`中会通过读取ConfigDB来获取hwsku, 如果在`show version`中没有看到hwsku，那么需要配置config_db.json配置文件来加载配置信息，重启后生效。

## chassis相关

以pmon的docker的psud为例，先获取`platform_chassis`，对于chassis的初始化，关注platform_base.py、platform.py以及chassis.py这三个文件，其中chassis.py中完成chassis的实例化，一般包括syseeprom、watchdog、fan、thermal、psu、sfp、component。

chassis.py是厂商的sonic_platform包里面提供的文件，pmon的docker创建的时候会根据platform挂载对应的sonic_platform包，所以能保证加载正确的板子的外设。
