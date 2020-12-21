---
title: Linux 内存问题汇总
date: 2020-01-15 16:30:03
categories: Linux
tags:
    - Linux
    - free
    - Memory
    - vmtouch
---

# Linux 内存问题汇总

## 内存使用观察

	# free -m
	         total       used       free     shared    buffers     cached
	Mem:          7515       1115       6400          0        189        492
	-/+ buffers/cache:        432       7082
	Swap:            0          0          0



<img src="https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/f8d944e2c7a8611384acb820c4471007.png" alt="image.png" style="zoom:80%;" />

**上图中-/+ buffers/cache: -是指userd去掉buffers/cached后真正使用掉的内存; +是指free加上buffers和cached后真正free的内存大小。**



## free

free是从 /proc/meminfo 读取数据然后展示：

> buff/cache = Buffers + Cached + SReclaimable

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

### /proc/buddyinfo

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
	echo 1/2/3 >/proc/sys/vm/drop_cached

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



## 还有很多cached无法回收

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
## read+write 和零拷贝

```
read(file, tmp_buf, len);
write(socket, tmp_buf, len);
```

![image-20201104175056589](D:%5Cali%5Ccase%5Cimage%5Cimage-20201104175056589.png)

### 通过mmap替换read优化一下

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/516c11b9b9d3f6092f00645c1742c111.png)

通过使用 `mmap()` 来代替 `read()`， 可以减少一次数据拷贝的过程。

但这还不是最理想的零拷贝，因为仍然需要通过 CPU 把内核缓冲区的数据拷贝到 socket 缓冲区里，而且仍然需要 4 次上下文切换，因为系统调用还是 2 次。

### sendfile

在 Linux 内核版本 2.1 中，提供了一个专门发送文件的系统调用函数 `sendfile()`，函数形式如下：

```c
#include <sys/socket.h>
ssize_t sendfile(int out_fd, int in_fd, off_t *offset, size_t count);
```

它的前两个参数分别是目的端和源端的文件描述符，后面两个参数是源端的偏移量和复制数据的长度，返回值是实际复制数据的长度。

首先，它可以替代前面的 `read()` 和 `write()` 这两个系统调用，这样就可以减少一次系统调用，也就减少了 2 次上下文切换的开销。

其次，该系统调用，可以直接把内核缓冲区里的数据拷贝到 socket 缓冲区里，不再拷贝到用户态，这样就只有 2 次上下文切换，和 3 次数据拷贝。如下图：

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/bd72f4a031bcd88db0ca233e59234832.png)

### SG-DMA（*The Scatter-Gather Direct Memory Access*）技术

如果网卡支持 SG-DMA（*The Scatter-Gather Direct Memory Access*）技术（和普通的 DMA 有所不同），我们可以进一步减少通过 CPU 把内核缓冲区里的数据拷贝到 socket 缓冲区的过程。

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/2361e8c6dcfd20a67f404b684196c160.png)

这就是所谓的**零拷贝（Zero-copy）技术，因为我们没有在内存层面去拷贝数据，也就是说全程没有通过 CPU 来搬运数据，所有的数据都是通过 DMA 来进行传输的。**。

零拷贝技术的文件传输方式相比传统文件传输的方式，减少了 2 次上下文切换和数据拷贝次数，**只需要 2 次上下文切换和数据拷贝次数，就可以完成文件的传输，而且 2 次的数据拷贝过程，都不需要通过 CPU，2 次都是由 DMA 来搬运。**

所以，总体来看，**零拷贝技术可以把文件传输的性能提高至少一倍以上**。

### 零拷贝应用

kafaka这个开源项目，就利用了「零拷贝」技术，从而大幅提升了 I/O 的吞吐率，这也是 Kafka 在处理海量数据为什么这么快的原因之一。

如果你追溯 Kafka 文件传输的代码，你会发现，最终它调用了 Java NIO 库里的 `transferTo` 方法：

```java
@Overridepublic 
long transferFrom(FileChannel fileChannel, long position, long count) throws IOException { 
    return fileChannel.transferTo(position, count, socketChannel);
}
```

如果 Linux 系统支持 `sendfile()` 系统调用，那么 `transferTo()` 实际上最后就会使用到 `sendfile()` 系统调用函数。

Nginx 也支持零拷贝技术，一般默认是开启零拷贝技术，这样有利于提高文件传输的效率，是否开启零拷贝技术的配置如下：

