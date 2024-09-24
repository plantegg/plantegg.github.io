---
title: 长连接黑洞重现和分析
date: 2024-05-05 08:30:03
categories:
    - network
tags:
    - LVS
    - network
    - Linux
    - SocketTimeout
    - TCP_USER_TIMEOUT
---


# 长连接黑洞重现和分析

这是一个存在多年，遍及各个不同的业务又反反复复地在集团内部出现的一个问题，本文先通过重现展示这个问题，然后从业务、数据库、OS等不同的角度来分析如何解决它，这个问题值得每一位研发同学重视起来，避免再次踩到



## 背景

为了高效率应对故障，本文尝试回答如下一些问题：

- 为什么数据库crash 重启恢复后，业务还长时间不能恢复？
- 我依赖的业务做了高可用切换，但是我的业务长时间报错
- 我依赖的服务下掉了一个节点，为什么我的业务长时间报错 
- 客户做变配，升级云服务节点规格，为什么会导致客户业务长时间报错



目的：希望通过这篇文章尽可能地减少故障时长、让业务快速从故障中恢复



## 重现

空说无凭，先也通过一次真实的重现来展示这个问题

### LVS+MySQL 高可用切换

OS 默认配置参数

```
#sysctl -a |grep -E "tcp_retries|keepalive"
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_time = 10
net.ipv4.tcp_retries1 = 3
net.ipv4.tcp_retries2 = 15  //主要是这个参数，默认以及alios 几乎都是15
```



LVS 对外服务端口是3001， 后面挂的是 3307，假设3307是当前的Master，Slave是 3306，当检测到3307异常后会从LVS 上摘掉 3307挂上 3306做高可用切换

![undefined](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/1713838496899-274cdfbd-aa6e-4f1f-9fcc-16725593c25e.png)

切换前的 LVS 状态

```
#ipvsadm -L --timeout
Timeout (tcp tcpfin udp): 900 120 300
#ipvsadm -L -n
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  127.0.0.1:3001 rr
  -> 127.0.0.1:3307               Masq    1      0          0
```

Sysbench启动压力模拟用户访问，在 31秒的时候模拟管控检测到 3307的Master无法访问，所以管控执行切主把 3306的Slave 提升为新的 Master，同时到 LVS 摘掉 3307，挂上3306，此时管控端着冰可乐、翘着二郎腿，得意地说，你就看吧我们管控牛逼不、我们的高可用牛逼不，这一套行云流水3秒钟不到全搞定

切换命令如下：

```
#cat del3307.sh
ipvsadm -d -t  127.0.0.1:3001 -r 127.0.0.1:3307 ; ipvsadm -a -t  127.0.0.1:3001 -r 127.0.0.1:3306 -m
```

此时Sysbench运行状态，在第 32秒如期跌0：

```
#/usr/local/bin/sysbench --debug=on --mysql-user='root' --mysql-password='123' --mysql-db='test' --mysql-host='127.0.0.1' --mysql-port='3001' --tables='16'  --table-size='10000' --range-size='5' --db-ps-mode='disable' --skip-trx='on' --mysql-ignore-errors='all' --time='11080' --report-interval='1' --histogram='on' --threads=1 oltp_read_write run
sysbench 1.1.0 (using bundled LuaJIT 2.1.0-beta3)

Running the test with following options:
Number of threads: 1
Report intermediate results every 1 second(s)
Debug mode enabled.

Initializing random number generator from current time


Initializing worker threads...

DEBUG: Worker thread (#0) started
DEBUG: Reporting thread started
DEBUG: Worker thread (#0) initialized
Threads started!

[ 1s ] thds: 1 tps: 51.89 qps: 947.00 (r/w/o: 739.44/207.56/0.00) lat (ms,95%): 35.59 err/s 0.00 reconn/s: 0.00
[ 2s ] thds: 1 tps: 60.03 qps: 1084.54 (r/w/o: 841.42/243.12/0.00) lat (ms,95%): 22.28 err/s 0.00 reconn/s: 0.00
…………
[ 29s ] thds: 1 tps: 68.00 qps: 1223.01 (r/w/o: 952.00/271.00/0.00) lat (ms,95%): 16.12 err/s 0.00 reconn/s: 0.00
[ 30s ] thds: 1 tps: 66.00 qps: 1188.00 (r/w/o: 924.00/264.00/0.00) lat (ms,95%): 16.71 err/s 0.00 reconn/s: 0.00
[ 31s ] thds: 1 tps: 67.00 qps: 1203.96 (r/w/o: 937.97/265.99/0.00) lat (ms,95%): 17.95 err/s 0.00 reconn/s: 0.00
[ 32s ] thds: 1 tps: 22.99 qps: 416.85 (r/w/o: 321.88/94.96/0.00) lat (ms,95%): 15.55 err/s 0.00 reconn/s: 0.00
[ 33s ] thds: 1 tps: 0.00 qps: 0.00 (r/w/o: 0.00/0.00/0.00) lat (ms,95%): 0.00 err/s 0.00 reconn/s: 0.00
[ 34s ] thds: 1 tps: 0.00 qps: 0.00 (r/w/o: 0.00/0.00/0.00) lat (ms,95%): 0.00 err/s 0.00 reconn/s: 0.00
[ 35s ] thds: 1 tps: 0.00 qps: 0.00 (r/w/o: 0.00/0.00/0.00) lat (ms,95%): 0.00 err/s 0.00 reconn/s: 0.00
```

