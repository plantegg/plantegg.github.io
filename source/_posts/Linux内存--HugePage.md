---
title: Linux内存--HugePage
date: 2020-11-15 16:30:03
categories: Linux
tags:
    - Linux
    - free
    - Memory
    - HugePage
---

# Linux内存--HugePage

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

## 消失的内存

OS刚启动后就报内存不够了，什么都没跑就500G没了，cached和buffer基本没用，纯粹就是used占用高，top按内存排序没有超过0.5%的进程

参考： https://cloud.tencent.com/developer/article/1087455

```
[aliyun@uos15 18:40 /u02/backup_15/leo/benchmark/run]
$free -g
              total        used        free      shared  buff/cache   available
Mem:            503         501           1           0           0           1
Swap:            15          12           3

$cat /proc/meminfo 
MemTotal:       528031512 kB
MemFree:         1469632 kB
MemAvailable:          0 kB
VmallocTotal:   135290290112 kB
VmallocUsed:           0 kB
VmallocChunk:          0 kB
Percpu:            81920 kB
AnonHugePages:    950272 kB
ShmemHugePages:        0 kB
ShmemPmdMapped:        0 kB
HugePages_Total:   252557   ----- 预分配太多，一个2M，加起来刚好500G了
HugePages_Free:    252557
HugePages_Rsvd:        0
HugePages_Surp:        0
Hugepagesize:       2048 kB
Hugetlb:        517236736 kB

以下是一台正常的机器对比：
Percpu:            41856 kB
AnonHugePages:  11442176 kB
ShmemHugePages:        0 kB
ShmemPmdMapped:        0 kB
HugePages_Total:       0            ----没有做预分配
HugePages_Free:        0
HugePages_Rsvd:        0
HugePages_Surp:        0
Hugepagesize:       2048 kB
Hugetlb:               0 kB

[aliyun@uos16 18:43 /home/aliyun]
$free -g
              total        used        free      shared  buff/cache   available
Mem:            503          20         481           0           1         480
Swap:            15           0          15

对有问题的机器执行：
# echo 1024 > /proc/sys/vm/nr_hugepages
可以看到内存恢复正常了 
root@uos15:/u02/backup_15/leo/benchmark/run# free -g
              total        used        free      shared  buff/cache   available
Mem:            503          10         492           0           0         490
Swap:            15          12           3
root@uos15:/u02/backup_15/leo/benchmark/run# cat /proc/meminfo 
MemTotal:       528031512 kB
MemFree:        516106832 kB
MemAvailable:   514454408 kB
VmallocTotal:   135290290112 kB
VmallocUsed:           0 kB
VmallocChunk:          0 kB
Percpu:            81920 kB
AnonHugePages:    313344 kB
ShmemHugePages:        0 kB
ShmemPmdMapped:        0 kB
HugePages_Total:    1024
HugePages_Free:     1024
HugePages_Rsvd:        0
HugePages_Surp:        0
Hugepagesize:       2048 kB
Hugetlb:         2097152 kB
```

## 关于hugetlb

 This is an entry in the TLB that points to a HugePage (a large/big page larger than regular 4K and predefined in size). HugePages are implemented via hugetlb entries, i.e. we can say that a HugePage is handled by a "hugetlb page entry". The 'hugetlb" term is also (and mostly) used synonymously with a HugePage (See Note 261889.1). In this document the term "HugePage" is going to be used but keep in mind that mostly "hugetlb" refers to the same concept.

 hugetlb 是TLB中指向HugePage的一个entry(通常大于4k或预定义页面大小)。 HugePage 通过hugetlb entries来实现，也可以理解为HugePage 是hugetlb page entry的一个句柄。

**Linux下的大页分为两种类型：标准大页（Huge Pages）和透明大页（Transparent Huge Pages）**

标准大页管理是预分配的方式，而透明大页管理则是动态分配的方式

目前透明大页与传统HugePages联用会出现一些问题，导致性能问题和系统重启。Oracle 建议禁用透明大页（Transparent Huge Pages）

hugetlbfs比THP要好，开thp的机器碎片化严重（不开THP会有更严重的碎片化问题），最后和没开THP一样 https://www.atatech.org/articles/152660

Linux 中的 HugePages 都被锁定在内存中，所以哪怕是在系统内存不足时，它们也不会被 Swap 到磁盘上，这也就能从根源上杜绝了重要内存被频繁换入和换出的可能。

虽然 HugePages 的开启大都需要开发或者运维工程师的额外配置，但是在应用程序中启用 HugePages 却可以在以下几个方面降低内存页面的管理开销：

- 更大的内存页能够减少内存中的页表层级，这不仅可以降低页表的内存占用，也能降低从虚拟内存到物理内存转换的性能损耗；
- 更大的内存页意味着更高的缓存命中率，CPU 有更高的几率可以直接在 TLB（Translation lookaside buffer）中获取对应的物理地址；
- 更大的内存页可以减少获取大内存的次数，使用 HugePages 每次可以获取 2MB 的内存，是 4KB 的默认页效率的 512 倍；

## THP

Linux kernel在2.6.38内核增加了Transparent Huge Pages (THP)特性 ，支持大内存页(2MB)分配，默认开启。当开启时可以降低fork子进程的速度，但fork之后，每个内存页从原来4KB变为2MB，会大幅增加重写期间父进程内存消耗。同时每次写命令引起的复制内存页单位放大了512倍，会拖慢写操作的执行时间，导致大量写操作慢查询。例如简单的incr命令也会出现在慢查询中。因此Redis日志中建议将此特性进行禁用。  

THP 的目的是用一个页表项来映射更大的内存（大页），这样可以减少 Page Fault，因为需要的页数少了。当然，这也会提升 TLB（Translation Lookaside Buffer，由存储器管理单元用于改进虚拟地址到物理地址的转译速度） 命中率，因为需要的页表项也少了。如果进程要访问的数据都在这个大页中，那么这个大页就会很热，会被缓存在 Cache 中。而大页对应的页表项也会出现在 TLB 中，从上一讲的存储层次我们可以知道，这有助于性能提升。但是反过来，假设应用程序的数据局部性比较差，它在短时间内要访问的数据很随机地位于不同的大页上，那么大页的优势就会消失。

THP 对redis、monglodb 这种cache类推荐关闭，对drds这种java应用最好打开

```
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
...
```

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

## 定制内存

物理内存700多G，要求OS只能用512G：

```
24条32G的内存条，总内存768G
# dmidecode -t memory |grep "Size: 32 GB"
  Size: 32 GB
…………
  Size: 32 GB
  Size: 32 GB
root@uos15:/etc# dmidecode -t memory |grep "Size: 32 GB" | wc -l
24

# cat /boot/grub/grub.cfg  |grep 512
  linux /vmlinuz-4.19.0-arm64-server root=UUID=dbc68010-8c36-40bf-b794-271e59ff5727 ro  splash quiet console=tty video=VGA-1:1280x1024@60 mem=512G DEEPIN_GFXMODE=$DEEPIN_GFXMODE
    linux /vmlinuz-4.19.0-arm64-server root=UUID=dbc68010-8c36-40bf-b794-271e59ff5727 ro  splash quiet console=tty video=VGA-1:1280x1024@60 mem=512G DEEPIN_GFXMODE=$DEEPIN_GFXMODE
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

