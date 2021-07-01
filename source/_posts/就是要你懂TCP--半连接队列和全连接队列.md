---
title: 就是要你懂TCP--半连接队列和全连接队列
date: 2017-06-07 17:30:03
categories: TCP
tags:
    - TCP queue
    - accept queue
    - syn queue
    - syn flood
    - netstat
    - ss
    - overflows
    - dropped
---


# 关于TCP 半连接队列和全连接队列

> 最近碰到一个client端连接异常问题，然后定位分析发现是因为全连接队列满了导致的。查阅各种资料文章和通过一系列的实验对TCP连接队列有了更深入的理解
>
> 查资料过程中发现没有文章把这两个队列以及怎么观察他们的指标说清楚，希望通过这篇文章能说清楚:
>
> 1)  这两个队列是干什么用的；
>
> 2）怎么设置和观察他们的最大值；
>
> 3）怎么查看这两个队列当前使用到了多少；
>
> 4）一旦溢出的后果和现象是什么

## 问题描述

    场景：JAVA的client和server，使用socket通信。server使用NIO。
    
    1.间歇性的出现client向server建立连接三次握手已经完成，但server的selector没有响应到这连接。
    2.出问题的时间点，会同时有很多连接出现这个问题。
    3.selector没有销毁重建，一直用的都是一个。
    4.程序刚启动的时候必会出现一些，之后会间歇性出现。

## 分析问题

### 正常TCP建连接三次握手过程：

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/159a331ff8cdd4b8994dfe6a209d035f.png)

- 第一步：client 发送 syn 到server 发起握手；
- 第二步：server 收到 syn后回复syn+ack给client；
- 第三步：client 收到syn+ack后，回复server一个ack表示收到了server的syn+ack（此时client的56911端口的连接已经是established）


从问题的描述来看，有点像TCP建连接的时候全连接队列（accept队列，后面具体讲）满了，尤其是症状2、4. 为了证明是这个原因，马上通过 netstat -s | egrep "listen" 去看队列的溢出统计数据：
    
    667399 times the listen queue of a socket overflowed

反复看了几次之后发现这个overflowed 一直在增加，那么可以明确的是server上全连接队列一定溢出了

接着查看溢出后，OS怎么处理：

    # cat /proc/sys/net/ipv4/tcp_abort_on_overflow
    0

**tcp_abort_on_overflow 为0表示如果三次握手第三步的时候全连接队列满了那么server扔掉client 发过来的ack（在server端认为连接还没建立起来）**

为了证明客户端应用代码的异常跟全连接队列满有关系，我先把tcp_abort_on_overflow修改成 1，1表示第三步的时候如果全连接队列满了，server发送一个reset包给client，表示废掉这个握手过程和这个连接（本来在server端这个连接就还没建立起来）。

接着测试，这时在客户端异常中可以看到很多connection reset by peer的错误，**到此证明客户端错误是这个原因导致的（逻辑严谨、快速证明问题的关键点所在）**。

于是开发同学翻看java 源代码发现socket 默认的backlog（这个值控制全连接队列的大小，后面再详述）是50，于是改大重新跑，经过12个小时以上的压测，这个错误一次都没出现了，同时观察到 overflowed 也不再增加了。

到此问题解决，**简单来说TCP三次握手后有个accept队列，进到这个队列才能从Listen变成accept，默认backlog 值是50，很容易就满了**。满了之后握手第三步的时候server就忽略了client发过来的ack包（隔一段时间server重发握手第二步的syn+ack包给client），如果这个连接一直排不上队就异常了。

> 但是不能只是满足问题的解决，而是要去复盘解决过程，中间涉及到了哪些知识点是我所缺失或者理解不到位的；这个问题除了上面的异常信息表现出来之外，还有没有更明确地指征来查看和确认这个问题。

## 深入理解TCP握手过程中建连接的流程和队列

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/bcf463efeb677d5749d8d7571274ee79.png)

