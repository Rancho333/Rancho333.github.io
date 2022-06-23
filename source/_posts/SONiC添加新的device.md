---
title: SONiC添加新的device
date: 2020-12-31 11:16:17
tags: SONiC
---

# 写在前面
SONiC项目中，有时候厂商需要添加自己新的device上去。
1. 需要添加那些东西？
2. 怎么编译进文件系统？
<!--more-->
3. SONiC启动时是如何选择对应设备的文件？

搞清楚这三个问题后，我们就可以对device进行裁剪（SONiC默认会将device目录下所有文件拷贝进文件系统）。

# 目录结构及添加内容

与设备硬件耦合的文件夹有两个，分别是`platform`与`device`，`platform`描述ASIC，厂商设备驱动代码以及new platform API的适配；`device`描述厂商设备代码，其中包括端口配置，led配置，sai配置等信息，`plugins`文件夹是一些外设命令适配的python代码。
```
sonic-buildimage/
    platform/            # asic相关，重点关注sai以及sonic-platform.bin
        broadcom/        
    device              # 设备相关，对设备硬件特性的控制描述，如端口，led，console；以及和硬件相关的命令的底层适配接口，如填入eeprom的地址，之后使用SONiC的解析器进行解析。对于SONiC的命令体系，可以再写一篇文档
        celestica/
```

在`platform`中有个`sonic-platform`的文件夹，这里面包含了eeprom、fan、psu等外设相关的文件，与`device`里面的文件实际上是有重复的，这可能是SONiC的历史遗留问题，在字节项目中有讨论过后续会将外设相关的处理全部放到`platform`中去。

对于端口适配这些内容不熟悉，在此只做简单介绍。

# 编译相关
## device的编译

