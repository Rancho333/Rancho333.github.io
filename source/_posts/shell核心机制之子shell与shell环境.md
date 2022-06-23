---
title: shell核心机制之子shell与shell环境
date: 2021-02-22 10:49:31
tags: shell
---

# 深入了解shell必备的两个知识点
子shell与shell环境是深入了解shell所必备的两个知识点。shell的实现方式有多种，如bash，sh，zsh等，这些软件本质就是一个shell解释器，最常用的是bash，因为其在几乎所有的Linux发行版中都预安装了。
子shell是shell命令的运行机制，而shell环境是shell命令的运行环境，就是我们常说的环境变量了。

<!--more-->
# 命令类型与子shell
并不是在shell里执行的所有命令都会在子shell里执行，我们需要先认识一下shell命令分类。

`type`命令可以可以显示出命令的类型，对于不同的类型shell解释器有不同的处理方式。命令类型有以下几种：
- alias(shell alias)
- function(shell functions)，shell函数
- builtin(shell builtin)，shell内建命令
- file(disk file)，磁盘文件，需要有可执行权限，我们安装的第三方软件一般就是这种类型，在PATH下找到，这个是外部命令，如ssh、ls
- keyword(shell reserved word)，shell保留关键字，如for、done、while等，在shell脚本中很常用

`type`的常用参数如下
```
-t      打印命令类型，上述5种类型之一
-a      打印所有包含该命令的文件位置
```

shell对于不同的命令类型，处理方式如下：
- file(外部命令)的执行：先fork shell子进程，在后在子shell进程中exec调用外部命令
- function、builtin、keyword: 这些命令依赖于shell进程，没有shell进程，他们都没有意义。他们都是直接在当前shell进程内执行的，不会创建新的子shell进程来执行
- alias:在命令解析阶段替换成对应的内容，然后重新执行命令解析

当alias、keyword、function、builtion、file冲突时，会按照优先级进行执行，优先级从左至右依次递减。

对于使用子shell方式执行cmd
1. 当前shell进程fork创建一个子shell进程，子shell继承父shell大量属性，如变量
2. 子shell进程通过exec调用执行cmd, 并用cmd代码替换刚才创建的子shell进程(子shell进程继承自父shell进程的属性会被覆盖)，于是子shell进程就变成cmd进程，所以父shell的子进程变成了cmd进程
3. 父shell进程wait子cmd进程退出

伪代码描述如下, 以执行`ls -lah`命令为例：
```
pid = fork();
if(pid == 0 ) {
    //子进程中，调用exec
    exec("ls -lah")
} else if (pid > 0) {
    //父进程中，waitpid等待子进程退出
    waitpid(pid);
} 
```

通过`$BASHPID`可以查看当前bash进程的pid，从而判断在那个shell(父还是子).

# shell命令的运行环境
每个shell进程有一个自己的运行环境，不同的shell进程有不同的shell环境。shell解析命令行、调用命令行的过程都在这个环境中完成。

