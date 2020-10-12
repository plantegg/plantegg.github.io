---
title: 如何创建一个自己连自己的TCP连接
date: 2020-07-01 17:30:03
categories:
    - TCP
tags:
    - Linux
    - TCP
    - network
    - simultaneous
    - 自连接
---

# 如何创建一个自己连自己的TCP连接



> 能不能建立一个tcp连接， src-ip:src-port 等于dest-ip:dest-port 呢？

执行

```
# nc 192.168.0.79 18082 -p 18082
```

然后就能看到

```
# netstat -ant |grep 18082
tcp        0      0 192.168.0.79:18082      192.168.0.79:18082      ESTABLISHED
```

比较神奇，这个连接的srcport等于destport，并且完全可以工作，也能收发数据。这有点颠覆大家的理解，端口能重复使用？

##  port range

我们都知道linux下本地端口范围由参数控制

```
# cat /proc/sys/net/ipv4/ip_local_port_range 
10000	65535
```

所以也经常看到一个误解：一台机器上最多能创建65535个TCP连接

## 到底一台机器上最多能创建多少个TCP连接

在内存、文件句柄足够的话可以创建的连接是没有限制的，那么/proc/sys/net/ipv4/ip_local_port_range指定的端口范围到底是什么意思呢？

一个TCP连接只要保证四元组(src-ip src-port dest-ip dest-port)唯一就可以了，而不是要求src port唯一，比如：

```
# netstat -ant |grep 18089
tcp        0      0 192.168.1.79:18089      192.168.1.79:22         ESTABLISHED
tcp        0      0 192.168.1.79:18089      192.168.1.79:18080      ESTABLISHED
tcp        0      0 192.168.0.79:18089      192.168.0.79:22         TIME_WAIT 
tcp        0      0 192.168.1.79:22         192.168.1.79:18089      ESTABLISHED
tcp        0      0 192.168.1.79:18080      192.168.1.79:18089      ESTABLISHED
```

从前三行可以清楚地看到18089被用了三次，第一第二行src-ip、dest-ip也是重复的，但是dest port不一样，第三行的src-port还是18089，但是src-ip变了。

所以一台机器能创建的TCP连接是没有限制的，而ip_local_port_range是指没有bind的时候OS随机分配端口的范围，但是分配到的端口要同时满足五元组唯一，这样 ip_local_port_range 限制的是连同一个目标（dest-ip和dest-port一样）的port的数量（请忽略本地多网卡的情况，因为dest-ip为以后route只会选用一个本地ip）。

## 自己连自己的连接

我们来看自己连自己发生了什么

```bash
# strace nc 192.168.0.79 18084 -p 18084
execve("/usr/bin/nc", ["nc", "192.168.0.79", "18084", "-p", "18084"], [/* 31 vars */]) = 0
brk(NULL)                               = 0x23d4000
mmap(NULL, 4096, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x7f213f394000
access("/etc/ld.so.preload", R_OK)      = -1 ENOENT (No such file or directory)
open("/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 3
fstat(3, {st_mode=S_IFREG|0644, st_size=23295, ...}) = 0
mmap(NULL, 23295, PROT_READ, MAP_PRIVATE, 3, 0) = 0x7f213f38e000
close(3)                                = 0
open("/lib64/libssl.so.10", O_RDONLY|O_CLOEXEC) = 3
………………
munmap(0x7f213f393000, 4096)            = 0
open("/usr/share/ncat/ca-bundle.crt", O_RDONLY) = -1 ENOENT (No such file or directory)
socket(AF_INET, SOCK_STREAM, IPPROTO_TCP) = 3
fcntl(3, F_GETFL)                       = 0x2 (flags O_RDWR)
fcntl(3, F_SETFL, O_RDWR|O_NONBLOCK)    = 0
setsockopt(3, SOL_SOCKET, SO_REUSEADDR, [1], 4) = 0
bind(3, {sa_family=AF_INET, sin_port=htons(18084), sin_addr=inet_addr("0.0.0.0")}, 16) = 0
//注意这里bind后直接就是connect，没有listen
connect(3, {sa_family=AF_INET, sin_port=htons(18084), sin_addr=inet_addr("192.168.0.79")}, 16) = -1 EINPROGRESS (Operation now in progress)
select(4, [3], [3], [3], {10, 0})       = 1 (out [3], left {9, 999998})
getsockopt(3, SOL_SOCKET, SO_ERROR, [0], [4]) = 0
select(4, [0 3], [], [], NULL
```

