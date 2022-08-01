---
title: 关于动态库以及constructor属性的使用
date: 2020-02-26 11:00:40
tags:
- 动态库so
- attribute属性
---

# 写在前面
在做linux系统移植的过程中逐步加深了对动态编译和静态编译的理解，今天这里记录一下如何将自己的代码编译成动态库供其他程序使用。顺道记录一下遇到的一个好玩的东西：C语言中的constructor属性，是`__attribute__`的attr_list中的一员。
<!--more-->

## 将自己的模块编译生成so
示例模块分成两个部分，cons.c和cons.h,cons.c的代码如下：
```
#include "cons.h"

void before_main()
{
        printf("%s\n", __FUNCTION__);
}

void after_main()
{
        printf("after main!\n");
}
```
cons.h的代码如下：
```
#include <stdio.h>

void before_main() __attribute__((constructor)); 
void after_main();
```
使用命令`gcc cons.c -fPIC -shared -o  libcons.so`编译生成动态库文件。

## 使用动态进行编译
动态库一般是封装了一些常用的模块或功能，我们在需要调用动态库的代码中先加入需要调用函数所在的头文件（这些头文件是与动态库一起发布的），然后在编译的时候链接该库就可以了。调用库的示例代码demo.c:
```
#include "cons.h"

void main()
{
        printf("%s\n", __FUNCTION__);
}
```
使用命令`gcc demo.c -o demo -L./ -lcons`进行编译，其中`-L`指明了查找动态库的路径，`-lcons`指明动态库的名字，它的组成是`-l`加上动态库真实名字的`lib`与`.so`之间的字符串，如`libcons.so`就是`-l+cons`。
使用`ldd demo`查看程序所依赖动态库的具体情况（是否存在，查找路径等）：
![](https://rancho333.github.io/pictures/ldd.png)

发现demo与libcons.so之间并未产生依赖关系，这里猜测是demo.c中并没有显示的使用到libcons.so中的资源，所以即使加上`-lcons`编译选项，编译器也会对之进行优化。那么我们修改demo.c中的代码为：
```
#include "cons.h"

void main()
{
        printf("%s\n", __FUNCTION__);
        after_main();
}
```
这里加上对函数`after_main`的调用，再使用ldd查看：
![](https://rancho333.github.io/pictures/ldd_2.png)

发现ldd中虽然已经有了libcons.so的信息，但是是`not found`，执行`demo`当然也会报这个库找不到。这是因为我们的库所在的路径并没有加到*查找库所在路径*的环境中，类似于shell的命令查找规则*PATH*环境变量，这里可以将路径添加到环境变量中或者将库拷贝到已知的查找路径中。用户添加的一般拷到`/usr/lib`下，这里再回到上面编译demo.c的地方，如果事先将库拷到系统路径中，那么久不用加`-L`指定路径了。如果是做嵌入式开发，记得一定要把库拷到开发板上哦。动态库在程序编译和执行的时候都会用的。

再次ldd看下并执行：
![](https://rancho333.github.io/pictures/ldd_3.png)

可以正常执行打印出函数名字了，但是有点奇怪的是没有调用befor_main函数为什么也会打印出来呢。

## constructor关键字

回到上面去看看before_main函数的声明，发现有个`__attribute__((constructor))`。

### __attribute__介绍

__attribute__可以设置函数属性(Function Attribute)、变量属性(Variable Attribute)和类型属性(Type Attribute)。__attribute__前后都有两个下划线，并且后面会紧跟一对原括弧，括弧里面是相应的__attribute__参数
*__attribute__语法格式为：__attribute__ ( ( attribute-list ) )*

若函数被设定为constructor属性，则该函数会在main（）函数执行之前被自动的执行。类似的，若函数被设定为destructor属性，则该函数会在main（）函数执行之后或者exit（）被调用后被自动的执行。

所以记得了before_main在main函数之前执行的哦，以前一直只记得main函数是程序的入口。这次移植调试发现在main函数之前就coredump了，查了好半天才定位出来。

好玩的东西很多，遇到奇怪的东西很多时候心里会打鼓，但越来越坚定：代码里没有玄学！
