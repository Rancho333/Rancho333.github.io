---
title: SONiC中syncd调用SAI简析
date: 2021-09-06 13:45:19
tags: 
    - SONiC
    - syncd
---

# 写在前面
本文以SONiC`202012`版本进行`syncd`模块初始化分析。sycnd与orchagent强相关，主要有5个动作，分别是`create`、`remove`、`set`、`get`以及`notify`。对于前三个动作，orchagent调用sairedis api写往ASIC_DB即返回成功，`get`动作会阻塞等待syncd的答复，当syncd接收到`notify`事件后会通过ASIC_DB通知到orchagent。本文暂分析syncd的初始化动作。 

本文可以总结成一句话：SONiC上层根据objecttype获取对应的info结构，从而调用里面的具体方法，完成sai的调用。
<!--more-->

# syncd_main.cpp中初始化ASIC 
`syncd_main.cpp`是syncd进程的入口函数，里面主要做3件事情：
1. 初始或日志服务
2. 获取warmreboot状态
3. 实例化类`VendorSai`、`Syncd`以及运行`syncd->run`函数进入syncd主循环模块

在`Syncd_main.cpp`中主要是三行代码：
```
auto vendorSai = std::make_shared<VendorSai>();             //实例化VendorSai，作为参数传给syncd
auto syncd = std::make_shared<Syncd>(vendorSai, commandLineOptions, isWarmStart);   //实例化Syncd
syncd->run();                                               // 执行run方法
```

对于`VendorSai`实例化，它的构造函数并没有做什么特别的事。

对于`Syncd`实例化
```
//Syncd.cpp
// 注册notify事件的回调函数，onFdbEvent，onPortStateChange，onSwitchShutdownRequest，onSwitchStateChange等
m_sn.onFdbEvent = std::bind(&NotificationHandler::onFdbEvent, m_handler.get(), _1, _2);
m_sn.onPortStateChange = std::bind(&NotificationHandler::onPortStateChange, m_handler.get(), _1, _2);

vendorSai->initialize               //初始化sai api，并将之放到 m_apis中

//初始化关心的DB、channel, 在syncd::run中通过其获取各种事件然后进行处理
m_selectableChannel = std::make_shared<RedisSelectableChannel>(
                m_dbAsic,
                ASIC_STATE_TABLE,
                REDIS_TABLE_GETRESPONSE,
                TEMP_PREFIX,
                modifyRedis);
m_restartQuery = std::make_shared<swss::NotificationConsumer>(m_dbAsic.get(), SYNCD_NOTIFICATION_CHANNEL_RESTARTQUERY);
m_flexCounter = std::make_shared<swss::ConsumerTable>(m_dbFlexCounter.get(), FLEX_COUNTER_TABLE);
    m_flexCounterGroup = std::make_shared<swss::ConsumerTable>(m_dbFlexCounter.get(), FLEX_COUNTER_GROUP_TABLE);
```
对于方法`initialize`
```
auto status = sai_api_initialize(flags, service_method_table);      //初始化sai api
int failed = sai_metadata_apis_query(sai_api_query, &m_apis);       //将api放入数据结构 m_api中
```

`Syncd`的主逻辑在`run`方法中，循环处理各种到来的事件，首先是初始化switch，在`onSyncdStart`中：
```
HardReiniter hr(m_client, m_translator, m_vendorSai, m_handler); // 构造函数只是完成参数初始化
m_switches = hr.hardReinit();
```
然后调
```
//HardReiniter.cpp
   std::vector<std::shared_ptr<SingleReiniter>> vec;

    // perform hard reinit on all switches

    for (auto& kvp: m_switchMap)
    {
        auto sr = std::make_shared<SingleReiniter>(
                m_client,
                m_translator,
                m_vendorSai,
                m_handler,
                m_switchVidToRid.at(kvp.first),
                m_switchRidToVid.at(kvp.first),
                kvp.second);

        sr->hardReinit();
// 这里面有做多ASIC的考虑，我们当前只会用到单ASIC
```
之后
```
 processSwitches();
 status = m_vendorSai->create(SAI_OBJECT_TYPE_SWITCH, &m_switch_rid, 0, attr_count, attr_list);
```
在VendorSai.cpp中
```
auto info = sai_metadata_get_object_type_info(objectType);          // 根据SAI_OBJECT_TYPE_SWITCH获取type_info
auto status = info->create(&mk, switchId, attr_count, attr_list);   // 根据type_info中的方法（sai提供）初始化ASIC
```

`sai_metadata_get_object_type_info`实际上就是一个数组，根据`objectType`获取相应的数据。
```
//saimetadatautils.c
const sai_object_type_info_t* sai_metadata_get_object_type_info(
        _In_ sai_object_type_t object_type)
{                                                                                                                                                                                              
    if (sai_metadata_is_object_type_valid(object_type))
    {   
        return sai_metadata_all_object_type_infos[object_type];
    }   
 
    return NULL;
}
```