5分钟后故障报告大批量涌进来，客户：怎么回事，我们的业务挂掉10分钟了，报错都是访问MySQL 超时，赶紧给我看看，从监控确实看到10分钟后客户业务还没恢复：

```
[ 601s ] thds: 1 tps: 0.00 qps: 0.00 (r/w/o: 0.00/0.00/0.00) lat (ms,95%): 0.00 err/s 0.00 reconn/s: 0.00
[ 602s ] thds: 1 tps: 0.00 qps: 0.00 (r/w/o: 0.00/0.00/0.00) lat (ms,95%): 0.00 err/s 0.00 reconn/s: 0.00
[ 603s ] thds: 1 tps: 0.00 qps: 0.00 (r/w/o: 0.00/0.00/0.00) lat (ms,95%): 0.00 err/s 0.00 reconn/s: 0.00
[ 604s ] thds: 1 tps: 0.00 qps: 0.00 (r/w/o: 0.00/0.00/0.00) lat (ms,95%): 0.00 err/s 0.00 reconn/s: 0.00
```

这时 oncall 都被从被窝里拎了起来，不知谁说了一句赶紧恢复吧，先试试把应用重启，5秒钟后应用重启完毕，业务恢复，大家开心地笑了，又成功防御住一次故障升级，还是重启大法好！

在业务/Sysbench QPS跌0 期间可以看到 3307被摘掉，3306 成功挂上去了，但是没有新连接建向 3306，业务/Sysbench 使劲薅着 3307

```
#ipvsadm -L -n --stats -t 127.0.0.1:3001
Prot LocalAddress:Port               Conns   InPkts  OutPkts  InBytes OutBytes
  -> RemoteAddress:Port
TCP  127.0.0.1:3001                      2   660294   661999 78202968  184940K
  -> 127.0.0.1:3306                      0        0        0        0        0
  
#ipvsadm -Lcn | head -10
IPVS connection entries
pro expire state       source             virtual            destination
TCP 13:11  ESTABLISHED 127.0.0.1:33864    127.0.0.1:3001     127.0.0.1:3307

#netstat -anto |grep -E "Recv|33864|3001|33077"
Proto Recv-Q Send-Q Local Address           Foreign Address         State       Timer
tcp        0    248 127.0.0.1:33864         127.0.0.1:3001          ESTABLISHED probe (33.48/0/8)
tcp6       0     11 127.0.0.1:3307          127.0.0.1:33864         ESTABLISHED on (49.03/13/0)
```

直到 900多秒后 OS 重试了15次发现都失败，于是向业务/Sysbench 返回连接异常，触发业务/Sysbench 释放异常连接重建新连接，新连接指向了新的 Master 3306，业务恢复正常

```
[ 957s ] thds: 1 tps: 0.00 qps: 0.00 (r/w/o: 0.00/0.00/0.00) lat (ms,95%): 0.00 err/s 0.00 reconn/s: 0.00
DEBUG: Ignoring error 2013 Lost connection to MySQL server during query,
DEBUG: Reconnecting 
DEBUG: Reconnected
[ 958s ] thds: 1 tps: 53.00 qps: 950.97 (r/w/o: 741.98/208.99/0.00) lat (ms,95%): 30.26 err/s 0.00 reconn/s: 1.00
[ 959s ] thds: 1 tps: 64.00 qps: 1154.03 (r/w/o: 896.02/258.01/0.00) lat (ms,95%): 22.69 err/s 0.00 reconn/s: 0.00
[ 960s ] thds: 1 tps: 66.00 qps: 1184.93 (r/w/o: 923.94/260.98/0.00) lat (ms,95%): 25.28 err/s 0.00 reconn/s: 0.00
```