如上图所示，这里有两个队列：syns queue(半连接队列）；accept queue（全连接队列）

三次握手中，在第一步server收到client的syn后，把这个连接信息放到半连接队列中，同时回复syn+ack给client（第二步）；


    题外话，比如syn floods 攻击就是针对半连接队列的，攻击方不停地建连接，但是建连接的时候只做第一步，第二步中攻击方收到server的syn+ack后故意扔掉什么也不做，导致server上这个队列满其它正常请求无法进来


第三步的时候server收到client的ack，如果这时全连接队列没满，那么从半连接队列拿出这个连接的信息放入到全连接队列中，同时将连接状态从 SYN_RECV 改成 ESTABLISHED 状态，否则按tcp_abort_on_overflow指示的执行。

这时如果全连接队列满了并且tcp_abort_on_overflow是0的话，server会扔掉三次握手中第三步收到的ack（假装没有收到一样），过一段时间再次发送syn+ack给client（也就是重新走握手的第二步），如果client超时等待比较短，就很容易异常了。其实这个时候client认为连接已经建立了，可以发数据或者可以断开，而实际server上连接还没建立好（还没能力）。

在我们的os中retry 第二步的默认次数是2（centos默认是5次）：

    net.ipv4.tcp_synack_retries = 2

## 如果TCP连接队列溢出，有哪些指标可以看呢？

上述解决过程有点绕，听起来蒙逼，那么下次再出现类似问题有什么更快更明确的手段来确认这个问题呢？

（*通过具体的、感性的东西来强化我们对知识点的理解和吸收*）

### netstat -s

    [root@server ~]#  netstat -s | egrep "listen|LISTEN" 
    667399 times the listen queue of a socket overflowed
    667399 SYNs to LISTEN sockets ignored

比如上面看到的 667399 times ，表示全连接队列溢出的次数，隔几秒钟执行下，如果这个数字一直在增加的话肯定全连接队列偶尔满了。

### ss 命令

    [root@server ~]# ss -lnt
    Recv-Q Send-Q Local Address:Port  Peer Address:Port 
    0        50               *:3306             *:* 


**上面看到的第二列Send-Q 值是50，表示第三列的listen端口上的全连接队列最大为50，第一列Recv-Q为全连接队列当前使用了多少**

**全连接队列的大小取决于：min(backlog, somaxconn) . backlog是在socket创建的时候传入的，somaxconn是一个os级别的系统参数**

《Unix Network Programming》中关于backlog的描述

> The backlog argument to the listen function has historically specified the maximum value for the sum of both queues.
>
> There has never been a formal definition of what the backlog means. The 4.2BSD man page says that it "defines the maximum length the queue of pending connections may grow to." Many man pages and even the POSIX specification copy this definition verbatim, but this definition does not say whether a pending connection is one in the SYN_RCVD state, one in the ESTABLISHED state that has not yet been accepted, or either. The historical definition in this bullet is the Berkeley implementation, dating back to 4.2BSD, and copied by many others.

这个时候可以跟我们的代码建立联系了，比如Java创建ServerSocket的时候会让你传入backlog的值：

    ServerSocket()
    	Creates an unbound server socket.
    ServerSocket(int port)
    	Creates a server socket, bound to the specified port.
    ServerSocket(int port, int backlog)
    	Creates a server socket and binds it to the specified local port number, with the specified backlog.
    ServerSocket(int port, int backlog, InetAddress bindAddr)
    	Create a server with the specified port, listen backlog, and local IP address to bind to.


（来自JDK帮助文档：https://docs.oracle.com/javase/7/docs/api/java/net/ServerSocket.html）

**半连接队列的大小取决于：max(64,  /proc/sys/net/ipv4/tcp_max_syn_backlog)。 不同版本的os会有些差异**

> 我们写代码的时候从来没有想过这个backlog或者说大多时候就没给他值（那么默认就是50），直接忽视了他，首先这是一个知识点的忙点；其次也许哪天你在哪篇文章中看到了这个参数，当时有点印象，但是过一阵子就忘了，这是知识之间没有建立连接，不是体系化的。但是如果你跟我一样首先经历了这个问题的痛苦，然后在压力和痛苦的驱动自己去找为什么，同时能够把为什么从代码层推理理解到OS层，那么这个知识点你才算是比较好地掌握了，也会成为你的知识体系在TCP或者性能方面成长自我生长的一个有力抓手

#### netstat 命令

netstat跟ss命令一样也能看到Send-Q、Recv-Q这些状态信息，不过如果这个连接不是**Listen状态**的话，Recv-Q就是指收到的数据还在缓存中，还没被进程读取，这个值就是还没被进程读取的 bytes；而 Send 则是发送队列中没有被远程主机确认的 bytes 数

    $netstat -tn  
    Active Internet connections (w/o servers)
    Proto Recv-Q Send-Q Local Address   Foreign Address State  
    tcp    0  0 server:8182  client-1:15260 SYN_RECV   
    tcp    0 28 server:22    client-1:51708  ESTABLISHED
    tcp    0  0 server:2376  client-1:60269 ESTABLISHED

**netstat -tn 看到的 Recv-Q 跟全连接半连接中的Queue没有关系，这里特意拿出来说一下是因为容易跟 ss -lnt 的 Recv-Q 搞混淆**  

所以ss看到的 Send-Q、Recv-Q是目前全连接队列使用情况和最大设置
netstat看到的 Send-Q、Recv-Q，如果这个连接是Established状态的话就是发出的bytes并且没有ack的包、和os接收到的bytes还没交给应用

我们看到的 Recv-Q、Send-Q获取源代码如下（ net/ipv4/tcp_diag.c ）：   

    static void tcp_diag_get_info(struct sock *sk, struct inet_diag_msg *r,
      void *_info)
    {
        const struct tcp_sock *tp = tcp_sk(sk);
        struct tcp_info *info = _info;
        
        if (sk->sk_state == TCP_LISTEN) {  //LISTEN状态下的 Recv-Q、Send-Q
    	    r->idiag_rqueue = sk->sk_ack_backlog;
    	    r->idiag_wqueue = sk->sk_max_ack_backlog; //Send-Q 最大backlog
        } else {						   //其它状态下的 Recv-Q、Send-Q
    	    r->idiag_rqueue = max_t(int, tp->rcv_nxt - tp->copied_seq, 0);
    	    r->idiag_wqueue = tp->write_seq - tp->snd_una;
        }
        if (info != NULL)
        	tcp_get_info(sk, info);
    }

比如如下netstat -t 看到的Recv-Q有大量数据堆积，那么一般是CPU处理不过来导致的：


![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/77ed9ba81f70f7940546f0a22dabf010.png)

#### netstat看到的listen状态的Recv-Q/Send-Q

netstat 看到的listen状态下的Recv-Q/Send-Q意义跟 ss -lnt看到的完全不一样。上面的 netstat 对非listen的描述没问题，但是listen状态似乎Send-Q这个值总是0，这要去看netstat的代码了，实际上Listen状态它不是一个连接，所以肯定统计不到流量，netstat似乎只是针对连接的统计

从网上找了两个Case，server的8765端口故意不去读取对方发过来的2000字节，所看到的是：

    $ netstat -ano | grep 8765  
    tcp0  0 0.0.0.0:87650.0.0.0:*   LISTEN  off (0.00/0/0)  
    tcp 2000  0 10.100.70.140:8765  10.100.70.139:43634 ESTABLISHED off (0.00/0/0)

第二个Case，8000端口的半连接满了（129），但是这个时候Send-Q还是看到的0

	$ netstat -ntap | grep 8000 
	tcp      129      0 0.0.0.0:8000            0.0.0.0:*               LISTEN      1526/XXXXX- 
	tcp        0      0 9.11.6.36:8000          9.11.6.37:48306         SYN_RECV    - 
	tcp        0      0 9.11.6.36:8000          9.11.6.34:44936         SYN_RECV    - 
	tcp      365      0 9.11.6.36:8000          9.11.6.37:58446         CLOSE_WAIT  -  

## 案列：如果TCP连接队列溢出，抓包是什么现象呢？

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/c0849615ae52531887ce6b0313d7d2d1.png)

