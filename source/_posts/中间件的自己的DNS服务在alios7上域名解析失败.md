---
title: 中间件的vipclient服务在centos7上域名解析失败
date: 2019-01-13 10:30:03
categories: DNS
tags:
    - vipclient
    - EDNS
    - DNS
---

# 中间件的vipclient服务在centos7上域名解析失败

> 我们申请了一批ECS，操作系统是centos7，这些ECS部署了中间件的DNS服务（vipclient），但是发现这个时候域名解析失败，而同样的配置在centos6上就运行正确



## 抓包分析

分别在centos6、centos7上nslookup通过同一个DNS Server解析同一个域名，并抓包比较得到如下截图（为了方便我将centos6、7抓包做到了一张图上）：

![image.png](http://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/1d5295ccb1fab715f246b54faf94eaaf.png)

绿色部分是正常的解析（centos6），**红色部分是解析，多了一个OPT（centos7）**

赶紧Google一下OPT，原来DNS协议还有一个extention，参考[这里](https://tools.ietf.org/html/rfc6891#page-15 "EDNS OPT")： 

而centos7默认启用edns，但是vipclient实现的时候没有支持edns，所以 centos7 解析域名就出了问题

## 通过 dig 命令来查看dns解析过程

在centos7上，通过命令 dig edas.console.cztest.com 解析失败，但是改用这个命令禁用edns后就解析正常了：dig +noedns edas.console.cztest.com 

vipclient会启动一个53端口，在上面监听dns query，也就是自己就是一个DNS Service

## 分析vipclient域名解析返回的包内容

![image.png](http://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/0882e4815fb1acfa80f813db4bb7265b.png)

把上图中最后4个16进制翻译成10进制IP地址，这个IP地址正是域名所对应的IP，可见vipclient收到域名解析后，因为看不懂edns协议，就按照自己的理解返回了结果，客户端收到这个结果后按照edns协议解析不出来IP，也就是两个的协议不对等导致了问题

## 总结

centos7之前默认都不启用edns，centos7后默认启用edns，但是vipclient目前不支持edns
通过命令：dig +noedns edas.console.cztest.com 能解析到域名所对应的IP
但是命令：dig edas.console.cztest.com  解析不到IP，因为vipclient（相当于这里的dns server）没有兼容edns，实际返回的结果带了IP但是客户端不支持edns协议所以解析不到（vipclient返回的格式、规范不对）