```
http {
...
    sendfile on
...
}
```

sendfile 配置的具体意思:

- 设置为 on 表示，使用零拷贝技术来传输文件：sendfile ，这样只需要 2 次上下文切换，和 2 次数据拷贝。
- 设置为 off 表示，使用传统的文件传输技术：read + write，这时就需要 4 次上下文切换，和 4 次数据拷贝。

如果是大文件很容易消耗非常多的PageCache，不推荐使用PageCache（或者说零拷贝），建议使用异步IO+直接IO。

在 nginx 中，我们可以用如下配置，来根据文件的大小来使用不同的方式：

```
location /video/ { 
    sendfile on; 
    aio on; 
    directio 1024m; 
}
```

当文件大小大于 `directio` 值后，使用「异步 I/O + 直接 I/O」，否则使用「零拷贝技术」。

## pagecache 的产生和释放

- 标准 I/O 是写的 (write(2)) 用户缓冲区 (Userpace Page 对应的内存)，**然后再将用户缓冲区里的数据拷贝到内核缓冲区 (Pagecache Page 对应的内存)**；如果是读的 (read(2)) 话则是先从内核缓冲区拷贝到用户缓冲区，再从用户缓冲区读数据，也就是 buffer 和文件内容不存在任何映射关系。
- 对于存储映射 I/O（Memory-Mapped I/O） 而言，则是直接将 Pagecache Page 给映射到用户地址空间，用户直接读写 Pagecache Page 中内容，效率相对标准IO更高一些

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/51bf36aa14dc01e7ad309c1bb9d252e9.png)

当 **将用户缓冲区里的数据拷贝到内核缓冲区 (Pagecache Page 对应的内存)** 最容易发生缺页中断，OS需要先分配Page（应用感知到的就是卡顿了）

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/d62ea00662f8342b7df3aab6b28e4cbb.png)  

- Page Cache 是在应用程序读写文件的过程中产生的，所以在读写文件之前你需要留意是否还有足够的内存来分配 Page Cache；
- Page Cache 中的脏页很容易引起问题，你要重点注意这一块；
- 在系统可用内存不足的时候就会回收 Page Cache 来释放出来内存，我建议你可以通过 sar 或者 /proc/vmstat 来观察这个行为从而更好的判断问题是否跟回收有关



缺页后kswapd在短时间内回收不了足够多的 free 内存，或kswapd 还没有触发执行，操作系统就会进行内存页直接回收。这个过程中，应用会进行自旋等待直到回收的完成，从而产生巨大的延迟。

![](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/0a5cdeb75b7dee2068254cd4b7fe254d.png)

如果page被swapped，那么恢复进内存的过程也对延迟有影响，当被匿名内存页被回收后，如果下次再访问就会产生IO的延迟。

![](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/740b95056dace8ae6fb3b8f58d91572e.png)



### min 和 low的区别

1. min下的内存是保留给内核使用的；当到达min，会触发内存的direct reclaim （vm.min_free_kbytes）
2. low水位比min高一些，当内存可用量小于low的时候，会触发 kswapd回收内存，当kswapd慢慢的将内存 回收到high水位，就开始继续睡眠 

### 内存回收方式

内存回收方式有两种，主要对应low ，min

1. kswapd reclaim : 达到low水位线时执行 -- 异步（实际还有，只是比较危险了，后台kswapd会回收，不会卡顿应用）
2. direct reclaim : 达到min水位线时执行 -- 同步

为了减少缺页中断，首先就要保证我们有足够的内存可以使用。由于Linux会尽可能多的使用free的内存，运行很久的应用free的内存是很少的。下面的图中，紫色表示已经使用的内存，白色表示尚未分配的内存。当我们的内存使用达到水位的low值的时候，kswapd就会开始回收工作，而一旦内存分配超过了min，就会进行内存的直接回收。

![](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/5933cc4c28f86aa08410a8af4ff4410d.png)

针对这种情况，我们需要采用预留内存的手段，系统参数vm.extra_free_kbytes就是用来做这个事情的。这个参数设置了系统预留给应用的内存，可以避免紧急需要内存时发生内存回收不及时导致的高延迟。从下面图中可以看到，通过vm.extra_free_kbytes的设置，预留内存可以让内存的申请处在一个安全的水位。**需要注意的是，因为内核的优化，在3.10以上的内核版本这个参数已经被取消。**