到这里重现了故障中经常碰到的业务需要900多秒才能慢慢恢复，这个问题也就是 **TCP 长连接流量黑洞**



如果我们**把 net.ipv4.tcp_retries2 改成5** 再来做这个实验，就会发现业务/Sysbench 只需要20秒就能恢复了，也就是这个流量黑洞从900多秒变成了20秒，这回 oncall 不用再被从被窝里拎出来了吧：

```
[ 62s ] thds: 1 tps: 66.00 qps: 1191.00 (r/w/o: 924.00/267.00/0.00) lat (ms,95%): 17.63 err/s 0.00 reconn/s: 0.00
[ 63s ] thds: 1 tps: 63.00 qps: 1123.01 (r/w/o: 874.00/249.00/0.00) lat (ms,95%): 17.63 err/s 0.00 reconn/s: 0.00
[ 64s ] thds: 1 tps: 0.00 qps: 0.00 (r/w/o: 0.00/0.00/0.00) lat (ms,95%): 0.00 err/s 0.00 reconn/s: 0.00
[ 65s ] thds: 1 tps: 0.00 qps: 0.00 (r/w/o: 0.00/0.00/0.00) lat (ms,95%): 0.00 err/s 0.00 reconn/s: 0.00
[ 66s ] thds: 1 tps: 0.00 qps: 0.00 (r/w/o: 0.00/0.00/0.00) lat (ms,95%): 0.00 err/s 0.00 reconn/s: 0.00
[ 67s ] thds: 1 tps: 0.00 qps: 0.00 (r/w/o: 0.00/0.00/0.00) lat (ms,95%): 0.00 err/s 0.00 reconn/s: 0.00
[ 68s ] thds: 1 tps: 0.00 qps: 0.00 (r/w/o: 0.00/0.00/0.00) lat (ms,95%): 0.00 err/s 0.00 reconn/s: 0.00
[ 69s ] thds: 1 tps: 0.00 qps: 0.00 (r/w/o: 0.00/0.00/0.00) lat (ms,95%): 0.00 err/s 0.00 reconn/s: 0.00
[ 70s ] thds: 1 tps: 0.00 qps: 0.00 (r/w/o: 0.00/0.00/0.00) lat (ms,95%): 0.00 err/s 0.00 reconn/s: 0.00
[ 71s ] thds: 1 tps: 0.00 qps: 0.00 (r/w/o: 0.00/0.00/0.00) lat (ms,95%): 0.00 err/s 0.00 reconn/s: 0.00
[ 72s ] thds: 1 tps: 0.00 qps: 0.00 (r/w/o: 0.00/0.00/0.00) lat (ms,95%): 0.00 err/s 0.00 reconn/s: 0.00
[ 73s ] thds: 1 tps: 0.00 qps: 0.00 (r/w/o: 0.00/0.00/0.00) lat (ms,95%): 0.00 err/s 0.00 reconn/s: 0.00
[ 74s ] thds: 1 tps: 0.00 qps: 0.00 (r/w/o: 0.00/0.00/0.00) lat (ms,95%): 0.00 err/s 0.00 reconn/s: 0.00
[ 75s ] thds: 1 tps: 0.00 qps: 0.00 (r/w/o: 0.00/0.00/0.00) lat (ms,95%): 0.00 err/s 0.00 reconn/s: 0.00
[ 76s ] thds: 1 tps: 0.00 qps: 0.00 (r/w/o: 0.00/0.00/0.00) lat (ms,95%): 0.00 err/s 0.00 reconn/s: 0.00
[ 77s ] thds: 1 tps: 0.00 qps: 0.00 (r/w/o: 0.00/0.00/0.00) lat (ms,95%): 0.00 err/s 0.00 reconn/s: 0.00
[ 78s ] thds: 1 tps: 0.00 qps: 0.00 (r/w/o: 0.00/0.00/0.00) lat (ms,95%): 0.00 err/s 0.00 reconn/s: 0.00
[ 79s ] thds: 1 tps: 0.00 qps: 0.00 (r/w/o: 0.00/0.00/0.00) lat (ms,95%): 0.00 err/s 0.00 reconn/s: 0.00
[ 80s ] thds: 1 tps: 0.00 qps: 0.00 (r/w/o: 0.00/0.00/0.00) lat (ms,95%): 0.00 err/s 0.00 reconn/s: 0.00
[ 81s ] thds: 1 tps: 0.00 qps: 0.00 (r/w/o: 0.00/0.00/0.00) lat (ms,95%): 0.00 err/s 0.00 reconn/s: 0.00
[ 82s ] thds: 1 tps: 0.00 qps: 0.00 (r/w/o: 0.00/0.00/0.00) lat (ms,95%): 0.00 err/s 0.00 reconn/s: 0.00
DEBUG: Ignoring error 2013 Lost connection to MySQL server during query,
DEBUG: Reconnecting 
DEBUG: Reconnected
[ 83s ] thds: 1 tps: 26.00 qps: 457.01 (r/w/o: 357.01/100.00/0.00) lat (ms,95%): 16.41 err/s 0.00 reconn/s: 1.00
[ 84s ] thds: 1 tps: 60.00 qps: 1086.94 (r/w/o: 846.96/239.99/0.00) lat (ms,95%): 26.68 err/s 0.00 reconn/s: 0.00
[ 85s ] thds: 1 tps: 63.00 qps: 1134.02 (r/w/o: 882.01/252.00/0.00) lat (ms,95%): 23.10 err/s 0.00 reconn/s: 0.00
```