抓包看看，正常三次握手，但是syn的seq和syn+ack的seq是一样的

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/341f2891253baa4eebdaeaf34aa60c4b.png)

这里算是常说的TCP simultaneous open，simultaneous open指的是两个不同port同时发syn建连接。而这里是先创建了一个socket，然后socket bind到18084端口上（作为local port，因为nc指定了local port），然后执行 connect, 连接到的目标也是192.168.0.79:18084，而这个目标正好是刚刚创建的socket，也就是自己连自己（连接双方总共只有一个socket）。因为一个socket充当了两个角色（client、server），这里发syn，自己收到自己发的syn，就相当于两个角色simultaneous open了。

正常一个连接一定需要两个socket参与（这两个socket不一定要在两台机器上），而这个连接只用了一个socket就创建了，还能正常传输数据。但是仔细观察发数据的时候发放的seq增加（注意tcp_len 11那里的seq），收方的seq也增加了11，这是因为本来这就是用的同一个socket。正常两个socket通讯不是这样的。

那么这种情况为什么没有当做bug被处理呢？

## TCP simultanous open

在tcp连接的定义中，通常都是一方先发起连接，假如两边同时发起连接，也就是两个socket同时给对方发 syn 呢？ 这在内核中是支持的，就叫同时打开（simultaneous open）。

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/b9a0144a3835759c844f697bc45103fa.png)

​							                                           摘自《tcp/ip卷1》

可以清楚地看到这个连接建立用了四次握手，然后连接建立了，当然也有 simultanous close(3次挥手成功关闭连接)。如下 net/ipv4/tcp_input.c 的5924行中就说明了允许这种自己连自己的连接（当然也允许simultanous open). 也就是允许一个socket本来应该收到 syn+ack,结果收到了syn的情况，而一个socket自己连自己又是这种情况的特例。

```
	static int tcp_rcv_synsent_state_process(struct sock *sk, struct sk_buff *skb,
                     const struct tcphdr *th)
	{
5916         /* PAWS check. */
5917         if (tp->rx_opt.ts_recent_stamp && tp->rx_opt.saw_tstamp &&
5918             tcp_paws_reject(&tp->rx_opt, 0))
5919                 goto discard_and_undo;
5920         //在socket发送syn后收到了一个syn(正常应该收到syn+ack),这里是允许的。
5921         if (th->syn) {
5922                 /* We see SYN without ACK. It is attempt of
5923                  * simultaneous connect with crossed SYNs.
5924                  * Particularly, it can be connect to self.  //自己连自己
5925                  */
5926                 tcp_set_state(sk, TCP_SYN_RECV);
5927 
5928                 if (tp->rx_opt.saw_tstamp) {
5929                         tp->rx_opt.tstamp_ok = 1;
5930                         tcp_store_ts_recent(tp);
5931                         tp->tcp_header_len =
5932                                 sizeof(struct tcphdr) + TCPOLEN_TSTAMP_ALIGNED;
5933                 } else {
5934                         tp->tcp_header_len = sizeof(struct tcphdr);
5935                 }
5936 
5937                 tp->rcv_nxt = TCP_SKB_CB(skb)->seq + 1;
5938                 tp->copied_seq = tp->rcv_nxt;
5939                 tp->rcv_wup = TCP_SKB_CB(skb)->seq + 1;
5940 
5941                 /* RFC1323: The window in SYN & SYN/ACK segments is
5942                  * never scaled.
5943                  */
```

