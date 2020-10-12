---
title: 就是要你懂网络--谁动了我的TCP连接
date: 2019-11-06 15:30:03
categories:
    - TCP
tags:
    - TCP
    - TTL
    - identification
    - Linux
    - network
---

# 谁动了我的TCP连接

通过一个案例展示TCP连接是如何被reset的，以及identification、ttl都可以帮我们干点啥。

## 问题描述

用户用navicat从自己访问云上的MySQL的时候，点开数据库总是报错（不是稳定报错，有一定的概率报错）

## 抓包

在 Navicat 机器上抓包如下：

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/83b07725d92b9e4d3eb4a504cf83cc09.png)

从抓包可以清楚看到 Navicat 发送 Use Database后收到了 MySQL（来自3306端口）的Reset重接连接命令，所以连接强行中断，然后 Navicat报错了。注意图中红框中的 Identification 两次都是13052，先留下不表，这是个线索。

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/53b5dc8e0a90ed9ad641caf38399141b.png)

## MySQL Server上抓包

特别说明下，MySQL上抓到的不是跟Navicat上抓到的同一次报错，所以报错的端口等会不一样

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/70287488290b38cd4753d9fce0bee945.png)

从这个图中可以清楚看到reset是从 Navicat 客户端发过来的，并且 Use Database被拦截了，没有发到MySQL上。

从这里基本可以判断是客户的防火墙之类的中间设备监控到了关键字之类的触发了防火墙向两边发送了reset，导致了 Navicat 报错。

### 如果连接已经断开

如果连接已经断开后还收到Client的请求包，因为连接在Server上是不存在的，这个时候Server收到这个包后也会发一个reset回去，这个reset的特点是identification是0.

## 到底是谁动了这个连接呢？

### 得帮客户解决问题

虽然原因很清楚，但是客户说连本地 MySQL就没这个问题，连你的云上MySQL就这样，你让我们怎么用？你们得帮我们找到是哪个设备。

### 线索一 Identification

还记得第一个截图中的两个相同的identification 13052吧，让我们来看看基础知识：


![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/eed9ba1f9ba492ed8954ae7f39e72803.png)

（摘自 TCP卷一），简单来说这个 identification 用来标识一个连接中的每个包，这个序号按包的个数依次递增，通信双方是两个不同的序列。

所以如果这个reset是MySQL发出来的话，因为MySQL发出的前一个包的 identification 是23403，所以这个必须是23404，实际上居然是13502（而且还和Navicat发出的 Use Database包是同一个 identification），这是非常不对的。

所以可以大胆猜测，这里有个中间设备收到 Use Database后触发了不放行的逻辑，于是冒充 Navicat给 MySQL Server发了reset包，src ip/src port/seq等都直接用Navicat的，identification也用Navicat的，所以 MySQL Server收到的 Reset看起来很正常（啥都是对的，没留下一点冒充的痕迹）。

但是这个中间设备还要冒充MySQL Server给 Navicat 也发个reset，有点难为中间设备了，这个时候中间设备手里只有 Navicat 发出来的包， src ip/src port/seq 都比较好反过来，但是 identification 就不好糊弄了，手里只有 Navicat的，因为 Navicat和MySQL Server是两个序列的 identification，这下中间设备搞不出来MySQL Server的identification，怎么办？ 只能糊弄了，就随手用 Navicat 自己的 identification填回去了（所以看到这么个奇怪的 identification）

但是这不影响实际连接被reset，也就是验证包的时候不会判断identification的正确性。

### TTL

说了半天identification还是没解决问题啊，还得进一步找到是哪个机器，我们先来看一个基础知识 TTL(Time-to-Live):

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/ed8c624b704b0c94da2ca76a37b39916.png)

然后我们再看看 Navicat收到的这个reset包的ttl是63，而正常的MySQL Server回过来的包是47，而发出的第一个包初始ttl是64，所以这里可以很清楚地看到在Navicat 下一跳发出的这个reset

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/b288a740f9f10007485e37fd339051f8.png)

既然是下一跳干的直接拿这个包的src mac地址，然后到内网中找这个内网设备就可以了，最终找到是一个锐捷的防火墙。

### 扩展一下

假如这里不是下一跳，而是隔了几跳发过来的reset，那么这个src mac地址就不是发reset设备的mac了，那该怎么办呢？

可以根据中间的跳数(TTL)，再配合 traceroute 来找到这个设备的ip

## slb主动reset的话

ttl是102, identification是31415，探活reset不是这样的。

## 总结

基础知识很重要，但是知道ttl、identification到会用ttl、identification是两个不同的层次。只是看书的话未必会有很深的印象，实际也不会定会灵活使用。

平时不要看那么多书，会用才是关键。


