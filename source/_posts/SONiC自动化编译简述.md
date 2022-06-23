---
title: SONiC自动化编译简述
date: 2021-10-08 10:58:42
tags: 
    - SONiC
    - jenkins
---

# 关于SONiC自动化编译
- 当gitlab仓库有push动作时触发自动编译，仓库地址为：http://cshgitlab.cn-csh.celestica.com/sonic-sdk/brixia_sonic.git
<!--more-->

- 编译环境部署在泰国服务器，设备ip为：10.196.48.47

- 考虑网络问题以及SONiC编译偶尔会抽疯，编译失败后再次执行，5次失败后退出编译

- 镜像版本号为“SONiC.202012-brixia-时间-版本”，如“SONiC.202012-brixia-20210930-r4”，其中时间为当天编译时间，r后面的数字依次递增，r5,r6……

- 编译好的版本，命名规则为"sonic-broadcom-时间-版本.bin"，会自动推送到文件服务器：http://10.204.112.155:8081/sonic/brixia/

- jenkins环境部署在：10.204.112.155:8080, 后续稳定后考虑迁移到testbed的环境，当前上面只有一个账号(rancho/123456)，有兴趣的同学请自行参观使用

- 针对不需要gitlab+jenkins的场景，提供shell脚本实现自动化编译，在自己家目录下执行 bash ~/auto_build.sh即可

# 自动化编译一些小问题
- 自动化编译每次均为全量编译，时间较长，加上从泰国服务器拷贝image，时间较长，如果是特性或编译临时版本，并不建议使用，推荐增量编译或模块化编译。

- 自动化编译只会编译基础SONiC镜像，debug版本或加特性(如syncd-rpc)不会在自动化编译中(主要考虑编译时间、传输时间、存储空间以及使用率)

- 自动化编译单次只会编译一个target，对于无依赖关系target不能并行处理，并行处理大概率会报错，需要手动纠错

- jenkins在远程主机上执行shell命令使用的是SSH，该shell是非交互式非登录式shell，需要注意shell配置文件的加载以及环境变量的配置

- 在host上清除已经编译过的环境需要root权限(fsroot文件夹)，使用脚本中的b.out可以完成该操作
    修改Makefile, 在target中加入sonic-slave-run, 使用 `make sonic-slave-run SONIC_RUN_CMDS="rm -rf fsroot"`删除不能删除的部分