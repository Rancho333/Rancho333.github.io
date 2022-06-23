---
title: sonic-testbed
date: 2020-12-18 15:29:56
tags: SONiC
---

# 写在前面
最初，SONiC的所有测试用例都是用ansible playbook写的。2019年开始使用pytest， 2020年9月份之后，只有用pytest写的测试用例才被采纳。
但是ansible依然很重要，pytest-ansible插件连接pytest与ansible。pytest通过ansible进行多设备协同工作。

<!--more-->
## 物理拓扑
![](https://rancho333.gitee.io/pictures/physical-topology.png)

1. DUT和leaf fanout的端口一一互联
2. leaf fanout与DUT相连的端口进行VLAN隔离
3. root fanout连接leaf fanout与testbed server
4. root fanout的端口工作在vlan trunk模式下
5. 任一testbed server可以发送带有vlan tag的包到达DUT端口（root fanout的trunk口需要使能该vlan tag）

### Fanout switch
*Fanout switch是使能了vlan trunking的物理交换机*
* Et33是一个vlan trunking端口，并且和linux host的eth0连接
* Et1-Et32是vlan access端口，并且与DUT连接
* 使能LACP/LLDP
* 关闭STP功能

### Testbed server
![](https://rancho333.gitee.io/pictures/testbed-server.png)

#### 网络连接
* testbed server有两个网络接口
    * trunk端口连接root fanout
    * management port管理服务器以及服务器上的VMs和PTF容器

### VMs
VMs使用的是Arista的vEOS。它们用来设置测试协议，例如BGP、LACP、LLDP等。它们通过`testbed-cli.sh start-vms`进行创建。每一个VM使用2G内存并且拥有10个网络接口。
    * 8个前面板端口。这些端口用来连接到openvswitch网桥，连接到vlan interfaces.vlan interface通过物理接口连接到fanout。
    * 一个后背板端口。所有VMs通过这个背板口互联。
    * 一个管理网口。用来管理VMs.

### PTF
PTF容器通过发送和接收数据包来验证DUT的数据面。
PTF with direct port
![](https://rancho333.gitee.io/pictures/testbed-direct.png)

DUT的前面板口直连到一个PTF容器的端口。一般的PTF容器的eth0连接到DUT的Ethernet0，eth1连接到Ethernet4。这一般在PTF拓扑中用来连接DUT端口和PTF容器端口。

![](https://rancho333.gitee.io/pictures/testbed-injected.png)

DUT的前面板口和一个VM的接口直连。但是我们在这个连接上有个tap。从vlan interface中收到的包被发送给VMs和PTF容器。从VM和PTF容器中发出的包被送到vlan interface。这允许我们可以同时从PTF host往DUT注入包和维持VM与DUT之间的BGP会话。

### SONiC Tested with keysight IxNetwork as Traffic Generator
TO BE DONE！！

## Testbed设置
下面讲述testbed的设置步骤以及拓扑的部署。

### 准备testbed服务器
* 系统要求：ubuntu 18.04 amd64
* 设置管理口，使用如下示例：
```
root@server-1:~# cat /etc/network/interfaces
# The management network interface
auto ma0
iface ma0 inet manual

# Server, VM and PTF management interface
auto br1
iface br1 inet static
    bridge_ports ma0
    bridge_stp off
    bridge_maxwait 0
    bridge_fd 0
    address 10.250.0.245
    netmask 255.255.255.0
    network 10.250.0.0
    broadcast 10.250.0.255
    gateway 10.250.0.1
    dns-nameservers 10.250.0.1 10.250.0.2
    # dns-* options are implemented by the resolvconf package, if installed
```
* 安装python2.7（Ansible需要）
* 添加Docker的官方GPG key：
```
$ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
```

### 为`docker-pth`设置docker仓库
1. build `docker-pth`镜像
```
git clone --recursive https://github.com/Azure/sonic-buildimage.git
cd sonic-buildimage
make configure PLATFORM=generic
make target/docker-ptf.gz
```
2. 设置自己的docker仓库并将`docker-ptf`上传

### 创建并且运行`docker-sonic-mgmt`

管理testbed和运行测试用例需要很多依赖。将所有的依赖部署到`docker-sonic-mgmt`中，这样就可以很方便的使用`ansible-playbook`，`pytest`，`spytest`。
1. 构建`docker-sonic-mgmt`镜像
```
git clone --recursive https://github.com/Azure/sonic-buildimage.git
cd sonic-buildimage
make configure PLATFORM=generic
make target/docker-sonic-mgmt.gz
```
或者从[这里](https://sonic-jenkins.westus2.cloudapp.azure.com/job/bldenv/job/docker-sonic-mgmt/lastSuccessfulBuild/artifact/sonic-buildimage/target/docker-sonic-mgmt.gz)下载事先编译好的镜像。

2. 克隆`sonic-mgmt`库到testbed server的工作目录
```
git clone https://github.com/Azure/sonic-mgmt
```

3. 创建`docker-sonic-mgmt`容器，注意需要将上面克隆的`sonic-mgmt`挂载到容器中去:
```
docker load < docker-sonic-mgmt.gz
docker run -v $PWD:/data -it docker-sonic-mgmt bash
cd ~/sonic-mgmt
```

*注意：之后的所有操作都是在`docker-sonic-mgmt`容器中操作*

### 准备Testbed配置

进入到容器之后，我们需要修改testbed的配置文件使之与实验拓扑映射起来。

* Testbed Server
    * 在`ansible/veos`中更新server的管理IP
    * 在`ansible/group_vars/vm_host/creds.yml`中更新server的凭证
    * 在`ansible/host_vars/STA-ACS-SERV-01.yml`中更新server的网络配置（for VMs和PTF management）
        * `external_port`：server的trunk口名称（连接到fanout switch）
        * `mgmt_gw`：VM管理端口的网关IP
        * `mgmt_prefixlen`: 管理网口子网掩码
    * 检查ansible可以与这个host连接
    ```
    ansible -m ping -i veos vm_host_1 
    ```

* VMs
    * 从Arista下载[vEOS](https://www.arista.com/en/support/software-download)
    * 将镜像文件拷贝到`ansible/veos`
        * `Aboot-veos-serial-8.0.0.iso`
        * `vEOS-lab-4.20.15M.vmdk`
    * 将VM的IP地址更新到`ansible/veos`. 这个IP地址应该和定义的管理IP在同一个子网中
    * 在`ansible/group_vars/eos/creds.yml`中更新VM的凭证

* PTF容器
    * 在`vars/docker_registry.yml`中更新docker仓库信息


### 设置VMs

1. 开启VMs：
```
./testbed-cli.sh start-vms server_1 password.txt
```
`password.txt`是ansible的密码文件，如果不使用直接创建一个空文件即可。


2. 检查所有的VMs是否启动并且在运行中
```
ansible -m ping -i veos server_1
```

### 部署Fanout交换机的Vlan

在部署Fanout和运行测试用例之前需要明确环境中的所有物理连接。
在`roles/fanout`下的playbook只是用来部署Arista的Vlan配置。如果使用其它类型的交换机，请手动配置Vlan，或者部署一个2层交换机。

### 部署拓扑

* 使用自己的数据更新`testbed.csv`。至少需要更新PTF管理接口的配置。
* 部署拓扑请运行：`/testbed-cli.sh add-topo vms-t1 ~/.password`
* 移除拓扑请运行: `./testbed-cli.sh remove-topo vms-t1 ~/.password`

注意：`testbed-cli.sh`的最后一步试图在root fanout中重新部署vlan范围（与拓扑中规定的相匹配）。Arista的正常工作，其它型号的需要手动修改？

## Docker容器设置
使用`setup-container.sh`脚本去自动创建和配置sonic-mgmt的docker容器。使用普通用户user创建即可。
```
./setuo-container.sh -n container_name -i image_id -d directory
image_id是在sonic-buildimage中创建的docker-sonic-mgmt.tar
directory是主机与docker进行mount的文件夹
```
创建完dokcer容器之后，可以进入容器中：
```
docker exec -u <user> -it <container name> bash
```

## KVM testbed设置
可以给testbed创建虚拟的交换机，在上面部署T0拓扑，运行一个快速测试去验证是否符合预期。
即物理设备都虚拟化在服务器上，对内存资源要求比较高，我们现在使用物理设备连接，暂不研究这块内容。
这里面有vEOS与cEOS的介绍，分别是基于KVM和docker的技术。

## cEOS

如何使用cEOS作为DUT的邻居设备。
cEOS是容器化的EOS。所有的软件在容器中运行。与vEOS相比，cEOS内存暂用更少。

### 网络设置
首先创建一个基容器`net_${testbed_name}_${vm_name}`，在基容器中创建6个以太口。然后在基容器基础上启动cEOS`ceos_${testbed_name}_${vm_name}`容器。这6个网口分别用来：
* 一个管理网口
* 4个前面板端口用来连接DUT
* 一个背板口连接PTF容器
```
         +------------+                      +----+
         |  cEOS  Ma0 +--------- VM0100-m ---+ br |
         |            |                      +----+
         |            |
         |            |                      +--------------+
         |        Et1 +----------VM0100-t0---+  br-VM0100-0 |
         |            |                      +--------------+
         |            |
         |            |                      +--------------+
         |        Et2 +----------VM0100-t1---+  br-VM0100-1 |
         |            |                      +--------------+
         |            |
         |            |                      +--------------+
         |        Et3 +----------VM0100-t2---+  br-VM0100-2 |
         |            |                      +--------------+
         |            |
         |            |                      +--------------+
         |        Et4 +----------VM0100-t3---+  br-VM0100-3 |
         |            |                      +--------------+
         |            |
         |            |                       +--------------+
         |        Et5 +----------VM0100-back--+  br-b-vms6-1 |
         |            |                       +--------------+
         +------------+
```

### 配置
cEOS容器中的`/mnt/flash`挂载到主机的`/data/ceos/ceos_${testbed_name}_${vm_name}`。

### 登录
两种方式登录到cEOS容器。

1. docker exec
```
docker exec -it ceos_vms6-1_VM0100 Cli
```

2. ssh
```
lgh@jenkins-worker-15:~$ ssh admin@10.250.0.51
Password: 
ARISTA01T1>show int status
Port       Name      Status       Vlan     Duplex Speed  Type            Flags Encapsulation
Et1                  connected    in Po1   full   unconf EbraTestPhyPort                    
Et2                  connected    1        full   unconf EbraTestPhyPort                    
Et3                  connected    1        full   unconf EbraTestPhyPort                    
Et4                  connected    1        full   unconf EbraTestPhyPort                    
Et5        backplane connected    routed   full   unconf EbraTestPhyPort                    
Ma0                  connected    routed   full   10G    10/100/1000                        
Po1                  connected    routed   full   unconf N/A                                

ARISTA01T1>
```

## testbed路由设计
下面说明testbed中的BGP路由设计。
```
              +------+
              +  VM  +---------+
              +------+         |
                               |
              +------+         |
              +  VM  +---------+
              +------+         |
+-------+                  +---+---+     
|  PTF  +------------------+  DUT  |
+-------+                  +---+---+
              +------+         |
              +  VM  +---------+
              +------+         |
                               |
              +------+         |
              +  VM  +---------+
              +------+
```
在这个拓扑中，VMs（vEOS）充当DUT的BGP邻居。VMs生成并且宣告BGP路由给DUT.这种方式有几个问题：
- 在vEOS很难生成任意路由，例如，写一个复杂的路由表，过滤生成需要的路由
- 消耗很多内存在vENOS中
- 特定的NOS规则。如果我们打算从VN切换到SONiC，我们需要重写所有的路由表。
```
              +------+
    +---------+  VM  +---------+
    |         +------+         |
    |                          |
    |         +------+         |
    +---------+  VM  +---------+
    |         +------+         |
+---+---+                  +---+---+     
|  PTF  |                  |  DUT  |
+---+---+                  +---+---+
    |         +------+         |
    +---------+  VM  +---------+
    |         +------+         |
    |                          |
    |         +------+         |
    +---------+  VM  +---------+
              +------+
```
新的方法是将VM作为一个透传设备，我们在PTF容器上运行exabgp,exabgp通告如有信息给VM，VM再将路由信息通告给DUT。这种方式有几个好处：
- VM模板变得简单很多。只有基础的端口，lag，BGP配置
- VM的内存开销变小
- exbgp可以生成复杂路由条目
- 容易支持不同的NOS作为邻居设备，例如SONiC vm

## 拓扑
1. 配置testbed的拓扑定义在一个文件中：`testbed.csv`
2. 一个脚本去操作所有的testbed:`testbed-cli.sh`
3. 灵活的拓扑允许将VM_SET和PTF容器作为一个实体看待
4. 所有的VM管理网口ip定义在：`veos`
5. PTF容器在所有拓扑中被使用
6. 自动构建fanout switch的配置（需要被重构）
7. 请看示例模块如果你想设置任意的testbed的拓扑

### testbed拓扑配置
- `testbed.csv`文件由以下组成：
    - 物理拓扑；VMs和PTF容器的端口如何与DUT连接
    - VMs的配置模板
- 拓扑在`vars/topo_*.yml`文件中
- 当前的拓扑有：
    - t1:32个VMs + 用来端口注入的PTF容器
    - t1-lag：24个VMs + 用来端口注入的PTF容器。其中8个VMs在每一LAG中有两个端口
    - ptf32: 拥有32个个端口的PTF容器与DUT端口直连
    - ptf64: 和ptf32相同，但是拥有64个端口
    - t0：4个VMs + PTF容器（4个用来端口注入，28个用来直连DUT）

### 当前的拓扑
#### t1
![](https://rancho333.gitee.io/pictures/testbed-t1.png)
- 需要32个VMs
- 所有的DUT端口直连VMs
- PTF容器只有注入端口

#### t1-lag
![](https://rancho333.gitee.io/pictures/testbed-t1-lag.png)
- 需要24个VMs
- 所有的DUT端口直连VMs
- PTF容器只有注入端口

#### ptf32
![](https://rancho333.gitee.io/pictures/testbed-ptf32.png)
- 不需要VMs
- 所有的DUT端口直连PTF容器
- PTF容器没有注入端口

#### ptf64
![](https://rancho333.gitee.io/pictures/testbed-ptf64.png)
和ptf32一样

#### t0
![](https://rancho333.gitee.io/pictures/testbed-t0.png)
- 需要4个VMs
- 4个DUT端口连接到VMs
- PTF容器有4个注入端口与28个直连端口

## testbed配置

### testbed清单
- `ansible/lab`：包含实验的所有DUTs， fanout switch, testbed server拓扑
- `ansible/veos`：所有的server和VMs

###

## Sonic-Mgmt testbed设置
从github上将sonic testbed设置到自己的环境中将会是一个冗长的过程。在将测试用例跑起来之前有十多个文件需要更新。
然而，这个过程可以通过testbed.yaml和TestbedProcessing.py自动完成。testbed.yaml是一个配置文件（编译所有需要运行testcase的数据到一个文件中）。TestbedProcess.py的工作原理是：从配置文件拉取信息，然后将信息推送到它们属于的文件中去。这篇指南将会勾勒并简易化testbed的设置。

### 目标
通过使用testbed.yaml和TestbedProcessing.py来完成testbed的设置。这篇指南结束后，应该完成sonic-mgmt testbed的设置并且将testcases跑起来。
 
### 预迁移设置 
 sonic-mgmt启动并运行测试用例需要下述的设备：
 - Linux服务器
 - root fanout
 - leaf fanout
 - DUT (device under test)
 testbed的信息和拓扑可以从overview中获取到。

### 修改 Testbed.yaml配置文件
在testbed.yaml中有7个主要的部分需要编辑：
1. device_groups
2. devices
3. host_vars
4. veos_groups
5. veos
6. testbed
7. topology
每一部分文件的作用都需要按顺序的写好。具体信息在Sonic-Mgmt testbed Configuration中有描述

对于testbed.yaml文件（在ansible下面有个testbed-new.yaml文件）：

#### （可选）testbed_config部分：
- name - 给testbed配置文件选择一个名字
- alias - 给testbed配置文件选择一个别名

##### device_groups部分
用法：lab

device_group部分生成lab文件，是用来设置testbed的的必须清单文件。配置文件的格式是yaml格式，脚本会将之转换成INI格式。device_group部分包含实验室中所有DUTs, fanout switchs，testbed server拓扑。组子节点从下面的device部分介绍。在大多数情况下可以不用管这一部分。

#### devices部分
用法：files/sonic_lab_devices, group_vars/fanout/secrets, group_vars/lab/secrets, lab

device部分是包含所有设备和主机的字典。这部分不包含PTF容器的信息。关于PTF容器的信息，查看testbed.csv文件。
对每一个你添加的设备，添加下面的信息：

| Hostname | ansible_host | ansible_ssh_user | ansible_ssh_pass | HwSKU | device_type |
| ---- | ---- | ---- | ---- | ---- | ---- | 
| str-msn2700-01 | [IP Address] | [username] | [password] | DevSonic | DevSonic |
| str-7260-10 | [IP Address] | [username] | [password] | Arista-7260QX-64 | FanoutRoot |
| str-7260-10 | [IP Address] | [username] | [password] | Arista-7260QX-64 | FanoutLeaf |
| str-acs-serv-01 | [IP Address] | [username] | [password] | TestServ | Server |

- hostname - 设备名称
- ansible_host - 设备的管理IP
- ansible_ssh_user - 设备登录名称
- ansible_ssh_pass - 设备登录密码
- hesku - 这是用来查阅验证的值（在/group_vars/all/labinfo.json）。没有这部分，就爱那个会失败。确保这部分在labinfo.json中有准确的数据。
- device_type - 设备类型。如果只有4种设备，可以将提供标签留白不填写。

lab server部分需要不同的字段输入：ansible_become_pass, sonicadmin_user(用户名), sonicadmin_password, sonic_inital_password. 这些字段是可选的，因为它们是直接从group_var/lab/secrets.yml中获取的变量。所以为了便利，这部分的配置文件作为一个拷贝。

#### host_vars部分

用法：所有的host_val数据

host的参数在此处设置。在这篇指南中，我们在此处定义server（str-acs-serv-01）：
对于每一个你添加的host，定义或确认如下数据：

- mgmt_bridge
- mgmt_prefixlen (这个应该和mgmt_subnet_mask_length匹配)
- mgmt_gw
- external_about

#### veos_groups部分

用法：veos

#### veos部分

用法：group_vars/eos/cred, main.yml, group_vars/vm_host/creds


#### testbed部分

用法： testbed.csv

#### 拓扑部分

用法： files/sonic_lab_links.csv

#### docker_registry部分

用法： /vars/docker_registry.yml


### testbed运行脚本

当testbed.yaml文件配置好后，将TestbedProcess.py和testbed.yaml文件放在sonic-mgmt/ansible下面。

运行TestbedProcessing.py脚本：
```
python TestbedProcessing.py -i testbed.yaml
options:
-i = 解析testbed.yaml文件
-basedir = 项目的根目录
-backup = 文件的备份文件夹
```

#### VMS命令
开启VMS（使用vms_1）:
```
./testbed-cli.sh start-vms vms_1 password.txt
```
停止VMS（使用vms_1）:
```
./testbed-cli.sh stop-vms vms_1 password.txt
```

### 部署（PTF32）拓扑容器

在这篇指南中，将会使用testbed-cli.sh添加ptf32-1作为示例

移除拓扑 ptf32-1:
```
./testbed-cli.sh remove-topo ptf32-1 password.txt
```

添加拓扑 ptf32-1:
```
./testbed-cli.sh add-topo ptf32-1 password.txt
```
可以使用"docker ps"或者"dokcer container ls"命令去检查是否添加或移除。

### 运行第一个测试用例（Neighbour）

当VMs和ptf32-1拓扑成功添加后，第一个测试用例“neighbour”就可以运行起来了。testbed的名字和测试用例的名字需要通过变量声明出来。请检查一下，之后，playbook就可以运行了。
运行如下命令：
```
export TESTBED_NAME=ptf32-1
export TESTCASE_NAME=neighbour
echo $TESTBED_NAME
echo $TESTCASE_NAME
ansible-playbook -i lab -l sonic-ag9032 test_sonic.ynl -e testbed_name=$TESTBED_NAME -e testcase_name=$TESTCASE_NAME
```

## 排错

问题：Testbed命令行提示没有password文件
解决方式：创建一个空的password文件去绕过这个问题

问题：即使在我运行完stop-vms命令后IPs不可达
解决方式：如果运行了stop-vms命令后这个问题依然存在，运行如下命令：
```
virsh
list
destory VM_Name (删除占用这个IP的VM)
exit(退出virsh)，在永久删除这个IPs前请确保没有其它VM使用这个IPs
```

问题：任务设置失败。SSH Error：data could not be sent to the remote host
解决方式：导致这个现象的问题可能有很多。
    1. 确保这台主机可以通过SSH到达
    2. group_vars/all/lab_info.json文件中包含了正确的凭证吗？
    3. 设备在files/sonic_lab_devices.cav中有正确的hwsku吗？
    4. 确保lab文件中在IPs后面没有"/"，INI文件无法识别
    5. 重新检查testbed.yaml配置文件，是否获取了IPs和正确的凭证
