---
title: Linux内存--HugePage
date: 2020-11-15 16:30:03
categories: Memory
tags:
    - Linux
    - free
    - Memory
    - HugePage
---

# Linux内存--HugePage

本系列有如下几篇

[Linux 内存问题汇总](/2020/01/15/Linux 内存问题汇总/)

[Linux内存--PageCache](/2020/11/15/Linux内存--pagecache/)

[Linux内存--管理和碎片](/2020/11/15/Linux内存--管理和碎片/)

[Linux内存--HugePage](/2020/11/15/Linux内存--HugePage/)

[Linux内存--零拷贝](/2020/11/15/Linux内存--零拷贝/)



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

## slabtop和/proc/slabinfo

slabtop和/proc/slabinfo 查看cached使用情况 主要是：pagecache（页面缓存）， dentries（目录缓存）， inodes

## 关于hugetlb

This is an entry in the TLB that points to a HugePage (a large/big page larger than regular 4K and predefined in size). HugePages are implemented via hugetlb entries, i.e. we can say that a HugePage is handled by a "hugetlb page entry". The 'hugetlb" term is also (and mostly) used synonymously with a HugePage.

 hugetlb 是TLB中指向HugePage的一个entry(通常大于4k或预定义页面大小)。 HugePage 通过hugetlb entries来实现，也可以理解为HugePage 是hugetlb page entry的一个句柄。

**Linux下的大页分为两种类型：标准大页（Huge Pages）和透明大页（Transparent Huge Pages）**

标准大页管理是预分配的方式，而透明大页管理则是动态分配的方式

目前透明大页与传统HugePages联用会出现一些问题，导致性能问题和系统重启。Oracle 建议禁用透明大页（Transparent Huge Pages）

hugetlbfs比THP要好，开thp的机器碎片化严重（不开THP会有更严重的碎片化问题），最后和没开THP一样 https://www.atatech.org/articles/152660

Linux 中的 HugePages 都被锁定在内存中，所以哪怕是在系统内存不足时，它们也不会被 Swap 到磁盘上，这也就能从根源上杜绝了重要内存被频繁换入和换出的可能。

> **Transparent Hugepages** are similar to standard **HugePages**. However, while standard **HugePages** allocate memory at startup, **Transparent Hugepages** memory uses the khugepaged thread in the kernel to allocate memory dynamically during runtime, using swappable **HugePages**.

HugePage要求OS启动的时候提前分配出来，管理难度比较大，所以Enterprise Linux 6增加了一层抽象层来动态创建管理HugePage，这就是THP，而这个THP对应用透明，由khugepaged thread在后台动态将小页组成大页给应用使用，这里会遇上碎片问题导致需要compact才能得到大页，应用感知到的就是SYS CPU飙高，应用卡顿了。

虽然 HugePages 的开启大都需要开发或者运维工程师的额外配置，但是在应用程序中启用 HugePages 却可以在以下几个方面降低内存页面的管理开销：

- 更大的内存页能够减少内存中的页表层级，这不仅可以降低页表的内存占用，也能降低从虚拟内存到物理内存转换的性能损耗；
- 更大的内存页意味着更高的缓存命中率，CPU 有更高的几率可以直接在 TLB（Translation lookaside buffer）中获取对应的物理地址；
- 更大的内存页可以减少获取大内存的次数，使用 HugePages 每次可以获取 2MB 的内存，是 4KB 的默认页效率的 512 倍；

## HugePage

**为什么需要Huge Page** 了解CPU Cache大致架构的话，一定听过TLB Cache。`Linux`系统中，对程序可见的，可使用的内存地址是`Virtual Address`。每个程序的内存地址都是从0开始的。而实际的数据访问是要通过`Physical Address`进行的。因此，每次内存操作，CPU都需要从`page table`中把`Virtual Address`翻译成对应的`Physical Address`，那么对于大量内存密集型程序来说`page table`的查找就会成为程序的瓶颈。