![](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/f55022d4eb181b92ba5d2e142ec940c8.png)

或者禁止： vm.swappiness  来避免swapped来减少延迟

## Page回收--缺页中断

<img src="https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/3fdffacd66c0981956b15be348fff46a.png" alt="image.png" style="zoom:50%;" />

从图里你可以看到，在开始内存回收后，首先进行后台异步回收（上图中蓝色标记的地方），这不会引起进程的延迟；如果后台异步回收跟不上进程内存申请的速度，就会开始同步阻塞回收，导致延迟（上图中红色和粉色标记的地方，这就是引起 load 高的地址 -- Sys CPU 使用率飙升/Sys load 飙升）。

那么，针对直接内存回收引起 load 飙高或者业务 RT 抖动的问题，一个解决方案就是及早地触发后台回收来避免应用程序进行直接内存回收，那具体要怎么做呢？

<img src="https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/4b341ba757d27e3a81145a55f54363e1.png" alt="image.png" style="zoom:67%;" />

它的意思是：当内存水位低于 watermark low 时，就会唤醒 kswapd 进行后台回收，然后 kswapd 会一直回收到 watermark high。

那么，我们可以增大 min_free_kbytes 这个配置选项来及早地触发后台回收，该选项最终控制的是内存回收水位，不过，内存回收水位是内核里面非常细节性的知识点，我们可以先不去讨论。

对于大于等于 128G 的系统而言，将 min_free_kbytes 设置为 4G 比较合理，这是我们在处理很多这种问题时总结出来的一个经验值，既不造成较多的内存浪费，又能避免掉绝大多数的直接内存回收。

该值的设置和总的物理内存并没有一个严格对应的关系，我们在前面也说过，如果配置不当会引起一些副作用，所以在调整该值之前，我的建议是：你可以渐进式地增大该值，比如先调整为 1G，观察 sar -B 中 pgscand 是否还有不为 0 的情况；如果存在不为 0 的情况，继续增加到 2G，再次观察是否还有不为 0 的情况来决定是否增大，以此类推。

> sar -B :  Report paging statistics.
>
> pgscand/s  Number of pages scanned directly per second.

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

## 通过tracepoint分析内存卡顿问题

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/d5446b656e8d91a9fb72200a7b97e723.png)

我们继续以内存规整 (memory compaction) 为例，来看下如何利用 tracepoint 来对它进行观察：

```
#首先来使能compcation相关的一些tracepoing
$ echo 1 >
/sys/kernel/debug/tracing/events/compaction/mm_compaction_begin/enable
$ echo 1 >
/sys/kernel/debug/tracing/events/compaction/mm_compaction_end/enable 

#然后来读取信息，当compaction事件触发后就会有信息输出
$ cat /sys/kernel/debug/tracing/trace_pipe
           <...>-49355 [037] .... 1578020.975159: mm_compaction_begin: 
zone_start=0x2080000 migrate_pfn=0x2080000 free_pfn=0x3fe5800 
zone_end=0x4080000, mode=async
           <...>-49355 [037] .N.. 1578020.992136: mm_compaction_end: 
zone_start=0x2080000 migrate_pfn=0x208f420 free_pfn=0x3f4b720 
zone_end=0x4080000, mode=async status=contended
```

从这个例子中的信息里，我们可以看到是 49355 这个进程触发了 compaction，begin 和 end 这两个 tracepoint 触发的时间戳相减，就可以得到 compaction 给业务带来的延迟，我们可以计算出这一次的延迟为 17ms。

或者用 [perf script](https://lore.kernel.org/linux-mm/20191001144524.GB3321@techsingularity.net/T/) 脚本来分析, [基于 bcc(eBPF) 写的direct reclaim snoop](https://github.com/iovisor/bcc/blob/master/tools/drsnoop.py)来观察进程因为 direct reclaim 而导致的延迟。

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

## DMA

什么是 DMA 技术？简单理解就是，**在进行 I/O 设备和内存的数据传输的时候，数据搬运的工作全部交给 DMA 控制器，而 CPU 不再参与任何与数据搬运相关的事情，这样 CPU 就可以去处理别的事务**。	

## 参考资料

https://www.atatech.org/articles/66885

https://cloud.tencent.com/developer/article/1087455

https://www.cnblogs.com/xiaolincoding/p/13719610.html