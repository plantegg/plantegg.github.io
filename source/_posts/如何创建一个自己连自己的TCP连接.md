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

所以也经常看到一个**误解**：一台机器上最多能创建65535个TCP连接

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

但是如果程序调用的是bind函数(bind(ip,port=0))这个时候是让系统绑定到某个网卡和自动分配的端口，此时系统没有办法确定接下来这个socket是要去connect还是listen. 如果是listen的话，那么肯定是不能出现端口冲突的，如果是connect的话，只要满足4元组唯一即可。在这种情况下，系统只能尽可能满足更强的要求，就是先要求端口不能冲突，即使之后去connect的时候4元组是唯一的。

bind()的时候内核是还不知道四元组的，只知道src_ip、src_port，所以这个时候单网卡下src_port是没法重复的，但是connect()的时候已经知道了四元组的全部信息，所以只要保证四元组唯一就可以了，那么这里的src_port完全是可以重复使用的。

### TCP SO_REUSEADDR

SO_REUSEADDR 主要解决的是重用TIME_WAIT状态的port, 程序崩溃后立即重启失败（Address Already in use），可以通过在调用bind函数之前设置SO_REUSEADDR来解决。

> What exactly does SO_REUSEADDR do?
>
> This socket option tells the kernel that even if this port is busy (in the TIME_WAIT state), go ahead and reuse it anyway. If it is busy, but with another state, you will still get an address already in use error. It is useful if your server has been shut down, and then restarted right away while sockets are still active on its port. You should be aware that if any unexpected data comes in, it may confuse your server, but while this is possible, it is not likely.
>
> It has been pointed out that "A socket is a 5 tuple (proto, local addr, local port, remote addr, remote port). SO_REUSEADDR just says that you can reuse local addresses. The 5 tuple still must be unique!" This is true, and this is why it is very unlikely that unexpected data will ever be seen by your server. The danger is that such a 5 tuple is still floating around on the net, and while it is bouncing around, a new connection from the same client, on the same system, happens to get the same remote port. 

By setting `SO_REUSEADDR` user informs the kernel of an intention to share the bound port with anyone else, but only if it doesn't cause a conflict on the protocol layer. There are at least three situations when this flag is useful:

1. Normally after binding to a port and stopping a server it's neccesary to wait for a socket to time out before another server can bind to the same port. With `SO_REUSEADDR` set it's possible to rebind immediately, even if the socket is in a `TIME_WAIT` state.
2. When one server binds to `INADDR_ANY`, say `0.0.0.0:1234`, it's impossible to have another server binding to a specific address like `192.168.1.21:1234`. With `SO_REUSEADDR` flag this behaviour is allowed.
3. When using the bind before connect trick only a single connection can use a single outgoing source port. With this flag, it's possible for many connections to reuse the same source port, given that they connect to different destination addresses.

### TCP SO_REUSEPORT

SO_REUSEPORT主要用来解决惊群、性能等问题。

> SO_REUSEPORT is also useful for eliminating the try-10-times-to-bind hack in ftpd's data connection setup routine.  Without SO_REUSEPORT, only one ftpd thread can bind to TCP (lhost, lport, INADDR_ANY, 0) in preparation for connecting back to the client.  Under conditions of heavy load, there are more threads colliding here than the try-10-times hack can accomodate.  With SO_REUSEPORT, things  work nicely and the hack becomes unnecessary.

SO_REUSEPORT使用场景：linux kernel 3.9 引入了最新的SO_REUSEPORT选项，使得多进程或者多线程创建多个绑定同一个ip:port的监听socket，提高服务器的接收链接的并发能力,程序的扩展性更好；此时需要设置SO_REUSEPORT（**注意所有进程都要设置才生效**）。

setsockopt(listenfd, SOL_SOCKET, SO_REUSEPORT,(const void *)&reuse , sizeof(int));

目的：每一个进程有一个独立的监听socket，并且bind相同的ip:port，独立的listen()和accept()；提高接收连接的能力。（例如nginx多进程同时监听同一个ip:port）

