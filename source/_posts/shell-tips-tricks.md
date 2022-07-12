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

## 关于 [[]]
[[]]中没有文件扩展和`单词分离`，但是会发生参数扩展和命令替换。
如果字符串中有空格，那么只能用[[]]惊醒判断。如：
```
str=“abc def”
[[ -z $str ]]           // 判断str是否为空，如果使用[ -z str ] 则会报数组错误，因为`[]`会将str分割成abc、def两个字符串
```