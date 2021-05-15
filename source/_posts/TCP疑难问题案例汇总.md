---
title: TCP疑难问题案例汇总
date: 2021-02-14 13:30:03
categories:
    - TCP
tags:
    - Linux
    - TCP
    - network
---

# TCP疑难问题案例汇总

碰到各种奇葩的TCP相关问题，所以汇总记录一下。分析清楚这些问题的所有来龙去脉，就能帮你在TCP知识体系里建立几个坚固的抓手，让TCP知识慢慢在抓手之间生长和互通

## 服务不响应的现象或者奇怪异常的原因分析

 [一个黑盒程序奇怪行为的分析](https://plantegg.github.io/2021/02/10/%E4%B8%80%E4%B8%AA%E9%BB%91%E7%9B%92%E7%A8%8B%E5%BA%8F%E5%A5%87%E6%80%AA%E7%9A%84%E8%A1%8C%E4%B8%BA%E5%88%86%E6%9E%90/) listen端口上很快就全连接队列溢出了，导致整个程序不响应了

[举三反一--从理论知识到实际问题的推导](https://plantegg.github.io/2020/11/02/%E4%B8%BE%E4%B8%89%E5%8F%8D%E4%B8%80--%E4%BB%8E%E7%90%86%E8%AE%BA%E7%9F%A5%E8%AF%86%E5%88%B0%E5%AE%9E%E9%99%85%E9%97%AE%E9%A2%98%E7%9A%84%E6%8E%A8%E5%AF%BC/) 服务端出现大量CLOSE_WAIT 个数正好 等于somaxconn（调整somaxconn大小后 CLOSE_WAIT 也会跟着变成一样的值）

[活久见，TCP连接互串了](https://plantegg.github.io/2020/11/18/TCP%E8%BF%9E%E6%8E%A5%E4%B8%BA%E5%95%A5%E4%BA%92%E4%B8%B2%E4%BA%86/)  应用每过一段时间总是会抛出几个连接异常的错误，需要查明原因。排查后发现是TCP连接互串了，这个案例实在是很珍惜，所以记录一下。

 [如何创建一个自己连自己的TCP连接](https://plantegg.github.io/2020/07/01/如何创建一个自己连自己的TCP连接/)



## 传输速度分析

案例：[TCP传输速度案例分析](https://plantegg.github.io/2021/01/15/TCP%E4%BC%A0%E8%BE%93%E9%80%9F%E5%BA%A6%E6%A1%88%E4%BE%8B%E5%88%86%E6%9E%90/)（长肥网络、rt升高、delay ack的影响等）

原理：[就是要你懂TCP–性能和发送接收Buffer的关系：发送窗口大小(Buffer)、接收窗口大小(Buffer)对TCP传输速度的影响，以及怎么观察窗口对传输速度的影响。BDP、RT、带宽对传输速度又是怎么影响的](https://plantegg.github.io/2019/09/28/就是要你懂TCP--性能和发送接收Buffer的关系/)

[就是要你懂TCP–最经典的TCP性能问题 Nagle和Delay ack](https://plantegg.github.io/2018/06/14/就是要你懂TCP--最经典的TCP性能问题/)

[就是要你懂TCP--性能优化大全](https://plantegg.github.io/2019/06/21/就是要你懂TCP--性能优化大全/)



## TCP队列问题以及连接数

 [到底一台服务器上最多能创建多少个TCP连接](https://plantegg.github.io/2020/11/30/一台机器上最多能创建多少个TCP连接/)

 [就是要你懂TCP队列--通过实战案例来展示问题](https://plantegg.github.io/2019/08/31/就是要你懂TCP队列--通过实战案例来展示问题/)

 [就是要你懂TCP--半连接队列和全连接队列](https://plantegg.github.io/2017/06/07/就是要你懂TCP--半连接队列和全连接队列/)

 [就是要你懂TCP--握手和挥手](https://plantegg.github.io/2017/06/02/就是要你懂TCP--连接和握手/)



## 防火墙和reset定位分析

对ttl、identification等的运用

[关于TCP连接的Keepalive和reset](https://plantegg.github.io/2018/08/26/关于TCP连接的KeepAlive和reset/)

[就是要你懂网络--谁动了我的TCP连接](https://plantegg.github.io/2019/11/06/谁动了我的TCP连接/)



## TCP相关参数

 [TCP相关参数解释](https://plantegg.github.io/2020/01/26/TCP相关参数解释/)

[网络通不通是个大问题–半夜鸡叫](https://plantegg.github.io/2019/05/16/网络通不通是个大问题--半夜鸡叫/) 

[网络丢包](https://plantegg.github.io/2018/12/26/网络丢包/)



## 工具技巧篇

 [netstat定位性能案例](https://plantegg.github.io/2019/04/21/netstat定位性能案例/)

 [netstat timer keepalive explain](https://plantegg.github.io/2017/08/28/netstat --timer/)

[就是要你懂网络监控--ss用法大全](https://plantegg.github.io/2016/10/12/ss用法大全/)

[就是要你懂抓包--WireShark之命令行版tshark](https://plantegg.github.io/2019/06/21/就是要你懂抓包--WireShark之命令行版tshark/)

[通过tcpdump对Unix Domain Socket 进行抓包解析](https://plantegg.github.io/2018/01/01/通过tcpdump对Unix Socket 进行抓包解析/)

[如何追踪网络流量](https://plantegg.github.io/2017/12/07/如何追踪网络流量/)