shell运行环境由配置文件来完成初始化，bash会读取的配置文件有：
- /etc/profile
- /etc/profile.d/*.sh
- ~/.bash_profile
- ~/.bashrc
- /etc/bashrc

shell分为login shell、non-login shell与interactive shell、non-interactive shell，不同的shell加载的配置文件是不同的。

环境主要体现在对环境的设置，包括但不限于环境的设置有：
- `cd /tmp`表示设置当前shell环境的工作目录
- shopt或set命令进行shell的功能设置，可在配置文件中找到相关设置
- 环境变量设置
    - 主要用于shell进程和其子进程之间的数据传递
    - 子进程（不仅仅是子shell进程）可以继承父shell环境中的环境变量
    - 环境变量通常以大写字母定义，非一定
    - 使用bash内置命令`export`可以定义环境变量
    - 命令前定义变量`var=value cmd`，表示定义一个专属环境变量，该环境变量只能在cmd进程环境中可以访问，cmd进程退出后，var环境变量也消失
- `export var=value`表示在当前shell环境下定义一个环境变量var，以便让子进程继承这个变量

每当提到shell内置命令，就要想到这个命令的作用有可能是在当前shell环境下进行某项设置
shell内置命令不会创建新进程，而是直接在当前shell环境内部执行
内置命令`source`或`.`执行脚本时，表示在当前shell环境下执行脚本内容，即脚本中所有设置操作都会直接作用于当前shell环境
父shell环境可能影响子shell环境，但子shell环境一定不影响父shell环境，比如子shell脚本中的环境变量不会粘滞到父shell环境中

## shell环境/属性设置
`bash`也是一个程序，一个命令，它可以通过设置选项来修改其某些属性，这些属性可以提高bash的安全性和可维护性。
- -u        遇到未定义的变量抛出错误，bash默认忽略它，当作空来处理
- -x        显示bash执行的执行命令，在前面用`+`来区分命令和命令的输出；如果遇到-u的错误，不会打印该命令(测试所得)
- -e        脚本发生错误，终止执行

这里注意一个特殊场景即管道命令，bash会把管道命令最后一个子命令的返回值作为整个命令的返回值，也就是说，只要最后一个命令不失败，管道命令总是会执行成功。
```
#!/bin/bash
set -eux
demo | echo adsad
echo afe
```
此处`demo`未定义，执行失败，但是`echo adsad`会执行成功，所以管道命令`demo | echo adsad`的返回值是`0`,脚本接下来的命令`echo afe`会继续执行，`set -e`在这里就失效了。使用`set -o pipefaile`可以解决这种情况，只要一个子命令失败，整个管道命令就失败，脚本就会终止执行。注意配合`set -e`一起使用才会生效，即`set -o pipeline`是`set -e`的一个补丁。

养成好习惯，在所有bash脚本开头加上
```
set -euxo pipefail
```

如果有意让退出状态不为0的程序使用`cmd || true`

此外，shell可以关闭模式扩展
```
set -o noglob
或者
set -f
```

# 关于引号
子shell和shell环境是shell机制方面的核心，其实引号在shell中的重要性与之可比肩。
在许多编程语言中，引号被用来表明：包含在里面的文本会被解析成字符串。但是在shell中，只有一种数据类型就是字符串。因此，字符串相关的引号和转义，对bash来说就非常重要。

引号的功能：
- 防止保留字符被替换，如`echo '$'`
- 防止域分割和通配符，如包含空格的文件名
- 参数扩展，如`"$@"`

有三种标准的引号(如果算上转义是4种)，和2种非标准的bash扩展用法。
- 单引号(single quotes)：移除在单引号之间所有字符的特殊含义, 避免被bash自动扩展。单引号之间的所有东东都会变成字符串(literal string)，唯一不能安全的被单引号修饰的字符就是单引号本身，即使使用了转义符也不行
- 双引号(double quotes)：双引号中不会进行文件名扩展，但是三个字符除外`$` `反引号` `\`，如果开启了`!`引用历史命令，则`!`也除外。大部分特殊字符在双引号中会失去特殊含义，变成普通字符，如`*`
- 反引号(`backticks`)：这是命令替换语法的遗产，现在使用`$(...)`替代，但因为历史问题，现在依然被允许使用
- 转义符(\)：将`\`放在元字符($、&、*、\)前面去掉其特殊含义，如 `echo \$？`, 在双引号和没有引号中有效，在单引号中无效.反斜杠除了用于转义，还可以表示一些不可打印的字符
    - \a    响铃
    - \b    退格
    - \n    换行
    - \r    回车
    - \t    制表符
所以在命令结尾结尾加上`\`，其实就是在换行符前加上转义，使得换行符变成一个普通字符，bash会将其当作空格处理，从而可以将一行命令写成多行。

这里举一个`find`使用的小例子：
```
[rancho test]$ ls
a.c  c  deb  kernel  linux  make  python  shell

[rancho test]$ find ./ -name "*.c"
./shell/a.c
./shell/b.c
./a.c
./deb/zhw-1.0.0/a.c
./python/a.c
./linux/a.c
./c/syntax.c

[rancho test]$ find ./ -name *.c
./shell/a.c
./a.c
./deb/zhw-1.0.0/a.c
./python/a.c
./linux/a.c
[rancho test]$ 
```
第一次使用find，传给它的参数是`*.c`，find会在当前目录下面去找所有以`.c`结尾的文件
第二次使用find, 传给它的参数是`a.c`，注意当前目录下面有`a.c`，所以`*.c`会被shell模式扩展为`a.c`；如果当前目录下没有`.c`文件，则扩展失败，原样输出`*.c`，这时候和用双引号修饰效果是一样的。
shell模式扩展完之后才会调用命令，所以一定要主要哪些词元是给shell做模式扩展的，哪些是直接传递给命令的，我们通过引号进行标识告知bash。


# shell核心知识点
最开始是想记录下`子shell`与`shell环境`这两个知识点的，后来越来越多的发现自己不知道某些知识点或者知识点认识模糊，shell笔记也有好几个文件了，这里列举一下shell中比较重要的知识点。
- 子shell
- shell命令执行环境
- 模式扩展(通配符扩展、变量扩展、子命令扩展、算术扩展)，expansion，globbing and word splitting
- 引用(引号和转义)
- shell变量(变量引用，变量替换)
- 退出和退出状态
- 各种test(文件测试、字符串测试、数值测试)
- 循环和分支
- shellcheck   这个并不是shell的知识点，而是一个shell脚本的检查工具，python，C都有这种检查工具，可以很好的帮我们检查一些通用的易错的语法问题，强烈建议使用

# 参考资料
[Bash脚本教程](https://wangdoc.com/bash/)
[Google shell脚本代码规法](https://google.github.io/styleguide/shellguide.html)
[打造高效工作环境-shell篇](https://coolshell.cn/articles/19219.html)