---
title: SONiC中Vxlan-decap测试用例简析
date: 2021-04-28 15:16:06
tags: SONiC
---

## 写在前面
本文简要分析SONiC testbed中Vxlan decap测试用例的实现，作为对[vxlan学习](https://rancho333.github.io/2021/02/03/vxlan%E5%AD%A6%E4%B9%A0/)的补充。
<!--more-->

## 背景简述
Vxlan技术的本质是通过overlay实现一个vm无感知的大二层网络，一般用于数据中心，好处是vm迁移时可以保持IP不变（再辅以一些技术手段可以保持业务不中断）,换种方式说，vm可以在任意物理主机上实现和网关的二层互通。

## 测试用例简析
在`sonic-mgmt/tests/vxlan`下共有5个测试文件：
```
test_vnet_route_leak.py
test_vnet_vxlan.py
test_vxlan_decap.py
vnet_constants.py
vnet_utils.py
```
本次只是简要分析下`test_vxlan_decap.py`测试内容。

## 测试内容
测试dut在数据面对vxlan报文的解封装。对每一vlan会运行三个case。
1. Vxlan： 给portchannel接口发送封装的vxlan报文，应该在对应的vlan接口上看到payload报文。
2. RegularLAGtoVLAN: 发送常规报文给portchannel接口，应该在对应的vlan接口上看到该报文。
3. RegularVLANtoLAG: 发送常规报文给vlan成员接口，应该在portchannel接口上看到该报文。

![](https://rancho333.github.io/pictures/vxlan_tests.png)

## 测试参数
共有6个测试参数。
1. `config_file`是运行test所需要的所有必要信息。该文件由ansible构造生成。该参数不可缺省。
2. `vxlan_enabled`是一个布尔参数。当设置为true时，vxlan测试失败整个测试失败。该参数默认为false。
3. `count`是一个整数。表示发包数，默认为1.
4. `dut_host`是dut的ip地址
5. `sonic_admin_user`是dut的登录名
6. `sonic_admin_password`是登录密码

## 测试方法
testbed设置好之后，运行:
```
./run_tests.sh -d cel-seastone-01 -n cel_slx_t0 -c vxlan/test_vxlan_decap.py -t t0,any
```

## 测试结果

测试失败

log记录下来供后续参考。
```
E               "delta": "0:01:30.984956", E               "end": "2021-04-28 09:12:57.714679", E               "failed": true, E               "invocation": {E                   "module_args": {E                       "_raw_params": "ptf --test-dir ptftests vxlan-decap.Vxlan --platform-dir ptftests --qlen=10000 --platform remote -t 'vxlan_enabled=False;count=10;config_file='\"'\"'/tmp/vxlan_decap.json'\"'\"';sonic_admin_user=u'\"'\"'admin'\"'\"';sonic_admin_password=u'\"'\"'password'\"'\"';dut_hostname=u'\"'\"'10.251.0.100'\"'\"';sonic_admin_alt_password=u'\"'\"'YourPaSsWoRd'\"'\"'' --relax --debug info --log-file /tmp/vxlan-decap.Vxlan.Removed.2021-04-28-09:11:26.log", E                       "_uses_shell": true, E                       "argv": null, E                       "chdir": "/root", E                       "creates": null, E                       "executable": null, E                       "removes": null, E                       "stdin": null, E                       "stdin_add_newline": true, E                       "strip_empty_ends": true, E                       "warn": trueE                   }E               }, E               "msg": "non-zero return code", E               "rc": 1, E               "start": "2021-04-28 09:11:26.729723", E               "stderr": "WARNING: No route found for IPv6 destination :: (no default route?)\n/usr/local/lib/python2.7/dist-packages/paramiko/transport.py:33: CryptographyDeprecationWarning: Python 2 is no longer supported by the Python core team. Support for it is now deprecated in cryptography, and will be removed in a future release.\n  from cryptography.hazmat.backends import default_backend\nvxlan-decap.Vxlan ... FAIL\n\n======================================================================\nFAIL: vxlan-decap.Vxlan\n----------------------------------------------------------------------\nTraceback (most recent call last):\n  File \"ptftests/vxlan-decap.py\", line 397, in runTest\n    self.warmup()\n  File \"ptftests/vxlan-decap.py\", line 334, in warmup\n    raise AssertionError(\"Warmup failed\")\nAssertionError: Warmup failed\n\n----------------------------------------------------------------------\nRan 1 test in 89.524s\n\nFAILED (failures=1)", E               "stderr_lines": [E                   "WARNING: No route found for IPv6 destination :: (no default route?)", E                   "/usr/local/lib/python2.7/dist-packages/paramiko/transport.py:33: CryptographyDeprecationWarning: Python 2 is no longer supported by the Python core team. Support for it is now deprecated in cryptography, and will be removed in a future release.", E                   "  from cryptography.hazmat.backends import default_backend", E                   "vxlan-decap.Vxlan ... FAIL", E                   "", E                   "======================================================================", E                   "FAIL: vxlan-decap.Vxlan", E                   "----------------------------------------------------------------------", E                   "Traceback (most recent call last):", E                   "  File \"ptftests/vxlan-decap.py\", line 397, in runTest", E                   "    self.warmup()", E                   "  File \"ptftests/vxlan-decap.py\", line 334, in warmup", E                   "    raise AssertionError(\"Warmup failed\")", E                   "AssertionError: Warmup failed", E                   "", E                   "----------------------------------------------------------------------", E                   "Ran 1 test in 89.524s", E                   "", E                   "FAILED (failures=1)"E               ], E               "stdout": "", E               "stdout_lines": []E           }
```

可以找到是在`warmup`中出错了，具体怎么修改后续再跟吧！