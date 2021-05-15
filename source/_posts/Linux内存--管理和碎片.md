---
title: Linux内存--管理和碎片
date: 2020-11-15 16:30:03
categories: Linux
tags:
    - Linux
    - free
    - buddyinfo
    - 碎片
---

# Linux内存--管理和碎片

node->zone->buddy->slab



## 内存管理和使用

### node、zone、buddy、slab

![img](/images/oss/debfe12e-d1b9-49cd-988d-3f7fcba6ecd2.png)



### 查看zone

[The zones are](https://utcc.utoronto.ca/~cks/space/blog/linux/KernelMemoryZones):

- `DMA` is the low 16 MBytes of memory. At this point it exists for historical reasons; once upon what is now a long time ago, there was hardware that could only do DMA into this area of physical memory.
- `DMA32` exists only in 64-bit Linux; it is the low 4 GBytes of memory, more or less. It exists because the transition to large memory 64-bit machines has created a class of hardware that can only do DMA to the low 4 GBytes of memory.(This is where people mutter about everything old being new again.)
- **`Normal`** is different on 32-bit and 64-bit machines. On 64-bit machines, it is all RAM from 4GB or so on upwards. On 32-bit machines it is all RAM from 16 MB to 896 MB for complex and somewhat historical reasons. Note that this implies that machines with a 64-bit kernel can have very small amounts of Normal memory unless they have significantly more than 4GB of RAM. For example, a 2 GB machine running a 64-bit kernel will have no Normal memory at all while a 4 GB machine will have only a tiny amount of it.
- `HighMem` exists only on 32-bit Linux; it is all RAM above 896 MB, including RAM above 4 GB on sufficiently large machines.

每个zone下很多pages(大小为4K)，buddy就是这些Pages的组织管理者

```
# cat /proc/zoneinfo |grep Node -A10
Node 0, zone      DMA
  pages free     3972
        min      0
        low      0
        high     0
        scanned  0
        spanned  4095
        present  3993
        managed  3972
    nr_free_pages 3972
    nr_alloc_batch 0
--
Node 0, zone    DMA32
  pages free     361132
        min      30
        low      37
        high     45
        scanned  0
        spanned  1044480
        present  430773
        managed  361133
    nr_free_pages 361132
    nr_alloc_batch 8
--
Node 0, zone   Normal
  pages free     96017308
        min      16864
        low      21080
        high     25296
        scanned  0
        spanned  200736768
        present  200736768
        managed  197571780
    nr_free_pages 96017308
    nr_alloc_batch 3807
    
# free -g
              total        used        free      shared  buff/cache   available
Mem:            755         150         367           3         236         589
Swap:             0           0           0    
```

每个页面大小是4K，很容易可以计算出每个 zone 的大小。比如对于上面 Node0 的 Normal， 197571780 * 4K/(1024*1024) = 753 GB。

dmidecode 可以查看到服务器上插着的所有内存条，也可以看到它是和哪个CPU直接连接的。每一个CPU以及和他直连的内存条组成了一个 **node（节点）**

### /proc/buddyinfo

/proc/buddyinfo记录了可用内存的情况。

```
#cat /proc/buddyinfo 
Node 0, zone      DMA      1      1      1      0      2      1      1      0      1      1      3 
Node 0, zone    DMA32      2      5      3      6      2      0      4      4      2      2    404 
Node 0, zone   Normal 243430 643847 357451  32531   9508   6159   3917   2960  17172   2633  22854
```

Normal那行之后的第二列表示：  643847\*2^1\*Page_Size(4K) ;  第三列表示：  357451\*2^2\*Page_Size(4K)  ，高阶内存指的是2^3及更大的内存块。

应用申请大块连续内存（高阶内存，一般之4阶及以上, 也就是64K以上--2^4*4K）时，容易导致卡顿。这是因为大块连续内存确实系统需要触发回收或者碎片整理，需要一定的时间。

### /proc/pagetypeinfo

`cat /proc/pagetypeinfo`, 你可以看到当前系统里伙伴系统里各个尺寸的可用连续内存块数量。

![img](/images/oss/2e73247c-8a10-43e6-bb0e-49ecfff14268.png)

**当迁移类型为 Unmovable 的页面都聚集在 order < 3 时，说明内核 slab 碎片化严重**

alloc_pages分配内存的时候就到上面对应大小的free_area的链表上寻找可用连续页面。`alloc_pages`是怎么工作的呢？我们举个简单的小例子。假如要申请8K-连续两个页框的内存。为了描述方便，我们先暂时忽略UNMOVEABLE、RELCLAIMABLE等不同类型

![img](/images/oss/16ebe996-0e3a-4d67-810f-3121b457271e.png)

基于伙伴系统的内存分配中，有可能需要将大块内存拆分成两个小伙伴。在释放中，可能会将两个小伙伴合并再次组成更大块的连续内存。

> 伙伴系统中的伙伴指的是两个内存块，大小相同，地址连续，同属于一个大块区域。

对于应用来说基本分配单位是4K(开启大页后一般是2M)，对于内核来说4K有点浪费。所以内核又专门给自己定制了一个更精细的内存管理系统slab。

### slab

对于内核运行中实际使用的对象来说，多大的对象都有。有的对象有1K多，但有的对象只有几百、甚至几十个字节。如果都直接分配一个 4K的页面 来存储的话也太浪费了，所以伙伴系统并不能直接使用。

在伙伴系统之上，**内核又给自己搞了一个专用的内存分配器， 叫slab**。

这个分配器最大的特点就是，一个slab内只分配特定大小、甚至是特定的对象。这样当一个对象释放内存后，另一个同类对象可以直接使用这块内存。通过这种办法极大地降低了碎片发生的几率。



通过查看 `/proc/slabinfo` 我们可以查看到所有的 kmem cache。

![img](/images/oss/5135d81f-6985-4d6a-8896-e451c0ba20f5.png)

slabtop 按占用内存从大往小进行排列。用来分析 slab 内存开销。

![0d8a26db-3663-40af-b215-f8601ef23676.png (1388×1506)](/images/oss/0d8a26db-3663-40af-b215-f8601ef23676.png)

无论是 `/proc/slabinfo`，还是 slabtop 命令的输出。里面都包含了每个 cache 中 slab的如下几个关键属性。

- objsize：每个对象的大小
- objperslab：一个 slab 里存放的对象的数量

- pagesperslab：一个slab 占用的页面的数量，每个页面4K，这样也就能算出每个 slab 占用的内存大小。

比如如下TCP slabinfo中可以看到每个slab占用8(pagesperslab)个Page(8*4096=32768)，每个对象的大小是1984(objsize)，每个slab存放了16(objperslab)个对象. 那么1984 *16=31744，现在的空间基本用完，剩下接近1K，又放不下一个1984大小的对象，算是额外开销了。

```
#cat /proc/slabinfo |grep -E "active_objs|TCP"
# name            <active_objs> <num_objs> <objsize> <objperslab> <pagesperslab> : tunables <limit> <batchcount> <sharedfactor> : slabdata <active_slabs> <num_slabs> <sharedavail>
tw_sock_TCP         5372   5728    256   32    2 : tunables    0    0    0 : slabdata    179    179      0
TCP                 6090   6144   1984   16    8 : tunables    0    0    0 : slabdata    384    384      0
```

### tlab miss

TLB(Translation Lookaside Buffer) Cache用于缓存少量热点内存地址的mapping关系。然而由于制造成本和工艺的限制，响应时间需要控制在CPU Cycle级别的Cache容量只能存储几十个对象。那么TLB Cache在应对大量热点数据`Virual Address`转换的时候就显得捉襟见肘了。我们来算下按照标准的Linux页大小(page size) 4K，一个能缓存64元素的TLB Cache只能涵盖`4K*64 = 256K`的热点数据的内存地址，显然离理想非常遥远的。于是Huge Page就产生了。

![img](/images/951413iMgBlog/tlb_lookup.png)

以intel x86为例，一个cpu也就32到64个tlb, 超出这个范畴，就得去查页表。 每个型号的cpu都不一样，需要查看[spec](https://en.wikichip.org/wiki/WikiChip)

进程分配到的不是内存的实际物理地址，而是一个经过映射后的虚拟地址，这么做的原因是为了用更少的内存消耗来管理庞大的内存，Linux通过四级表项来做虚拟地址到物理地址的映射，这样4Kb就能管理256T内存。

[虚拟内存的核心原理](https://mp.weixin.qq.com/s/dZNjq05q9jMFYhJrjae_LA)是：为每个程序设置一段"连续"的虚拟地址空间，把这个地址空间分割成多个具有连续地址范围的页 (page)，并把这些页和物理内存做映射，在程序运行期间动态映射到物理内存。当程序引用到一段在物理内存的地址空间时，由硬件立刻执行必要的映射；而当程序引用到一段不在物理内存中的地址空间时，由操作系统负责将缺失的部分装入物理内存并重新执行失败的指令：

![img](/images/951413iMgBlog/1610941678194-bb42451f-b59a-475d-9b8d-b1085c18766d.png)

在 **内存管理单元（Memory Management Unit，MMU）**进行地址转换时，如果页表项的 "在/不在" 位是 0，则表示该页面并没有映射到真实的物理页框，则会引发一个**缺页中断**，CPU 陷入操作系统内核，接着操作系统就会通过页面置换算法选择一个页面将其换出 (swap)，以便为即将调入的新页面腾出位置，如果要换出的页面的页表项里的修改位已经被设置过，也就是被更新过，则这是一个脏页 (dirty page)，需要写回磁盘更新改页面在磁盘上的副本，如果该页面是"干净"的，也就是没有被修改过，则直接用调入的新页面覆盖掉被换出的旧页面即可。

还需要了解的一个概念是**转换检测缓冲器（Translation Lookaside Buffer，TLB）**，也叫快表，是用来加速虚拟地址映射的，因为虚拟内存的分页机制，页表一般是保存内存中的一块固定的存储区，导致进程通过 MMU 访问内存比直接访问内存多了一次内存访问，性能至少下降一半，因此需要引入加速机制，即 TLB 快表，TLB 可以简单地理解成页表的高速缓存，保存了最高频被访问的页表项，由于一般是硬件实现的，因此速度极快，MMU 收到虚拟地址时一般会先通过硬件 TLB 查询对应的页表号，若命中且该页表项的访问操作合法，则直接从 TLB 取出对应的物理页框号返回，若不命中则穿透到内存页表里查询，并且会用这个从内存页表里查询到最新页表项替换到现有 TLB 里的其中一个，以备下次缓存命中。

如果没有TLB那么每一次内存映射都需要查表四次然后才是一次真正的内存访问，代价比较高。

有了TLB之后，CPU访问某个虚拟内存地址的过程如下

- 1.CPU产生一个虚拟地址
- 2.MMU从TLB中获取页表，翻译成物理地址
- 3.MMU把物理地址发送给L1/L2/L3/内存
- 4.L1/L2/L3/内存将地址对应数据返回给CPU

由于第2步是类似于寄存器的访问速度，所以**如果TLB能命中，则虚拟地址到物理地址的时间开销几乎可以忽**略。tlab miss比较高的话开启内存大页对性能是有提升的，但是会有一定的内存浪费。

## cache回收	

> echo 1/2/3 >/proc/sys/vm/drop_cached

查看回收后：

	cat /proc/meminfo

<img src="/images/oss/7cedcb6daa53cbcfc9c68568086500b7.png" alt="image.png" style="zoom:33%;" />

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



## 内存分配和延迟

内存不够、脏页太多、碎片太多，都会导致分配失败，从而触发回收，导致卡顿。

### 系统中脏页过多引起 load 飙高

直接回收过程中，如果存在较多脏页就可能涉及在回收过程中进行回写，这可能会造成非常大的延迟，而且因为这个过程本身是阻塞式的，所以又可能进一步导致系统中处于 D 状态的进程数增多，最终的表现就是系统的 load 值很高。

<img src="/images/oss/f16438b744a248d7671d5ac7317b0a98.png" alt="image.png" style="zoom: 50%;" />

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

![image.png](/images/oss/cf58f10a523e1e4f0db443be3f54fc04.png)



## 碎片化

内存碎片严重的话会导致系统hang很久(回收、压缩内存）

尽量让系统的free多一点(比例高一点）可以调整 vm.min_free_kbytes(128G 以内 2G，256G以内 4G/8G), 线上机器直接修改vm.min_free_kbytes**会触发回收，导致系统hang住** https://www.atatech.org/articles/163233 https://www.atatech.org/articles/97130

每个zone都有自己的min low high,如下，但是单位是page, 计算案例：

```
#cat /proc/zoneinfo  |grep "Node"
Node 0, zone      DMA
Node 0, zone    DMA32
Node 0, zone   Normal
Node 1, zone   Normal

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


#T=min;sum=0;for i in `cat /proc/zoneinfo  |grep $T | awk '{print $NF}'`;do sum=`echo "$sum+$i" |bc`;done;sum=`echo "$sum*4/1024" |bc`;echo "sum=${sum} MB"
sum=499 MB

#T=low;sum=0;for i in `cat /proc/zoneinfo  |grep $T | awk '{print $NF}'`;do sum=`echo "$sum+$i" |bc`;done;sum=`echo "$sum*4/1024" |bc`;echo "sum=${sum} MB"
sum=624 MB

#T=high;sum=0;for i in `cat /proc/zoneinfo  |grep $T | awk '{print $NF}'`;do sum=`echo "$sum+$i" |bc`;done;sum=`echo "$sum*4/1024" |bc`;echo "sum=${sum} MB"
sum=802 MB
```

## 内存碎片化导致rt升高的诊断

判定方法如下：

1. 运行 sar -B 观察 pgscand/s，其含义为每秒发生的直接内存回收次数，当在一段时间内持续大于 0 时，则应继续执行后续步骤进行排查；
2. 运行 `cat /sys/kernel/debug/extfrag/extfrag_index` 观察内存碎片指数，重点关注 order >= 3 的碎片指数，当接近 1.000 时，表示碎片化严重，当接近 0 时表示内存不足；
3. 运行 `cat /proc/buddyinfo, cat /proc/pagetypeinfo` 查看内存碎片情况， 指标含义[参考](https://man7.org/linux/man-pages/man5/proc.5.html) ，同样关注 order >= 3 的剩余页面数量，pagetypeinfo 相比 buddyinfo 展示的信息更详细一些，根据迁移类型 （伙伴系统通过迁移类型实现反碎片化）进行分组，需要注意的是，**当迁移类型为 Unmovable 的页面都聚集在 order < 3 时，说明内核 slab 碎片化严重**，我们需要结合其他工具来排查具体原因，在本文就不做过多介绍了；
4. 对于 CentOS 7.6 等支持 BPF 的 kernel 也可以运行我们研发的 [drsnoop](https://github.com/iovisor/bcc/blob/master/tools/drsnoop_example.txt)，[compactsnoop](https://github.com/iovisor/bcc/blob/master/tools/compactsnoop_example.txt) 工具对延迟进行定量分析，使用方法和解读方式请参考对应文档；
5. (Opt) 使用 ftrace 抓取 mm_page_alloc_extfrag 事件，观察因内存碎片从备用迁移类型“盗取”页面的信息。

## 一个阿里云ECS 因为宿主机碎片导致性能衰退的案例

LVS后面三个RS在同样压力流量下，其中一个节点CPU非常高，通过top看起来是所有操作都很慢，像是CPU被降频了一样，但是直接跑CPU Prime性能又没有问题

![image.png](/images/oss/8bbb5c886dc06196546daec46712ff71.png)

原因：ECS所在的宿主机内存碎片比较严重，导致分配到的内存主要是4K Page，在ECS中大页场景下会慢很多

通过 **openssl speed aes-256-ige 能稳定重现** 在大块的加密上慢很多

![image.png](/images/oss/8e15e91d4dcc61bbd329e7283c7c7500.png)

小块上性能一致，这也就是为什么算Prime性能没问题。导致慢只涉及到大块内存分配的场景，这里需要映射到宿主机，但是碎片多分配慢导致了问题。

如果reboot ECS的话实际只是就地重启ECS，仍然使用的reboot前分配好的宿主机内存，不会解决问题。重启ECS中的进程也不会解决问题，只有将ECS迁移到别的物理机（也就是通过控制台重启，会重新选择物理机）才有可能解决这个问题。

或者购买新的ECS机型（比如第6代之后ECS）能避免这个问题。

ECS内部没法查看到这个碎片，只能在宿主机上通过命令查看大页情况：

```
有问题NC上buddyinfo信息
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

[说出来你可能不信，内核这家伙在内存的使用上给自己开了个小灶！](https://mp.weixin.qq.com/s/OR2XB4J76haGc1THeq7WQg)