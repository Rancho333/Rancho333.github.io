---
title: Makefile学习
date: 2019-08-26 10:51:37
tags:
---

## 写在前面

学软件的时候接触过一些makefile，但是之后的工作中一直没怎么用上。最近在做白盒交换机SONiC以及ONL的编译工作，里面用makefile和python完成整个工程的编译，有些宏大与震撼，关键很多地方看不懂哇。系统的学习一下，这里作为笔记，参考的是陈皓的《跟我一起写Makefile》。

<!--more-->
## 概述

会不会写makefile从一个侧面说明一个人是否具备完成大型工程的能力。

makefile关系到了整个工程的编译规则。源文件（类型、功能、模块）放在若干目录，makefile是编译规则，指定那些文件需要先编译，后编译，重新编译。其中也可以执行操作系统的命令。

make是解释makefile中指令的命令工具。

## 关于程序的编译与链接

编译流程：预处理（.i），编译(.s)，汇编(.o)，链接(binary)。

编译时，编译器需要的是语法的正确，函数与变量的声明的正确（告诉头文件所在的位置，定义应该放在C文件中）。一般来说，每个源文件都应该对应于一个中间目标文件（.o文件）。如果函数未被声明，编译器可以生成Obiect File。

链接时，主要链接函数与全局变量。将中间目标文件链接成应用程序。中间目标文件太多，将其打包，windows下这种包叫“库文件”(library file)，也就是.lib文件，在UNIX下是Archive File,也就是.a文件。在Object File中寻找函数的实现，如果找不到，就报错。

## Makefile介绍

Makefile规则：
```
target ... : prerequisites ...
    command
    ...
    ...
```
target是目标文件，可以是Object File，也可以是执行文件，还可以是一个标签（Lablel）。
prerequisites即依赖。
command是make需要执行的命令，任意shell命令。

Makefile中核心内容：
***prerequisites中如果有一个以上的文件必target文件要新（或者target不存在）的话，command所定义的命令就会被执行***

Makefile自动推导功能，对于[.o]文件，他会把[.c]文件自动加在依赖关系中，并且[command]gcc -c file.c也会被推导出来。

## Makefile总述