### LVS + Nginx 上重现

NGINX上重现这个问题：https://asciinema.org/a/649890 3分钟的录屏，这个视频构造了一个LVS 的HA切换过程，LVS后有两个Nginx，模拟一个Nginx(Master) 断网后，将第二个Nginx(Slave) 加入到LVS 并将第一个Nginx(Master) 从LVS 摘除，期望业务能立即恢复，但实际上可以看到之前的所有长连接都没有办法恢复，进入一个流量黑洞



## TCP 长连接流量黑洞原理总结

TCP 长连接在发送包的时候，如果没收到ack 默认会进行15次重传(net.ipv4.tcp_retries2=15, 这个不要较真，会根据RTO 时间大致是15次)，累加起来大概是924秒，所以我们经常看到业务需要15分钟左右才恢复。这个问题存在所有TCP长连接中(几乎没有业务还在用短连接吧？)，问题的本质和 LVS/k8s Service 都没关系

我这里重现带上 LVS 只是为了场景演示方便 

这个问题的本质就是如果Server突然消失(宕机、断网，来不及发 RST )客户端如果正在发东西给Server就会遵循TCP 重传逻辑不断地TCP retran , 如果一直收不到Server 的ack，大约重传15次，900秒左右。所以不是因为有 LVS 导致了这个问题，而是在某些场景下 LVS 有能力处理得更优雅，比如删除 RealServer的时候 LVS 完全可以感知这个动作并 reset 掉其上所有长连接

