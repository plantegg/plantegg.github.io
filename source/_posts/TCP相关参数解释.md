---
title: TCP相关参数解释
date: 2020-01-26 17:30:03
categories:
    - TCP
tags:
    - Linux
    - TCP
    - 参数
    - network
---

# TCP相关参数解释

读懂TCP参数前得先搞清楚内核中出现的HZ、Tick、Jiffies三个值是什么意思

## HZ

它可以理解为1s，所以120*HZ就是120秒，HZ/5就是200ms。

HZ表示CPU一秒种发出多少次时间中断--IRQ-0，Linux中通常用HZ来做时间片的计算（[参考](http://blog.csdn.net/bdc995/article/details/4144031)）。

这个值在内核编译的时候可设定100、250、300或1000，一般设置的是1000

```
#cat /boot/config-`uname -r` |grep 'CONFIG_HZ='
CONFIG_HZ=1000 //一般默认1000, Linux核心每隔固定周期会发出timer interrupt (IRQ 0)，HZ是用来定义
每一秒有几次timer interrupts。举例来说，HZ为1000，代表每秒有1000次timer interrupts
```

HZ的设定：
\#make menuconfig
processor type and features--->Timer frequency (250 HZ)--->

HZ的不同值会影响timer （节拍）中断的频率

## Tick

Tick是HZ的倒数，意即timer interrupt每发生一次中断的间隔时间。如HZ为250时，tick为4毫秒(millisecond)。

## Jiffies

Jiffies为Linux核心变数(32位元变数，unsigned long)，它被用来纪录系统自开几以来，已经过多少的tick。每发生一次timer interrupt，Jiffies变数会被加一。值得注意的是，Jiffies于系统开机时，并非初始化成零，而是被设为-300*HZ (arch/i386/kernel/time.c)，即代表系统于开机五分钟后，jiffies便会溢位。那溢出怎么办?事实上，Linux核心定义几个macro(timer_after、time_after_eq、time_before与time_before_eq)，即便是溢位，也能藉由这几个macro正确地取得jiffies的内容。

另外，80x86架构定义一个与jiffies相关的变数jiffies_64 ，此变数64位元，要等到此变数溢位可能要好几百万年。因此要等到溢位这刻发生应该很难吧。那如何经由jiffies_64取得jiffies呢?事实上，jiffies被对应至jiffies_64最低的32位元。因此，经由jiffies_64可以完全不理会溢位的问题便能取得jiffies。



## 数据取自于4.19内核代码中的 include/net/tcp.h

```
//rto的定义，不让修改，到每个ip的rt都不一样，必须通过rtt计算所得, HZ 一般是1秒
#define TCP_RTO_MAX     ((unsigned)(120*HZ))
#define TCP_RTO_MIN     ((unsigned)(HZ/5)) //在rt很小的环境中计算下来RTO基本等于TCP_RTO_MIN

/* Maximal number of ACKs sent quickly to accelerate slow-start. */
#define TCP_MAX_QUICKACKS       16U //默认前16个ack必须quick ack来加速慢启动

//默认delay ack不能超过200ms
#define TCP_DELACK_MAX  ((unsigned)(HZ/5))  /* maximal time to delay before sending an ACK */
#if HZ >= 100
//默认 delay ack 40ms，不能修改和关闭
#define TCP_DELACK_MIN  ((unsigned)(HZ/25))     /* minimal time to delay before sending an ACK */
#define TCP_ATO_MIN     ((unsigned)(HZ/25))
#else
#define TCP_DELACK_MIN  4U
#define TCP_ATO_MIN     4U
#endif

#define TCP_SYNQ_INTERVAL       (HZ/5)  /* Period of SYNACK timer */
#define TCP_KEEPALIVE_TIME      (120*60*HZ)     /* two hours */
#define TCP_KEEPALIVE_PROBES    9               /* Max of 9 keepalive probes    */
#define TCP_KEEPALIVE_INTVL     (75*HZ)

/* cwnd init 默认大小是10个拥塞窗口，也可以通过sysctl_tcp_init_cwnd来设置，要求内核编译的时候支持*/
#if IS_ENABLED(CONFIG_TCP_INIT_CWND_PROC)
extern u32 sysctl_tcp_init_cwnd;
/* TCP_INIT_CWND is rvalue */
#define TCP_INIT_CWND           (sysctl_tcp_init_cwnd + 0)
#else
/* TCP initial congestion window as per rfc6928 */
#define TCP_INIT_CWND           10
#endif

/* Flags in tp->nonagle 默认nagle算法关闭的*/
#define TCP_NAGLE_OFF           1       /* Nagle's algo is disabled */
#define TCP_NAGLE_CORK          2       /* Socket is corked         */
#define TCP_NAGLE_PUSH          4       /* Cork is overridden for already queued data */

#define TCP_TIMEWAIT_LEN (60*HZ) /* how long to wait to destroy TIME-WAIT
                                  * state, about 60 seconds     */
                                  
#define TCP_SYN_RETRIES  6      /* This is how many retries are done
                                 * when active opening a connection.
                                 * RFC1122 says the minimum retry MUST
                                 * be at least 180secs.  Nevertheless
                                 * this value is corresponding to
                                 * 63secs of retransmission with the
                                 * current initial RTO.
                                 */

#define TCP_SYNACK_RETRIES 5    /* This is how may retries are done
                                 * when passive opening a connection.
                                 * This is corresponding to 31secs of
                                 * retransmission with the current
                                 * initial RTO.
                                 */                                  
```

rto不能设置，而是根据到不同server的rtt计算得到，即使RTT很小（比如0.8ms），但是因为RTO有下限，最小必须是200ms，所以这是RTT再小也白搭；RTO最小值是内核编译是决定的，socket程序中无法修改，Linux TCP也没有任何参数可以改变这个值。

### delay ack

正常情况下ack可以quick ack也可以delay ack，redhat在sysctl中可以设置这两个值

> /proc/sys/net/ipv4/tcp_ato_min

默认都是推荐delay ack的，一定要修改成quick ack的话（3.10.0-327之后的内核版本）：

```
$sudo ip route show
default via 10.0.207.253 dev eth0 proto dhcp src 10.0.200.23 metric 1024
10.0.192.0/20 dev eth0 proto kernel scope link src 10.0.200.23
10.0.207.253 dev eth0 proto dhcp scope link src 10.0.200.23 metric 1024

$sudo ip route change default via 10.0.207.253  dev eth0 proto dhcp src 10.0.200.23 metric 1024 quickack 1

$sudo ip route show
default via 10.0.207.253 dev eth0 proto dhcp src 10.0.200.23 metric 1024 quickack 1
10.0.192.0/20 dev eth0 proto kernel scope link src 10.0.200.23
10.0.207.253 dev eth0 proto dhcp scope link src 10.0.200.23 metric 1024
```

默认开启delay ack的抓包情况如下，可以清晰地看到有几个40ms的ack

![image.png](/images/oss/7f4590cccf73fd672268dbf0e6a1b309.png)

第一个40ms 的ack对应的包， 3306收到 update请求后没有ack，而是等了40ms update也没结束，就ack了

![image.png](/images/oss/b06d3148450fc24fa26b2a9cdfe07831.png)

同样的机器，执行quick ack后的抓包

> sudo ip route change default via 10.0.207.253  dev eth0 proto dhcp src 10.0.200.23 metric 1024 quickack 1

![image.png](/images/oss/9fba9819e769494bc09a2a11245e4769.png)

**同样场景下，改成quick ack后基本所有的ack都在0.02ms内发出去了。**

比较奇怪的是在delay ack情况下不是每个空ack都等了40ms，这么多包只看到4个delay了40ms，其它的基本都在1ms内就以空包就行ack了。

将 quick ack去掉后再次抓包仍然抓到了很多的40ms的ack。

Java中setNoDelay是指关掉nagle算法，但是delay ack还是存在的。

C代码中关闭的话：At the application level with the `TCP_QUICKACK` socket option. See `man 7 tcp` for further details. This option needs to be set with `setsockopt()` after each operation of TCP on a given socket

连接刚建立前16个包一定是quick ack的，目的是加快慢启动

一旦后面进入延迟ACK模式后，[如果接收的还没有回复ACK确认的报文总大小超过88bytes的时候就会立即回复ACK报文](https://www.cnblogs.com/lshs/p/6038635.html)。



## 参考资料

https://access.redhat.com/solutions/407743

https://www.cnblogs.com/lshs/p/6038635.html