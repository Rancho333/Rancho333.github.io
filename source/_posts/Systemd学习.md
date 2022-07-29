---
title: Systemd学习
date: 2021-01-26 13:32:42
tags:
    - Linux
    - Systemd
Categories:
    - Linux
---

# 写在前面
Systemd是现代Linux的服务启动管理。Linux的第一个进程已经由`init`变成`systemd`了。
<!--more-->
```
[rancho sonic-buildimage]$ ps -ef | grep root | grep init
root         1     0  0  2020 ?        00:19:51 /sbin/init splash
[rancho sonic-buildimage]$ file /sbin/init
/sbin/init: symbolic link to /lib/systemd/systemd
```
init的两个缺点:
1. 启动时间长。init是串行启动。
2. 启动脚本复杂。init进程只是执行启动脚本，不管其它事情。所以脚本里面要处理各种情况，如依赖关系等，这使得脚本变得复杂且长。

# Systemd概述

Linux一直没有一个统一的管理平台，所以各种资料与学习都很零散，而且是一个分散的管理系统。Systemd是一个趋势，不然这么多发行版(Arch Linux、Debian系、Red Hat系)也不会去集成它了。

Systemd的设计目标是：为系统的启动和管理提供一套完整的解决方案。

Systemd的优点是功能强大，使用方便。缺点是体系庞大，非常复杂，与操作系统其它部分强耦合。
![](https://rancho333.github.io/pictures/arch_of_systemd.png)

# Systemd命令族
Systemd是一组命令的集合，涉及到系统管理的各个方面。

## systemctl
`systemctl`是Systemd的主命令，用于系统管理。systemctl接受服务（.service），挂载点（.mount）,套接口（.socket）和设备（.device）作为单元。
```
systemctl --version                 #查看systemd的版本
systemctl reboot                    #重启系统
systemctl poweroff                  #掉电
systemctl halt                      #CPU停止工作
systemctl suspend                   #暂停系统

systemctl list-unit-files           #列出所有可用单元
            [--type=service]        #所有服务
            [--type=mount]          #所有系统挂载点
            [--type=socket]         #所有可用系统套接口
systemctl list-units                #列出所有运行中的单元
systemctl --failed                  #列出所有失败的单元

systemctl status                    #显示系统状态
            [XX.service]            #检查某个服务状态
systemctl start XX.service          
systemctl restart XX.service
systemctl stop XX.service
systemctl reload XX.service         #启动、重启、停止、重载服务

systemctl is-active XX.service      #检查某个单元是否正在运行
systemctl is-enabled XX.service     #检查某个单元是否启用
systemctl is-failed XX.service      #检查某个单元是否启动失败

systemctl enable XX.service         #在启动时启用服务
systemctl disable XX.service        #在启动时禁止服务
systemctl kill XX.service           #杀死服务
systemctl show XX                   #检查某个服务的所有配置细节

systemctl mask XX.service           #屏蔽服务
systemctl unmask XX.service         #显示服务

systemctl list-dependencies XX.service      #获取某个服务的依赖性列表

systemctl get-default               #查看启动时的默认target

systemctl daemon-reload             # 重新加载配置文件
systemctl restart foobar            # 重启相关服务
```

## systemd-analyze

服务分析工具。
```
systemd-analyze                     #查看启动耗时
systemd-analyze plot                #生成更直观的图表
systemd-analyze blame               #查看各个进程耗费时间
systemd-analyze critical-chain      #分析启动时的关键链
systemd-analyze critical-chain XX.service   #分析某个服务的关键链
```

## 不常用命令
systemd的有些命令功能会和某些命令重合，还有一些不常见的命令，如：hostnamectl、localectl、timedatectl、loginctl。

# Unit

Systemd可以管理所有的系统资源，不同的资源统称为unit(单元)。
unit一共分成12种.   
- service : 系统服务
- target : 多个unit构成的一个组
- device : 硬件设备
- mount : 文件系统挂载点
- automount : 自动挂载点
- path ： 文件或路径
- scope ： 不是由systemd启动的外部进程
- slice ： 进程组
- snapshot : systemd快照，可以切回某个快照
- socket : 进程间通信的socket
- swap : swap文件
- timer : 定时器

## unit配置文件

每一个unit都有一个配置文件，告诉systemd怎么启动这个unit。
systemd默认从`/etc/systemd/system`读取配置文件。这里面部分文件是符号链接，指向`/lib/systemd/system`或者`/usr/lib/systemd/system`。

`systemctl enable`的本质就是在上面两个目录的文件之间建立符号链接关系。
```
systemctl enable XX.service
等同于
ln -s /lib/systemd/system/XX.service /etc/systemd/system/XX.service
```
![](https://rancho333.github.io/pictures/systemd_enable.png)

如果配置文件里面设置了开机启动，`systemctl enable`命令相当于激活开机启动。

配置文件的后缀名就是该unit的种类，systemd默认后缀名是`.service`，所以`bluetooth`等效于`bluetooth.service`。

`systemctl list-unit-files`会显示每个unit的状态，一共有四种：
- enabled：已建立启动连接
- disabled：未建立启动链接
- static: 该配置文件没有[install]部分，无法通过enable命令进行安装。只能做为其它unit的依赖(After字段或Requires字段)或者手动开启。相反的，基于这个特性，它无法通过disable关闭，一般用在必须启动的unit上。如写一个rc-local.service，实现开机后自动实现某些功能。
- masked：该配置文件被禁止建立启动链接

## 配置文件的格式

配置文件示例如下：
![](https://rancho333.github.io/pictures/systemd_config_file.png)

配置文件分为Unit、Service、Install等区块，每个区块中都是key-value形式的配置。

`[Unit]`是配置文件的第一个区块，用来定义Unit的元数据，以及配置与其他Unit的关系，主要字段如下：

- Description: 简短描述
- Documentation: 文档地址
- Requires: 当前 Unit 依赖的其他 Unit，如果它们没有运行，当前 Unit 会启动失败
- Wants：与当前 Unit 配合的其他 Unit，如果它们没有运行，当前 Unit 不会启动失败
- BindsTo：与Requires类似，它指定的 Unit 如果退出，会导致当前 Unit 停止运行
- Before：如果该字段指定的 Unit 也要启动，那么必须在当前 Unit 之后启动
- After：如果该字段指定的 Unit 也要启动，那么必须在当前 Unit 之前启动
- Conflicts：这里指定的 Unit 不能与当前 Unit 同时运行
- Condition...：当前 Unit 运行必须满足的条件，否则不会运行
- Assert...：当前 Unit 运行必须满足的条件，否则会报启动失败

`[Service]`区块用来Service配置，只有Service类型的Unit才会有这个区块，它的主要字段如下：

- Type：定义启动时的进程行为。它有以下几种值
    - Type=simple：默认值，执行ExecStart指定的命令，启动主进程
    - Type=forking：以 fork 方式从父进程创建子进程，创建后父进程会立即退出
    - Type=oneshot：一次性进程，Systemd 会等当前服务退出，再继续往下执行
    - Type=dbus：当前服务通过D-Bus启动
    - Type=notify：当前服务启动完毕，会通知Systemd，再继续往下执行
    - Type=idle：若有其他任务执行完毕，当前服务才会运行
- ExecStart：启动当前服务的命令
- ExecStartPre：启动当前服务之前执行的命令
- ExecStartPost：启动当前服务之后执行的命令
- ExecReload：重启当前服务时执行的命令
- ExecStop：停止当前服务时执行的命令
- ExecStopPost：停止当其服务之后执行的命令
- RestartSec：自动重启当前服务间隔的秒数
- Restart：定义何种情况 Systemd 会自动重启当前服务，可能的值包括always（总是重启）、on-success、on-failure、on-abnormal、on-abort、on-watchdog
- TimeoutSec：定义 Systemd 停止当前服务之前等待的秒数
- Environment：指定环境变量

`[Install]`通常是配置文件的最后一个区块，用来定义如何启动，以及是否开机启动，它的主要字段如下：

- WantedBy：它的值是一个或多个 Target，当前 Unit 激活时（enable）符号链接会放入/etc/systemd/system目录下面以 Target 名 + .wants后缀构成的子目录中
- RequiredBy：它的值是一个或多个 Target，当前 Unit 激活时，符号链接会放入/etc/systemd/system目录下面以 Target 名 + .required后缀构成的子目录中
- Alias：当前 Unit 可用于启动的别名
- Also：当前 Unit 激活（enable）时，会被同时激活的其他 Unit

Unit配置文件的完整key-value清单，参见[官方文档](https://www.freedesktop.org/software/systemd/man/systemd.unit.html)。

# Target

计算机启动的时候，需要启动大量的Unit。如果每一次启动，都要一一写明本次启动需要那些Unit，显然非常不方便。Systemd的解决方案就是Target。

Target就是一个Unit组，包含许多相关的Unit。启动某个Target的时候，Systemd就会启动里面所有的Unit。从这个意义上说，Target这个概念类似于“状态点”，启动某个Target就好比启动到某种状态。

传统的Init启动模式中，有Runlevle的概念，和Target的作用很类似。不同的是，Runlevel是互斥的，但是多个Target是可以同时启动的。
```
systemctl get-default           #查看启动时的默认 Target
systemctl list-dependencies multi-user.target   #查看一个 Target 包含的所有 Unit
```

它与Init的主要差别如下：
1. 默认的 RunLevel（在/etc/inittab文件设置）现在被默认的 Target 取代，位置是/etc/systemd/system/default.target，通常符号链接到graphical.target（图形界面）或者multi-user.target（多用户命令行）。
2. 启动脚本的位置，以前是/etc/init.d目录，符号链接到不同的 RunLevel 目录 （比如/etc/rc3.d、/etc/rc5.d等），现在则存放在/lib/systemd/system和/etc/systemd/system目录。
3. 配置文件的位置，以前init进程的配置文件是/etc/inittab，各种服务的配置文件存放在/etc/sysconfig目录。现在的配置文件主要存放在/lib/systemd目录，在/etc/systemd目录里面的修改可以覆盖原始设置。

# 日志管理

Systemd统一管理Unit的启动日志，通过`journalctl`命令可以查看所有日志，日志的配置文件是`/etc/systemd/journald.conf`。它的功能很强大，用法也很多。
```
journalctl                      # 查看所有日志（默认情况下 ，只保存本次启动的日志）

journalctl -k                   # 查看内核日志（不显示应用日志）

journalctl -b                    # 查看系统本次启动的日志
journalctl -b -0

# 查看指定时间的日志
journalctl --since="2012-10-30 18:17:16"
journalctl --since "20 min ago"
journalctl --since yesterday
journalctl --since "2015-01-10" --until "2015-01-11 03:00"
journalctl --since 09:00 --until "1 hour ago"

journalctl -n                   # 显示尾部的最新10行日志
journalctl -n 20                # 显示尾部指定行数的日志

journalctl -f                   # 实时滚动显示最新日志

journalctl /usr/lib/systemd/systemd    # 查看指定服务的日志

journalctl _PID=1               # 查看指定进程的日志

journalctl /usr/bin/bash        # 查看某个路径的脚本的日志

journalctl _UID=33 --since today    # 查看指定用户的日志

# 查看某个 Unit 的日志
journalctl -u nginx.service
journalctl -u nginx.service --since today

# 查看指定优先级（及其以上级别）的日志，共有8级
# 0: emerg
# 1: alert
# 2: crit
# 3: err
# 4: warning
# 5: notice
# 6: info
# 7: debug
journalctl -p err -b

journalctl --disk-usage                  # 显示日志占据的硬盘空间

journalctl --vacuum-size=1G            # 指定日志文件占据的最大空间

journalctl --vacuum-time=1years             # 指定日志文件保存多久
```

# 几个问题

列举几个在systemd使用过程中可能遇到的问题。

## 开机启动与启动服务
`systemctl enable`设置服务开机启动，该服务需要等到下一次开机才会启动。`systemctl start`表明立即启动该服务。

## Unit区块中的启动顺序与依赖关系
启动顺序由`Before`和`After`字段表示。Before表明应该在value表示的服务*之前*启动，After表示应该在value表示的服务*之后*启动。这两个字段只涉及到启动顺序而不设计依赖关系。

举例来说，SONiC中的bgp服务需要用redis数据库存储数据。如果在配置文件中只定义在redis之后启动，而没有定义依赖关系。设备启动后，由于某些原因，redis挂掉了，这之后bgp就会无法建立数据库连接。

设置依赖关系，需要使用`Wants`和`Requires`字段。Wants字段表明两者之间存在*弱依赖*关系，即如果value表明的服务启动失败或者停止运行，不影响主服务的继续执行。Requires字段则表明两者之间存在*强依赖*关系，即如果value表明的服务启动失败或者异常退出，那么主服务也必须退出。注意这两个字段只涉及依赖关系，与启动顺序无关，默认情况下不是同时启动的。

依赖于某一服务才能正常运行，可以同时定义Requires和After字段，如下所示。
![](https://rancho333.github.io/pictures/requires_after.png)

## Services区块的小问题
Services区块定义如何启动当前服务。

在所有的启动设置之前加上一个连词号(-),表示*抑制错误*，即错误发生的时候，不影响其它命令的执行。比如，`EnvironmentFile=-/etc/sysconfig/sshd`（注意等号后面的那个连词号），就表示即使`/etc/sysconfig/sshd`文件不存在，也不会抛出错误。

`KillMode`字段定义了Systemd如何停止服务，value可以设置的值如下：
```
control-group（默认值）：当前控制组里面的所有子进程，都会被杀掉
process：只杀主进程
mixed：主进程将收到 SIGTERM 信号，子进程收到 SIGKILL 信号
none：没有进程会被杀掉，只是执行服务的 stop 命令。
```

`Restart`字段定义了服务退出后，systemd重启该服务的方式，value可以设置的值如下：
```
no（默认值）：退出后不会重启
on-success：只有正常退出时（退出状态码为0），才会重启
on-failure：非正常退出时（退出状态码非0），包括被信号终止和超时，才会重启
on-abnormal：只有被信号终止和超时，才会重启
on-abort：只有在收到没有捕捉到的信号终止时，才会重启
on-watchdog：超时退出，才会重启
always：不管是什么退出原因，总是重启
```
SONiC中很多服务Restart都设置为always，如swss服务。`RestartSec`字段表示systemd重启服务之前，需要等待的秒数。

## Install区块的小问题
Install区块定义如何安装这个配置文件，即怎样做到开机启动。

`WanteBy`字段表示该服务所在的Target。systemd默认启动的Target可以通过`systemctl get-default`查看到。服务必须加到这个Target或这个Target的子Target中才能开机启动。

常用的Target有两个，一个是`multi-user.target`，表示多用户命令行状态；另一个是`graphical.target`，表示图形用户状态，它依赖于`multi-user.target`，SONiC使用的是后者。官方文档有一张非常清晰的[Target依赖关系图](https://www.freedesktop.org/software/systemd/man/bootup.html#System%20Manager%20Bootup)

## Target的配置文件
在`/lib/systemd/system`下可以找到Target的配置文件,以`graphical.target`为例：
![](https://rancho333.github.io/pictures/graphical_target.png)
其中：
```
Requires字段：要求basic.target一起运行。
Conflicts字段：冲突字段。如果rescue.service或rescue.target正在运行，multi-user.target就不能运行，反之亦然。
After：表示multi-user.target在basic.target 、 rescue.service、 rescue.target之后启动，如果它们有启动的话。
AllowIsolate：允许使用systemctl isolate命令切换到multi-user.target。
```

# 小结
一般而言，配置文件存放在`/lib/systemd/system`和`/usr/lib/systemd/system`目录下，通过`systemctl enable`在`/etc/systemd/system`创建符号链接指向前者，Systemd会执行etc下的文件，前提是文件中的Install配对了Target。

# 参考资料

[Systemd入门教程：命令篇](http://www.ruanyifeng.com/blog/2016/03/systemd-tutorial-commands.html)
[systemctl 命令完全指南](https://linux.cn/article-5926-1.html)
