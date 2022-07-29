---
title: C语言弱符号weak
date: 2020-03-03 19:05:55
tags:
    - 弱符号
---

# 写在前面
上一篇文章《ENOS上段错调试记录》中有提到弱符号`weak`引发的段错，这篇文章来学习一下weak的用法。说来惭愧，工作了快4年，第一次见到这个语法。

<!--more-->
# weak弱符号定义

网上找了下weak符号的定义：#pragma weak to define a weakglobal symbol. This pragma is used mainly in source files for building libraries. The linker does not produce an error if it is unable to resolve a weak symbol.
对于全局的函数和变量，能不能重命名是有一定的规矩的，强、弱符号就是针对这些全局函数和变量来说的。

| 符号类型 | 对象 |
| :---- | :---- |
| 强 | 函数名，赋初值的全局变量 |
| 弱 | 未初始化的全局变量 |

当代码中存在多个强或弱的全局变量时，规则如下：
1. 强符号只能定义一次，否则编译error(未使用weak修饰的都是强符号)
2. 强弱符号同时存在，以强符号为准
3. 没有强符号，从多个弱符号中选一个，`-fno-common`这种情况下可以打出`warning`
这玩意的用途有点类似于
```
#ifndef name
    #define name
#endif
```

# 代码演示
## 弱符号声明
两种方式，第一种 
```
extern void weak0();
#pragma weak weak0
```
第二种方式
```
void __attribute__((weak)) weak0();
```

## 规则演示
下面通过三段代码来演示上诉的3条规则。
### main.c
`main.c`里面调用了2个声明为弱符号的函数，分别是`weak0`和`weak1`
```
#include <stdio.h>                                                                                                                                                                                              
//void __attribute__((weak)) weak0(void);
//void __attribute__((weak)) weak1(void);
extern void weak0();
extern void weak1();
#pragma weak weak0
#pragma weak weak1
 
int main(int argc, char **argv){
    //尝试调用弱符号函数weak0
    if (weak0){
        weak0();
    }   
    else{
        printf("weak0=%p\n", weak0);
    }   
    //尝试调用弱符号函数weak1
    if (weak1){
        weak1();
    }   
    else{
        printf("weak1=%p\n", weak1);
    }   
    return 0;
}
```

### weak.c
`weak.c`中定义了两个函数（weak0和weak1），并将之声明为弱符号
```
#include <stdio.h>

//标记weak0为弱符号
#pragma weak weak0
//标记weak1为弱符号
void __attribute__((weak)) weak1(void);

static char *label = "weak";

void weak0(void){
    printf("[%s]%s is called\n", label, __FUNCTION__);
}

void weak1(void){
    printf("[%s]%s is called\n", label, __FUNCTION__);
}
```

### strong.c
`strong.c`中重复定义了这两个函数，不做声明。
```
#include <stdio.h>

//两个函数都[不]声明为弱符号
//#pragma weak weak0
//void __attribute__((weak)) weak1(void);

static char *label = "strong";

void weak0(void){
    printf("[%s]%s is called\n", label, __FUNCTION__);
}

void weak1(void){
    printf("[%s]%s is called\n", label, __FUNCTION__);
}
```

## 不同编译组合及其输出情况
### 单独编译main.c
此处弱符号函数链接不成功，但是不会报编译错误，函数名所代表的地址为`nil`
![](https://rancho333.github.io/pictures/main.png)
如果这里依然调用它，那么便会如前面文章中提到的一样产生段错。
![](https://rancho333.github.io/pictures/segmentation_fault.png)

### 编译main.c+weak.c
弱符号链接成功，可以正常调用。
![](https://rancho333.github.io/pictures/weak.png)

### 编译main.c+weak.c+strong.c
当出现强符号定义时，弱符号定义不起作用
![](https://rancho333.github.io/pictures/strong.png)


