---
title: ssd/san/sas  磁盘 光纤性能比较
date: 2020-01-25 17:30:03
categories:
    - performance
tags:
    - Linux
    - 磁盘性能
    - san
    - 光纤
---

# ssd/san/sas 磁盘 光纤性能比较

正好有机会用到一个san存储设备，跑了一把性能数据，记录一下

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/d57a004c846e193126ca01398e394319.png)

所使用的测试命令：

```
fio -ioengine=libaio -bs=4k -direct=1 -thread -rw=randwrite -size=1000G -filename=/data/fio.test -name="EBS 4K randwrite test" -iodepth=64 -runtime=60
```

ssd（Solid State Drive）和san的比较是在同一台物理机上，所以排除了其他因素的干扰。

简要的结论：

- 本地ssd性能最好、sas机械盘(RAID10)性能最差

- san存储走特定的光纤网络，不是走tcp的san（至少从网卡看不到san的流量），性能居中

- 从rt来看 ssd:san:sas 大概是 1:3:15

- san比本地sas机械盘性能要好，这也许取决于san的网络传输性能和san存储中的设备（比如用的ssd而不是机械盘）


## NVMe SSD 和 HDD的性能比较

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/d64a0f78ebf471ac69d447ecb46d90f1.png)

表中性能差异比上面测试还要大，SSD 的随机 IO 延迟比传统硬盘快百倍以上，一般在微妙级别；IO 带宽也高很多倍，可以达到每秒几个 GB；随机 IOPS 更是快了上千倍，可以达到几十万。

**HDD只有一个磁头，并发没有意义，但是SSD支持高并发写入读取。SSD没有磁头、不需要旋转，所以随机读取和顺序读取基本没有差别。**

##  SSD 的性能特性和机制

SSD 的内部工作方式和 HDD 大相径庭，我们先了解几个概念。

**单元（Cell）、页面（Page）、块（Block）**。当今的主流 SSD 是基于 NAND 的，它将数字位存储在单元中。每个 SSD 单元可以存储一位或多位。对单元的每次擦除都会降低单元的寿命，所以单元只能承受一定数量的擦除。单元存储的位数越多，制造成本就越少，SSD 的容量也就越大，但是耐久性（擦除次数）也会降低。

一个页面包括很多单元，典型的页面大小是 4KB，页面也是要读写的最小存储单元。SSD 上没有“重写”操作，不像 HDD 可以直接对任何字节重写覆盖。一个页面一旦写入内容后就不能进行部分重写，必须和其它相邻页面一起被整体擦除重置。

多个页面组合成块。一个块的典型大小为 512KB 或 1MB，也就是大约 128 或 256 页。**块是擦除的基本单位，每次擦除都是整个块内的所有页面都被重置。**

**擦除速度相对很慢，通常为几毫秒**。所以对同步的 IO，发出 IO 的应用程序可能会因为块的擦除，而经历很大的写入延迟。为了尽量地减少这样的场景，保持空闲块的阈值对于快速的写响应是很有必要的。SSD 的垃圾回收（GC）的目的就在于此。GC 可以回收用过的块，这样可以确保以后的页写入可以快速分配到一个全新的页。

### 写入放大（Write Amplification, or WA)

这是 SSD 相对于 HDD 的一个缺点，即实际写入 SSD 的物理数据量，有可能是应用层写入数据量的多倍。一方面，页级别的写入需要移动已有的数据来腾空页面。另一方面，GC 的操作也会移动用户数据来进行块级别的擦除。所以对 SSD 真正的写操作的数据可能比实际写的数据量大，这就是写入放大。一块 SSD 只能进行有限的擦除次数，也称为编程 / 擦除（P/E）周期，所以写入放大效用会缩短 SSD 的寿命。

### 耗损平衡 (Wear Leveling) 

对每一个块而言，一旦达到最大数量，该块就会死亡。对于 SLC 块，P/E 周期的典型数目是十万次；对于 MLC 块，P/E 周期的数目是一万；而对于 TLC 块，则可能是几千。为了确保 SSD 的容量和性能，我们需要在擦除次数上保持平衡，SSD 控制器具有这种“耗损平衡”机制可以实现这一目标。在损耗平衡期间，数据在各个块之间移动，以实现均衡的损耗，这种机制也会对前面讲的写入放大推波助澜。

## 光纤和网线的性能差异

以下都是在4.19内核的UOS，光纤交换机为锐捷，服务器是华为鲲鹏920

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/553e1c5fff2dd04a668434f0da4f9d90.png)

光纤稳定性好很多，平均rt是网线的三分之一，最大值则是网线的十分之一. 光纤的带宽大约是网线的1.5倍

