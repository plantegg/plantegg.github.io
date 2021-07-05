---
title: 活久见，TCP连接互串了
date: 2020-11-18 17:30:03
categories:
    - TCP
tags:
    - Linux
    - TCP
    - network
    - reset
---

# 活久见，TCP连接互串了

## 背景

应用每过一段时间总是会抛出几个连接异常的错误，需要查明原因。

排查后发现是TCP连接互串了，这个案例实在是很珍惜，所以记录一下。

## 抓包

业务结构： 应用->MySQL(10.112.61.163)

在 应用 机器上抓包这个异常连接如下（3269为MySQL服务端口）：

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/dd657fee9d961a786c05e8d3cccbc297.png)

粗一看没啥奇怪的，就是应用发查询给3269，但是一直没收到3269的ack，所以一直重传。这里唯一的解释就是网络不通。最后MySQL的3269还回复了一个rst，这个rst的id是42889，引起了我的好奇，跟前面的16439不连贯，正常应该是16440才对。（请记住上图中的绿框中的数字）

于是我过滤了一下端口61902上的所有包：

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/8ca7da8ccec0041dd5d3f66f94d1f574.png)

可以看到绿框中的查询从61902端口发给3269后，很奇怪居然收到了一个来自别的IP+3306端口的reset，这个包对这个连接来说自然是不认识（这个连接只接受3269的回包），就扔掉了。但是也没收到3269的ack，所以只能不停地重传，然后每次都收到3306的reset，reset包的seq、id都能和上图的绿框对应上。

明明他们应该是两个连接：

>  61902->10.141.16.0:3306
>
>  61902->10.112.61.163:3269

他们虽然用的本地ip端口（61902）是一样的， 但是根据四元组不一样，还是不同的TCP连接，所以应该是不会互相干扰的。但是实际看起来**seq、id都重复了**，不会有这么巧，非常像是TCP互串了。

## 分析原因

10.141.16.0 这个ip看起来像是lvs的ip，查了一下系统，果然是lvs，然后这个lvs 后面的rs就是10.112.61.163

那么这个连结构就是10.141.16.0:3306：

> 应用 -> lvs(10.141.16.0:3306)-> 10.112.61.163:3269  跟应用直接连MySQL是一回事了

所以这里的疑问就变成了：**10.141.16.0 这个IP的3306端口为啥能知道 10.112.61.163:3269端口的seq和id，也许是TCP连接串了**

接着往下排查

### [先打个岔，分析下这里的LVS的原理](/2019/06/20/就是要你懂负载均衡--lvs和转发模式/)

这里使用的是 full NAT模型(full NetWork Address Translation-全部网络地址转换)

基本流程（类似NAT）：

1. client发出请求（sip 200.200.200.2 dip 200.200.200.1）
2. 请求包到达lvs，lvs修改请求包为**（sip 200.200.200.1， dip rip）** 注意这里sip/dip都被修改了
3. 请求包到达rs， rs回复（sip rip，dip 200.200.200.1）
4. 这个回复包的目的IP是VIP(不像NAT中是 cip)，所以LVS和RS不在一个vlan通过IP路由也能到达lvs
5. lvs修改sip为vip， dip为cip，修改后的回复包（sip 200.200.200.1，dip 200.200.200.2）发给client

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/94d55b926b5bb1573c4cab8353428712.png)

**注意上图中绿色的进包和红色的出包他们的地址变化**

本来这个模型下都是正常的，但是为了Real Server能拿到client ip，也就是Real Server记录来源ip的时候希望记录的是client ip而不是LVS ip。这个时候LVS会将client ip放在tcp的options里面，然后在RealServer机器的内核里面将options中的client ip取出替换掉 lvs ip。所以Real Server上感知到的对端ip就是client ip。

回包的时候RealServer上的内核模块同样将目标地址从client ip改成lvs ip，同时将client ip放入options中。



## 回到问题

看完理论，再来分析这两个连接的行为

fulnat模式下连接经过lvs到达mysql后，mysql上看到的连接信息是，cip+port，也就是在MySQL上的连接

**lvs-ip:port -> 10.112.61.163:3269  被修改成了 **client-ip:61902 **-> 10.112.61.163:3269

那么跟不走LVS的连接：

**client-ip:61902 ->  10.112.61.163:3269 (直连) 完全重复了。**

MySQL端看到的两个连接四元组一模一样了：

> 10.112.61.163:3269 -> client-ip:61902 (走LVS，本来应该是lvs ip的，但是被替换成了client ip) 
>
> 10.112.61.163:3269 -> client-ip:61902 (直连) 

这个时候应用端看到的还是两个连接：

> client-ip:61902 -> 10.141.16.0:3306 （走LVS） 
>
> client-ip:61902 ->  10.112.61.163:3269 (直连) 

总结下，也就是这个连接经过LVS转换后在服务端（MYSQL）跟直连MySQL的连接四元组完全重复了，也就是MySQL会认为这两个连接就是同一个连接，所以必然出问题了。

实际两个连接建立的情况：

>  和mysqlserver的61902是04:22建起来的，和lvs的61902端口 是42:10建起来的，和lvs的61902建起来之后马上就出问题了

## 问题出现的条件

- fulnat模式的LVS，RS上装有slb_toa内核模块（RS上会将LVS ip还原成client ip）
- client端正好重用一个相同的本地端口分别和RS以及LVS建立了两个连接

这个时候这两个连接在MySQL端就会变成一个，然后两个连接的内容互串，必然导致rst

这个问题还挺有意思的，估计没几个程序员一辈子能碰上一次。推荐另外一个好玩的连接：[如何创建一个自己连自己的TCP连接](/2020/07/01/如何创建一个自己连自己的TCP连接/)



## 参考资料

[就是要你懂负载均衡--lvs和转发模式](/2019/06/20/就是要你懂负载均衡--lvs和转发模式/)

https://idea.popcount.org/2014-04-03-bind-before-connect/

[no route to host](https://github.com/kubernetes/kubernetes/issues/81775 )

[另一种形式的tcp连接互串，新连接重用了time_wait的port，导致命中lvs内核表中的维护的旧连接发给了老的realserver](https://zhuanlan.zhihu.com/p/127099484)

