---
title: shell_tips_tricks
date: 2021-02-20 15:09:00
tags: shell
---

# 写在前面
这篇文章用来记录shell的一些使用技巧，使用场景
<!--more-->

# Tips & Tricks

## 获取shell脚本所在的目录

`dirname "$(realpath "$(BASH_SOURC[0])")"`
$0或者$(BASH_SOURC[0])表示当前脚本，`realpath`获取脚本的绝对路径，`dirname`将文件名的最后一个组件去掉。