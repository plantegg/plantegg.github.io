---
title: 流量一样但为什么CPU使用率差别很大
date: 2024-04-26 12:30:03
categories: CPU
tags:
    - performance
    - CPU
    - perf
---



# 流量一样但为什么CPU使用率差别很大

这是我翻到2013年的一篇文章，当时惊动所有公司高人，最后分析得知原因后所有人都跪拜，你要知道那是2013年，正好10年过去了，如果是现在用我们星球的理论去套的话，简直不要太容易



## 问题描述

> 同样大小内存、同样的CPU、同样数量的请求、几乎可以忽略的io，两个机器的load却差异挺大。一个机器的load是12左右，另外一个机器却是30左右
>
> 你可以理解这是两台一摸一样的物理机挂在一个LVS 下，LVS 分发流量绝对均衡

所以要找出为什么？

## 分析

两台机器的资源使用率：

```
//load低、CPU使用率低 的物理机，省略一部分核
Cpu0  : 67.1%us,  1.6%sy,  0.0%ni, 30.6%id,  0.0%wa,  0.0%hi,  0.7%si,  0.0%st
Cpu1  : 64.1%us,  1.6%sy,  0.0%ni, 34.3%id,  0.0%wa,  0.0%hi,  0.0%si,  0.0%st
Cpu2  : 63.0%us,  1.6%sy,  0.0%ni, 35.4%id,  0.0%wa,  0.0%hi,  0.0%si,  0.0%st
Cpu3  : 60.0%us,  1.3%sy,  0.0%ni, 38.4%id,  0.0%wa,  0.0%hi,  0.3%si,  0.0%st
Cpu4  : 59.8%us,  1.3%sy,  0.0%ni, 37.9%id,  1.0%wa,  0.0%hi,  0.0%si,  0.0%st
Cpu5  : 56.7%us,  1.0%sy,  0.0%ni, 42.3%id,  0.0%wa,  0.0%hi,  0.0%si,  0.0%st
Cpu6  : 63.4%us,  1.3%sy,  0.0%ni, 34.6%id,  0.0%wa,  0.0%hi,  0.7%si,  0.0%st
Cpu7  : 62.5%us,  2.0%sy,  0.0%ni, 35.5%id,  0.0%wa,  0.0%hi,  0.0%si,  0.0%st
Cpu8  : 58.5%us,  1.3%sy,  0.0%ni, 39.5%id,  0.0%wa,  0.0%hi,  0.7%si,  0.0%st
Cpu9  : 55.8%us,  1.6%sy,  0.0%ni, 42.2%id,  0.3%wa,  0.0%hi,  0.0%si,  0.0%st

//load高、CPU使用率高 的物理机，省略一部分核
Cpu0  : 90.1%us,  1.9%sy,  0.0%ni,  7.1%id,  0.0%wa,  0.0%hi,  1.0%si,  0.0%st
Cpu1  : 88.5%us,  2.9%sy,  0.0%ni,  8.0%id,  0.0%wa,  0.0%hi,  0.6%si,  0.0%st
Cpu2  : 90.4%us,  1.9%sy,  0.0%ni,  7.7%id,  0.0%wa,  0.0%hi,  0.0%si,  0.0%st
Cpu3  : 86.9%us,  2.6%sy,  0.0%ni, 10.2%id,  0.0%wa,  0.0%hi,  0.3%si,  0.0%st
Cpu4  : 87.5%us,  1.9%sy,  0.0%ni, 10.2%id,  0.0%wa,  0.0%hi,  0.3%si,  0.0%st
Cpu5  : 87.3%us,  1.9%sy,  0.0%ni, 10.5%id,  0.0%wa,  0.0%hi,  0.3%si,  0.0%st
Cpu6  : 90.4%us,  2.9%sy,  0.0%ni,  6.4%id,  0.0%wa,  0.0%hi,  0.3%si,  0.0%st
Cpu7  : 90.1%us,  1.9%sy,  0.0%ni,  7.6%id,  0.0%wa,  0.0%hi,  0.3%si,  0.0%st
Cpu8  : 89.5%us,  2.6%sy,  0.0%ni,  6.7%id,  0.0%wa,  0.0%hi,  1.3%si,  0.0%st
Cpu9  : 90.7%us,  1.9%sy,  0.0%ni,  7.4%id,  0.0%wa,  0.0%hi,  0.0%si,  0.0%st
```

