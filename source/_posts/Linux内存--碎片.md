---
title: Linux内存--碎片
date: 2020-11-15 16:30:03
categories: Linux
tags:
    - Linux
    - free
    - buddyinfo
    - 碎片
---

# Linux内存--碎片

## /proc/buddyinfo

/proc/buddyinfo记录了内存的详细碎片情况。

```
#cat /proc/buddyinfo 
Node 0, zone      DMA      1      1      1      0      2      1      1      0      1      1      3 
Node 0, zone    DMA32      2      5      3      6      2      0      4      4      2      2    404 
Node 0, zone   Normal 243430 643847 357451  32531   9508   6159   3917   2960  17172   2633  22854
```

Normal行的第二列表示：  643847\*2^1\*Page_Size(4K) ;  第三列表示：  357451\*2^2\*Page_Size(4K)  ，高阶内存指的是2^3及更大的内存块。

应用申请大块连续内存（高阶内存，一般之4阶及以上, 也就是64K以上--2^4*4K）时，容易导致卡顿。这是因为大块连续内存确实系统需要触发回收或者碎片整理，需要一定的时间。

[The zones are](https://utcc.utoronto.ca/~cks/space/blog/linux/KernelMemoryZones):

- `DMA` is the low 16 MBytes of memory. At this point it exists for historical reasons; once upon what is now a long time ago, there was hardware that could only do DMA into this area of physical memory.
- `DMA32` exists only in 64-bit Linux; it is the low 4 GBytes of memory, more or less. It exists because the transition to large memory 64-bit machines has created a class of hardware that can only do DMA to the low 4 GBytes of memory.(This is where people mutter about everything old being new again.)
- **`Normal`** is different on 32-bit and 64-bit machines. On 64-bit machines, it is all RAM from 4GB or so on upwards. On 32-bit machines it is all RAM from 16 MB to 896 MB for complex and somewhat historical reasons. Note that this implies that machines with a 64-bit kernel can have very small amounts of Normal memory unless they have significantly more than 4GB of RAM. For example, a 2 GB machine running a 64-bit kernel will have no Normal memory at all while a 4 GB machine will have only a tiny amount of it.
- `HighMem` exists only on 32-bit Linux; it is all RAM above 896 MB, including RAM above 4 GB on sufficiently large machines.

cache回收：	

> echo 1/2/3 >/proc/sys/vm/drop_cached

查看回收后：

	cat /proc/meminfo

<img src="https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/7cedcb6daa53cbcfc9c68568086500b7.png" alt="image.png" style="zoom:33%;" />

当我们执行 echo 2 来 drop slab 的时候，它也会把 Page Cache(inode可能会有对应的pagecache，inode释放后对应的pagecache也释放了)给 drop 掉

在系统内存紧张的时候，运维人员或者开发人员会想要通过 drop_caches 的方式来释放一些内存，但是由于他们清楚 Page Cache 被释放掉会影响业务性能，所以就期望只去 drop slab 而不去 drop pagecache。于是很多人这个时候就运行 echo 2 > /proc/sys/vm/drop_caches，但是结果却出乎了他们的意料：Page Cache 也被释放掉了，业务性能产生了明显的下降。

查看 drop_caches 是否执行过释放：

```
$ grep drop /proc/vmstat
drop_pagecache 1
drop_slab 0

 $ grep inodesteal /proc/vmstat 
 pginodesteal 114341
 kswapd_inodesteal 1291853
```

在内存紧张的时候会触发内存回收，内存回收会尝试去回收 reclaimable（可以被回收的）内存，这部分内存既包含 Page Cache 又包含 reclaimable kernel memory(比如 slab)。inode被回收后可以通过  grep inodesteal /proc/vmstat 观察到

> kswapd_inodesteal 是指在 kswapd 回收的过程中，因为回收 inode 而释放的 pagecache page 个数；pginodesteal 是指 kswapd 之外其他线程在回收过程中，因为回收 inode 而释放的 pagecache page 个数;



## 内存分配

内存不够、脏页太多、碎片太多，都会导致分配失败，从而触发回收，导致卡顿。

### 系统中脏页过多引起 load 飙高

直接回收过程中，如果存在较多脏页就可能涉及在回收过程中进行回写，这可能会造成非常大的延迟，而且因为这个过程本身是阻塞式的，所以又可能进一步导致系统中处于 D 状态的进程数增多，最终的表现就是系统的 load 值很高。

<img src="https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/f16438b744a248d7671d5ac7317b0a98.png" alt="image.png" style="zoom: 50%;" />

可以通过 sar -r 来观察系统中的脏页个数：

```
$ sar -r 1
07:30:01 PM kbmemfree kbmemused  %memused kbbuffers  kbcached  kbcommit   %commit  kbactive   kbinact   kbdirty
09:20:01 PM   5681588   2137312     27.34         0   1807432    193016      2.47    534416   1310876         4
09:30:01 PM   5677564   2141336     27.39         0   1807500    204084      2.61    539192   1310884        20
09:40:01 PM   5679516   2139384     27.36         0   1807508    196696      2.52    536528   1310888        20
09:50:01 PM   5679548   2139352     27.36         0   1807516    196624      2.51    536152   1310892        24
```

kbdirty 就是系统中的脏页大小，它同样也是对 /proc/vmstat 中 nr_dirty 的解析。你可以通过调小如下设置来将系统脏页个数控制在一个合理范围:

> vm.dirty_background_bytes = 0
>
> vm.dirty_background_ratio = 10
>
> vm.dirty_bytes = 0
>
> vm.dirty_expire_centisecs = 3000
>
> vm.dirty_ratio = 20

至于这些值调整大多少比较合适，也是因系统和业务的不同而异，我的建议也是一边调整一边观察，将这些值调整到业务可以容忍的程度就可以了，即在调整后需要观察业务的服务质量 (SLA)，要确保 SLA 在可接受范围内。调整的效果你可以通过 /proc/vmstat 来查看：

```
#grep "nr_dirty_" /proc/vmstat
nr_dirty_threshold 3071708
nr_dirty_background_threshold 1023902
```

在4.20的内核并且sar 的版本为12.3.3可以看到PSI（Pressure-Stall Information）

```
some avg10=45.49 avg60=10.23 avg300=5.41 total=76464318
full avg10=40.87 avg60=9.05 avg300=4.29 total=58141082
```

你需要重点关注 avg10 这一列，它表示最近 10s 内存的平均压力情况，如果它很大（比如大于 40）那 load 飙高大概率是由于内存压力，尤其是 Page Cache 的压力引起的。

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/cf58f10a523e1e4f0db443be3f54fc04.png)



