---
title: 就是要你懂负载均衡--lvs和转发模式
date: 2019-06-20 15:30:03
categories:
    - LVS
tags:
    - LVS
    - network
    - LoadBalance
    - Linux
---

# 基础知识的力量--lvs和转发模式

> 本文希望阐述清楚LVS的各种转发模式，以及他们的工作流程和优缺点，同时从网络包的流转原理上解释清楚优缺点的来由，并结合阿里云的slb来说明优缺点。


大家都背过LVS的几种转发模式，DR模式性能最好但是部署不灵活；NAT性能差部署灵活多了…… 实际都是没理解好这几个模式背后代表的网络连通性的原理和网络包路由原理，导致大多时候都是死背那几个概念。

如果我们能从网络包背后流转的流程和原理来看LVS的转发模式，那么那些优缺点简直就太直白了，这就是基础知识的力量。

如果对网络包是怎么流转的不太清楚，推荐先看这篇基础：[程序员的网络知识 -- 一个网络包的旅程](https://www.atatech.org/articles/80573) ，对后面理解LVS的各个转发模式非常有帮助。

## 几个术语和缩写

	cip：Client IP，客户端地址
	vip：Virtual IP，LVS实例IP
	rip：Real IP，后端RS地址
	RS: Real Server 后端真正提供服务的机器
	LB： Load Balance 负载均衡器
	LVS： Linux Virtual Server
	sip： source ip
	dip： destination

## LVS的几种转发模式

- DR模型 -- （Director Routing-直接路由）
- NAT模型 -- (NetWork Address Translation-网络地址转换)
- fullNAT -- （full NAT）
- ENAT --（enhence NAT 或者叫三角模式/DNAT，阿里云提供）
- IP TUN模型 -- (IP Tunneling - IP隧道)

## DR模型(Director Routing--直接路由)

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/574a12e18ebbf0bafcfc97b1984305b5.png)

如上图所示基本流程(假设 cip 是200.200.200.2， vip是200.200.200.1）：

1. 请求流量(sip 200.200.200.2, dip 200.200.200.1) 先到达 LVS（图中Director）
2. 然后LVS，根据负载策略挑选众多 RS中的一个，然后将这个网络包的MAC地址修改成这个选中的RS的MAC
3. 然后丢给交换机，交换机将这个包丢给选中的RS
4. 选中的RS看到MAC地址是自己的、dip也是自己的，愉快地收下并处理、回复
5. 回复包（sip 200.200.200.1， dip 200.200.200.2）
6. 经过交换机直接回复给client了（不再走LVS）

我们看到上面流程，请求包到达LVS后，LVS只对包的目的MAC地址作了修改，回复包直接回给了client。

同时要求多个RS和LVS（Director）都配置的是同一个IP地址，但是用的不同的MAC。这就要求所有RS和LVS在同一个子网，在二层路由不需要IP，他们又在同一个子网，所以这里联通性没问题。

RS上会将vip配置在lo回环网卡上，同时route中添加相应的规则，这样在第四步收到的包能被os正常处理。

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/739447baddd120ca23c68ac85c0ea36d.png)


优点：

- DR模式是性能最好的一种模式，入站请求走LVS，回复报文绕过LVS直接发给Client

缺点：

- 要求LVS和rs在同一个vlan，扩展性不够好；
- RS需要配置vip同时特殊处理arp；
- 配置比较复杂；
- 不支持端口映射。


### 为什么要求LVS和RS在同一个vlan（或者说同一个二层网络里）

因为DR模式依赖多个RS和LVS共用同一个VIP，然后依据MAC地址来在LVS和多个RS之间路由，所以LVS和RS必须在一个vlan或者说同一个二层网络里

### DR 模式为什么性能最好

因为回复包不走LVS了，大部分情况下都是请求包小，回复包大，LVS很容易成为流量瓶颈，同时LVS只需要修改进来的包的MAC地址。

### DR 模式为什么回包不需要走LVS了

因为RS和LVS共享同一个vip，回复的时候RS能正确地填好sip为vip，不再需要LVS来多修改一次（后面讲的NAT、Full NAT都需要）

### 总结下 DR的结构

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/bb209bc08a21a28e99703e700acc82e4.png)

绿色是请求包进来，红色是修改过MAC的请求包，SW是一个交换机。

## NAT模型(NetWork Address Translation - 网络地址转换)

nat模式的结构图如下：

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/b806e1615d99f6a018c537a18addc464.png)


基本流程：

