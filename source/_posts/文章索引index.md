---
title: 文章索引
date: 2117-06-07 18:30:03
categories: TCP
tags:
    - TCP queue
    - network
    - performance
    - tcpdump
    - LVS
---

## 精华文章推荐

#### [国产CPU和Intel、AMD性能PK](/2022/01/13/%E4%B8%8D%E5%90%8CCPU%E6%80%A7%E8%83%BD%E5%A4%A7PK/) 从Intel、AMD、海光、鲲鹏920、飞腾2500 等CPU在TPCC、sysbench下的性能对比来分析他们的性能差距，同时分析内存延迟对性能的影响

![image-20220319115644219](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20220319115644219.png)

#### [CPU的制造和概念](/2021/06/01/CPU的制造和概念/) 从最底层的沙子开始用8篇文章来回答关于CPU的各种疑问以及大量的实验对比案例和测试数据来展示了CPU的各种原理，比如多核、超线程、NUMA、睿频、功耗、GPU、大小核再到分支预测、cache_line失效、加锁代价、IPC等各种指标（都有对应的代码和测试数据）。

![image-20210802161410524](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20210802161410524-1011377.png) 

#### [在2010年前后MySQL、PG、Oracle数据库在使用NUMA的时候碰到了性能问题，流传最广的这篇  MySQL – The MySQL “swap insanity” problem and the effects of the NUMA architecture http://blog.jcole.us/2010/09/28/mysql-swap-insanity-and-the-numa-architecture/ 文章描述了性能问题的原因(文章中把原因找错了)以及解决方案：关闭NUMA。 实际这个原因是kernel实现的一个低级bug，这个Bug在2014年修复了https://github.com/torvalds/linux/commit/4f9b16a64753d0bb607454347036dc997fd03b82，但是修复这么多年后仍然以讹传讹，这篇文章希望正本清源、扭转错误的认识。](2021/05/14/%E5%8D%81%E5%B9%B4%E5%90%8E%E6%95%B0%E6%8D%AE%E5%BA%93%E8%BF%98%E6%98%AF%E4%B8%8D%E6%95%A2%E6%8B%A5%E6%8A%B1NUMA/)

![image-20210517082233798](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20210517082233798.png)

#### [《Intel PAUSE指令变化是如何影响自旋锁以及MySQL的性能的》 从一个参数引起的rt抖动定位到OS锁等待再到CPU Pause指令，以及不同CPU型号对Pause使用cycles不同的影响，最终反馈到应用层面的rt全过程。在MySQL内核开发的时候考虑了Pause，但是没有考虑不同的CPU型号，所以换了CPU型号后性能差异比较大](2019/12/16/Intel%20PAUSE%E6%8C%87%E4%BB%A4%E5%8F%98%E5%8C%96%E6%98%AF%E5%A6%82%E4%BD%95%E5%BD%B1%E5%93%8D%E8%87%AA%E6%97%8B%E9%94%81%E4%BB%A5%E5%8F%8AMySQL%E7%9A%84%E6%80%A7%E8%83%BD%E7%9A%84/)

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/d567449fe52725a9d0b9d4ec9baa372c.png)

#### [10倍性能提升全过程](2018/01/23/10+%E5%80%8D%E6%80%A7%E8%83%BD%E6%8F%90%E5%8D%87%E5%85%A8%E8%BF%87%E7%A8%8B/) 在双11的紧张流程下，将系统tps从500优化到5500，从网络到snat、再到Spring和StackTrace，一次全栈性能优化过程的详细记录和分析。

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/05703c168e63e96821ea9f921d83712b.png)

#### [就是要你懂TCP--半连接队列和全连接队列：偶发性的连接reset异常、重启服务后短时间的连接异常，通过一篇文章阐明TCP连接的半连接队列和全连接队大小是怎么影响连接创建的，以及用什么工具来观察队列有没有溢出、连接为什么会RESET](2017/06/07/%E5%B0%B1%E6%98%AF%E8%A6%81%E4%BD%A0%E6%87%82TCP--%E5%8D%8A%E8%BF%9E%E6%8E%A5%E9%98%9F%E5%88%97%E5%92%8C%E5%85%A8%E8%BF%9E%E6%8E%A5%E9%98%9F%E5%88%97/)

<img src="https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/1579241362064-807d8378-6c54-4a2c-a888-ff2337df817c.png" alt="image.png" style="zoom:80%;" />



