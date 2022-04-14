---
title: nslookup-OK-but-ping-fail
date: 2019-01-09 10:30:03
categories: DNS
tags:
    - ping
    - nslookup
    - DNS
    - glibc
    - rotate
---

# nslookup 域名结果正确，但是 ping 域名 返回 unknown host

> 2018-02 update : 最根本的原因 [https://access.redhat.com/solutions/1426263](https://access.redhat.com/solutions/1426263)

## 下面让我们来看看这个问题的定位过程

先Google一下: nslookup ok but ping fail, 这个关键词居然被Google自动提示了，看来碰到这个问题同学的好多

Google到的帖子大概有如下原因：

- 域名最后没有加 . 然后被自动追加了 tbsite.net aliyun.com alidc.net，自然 ping不到了
- /etc/resolv.conf 配置的nameserver要保证都是正常服务的
- /etc/nsswitch.conf 中的这行：hosts: files dns 配置成了 hosts: files mdns dns，而server不支持mdns
- 域名是单标签的（domain 单标签； domain.com 多标签），单标签在windows下走的NBNS而不是DNS协议

检查完我的环境不是上面描述的情况，比较悲催，居然碰到了一个Google不到的问题

### 抓包看为什么解析不了

> 
> DNS协议是典型的UDP应用，一来一回就搞定了查询，效率比TCP三次握手要高多了，DNS Server也支持TCP，不过一般不用TCP

    sudo tcpdump -i eth0 udp and port 53 

抓包发现ping 不通域名的时候都是把域名丢到了 /etc/resolv.conf 中的第二台nameserver，或者根本没有发送 dns查询。

这里要多解释一下我们的环境， /etc/resolv.conf 配置了2台 nameserver，第一台负责解析内部域名，另外一台负责解析其它域名，如果内部域名的解析请求丢到了第二台上自然会解析不到。

所以这个问题的根本原因是挑选的nameserver不对，按照 /etc/resolv.conf 的逻辑都是使用第一个nameserver，失败后才使用第二、第三个备用nameserver。

比较奇怪，出问题的都是新申请到的一批ECS，仔细对比了一下正常的机器，发现有问题的 ECS /etc/resolv.conf 中放了一个词rotate，赶紧查了一下rotate的作用（轮询多个nameserver），然后把rotate去掉果然就好了。

### 风波再起

本来以为问题彻底解决了，结果还是有一台机器ping仍然是unknow host，眼睛都看瞎了没发现啥问题，抓包发现总是把dns请求交给第二个nameserver，或者根本不发送dns请求，这就有意思了，跟我们理解的不太一样。

看着像有cache之类的，于是在正常和不正常的机器上使用 strace ，果然发现了点不一样的东西：

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/ca466bb6430f1149958ceb41b9ffe591.png)