所以现代CPU中就出现了TLB(Translation Lookaside Buffer) Cache用于缓存少量热点内存地址的mapping关系。然而由于制造成本和工艺的限制，响应时间需要控制在CPU Cycle级别的Cache容量只能存储几十个对象。那么TLB Cache在应对大量热点数据`Virual Address`转换的时候就显得捉襟见肘了。我们来算下按照标准的Linux页大小(page size) 4K，一个能缓存64元素的TLB Cache只能涵盖`4K*64 = 256K`的热点数据的内存地址，显然离理想非常遥远的。于是Huge Page就产生了。

Huge pages require contiguous areas of memory, so allocating them at boot is the most reliable method since memory has not yet become fragmented. To do so, add the following parameters to the kernel boot command line:

**Huge pages kernel options**

- hugepages

  Defines the number of persistent huge pages configured in the kernel at boot time. The default value is `0`. It is only possible to allocate (or deallocate) huge pages if there are sufficient physically contiguous free pages in the system. Pages reserved by this parameter cannot be used for other purposes.

  Default size huge pages can be dynamically allocated or deallocated by changing the value of the `/proc/sys/vm/nr_hugepages` file.

  In a NUMA system, huge pages assigned with this parameter are divided equally between nodes. You can assign huge pages to specific nodes at runtime by changing the value of the node's `/sys/devices/system/node/node_id/hugepages/hugepages-1048576kB/nr_hugepages` file.

  For more information, read the relevant kernel documentation, which is installed in `/usr/share/doc/kernel-doc-kernel_version/Documentation/vm/hugetlbpage.txt` by default. This documentation is available only if the *kernel-doc* package is installed.

- hugepagesz

  Defines the size of persistent huge pages configured in the kernel at boot time. Valid values are 2 MB and 1 GB. The default value is 2 MB.

- default_hugepagesz

  Defines the default size of persistent huge pages configured in the kernel at boot time. Valid values are 2 MB and 1 GB. The default value is 2 MB.