数组`type_info`的定义在：
```
//saimetadata.c
const sai_object_type_info_t* const sai_metadata_all_object_type_infos[] = {
    NULL,  
    &sai_metadata_object_type_info_SAI_OBJECT_TYPE_PORT,                                                                                                                                       
    &sai_metadata_object_type_info_SAI_OBJECT_TYPE_LAG,
    &sai_metadata_object_type_info_SAI_OBJECT_TYPE_VIRTUAL_ROUTER,
    &sai_metadata_object_type_info_SAI_OBJECT_TYPE_NEXT_HOP,
    ……
    &sai_metadata_object_type_info_SAI_OBJECT_TYPE_SWITCH,
    ……
    };
```
以`type_switch`为例，它的具体数据为：
```
const sai_object_type_info_t sai_metadata_object_type_info_SAI_OBJECT_TYPE_SWITCH = {
    .objecttype           = SAI_OBJECT_TYPE_SWITCH,                    
    .objecttypename       = "SAI_OBJECT_TYPE_SWITCH",                  
    .attridstart          = SAI_SWITCH_ATTR_START,                     
    .attridend            = SAI_SWITCH_ATTR_END,                       
    .enummetadata         = &sai_metadata_enum_sai_switch_attr_t,
    .attrmetadata         = sai_metadata_object_type_sai_switch_attr_t,
    .attrmetadatalength   = 195,                                       
    .isnonobjectid        = false,                                     
    .isobjectid           = !false,                                    
    .structmembers        = NULL,                                      
    .structmemberscount   = 0,                                         
    .revgraphmembers      = sai_metadata_SAI_OBJECT_TYPE_SWITCH_rev_graph_members,
    .revgraphmemberscount = 8,                                         
    .create               = sai_metadata_generic_create_SAI_OBJECT_TYPE_SWITCH,
    .remove               = sai_metadata_generic_remove_SAI_OBJECT_TYPE_SWITCH,
    .set                  = sai_metadata_generic_set_SAI_OBJECT_TYPE_SWITCH,
    .get                  = sai_metadata_generic_get_SAI_OBJECT_TYPE_SWITCH,
    .getstats             = sai_metadata_generic_get_stats_SAI_OBJECT_TYPE_SWITCH,
    .getstatsext          = sai_metadata_generic_get_stats_ext_SAI_OBJECT_TYPE_SWITCH,
    .clearstats           = sai_metadata_generic_clear_stats_SAI_OBJECT_TYPE_SWITCH,
    .isexperimental       = false,                                     
    .statenum             = &sai_metadata_enum_sai_switch_stat_t,                                                                                                                           
};                                                   
```
由于在`VendorSai::create`中调用的是其`create`方法，我们看下其实现：
```
//saimetadata.c
sai_status_t sai_metadata_generic_create_SAI_OBJECT_TYPE_SWITCH(
    _Inout_ sai_object_meta_key_t *meta_key,
    _In_ sai_object_id_t switch_id,
    _In_ uint32_t attr_count,
    _In_ const sai_attribute_t *attr_list)
{             
    return sai_metadata_sai_switch_api->create_switch(&meta_key->objectkey.key.object_id, attr_count, attr_list);
}  
//sai_metadata_sai_switch_api的数据类型是sai_switch_api_t
sai_switch_api_t *sai_metadata_sai_switch_api = NULL;

// 给sai_metadata_sai_switch_api赋值，获取的实际就是sai_switch_api_t的实现
status = api_query(SAI_API_SWITCH, (void**)&sai_metadata_sai_switch_api);
// sai_metadata_generic_create_SAI_OBJECT_TYPE_SWITCH是将switch_api中的create方法单独拎出来，以前的SAI冒似都是获取apis，然后调用switch_api，最后调用create_switch
apis->switch_api = sai_metadata_sai_switch_api;
```

`sai_switch_api_t`结构体的定义在：
```
//saiswitch.c
typedef struct _sai_switch_api_t
{                                                                                                                                                                                              
    sai_create_switch_fn                   create_switch;
    sai_remove_switch_fn                   remove_switch;
    sai_set_switch_attribute_fn            set_switch_attribute;
    sai_get_switch_attribute_fn            get_switch_attribute;
    sai_get_switch_stats_fn                get_switch_stats;
    sai_get_switch_stats_ext_fn            get_switch_stats_ext;
    sai_clear_switch_stats_fn              clear_switch_stats;
    sai_switch_mdio_read_fn                switch_mdio_read;
    sai_switch_mdio_write_fn               switch_mdio_write;
    sai_create_switch_tunnel_fn            create_switch_tunnel;
    sai_remove_switch_tunnel_fn            remove_switch_tunnel;
    sai_set_switch_tunnel_attribute_fn     set_switch_tunnel_attribute;
    sai_get_switch_tunnel_attribute_fn     get_switch_tunnel_attribute;
 
} sai_switch_api_t;
```
该结构的成员函数的实现则是由各ASIC厂家实现，以`create_switch`为例，在broadcom sai中：
```
//brcm_sai_switch.c
const sai_switch_api_t switch_apis = {
    brcm_sai_create_switch,
    brcm_sai_remove_switch,
    brcm_sai_set_switch_attribute,
    brcm_sai_get_switch_attribute,
};     
// brcm_sai_create_switch具体的实现则不过分纠结了，SDK干的活   
```
这样下来，从`SAI_OBJECT_TYPE_SWITCH`获取`tyep_info`结构，再到create方法在`sai`层的定义，以及最后的厂商实现就都连起来了。

