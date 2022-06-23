---
title: sonic-testbed的理解
date: 2021-03-02 19:00:15
tags: SONiC
---

# 简介
这篇文章用来记录对sonic testbed的一些理解以及一些较核心的知识点。
<!--more-->

sonic-mgmt代码运行在docker-sonic-mgmt环境中中，镜像在sonic-buildimage中编译生成，docker-ptf也是在里面生成的。docker-sonic-mgmt环境集成了ansible-playbook、pytest、spytest等所需的依赖。