#### [就是要你懂TCP--性能和发送接收Buffer的关系：发送窗口大小(Buffer)、接收窗口大小(Buffer)对TCP传输速度的影响，以及怎么观察窗口对传输速度的影响。BDP、RT、带宽对传输速度又是怎么影响的](2019/09/28/%E5%B0%B1%E6%98%AF%E8%A6%81%E4%BD%A0%E6%87%82TCP--%E6%80%A7%E8%83%BD%E5%92%8C%E5%8F%91%E9%80%81%E6%8E%A5%E6%94%B6Buffer%E7%9A%84%E5%85%B3%E7%B3%BB/) 

![](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/e177d59ecb886daef5905ed80a84dfd2.png)

#### [就是要你懂网络--一个网络包的旅程：教科书式地阐述书本中的路由、网关、子网、Mac地址、IP地址是如何一起协作让网络包最终传输到目标机器上。](2019/05/15/%E5%B0%B1%E6%98%AF%E8%A6%81%E4%BD%A0%E6%87%82%E7%BD%91%E7%BB%9C--%E4%B8%80%E4%B8%AA%E7%BD%91%E7%BB%9C%E5%8C%85%E7%9A%84%E6%97%85%E7%A8%8B/)  同时可以跟讲这块的[RFC1180](https://tools.ietf.org/html/rfc1180)比较一下，RFC1180 写的确实很好，清晰简洁，图文并茂，结构逻辑合理，但是对于90%的程序员没有什么卵用，看完几周后就忘得差不多，因为他不是从实践的角度来阐述问题，中间没有很多为什么，所以一般资质的程序员看完当时感觉很好，实际还是不会灵活运用

![](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/8f5d8518c1d92ed68d23218028e3cd11.png)

#### [从网络路由连通性的原理上来看负载均衡lvs的DR、NAT、FullNAT到底搞了些什么鬼，以及为什么要这么搞，和带来的优缺点：《就是要你懂负载均衡--lvs和转发模式》](2019/06/20/%E5%B0%B1%E6%98%AF%E8%A6%81%E4%BD%A0%E6%87%82%E8%B4%9F%E8%BD%BD%E5%9D%87%E8%A1%A1--lvs%E5%92%8C%E8%BD%AC%E5%8F%91%E6%A8%A1%E5%BC%8F/)

![](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/94d55b926b5bb1573c4cab8353428712.png)

#### [LVS 20倍的负载不均衡，原来是内核的这个Bug](2019/07/19/%E5%B0%B1%E6%98%AF%E8%A6%81%E4%BD%A0%E6%87%82%E8%B4%9F%E8%BD%BD%E5%9D%87%E8%A1%A1--%E8%B4%9F%E8%BD%BD%E5%9D%87%E8%A1%A1%E8%B0%83%E5%BA%A6%E7%AE%97%E6%B3%95%E5%92%8C%E4%B8%BA%E4%BB%80%E4%B9%88%E4%B8%8D%E5%9D%87%E8%A1%A1/)，这个内核bug现在还在，可以稳定重现，有兴趣的话去重现一下，然后对照源代码以及抓包分析一下就清楚了。

#### [就是要你懂TCP--握手和挥手，不是你想象中三次握手、四次挥手就理解了TCP，本文从握手的本质--握手都做了什么事情、连接的本质是什么等来阐述握手、挥手的原理](2017/06/02/%E5%B0%B1%E6%98%AF%E8%A6%81%E4%BD%A0%E6%87%82TCP--%E8%BF%9E%E6%8E%A5%E5%92%8C%E6%8F%A1%E6%89%8B/)

![](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/6d66dadecb72e11e3e5ab765c6c3ea2e.png)

#### [nslookup OK but ping fail--看看老司机是如何解决问题的，解决问题的方法肯定比知识点重要多了，同时透过一个问题怎么样通篇来理解一大块知识，让这块原理真正在你的只是提示中扎根下来](2019/01/09/nslookup-OK-but-ping-fail/)

![](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/ca466bb6430f1149958ceb41b9ffe591.png)

#### [如何在工作中学习](2018/05/23/%E5%A6%82%E4%BD%95%E5%9C%A8%E5%B7%A5%E4%BD%9C%E4%B8%AD%E5%AD%A6%E4%B9%A0/) 一篇很土但是很务实可以复制的方法论文章。不要讲举一反三、触类旁通，谁都知道要举一反三、触类旁通，但是为什么我总是不能够举一反三、触类旁通？

