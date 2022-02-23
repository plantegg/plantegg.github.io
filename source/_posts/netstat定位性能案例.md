---
title: netstat定位性能案例
date: 2019-04-21 17:30:03
categories: TCP
tags:
    - recv-q
    - netstat
    - send-q
    - timer(keepalive)
---

# netstat定位性能案例

netstat 和 ss 都是小工具，但是在网络性能、异常的窥探方面真的是神器。[ss用法见这里](/2016/10/12/ss%E7%94%A8%E6%B3%95%E5%A4%A7%E5%85%A8/)

下面的案例通过netstat很快就发现为什么系统总是压不上去了（主要是快速定位到一个长链条的服务调用体系中哪个节点碰到瓶颈了）

## netstat 命令

netstat跟ss命令一样也能看到Send-Q、Recv-Q这些状态信息，不过如果这个连接不是**Listen状态**的话，Recv-Q就是指收到的数据还在缓存中，还没被进程读取，这个值就是还没被进程读取的 bytes；而 Send 则是发送队列中没有被远程主机确认的 bytes 数

    $netstat -tn  
    Active Internet connections (w/o servers)
    Proto Recv-Q Send-Q Local Address   Foreign Address State  
    tcp0  0 server:8182  client-1:15260 SYN_RECV   
    tcp0 28 server:22    client-1:51708  ESTABLISHED
    tcp0  0 server:2376  client-1:60269 ESTABLISHED

 netstat -tn 看到的 Recv-Q 跟全连接半连接没有关系，这里特意拿出来说一下是因为容易跟 ss -lnt 的 Recv-Q 搞混淆。

### Recv-Q 和 Send-Q 的说明

> Recv-Q
> Established: The count of bytes not copied by the user program connected to this socket.
> Listening: Since Kernel 2.6.18 this column contains the current syn backlog.
>
> Send-Q
> Established: The count of bytes not acknowledged by the remote host.
> Listening: Since Kernel 2.6.18 this column contains the maximum size of the syn backlog. 

## 通过 netstat 发现问题的案例

#### 自身太慢，比如如下netstat -t 看到的Recv-Q有大量数据堆积，那么一般是CPU处理不过来导致的：

![image.png](/images/oss/77ed9ba81f70f7940546f0a22dabf010.png)



#### 下面的case是接收方太慢，从应用机器的netstat统计来看，也是client端回复太慢（本机listen 9108端口)

<img src="/images/oss/1579241362064-807d8378-6c54-4a2c-a888-ff2337df817c.png" alt="image.png" style="zoom:80%;" />

send-q表示回复从9108发走了，没收到对方的ack，**基本可以推断client端到9108之间有瓶颈**

实际确实是前端到9108之间的带宽被打满了，调整带宽后问题解决

## netstat -s 统计数据

所有统计信息基本都有

