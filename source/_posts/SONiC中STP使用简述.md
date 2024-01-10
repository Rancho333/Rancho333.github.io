---
title: SONiC中STP使用简述
date: 2023-12-14 14:46:41
tags:
    - STP
---

# 写在前面

SONiC社区当前不支持STP feature，虽然Broadcom已经提交了 [PR](https://github.com/sonic-net/sonic-buildimage/pull/3463), 但是一直没有merge, 并且长时间没有维护。基于github上的开源[MSTPD](https://github.com/mstpd/mstpd)项目，将其porting到sonic中，完善SONiC的L2 features. 本文简述porting过程中的关键节点。

<!--more-->

需要了解一些STP的背景知识，可以参考下面链接
- [STP802.1d简述](https://rancho333.github.io/2022/07/07/STP802-1d%E7%AE%80%E8%BF%B0/)
- [RSTP802.1w简述](https://rancho333.github.io/2022/07/07/RSTP802-1w%E7%AE%80%E8%BF%B0/)
- [mstp802.1s简述](https://rancho333.github.io/2022/07/07/mstp802-1s%E7%AE%80%E8%BF%B0/)

