---
title: localhost和127.0.0.1的区别
date: 2023-09-24 17:30:03
categories:
    - network
tags:
    - Linux
    - localhost
    - dns
---


# localhost和127.0.0.1的区别

## 背景

有人告诉我localhost和127.0.0.1的区别是localhost 不经过网卡，把我惊到了，因为我还真不知道这个知识点，于是去特别去验证了一下，这是个错误的理解，localhost会解析成127.0.0.1 然后接下来的流程和127.0.0.1 一模一样

我用Google搜了下标题，果然得到如下图:

![image-20230910100147730](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/image-20230910100147730.png)

红框里是排第一、第四的文章，都大言不惭地说localhost不经过网卡、不受防火墙网管限制等。

我也看了下第二、第三的文章，这两篇都是说在MySQL命令行中连 localhost 的时候，MySQL命令行会判断 localhost 这个字符串然后不走DNS 解析流程(走的话就肯定解析成了127.0.0.1)，因为是本地连接，可以绕过OS 的内核栈用MySQLD 启动的时候生成的 unix-socket 管道直接连上MySQLD，这样效率更高。

错误信息大概就是在MySQL这个特殊场景下演变而来的，**英文搜索就没有这个错误污染信息**

但这不是我要说的重点，我想说的是自己动手去求证！这一直都是我们星球里强调的能力和目标，我把[这条发到Twitter上后有无数的傻逼跑出来质疑或者一知半解不去验证就丢一个结论，这是我最痛恨的](https://twitter.com/plantegg/status/1700011179324920117)。比如：

- Localhost 写死了在 /etc/hosts(那我就要问，你清空/etc/hosts localhost还能工作吗？)

- Localhost 不走网卡（但凡抓个包就知道走了，我估计他们抓了，抓的是eth0. 这里有个小小的歧义 loopback 本地回环网卡算不算网卡）

所以我特意再写篇文章再验证下各种质疑，并让大家看看是怎么验证的，我希望你们可以跟着验证一遍而不是只要知道个结论

## 结论

Localhost 会按[dns解析流程进行解析](https://plantegg.github.io/2019/06/09/%E4%B8%80%E6%96%87%E6%90%9E%E6%87%82%E5%9F%9F%E5%90%8D%E8%A7%A3%E6%9E%90%E7%9B%B8%E5%85%B3%E9%97%AE%E9%A2%98/)，然后和127.0.0.1 一样。在特殊的程序中比如MySQL 命令行会对localhost提前做特别处理。

完整的区别见[这篇英文](https://www.tutorialspoint.com/difference-between-localhost-and-127-0-0-1#:~:text=The%20most%20significant%20difference%20between,look%20up%20a%20table%20somewhere.)(Google 英文第一篇就是)总结：

![image-20230910101843256](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/image-20230910101843256.png)

## 验证

### 问题1：经过网卡吗？

Ping localhost/127.0.0.1，然后 tcpdump -i any icmp or icmp6  [说明：any（抓所有网卡）icmp (精确点只抓ping包) ]，可以明显抓到网络包，所以你可以理解为经过网卡。这指的是这个网络包完整地经过了内核协议栈，加tcp包头、ip包头、mac 包头等等。

而很多人理解的不经过网卡是指不走内核协议栈(毕竟是本机)，加tcp包头、ip包头、mac 包头然后又脱mac包头、脱ip包头、tcp包头，有点像没必要的折腾。比如你通过unix socket 连就不走内核协议栈，性能要高一些

但**严格来说是没经过物理意义上的网卡**，因为 lo 是一块虚拟网卡，不需要插网线，不会真的走到网卡、网线然后回来。如果让内核重新设计，让127.0.0.1 不过经过内核协议栈行不行？我觉得是完全可以的，当时为什么这么设计我也不懂。

总之，**我强调经过网卡是从完整经过了内核协议栈、能抓到这个概念上来说**的，为了跟别人说用127.0.0.1比用本机物理IP 性能要好而言(实际没有区别)，你如果用本机物理IP 也同样走 lo 网卡



### 问题2：localhost和127.0.0.1 的关系

如图是我在centos、微软azure(应该是个ubuntu)、macos下做的测试：

![image-20230910103644707](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/image-20230910103644707.png)

### 问题3：如果/etc/hosts 中没有写死 localhost 127.0.0.1 会怎么样？

如下图，ping的时候即使没有 /etc/hosts 也可以把localhost 解析成127.0.0.1，为什么呢？所以接着我就 nslookup 看一下是哪个 DNS server做的这事，最后我用114.114.114.114 这个公网的DNS 做了解析，就不认识localhost了，说明去掉 /etc/hosts 之后 会把localhost 发给dns server解析，标准的dns(比如114.114.114.114,8.8.8.8) 都不会返回127.0.0.1 ，但是有些特定实现的为了省事帮你解析到127.0.0.1了

![image-20230910104133832](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/image-20230910104133832.png)

### 问题4：127.0.0.1比localhost少了查/etc/hsots 到底快多少?

这个问题来自这个评论：https://twitter.com/InnerHack/status/1700012845302436087  所以我去验证了一下，特别强调这个数据意义不大，但是你们可以学会用strace，命令：

```
strace -tt ping -c 1 localhost
```

然后你得到如下图，从strace时间戳你可以看到 localhost 解析成127.0.0.1 的过程，再后面就是ping 127.0.0.1(这里也说明了前面的结论，两者是一样的，就是多了域名解析)

![image-20230910104733229](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/image-20230910104733229.png)

域名解析的时候，先去找/etc/hosts 没找到再去找 /etc/resolv.conf 拿dns server ip然后把localhost发给这个dns  server 解析，tcpdump抓包如下，红框是dns server返回的结果：

![image-20230910105107629](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/image-20230910105107629.png)

### 问题5：127.0.0.1 和127.1 的关系

127.1 会自动补全成127.0.0.1 

### 问题6：为什么还是抓不到包

ping localhost的时候没有包，只有127.1有，如下图：

![image-20240505103504490](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/image-20240505103504490.png)

这是对提示信息敏感度不够，仔细看上图右下角的 ::1 这是个ipv6地址；也就是localhost被默认指向了这个 ipv6(localhost其实可以随便配置指向哪里，新一点的OS 默认都是指向 ipv6了)，抓包命令多加一个 icmp6  (一个协议名字，默认不抓这个协议) 就能抓到了：tcpdump -i any icmp6

## 总结

唯有动手能解释一切，不要空逼逼(不是说你们，是说Twitter上那帮人，我是被他们留言多了逼着写了这篇)

我是欢迎一切有理有据的质疑，事实文中很多信息来源于别人的质疑，然后我去验证

然后好多验证手段你们可以学学，比如nslookup/tcpdump/strace 等。

我给的文章链接也可以仔细读读，能学到很多东西，每一次进步都来自你深挖、展开能力。

