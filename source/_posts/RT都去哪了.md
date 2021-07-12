---
title: delay ack拉高实际rt的case
date: 2020-09-16 17:30:03
categories:
    - Performance
tags:
    - Linux
    - Performance
    - TCP
---

## delay ack拉高实际rt的case

## 案例描述

> 开发人员发现client到server的rtt是2.5ms，每个请求1ms server就能处理完毕，但是监控发现的rt不是3.5（1+2.5），而是6ms，想知道这个6ms怎么来的？

如下业务监控图：实际处理时间（逻辑服务时间1ms，rtt2.4ms，加起来3.5ms），但是系统监控到的rt（蓝线）是6ms，如果一个请求分很多响应包串行发给client，这个6ms是正常的（1+2.4*N），但实际上如果send buffer足够的话，按我们前面的理解多个响应包会并发发出去，所以如果整个rt是3.5ms才是正常的。

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/d56f87a19a10b0ac9a3b7009641247a0.png)

## 分析

抓包来分析原因：

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/d5e2e358dd1a24e104f54815c84875c9.png)

实际看到大量的response都是3.5ms左右，符合我们的预期，但是有少量rt被delay ack严重影响了

从下图也可以看到有很多rtt超过3ms的，这些超长时间的rtt会最终影响到整个服务rt

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/48eae3dcd7c78a68b0afd5c66f783f23.png)