为什么在K8S 上这个问题更明显呢，K8S 讲究的就是服务不可靠，随时干掉POD(切断网络），如果干POD 之前能kill -9(触发reset)、或者close 业务触发断开连接那还好，但是大多时候啥都没干，有强摘POD、有直接隔离等等，这些操作都会导致对端只能TCP retran



## 怎么解决

### 业务方

业务方要对自己的请求超时时间有控制和兜底，不能任由一个请求长时间 Hang 在那里

比如JDBC URL 支持设置 SocketTimeout、ConnectTimeout，我相信其他产品也有类似的参数，业务方要设置这些值，不设置就是如上重现里演示的900多秒后才恢复

#### SocketTimeout

只要是连接有机会设置 SocketTimeout 就一定要设置，具体值可以根据你们能接受的慢查询来设置；分析、AP类的请求可以设置大一点

**最重要的：任何业务只要你用到了TCP 长连接一定要配置一个恰当的SocketTimeout**，比如 Jedis 是连接池模式，底层超时之后，会销毁当前连接，下一次重新建连，就会连接到新的切换节点上去并恢复



#### [RFC 5482](https://datatracker.ietf.org/doc/html/rfc5482) `TCP_USER_TIMEOUT`

[RFC 5482](https://datatracker.ietf.org/doc/html/rfc5482) 中增加了`TCP_USER_TIMEOUT`这个配置，通常用于定制当 TCP 网络连接中出现数据传输问题时，可以等待多长时间前释放网络资源，对应Linux 这个 [commit ](https://github.com/torvalds/linux/commit/dca43c75e7e545694a9dd6288553f55c53e2a3a3)

`TCP_USER_TIMEOUT` 是一个整数值，它指定了当 TCP 连接的数据包在发送后多长时间内未被确认（即没有收到 ACK），TCP 连接会考虑释放这个连接。

打个比方，设置 `TCP_USER_TIMEOUT` 后，应用程序就可以指定说：“如果在 30 秒内我发送的数据没有得到确认，那我就认定网络连接出了问题，不再尝试继续发送，而是直接断开连接。”这对于确保连接质量和维护用户体验是非常有帮助的。

在 Linux 中，可以使用 `setsockopt` 函数来设置某个特定 socket 的 `TCP_USER_TIMEOUT` 值：

```
int timeout = 30000; // 30 seconds
setsockopt(sock, IPPROTO_TCP, TCP_USER_TIMEOUT, (char *)&timeout, sizeof(timeout));
```

在这行代码中，`sock` 是已经 established 的 TCP socket，我们将该 socket 的 `TCP_USER_TIMEOUT` 设置为 30000 毫秒，也就是 30 秒。如果设置成功，这个 TCP 连接在发送数据包后 30 秒内如果没有收到 ACK 确认，将开始进行 TCP 连接的释放流程。

TCP_USER_TIMEOUT 相较 SocketTimeout 可以做到更精确(不影响慢查询)，SocketTimeout 超时是不区分ACK 还是请求响应时间的，但是 TCP_USER_TIMEOUT 要求下层的API、OS 都支持。比如 JDK 不支持 TCP_USER_TIMEOUT，但是 [Netty 框架自己搞了Native](https://github.com/tomasol/netty/commit/3010366d957d7b8106e353f99e15ccdb7d391d8f#diff-a998f73b7303461ca171432d10832884c6e7b0955d9f5634b9a8302b42a4706c) 来实现对 TCP_USER_TIMEOUT 以及其它OS 参数的设置，在这些基础上[Redis 的Java 客户端 lettuce 依赖了 Netty ，所以也可以设置 TCP_USER_TIMEOUT](https://github.com/redis/lettuce/pull/2499)

原本我是想在Druid 上提个feature 来支持 TCP_USER_TIMEOUT，这样集团绝大部分业务都可以无感知解决掉这个问题，但查下来发现 JDK 不支持设置这个值，想要在Druid 里面实现设置 TCP_USER_TIMEOUT 的话，得像 Netty 一样走Native 绕过JDK 来设置，这对 Druid 而言有点重了

#### ConnectTimeout

这个值是针对新连接创建超时时间设置，一般设置3-5秒就够长了



#### 连接池

建议参考这篇 [《数据库连接池配置推荐》](https://help.aliyun.com/document_detail/181399.html)  这篇里的很多建议也适合业务、应用等，你把数据库看成一个普通服务就好理解了

补充下如果用的是Druid 数据库连接池不要用它来设置你的  SocketTimeout 参数，因为他有bug 导致你觉得设置了但实际没设置上，[2024-03-16号的1.2.22](https://github.com/alibaba/druid/releases/tag/1.2.22)这个Release 才fix，所以强烈建议你讲 SocketTimeout 写死在JDBC URL 中简单明了



### OS 兜底

假如业务是一个AP查询/一次慢请求，一次查询/请求就是需要半个小时，将 SocketTimeout 设置太小影响正常的查询，那么可以将如下 OS参数改小，从 OS 层面进行兜底

```
net.ipv4.tcp_retries2 = 8
net.ipv4.tcp_syn_retries = 4
```

#### keepalive

keepalive 默认 7200秒太长了，建议改成20秒，可以在OS 镜像层面固化，然后各个业务可以 patch 自己的值；

如果一条连接限制超过 900 秒 LVS就会Reset 这条连接，但是我们将keepalive 设置小于900秒的话，即使业务上一直闲置，因为有 keepalive 触发心跳包，让 LVS 不至于 Reset，这也就避免了当业务取连接使用的时候才发现连接已经不可用被断开了，往往这个时候业务抛错误的时间很和真正 Reset 时间还差了很多，不好排查

在触发 TCP retransmission 后会停止 keepalive 探测

### LVS

如果你们试用了aliyun的SLB，当摘除节点的时候支持你设置一个时间，过了这个时间 aliyun的SLB 就会向这些连接的客户端发 Reset 干掉这些流量，让客户端触发新建连接，从故障中快速恢复，这是一个实例维度的参数，建议云上所有产品都支持起来，管控可以在购买 aliyun的SLB 的时候设置一个默认值：

 `connection_drain_timeout` 



## 其它

### 神奇的900秒

上面阐述的长连接流量黑洞一般是900+秒就恢复了，有时候我们经常在日志中看到 CommunicationsException: Communications link failure 900秒之类的错误，恰好 LVS 也是设置的 900秒闲置 Reset

```
#ipvsadm -L --timeout
Timeout (tcp tcpfin udp): 900 120 300
```

### 为什么这个问题这几年才明显暴露

- 工程师们混沌了几十年
- 之前因为出现频率低重启业务就糊弄过去了
- 对新连接不存在这个问题
- 有些连接池配置了Check 机制(Check机制一般几秒钟超时 fail)
- 微服务多了
- 云上 LVS 普及了
- k8s service 大行其道



### 我用的 7层是不是就没有这个问题了？

幼稚，你4层都挂了7层还能蹦跶，再说一遍只要是 TCP 长连接就有这个问题



### 极端情况

A 长连接 访问B 服务，B服务到A网络不通，假如B发生HA，一般会先Reset/断开B上所有连接(比如 MySQL 会去kill 所有processlist；比如重启MySQL——假如这里的B是MySQL)，但是因为网络不通这里的reset、fin网络包都无法到达A，所以B是无法兜底这个异常场景， A无法感知B不可用了，会使用旧连接大约15分钟

最可怕的是 B 服务不响应，B所在的OS 还在响应，那么在A的视角 网络是正常的，这时只能A自己来通过超时兜底



## 总结

这种问题在 LVS 场景下暴露更明显了，但是又和LVS 没啥关系，任何业务长连接都会导致这个 900秒左右的流量黑洞，首先要在业务层面重视这个问题，要不以后数据库一挂掉还得重启业务才能从故障中将恢复，所以业务层面处理好了可以避免900秒黑洞和重启业务，达到快速从故障中恢复

再强调下这个问题如果去掉LVS/k8s Service/软负载等让两个服务直连，然后拔网线也会同样出现



最佳实践总结：

- 如果你的业务支持设置 SocketTimeout 那么请一定要设置，但不一定适合分析类就是需要长时间返回的请求
- 最好的方式是设置 OS 层面的 TCP_USER_TIMEOUT 参数，只要长时间没有 ack 就报错返回，但 JDK 不支持直接设置
- 如果用了 ALB/SLB 就一定要配置 connection_drain_timeout 这个参数
- OS 镜像层面也可以将 tcp_retries2 设置为5-10次做一个兜底
- 对你的超时时间做到可控、可预期



## 相关故障和资料

ALB 黑洞问题详述：https://mp.weixin.qq.com/s/BJWD2V_RM2rnU1y7LPB9aw

数据库故障引发的“血案” ：https://www.cnblogs.com/nullllun/p/15073022.html 这篇描述较细致，推荐看看

tcp_retries2 的解释：

```
tcp_retries1 - INTEGER
    This value influences the time, after which TCP decides, that
    something is wrong due to unacknowledged RTO retransmissions,
    and reports this suspicion to the network layer.
    See tcp_retries2 for more details.

    RFC 1122 recommends at least 3 retransmissions, which is the
    default.

tcp_retries2 - INTEGER
    This value influences the timeout of an alive TCP connection,
    when RTO retransmissions remain unacknowledged.
    Given a value of N, a hypothetical TCP connection following
    exponential backoff with an initial RTO of TCP_RTO_MIN would
    retransmit N times before killing the connection at the (N+1)th RTO.

    The default value of 15 yields a hypothetical timeout of 924.6
    seconds and is a lower bound for the effective timeout.
    TCP will effectively time out at the first RTO which exceeds the
    hypothetical timeout.

    RFC 1122 recommends at least 100 seconds for the timeout,
    which corresponds to a value of at least 8.
```

tcp_retries2 默认值为15，根据RTO的值来决定，相当于13-30分钟(RFC1122规定，必须大于100秒)，但是这是很多年前的拍下来古董参数值，现在网络条件好多了，尤其是内网，个人认为改成 5-10 是比较恰当 azure 建议：https://learn.microsoft.com/en-us/azure/azure-cache-for-redis/cache-best-practices-connection ，Oracle RAC的建议值是3：https://access.redhat.com/solutions/726753