应用程序想要利用大页优势，需要通过hugetlb文件系统来使用标准大页。[操作步骤](https://ata.alibaba-inc.com/articles/208718)

#### 1.预留大页

echo 20 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

#### 2.挂载hugetlb文件系统

mount hugetlbfs /mnt/huge -t hugetlbfs

#### 3.映射hugetbl文件

fd = open("/mnt/huge/test.txt", O_CREAT|O_RDWR);

addr = mmap(0, MAP_LENGTH, PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);

#### 4.hugepage统计信息

通过hugepage提供的sysfs接口，可以了解大页使用情况

HugePages_Total: 预先分配的大页数量

HugePages_Free：空闲大页数量

HugePages_Rsvd: mmap申请大页数量(还没有产生缺页)

HugePages_Surp: 多分配的大页数量(由nr_overcommit_hugepages决定)

#### 5 hugpage优缺点

缺点:

1.需要提前预估大页使用量，并且预留的大页不能被其他内存分配接口使用。

2.兼容性不好，应用使用标准大页，需要对代码进行重构才能有效的使用标准大页。

优点:因为内存是预留的，缺页延时非常小

针对Hugepage的不足，内核又衍生出了THP大页(**Transparent Huge pages)**

### [工具](https://www.golinuxcloud.com/configure-hugepages-vm-nr-hugepages-red-hat-7/)

```
yum install libhugetlbfs-utils -y

//列出
hugeadm --pool-list
      Size  Minimum  Current  Maximum  Default
   2097152    12850    12850    12850        *
1073741824        0        0        0

hugeadm --list-all-mounts
Mount Point          Options
/dev/hugepages       rw,relatime,pagesize=2M
```

### 大页和 MySQL 性能 case

MySQL的页都是16K, 当查询的行不在内存中时需要按照16K为单位从磁盘读取页,而文件系统中的页是4k，也就是一次数据库请求需要有4次磁盘IO，如过查询比较随机，每次只需要一个页中的几行数据，存在很大的读放大。

那么我们是否可以把MySQL的页设置为4K来减少读放大呢？

在5.7里收益不大，因为每次IO存在 fil_system 的锁，导致IO的并发上不去

8.0中总算优化了这个场景，测试细节可以参考[这篇](http://dimitrik.free.fr/blog/archives/2018/05/mysql-performance-1m-iobound-qps-with-80-ga-on-intel-optane-ssd.html)

16K VS 4K 性能对比（4K接近翻倍）

![img](/images/951413iMgBlog/1547605552845-d406952d-9857-462d-a666-1694b19fbedb.png)

4K会带来的问题：顺序insert慢了10%（因为fsync更多了）；DDL更慢；二级索引更多的场景下4K性能较差；大BP下，刷脏代价大。



### [HugePage 带来的问题](http://cenalulu.github.io/linux/huge-page-on-numa/)

#### CPU对同一个Page抢占增多

对于写操作密集型的应用，Huge Page会大大增加Cache写冲突的发生概率。由于CPU独立Cache部分的写一致性用的是`MESI协议`，写冲突就意味：

- 通过CPU间的总线进行通讯，造成总线繁忙
- 同时也降低了CPU执行效率。
- CPU本地Cache频繁失效

类比到数据库就相当于，原来一把用来保护10行数据的锁，现在用来锁1000行数据了。必然这把锁在线程之间的争抢概率要大大增加。

#### 连续数据需要跨CPU读取

Page太大，更容易造成Page跨Numa/CPU 分布。

从下图我们可以看到，原本在4K小页上可以连续分配，并因为较高命中率而在同一个CPU上实现locality的数据。到了Huge Page的情况下，就有一部分数据为了填充统一程序中上次内存分配留下的空间，而被迫分布在了两个页上。而在所在Huge Page中占比较小的那部分数据，由于在计算CPU亲和力的时候权重小，自然就被附着到了其他CPU上。那么就会造成：本该以热点形式存在于CPU2 L1或者L2 Cache上的数据，不得不通过CPU inter-connect去remote CPU获取数据。 假设我们连续申明两个数组，`Array A`和`Array B`大小都是1536K。内存分配时由于第一个Page的2M没有用满，因此`Array B`就被拆成了两份，分割在了两个Page里。而由于内存的亲和配置，一个分配在Zone 0，而另一个在Zone 1。那么当某个线程需要访问Array B时就不得不通过代价较大的Inter-Connect去获取另外一部分数据。

![img](/images/951413iMgBlog/false_sharing.png)

### Java进程开启HugePage

从perf数据来看压满后tlab miss比较高，得想办法降低这个值

#### 修改JVM启动参数

JVM启动参数增加如下三个(-XX:LargePageSizeInBytes=2m, 这个一定要，有些资料没提这个，在我的JDK8.0环境必须要)：

> -XX:+UseLargePages -XX:LargePageSizeInBytes=2m -XX:+UseHugeTLBFS

#### 修改机器系统配置

设置HugePage的大小

> cat /proc/sys/vm/nr_hugepages

nr_hugepages设置多大参考如下计算方法：

> If you are using the option `-XX:+UseSHM` or `-XX:+UseHugeTLBFS`, then specify the number of large pages. In the following example, 3 GB of a 4 GB system are reserved for large pages (assuming a large page size of 2048kB, then 3 GB = 3 * 1024 MB = 3072 MB = 3072 * 1024 kB = 3145728 kB and 3145728 kB / 2048 kB = 1536):
>
> echo 1536 > /proc/sys/vm/nr_hugepages 

透明大页是没有办法减少系统tlab，tlab是对应于进程的，系统分给进程的透明大页还是由物理上的4K page组成。



对于c++来说，他malloc经常会散落得全地址都是，因为会触发各种mmap，冷热区域。所以THP和hugepage都可能导致大量内存被浪费了，进而导致内存紧张，性能下滑。jvm的连续内存布局，加上gc会使得内存密度很紧凑。THP的问题是，他是逻辑页，不是物理页，tlb依旧要N份，所以他的收益来自page fault减少，是一次性的收益。

hugepage的在减少page_fault上和thp效果一样第二个作用是，他只需要一份TLB了，hugepage是真正的大页内存，thp是逻辑上的，物理上还是需要很多小的page。

**如果TLB miss，则可能需要额外三次内存读取操作才能将线性地址翻译为物理地址。**

## THP

Linux kernel在2.6.38内核增加了Transparent Huge Pages (THP)特性 ，支持大内存页(2MB)分配，默认开启。当开启时可以降低fork子进程的速度，但fork之后，每个内存页从原来4KB变为2MB，会大幅增加重写期间父进程内存消耗。同时**每次写命令引起的复制内存页单位放大了512倍**，会拖慢写操作的执行时间，导致大量写操作慢查询。例如简单的incr命令也会出现在慢查询中。因此Redis日志中建议将此特性进行禁用。  

THP 的目的是用一个页表项来映射更大的内存（大页），这样可以减少 Page Fault，因为需要的页数少了。当然，这也会提升 TLB（Translation Lookaside Buffer，由存储器管理单元用于改进虚拟地址到物理地址的转译速度） 命中率，因为需要的页表项也少了。如果进程要访问的数据都在这个大页中，那么这个大页就会很热，会被缓存在 Cache 中。而大页对应的页表项也会出现在 TLB 中，从上一讲的存储层次我们可以知道，这有助于性能提升。但是反过来，假设应用程序的数据局部性比较差，它在短时间内要访问的数据很随机地位于不同的大页上，那么大页的优势就会消失。

#### THP 原理

大页分配: 在缺页处理函数__handle_mm_fault中判断是否使用大页 大页生成: 主要通过在分配大页内存时是否带__GFP_DIRECT_RECLAIM 标志来控制大页的生成.

1.异步生成大页: 在缺页处理中，把需要异步生成大页的VMA注册到链表，内核态线程k**hugepage**d 动态为vma分配大页(内存回收，内存归整)

2.madvise系统调用只是给VMA加了VM_**HUGEPAGE,用来**标记这段虚拟地址需要使用大页



THP 对redis、mongodb 这种cache类推荐关闭，对drds这种java应用最好打开

```
#cat /sys/kernel/mm/transparent_hugepage/enabled
[always] madvise never

grep "Huge" /proc/meminfo
AnonHugePages:   1286144 kB
ShmemHugePages:        0 kB
HugePages_Total:       0
HugePages_Free:        0
HugePages_Rsvd:        0
HugePages_Surp:        0
Hugepagesize:       2048 kB
Hugetlb:               0 kB

$grep -e AnonHugePages  /proc/*/smaps | awk  '{ if($2>4) print $0} ' |  awk -F "/"  '{print $0; system("ps -fp " $3)} '

$grep -e AnonHugePages  /proc/*/smaps | awk  '{ if($2>4) print $0} ' |  awk -F "/"  '{print $0; system("ps -fp " $3)} '

//查看pagesize（默认4K） 
$getconf PAGESIZE
```

在透明大页功能打开时，造成系统性能下降的主要原因可能是 `khugepaged` 守护进程。该进程会在（它认为）系统空闲时启动，扫描系统中剩余的空闲内存，并将普通 4k 页转换为大页。该操作会在内存路径中加锁，而该守护进程可能会在错误的时间启动扫描和转换大页的操作，从而影响应用性能。

此外，当缺页异常(page faults)增多时，透明大页会和普通 4k 页一样，产生同步内存压缩(direct compaction)操作，以节省内存。该操作是一个同步的内存整理操作，如果应用程序会短时间分配大量内存，内存压缩操作很可能会被触发，从而会对系统性能造成风险。https://yq.aliyun.com/articles/712830

```
#查看系统级别的 THP 使用情况，执行下列命令：
cat /proc/meminfo  | grep AnonHugePages
#类似地，查看进程级别的 THP 使用情况，执行下列命令：
cat /proc/1730/smaps | grep AnonHugePages |grep -v "0 kB"
#是否开启了hugepage
$cat /sys/kernel/mm/transparent_hugepage/enabled
always [madvise] never
```

`/proc/sys/vm/nr_hugepages` 中存储的数据就是大页面的数量，虽然在默认情况下它的值都是 0，不过我们可以通过更改该文件的内容申请或者释放操作系统中的大页：

```terminal
$ echo 1 > /proc/sys/vm/nr_hugepages
$ cat /proc/meminfo | grep HugePages_
HugePages_Total:       1
HugePages_Free:        1
```

### THP和perf

thp on后比off性能稳定好 10-15%

```
//on 419， thp off
9,145,128,732      branch-instructions       #  229.068 M/sec                    (10.65%)
       555,518,878      branch-misses             #    6.07% of all branches          (14.24%)
     3,951,535,475      bus-cycles                #   98.979 M/sec                    (14.29%)
       372,477,068      cache-misses              #    7.733 % of all cache refs      (14.34%)
     4,816,702,013      cache-references          #  120.649 M/sec                    (14.36%)
   114,521,174,305      cpu-cycles                #    2.869 GHz                      (14.36%)
    48,969,565,344      instructions              #    0.43  insn per cycle           (17.93%)
    98,728,666,922      ref-cycles                # 2472.967 M/sec                    (21.52%)
                 0      alignment-faults          #    0.000 K/sec
            12,187      context-switches          #    0.305 K/sec
         39,922.47 msec cpu-clock                 #    7.898 CPUs utilized
               147      cpu-migrations            #    0.004 K/sec
                 0      dummy                     #    0.000 K/sec
                 0      emulation-faults          #    0.000 K/sec
                 0      major-faults              #    0.000 K/sec
             1,727      minor-faults              #    0.043 K/sec
             1,768      page-faults               #    0.044 K/sec
         39,923.84 msec task-clock                #    7.898 CPUs utilized
     1,848,336,574      L1-dcache-load-misses     #   13.31% of all L1-dcache hits    (21.51%)
    13,889,399,043      L1-dcache-loads           #  347.903 M/sec                    (21.51%)
     7,055,617,648      L1-dcache-stores          #  176.730 M/sec                    (21.50%)
     2,017,950,458      L1-icache-load-misses                                         (21.50%)
        88,802,885      LLC-load-misses           #    9.86% of all LL-cache hits     (14.35%)
       900,379,398      LLC-loads                 #   22.553 M/sec                    (14.33%)
       162,711,813      LLC-store-misses          #    4.076 M/sec                    (7.13%)
       419,869,955      LLC-stores                #   10.517 M/sec                    (7.14%)
       553,257,955      branch-load-misses        #   13.858 M/sec                    (10.71%)
     9,195,874,519      branch-loads              #  230.339 M/sec                    (14.29%)
       176,112,524      dTLB-load-misses          #    1.28% of all dTLB cache hits   (14.29%)
    13,739,965,115      dTLB-loads                #  344.160 M/sec                    (14.28%)
        33,087,849      dTLB-store-misses         #    0.829 M/sec                    (14.28%)
     6,992,863,588      dTLB-stores               #  175.158 M/sec                    (14.26%)
       170,555,902      iTLB-load-misses          #  107.90% of all iTLB cache hits   (14.24%)
       158,070,998      iTLB-loads                #    3.959 M/sec                    (14.24%)
        68,973,832      node-load-misses          #    1.728 M/sec                    (14.24%)
        20,207,143      node-loads                #    0.506 M/sec                    (14.24%)
        93,216,790      node-store-misses         #    2.335 M/sec                    (7.10%)
        73,871,126      node-stores               #    1.850 M/sec                    (7.08%)

//on 419， thp on
    12,958,974,094      branch-instructions       #  227.392 M/sec                    (10.68%)
       850,468,837      branch-misses             #    6.56% of all branches          (14.27%)
     5,639,495,284      bus-cycles                #   98.957 M/sec                    (14.29%)
       526,744,798      cache-misses              #    7.324 % of all cache refs      (14.32%)
     7,192,328,925      cache-references          #  126.204 M/sec                    (14.34%)
   163,419,436,811      cpu-cycles                #    2.868 GHz                      (14.33%)
    68,638,583,038      instructions              #    0.42  insn per cycle           (17.90%)
   140,882,455,768      ref-cycles                # 2472.076 M/sec                    (21.48%)
                 0      alignment-faults          #    0.000 K/sec
            18,171      context-switches          #    0.319 K/sec
         56,987.52 msec cpu-clock                 #    7.932 CPUs utilized
                68      cpu-migrations            #    0.001 K/sec
                 0      dummy                     #    0.000 K/sec
                 0      emulation-faults          #    0.000 K/sec
                 0      major-faults              #    0.000 K/sec
             2,323      minor-faults              #    0.041 K/sec
             2,362      page-faults               #    0.041 K/sec
         56,991.53 msec task-clock                #    7.932 CPUs utilized
     2,471,392,118      L1-dcache-load-misses     #   12.69% of all L1-dcache hits    (21.47%)
    19,480,914,771      L1-dcache-loads           #  341.833 M/sec                    (21.48%)
    10,059,893,871      L1-dcache-stores          #  176.522 M/sec                    (21.46%)
     3,184,073,065      L1-icache-load-misses                                         (21.46%)
       128,467,945      LLC-load-misses           #   10.83% of all LL-cache hits     (14.31%)
     1,186,653,892      LLC-loads                 #   20.822 M/sec                    (14.30%)
       224,877,539      LLC-store-misses          #    3.946 M/sec                    (7.15%)
       628,574,746      LLC-stores                #   11.030 M/sec                    (7.15%)
       848,830,289      branch-load-misses        #   14.894 M/sec                    (10.71%)
    13,074,297,582      branch-loads              #  229.416 M/sec                    (14.28%)
       109,223,171      dTLB-load-misses          #    0.56% of all dTLB cache hits   (14.27%)
    19,418,657,165      dTLB-loads                #  340.741 M/sec                    (14.29%)
        13,930,402      dTLB-store-misses         #    0.244 M/sec                    (14.28%)
    10,047,511,003      dTLB-stores               #  176.305 M/sec                    (14.28%)
       194,902,860      iTLB-load-misses          #   61.23% of all iTLB cache hits   (14.27%)
       318,292,771      iTLB-loads                #    5.585 M/sec                    (14.26%)
       100,512,054      node-load-misses          #    1.764 M/sec                    (14.27%)
        28,144,120      node-loads                #    0.494 M/sec                    (14.27%)
       128,218,262      node-store-misses         #    2.250 M/sec                    (7.14%)
       103,892,078      node-stores               #    1.823 M/sec                    (7.11%) 
       
         7,599,757      dTLB-load-misses          #    0.09% of all dTLB cache hits   (15.59%)
     8,425,208,450      dTLB-loads                #  528.778 M/sec                    (15.62%)
         1,288,979      dTLB-store-misses         #    0.081 M/sec                    (15.67%)
     3,989,148,957      dTLB-stores               #  250.365 M/sec                    (15.27%)
        21,578,944      iTLB-load-misses          #   15.23% of all iTLB cache hits   (14.42%)
       141,697,584      iTLB-loads                #    8.893 M/sec                    (14.34%)
```



## [MySQL 场景下代码大页对性能的影响](https://ata.alibaba-inc.com/articles/217859)

不只是数据可以用HugePage，代码段也可以开启HugePage, 无论在x86还是arm（arm下提升更明显）下，都可以得到大页优于透明大页，透明大页优于正常的4K page

> 收益：代码大页 > anon THP > 4k

arm下，对32core机器用32并发的sysbench来对比，代码大页带来的性能提升大概有11%，iTLB miss下降了10倍左右。

x86下，性能提升只有大概3-5%之间，iTLB miss下降了1.5-3倍左右。

## [TLAB miss高的案例](https://ata.alibaba-inc.com/articles/152660)

程序运行久了之后会变慢大概10%

刚开始运行的时候perf各项数据:

![img](/images/951413iMgBlog/7a26deaf96bdcc07db4db34ae1178641.png)

长时间运行后：

![img](/images/951413iMgBlog/3385ae6ffbd5b48b80efa759f42b8174.png)

内存的利用以页为单位，当时分析认为，在此4k连续的基础上，页的碎片不应该对64 byte align的cache有什么影响。当时guest和host都没有开THP。

既然无法理解这个结果，那就只有按部就班的查看内核执行路径上各个函数的差别了，祭出ftrace:

```
echo kerel_func_name1 > /sys/kernel/debug/tracing/set_ftrace_filter

echo kerel_func_name2 > /sys/kernel/debug/tracing/set_ftrace_filter

echo kerel_func_name3 > /sys/kernel/debug/tracing/set_ftrace_filter
echo 1 > /sys/kernel/debug/tracing/function_profile_enabled
```

在CPU#20上执行代码:

taskset -c 20 ./b

代码执行完后:

```
echo 0 > /sys/kernel/debug/tracing/function_profile_enabled
cat /sys/kernel/debug/tracing/trace_stat/function20
```

这个时候就会打印出在各个函数上花费的时间，比如:

![img](/images/951413iMgBlog/329769dd1da2ed324ac11b8b922382cd.png)

经过调试后，逐步定位到主要时间差距在  __mem_cgroup_commit_charge() (58%).

在阅读代码的过程中，注意到当前内核使能了CONFIG_SPARSEMEM_VMEMMAP=y

原因就是机器运行久了之后内存碎片化严重，导致TLAB Miss严重。

解决：开启THP后，性能稳定

## 碎片化

内存碎片严重的话会导致系统hang很久(回收、压缩内存）

尽量让系统的free多一点(比例高一点）可以调整 vm.min_free_kbytes(128G 以内 2G，256G以内 4G/8G), 线上机器直接修改vm.min_free_kbytes**会触发回收，导致系统hang住** https://www.atatech.org/articles/163233 https://www.atatech.org/articles/97130

compact: 在进行 compcation 时，线程会从前往后扫描已使用的 movable page，然后从后往前扫描 free page，扫描结束后会把这些 movable page 给迁移到 free page 里，最终规整出一个 2M 的连续物理内存，这样 THP 就可以成功申请内存了。

![image-20210628144121108](/images/951413iMgBlog/image-20210628144121108.png)

一次THP compact堆栈：

```
java          R  running task        0 144305 144271 0x00000080
 ffff88096393d788 0000000000000086 ffff88096393d7b8 ffffffff81060b13
 ffff88096393d738 ffffea003968ce50 000000000000000e ffff880caa713040
 ffff8801688b0638 ffff88096393dfd8 000000000000fbc8 ffff8801688b0640

Call Trace:
 [<ffffffff81060b13>] ? perf_event_task_sched_out+0x33/0x70
 [<ffffffff8100bb8e>] ? apic_timer_interrupt+0xe/0x20
 [<ffffffff810686da>] __cond_resched+0x2a/0x40
 [<ffffffff81528300>] _cond_resched+0x30/0x40
 [<ffffffff81169505>] compact_checklock_irqsave+0x65/0xd0
 [<ffffffff81169862>] compaction_alloc+0x202/0x460
 [<ffffffff811748d8>] ? buffer_migrate_page+0xe8/0x130
 [<ffffffff81174b4a>] migrate_pages+0xaa/0x480
 [<ffffffff81169660>] ? compaction_alloc+0x0/0x460                 //compact and migrate
 [<ffffffff8116a1a1>] compact_zone+0x581/0x950
 [<ffffffff8116a81c>] compact_zone_order+0xac/0x100
 [<ffffffff8116a951>] try_to_compact_pages+0xe1/0x120
 [<ffffffff8112f1ba>] __alloc_pages_direct_compact+0xda/0x1b0
 [<ffffffff8112f80b>] __alloc_pages_nodemask+0x57b/0x8d0
 [<ffffffff81167b9a>] alloc_pages_vma+0x9a/0x150
 [<ffffffff8118337d>] do_huge_pmd_anonymous_page+0x14d/0x3b0        //huge page
 [<ffffffff8152a116>] ? rwsem_down_read_failed+0x26/0x30
 [<ffffffff8114b350>] handle_mm_fault+0x2f0/0x300
 [<ffffffff810ae950>] ? wake_futex+0x40/0x60
 [<ffffffff8104a8d8>] __do_page_fault+0x138/0x480
 [<ffffffff810097cc>] ? __switch_to+0x1ac/0x320
 [<ffffffff81527910>] ? thread_return+0x4e/0x76e
 [<ffffffff8152d45e>] do_page_fault+0x3e/0xa0                       //page fault
 [<ffffffff8152a815>] page_fault+0x25/0x30
```



### 查看pagetypeinfo

```
#cat /proc/pagetypeinfo
Page block order: 9
Pages per block:  512

Free pages count per migrate type at order       0      1      2      3      4      5      6      7      8      9     10
Node    0, zone      DMA, type    Unmovable      1      1      1      0      2      1      1      0      1      0      0
Node    0, zone      DMA, type  Reclaimable      0      0      0      0      0      0      0      0      0      0      0
Node    0, zone      DMA, type      Movable      0      0      0      0      0      0      0      0      0      1      3
Node    0, zone      DMA, type      Reserve      0      0      0      0      0      0      0      0      0      0      0
Node    0, zone      DMA, type          CMA      0      0      0      0      0      0      0      0      0      0      0
Node    0, zone      DMA, type      Isolate      0      0      0      0      0      0      0      0      0      0      0
Node    0, zone    DMA32, type    Unmovable     89    144     98     42     21     14      5      2      1      0      1
Node    0, zone    DMA32, type  Reclaimable     28     22      9      8      0      0      0      0      0      1      7
Node    0, zone    DMA32, type      Movable    402     50     21      8    880    924    321     51      4      1    227
Node    0, zone    DMA32, type      Reserve      0      0      0      0      0      0      0      0      0      0      1
Node    0, zone    DMA32, type          CMA      0      0      0      0      0      0      0      0      0      0      0
Node    0, zone    DMA32, type      Isolate      0      0      0      0      0      0      0      0      0      0      0
Node    0, zone   Normal, type    Unmovable  13709  15231   6637   2646    816    181     46      4      4      1      0
Node    0, zone   Normal, type  Reclaimable      1      5      6   3293   1295    128     29      7      5      0      0
Node    0, zone   Normal, type      Movable   6396 1383350 1301956 1007627 670102 366248 160232  54894  13126   1482     37
Node    0, zone   Normal, type      Reserve      0      0      0      2      1      1      0      0      0      0      0
Node    0, zone   Normal, type          CMA      0      0      0      0      0      0      0      0      0      0      0
Node    0, zone   Normal, type      Isolate      0      0      0      0      0      0      0      0      0      0      0

Number of blocks type     Unmovable  Reclaimable      Movable      Reserve          CMA      Isolate
Node 0, zone      DMA            1            0            7            0            0            0
Node 0, zone    DMA32           24           38          889            1            0            0
Node 0, zone   Normal         1568          795       127683            2            0            0
Page block order: 9
Pages per block:  512

Free pages count per migrate type at order       0      1      2      3      4      5      6      7      8      9     10
Node    1, zone   Normal, type    Unmovable   3938   8735   5469   3221   2097    989    202      6      0      0      0
Node    1, zone   Normal, type  Reclaimable      1      7      7      8      7      2      2      2      1      0      0
Node    1, zone   Normal, type      Movable  18623 1001037 2084894 1261484 631159 276096  87272  17169   1389    797      0
Node    1, zone   Normal, type      Reserve      0      0      0      8      0      0      0      0      0      0      0
Node    1, zone   Normal, type          CMA      0      0      0      0      0      0      0      0      0      0      0
Node    1, zone   Normal, type      Isolate      0      0      0      0      0      0      0      0      0      0      0

Number of blocks type     Unmovable  Reclaimable      Movable      Reserve          CMA      Isolate
Node 1, zone   Normal         1530          637       128903            2            0            0
```

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

​	

## 参考资料

https://www.atatech.org/articles/66885

https://cloud.tencent.com/developer/article/1087455

https://www.cnblogs.com/xiaolincoding/p/13719610.html