总结下来，`VendorSai::create`方法中：
```
auto info = sai_metadata_get_object_type_info(objectType);      //根据objecttype获取info结构，包含了该type的所有方法及属性
auto status = info->create(&mk, switchId, attr_count, attr_list);  // 调用type的create方法完成sai的调用
```

`onSyncdStart`之后，创建线程处理notifiy事件。
```
m_processor->startNotificationsProcessingThread();

//将care的db放到select监控中，接下来的main loop中就是循环处理这四个select事件
s->addSelectable(m_selectableChannel.get());
s->addSelectable(m_restartQuery.get());
s->addSelectable(m_flexCounter.get());
s->addSelectable(m_flexCounterGroup.get());
```

# 对于某一具体功能的下发

此处以IP Tunnel的创建为例。在swss docker中执行`swssconfig ipinip.json`，在`orchagent`这边大致流程为：

```
//orchdaemon.cpp 中会调用每一功能模块中的doTask任务
TunnelDecapOrch *tunnel_decap_orch = new TunnelDecapOrch(m_applDb, APP_TUNNEL_DECAP_TABLE_NAME);
 m_orchList = { …… gIntfsOrch, gNeighOrch, gRouteOrch, copp_orch, tunnel_decap_orch, qos_orch, ……};
for (Orch *o : m_orchList)
             o->doTask();

//tunneldecaporch.cpp
if (addDecapTunnel(key, tunnel_type, ip_addresses, p_src_ip, dscp_mode, ecn_mode, encap_ecn_mode, ttl_mode))
{
    SWSS_LOG_NOTICE("Tunnel(s) added to ASIC_DB.");
}
status = sai_tunnel_api->create_tunnel(&tunnel_id, gSwitchId, (uint32_t)tunnel_attrs.size(), tunnel_attrs.data());
// 给每一ip创建一个decap tunnel entry
if (!addDecapTunnelTermEntries(key, dst_ip, tunnel_id))

// 将tunnel_term写入到ASIC DB中
sai_status_t status = sai_tunnel_api->create_tunnel_term_table_entry(&tunnel_term_table_entry_id, gSwitchId, (uint32_t)tunnel_table_entry_attrs.size(), tunnel_table_entry_attr    s.data());  
SWSS_LOG_NOTICE("Created tunnel entry for ip: %s", ip.c_str());
```

`syncd`的mainloop中接收到通知，进行处理：
```
//syncd.cpp
processEvent(*m_selectableChannel.get());

processSingleEvent(kco);

// create，remove，set，get都是使用这一个API，大概这就是quard的意思吧
return processQuadEvent(SAI_COMMON_API_CREATE, kco);
```

我们创建的是IP tunnel的解封装规则，对应的sai objtype是`SAI_OBJECT_TYPE_TUNNEL_TERM_TABLE_ENTRY`.
```
//syncd.cpp
// 获取参数列表
auto& values = kfvFieldsValues(kco);
sai_attribute_t *attr_list = list.get_attr_list();
uint32_t attr_count = list.get_attr_count();

// 获取type对应的info数据，isnonobjectid是false
auto info = sai_metadata_get_object_type_info(metaKey.objecttype);

status = processOid(metaKey.objecttype, strObjectId, api, attr_count, attr_list);
 
return processOidCreate(objectType, strObjectId, attr_count, attr_list);

// 调用vendorSai中的create方法
sai_status_t status = m_vendorSai->create(objectType, &objectRid, switchRid, attr_count, attr_list);

//在VendorSai.cpp中是create方法的实现
// 根据objecttype获取info结构
auto info = sai_metadata_get_object_type_info(objectType);
// 调用infor中的create方法
auto status = info->create(&mk, switchId, attr_count, attr_list);
//tunnel term的create方法在saimetadata.c中
sai_metadata_generic_create_SAI_OBJECT_TYPE_TUNNEL_TERM_TABLE_ENTRY

// 最后是发送通知信息给swss
sendApiResponse(api, status);
```

# 关于Tunnelmgrd
`swss`中有一类进程以`*mgrd`结尾，它们干的活是将APP_DB中的数据同步到linux kernel，sonic中的一些配置是通过写APP_DB来完成的，`orchagent`完成`ASIC`的下发，`*mgrd`完成kernel的同步。

当然也有与之相反的配置流程，如路由的下发，`zebra`将路由信息下发到kernel，同时发送一份信息到`Fpmsyncd`，`Fpmsyncd`将其写到`APP_DB`,最后`orchagent`将其下发到`ASIC`.

上面两种方式的本质就是`kernel`和`ASIC`之间配置的同步。