ping的过程中访问了 nscd(name service cache daemon） 同时发现 nscd返回值图中红框的 0，跟正常机器比较发现正常机器红框中是 -1，于是检查 /var/run/nscd/ 下面的东西，kill 掉 nscd进程，然后删掉这个文件夹，再ping，一切都正常了。

**从strace来看所有的ping都会尝试看看 nscd 是否在运行，在的话找nscd要域名解析结果，如果nscd没有运行，那么再找 /etc/resolv.conf中的nameserver做域名解析**

而nslookup和dig这样的命令就不会尝试找nscd，所以没有这个问题。

如下文字摘自：https://www.atatech.org/articles/91088

>NSCD(name service cache daemon)是GLIBC关于网络库的一个组件，服务基于glibc开发的各类网络服务，基本上来讲我们能见到的一些编程语言和开发框架最终均会调用到glibc的网络解析的函数（如GETHOSTBYNAME or GETHOSTBYADDR等），因此绝大部分程序能够使用NSCD提供的缓存服务。当然了如果是应用端自己用socker编写了一个网络client就无法使用NSCD提供的缓存服务，比如DNS领域常见的dig命令不会使用NSCD提供的缓存，而作为对比ping得到的DNS解析结果将使用NSCD提供的缓存

#### connect函数返回值的说明：

    RETURN VALUE
       If  the  connection or binding succeeds, zero is returned.  On error, -1 is returned,and errno is set appropriately.


Windows下客户端是默认有dns cache的，但是Linux Client上默认没有dns cache，DNS Server上是有cache的，所以忽视了这个问题。这个nscd是之前看ping不通，google到这么一个命令，但是应该没有搞明白它的作用，就执行了一个网上的命令，把nscd拉起来，然后ping 因为rotate的问题，还是不通，同时nscd cache了这个不通的结果，导致了新的问题

## 域名解析流程（或者说 glibc的 gethostbyname() 函数流程--背后是NameServiceSwitch）

- DNS域名解析的时候先根据 /etc/nsswitch.conf 配置的顺序进行dns解析（name service switch），一般是这样配置：hosts: files dns 【files代表 /etc/hosts ； dns 代表 /etc/resolv.conf】(**ping是这个流程，但是nslookup和dig不是**)
- 如果本地有DNS Client Cache，先走Cache查询，所以有时候看不到DNS网络包。Linux下nscd可以做这个cache，Windows下有 ipconfig /displaydns ipconfig /flushdns 
- 如果 /etc/resolv.conf 中配置了多个nameserver，默认使用第一个，只有第一个失败【如53端口不响应、查不到域名后再用后面的nameserver顶上】
- 如果 /etc/resolv.conf 中配置了rotate，那么多个nameserver轮流使用. [但是因为glibc库的原因用了rotate 会触发nameserver排序的时候第二个总是排在第一位](https://access.redhat.com/solutions/1426263)

**nslookup和dig程序是bind程序包所带的工具，专门用来检测DNS Server的，实现上更简单，就一个目的，给DNS Server发DNS解析请求，没有调gethostbyname()函数，也就不遵循上述流程，而是直接到 /etc/resolv.conf 取第一个nameserver当dns server进行解析**

### glibc函数

glibc 的解析器(revolver code) 提供了下面两个函数实现名称到 ip 地址的解析, gethostbyname 函数以同步阻塞的方式提供服务, 没有超时等选项, 仅提供 IPv4 的解析. getaddrinfo 则没有这些限制, 同时支持 IPv4, IPv6, 也支持 IPv4 到 IPv6 的映射选项. 包含 Linux 在内的很多系统都已废弃 gethostbyname 函数, 使用 getaddrinfo 函数代替. 不过从现实的情况来看, 还是有很多程序或网络库使用 gethostbyname 进行服务.

备注:
线上开启 nscd 前, 建议做好程序的测试, nscd 仅支持通过 glibc, c 标准机制运行的程序, 没有基于 glibc 运行的程序可能不支持 nscd. 另外一些 go, perl 等编程语言网络库的解析函数是单独实现的, 不会走 nscd 的 socket, 这种情况下程序可以进行名称解析, 但不会使用 nscd 缓存. 不过我们在测试环境中使用go, java 的常规网络库都可以正常连接 nscd 的 socket 进行请求; perl 语言使用 Net::DNS 模块, 不会使用 nscd 缓存; python 语言使用 python-dns 模块, 不会使用 nscd 缓存. python 和 perl 不使用模块的时候进行解析还是遵循上述的过程, 同时使用 nscd 缓存.

## 下面是glibc中对rotate的处理：

这是glibc 2.2.5(2010年的版本），如果有rotate逻辑就是把第一个nameserver总是丢到最后一个去（为了均衡nameserver的负载，保护第一个nameserver）：

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/2a8116a867726e3fea20e0f45e9ed9fa.png)

在2017年这个代码逻辑终于改了，不过还不是默认用第一个，而是随机取一个，rotate搞成random了，这样更不好排查问题了

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/b0d3f9bb8cc2a4bdcd2378e173ba8cf1.png)

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/245e70b53aee4bfcdc9a921993ddad6f.png)

