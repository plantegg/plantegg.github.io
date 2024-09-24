---
title: Linux 内存问题汇总
date: 2020-01-15 16:30:03
categories: Memory
tags:
    - Linux
    - free
    - Memory
    - vmtouch
---

# Linux 内存问题汇总

本系列有如下几篇

[Linux 内存问题汇总](/2020/01/15/Linux 内存问题汇总/)

[Linux内存--PageCache](/2020/11/15/Linux内存--pagecache/)

[Linux内存--管理和碎片](/2020/11/15/Linux内存--管理和碎片/)

[Linux内存--HugePage](/2020/11/15/Linux内存--HugePage/)

[Linux内存--零拷贝](/2020/11/15/Linux内存--零拷贝/)



## 内存使用观察

	# free -m
	         total       used       free     shared    buffers     cached
	Mem:          7515       1115       6400          0        189        492
	-/+ buffers/cache:        432       7082
	Swap:            0          0          0

其中，[cached 列表示当前的页缓存（Page Cache）占用量](https://spongecaptain.cool/SimpleClearFileIO/1.%20page%20cache.html)，buffers 列表示当前的块缓存（buffer cache）占用量。用一句话来解释：**Page Cache 用于缓存文件的页数据，buffer cache 用于缓存块设备（如磁盘）的块数据。**页是逻辑上的概念，因此 Page Cache 是与文件系统同级的；块是物理上的概念，因此 buffer cache 是与块设备驱动程序同级的。

<img src="https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/oss/f8d944e2c7a8611384acb820c4471007.png" alt="image.png" style="zoom:80%;" />

**上图中-/+ buffers/cache: -是指userd去掉buffers/cached后真正使用掉的内存; +是指free加上buffers和cached后真正free的内存大小。**

## [free](https://aleiwu.com/post/linux-memory-monitring/)

free是从 /proc/meminfo 读取数据然后展示：

> buff/cache = Buffers + Cached + SReclaimable
>
> Buffers + Cached + SwapCached = Active(file) + Inactive(file) + Shmem + SwapCached

```
[root@az1-drds-79 ~]# cat /proc/meminfo |egrep -i "buff|cach|SReclai"
Buffers:          817764 kB
Cached:         76629252 kB
SwapCached:            0 kB
SReclaimable:    7202264 kB
[root@az1-drds-79 ~]# free -k
             total       used       free     shared    buffers     cached
Mem:      97267672   95522336    1745336          0     817764   76629352
-/+ buffers/cache:   18075220   79192452
Swap:            0          0          0

```

在内核启动时，物理页面将加入到伙伴系统 （Buddy System）中，用户申请内存时分配，释放时回收。为了照顾慢速设备及兼顾多种 workload，Linux 将页面类型分为匿名页（Anon Page）和文件页 （Page Cache），及 swapness，使用 Page Cache 缓存文件 （慢速设备），通过 swap cache 和 swapness 交由用户根据负载特征决定内存不足时回收二者的比例。

## cached过高回收

系统内存大体可分为三块，应用程序使用内存、系统Cache 使用内存（包括page cache、buffer，内核slab 等）和Free 内存。

- 应用程序使用内存：应用使用都是虚拟内存，应用申请内存时只是分配了地址空间，并未真正分配出物理内存，等到应用真正访问内存时会触发内核的缺页中断，这时候才真正的分配出物理内存，映射到用户的地址空间，因此应用使用内存是不需要连续的，内核有机制将非连续的物理映射到连续的进程地址空间中（mmu），缺页中断申请的物理内存，内核优先给低阶碎内存。
-  系统Cache 使用内存：使用的也是虚拟内存，申请机制与应用程序相同。

- Free 内存，未被使用的物理内存，这部分内存以4k 页的形式被管理在内核伙伴算法结构中，相邻的2^n 个物理页会被伙伴算法组织到一起，形成一块连续物理内存，所谓的阶内存就是这里的n (0<= n <=10)，高阶内存指的就是一块连续的物理内存，在OSS 的场景中，如果3阶内存个数比较小的情况下，如果系统有吞吐burst 就会触发Drop cache 情况。

cache回收：	
	echo 1/2/3 >/proc/sys/vm/drop_caches

查看回收后：

	cat /proc/meminfo

手动回收系统Cache、Buffer，这个文件可以设置的值分别为1、2、3。它们所表示的含义为：

**echo 1 > /proc/sys/vm/drop_caches**:表示清除pagecache。

**echo 2 > /proc/sys/vm/drop_caches**:表示清除回收slab分配器中的对象（包括目录项缓存和inode缓存）。slab分配器是内核中管理内存的一种机制，其中很多缓存数据实现都是用的pagecache。

**echo 3 > /proc/sys/vm/drop_caches**:表示清除pagecache和slab分配器中的缓存对象。

## cached无法回收

可能是正打开的文件占用了cached，比如 vim 打开了一个巨大的文件；比如 mount的 tmpfs； 比如 journald 日志等等

### 通过[vmtouch](https://hoytech.com/vmtouch/) 查看

	# vmtouch -v test.x86_64.rpm 
	test.x86_64.rpm
	[OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO] 10988/10988
	
	           Files: 1
	     Directories: 0
	  Resident Pages: 10988/10988  42M/42M  100%
	         Elapsed: 0.000594 seconds
	
	# ls -lh test.x86_64.rpm
	-rw-r--r-- 1 root root 43M 10月  8 14:11 test.x86_64.rpm

如上，表示整个文件 test.x86_64.rpm 都被cached了，回收的话执行：

	vmtouch -e test.x86_64.rpm // 或者： echo 3 >/proc/sys/vm/drop_cached

### 遍历某个目录下的所有文件被cached了多少

	# vmtouch -vt /var/log/journal/
	/var/log/journal/20190829214900434421844640356160/user-1000@ad408d9cb9d94f9f93f2c2396c26b542-000000000011ba49-00059979e0926f43.journal
	[OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO] 4096/4096
	/var/log/journal/20190829214900434421844640356160/system@782ec314565e436b900454c59655247c-0000000000152f41-00059b2c88eb4344.journal
	[OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO] 14336/14336
	/var/log/journal/20190829214900434421844640356160/user-1000@ad408d9cb9d94f9f93f2c2396c26b542-00000000000f2181-000598335fcd492f.journal
	[OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO] 4096/4096
	/var/log/journal/20190829214900434421844640356160/system@782ec314565e436b900454c59655247c-0000000000129aea-000599e83996db80.journal
	[OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO] 14336/14336
	/var/log/journal/20190829214900434421844640356160/user-1000@ad408d9cb9d94f9f93f2c2396c26b542-000000000009f171-000595a722ead670.journal
	…………
	           Files: 48
	 Directories: 2
	 Touched Pages: 468992 (1G)
	 Elapsed: 13.274 seconds
### vmtouch 清理目录

如下脚本传入一个指定目录(业务方来确认哪些目录占用 pagecache 较大, 且可以清理)，然后用vmtouch 遍历排序最大的几个清理掉，可能会造成业务的卡度

```
#!/bin/bash
#
#echo "*/2 * * * * root bash /root/cron/os_pagecache_clean.sh -n 5 -e > /root/cron/os_pagecache_clean.out 2>&1" > /etc/cron.d/os_pagecache_clean

function usage(){
cat << EOF
usage:
    $0 -n topN [-l|-e]
option:
    -l list top n redis_dir
    -e list and evict top n redis_dir
    -n top n
EOF
exit 1
}

while getopts "n:leh" opt; do
  case $opt in
    l) list=1 ;;
    e) list=1 && evict=1 ;;
    n) n=${OPTARG} ;;
    h) usage ;;
  esac
done

[[ -z $n ]] && usage
[[ -z $list && -z $evict ]] && usage

# list must = 1
cd /root && ls | while read dirname ; do
    page=$(vmtouch $dirname |  grep "Resident Pages")
    echo -e "$dirname\t$page"
done | tr "/" " " |   sort -nr -k4 | head -n $n | awk '{print $1,$6}' | while read dirname cache_size; do
    echo -e "$dirname\t$cache_size"
    [[ $evict == 1 ]] && vmtouch -e $dirname
done
```



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

​	

## 参考资料

https://www.atatech.org/articles/66885

https://cloud.tencent.com/developer/article/1087455

https://www.cnblogs.com/xiaolincoding/p/13719610.html