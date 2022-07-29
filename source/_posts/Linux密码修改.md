---
title: Linux密码修改
date: 2020-03-09 17:20:27
tags:
    - passwd
---

# 写在前面
在做交换机Linux系统移植的过程中，发现进入shell的密码还是上一家的默认密码，还是改改吧。简单交代一下，ENOS上kernel加载完成之后应用的启动顺序如下如：
<!--more-->
![](https://rancho333.github.io/pictures/inittab.png)

这里是不进入shell的，而是直接进入klish作为交换机的命令行交互界面，类似于quagga的vtysh。之后在`configure`视图下面执行`start shell`进入linux shell的。
![](https://rancho333.github.io/pictures/shell.png)
在fnconvert里面会获取用户`root`的密码，其实就是使用`getspnam`获取`passwd或者shadow`的口令。既然这玩意使用的是Linux的账户和密码，那就是修改`/etc/passwd`文件了。
![](https://rancho333.github.io/pictures/spnam.png)

# passwd文件简介
Linux中每个用户在/etc/passwd文件中都有一个对应的记录行，每一行被冒号`:`分隔为7个字段，具体含义如下：
```
用户名：口令：用户标识号：组标识号：注释性描述：主目录：登陆shell
```
发行版中口令字段一般是`*或x`，`*`表示账号锁定, `x`表示密码存放在`/etc/shadown`文件中（访问需要sudo权限，而passwd文件不需要），当然我们的嵌入式系统密文是直接放在passwd中，如下：
![](https://rancho333.github.io/pictures/passwd.png)

其它字段除了`登陆shell`就没啥好玩的了，有些账号出于安全限制，并不会允许登陆进shell，而采用`nologin`的方式可以让这些用户使用部分系统功能。
![](https://rancho333.github.io/pictures/nologin.png)

## 修改用户密码
常规的在linux命令行下面修改密码没啥好说的，直接敲`passwd`然后输入新密码就行了，之后你会发现`passwd或者shadow`中的口令发生变化了。这里介绍一下口令了列的组成，不同的特殊字符表示不同的特殊意义：
```
1. 该列留空，即"::"，表示该用户没有密码。
2. 该列为"!"，即":!:"，表示该用户被锁，被锁将无法登陆，但是可能其他的登录方式是不受限制的，如ssh公钥认证的方式，su的方式。
3. 该列为"*"，即":*:"，也表示该用户被锁，和"!"效果是一样的。
4. 该列以"!"或"!!"开头，则也表示该用户被锁。
5. 该列为"!!"，即":!!:"，表示该用户从来没设置过密码。
6. 如果格式为"$id$salt$hashed"，则表示该用户密码正常。其中$id$的id表示密码的加密算法，$1$表示使用MD5算法，$2a$表示使用Blowfish算法，"$2y$"是另一算法长度的Blowfish,"$5$"表示SHA-256算法，而"$6$"表示SHA-512算法。加密算法会根据salt进行特定的加密，hashed是生成的密文
```
我看自己的linux服务器上面都是使用SHA-512加密的，而嵌入式系统上面用的是MD5，使用命令
![](https://rancho333.github.io/pictures/openssl.png)
就可以生成密码了，将原来的口令字段替换掉即可完成密码的修改。

有个小问题，实验过程中，发现在嵌入式系统上直接在命令行中修改密码不是按照`$id$salt$hashed`模式生成的口令，而是：
![](https://rancho333.github.io/pictures/abnormal.png)
但是在发行版Linux上面是符合预期的，有可能是嵌入式系统的某些差异吧，这里留个记录！
