---
title: 就是要你懂网络监控--ss用法大全
date: 2016-10-12 15:30:03
categories: network
tags:
    - Linux
    - ss
    - netstat
    - socket
---

# 就是要你懂网络监控--ss用法大全

ss是Socket Statistics的缩写。

netstat命令大家肯定已经很熟悉了，但是在2001年的时候netstat 1.42版本之后就没更新了，之后取代的工具是ss命令，是iproute2 package的一员。

> ​	rpm -ql iproute | grep ss
> ​	/usr/sbin/ss

netstat的替代工具是nstat，当然netstat的大部分功能ss也可以替代

ss可以显示跟netstat类似的信息，但是速度却比netstat快很多，netstat是基于/proc/net/tcp获取 TCP socket 的相关统计信息，用strace跟踪一下netstat查询tcp的连接，会看到他open的是/proc/net/tcp的信息。ss快的秘密就在于它利用的是TCP协议的tcp_diag模块，而且是从内核直接读取信息，**当内核不支持  tcp_diag 内核模块时，会回退到 /proc/net/tcp 模式**。

/proc/net/snmp 存放的是系统启动以来的累加值，netstat -s 读取它
/proc/net/tcp  是存放目前活跃的tcp连接的统计值，连接断开统计值清空， ss -it 读取它

## [ss 查看Buffer窗口](https://access.redhat.com/discussions/3624151)

