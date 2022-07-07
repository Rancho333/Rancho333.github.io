---
title: Hexo使用优化
date: 2019-07-14 21:45:48
categories:
- Hexo
tags:
- Hexo
---

## 说明

``` bash
站点配置文件：位于站点根目录下，主要包含Hexo本身的配置
主题配置文件：位于主题目录下，主要用于配置主题相关的选项
```

版本说明, 当前配置基于以下版本进行修改，hexo代码环境打包在[docker](https://hub.docker.com/repository/docker/rancho123/ubuntu)中，避免生产环境改变带来的问题。
``` 
hexo: 5.4.0
hexo-cli: 4.2.0
next: 7.8.0
```

## hexo的一些规则
1. 放在`source`下所有不以下划线开头的文件，在`hexo g`的时候会拷贝到`public`下面
2. hexo默认渲染所有的html和markdown文件 

## 使用next主题
网上一搜大部分都是Hexo+next的使用，本着站在前人的肩膀上原则，使用next主题。  
主题下载：`git clone https://gitee.com/Rancho333/hexo-theme-next.git themes/next`  
启用主题，打开站点配置文件，找到`theme`字段，修改为如下：  

``` bash
theme: next
```

### 选择scheme
next提供4种不同外观，找到`scheme`字段，启用其中一种scheme，这里我选择Gemini.  

``` bash
# Schemes                                  
#scheme: Muse
#scheme: Mist
#scheme: Pisces
scheme: Gemini
```

### 设置语言
在站点配置文件中找到`language`字段，修改为(中文，英文为：en)：

``` bash
language: zh-CN
```
注意需要在`themes/next/languages/`下面有对应的语言文件，否则不生效（使用默认）


### 设置侧栏
找到`sidebar`字段，修改如下：  

``` bash
sidebar:
  #靠左放置
  position: left
  #显示时机
  display: always
```

### 设置头像
在主题配置文件中，找到`avatar`字段，值设置成头像的链接地址

### 设置作者昵称
在站点配置文件中，找到`author`字段，进行设置  

## 修改网址图标
可以在`https://www.iconfont.cn/`上找合适的图标，下载两个尺寸(16x16和32x32)的png格式图片，放到主题下的images文件夹中。在主题配置文件中找到：

``` bash
favicon:                         
  small: /images/R-16x16.png  
  medium: /images/R-32x32.png 
```
替换small和medium两项，分别对应两种尺寸的图标。

## 给文章添加"categories"属性
创建`categories`页面  

``` bash
hexo new page categories
```
找到`source/categories/index.md`文件，里面的初始内容如下：

``` bash
---                                       
title: categories
date: 2019-07-12 12:14:44
---
```

添加`type: "categories"`到内容中，添加后内容如下：

``` bash
---                                               
title: categories
date: 2019-07-12 12:14:44
type: "categories"
---
```

给文章添加`categories`属性，打开任意一篇md文件，为其添加概述信，添加后内容如下：

``` bash
---                                              
title: Linux查找so文件所在pkg 
date: 2019-07-14 20:17:03
categories: 
- Linux相关
tags:
- Linux
- so文件
---
```
hexo一篇文章只能属于一个分类，如添加多个分类，则按照分类嵌套进行处理。

## 给文章添加"tags"属性
创建`tags`页面

``` bash
hexo new page tags
```

后面的操作与添加`categories`属性类似，一篇文章可以添加多个`tags`  

# 关于图片
有时候会分享md文件给别人，这时候要求图片的标识是因特网可达的，而不能使用资源文件夹这种方式。可以将图片放在`public/pictures`文件夹中，`hexo clean`命令会删除该文件夹。图片调用：`![](https://rancho333.gitee.io/pictures/arp_protocol.png) `
1. 将图片源文件放到`source/pictures`路径下（源码可以备份，`hexo clean`命令会删除public文件夹）
2. `hexo g`会将`source`下面非下划线开头的文件或文件夹拷贝到`public`下面
3. `public`里面的内容会上传到master分支，所以我们可以使用上面的链接进行访问

# 文章搜索功能
安装搜索功能插件：
``` bash
npm install hexo-generator-searchdb --save
```
在站点配置文件中添加：
``` bash
search:                                                                                                                                                                                          
  path: search.xml    搜索文件path，所有的可搜索内容都静态写到了该文件中
  field: post         搜索范围
  format: html
  limit: 100         限制搜索的条目
```
在主题配置文件中：
``` bash
local_search:                                                                                       
  enable: true 
```

# 查看插件以及脚本
`hexo --debug`可以查看插件以及使用的脚本

# 添加看板娘
安装插件`hexo-helper-live2d`
安装看板模型`live2d-widget-model-shizuku`
在站点配置文件中增加如下配置
```
# Live2D
# https://github.com/EYHN/hexo-helper-live2d
live2d:
  enable: true
  pluginRootPath: live2dw/
  pluginJsPath: lib/
  pluginModelPath: assets/ Relative)
 
  # 脚本加载源
  scriptFrom: local # 默认从本地加载脚本
  # scriptFrom: jsdelivr # 从 jsdelivr CDN 加载脚本
  # scriptFrom: unpkg # 从 unpkg CDN 加载脚本
  # scriptFrom: https://cdn.jsdelivr.net/npm/live2d-widget@3.x/lib/L2Dwidget.min.js # 从自定义地址加载脚本
  tagMode: false # 只在有 {{ live2d() }} 标签的页面上加载 / 在所有页面上加载
  log: false # 是否在控制台打印日志
 
  # 选择看板娘模型
  model:
    use: live2d-widget-model-shizuku  # npm package的名字
    # use: wanko # /live2d_models/ 目录下的模型文件夹名称
    # use: ./wives/wanko # 站点根目录下的模型文件夹名称
    # use: https://cdn.jsdelivr.net/npm/live2d-widget-model-wanko@1.0.5/assets/wanko.model.json # 自定义网络数据源
  display:
    position: left # 显示在左边还是右边
    width: 100 # 宽度
    height: 180 # 高度
  mobile:
    show: false
  react:
    opacityDefault: 0.7 # 默认透明度
```

## 添加字数统计
安装插件`npm install hexo-wordcount --save`
在`themes/next/layout/_macro/post.swig`文件的`busuazi`所在的模块的`endif`前面加上：
```
<span class="post-meta-divider">|</span>
<span title="{{ __('post.wordcount') }}"><span class="post-meta-item-icon"><i class="fa fa-file-word-o"></i></span>字数： {{ wordcount(post.content) }}</span>
```
在`themes/next/layout/_partials/footer.swig`文件的最后一行之前加上：
```
<div class="theme-info">
  <div class="powered-by"></div>
<span class="post-count">全站共 {{ totalcount(site) }} 字</span>
</div>
```

## 圆角设置
在 hexo/source/_data 目录下新建 variables.styl 文件，填写下面内容。
```
// 圆角设置
$border-radius-inner     = 20px 20px 20px 20px;
$border-radius           = 20px;
```
主题配置文件 next.yml 去除 variables.styl 的注释。

## 设置网站背景
除了设置背景图片，还需要设置博客文章博客文章透明度才能看到背景图片。
主题配置文件 next.yml 去除 style.styl 的注释。
在 hexo/source/_data/style.styl 文件中写入下面代码。
```
// 设置背景图片
body {
    background:url(/images/background.png);
    background-repeat: no-repeat;
    background-attachment:fixed; //不重复
    background-size: cover;      //填充
    background-position:50% 50%;
}
```
next 主题的博客文章都是不透明的，这样即使设置了背景图片也无法看到，在 hexo/source/_data/styles.styl 中写入下面内容，使博客文章透明化。
```
//博客内容透明化
//文章内容的透明度设置
.content-wrap {
  opacity: 0.9;
}

//侧边框的透明度设置
.sidebar {
  opacity: 0.9;
}

//菜单栏的透明度设置
.header-inner {
  background: rgba(255,255,255,0.9);
}

//搜索框（local-search）的透明度设置
.popup {
  opacity: 0.9;
}
```

## 目录与跳转
使用`doctoc`工具可以自动生成md的目录，并支持跳转，安装方式如下：
`npm i doctoc -g`
使用方式`doctoc file.md`就会在文章顶层生成目录，需要手动调整位置。
如果目录更新,`doctoc -u file.md`

## 本地部署
`hexo s`可以开启本地部署，这样可以快速验证一些feature.


**参考资料：**
[NexT官方](http://theme-next.iissnan.com/)  
