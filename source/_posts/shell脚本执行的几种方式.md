---
title: shell脚本执行的几种方式
date: 2021-02-20 13:59:22
tags: shell
---

# shell脚本执行的几种方式

shell脚本有三种执行方式

<!--more-->
## ./filename 或 filename
这种方式是我们在CLI中最常使用的方式，要求脚本具有*可执行*权限。类似于执行二进制程序，需要让shell找到文件的具体位置。这种执行方式是重新启动一个子shell，在子shell中执行此脚本。子shell继承父shell的环境变量，但子shell新建的、改变的变量不会带回父shell，除非使用export。

## source filename 或 . filename
这种方式一般用在脚本中定义shell环境变量，比如修改`.bashrc`后使用source执行一下，将改动生效到当前shell中。
这个命令其实只是简单的读取脚本里面的语句依次在当前shell里面执行，没有新建子shell。脚本里面所有新建、改变变量的语句都会保存在当前shell里面。


## bash filename 或 sh filename，两者等效
这种方式与./filename执行方式的唯一区别是，filename不需要可执行权限。

# 关于$0和BASH_SOURCE
`$0`保存了被执行脚本的程序名称, 在脚本中`basename $0`可以获取脚本的文件名。用source方式执行的脚本不适用，$0为`-bash`。
但是，除了$0之外，bash还提供了一个数组变量`BASH_SOURCE`,程序名以入栈的方式存储在BASH_SOURCE中，即最后一个执行的脚本是BASH_SOURCE[0]或BASH_SOURCE，等价于$0。
在嵌套脚本的调用中，使用`BASH_SOURCE[0]`获取当前脚本的路径，使用`BASH_SOURCE[-1]`或`$0`获取顶层脚本的路径