ss参数说明[权威参考](https://man7.org/linux/man-pages/man8/ss.8.html)

--memory/-m ： 展示buffer窗口的大小

```
#ss -m | xargs -L 1 | grep "tcp EST" | awk '{ if($3>0 || $4>0) print $0 }'
tcp ESTAB 0 31 10.97.137.1:7764 10.97.137.2:41019 skmem:(r0,rb7160692,t0,tb87040,f1792,w2304,o0,bl0)
tcp ESTAB 0 193 ::ffff:10.97.137.1:sdo-tls ::ffff:10.97.137.2:55545 skmem:(r0,rb369280,t0,tb87040,f1792,w2304,o0,bl0)
tcp ESTAB 0 65 ::ffff:10.97.137.1:splitlock ::ffff:10.97.137.2:47796 skmem:(r0,rb369280,t0,tb87040,f1792,w2304,o0,bl0)
tcp ESTAB 0 80 ::ffff:10.97.137.1:informer ::ffff:10.97.137.3:49279 skmem:(r0,rb369280,t0,tb87040,f1792,w2304,o0,bl0)
tcp ESTAB 0 11 ::ffff:10.97.137.1:acp-policy ::ffff:10.97.137.2:41607 skmem:(r0,rb369280,t0,tb87040,f1792,w2304,o0,bl0)

#ss -m -n | xargs -L 1 | grep "tcp EST" | grep "t[1-9]"
tcp ESTAB 0 281 10.97.169.173:32866 10.97.170.220:3306 skmem:(r0,rb4619516,t2304,tb87552,f1792,w2304,o0,bl0)
```

![image.png](/images/oss/4a09503e6c6e84c25e026248a1b3ebb6.png)

如上图，tb指可分配的发送buffer大小，不够还可以动态调整（应用没有写死的话），w[The memory allocated for sending packet (which has not been sent to layer 3)]已经预分配好了的size，t[the memory used for sending packet (which has been sent to layer 3)] , 似乎 w总是等于大于t？

The entire print format of `ss -m` is given in the source:

```
      printf(" skmem:(r%u,rb%u,t%u,tb%u,f%u,w%u,o%u",
               skmeminfo[SK_MEMINFO_RMEM_ALLOC],
               skmeminfo[SK_MEMINFO_RCVBUF],
               skmeminfo[SK_MEMINFO_WMEM_ALLOC],
               skmeminfo[SK_MEMINFO_SNDBUF],
               skmeminfo[SK_MEMINFO_FWD_ALLOC],
               skmeminfo[SK_MEMINFO_WMEM_QUEUED],
               skmeminfo[SK_MEMINFO_OPTMEM]);

        if (RTA_PAYLOAD(tb[attrtype]) >=
                (SK_MEMINFO_BACKLOG + 1) * sizeof(__u32))
                printf(",bl%u", skmeminfo[SK_MEMINFO_BACKLOG]);

        if (RTA_PAYLOAD(tb[attrtype]) >=
                (SK_MEMINFO_DROPS + 1) * sizeof(__u32))
                printf(",d%u", skmeminfo[SK_MEMINFO_DROPS]);

        printf(")");
        
        
net/core/sock.c line:3095
void sk_get_meminfo(const struct sock *sk, u32 *mem)
{
	memset(mem, 0, sizeof(*mem) * SK_MEMINFO_VARS);

	mem[SK_MEMINFO_RMEM_ALLOC] = sk_rmem_alloc_get(sk);
	mem[SK_MEMINFO_RCVBUF] = sk->sk_rcvbuf;
	mem[SK_MEMINFO_WMEM_ALLOC] = sk_wmem_alloc_get(sk);
	mem[SK_MEMINFO_SNDBUF] = sk->sk_sndbuf;
	mem[SK_MEMINFO_FWD_ALLOC] = sk->sk_forward_alloc;
	mem[SK_MEMINFO_WMEM_QUEUED] = sk->sk_wmem_queued;
	mem[SK_MEMINFO_OPTMEM] = atomic_read(&sk->sk_omem_alloc);
	mem[SK_MEMINFO_BACKLOG] = sk->sk_backlog.len;
	mem[SK_MEMINFO_DROPS] = atomic_read(&sk->sk_drops);
}
```

![image-20210604120011898](/images/951413iMgBlog/image-20210604120011898.png)

example:

![image.png](/images/oss/4ed3d8aab6ef3ee45decda75e534baab.png)



## ss 查看拥塞窗口、RTO

> //rto的定义，不让修改，到每个ip的rt都不一样，必须通过rtt计算所得, HZ 一般是1秒
> #define TCP_RTO_MAX     ((unsigned)(120*HZ))
> #define TCP_RTO_MIN     ((unsigned)(HZ/5)) //在rt很小的环境中计算下来RTO基本等于TCP_RTO_MIN

下面看到的rto和rtt单位都是毫秒，一般rto最小为200ms、最大为120秒

```
#ss -itn |egrep "cwnd|rto"	
ESTAB       0      165      [::ffff:192.168.0.174]:48074                [::ffff:192.168.0.173]:3306
	cubic wscale:7,7 rto:201 rtt:0.24/0.112 ato:40 mss:1448 rcvmss:1448 advmss:1448 cwnd:10 bytes_acked:1910206449 bytes_received:8847784416 segs_out:11273005 segs_in:22997562 data_segs_out:9818729 data_segs_in:13341573 send 482.7Mbps lastsnd:1 lastrcv:1 pacing_rate 963.8Mbps delivery_rate 163.2Mbps app_limited busy:2676463ms retrans:0/183 rcv_rtt:1.001 rcv_space:35904 minrtt:0.135

ESTAB       0      0        [::ffff:192.168.0.174]:48082                [::ffff:192.168.0.173]:3306
	 cubic wscale:7,7 rto:201 rtt:0.262/0.112 ato:40 mss:1448 rcvmss:1448 advmss:1448 cwnd:10 bytes_acked:1852907381 bytes_received:8346503207 segs_out:10913962 segs_in:22169704 data_segs_out:9531411 data_segs_in:12796151 send 442.1Mbps lastsnd:2 lastack:2 pacing_rate 881.3Mbps delivery_rate 164.3Mbps app_limited busy:2736500ms retrans:0/260 rcv_rtt:1.042 rcv_space:31874 minrtt:0.133
	 
	 -----
	 skmem:(r0,rb131072,t0,tb133632,f0,w0,o0,bl0,d0) cubic wscale:8,7 rto:233 rtt:32.489/2.99 ato:40 mss:1380 rcvmss:536 advmss:1460 cwnd:11 ssthresh:8 bytes_acked:99862366 bytes_received:2943 segs_out:78933 segs_in:23388 data_segs_out:78925 data_segs_in:81 send 3.7Mbps lastsnd:1735288 lastrcv:1735252 lastack:1735252 pacing_rate 4.5Mbps delivery_rate 2.9Mbps busy:370994ms retrans:0/6479 reordering:5 rcv_space:14600 minrtt:27.984
```

### RTO计算算法

RTO的计算依赖于RTT值，或者说一系列RTT值。rto=f(rtt)

```
1.1. 在没有任何rtt sample的时候，RTO <- TCP_TIMEOUT_INIT (1s)
   多次重传时同样适用指数回避算法(backoff)增加RTO  

1.2. 获得第一个RTT sample后，
    SRTT <- RTT
    RTTVAR <- RTT/2
    RTO <- SRTT + max(G, K * RTTVAR)
其中K=4, G表示timestamp的粒度(在CONFIG_HZ=1000时，粒度为1ms)

1.3. 后续获得更多RTT sample后，
    RTTVAR <- (1 - beta) * RTTVAR + beta * |SRTT - R|
    SRTT <- (1 - alpha) * SRTT + alpha * R
其中beta = 1/4, alpha = 1/8

1.4. Whenever RTO is computed, if it is less than 1 second, then the
   RTO SHOULD be rounder up to 1 second.

1.5. A maximum value MAY be placed on RTO provided it is at least 60 seconds.
```

RTTVAR表示的是平滑过的平均偏差，SRTT表示的平滑过的RTT。这两个值的具体含义会在后面介绍
具体实现的时候进一步的解释。
以上是计算一个初始RTO值的过程，当连续出现RTO超时后，
RTO值会用一个叫做指数回避的策略进行调整，下面来具体介绍。

## 从系统cache中查看 tcp_metrics item

	$sudo ip tcp_metrics show | grep  100.118.58.7
	100.118.58.7 age 1457674.290sec tw_ts 3195267888/5752641sec ago rtt 1000us rttvar 1000us ssthresh 361 cwnd 40 ----这两个值对传输性能很重要
	
	192.168.1.100 age 1051050.859sec ssthresh 4 cwnd 2 rtt 4805us rttvar 4805us source 192.168.0.174 ---这条记录有问题，缓存的ssthresh 4 cwnd 2都太小，传输速度一定慢 
	
	清除 tcp_metrics, sudo ip tcp_metrics flush all 
	关闭 tcp_metrics 功能，net.ipv4.tcp_no_metrics_save = 1
	sudo ip tcp_metrics delete 100.118.58.7

每个连接的ssthresh默认是个无穷大的值，但是内核会cache对端ip上次的ssthresh（大部分时候两个ip之间的拥塞窗口大小不会变），这样大概率到达ssthresh之后就基本拥塞了，然后进入cwnd的慢增长阶段。

## ss 过滤地址和端口号，类似tcpdump的用法

过滤目标端口是80的或者源端口是1723的连接，dst后面要跟空格然后加“：”：

	# ss -ant dst :80 or src :1723 
	State      Recv-Q Send-Q   Local Address:Port Peer Address:Port 
	LISTEN     0      3        *:1723              *:*     
	TIME-WAIT  0      0                                                     172.31.23.95:37269                                              111.161.68.235:80    
	TIME-WAIT  0      0                                                     172.31.23.95:37263                                              111.161.68.235:80    
	TIME-WAIT  0      0                                                     172.31.23.95:37267 

or：

	ss -ant dport = :80 or sport = :1723

地址筛选，目标地址是111.161.68.235的连接

	ss -ant dst 111.161.68.235

端口大小筛选，源端口大于1024的端口：

	ss sport gt 1024

How Do I Compare Local and/or Remote Port To A Number?
Use the following syntax:

	## Compares remote port to a number ##
	ss dport OP PORT
	 
	## Compares local port to a number ##
	sport OP PORT

Where OP can be one of the following:

	<= or le : Less than or equal to port
	>= or ge : Greater than or equal to port
	== or eq : Equal to port
	!= or ne : Not equal to port
	< or gt : Less than to port
	> or lt : Greater than to port
	Note: le, gt, eq, ne etc. are use in unix shell and are accepted as well.
	
	###################################################################################
	### Do not forget to escape special characters when typing them in command line ###
	###################################################################################
	 
	ss  sport = :http
	ss  dport = :http
	ss  dport \> :1024
	ss  sport \> :1024
	ss sport \< :32000
	ss  sport eq :22
	ss  dport != :22
	ss  state connected sport = :http
	ss \( sport = :http or sport = :https \)
	ss -o state fin-wait-1 \( sport = :http or sport = :https \) dst 192.168.1/24

## 按连接状态过滤

Display All Established HTTP Connections

	ss -o state established '( dport = :http or sport = :http )'

List all the TCP sockets in state -FIN-WAIT-1 for our httpd to network 202.54.1/24 and look at their timers:
	ss -o state fin-wait-1 '( sport = :http or sport = :https )' dst 202.54.1/24

Filter Sockets Using TCP States

	ss -4 state FILTER-NAME-HERE

Where FILTER-NAME-HERE can be any one of the following,

	established
	syn-sent
	syn-recv
	fin-wait-1
	fin-wait-2
	time-wait
	closed
	close-wait
	last-ack
	listen
	closing
	all : All of the above states
	connected : All the states except for listen and closed
	synchronized : All the connected states except for syn-sent
	bucket : Show states, which are maintained as minisockets, i.e. time-wait and syn-recv.
	big : Opposite to bucket state.

## ss分析重传的包数量

通过抓取ss命令，可以分析出来重传的包数量，然后将重传的流的数量和重传的包的数量按照对端IP:port的维度分段聚合，参考命令：

	ss -itn |grep -v "Address:Port" | xargs -L 1  | grep retrans | awk '{gsub("retrans:.*/", "",$21); print $5, $21}' | awk '{arr[$1]+=$2} END {for (i in arr) {print i,arr[i]}}' | sort -rnk 2 

xargs **-L 1**  每一行处理一次，但是这个行如果是空格、tab结尾，那么会被认为是连续行，跟下一行合并

高版本Linux内核的话，可以用systemtap或者bcc来获取每个连接的重传包以及发生重传的阶段

## 当前和最大全连接队列确认

	$ss -lt
	State      Recv-Q Send-Q Local Address:Port                 Peer Address:Port         
	LISTEN     0      128    127.0.0.1:10248                       *:*                   
	LISTEN     0      128           *:2376                        *:*                    
	LISTEN     0      128    127.0.0.1:10249                       *:*                   
	LISTEN     0      128           *:7337                        *:*                    
	LISTEN     0      128           *:10250                       *:*                    
	LISTEN     0      128    11.163.187.44:7946                        *:*               
	LISTEN     0      128    127.0.0.1:55631                       *:*                   
	LISTEN     0      128           *:10256                       *:*                    
	LISTEN     0      10            *:6640                        *:*                    
	LISTEN     0      128    127.0.0.1:vmware-fdm                  *:*                   
	LISTEN     0      128    11.163.187.44:vmware-fdm                  *:*               
	LISTEN     0      128           *:ssh                         *:*                    
	LISTEN     0      10     127.0.0.1:15772                       *:*                   
	LISTEN     0      10     127.0.0.1:15776                       *:*                   
	LISTEN     0      10     127.0.0.1:19777                       *:*                   
	LISTEN     0      10     11.163.187.44:15778                       *:*               
	LISTEN     0      128           *:tr-rsrb-p2                  *:*

## ss -s

统计所有连接的状态

## nstat

nstat -z -t 1 类似 netstat -s  (ss --info 展示rto、拥塞算法等更详细信息； netstat -ant -o 展示keepalive是否)

netstat[参考](http://perthcharles.github.io/2015/11/10/wiki-netstat-proc/)

## knetstat

最后给出的一个工具，knetstat（需要单独安装），也可以查看tcp的状态下的各种参数，需要单独安装

example(3306是本地server，4192是后端MySQL）：

	Recv-Q Send-Q Local Address           Foreign Address         Stat Diag Options
	 0      0 0.0.0.0:3306            0.0.0.0:*               LSTN      SO_REUSEADDR=1,SO_REUSEPORT=0,SO_KEEPALIVE=0,TCP_NODELAY=0,TCP_FASTOPEN=0,TCP_DEFER_ACCEPT=0
	 0      0 0.0.0.0:3406            0.0.0.0:*               LSTN      SO_REUSEADDR=1,SO_REUSEPORT=0,SO_KEEPALIVE=0,TCP_NODELAY=0,TCP_FASTOPEN=0,TCP_DEFER_ACCEPT=0
	 0      0 127.0.0.1:8182          0.0.0.0:*               LSTN      SO_REUSEADDR=1,SO_REUSEPORT=0,SO_KEEPALIVE=0,TCP_NODELAY=0,TCP_FASTOPEN=0,TCP_DEFER_ACCEPT=0
	 0      0 10.0.186.73:8182        0.0.0.0:*               LSTN      SO_REUSEADDR=1,SO_REUSEPORT=0,SO_KEEPALIVE=0,TCP_NODELAY=0,TCP_FASTOPEN=0,TCP_DEFER_ACCEPT=0
	 0      0 0.0.0.0:22              0.0.0.0:*               LSTN      SO_REUSEADDR=1,SO_REUSEPORT=0,SO_KEEPALIVE=0,TCP_NODELAY=0,TCP_FASTOPEN=0,TCP_DEFER_ACCEPT=0
	 0      0 0.0.0.0:8188            0.0.0.0:*               LSTN      SO_REUSEADDR=1,SO_REUSEPORT=0,SO_KEEPALIVE=0,TCP_NODELAY=0,TCP_FASTOPEN=0,TCP_DEFER_ACCEPT=0
	 0      0 127.0.0.1:15778         0.0.0.0:*               LSTN      SO_REUSEADDR=1,SO_REUSEPORT=0,SO_KEEPALIVE=0,TCP_NODELAY=0,TCP_FASTOPEN=0,TCP_DEFER_ACCEPT=0 
	 0    138 10.0.186.73:51756       10.0.160.1:4192         ESTB >#   SO_REUSEADDR=0,SO_REUSEPORT=0,SO_KEEPALIVE=1,TCP_NODELAY=1,TCP_DEFER_ACCEPT=0
	 0      0 10.0.186.73:3306        10.0.186.70:37428       ESTB      SO_REUSEADDR=1,SO_REUSEPORT=0,SO_KEEPALIVE=1,SO_RCVBUF=32768,SO_SNDBUF=65536,TCP_NODELAY=1,TCP_DEFER_ACCEPT=0
	 0    138 10.0.186.73:51476       10.0.160.1:4192         ESTB >#   SO_REUSEADDR=0,SO_REUSEPORT=0,SO_KEEPALIVE=1,TCP_NODELAY=1,TCP_DEFER_ACCEPT=0
	 0      0 10.0.186.73:3306        10.0.186.70:37304       ESTB      SO_REUSEADDR=1,SO_REUSEPORT=0,SO_KEEPALIVE=1,SO_RCVBUF=32768,SO_SNDBUF=65536,TCP_NODELAY=1,TCP_DEFER_ACCEPT=0
	 0      0 10.0.186.73:51842       10.0.160.1:4192         ESTB      SO_REUSEADDR=0,SO_REUSEPORT=0,SO_KEEPALIVE=1,TCP_NODELAY=1,TCP_DEFER_ACCEPT=0
	44      0 10.0.186.73:3306        10.0.186.70:36238       ESTB      SO_REUSEADDR=1,SO_REUSEPORT=0,SO_KEEPALIVE=1,SO_RCVBUF=32768,SO_SNDBUF=65536,TCP_NODELAY=1,TCP_DEFER_ACCEPT=0
	44      0 10.0.186.73:3306        10.0.186.70:36160       ESTB      SO_REUSEADDR=1,SO_REUSEPORT=0,SO_KEEPALIVE=1,SO_RCVBUF=32768,SO_SNDBUF=65536,TCP_NODELAY=1,TCP_DEFER_ACCEPT=0
	0      0 10.0.186.73:19030       10.0.171.188:8000       TIMW

3306对应的client上：

	Recv-Q Send-Q Local Address           Foreign Address         Stat Diag Options
	 0     44 10.0.186.70:42428       10.0.186.73:3306        ESTB >#   SO_REUSEADDR=0,SO_REUSEPORT=0,SO_KEEPALIVE=1,SO_RCVTIMEO=31536000000ms,SO_SNDTIMEO=31536000000ms,TCP_NODELAY=1,TCP_DEFER_ACCEPT=0
	 0     44 10.0.186.70:42298       10.0.186.73:3306        ESTB >#   SO_REUSEADDR=0,SO_REUSEPORT=0,SO_KEEPALIVE=1,SO_RCVTIMEO=31536000000ms,SO_SNDTIMEO=31536000000ms,TCP_NODELAY=1,TCP_DEFER_ACCEPT=0
	 0     44 10.0.186.70:42296       10.0.186.73:3306        ESTB >#   SO_REUSEADDR=0,SO_REUSEPORT=0,SO_KEEPALIVE=1,SO_RCVTIMEO=31536000000ms,SO_SNDTIMEO=31536000000ms,TCP_NODELAY=1,TCP_DEFER_ACCEPT=0
	 0     44 10.0.186.70:42322       10.0.186.73:3306        ESTB >#   SO_REUSEADDR=0,SO_REUSEPORT=0,SO_KEEPALIVE=1,SO_RCVTIMEO=31536000000ms,SO_SNDTIMEO=31536000000ms,TCP_NODELAY=1,TCP_DEFER_ACCEPT=0

Diag列的说明	
	Indicator		Meaning
	  >|	         The sender window (i.e. the window advertised by the remote endpoint) is 0. No data can be sent to the peer.
	    >|<	         The receiver window (i.e. the window advertised by the local endpoint) is 0. No data can be received from the peer.
	  >
	  >#	         There are unacknowledged packets and the last ACK was received more than one second ago. This may be an indication that there are network problems or that the peer crashed.


## 参考文章

https://www.cyberciti.biz/tips/linux-investigate-sockets-network-connections.html

http://perthcharles.github.io/2015/11/10/wiki-netstat-proc/

源代码：https://github.com/sivasankariit/iproute2/blob/master/misc/ss.c

https://github.com/veithen/knetstat/tree/master

https://access.redhat.com/discussions/782343

[RTO的计算方法(基于RFC6298和Linux 3.10)](https://perthcharles.github.io/2015/09/06/wiki-rtt-estimator/)