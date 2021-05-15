---
title: docker、swarm的Label使用
date: 2017-03-24 17:30:03
categories: docker
tags:
    - Linux
    - docker
---

# docker、swarm的Label使用

## 需求背景

广发银行需要把方舟集群部署在多个机房（多个机房组成一个大集群），这样物理机和容器vlan没法互相完全覆盖，

也就是可能会出现A机房的网络subnet:192.168.1.0/24, B 机房的网络subnet：192.168.100.0/24 但是他们属于同一个vlan，要求如果容器在A机房的物理机拉起，分到的是192.168.1.0/24中的IP，B机房的容器分到的IP是：192.168.100.0/24

**功能实现：**

- **本质就是对所有物理机打标签，同一个asw下的物理机用同样的标签，不同asw下的物理机标签不同；**
- **创建容器网络的时候也加标签，不同asw下的网络标签不一样，同时跟这个asw下的物理机标签匹配；**
- **创建容器的时候使用 --net=driver:vlan 来动态选择多个vlan网络中的任意一个，然后swarm根据网络的标签要和物理机的标签一致，从而把容器调度到正确的asw下的物理机上。**

**分为如下三个改造点**

**1：**

daemon启动的时候增加标签（其中一个就行）：

| 上联交换机组的名称，多个逗号隔开 | com.alipay.acs.engine.asw.hostname |
| -------------------------------- | ---------------------------------- |
|                                  |                                    |

**2：**
创建网络的时候使用对应的标签：

| 网络域交换机组asw列表的名称，多个逗号隔开                    | com.alipay.acs.network.asw.hostname |
| ------------------------------------------------------------ | ----------------------------------- |
| 该VLAN网络是否必须显式指定，默认为0即不必须，此时当传入--net driver:vlan时ACS会根据调度结果自行选择一个可用的VLAN网络并拼装到参数中 | com.alipay.acs.network.explicit     |

**3：**

Swarm manager增加可选启动选项netarch.multiscope，值为true

### 功能实现逻辑

1. Swarm manager增加可选启动选项netarch.multiscope，当为1时，network create时强制要求必须指定label描述配置VLAN的ASW信息
2. Swarm manager在创建容器时检查网络类型，VLAN网络时则将网络ASW的label放入过滤器中，在调度时按照机器的ASW标签过滤
3. 如果使用者如果不关心具体使用哪个VLAN，则可以指定--net="driver:vlan"，会自动查找driver=vlan的network，并根据调度结果（Node所关联的ASW）自动选择合适的network填入Config.HostConfig.NetworkMode传递给Docker daemon.

如果是现存的环境，修改zk来更新网络标签：

```
[zk: localhost:2181(CONNECTED) 21] get /Cluster/docker/network/v1.0/network/c79e533e4444294ac9cb7838608115c961c6e403d3610367ff4b197ef6b981fc 
{"addrSpace":"GlobalDefault","enableIPv6":false,"generic":{"com.docker.network.enable_ipv6":false,"com.docker.network.generic":{"VlanId":"192"}},"id":"c79e533e4444294ac9cb7838608115c961c6e403d3610367ff4b197ef6b981fc","inDelete":false,"internal":false,"ipamOptions":{"VlanId":"192"},"ipamType":"default","ipamV4Config":"[{\"PreferredPool\":\"192.168.8.0/24\",\"SubPool\":\"\",\"Gateway\":\"192.168.8.1\",\"AuxAddresses\":null}]","ipamV4Info":"[{\"IPAMData\":\"{\\\"AddressSpace\\\":\\\"\\\",\\\"Gateway\\\":\\\"192.168.8.1/24\\\",\\\"Pool\\\":\\\"192.168.8.0/24\\\"}\",\"PoolID\":\"GlobalDefault/192.168.8.0/24\"}]","labels":{},"name":"vlan192-8","networkType":"vlan","persist":true,"postIPv6":false,"scope":"global"}
cZxid = 0x4100008cce
ctime = Fri Mar 09 12:46:44 CST 2018
mZxid = 0x4100008cce
mtime = Fri Mar 09 12:46:44 CST 2018
pZxid = 0x4100008cce
cversion = 0
dataVersion = 0
aclVersion = 0
ephemeralOwner = 0x0
dataLength = 716
numChildren = 0
```

//注意上面的网络还没有标签，修改如下：

``` 
[zk: localhost:2181(CONNECTED) 28] set /Cluster/docker/network/v1.0/network/c79e533e4444294ac9cb7838608115c961c6e403d3610367ff4b197ef6b981fc {"addrSpace":"GlobalDefault","enableIPv6":false,"generic":{"com.docker.network.enable_ipv6":false,"com.docker.network.generic":{"VlanId":"192"}},"id":"c79e533e4444294ac9cb7838608115c961c6e403d3610367ff4b197ef6b981fc","inDelete":false,"internal":false,"ipamOptions":{"VlanId":"192"},"ipamType":"default","ipamV4Config":"[{\"PreferredPool\":\"192.168.8.0/24\",\"SubPool\":\"\",\"Gateway\":\"192.168.8.1\",\"AuxAddresses\":null}]","ipamV4Info":"[{\"IPAMData\":\"{\\\"AddressSpace\\\":\\\"\\\",\\\"Gateway\\\":\\\"192.168.8.1/24\\\",\\\"Pool\\\":\\\"192.168.8.0/24\\\"}\",\"PoolID\":\"GlobalDefault/192.168.8.0/24\"}]",**"labels":{"com.alipay.acs.network.asw.hostname":"238"},**"name":"vlan192-8","networkType":"vlan","persist":true,"postIPv6":false,"scope":"global"}

```

example：

创建网络：//--label="com.alipay.acs.network.asw.hostname=vlan902-63" 
docker network create -d vlan --label="com.alipay.acs.network.asw.hostname=vlan902-63" --subnet=11.162.63.0/24  --gateway=11.162.63.247  --opt VlanId=902 --ipam-opt VlanId=902 hanetwork2
跟daemon中的标签：com.alipay.acs.engine.asw.hostname=vlan902-63 对应，匹配调度

``` 
$sudo cat /etc/docker/daemon.json
{"labels":["com.alipay.acs.engine.hostname=11.239.142.46","com.alipay.acs.engine.ip=11.239.142.46","com.alipay.acs.engine.device_type=Server","com.alipay.acs.engine.status=free","ark.network.vlan.range=vlan902-63","com.alipay.acs.engine.asw.hostname=vlan902-63","com.alipay.acs.network.asw.hostname=vlan902-63"]}
//不指定具体网络，有多个网络的时候自动调度  --net driver:vlan 必须是network打过标签了
docker run -d -it --name="udp10" --net driver:vlan --restart=always reg.docker.alibaba-inc.com/middleware.udp 
```