#### [举三反一--从理论知识到实际问题的推导](2020/11/02/举三反一--从理论知识到实际问题的推导/) 坚决不让思路跑偏，如何从一个理论知识点推断可能的问题



## 性能相关（2015-2018年）

#### [就是要你懂TCP--半连接队列和全连接队列](2017/06/07/%E5%B0%B1%E6%98%AF%E8%A6%81%E4%BD%A0%E6%87%82TCP--%E5%8D%8A%E8%BF%9E%E6%8E%A5%E9%98%9F%E5%88%97%E5%92%8C%E5%85%A8%E8%BF%9E%E6%8E%A5%E9%98%9F%E5%88%97/)  偶发性的连接reset异常、重启服务后短时间的连接异常

#### [就是要你懂TCP--性能和发送接收Buffer的关系：发送窗口大小(Buffer)、接收窗口大小(Buffer)对TCP传输速度的影响，以及怎么观察窗口对传输速度的影响。BDP、RT、带宽对传输速度又是怎么影响的](2019/09/28/%E5%B0%B1%E6%98%AF%E8%A6%81%E4%BD%A0%E6%87%82TCP--%E6%80%A7%E8%83%BD%E5%92%8C%E5%8F%91%E9%80%81%E6%8E%A5%E6%94%B6Buffer%E7%9A%84%E5%85%B3%E7%B3%BB/)  发送窗口大小(Buffer)、接收窗口大小(Buffer)对TCP传输速度的影响，以及怎么观察窗口对传输速度的影响

#### [就是要你懂TCP--性能优化大全](2019/06/21/%E5%B0%B1%E6%98%AF%E8%A6%81%E4%BD%A0%E6%87%82TCP--%E6%80%A7%E8%83%BD%E4%BC%98%E5%8C%96%E5%A4%A7%E5%85%A8/)

#### [就是要你懂TCP--TCP性能问题](2018/06/14/%E5%B0%B1%E6%98%AF%E8%A6%81%E4%BD%A0%E6%87%82TCP--%E6%9C%80%E7%BB%8F%E5%85%B8%E7%9A%84TCP%E6%80%A7%E8%83%BD%E9%97%AE%E9%A2%98/) Nagle算法和delay ack
#### [10倍性能提升全过程](2018/01/23/10+%E5%80%8D%E6%80%A7%E8%83%BD%E6%8F%90%E5%8D%87%E5%85%A8%E8%BF%87%E7%A8%8B/) 在双11的紧张流程下，将系统tps从500优化到5500，从网络到snat、再到Spring和StackTrace，看看一个性能全栈工程师如何在各种工具加持下发现各种问题的。



## CPU系列文章（2021年完成）

#### [CPU的制造和概念](/2021/06/01/CPU的制造和概念/)

#### [十年后数据库还是不敢拥抱NUMA？](/2021/05/14/十年后数据库还是不敢拥抱NUMA/)

#### [Intel PAUSE指令变化是如何影响自旋锁以及MySQL的性能的](/2019/12/16/Intel PAUSE指令变化是如何影响自旋锁以及MySQL的性能的/)

#### [Perf IPC以及CPU性能](/2021/05/16/Perf IPC以及CPU利用率/)

#### [CPU性能和CACHE](https://plantegg.github.io/2021/07/19/CPU性能和CACHE/)

#### [CPU 性能和Cache Line](/2021/05/16/CPU Cache Line 和性能/)

#### [AMD Zen CPU 架构 以及 AMD、海光、Intel、鲲鹏的性能对比](/2021/08/13/AMD_Zen_CPU架构/)

#### [Intel、海光、鲲鹏920、飞腾2500 CPU性能对比](/2021/06/18/几款CPU性能对比/)



## 网络相关基础知识（2017年完成）

#### [就是要你懂网络--一个网络包的旅程](2019/05/15/%E5%B0%B1%E6%98%AF%E8%A6%81%E4%BD%A0%E6%87%82%E7%BD%91%E7%BB%9C--%E4%B8%80%E4%B8%AA%E7%BD%91%E7%BB%9C%E5%8C%85%E7%9A%84%E6%97%85%E7%A8%8B/)