1. client发出请求（sip 200.200.200.2，dip 200.200.200.1）
2. 请求包到达LVS(图中Director)，LVS修改请求包为（sip 200.200.200.2， dip rip）
3. 请求包到达rs， rs回复（sip rip，dip 200.200.200.2）
4. 这个回复包不能直接给client，因为rip不是VIP会被reset掉（client看到的连接是vip，突然来一个rip就reset）
5. 但是因为lvs是网关，所以这个回复包先走到网关，网关有机会修改sip
6. 网关修改sip为VIP，修改后的回复包（sip 200.200.200.1，dip 200.200.200.2）发给client

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/bd311051c55f08c8d0add3cb329b87bf.png)


优点：

- 配置简单
- 支持端口映射（看名字就知道）
- RIP一般是私有地址，主要用户LVS和RS之间通信 


缺点：

- LVS和所有RS必须在同一个vlan
- 进出流量都要走LVS转发
- LVS容易成为瓶颈
- 一般而言需要将VIP配置成RS的网关

### 为什么NAT要求lvs和RS在同一个vlan

因为**回复包必须经过lvs再次修改sip为vip，client才认**，如果回复包的sip不是client包请求的dip（也就是vip），那么这个连接会被reset掉。如果LVS不是网关，因为回复包的dip是cip，那么可能从其它路由就走了，LVS没有机会修改回复包的sip

### 总结下NAT结构

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/51b694409882318d5acd6a1422afce03.png)

注意这里LVS修改进出包的(sip, dip)的时候只改了其中一个，所以才有接下来的full NAT。当然NAT最大的缺点是要求LVS和RS必须在同一个vlan，这样限制了LVS集群和RS集群的部署灵活性，尤其是在阿里云这种对外售卖的公有云环境下，NAT基本不实用。

## full NAT模型(full NetWork Address Translation-全部网络地址转换)

基本流程（类似NAT）：

1. client发出请求（sip 200.200.200.2 dip 200.200.200.1）
2. 请求包到达lvs，lvs修改请求包为**（sip 200.200.200.1， dip rip）** 注意这里sip/dip都被修改了
3. 请求包到达rs， rs回复（sip rip，dip 200.200.200.1）
4. 这个回复包的目的IP是VIP(不像NAT中是 cip)，所以LVS和RS不在一个vlan通过IP路由也能到达lvs
5. lvs修改sip为vip， dip为cip，修改后的回复包（sip 200.200.200.1，dip 200.200.200.2）发给client


优点：

- 解决了NAT对LVS和RS要求在同一个vlan的问题，适用更复杂的部署形式

缺点：

- RS看不到cip（NAT模式下可以看到）
- 进出流量还是都走的lvs，容易成为瓶颈（跟NAT一样都有这个问题）


### 为什么full NAT解决了NAT中要求的LVS和RS必须在同一个vlan的问题

因为LVS修改进来的包的时候把(sip, dip)都修改了(这也是full的主要含义吧)，RS的回复包目的地址是vip（NAT中是cip），所以只要vip和rs之间三层可通就行，这样LVS和RS可以在不同的vlan了，也就是LVS不再要求是网关，从而LVS和RS可以在更复杂的网络环境下部署。

### 为什么full NAT后RS看不见cip了

因为cip被修改掉了，RS只能看到LVS的vip，在阿里内部会将cip放入TCP包的Option中传递给RS，RS上一般部署自己写的toa模块来从Options中读取的cip，这样RS能看到cip了, 当然这不是一个开源的通用方案。

### 总结下full NAT的结构

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/94d55b926b5bb1573c4cab8353428712.png) 

**注意上图中绿色的进包和红色的出包他们的地址变化**

那么到现在full NAT解决了NAT的同vlan的要求，**基本上可以用于公有云了**，但是还是没解决进出流量都走LVS的问题（LVS要修改进出的包）。

### 比较下NAT和Full NAT

两者进出都要走LVS，NAT必须要求vip是RS的网关，这个限制在公有云这种应用场景下不能忍，于是Full NAT通过修改请求包的source ip，将原来的source ip从cip改成vip，这样RS回复的时候回复包的目标IP也是vip，所以LVS和RS之间不再要求是同一vlan的关系了。当然带来了新的问题，RS看不见cip了（这个可以通过自定义的vtoa模块来复原）

那么有没有一个方案能够像full NAT一样不限制lvs和RS之间的网络关系，同时出去的流量跟DR模式一样也不走LVS呢？

### 比较下DR、NAT和Full NAT