如上图server端8989端口的服务全连接队列已经满了（设置最大5，已经6了，通过后面步骤的ss -lnt可以验证）， 所以 server尝试过一会假装继续三次握手的第二步，跟client说我们继续谈恋爱吧。可是这个时候client比较性急，忙着分手了，server觉得都没恋上那什么分手啊。所以接下来两边自说自话也就是都不停滴重传
    

### 通过ss和netstat所观察到的状态

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/ec25ccb6cce8f554b7ef6927f05bd530.png)

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/2fbdd05162e9fd51e803682b8a18cc51.png)

[另外一个案例，虽然最终的锅不是TCP全连接队列太小，但是也能从重传、队列溢出找到根因](https://plantegg.github.io/2019/08/31/%E5%B0%B1%E6%98%AF%E8%A6%81%E4%BD%A0%E6%87%82TCP%E9%98%9F%E5%88%97--%E9%80%9A%E8%BF%87%E5%AE%9E%E6%88%98%E6%A1%88%E4%BE%8B%E6%9D%A5%E5%B1%95%E7%A4%BA%E9%97%AE%E9%A2%98/)

## 实践验证一下上面的理解

上面是通过一些具体的工具、指标来认识全连接队列，接下来结合文章开始的问题来具体验证一下 

把java中backlog改成10（越小越容易溢出），继续跑压力，这个时候client又开始报异常了，然后在server上通过 ss 命令观察到：

    Fri May  5 13:50:23 CST 2017
    Recv-Q Send-QLocal Address:Port  Peer Address:Port
    11         10         *:3306               *:*

按照前面的理解，这个时候我们能看到3306这个端口上的服务全连接队列最大是10，但是现在有11个在队列中和等待进队列的，肯定有一个连接进不去队列要overflow掉，同时也确实能看到overflow的值在不断地增大。

### Tomcat和Nginx中的Accept队列参数

Tomcat默认短连接，backlog（Tomcat里面的术语是Accept count）Ali-tomcat默认是200, Apache Tomcat默认100. 

    #ss -lnt
    Recv-Q Send-Q   Local Address:Port Peer Address:Port
    0       100                 *:8080            *:*

Nginx默认是511

    $sudo ss -lnt
    State  Recv-Q Send-Q Local Address:PortPeer Address:Port
    LISTEN    0     511              *:8085           *:*
    LISTEN    0     511              *:8085           *:*

因为Nginx是多进程模式，所以看到了多个8085，也就是多个进程都监听同一个端口以尽量避免上下文切换来提升性能   

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/01dc036aca4b445ed86e3e295bf245b8.png)