可以分析产出为什么低，检查CPU是否降频、内存频率是否有差异——检查结果一致

10年前经过一阵 perf top 看热点后终于醒悟过来知道得去看 IPC，也就是相同CPU使用率下，其中慢的机器产出低了一半，那么继续通过perf看IPC：

![img](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/FrsOfjsmHa6Zwv67IBgTd-GTI2fT.png)

可以看到两台机器的IPC是 0.3 VS 0.55，和CPU使用率差异基本一致，instructions几乎一样(意味着流量一样，LVS 不背锅)，但是处理同样的instructions 用掉的cpu-clock 几乎差了一倍，这应该是典型的内存时延大了一倍导致的。IPC 大致等于 instrunctions/cpu-clock （IPC：instrunctions per cycles）

经检查这两台物理机都是两路，虽然CPU型号/内存频率一致，但是主板间跨Socket的 QPI带宽差了一倍(主板是两个不同的服务商提供)。可以通过绑核测试不同Socket/Node 下内存时延来确认这个问题

这是同一台机器下两个Socket 的内存带宽，所以如果跨Socket 内存访问多了就会导致时延更高、CPU使用率更高

![img](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/FmaZP2Wf1xiSoHyi2xHslbAVr71_.png)



## 总结

在今天我们看到这种问题就很容易了，但我还是要感叹一下在入门前简直太神奇，入门后也不过尔尔，希望你也早点入门。



第一：向CPU要产出，同样的使用率产出得一样，不一样的话肯定是偷懒了，偷懒的直接证据就是 IPC 低了，导致IPC 低最常见的是内存时延高(内存频率、跨Node/Socket 等，或者内存碎片)；延伸阅读：[性能的本质 IPC](https://t.zsxq.com/10fYf762S) ，也是本星球唯二的必读实验

第二：测试工具很完善了，[lmbench](https://github.com/intel/lmbench) , 怎么用lmbench [可以看这篇](https://plantegg.github.io/2022/01/13/不同CPU性能大PK/) ; 怎么使用perf [Perf IPC以及CPU性能](https://plantegg.github.io/2021/05/16/Perf_IPC以及CPU利用率/)

，学成后装逼可以看 [听风扇声音来定位性能瓶颈](https://plantegg.github.io/2022/03/15/记一次听风扇声音来定位性能/) 



我以前说过每个领域都有一些核心知识点，IPC 就是CPU领域的核心知识点，和tcp的rmem/wmem 一样很容易引导你入门

计算机专业里非要挑几个必学的知识点肯定得有计算机组成原理，但计算机组成原理内容太多，都去看也不现实，况且很多过时的东西，那么我只希望你能记住计算机组成原理里有个最核心的麻烦：内存墙——CPU 访问内存太慢导致了内存墙是我们碰到众多性能问题的最主要、最核心的一个，结合今天这个案例掌握IPC后再来学内存墙，再到理解计算机组成原理就对了，从一个实用的小点入手。

计算机专业里除掉组成原理(有点高大上，没那么接地气)，另外一个我觉得最有用的是网络——看着low但是接地气，问题多，很实用



2011年的文章：

#### **[详解服务器内存带宽计算和使用情况测量](http://blog.yufeng.info/archives/1511)**

更好的工具来发现类似问题：https://github.com/intel/numatop

![img](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/FlOhgPPnxN3DcMRPUvNvbZOuQy0q.png)

 

## 如果你觉得看完对你很有帮助可以通过如下方式找到我

find me on twitter: [@plantegg](https://twitter.com/plantegg)

知识星球：[https://t.zsxq.com/0cSFEUh2J](https://t.zsxq.com/0cSFEUh2J)

开了一个星球，在里面讲解一些案例、知识、学习方法，肯定没法让大家称为顶尖程序员(我自己都不是)，只是希望用我的方法、知识、经验、案例作为你的垫脚石，帮助你快速、早日成为一个基本合格的程序员。

争取在星球内：

- 养成基本动手能力
- 拥有起码的分析推理能力--按我接触的程序员，大多都是没有逻辑的
- 知识上教会你几个关键的知识点

<img src="https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/image-20240324161113874.png" alt="image-20240324161113874" style="zoom:50%;" />