DR只修改目标Mac地址；
NAT只修改目标IP，LVS做网关得到修改回包的机会，RS能看到client ip；
Full-NAT同时修改 源ip和 目标ip， LVS通过三层路由和RS相通，RS看到的源ip是LVS IP。

## 阿里云的ENAT模式(enhence NAT) 或者叫 三角模式

前后端都是经典类型，属于NAT模式的特例，LVS转发给RS报文的源地址是客户端的源地址。

与NAT模式的差异在于 RS响应客户端的报文不再经过LVS机器，而是直接发送给客户端（源地址是VIP的地址, 后端RS需要加载一个ctk模块， lsmod | grep ctk 确认 ，主要是数据库产品使用）

优点：

- 不要求LVS和RS在同一个vlan
- 出去的流量不需要走LVS，性能好

缺点：

- 阿里集团内部实现的自定义方案，需要在所有RS上安装ctk组件（类似full NAT中的vtoa）

基本流程：

1. client发出请求（cip，vip）
2. 请求包到达lvs，lvs修改请求包为（vip，rip），并将cip放入TCP Option中
3. 请求包根据ip路由到达rs， ctk模块读取TCP Option中的cip
4. 回复包(RIP, vip)被ctk模块截获，并将回复包改写为（vip, cip)
5. 因为回复包的目的地址是cip所以不需要经过lvs，可以直接发给client

ENAT模式在内部也会被称为 三角模式或者DNAT/SNAT模式

### 为什么ENAT的回复包不需要走回LVS了

因为之前full NAT模式下要走回去是需要LVS再次改写回复包的IP，而ENAT模式下，这件事情在RS上被ctk模块提前做掉了

### 为什么ENAT的LVS和RS可以在不同的vlan

跟full NAT一样

### 总结下 ENAT的结构

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/5b498ed88c3233977a592f924affc43a.png)

最后说一下不太常用的 TUN模型

## IP TUN模型(IP Tunneling - IP隧道)

基本流程：

1. 请求包到达LVS后，LVS将请求包封装成一个新的IP报文
2. 新的IP包的目的IP是某一RS的IP，然后转发给RS
3. RS收到报文后IPIP内核模块解封装，取出用户的请求报文
4. 发现目的IP是VIP，而自己的tunl0网卡上配置了这个IP，从而愉快地处理请求并将结果直接发送给客户


优点：

- 集群节点可以跨vlan
- 跟DR一样，响应报文直接发给client

缺点：

- RS上必须安装运行IPIP模块
- 多增加了一个IP头
- LVS和RS上的tunl0虚拟网卡上配置同一个VIP（类似DR）


**DR模式中LVS修改的是目的MAC**

### 为什么IP TUN不要求同一个vlan

因为IP TUN中不是修改MAC来路由，所以不要求同一个vlan，只要求lvs和rs之间ip能通就行。DR模式要求的是lvs和RS之间广播能通

### IP TUN性能

回包不走LVS，但是多做了一次封包解包，不如DR好

### 总结下 IP TUN的结构

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/218e93e6fa37b6f04dae9669de0e3fe3.png)

图中红线是再次封装过的包，ipip是操作系统的一个内核模块。

DR可能在小公司用的比较多，IP TUN用的少一些，相对而言NAT、FullNAT、ENAT这三种在集团内部比较类似，用的也比较多，他们之间的可比较性很强，所以放在一块了。

## 阿里云slb的fnat

本质就是前面所讲的fullnat模式，为了解决RS看不到真正的client ip问题，在阿里云公网上的物理机/宿主机默认都会帮你将source-ip（本来是lvs ip）替换成真正的client ip，这样当包进到ecs的时候source ip已经是client ip了，所以slb默认的fnat模式会让你直接能拿到client ip。回包依然会经过lvs（虽然理论上可以不需要了，但是要考虑rs和client不能直接通，以及管理方便等）

这个进出的替换过程在物理机/宿主机上是avs来做，如果没有avs就得安装slb的toa模块来做了。

这就是为什么slb比直接用lvs要方便些，也就是云服务商提供这种云产品的价值所在。

## 参考资料

[云服务ALB接入，后端依赖内核模块及接口使用指南](https://www.atatech.org/articles/106276)

[程序员的网络知识 -- 一个网络包的旅程](https://www.atatech.org/articles/80573)

[章文嵩（正明）博士和他背后的负载均衡(LOAD BANLANCER)帝国](https://yq.aliyun.com/articles/52752)

https://yizhi.ren/2019/05/03/lvs/