## 进一步思考 client fooling 问题

如果client走完第三步在client看来连接已经建立好了，但是server上的对应的连接有可能因为accept queue满了而仍然是syn_recv状态，这个时候如果client发数据给server，server会怎么处理呢？（有同学说会reset，还是实践看看）

先来看一个例子：

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/9179e08ac24ce3d53e74b92dbd044906.png)

如上图，图中3号包是三次握手中的第三步，client发送ack给server，这个时候在client看来握手完成，然后4号包中client发送了一个长度为238的包给server，因为在这个时候client认为连接建立成功，但是server上这个连接实际没有ready，所以server没有回复，一段时间后client认为丢包了然后重传这238个字节的包，等到server reset了该连接（或者client一直重传这238字节到超时，client主动发fin包断开该连接，如下图）

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/3f5f1eeb0646a3af8afd6bbff2a9ea0b.png)

这个问题也叫client fooling，可以看这个patch在4.10后修复了：https://github.com/torvalds/linux/commit/5ea8ea2cb7f1d0db15762c9b0bb9e7330425a071 ，修复的逻辑就是，如果全连接队列满了就不再回复syn+ack了，免得client误认为这个连接建立起来了，这样client端收不到syn+ack就只能重发syn。

**从上面的实际抓包来看不是reset，而是server忽略这些包，然后client重传，一定次数后client认为异常，然后断开连接。**

如果这个连接已经放入了全连接队列但是应用没有accept（比如应用卡住了），那么这个时候client发过来的包是不会被扔掉，OS会先收下放到接收buffer中，知道buffer满了再扔掉新进来的。

## 过程中发现的一个奇怪问题

    [root@server ~]# date; netstat -s | egrep "listen|LISTEN" 
    Fri May  5 15:39:58 CST 2017
    1641685 times the listen queue of a socket overflowed
    1641685 SYNs to LISTEN sockets ignored
    
    [root@server ~]# date; netstat -s | egrep "listen|LISTEN" 
    Fri May  5 15:39:59 CST 2017
    1641906 times the listen queue of a socket overflowed
    1641906 SYNs to LISTEN sockets ignored


如上所示：
overflowed和ignored居然总是一样多，并且都是同步增加，overflowed表示全连接队列溢出次数，socket ignored表示半连接队列溢出次数，没这么巧吧。

翻看内核源代码（http://elixir.free-electrons.com/linux/v3.18/source/net/ipv4/tcp_ipv4.c）：

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/a5616904df3a505572d99d557b534db2.png)

可以看到overflow的时候一定会drop++（socket ignored），也就是drop一定大于等于overflow。

同时我也查看了另外几台server的这两个值来证明drop一定大于等于overflow：

    server1
    150 SYNs to LISTEN sockets dropped
    
    server2
    193 SYNs to LISTEN sockets dropped
    
    server3
    16329 times the listen queue of a socket overflowed
    16422 SYNs to LISTEN sockets dropped
    
    server4
    20 times the listen queue of a socket overflowed
    51 SYNs to LISTEN sockets dropped
    
    server5
    984932 times the listen queue of a socket overflowed
    988003 SYNs to LISTEN sockets dropped