```
[aliyun@uos15 11:00 /home/aliyun]  一下88都是光口、89都是电口。
$ping -c 10 10.88.88.16 //光纤
PING 10.88.88.16 (10.88.88.16) 56(84) bytes of data.
64 bytes from 10.88.88.16: icmp_seq=1 ttl=64 time=0.058 ms
64 bytes from 10.88.88.16: icmp_seq=2 ttl=64 time=0.049 ms
64 bytes from 10.88.88.16: icmp_seq=3 ttl=64 time=0.053 ms
64 bytes from 10.88.88.16: icmp_seq=4 ttl=64 time=0.040 ms
64 bytes from 10.88.88.16: icmp_seq=5 ttl=64 time=0.053 ms
64 bytes from 10.88.88.16: icmp_seq=6 ttl=64 time=0.043 ms
64 bytes from 10.88.88.16: icmp_seq=7 ttl=64 time=0.038 ms
64 bytes from 10.88.88.16: icmp_seq=8 ttl=64 time=0.050 ms
64 bytes from 10.88.88.16: icmp_seq=9 ttl=64 time=0.043 ms
64 bytes from 10.88.88.16: icmp_seq=10 ttl=64 time=0.064 ms

--- 10.88.88.16 ping statistics ---
10 packets transmitted, 10 received, 0% packet loss, time 159ms
rtt min/avg/max/mdev = 0.038/0.049/0.064/0.008 ms

[aliyun@uos15 11:01 /home/aliyun]
$ping -c 10 10.88.89.16 //电口
PING 10.88.89.16 (10.88.89.16) 56(84) bytes of data.
64 bytes from 10.88.89.16: icmp_seq=1 ttl=64 time=0.087 ms
64 bytes from 10.88.89.16: icmp_seq=2 ttl=64 time=0.053 ms
64 bytes from 10.88.89.16: icmp_seq=3 ttl=64 time=0.095 ms
64 bytes from 10.88.89.16: icmp_seq=4 ttl=64 time=0.391 ms
64 bytes from 10.88.89.16: icmp_seq=5 ttl=64 time=0.051 ms
64 bytes from 10.88.89.16: icmp_seq=6 ttl=64 time=0.343 ms
64 bytes from 10.88.89.16: icmp_seq=7 ttl=64 time=0.045 ms
64 bytes from 10.88.89.16: icmp_seq=8 ttl=64 time=0.341 ms
64 bytes from 10.88.89.16: icmp_seq=9 ttl=64 time=0.054 ms
64 bytes from 10.88.89.16: icmp_seq=10 ttl=64 time=0.066 ms

--- 10.88.89.16 ping statistics ---
10 packets transmitted, 10 received, 0% packet loss, time 149ms
rtt min/avg/max/mdev = 0.045/0.152/0.391/0.136 ms

[aliyun@uos15 11:02 /u01]
$scp uos.tar aliyun@10.88.89.16:/tmp/
uos.tar                                  100% 3743MB 111.8MB/s   00:33    

[aliyun@uos15 11:03 /u01]
$scp uos.tar aliyun@10.88.88.16:/tmp/
uos.tar                                   100% 3743MB 178.7MB/s   00:20    

[aliyun@uos15 11:07 /u01]
$sudo ping -f 10.88.89.16
PING 10.88.89.16 (10.88.89.16) 56(84) bytes of data.
--- 10.88.89.16 ping statistics ---
284504 packets transmitted, 284504 received, 0% packet loss, time 702ms
rtt min/avg/max/mdev = 0.019/0.040/1.014/0.013 ms, ipg/ewma 0.048/0.042 ms

[aliyun@uos15 11:07 /u01]
$sudo ping -f 10.88.88.16
PING 10.88.88.16 (10.88.88.16) 56(84) bytes of data.
--- 10.88.88.16 ping statistics ---
299748 packets transmitted, 299748 received, 0% packet loss, time 242ms
rtt min/avg/max/mdev = 0.012/0.016/0.406/0.006 ms, pipe 2, ipg/ewma 0.034/0.014 ms
```

光纤接口：

<img src="https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/b67715de1b8e143f6fc17ba574bcf0c4.png" alt="image.png" style="zoom:60%;" />

## Cache、内存、磁盘、网络的延迟比较

[假设主频2.6G的CPU，每个指令只需要 0.38ns](http://cizixs.com/2017/01/03/how-slow-is-disk-and-network) 

每次内存寻址需要 100ns 

一次 CPU 上下文切换（系统调用）需要大约 1500ns，也就是 1.5us（这个数字参考了[这篇文章](http://blog.tsunanet.net/2010/11/how-long-does-it-take-to-make-context.html)，采用的是单核 CPU 线程平均时间）

SSD 随机读取耗时为 150us

从内存中读取 1MB 的连续数据，耗时大约为 250us

同一个数据中心网络上跑一个来回需要 0.5ms

从 SSD 读取 1MB 的顺序数据，大约需要 1ms （是内存速度的四分之一）

磁盘寻址时间为 10ms

从磁盘读取 1MB 连续数据需要 20ms



如果 CPU 访问 L1 缓存需要 1 秒，那么访问主存需要 3 分钟、从 SSD 中随机读取数据需要 3.4 天、磁盘寻道需要 2 个月，网络传输可能需要 1 年多的时间。



**2012 年延迟数字对比表：**

| Work                               | Latency        |
| ---------------------------------- | -------------- |
| L1 cache reference                 | 0.5 ns         |
| Branch mispredict                  | 5 ns           |
| L2 cache reference                 | 7 ns           |
| Mutex lock/unlock                  | 25 ns          |
| Main memory reference              | 100 ns         |
| Compress 1K bytes with Zippy       | 3,000 ns       |
| Send 1K bytes over 1 Gbps network  | 10,000 ns      |
| Read 4K randomly from SSD*         | 150,000 ns     |
| Read 1 MB sequentially from memory | 250,000 ns     |
| Round trip within same datacenter  | 500,000 ns     |
| Read 1 MB sequentially from SSD*   | 1,000,000 ns   |
| Disk seek                          | 10,000,000 ns  |
| Read 1 MB sequentially from disk   | 20,000,000 ns  |
| Send packet CA->Netherlands->CA    | 150,000,000 ns |

## 参考资料

http://cizixs.com/2017/01/03/how-slow-is-disk-and-network