`device`中的数据会打包到`sonic-device-data_1.0-1_all.deb`, 具体是在`src/sonic-device-data/Makefile`实现文件拷贝然后打包成deb
```
$(addprefix $(DEST)/, $(MAIN_TARGET)): $(DEST)/% :                                       
    pushd ./src                     
                                    
    # Remove any stale data         
    rm -rf ./device                 
                                    
    # Create a new dir and copy all ONIE-platform-string-named dirs into it              
    mkdir ./device                  
    cp -r -L ../../../device/*/* ./device/                                               
                                    
    # Create hwsku for virtual switch
    for d in `find -L ../../../device -maxdepth 3 -mindepth 3 -type d | grep -vE "(plugins|led-code)"`; do \
        cp -Lr $$d device/x86_64-kvm_x86_64-r0/ ; \                                      
        cp ./sai.vs_profile device/x86_64-kvm_x86_64-r0/$$(basename $$d)/sai.profile; \  
        grep -v ^# device/x86_64-kvm_x86_64-r0/$$(basename $$d)/port_config.ini | awk '{i=i+1;print "eth"i":"$$2}' > device/x86_64-kvm_x86_64-r0/$$(basename $$d)/lanemap.ini
    done;                           
                                    
    # Build the package                                                                                                                                       
    dpkg-buildpackage -rfakeroot -b -us -uc
```
在`src/sonic-device-data/src/Makefile`中有config和media的测试
```
test:
    # Execute Broadcom config file test
    pushd ../tests/
    for f in $$(find ../../../device -name "*.config.bcm"); do
        ./config_checker $$f
    done
    for f in $$(find ../../../device -name media_settings.json); do                                                                                           
        ./media_checker $$f
    done
    popd
```
使用`dpkg -X target/debs/stretch/sonic-device-data_1.0-1_all.deb`或者在`fsroot/usr/share/sonic/device/`目录下可以发现`device`相关的文件。这些文件与设备目录上`/usr/share/sonic/device/`的文件相对应。
在`sonic_debian_extension.sh`脚本中会将其释放到根文件系统中去。
![](https://rancho333.gitee.io/pictures/device_data.png)
注意，在slave.mk中操作一下才能看到脚本，否则它做为中间文件，编译完成后会被自动删除。
```
-       $(if $($*_DOCKERS),
-               rm sonic_debian_extension.sh,
-       )
+#      $(if $($*_DOCKERS),
+#              rm sonic_debian_extension.sh,
+#      )
 
        chmod a+x $@
        $(FOOTER)
```

对于porting而言，可以修改Makefile中cmd的规则，只拷贝需要的device和只进行与之对应的test。



## platform的编译

`slave.mk`是SONiC项目真正的Makefile，所有的编译规则在里面可以找到，`platform`的入口在：
```
ifneq ($(CONFIGURED_PLATFORM), undefined)
include $(PLATFORM_PATH)/rules.mk
endif 
```
我们在执行`make configure PLATFORM=platform`时会指定platform，从而找到对应的rules.mk。

![](https://rancho333.gitee.io/pictures/rules_mk.png)

这里面关注三个文件
```
sai.mk                          # 指定SAI版本以及下载路径
platform-modules-device.mk      # 指定设备platform源文件路径，编译打包成debian
one-image.mk                    # 指定SONiC系统安装镜像名称
```
sai由ASIC厂商维护，作为设备厂商，我们直接使用即可。Makefile中通过指定url在编译时下载指定版本sai，对于此类重要的模块文件，可以将之缓存到本地，指定本地url进行使用。

对于设备厂商的platform，通过在`rules.mk`中增删 ***platform-modules-device.mk*** 可以实现在文件系统中添加或删除设备厂商platform的`device`模块
```
diff --git a/platform/broadcom/rules.mk b/platform/broadcom/rules.mk
index 8dd7b2c8..91e3afd3 100644
--- a/platform/broadcom/rules.mk
+++ b/platform/broadcom/rules.mk
@@ -1,7 +1,7 @@
 include $(PLATFORM_PATH)/sai-modules.mk
 include $(PLATFORM_PATH)/sai.mk
-include $(PLATFORM_PATH)/platform-modules-dell.mk
-include $(PLATFORM_PATH)/platform-modules-arista.mk
+#include $(PLATFORM_PATH)/platform-modules-dell.mk
+#include $(PLATFORM_PATH)/platform-modules-arista.mk
 include $(PLATFORM_PATH)/platform-modules-ingrasys.mk
```

通过在`one-image.mk`中增删`**_PLATFORM_MODULE`可以选择将在`platform-modules-device.mk`中编译好的对应机型的deb包拷贝到文件系统中。
```
diff --git a/platform/broadcom/one-image.mk b/platform/broadcom/one-image.mk
index 8cbf7269..edc51460 100644
--- a/platform/broadcom/one-image.mk
+++ b/platform/broadcom/one-image.mk
@@ -54,8 +54,8 @@ $(SONIC_ONE_IMAGE)_LAZY_INSTALLS += $(DELL_S6000_PLATFORM_MODULE) \
                                $(ALPHANETWORKS_SNH60B0_640F_PLATFORM_MODULE) \
                                $(BRCM_XLR_GTS_PLATFORM_MODULE) \
                                $(DELTA_AG9032V2A_PLATFORM_MODULE) \
-                               $(JUNIPER_QFX5210_PLATFORM_MODULE) \
-                               $(CEL_SILVERSTONE_PLATFORM_MODULE)
+                               #$(JUNIPER_QFX5210_PLATFORM_MODULE) \
+                               #$(CEL_SILVERSTONE_PLATFORM_MODULE)
```

对于打包好的platform文件，会在`sonic_debian_extension.sh`中拷贝到文件系统中去
![](https://rancho333.gitee.io/pictures/platform_module.png)

上面这张图片上就是裁剪过后只会拷贝`cel-b3010`这一款机型的platform。有兴趣的同学可以研究下是如何实现的。

在SONiC的安装镜像第一次启动时，会在`rc.local`中将其释放到文件系统中去.
![](https://rancho333.gitee.io/pictures/platform_module_2.png)

对于`platform-modules-*_amd64.deb`，里面包含了device的驱动，会在systemd中添加服务完成驱动的加载。这个deb的生成规则参见`platform/broadcom/sonic-platform-modules-cel/debian/`，主要修改如下几个文件：
```
rules
control
```
以及添加
```
platform-modules-ivystone.init
platform-modules-ivystone.install
platform-modules-ivystone.postinst
```

注意编译`platform-modules-*_amd64.deb`的规则：
```
CEL_DX010_PLATFORM_MODULE = platform-modules-dx010_$(CEL_DX010_PLATFORM_MODULE_VERSION)_amd64.deb
$(CEL_DX010_PLATFORM_MODULE)_SRC_PATH = $(PLATFORM_PATH)/sonic-platform-modules-cel
$(CEL_DX010_PLATFORM_MODULE)_DEPENDS += $(LINUX_HEADERS) $(LINUX_HEADERS_COMMON)
$(CEL_DX010_PLATFORM_MODULE)_PLATFORM = x86_64-cel_seastone-r0
SONIC_DPKG_DEBS += $(CEL_DX010_PLATFORM_MODULE)
           
CEL_HALIBURTON_PLATFORM_MODULE = platform-modules-haliburton_$(CEL_HALIBURTON_PLATFORM_MODULE_VERSION)_amd64.deb
$(CEL_HALIBURTON_PLATFORM_MODULE)_PLATFORM = x86_64-cel_e1031-r0
$(eval $(call add_extra_package,$(CEL_DX010_PLATFORM_MODULE),$(CEL_HALIBURTON_PLATFORM_MODULE)))
```
在slave.mk中会有编译SONIC_DPKG_DEBS的命令，只有CEL_DX010_PLATFORM_MODULE是显示的添加到SONIC_DPKG_DEBS

# SONiC启动简述

对于从onie下面安装SONiC，在onie下面会维护一个`machine.conf`文件，这里面有设备的详细信息，之后SONiC会根据这里的信息完成初始化的文件加载流程。

对于从SONiC下面直接安装SONiC，修改grub，暂不做深入研究。

对于systemd的初始化，SDK的初始化，platform/chassis的初始化，后续有需要在继续研究。