## 那么全连接队列满了会影响半连接队列吗？

来看三次握手第一步的源代码（http://elixir.free-electrons.com/linux/v2.6.33/source/net/ipv4/tcp_ipv4.c#L1249）：

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/0c6bbb5d4a10f40c8b3c4ba6cab82292.png)

TCP三次握手第一步的时候如果全连接队列满了会影响第一步drop 半连接的发生。大概流程的如下：


    tcp_v4_do_rcv->tcp_rcv_state_process->tcp_v4_conn_request
    //如果accept backlog队列已满，且未超时的request socket的数量大于1，则丢弃当前请求  
      if(sk_acceptq_is_full(sk) && inet_csk_reqsk_queue_yong(sk)>1)
          goto drop;

## 总结

全连接队列、半连接队列溢出这种问题很容易被忽视，但是又很关键，特别是对于一些短连接应用（比如Nginx、PHP，当然他们也是支持长连接的）更容易爆发。 一旦溢出，从cpu、线程状态看起来都比较正常，但是压力上不去，在client看来rt也比较高（rt=网络+排队+真正服务时间），但是从server日志记录的真正服务时间来看rt又很短。

另外就是jdk、netty等一些框架默认backlog比较小，可能有些情况下导致性能上不去，比如 @毕玄 碰到的这个 [《netty新建连接并发数很小的case》 ](https://www.atatech.org/articles/12919)
都是类似原因

希望通过本文能够帮大家理解TCP连接过程中的半连接队列和全连接队列的概念、原理和作用，更关键的是有哪些指标可以明确看到这些问题。

另外每个具体问题都是最好学习的机会，光看书理解肯定是不够深刻的，请珍惜每个具体问题，碰到后能够把来龙去脉弄清楚。

----------

## 参考文章

http://veithen.github.io/2014/01/01/how-tcp-backlog-works-in-linux.html

http://www.cnblogs.com/zengkefu/p/5606696.html

http://www.cnxct.com/something-about-phpfpm-s-backlog/

[http://jaseywang.me/2014/07/20/tcp-queue-%E7%9A%84%E4%B8%80%E4%BA%9B%E9%97%AE%E9%A2%98/](http://jaseywang.me/2014/07/20/tcp-queue-%E7%9A%84%E4%B8%80%E4%BA%9B%E9%97%AE%E9%A2%98/)

http://jin-yang.github.io/blog/network-synack-queue.html#

http://blog.chinaunix.net/uid-20662820-id-4154399.html

https://www.atatech.org/articles/12919

https://blog.cloudflare.com/syn-packet-handling-in-the-wild/

[How Linux allows TCP introspection The inner workings of bind and listen on Linux.](https://ops.tips/blog/how-linux-tcp-introspection/)

https://www.cnblogs.com/xiaolincoding/p/12995358.html

[案例三：诡异的幽灵连接，全连接队列满后4.9内核不再回复syn+ack, 但是3.10会回syn+ack](https://mp.weixin.qq.com/s/YWzuKBK3TMclejeN2ziAvQ)

> commit 5ea8ea2cb7f1d0db15762c9b0bb9e7330425a071
> Author: Eric Dumazet <edumazet@google.com>
> Date:   Thu Oct 27 00:27:57 2016
>
>     tcp/dccp: drop SYN packets if accept queue is full
>     
>     Per listen(fd, backlog) rules, there is really no point accepting a SYN,
>     sending a SYNACK, and dropping the following ACK packet if accept queue
>     is full, because application is not draining accept queue fast enough.
>     
>     This behavior is fooling TCP clients that believe they established a
>     flow, while there is nothing at server side. They might then send about
>     10 MSS (if using IW10) that will be dropped anyway while server is under
>     stress.
>     
>     -
>     -       /* Accept backlog is full. If we have already queued enough
>     -        * of warm entries in syn queue, drop request. It is better than
>     -        * clogging syn queue with openreqs with exponentially increasing
>     -        * timeout.
>     -        */
>     -       if (sk_acceptq_is_full(sk) && inet_csk_reqsk_queue_young(sk) > 1) {
>     +       if (sk_acceptq_is_full(sk)) {
>                     NET_INC_STATS(sock_net(sk), LINUX_MIB_LISTENOVERFLOWS);
>                     goto drop;
>             }