## 碎片化

内存碎片严重的话会导致系统hang很久(回收、压缩内存）

尽量让系统的free多一点(比例高一点）可以调整 vm.min_free_kbytes(128G 以内 2G，256G以内 4G/8G), 线上机器直接修改vm.min_free_kbytes**会触发回收，导致系统hang住** https://www.atatech.org/articles/163233 https://www.atatech.org/articles/97130

每个zone都有自己的min low high,如下，但是单位是page, 计算案例：

```
[root@jiangyi01.sqa.zmf /home/ahao.mah]
#cat /proc/zoneinfo  |grep "Node"
Node 0, zone      DMA
Node 0, zone    DMA32
Node 0, zone   Normal
Node 1, zone   Normal

[root@jiangyi01.sqa.zmf /home/ahao.mah]
#cat /proc/zoneinfo  |grep "Node 0, zone" -A10
Node 0, zone      DMA
  pages free     3975
        min      20
        low      25
        high     30
        scanned  0
        spanned  4095
        present  3996
        managed  3975
    nr_free_pages 3975
    nr_alloc_batch 5
--
Node 0, zone    DMA32
  pages free     382873
        min      2335
        low      2918
        high     3502
        scanned  0
        spanned  1044480
        present  513024
        managed  450639
    nr_free_pages 382873
    nr_alloc_batch 584
--
Node 0, zone   Normal
  pages free     11105097
        min      61463
        low      76828
        high     92194
        scanned  0
        spanned  12058624
        present  12058624
        managed  11859912
    nr_free_pages 11105097
    nr_alloc_batch 12344
    
    low = 5/4 * min
high = 3/2 * min

[root@jiangyi01.sqa.zmf /home/ahao.mah]
#T=min;sum=0;for i in `cat /proc/zoneinfo  |grep $T | awk '{print $NF}'`;do sum=`echo "$sum+$i" |bc`;done;sum=`echo "$sum*4/1024" |bc`;echo "sum=${sum} MB"
sum=499 MB

[root@jiangyi01.sqa.zmf /home/ahao.mah]
#T=low;sum=0;for i in `cat /proc/zoneinfo  |grep $T | awk '{print $NF}'`;do sum=`echo "$sum+$i" |bc`;done;sum=`echo "$sum*4/1024" |bc`;echo "sum=${sum} MB"
sum=624 MB

[root@jiangyi01.sqa.zmf /home/ahao.mah]
#T=high;sum=0;for i in `cat /proc/zoneinfo  |grep $T | awk '{print $NF}'`;do sum=`echo "$sum+$i" |bc`;done;sum=`echo "$sum*4/1024" |bc`;echo "sum=${sum} MB"
sum=802 MB
```

## 内存碎片化导致rt升高的诊断

判定方法如下：

1. 运行 sar -B 观察 pgscand/s，其含义为每秒发生的直接内存回收次数，当在一段时间内持续大于 0 时，则应继续执行后续步骤进行排查；
2. 运行 `cat /sys/kernel/debug/extfrag/extfrag_index` 观察内存碎片指数，重点关注 order >= 3 的碎片指数，当接近 1.000 时，表示碎片化严重，当接近 0 时表示内存不足；
3. 运行 `cat /proc/buddyinfo, cat /proc/pagetypeinfo` 查看内存碎片情况， 指标含义参考 （https://man7.org/linux/man-pages/man5/proc.5.html），同样关注 order >= 3 的剩余页面数量，pagetypeinfo 相比 buddyinfo 展示的信息更详细一些，根据迁移类型 （伙伴系统通过迁移类型实现反碎片化）进行分组，需要注意的是，当迁移类型为 Unmovable 的页面都聚集在 order < 3 时，说明内核 slab 碎片化严重，我们需要结合其他工具来排查具体原因，在本文就不做过多介绍了；
4. 对于 CentOS 7.6 等支持 BPF 的 kernel 也可以运行我们研发的 [drsnoop](https://github.com/iovisor/bcc/blob/master/tools/drsnoop_example.txt)，[compactsnoop](https://github.com/iovisor/bcc/blob/master/tools/compactsnoop_example.txt) 工具对延迟进行定量分析，使用方法和解读方式请参考对应文档；
5. (Opt) 使用 ftrace 抓取 mm_page_alloc_extfrag 事件，观察因内存碎片从备用迁移类型“盗取”页面的信息。

## 一个阿里云ECS 因为宿主机碎片导致性能衰退的案例

LVS后面三个RS在同样压力流量下，其中一个节点CPU非常高，通过top看起来是所有操作都很慢，像是CPU被降频了一样，但是直接跑CPU Prime性能又没有问题

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/8bbb5c886dc06196546daec46712ff71.png)

原因：ECS所在的宿主机内存碎片比较严重，导致分配到的内存主要是4K Page，在ECS中大页场景下会慢很多

通过 **openssl speed aes-256-ige 能稳定重现** 在大块的加密上慢很多

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/8e15e91d4dcc61bbd329e7283c7c7500.png)

小块上性能一致，这也就是为什么算Prime性能没问题。导致慢只涉及到大块内存分配的场景，这里需要映射到宿主机，但是碎片多分配慢导致了问题。

如果reboot ECS的话实际只是就地重启ECS，仍然使用的reboot前分配好的宿主机内存，不会解决问题。重启ECS中的进程也不会解决问题，只有将ECS迁移到别的物理机（也就是通过控制台重启，会重新选择物理机）才有可能解决这个问题。

或者购买新的ECS机型（比如第6代之后ECS）能避免这个问题。

ECS内部没法查看到这个碎片，只能在宿主机上通过命令查看大页情况：

```
第二台有问题NC
$cat /proc/buddyinfo
Node 0, zone      DMA      1      1      0      0      2      1      1      0      1      1      3
Node 0, zone    DMA32     23     23     17     15     13      9      8      8      4      3    367
Node 0, zone   Normal 295291 298652 286048 266597 218191 156837  93156  45930  25856      0      0

最新建的vm，大页不多
$sudo cat /proc/9550/smaps |grep AnonHuge |awk '{sum+=$2}END{print sum}'
210944
------------------------
第一台正常ECS所在的NC
$cat /proc/buddyinfo
Node 0, zone      DMA      1      1      0      0      2      1      1      0      1      1      3
Node 0, zone    DMA32      7      5      5      9      8      4      6     10      5      5    366
Node 0, zone   Normal 203242 217888 184465 176280 148612 102122  55787  26642  24824      0      0

早期的vm，大页充足
$sudo cat /proc/87369/smaps |grep AnonHuge |awk '{sum+=$2}END{print sum}'
8275968

近期的vm，大页不够
$sudo cat /proc/22081/smaps |grep AnonHuge |awk '{sum+=$2}END{print sum}'
251904

$sudo cat /proc/44073/smaps |grep AnonHuge |awk '{sum+=$2}END{print sum}'
10240
```

## 内存使用分析

### pmap

```
pmap -x 24282 | less
24282:   /usr/sbin/rsyslogd -n
Address           Kbytes     RSS   Dirty Mode  Mapping
000055ce1a99f000     596     580       0 r-x-- rsyslogd
000055ce1ac34000      12      12      12 r---- rsyslogd
000055ce1ac37000      28      28      28 rw--- rsyslogd
000055ce1ac3e000       4       4       4 rw---   [ anon ]
000055ce1c1f1000     364     204     204 rw---   [ anon ]
00007fff8b5a4000     132      20      20 rw---   [ stack ]
00007fff8b5e6000      12       0       0 r----   [ anon ]
00007fff8b5e9000       8       4       0 r-x--   [ anon ]
---------------- ------- ------- -------
total kB          620060   17252    3304
```

- Address：占用内存的文件的内存起始地址。
- Kbytes：占用内存的字节数。
- RSS：实际占用内存大小。
- Dirty：脏页大小。
- Mapping：占用内存的文件，[anon] 为已分配的内存，[stack] 为程序堆栈

### /proc/pid/

`/proc/[pid]/` 下面与进程内存相关的文件主要有`maps , smaps, status`。
maps： 文件可以查看某个进程的代码段、栈区、堆区、动态库、内核区对应的虚拟地址
smaps: 显示每个分区更详细的内存占用数据
status: 包含了所有CPU活跃的信息，该文件中的所有值都是从系统启动开始累计到当前时刻

## 参考资料

https://www.atatech.org/articles/66885

https://cloud.tencent.com/developer/article/1087455

https://www.cnblogs.com/xiaolincoding/p/13719610.html

[rsyslog占用内存高](https://blog.csdn.net/fanren224/article/details/103991748)

https://sunsea.im/rsyslogd-systemd-journald-high-memory-solution.html

[鸟哥 journald 介绍](https://wizardforcel.gitbooks.io/vbird-linux-basic-4e/content/160.html)

