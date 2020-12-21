---
title: Docker中的DNS解析过程
date: 2019-01-12 10:30:03
categories: DNS
tags:
    - iptables
    - Docker
    - DNS
---


# Docker中的DNS解析过程 


## 问题描述

> 同一个Docker集群中两个容器中通过 nslookup 同一个域名，这个域名是容器启动的时候通过net alias指定的，但是返回来的IP不一样

如图所示：

![image.png](http://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/892a98b53c7f9e65da79d1d6d890c3b0.png)

图中上面的容器中 nslookup 返回来了两个IP，但是只有146是正确的，155是多出来，不对的。

要想解决这个问题抓包就没用了，因为Docker 中的net alias 域名是 Docker Daemon自己来解析的，也就是在容器中做域名解析（nslookup、ping）的时候，Docker Daemon先看这个域名是不是net alias的，是的话返回对应的ip，如果不是（比如 www.baidu.com) ，那么Docker Daemon再把这个域名丢到宿主机上去解析，在宿主机上的解析过程就是标准的DNS，可以抓包分析。但是Docker Daemon内部的解析过程没有走DNS协议，不好分析，所以得先了解一下 Docker Daemon的域名解析原理

具体参考文章： [http://www.jianshu.com/p/4433f4c70cf0](http://www.jianshu.com/p/4433f4c70cf0) [http://www.bijishequ.com/detail/261401?p=70-67](http://www.bijishequ.com/detail/261401?p=70-67)

## 继续分析所有容器对这个域名的解析

继续分析所有容器对这个域名的解析发现只有某一台宿主机上的有这个问题，而且这台宿主机上所有容器都有这个问题，结合上面的文章，那么这个问题比较明朗了，这台有问题的宿主机的Docker Daemon中残留了一个net alias，你可以理解成cache中有脏数据没有清理。

进而跟业务的同学们沟通，确实155这个IP的容器做过升级，改动过配置，可能升级前这个155也绑定过这个域名，但是升级后绑到146这个容器上去了，但是Docker Daemon中还残留这条记录。

## 重启Docker Daemon后问题解决（容器不需要重启）

重启Docker Daemon的时候容器还在正常运行，只是这段时间的域名解析会不正常，其它业务长连接都能正常运行，在Docker Daemon重启的时候它会去检查所有容器的endpoint、重建sandbox、清理network等等各种事情，所以就把这个脏数据修复掉了。

在Docker Daemon重启过程中，会给每个容器构建DNS Resovler（setup-resolver），如果构建DNS Resovler这个过程中容器发送了大量域名查询过来同时这些域名又查询不到的话Docker Daemon在重启过程中需要等待这个查询超时，然后才能继续往下走重启流程，所以导致启动流程拉长[问题严重的时候导致Docker Daemon长时间无法启动](https://www.atatech.org/articles/87339)

Docker的域名解析为什么要这么做，是因为容器中有两种域名解析需求：
1. 容器启动时通过 net alias 命名的域名
2. 容器中正常对外网各种域名的解析（比如 baidu.com/api.taobao.com)

对于第一种只能由docker daemon来解析了，所以容器中碰到的任何域名解析都会丢给 docker daemon(127.0.0.11), 如果 docker daemon 发现这个域名不认识，也就是不是net alias命名的域名，那么docker就会把这个域名解析丢给宿主机配置的 nameserver 来解析【非常非常像 dns-f/vipclient 的解析原理】


## 容器中的域名解析

容器启动的时候读取宿主机的 /etc/resolv.conf (去掉127.0.0.1/16 的nameserver）然后当成容器的 /etc/resolv.conf, 但是实际在容器中看到的 /etc/resolve.conf 中的nameserver只有一个：127.0.0.11，因为如上描述nameserver都被代理掉了

容器 -> docker daemon(127.0.0.11) -> 宿主机中的/etc/resolv.conf 中的nameserver

如果宿主机中的/etc/resolv.conf 中的nameserver没有，那么daemon默认会用8.8.8.8/8.8.4.4来做下一级dns server，如果在一些隔离网络中（跟外部不通），那么域名解析就会超时，因为一直无法连接到 8.8.8.8/8.8.4.4 ，进而导致故障。

比如 vipserver 中需要解析 armory的域名，如果这个时候在私有云环境，宿主机又没有配置 nameserver, 那么这个域名解析会发送给 8.8.8.8/8.8.4.4 ，长时间没有响应，超时后 vipserver 会关闭自己的探活功能，从而导致 vipserver 基本不可用一样。

修改 宿主机的/etc/resolv.conf后 重新启动、创建的容器才会load新的nameserver



## 如果容器中需要解析vipserver中的域名

1. 容器中安装vipclient，同时容器的 /etc/resolv.conf 配置 nameserver 127.0.0.1 
2. 要保证vipclient起来之后才能启动业务