> (a) on Linux SO_REUSEPORT is meant to be used *purely* for load balancing multiple incoming UDP packets or incoming TCP connection requests across multiple sockets belonging to the same app.  ie. it's a work around for machines with a lot of cpus, handling heavy load, where a single listening socket becomes a bottleneck because of cross-thread contention on the in-kernel socket lock (and state).
>
> (b) set IP_BIND_ADDRESS_NO_PORT socket option for tcp sockets before binding to a specific source ip
> with port 0 if you're going to use the socket for connect() rather then listen() this allows the kernel
> to delay allocating the source port until connect() time at which point it is much cheaper

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

![image.png](/images/oss/341f2891253baa4eebdaeaf34aa60c4b.png)

这里算是常说的TCP simultaneous open，simultaneous open指的是两个不同port同时发syn建连接。而这里是先创建了一个socket，然后socket bind到18084端口上（作为local port，因为nc指定了local port），然后执行 connect, 连接到的目标也是192.168.0.79:18084，而这个目标正好是刚刚创建的socket，也就是自己连自己（连接双方总共只有一个socket）。因为一个socket充当了两个角色（client、server），握手的时候发syn，自己收到自己发的syn，就相当于两个角色simultaneous open了。

正常一个连接一定需要两个socket参与（这两个socket不一定要在两台机器上），而这个连接只用了一个socket就创建了，还能正常传输数据。但是仔细观察发数据的时候发放的seq增加（注意tcp_len 11那里的seq），收方的seq也增加了11，这是因为本来这就是用的同一个socket。正常两个socket通讯不是这样的。

那么这种情况为什么没有当做bug被处理呢？

## TCP simultanous open

在tcp连接的定义中，通常都是一方先发起连接，假如两边同时发起连接，也就是两个socket同时给对方发 syn 呢？ 这在内核中是支持的，就叫同时打开（simultaneous open）。

![image.png](/images/oss/b9a0144a3835759c844f697bc45103fa.png)

​							                                           摘自《tcp/ip卷1》

可以清楚地看到这个连接建立用了四次握手，然后连接建立了，当然也有 simultanous close(3次挥手成功关闭连接)。如下内核代码 net/ipv4/tcp_input.c 的5924行中就说明了允许这种自己连自己的连接（当然也允许simultanous open). 也就是允许一个socket本来应该收到 syn+ack(发出syn后), 结果收到了syn的情况，而一个socket自己连自己又是这种情况的特例。

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

第一我们要理解Kernel是支持simultaneous open（同时打开）的，也就是说socket发走syn后，本来应该收到一个syn+ack的，但是实际收到了一个syn（没有ack），这是允许的。这叫TCP连接同时打开（同时给对方发syn），四次握手然后建立连接成功。

自己连自己又是simultaneous open的一个特例，特别在这个连接只有一个socket参与，发送、接收都是同一个socket，自然也会是发syn后收到了自己的syn（自己发给自己），然后依照simultaneous open连接也能创建成功。

这个bind到18084 local port的socket又要连接到 18084 port上，而这个18084 socket已经bind到了socket（也就是自己），就形成了两个socket 的simultaneous open一样，内核又允许这种simultaneous open，所以就形成了自己连自己，也就是一个socket在自己给自己收发数据，所以看到收方和发放的seq是一样的。

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

![image.png](/images/oss/5373ecfe0d4496d106c64d3f370c893c.png)





### listen



![image-20200702131215819](/images/oss/4d188cab03e919f055bb9dbe3da0188c.png)



## 参考资料

https://segmentfault.com/a/1190000002396411

[linux中TCP的socket、bind、listen、connect和accept的实现](https://blog.csdn.net/a364572/article/details/40628171)

[How Linux allows TCP introspection The inner workings of bind and listen on Linux.](https://ops.tips/blog/how-linux-tcp-introspection/)

https://idea.popcount.org/2014-04-03-bind-before-connect/