也就是2010年之前的glibc版本在rotate模式下都是把第一个nameserver默认挪到最后一个（为了保护第一个nameserver），这样rotate模式下默认第一个nameserver总是/etc/resolov.conf配置文件中的第二个，到2017年改掉了这个问题，不过改成随机取nameserver, 作者不认为这是一个bug，他觉得配置rotate就是要平衡多个nameserver的性能，所以random最公平，因为大多程序都是查一次域名缓存好久，不随机轮询的话第一个nameserver压力太大

[参考 glibc bug](https://sourceware.org/bugzilla/show_bug.cgi?id=19570)

[Linux内核与glibc](https://www.byvoid.com/zhs/blog/linux-kernel-and-glibc)

## 还有一种情况，开了easyconnect这样的vpn软件，同时又配置了自己的dns server

这个时候ping 某个自己的dns server中才有的域名是没法解析到的，即使你配置了自己的dns server，如果这个时候你通过 nslookup 自己的域名, 自己的dns-server-ip 确实是能够解析到的。但是你只是 nslookup 自己的域名 就不行，明显可以看到这个时候nslookup把域名发给了127.0.0.1:53来解析，而这个端口正是easyconnect这个软件在监听，你也可以理解easyconnect这样的软件的工作方式就是必须要挟持你的dns解析，可以理解的是这个时候nslookup肯定解析不到你的域名(只把dns解析丢给第一个nameserver--127.0.0.1)，但是不能理解的是还是ping不通域名，正常ping的逻辑丢给第一个127.0.0.1解析不到域名的话，会丢给第二个dns-server继续尝试解析，但是这里的easyconnect没有进行第二次尝试，这也许是它实现上没有考虑到或者故意这样实现的。

## 其他情况

[resolv.conf中search只能支持最多6个后缀（代码中写死了）](https://access.redhat.com/solutions/58028): This cannot be modified for RHEL 6.x and below and is resolved in RHEL7 glibc package versions at or exceeding glibc-2.17-222.el7.

nameserver：指定nameserver，必须配置，每行指定一个nameserver，最多只能生效3行

## 总结

- /etc/resolv.conf rotate参数的关键作用
- nscd对域名解析的cache
- nslookup背后执行原理和ping不一样(前者不调glibc的gethostbyname() 函数), nslookup不会检查 /etc/hosts、/etc/nsswitch.conf, 而是直接从 /etc/resolv.conf 中取nameserver； 但是ping或者我们在程序一般最终都是通过调glibc的gethostbyname() 函数对域名进行解析的，也就是按照 /etc/nsswitch.conf 指示的来
- 在没有源代码的情况下strace和抓包能够看到问题的本质
- [resolv.conf中最多只能使用前六个搜索域](https://access.redhat.com/solutions/58028)


下一篇介绍《在公司网下，我的windows7笔记本的wifi总是报dns域名异常无法上网（通过IP地址可以上网）》困扰了我两年，最近换了新笔记本还是有这个问题才痛下决心咬牙解决


### 参考资料

[https://superuser.com/questions/495759/why-is-ping-unable-to-resolve-a-name-when-nslookup-works-fine](https://superuser.com/questions/495759/why-is-ping-unable-to-resolve-a-name-when-nslookup-works-fine)

[https://stackoverflow.com/questions/330395/dns-problem-nslookup-works-ping-doesnt](https://stackoverflow.com/questions/330395/dns-problem-nslookup-works-ping-doesnt)

[DNS缓存介绍](https://www.atatech.org/articles/46211)

[来自redhat上原因的描述，但是从代码的原作者的描述来看，他认为rotate下这个行为是合理的](https://access.redhat.com/solutions/1426263)

[Linux 系统如何处理名称解析](https://arstercz.com/linux-%E7%B3%BB%E7%BB%9F%E5%A6%82%E4%BD%95%E5%A4%84%E7%90%86%E5%90%8D%E7%A7%B0%E8%A7%A3%E6%9E%90/)