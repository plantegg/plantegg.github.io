---
title: 一个没有遵守tcp规则导致的问题
date: 2018-11-26 16:30:03
categories: troubleshooting
tags:
    - performance
    - troubleshooting
    - network
    - TCP
---
# 一个没有遵守tcp规则导致的问题

### 问题描述

应用连接数据库一段时间后，执行SQL的时候总是抛出异常，通过抓包分析发现每次发送SQL给数据的时候，数据库总是Reset这个连接

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/3ea1a415f772af24d8f619a38542eb7e.png)

注意图中34号包，server（5029）发了一个fin包给client ，想要断开连接。client没断开，接着发了一个查询SQL给server。

进一步分析所有断开连接（发送第一个fin包）的时间点，得到如图：

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/0ac00bfe8dcf87fa5c4997c89a16eb59.png)

基本上可以猜测，server（5029端口）在建立连接100秒终止后如果没有任何请求过来就主动发送fin包给client，要断开连接，但是这个时候client比较无耻，收到端口请求后没搭理（除非是故意的），这个时候意味着server准备好关闭了，也不会再给client发送数据了（ack除外）。

但是client虽然收到了fin断开连接的请求不但不理，过一会还不识时务发SQL查询给server，server一看不懂了（server早就申明连接关闭，没法发数据给client了），就只能回复reset，强制告诉client断开连接吧，client这时才迫于无奈断开了这次连接（图一绿框）

client的应用代码层肯定会抛出异常。


### server强行断开连接

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/eca804fbb71e9cdfb033a9c072d8b72d.png)

18745号包，client发了一个查询SQL给server，server先是回复ack 18941号包，然后回复fin 19604号包，强行断开连接，client端只能抛异常了