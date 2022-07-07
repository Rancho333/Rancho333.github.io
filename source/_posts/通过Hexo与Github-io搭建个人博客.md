---
title: 通过Hexo与Github.io搭建个人博客
date: 2019-07-14 11:05:48
tags: hexo
---

## 前言
我信奉好记性不如记下来，上学时在笔记本上记笔记，后来在csdn上写点东西(有广告，不舒服)，后来笔记都记在有道云笔记上。最后发现利用github.io可以很方便的搭建个人博客。下面记录的是Blog搭建的过程(完成blog的上传)以及源码的备份，后面的文章记录一些优化与使用技巧。
<!--more-->

## 环境准备
```
Github账号
Linux服务器
  git
  node.js(6.9版本以上)
```
Github账号的注册在这里不做赘述，然后创建一个名为yourname.github.io的仓库（仓库名格式一定要符合）。我用的Linux是ubuntu16.04 server版(家用)与ubuntu18.04(aws云服务器,一年免费，可以用来科学上网)。hexo依赖于git与node.js
安装git  
```
sudo apt-get install git-core
```

安装node.js,具体的node.js与hexo的对应版本参见hexo官网，我们这里使用的是hexo3.9，对应的node.js版本应该不高于12,否则会有一些奇奇怪怪的错误。
```
curl -sL https://deb.nodesource.com/setup_15.x | sudo -E bash -
sudo apt-get install -y nodejs
```

依赖程序安装完成之后，就可以使用npm安装Hexo.
```
npm install -g hexo-cli
```
之后进行Hexo的初始化
```
hexo init <folder>
cd <folder>
```
完成之后，指定文件夹的目录如下：  
![](https://rancho333.gitee.io/pictures/hexo_tree.png)
这里面不包含pbulic文件夹，会在执行第一次`hexo g`命令后生成，并且在执行`hexo d`命令后会生成`.deploy_git`文件夹，这两个文件夹中的内容是相同的，是最终部署到github.io中的文件。  
然后执行`npm install`产生node_modules文件夹，至此，服务端的基本初始化完成。 
修改`_config.yml`配置文件如下：  
```
deploy:
  type: git 
  repository: git@github.com:yourname/yourname.github.io.git
  branch: master
```
部署到github.io即完成，执行`hexo g -d`。这时候访问：`https://yourname.github.io/`即可访问Blog。  

## Hexo常用命令  
| command | description |  
| :-----: | :---------: |  
| hexo init [folder] | 新建一个网站 |  
| hexo new `<title>` | 新建文章，如标题包含空格用引号括起来 |  
| hexo generate | 生成静态文件，简写hexo g |  
| hexo deploy | 部署网站，简写hexo d |  
| hexo clean | 清除缓存文件 |
| hexo version | 查看Hexo版本 |
| hexo --config custom.yml | 自定义配置文件路径，执行后不再使用_config.yml |  

注意，每个主题下面也有一个_config.yml文件(作用域是该主题)，主目录下的是全局配置(作用域是整个网站)。  

## 源码备份  
hexo d只是将生成的静态网页部署到github.io上，这样存放源码的服务器到期或者多台PC开发时便会产生不便，下面说明将源码部署到github.io上。  
创建README.md文件
```
echo "# shiningdan.github.io" >> README.md
```
初始化git仓库(在hexo init folder的folder目录下执行)，hexo d操作的仓库是.deployer_git.
```
git init 
git add README.md 
git commit -m "first commit"
```
和github.io建立映射  
`git remote add origin https://github.com/yourname/yourname.github.io.git ` 
master分支作为deploy的分支，创建hexo分支用来备份源码  
```
git branch hexo  
git push origin hexo  
git checkout hexo  
```
将github.io中的默认分支修改为hexo(这样下载时就是下源码)，因为user page的发布版必须位于master分支下  
后续开发在hexo分支下执行，执行`hexo g -d`生成网站并部署到github的master分支上，执行`git add、git commit、git push origin hexo`提交源码  

### 重新部署
1. 下载源码`git clone https://github.com/yourname/yourname.github.io.git`
2. 安装依赖`npm install -g hexo-cli、npm install、npm install hexo-deployer-git`,注意不需要执行`hexo init`  

## 重新部署的问题
虽然之前将hexo的源码也备份到了远程仓库，但是一旦主机环境发生改变，得重新安装对应的依赖，这也带来一定的不稳定隐患，现在将开发环境打包到docker，发布到[docker hub](https://hub.docker.com/repository/docker/rancho123/ubuntu)中, 后续个人的工作环境会持续集成进去。一些Linux通用配置（vim, bash）则存放到[gitee](https://gitee.com/Rancho333/vim_cfg)上。

之前主题文件`next`是用一个单独repository来进行管理，自己的修改可以提交，但是分成两个仓库不方便。所以现在将next主题源码也集成到hexo中。所以现在如果重新部署blog环境，需要做3件事：
1. `https://github.com/Rancho333/Rancho333.github.io.git`下载源码(包含hexo+theme)
2. 安装hexo依赖(见重新部署) 以及 下面插件，如果generate报错缺失插件，安装即可
```
[rancho blog]$ npm list --depth 0
hexo-site@0.0.0 /home/rancho/workdir/blog
├── eslint@7.23.0
├── hexo@5.4.0
├── hexo-deployer-git@3.0.0
├── hexo-generator-archive@1.0.0
├── hexo-generator-baidu-sitemap@0.1.9
├── hexo-generator-category@1.0.0
├── hexo-generator-feed@3.0.0
├── hexo-generator-index@2.0.0
├── hexo-generator-searchdb@1.3.3
├── hexo-generator-sitemap@2.1.0
├── hexo-generator-tag@1.0.0
├── hexo-helper-live2d@3.1.1
├── hexo-renderer-ejs@1.0.0
├── hexo-renderer-marked@4.0.0
├── hexo-renderer-stylus@2.0.1
├── hexo-renderer-swig@1.1.0
├── hexo-server@2.0.0
├── hexo-theme-landscape@0.0.3
├── hexo-wordcount@6.0.1
├── live2d-widget-model-shizuku@1.0.5
└── lodash@4.17.21
```
3. 检查站点配置文件中blog部署的位置，注意将page发布的分支必须是master(代码默认分支是hexo).


**参考资料：**  
[HEXO官方文档](https://hexo.io/zh-cn/docs/)