也就是在发送syn进入SYN_SENT状态之后，收到对端发来的syn包后不会RST，而是处理流程如下，调用tcp_set_state(sk, TCP_SYN_RECV)进入SYN_RECV状态，以及调用tcp_send_synack(sk)向对端发送syn+ack。



## 自己连自己的原理解释

第一我们要理解Kernel是支持simultaneous open的，也就是说socket发走syn后，本来应该收到一个syn+ack的，但是实际收到了一个syn（没有ack），这是允许的。这叫TCP连接同时打开（同时给对方发syn），四次握手然后建立连接成功。

自己连自己又是simultaneous open的一个特例，特别在这个连接只有一个socket参与，发送、接收都是同一个socket，自然也会是发syn后收到了自己的syn（自己发给自己），然后依照simultaneous open连接也能创建成功。



## bind 和 connect、listen

当对一个TCP socket调用connect函数时，如果这个socket没有bind指定的端口号，操作系统会为它选择一个当前未被使用的端口号，这个端口号被称为ephemeral port, 范围可以在/proc/sys/net/ipv4/ip_local_port_range里查看。假设30000这个端口被选为ephemeral port。

如果这个socket指定了local port那么socket创建后会执行bind将这个socket bind到这个port。比如：

```
socket(AF_INET, SOCK_STREAM, IPPROTO_TCP) = 3
fcntl(3, F_GETFL)                       = 0x2 (flags O_RDWR)
fcntl(3, F_SETFL, O_RDWR|O_NONBLOCK)    = 0
setsockopt(3, SOL_SOCKET, SO_REUSEADDR, [1], 4) = 0
bind(3, {sa_family=AF_INET, sin_port=htons(18084), sin_addr=inet_addr("0.0.0.0")}, 16) = 0
```

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/5373ecfe0d4496d106c64d3f370c893c.png)



然后这个bind到18084 local port的socket又要连接到 18084 port上，而这个18084socket已经bind到了socket（也就是自己），就形成了两个socket 的simultaneous open一样，内核又允许这种simultaneous open，所以就形成了自己连自己，也就是一个socket在自己给自己收发数据，所以看到收方和发放的seq是一样的。

可以用python来重现这个连接连自己的过程：

```
import socket
import time

connected=False
while (not connected):
        try:
                sock = socket.socket(socket.AF_INET,socket.SOCK_STREAM)
                sock.setsockopt(socket.IPPROTO_TCP,socket.TCP_NODELAY,1)
				sock.bind(('', 18084))               //sock 先bind到18084
                sock.connect(('127.0.0.1',18084))    //然后同一个socket连自己
                connected=True
        except socket.error,(value,message):
                print message

        if not connected:
                print "reconnect"
               
print "tcp self connection occurs!"
print "netstat -an|grep 18084"
time.sleep(1800)             
```

这里connect前如果没有bind那么系统就会从 local port range 分配一个可用port。

bind成功后会将ip+port放入hash表来判重，这就是我们常看到的 Bind to *** failed (IOD #1): Address already in use 异常。所以一台机器上，如果有多个ip，是可以将同一个port bind多次的，但是bind的时候如果不指定ip，也就是bind('0', port) 还是会冲突。

connect成功后会将四元组放入ehash来判定连接的重复性。如果connect四元组冲突了就会报如下错误

```
# nc 192.168.0.82 8080 -p 29798 -s 192.168.0.79
Ncat: Cannot assign requested address.
```



### listen



![image-20200702131215819](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/4d188cab03e919f055bb9dbe3da0188c.png)



## 参考资料

https://segmentfault.com/a/1190000002396411

[linux中TCP的socket、bind、listen、connect和accept的实现](https://blog.csdn.net/a364572/article/details/40628171)

[How Linux allows TCP introspection The inner workings of bind and listen on Linux.](https://ops.tips/blog/how-linux-tcp-introspection/)