#### [通过案例来理解MSS、MTU等相关TCP概念](2018/05/07/%E5%B0%B1%E6%98%AF%E8%A6%81%E4%BD%A0%E6%87%82TCP--%E9%80%9A%E8%BF%87%E6%A1%88%E4%BE%8B%E6%9D%A5%E5%AD%A6%E4%B9%A0MSS%E3%80%81MTU/)
#### [就是要你懂TCP--握手和挥手](2017/06/02/%E5%B0%B1%E6%98%AF%E8%A6%81%E4%BD%A0%E6%87%82TCP--%E8%BF%9E%E6%8E%A5%E5%92%8C%E6%8F%A1%E6%89%8B/)

#### [wireshark-dup-ack-issue and keepalive](2017/06/02/%E5%B0%B1%E6%98%AF%E8%A6%81%E4%BD%A0%E6%87%82TCP--wireshark-dup-ack-issue/)
#### [一个没有遵守tcp规则导致的问题](2018/11/26/%E4%B8%80%E4%B8%AA%E6%B2%A1%E6%9C%89%E9%81%B5%E5%AE%88tcp%E8%A7%84%E5%88%99%E5%AF%BC%E8%87%B4%E7%9A%84%E9%97%AE%E9%A2%98/)

#### [kubernetes service 和 kube-proxy详解](2020/09/22/kubernetes service 和 kube-proxy详解/)

## DNS相关

#### [就是要你懂DNS--一文搞懂域名解析相关问题](2019/06/09/%E4%B8%80%E6%96%87%E6%90%9E%E6%87%82%E5%9F%9F%E5%90%8D%E8%A7%A3%E6%9E%90%E7%9B%B8%E5%85%B3%E9%97%AE%E9%A2%98/)
#### [nslookup OK but ping fail](2019/01/09/nslookup-OK-but-ping-fail/)

#### [Docker中的DNS解析过程](2019/01/12/Docker%E4%B8%AD%E7%9A%84DNS%E8%A7%A3%E6%9E%90%E8%BF%87%E7%A8%8B/)

#### [windows7的wifi总是报DNS域名异常无法上网](2019/01/10/windows7%E7%9A%84wifi%E6%80%BB%E6%98%AF%E6%8A%A5DNS%E5%9F%9F%E5%90%8D%E5%BC%82%E5%B8%B8%E6%97%A0%E6%B3%95%E4%B8%8A%E7%BD%91/)

## LVS 负载均衡

#### [就是要你懂负载均衡--lvs和转发模式](2019/06/20/%E5%B0%B1%E6%98%AF%E8%A6%81%E4%BD%A0%E6%87%82%E8%B4%9F%E8%BD%BD%E5%9D%87%E8%A1%A1--lvs%E5%92%8C%E8%BD%AC%E5%8F%91%E6%A8%A1%E5%BC%8F/)
#### [就是要你懂负载均衡--负载均衡调度算法和为什么不均衡](2019/07/19/%E5%B0%B1%E6%98%AF%E8%A6%81%E4%BD%A0%E6%87%82%E8%B4%9F%E8%BD%BD%E5%9D%87%E8%A1%A1--%E8%B4%9F%E8%BD%BD%E5%9D%87%E8%A1%A1%E8%B0%83%E5%BA%A6%E7%AE%97%E6%B3%95%E5%92%8C%E4%B8%BA%E4%BB%80%E4%B9%88%E4%B8%8D%E5%9D%87%E8%A1%A1/)

## 网络工具

#### [就是要你懂Unix Socket 进行抓包解析](2018/01/01/%E9%80%9A%E8%BF%87tcpdump%E5%AF%B9Unix%20Socket%20%E8%BF%9B%E8%A1%8C%E6%8A%93%E5%8C%85%E8%A7%A3%E6%9E%90/)

#### [就是要你懂网络监控--ss用法大全](2016/10/12/ss%E7%94%A8%E6%B3%95%E5%A4%A7%E5%85%A8/)

#### [就是要你懂抓包--WireShark之命令行版tshark](2019/06/21/%E5%B0%B1%E6%98%AF%E8%A6%81%E4%BD%A0%E6%87%82%E6%8A%93%E5%8C%85--WireShark%E4%B9%8B%E5%91%BD%E4%BB%A4%E8%A1%8C%E7%89%88tshark/)
#### [netstat timer keepalive explain](2017/08/28/netstat%20%E7%AD%89%E7%BD%91%E7%BB%9C%E5%B7%A5%E5%85%B7/)
#### [Git HTTP Proxy and SSH Proxy](2018/03/14/%E5%A6%82%E4%BD%95%E8%AE%BE%E7%BD%AEgit%20Proxy/)

