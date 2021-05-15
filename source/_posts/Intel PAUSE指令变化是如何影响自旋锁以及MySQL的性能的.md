---
title: Intel PAUSE指令变化是如何影响自旋锁以及MySQL的性能的
date: 2019-12-16 12:30:03
categories: Linux
tags:
    - performance
    - mysql
    - perf
    - intel
    - pause
    - innodb_spin_wait_delay
---

# Intel PAUSE指令变化是如何影响自旋锁以及MySQL的性能的

本文记录专有云场景下Tomcat+MySQL集群的一次全表扫描性能优化过程

经验总结，长链路下性能瓶颈发现规则（最容易互相扯皮、协调难度大）：

> 从一个压测线程开始压，记录tps、rt；然后增加线程数量，到tps明显不再增加，分析此时各个环节的rt，看哪个环节rt增加最明显，瓶颈就在哪个环节
>
> 如果监控没法得到各个环节的rt数据(太现实和普遍了)，抓包分析请求相应的rt



## 业务结构

client -> Tomcat -> slb -> MySQL（32实例，每个实例8Core）

## 场景描述：

通过client压 Tomcat和MySQL，MySQL是32个实例，业务逻辑是不带拆分键的全表扫描，也就是一个client SQL经过Tomcat后会拆分成256个SQL发送给32个MySQL（每个MySQL上有8个分库）

业务SQL是一个简单的select sum求和，这个SQL在每个MySQL上都很快（有索引）

	SELECT SUM(emp_arr_amt) FROM uebmi_clct_det_c WHERE INSUTYPE='310' AND Revs_Flag='Z' AND accrym='201910' AND emp_no='1050457';

## 说明：

- 后述或者截图中的逻辑rt/QPS是指client看到的Tomcat的rt和QPS； 
- 物理rt/QPS是指Tomcat看到的MySQL rt和QPS（这里的rt是指到达Tomcat节点网卡的rt，所以还包含了网络消耗）

## 问题描述：

通过client压一个Tomcat节点+32个MySQL，QPS大概是430，Tomcat节点CPU跑满，MySQL rt是0.5ms，增加一个Tomcat节点，QPS大概是700，Tomcat CPU接近跑满，MySQL rt是0.6ms，到这里基本都是正常的。

继续增加Tomcat节点来横向扩容性能，通过client压三个Tomcat节点+32个MySQL，QPS还是700，Tomcat节点CPU跑不满，MySQL rt是0.8ms，这就严重不符合预期了。

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/28610e403282d493e2ce18fbecc69421.png)

**到这里一切都还是符合我们的经验的，看起来是后端有瓶颈。**

## 排查 MySQL

现场DBA通过监控看到MySQL CPU不到20%，没有慢查询，并且尝试用client越过所有中间环节直接压其中一个MySQL，发现MySQL CPU基本能跑满，这时的QPS大概是38000（对应上面的场景client QPS为700的时候，单个MySQL上的QPS才跑到6000) 所以排除了MySQL的嫌疑

## slb和网络的嫌疑

首先通过大查询排除了带宽的问题，因为这里都是小包，pps到了72万，很自然想到了xgw、slb的限流之类的

pps监控，这台物理机有4个MySQL实例上，pps 9万左右，9*32/4=72万
![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/b84245c17e213de528f2ad8090d504f6.png)

在xgw可以看到pps大概是100万：
![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/87a6b32986859828dc3b5f2de3d4f430.png)

另外检查lvs，也没看到有进出丢包的问题：
![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/3754ba7ac526423eba8e20f7d2953ae1.png)

所以网络因素被排除，另外做压测的时候反复从Tomcat上ping 后面的MySQL，rt跟没有压力的时候一样，也说明了网络没有问题。

## 问题的确认

尝试在Tomcat上打开慢查询，并将慢查询阈值设置为100ms，这个时候确实能从日志中看到大量MySQL上的慢查询，因为这个SQL需要在Tomcat上做拆分成256个SQL，同时下发，一旦有一个SQL返回慢，整个请求就因为这个短板被拖累了。平均rt0.8ms，但是经常有超过100ms的话对整体影响还是很大的。

将Tomcat记录下来的慢查询（Tomcat增加了一个唯一id下发给MySQL）到MySQL日志中查找，果然发现MySQL上确实慢了，所以到这里基本确认是MySQL的问题，终于不用再纠结是否是网络问题了。

同时在Tomcat进行抓包，对网卡上的rt进行统计分析：

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/ffd66d9a6098979b555dfb00d3494255.png)

这是Tomcat上抓到的每个sql的物理rt 平均值，上面是QPS 430的时候，rt 0.6ms，下面是3个server，QPS为700，但是rt上升到了0.9ms，基本跟Tomcat监控记录到的物理rt一致。如果MySQL上也有类似抓包计算rt时间的话可以快速排除网络问题。

网络抓包得到的rt数据更容易被所有人接受。尝试过在MySQL上抓包，但是因为slb模块的原因，进出端口、ip都被修改过，所以没法分析一个流的响应时间。

## 重心再次转向MySQL

这个时候因为问题点基本确认，再去查看MySQL是否有问题的重心都不一样了，不再只是看看CPU和慢查询，这个问题明显更复杂一些。

通过监控发现MySQL CPU虽然一直不高，但是经常看到running thread飙到100多，很快又降下去了，看起来像是突发性的并发查询请求太多导致了排队等待，每个MySQL实例是8Core的CPU，尝试将MySQL实例扩容到16Core（只是为了验证这个问题），QPS确实可以上升到1000（没有到达理想的1400）。

这是Tomcat上监控到的MySQL状态（Tomcat的监控还是很给力的)：
![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/e73c1371a02106a52f8a13f89a9dd9ad.png)

同时在MySQL机器上通过vmstat也可以看到这种飙升：
![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/4dbd9dff9deacec0e9911e3a7d025578.png)

另外像这种短暂突发性的并发流量似乎监控都很难看到（基本都被平均掉了），只有一些实时性监控偶尔会采集到这种短暂突发性飙升，这也导致了一开始忽视了MySQL

所以接下来的核心问题就是MySQL为什么会有这种飙升、这种飙升的影响到底是什么？

## MySQL部署awr

步骤：

1. 打开performance_schema；设置参数performance_schema=on
2. 压测前后调用调用 call awr_snapshot('memo');  memo 是你希望给这次测试设置的标签
3. 查看的时候，先call awr_list_snapshot(); 找到你对应的那次测试，再运行call awr_report(1,2); 1/2对应你测试的开始、结束snapshot ID

通过awr将performance_schema打开，并采集一些MySQL数据(SQL/CPU/Lock/Mutex等等)进行统计分析

可以清楚地看到一些锁等待：

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/481d7bef3dc0a1fbe20ab9cf01978a7c.png)
从上图可以看到主要是select wait比较多，符合业务场景（都是 select sum语句），这里wait是98%，QPS为38000的时候wait才88%。

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/745790bf9b7562cc60bf311c7963c983.png)

从这里可以看到fil_system_mutex锁等待比较多，但是还是不清楚这个锁是怎么产生的，得怎么优化掉。QPS为38000的时候这个等待才 10%

## perf top

直接上 perf ，发现ut_delay高得不符合逻辑：

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/cd145c494c074e01e9d2d1d5583a87a0.png)

展开看一下，基本是在优化器中做索引命中行数的选择：

<img src="https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/46d5f5ee5c58d7090a71164e645ccf79.png" alt="image.png" style="zoom: 67%;" />

跟直接在MySQL命令行中通过 show processlist看到的基本一致：

<img src="https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/89cccebe41a8b8461ea75586b61b929f.png" alt="image.png" style="zoom:50%;" />

主要是优化器在做statistics的时候需要对索引进行统计，统计的时候要加锁，thread running抖动时对应的通过show processlist看到很多thread处于 statistics 状态。

这里ut_delay 消耗了28%的CPU肯定太不正常了，于是将 innodb_spin_wait_delay 从 30 改成 6 后性能立即上去了，继续增加Tomcat节点，QPS也可以线性增加。

耗CPU最高的调用函数栈是…`mutex_spin_wait`->`ut_delay`，属于锁等待的逻辑。InnoDB在这里用的是自旋锁，锁等待是通过调用ut_delay做空循环实现的，会消耗比较高的CPU。也就是通过高CPU消耗尽量来避免等锁的时候上下文切换。

## 最终的性能

调整到MySQL官方默认配置innodb_spin_wait_delay=6 后在4个Tomcat节点下，并发40时，QPS跑到了1700，物理rt：0.7，逻辑rt：19.6，cpu：90%，这个时候只需要继续扩容Tomcat节点的数量就可以增加QPS
19.6，cpu：90%
![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/48c976f989747266f9892403794996c0.png)

再跟调整前比较一下，innodb_spin_wait_delay=30，并发40时，QPS 500+，物理rt：2.6ms 逻辑rt：72.1ms cpu：37%
![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/fdb459972926cff371f5f5ab703790bb.png)

再看看调整前压测的时候的vmstat和tsar --cpu，可以看到process running抖动明显
![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/4dbd9dff9deacec0e9911e3a7d025578.png)

对比修改delay后的process running就很稳定了，即使QPS大了3倍
![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/ed46d35161ea28352acd4289a3e9ddad.png)

## 关于 innodb_spin_wait_delay

innodb通过大量的自旋锁来用高CPU消耗避免CS，这是自旋锁的正确使用方式，但是在多个核的情况下，多核一起自旋抢同一个锁，容易造成cache ping-pong，进而多个CPU核之间会互相使对方缓存部分无效。所以这里[innodb通过增加innodb_spin_wait_delay和pause配合来缓解cache ping-pong](https://dev.mysql.com/doc/refman/5.7/en/innodb-performance-spin_lock_polling.html)，也就是本来要高速通过CPU自旋抢锁的，换成了抢锁失败后 delay一下（Pause）但是不释放CPU，delay时间到后继续抢锁，也就是把连续的自旋抢锁转换成了更稀疏的点状的抢锁（间隔的delay是个随机数--机关枪换成左轮手枪，避免卡壳），这样不但避免了CS也大大减少了cache ping-pong. 

多线程竞争锁的时候，加锁失败的线程会“忙等待”，直到它拿到锁。什么叫“忙等待”呢？它并不意味着一直执行 CAS 函数，生产级的自旋锁在“忙等待”时，会与 CPU 紧密配合 ，它通过 CPU 提供的 PAUSE 指令，减少循环等待时的cache ping-pong和耗电量；对于单核 CPU，忙等待并没有意义，此时它会主动把线程休眠。

> 比如：Java中的Random.getInt() 随机数生成的时候如果多线程共用一个Random，会造成CAS总是失败，导致CPU很高，效率很低

CPU专为自旋锁设计了pause指令，一旦自旋抢锁失败先pause一下，只是这个pause对于innodb来说pause的还不够久，所以需要 innodb_spin_wait_delay 来将pause放大一些。

在我们的这个场景下对每个SQL的rt抖动非常敏感（放大256倍），所以过高的delay会导致部分SQL rt变高。

函数 ut_delay(ut_rnd_interval(0, srv_spin_wait_delay)) 用来执行这个delay：

	/***************************MySQL代码****************************//**
	Runs an idle loop on CPU. The argument gives the desired delay
	in microseconds on 100 MHz Pentium + Visual C++.
	@return dummy value */
	UNIV_INTERN
	ulint
	ut_delay(ulint delay)  //delay 是[0,innodb_spin_wait_delay)之间的一个随机数
	{
	        ulint   i, j;
	
	        UT_LOW_PRIORITY_CPU();
	
	        j = 0;
	
	        for (i = 0; i < delay * 50; i++) {  //delay 放大50倍
	                j += i;
	                UT_RELAX_CPU();             //cpu Pause
	        }
	
	        UT_RESUME_PRIORITY_CPU();
	
	        return(j);
	}
	
	// kernel 自旋锁部分代码
	while (true) {
	  //因为判断lock变量的值比CAS操作更快，所以先判断lock再调用CAS效率更高
	  if (lock == 0 &&  CAS(lock, 0, pid) == 1) return;
	  
	  if (CPU_count > 1 ) { //如果是多核CPU，“忙等待”才有意义
	      for (n = 1; n < 2048; n <<= 1) {//pause的时间，应当越来越长
	        for (i = 0; i < n; i++) pause();//CPU专为自旋锁设计了pause指令
	        if (lock == 0 && CAS(lock, 0, pid)) return;//pause后再尝试获取锁
	      }
	  }
	  sched_yield();//单核CPU，或者长时间不能获取到锁，应主动休眠，让出CPU
	}
	
	//MySQL 8.0 针对PAUSE，源码中新增了spin_wait_pause_multiplier参数，来替换之前写死的循环次数。

innodb_spin_wait_delay的默认值为6. spin 等待延迟是一个动态全局参数，您可以在MySQL选项文件（my.cnf或my.ini）中指定该参数，或者在运行时使用SET GLOBAL 来修改。在我们的MySQL配置中默认改成了30，导致了这个问题。

### pause 和 spinlock

spinlock(自旋锁)是内核中最常见的锁，它的特点是：等待锁的过程中不休眠，而是占着CPU空转，优点是避免了上下文切换的开销，缺点是该CPU空转属于浪费, 同时还有可能导致cache ping-pong，**spinlock适合用来保护快进快出的临界区**。持有spinlock的CPU不能被抢占，持有spinlock的代码不能休眠 http://linuxperf.com/?p=138

### pause 和 cpu_relax

内核频繁使用 cpu_relax 函数，顺序锁 (seqlock) 就是其中的典型代表。cpu_relax 人如其名，它有两个作用：

- 主动让出cpu，小憩一会儿（一般是100ns左右），避免恶性竞争；
- 释放cpu占用的流水线资源。既可以降低功耗，在SMT中还可以让邻居HyperThread跑的更快；



对于顺序锁而言，cpu_relax 尤为关键：

- 锁一般是全局变量，各个cpu持续不断的轮询锁状态（读操作），会给系统总线（CCIX / UPI）、内存控制器造成很大的带宽压力，使得访存延迟恶化。
- cache coherence 维护代价增加；一旦某个cpu获得锁，需要写全局变量，然后会逐一通知其它cpu上的cacheline 失效； 这也会增加延迟。

由此可见，正确实现 cpu_relax 函数的语义，对内核是很有意义的。cpu_relax 的实现与处理器微架构有关，x86下是用pause来实现，而arm下是用的yield来实现，yield 指令的实现退化为 nop 指令，执行非常非常快，也就是一个circle。yield指令的IPC能达到3.99，而pause的IPC才0.03(intel 8260芯片)。

### Skylake架构的8163 和 Broadwell架构 E5-2682 CPU型号的不同

cpu_relax/UT_RELAX_CPU()的汇编指令为pause，在CPU指令同步数据时进行等待的空转，**在pause期间，同一个core上的HT可以执行其他指令**。

在Intel 64-ia-32-architectures-optimization-manual手册中提到：
The latency of the PAUSE instruction in prior generation microarchitectures is about 10 cycles, whereas in Skylake microarchitecture it has been extended to as many as 140 cycles.

> [The PAUSE instruction can improves the performance](https://xem.github.io/minix86/manual/intel-x86-and-64-manual-vol3/o_fe12b1e2a880e0ce-302.html) of processors supporting Intel Hyper-Threading Technology when executing “spin-wait loops” and other routines where one thread is accessing a shared lock or semaphore in a tight polling loop. When executing a spin-wait loop, the processor can suffer a severe performance penalty when exiting the loop because it detects a possible memory order violation and flushes the core processor’s pipeline. The PAUSE instruction provides a hint to the processor that the code sequence is a spin-wait loop. The processor uses this hint to avoid the memory order violation and prevent the pipeline flush. In addition, the PAUSE instruction de-
> pipelines the spin-wait loop to prevent it from consuming execution resources excessively and consume power needlessly. (See[ Section 8.10.6.1, “Use the PAUSE Instruction in Spin-Wait Loops,” for more ](https://xem.github.io/minix86/manual/intel-x86-and-64-manual-vol3/o_fe12b1e2a880e0ce-305.html)information about using the PAUSE instruction with IA-32 processors supporting Intel Hyper-Threading Technology.)



**Skylake架构的CPU的PAUSE指令从之前的10 cycles提升到140 cycles。**

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/f712640a787655ad1bcddec4c65215e5.png)

可以看到V52的CPU绝大部分时间消耗在ut_delay函数上。（注：V42和V52表示两种不同的机型，他们使用的CPU型号不一样）

使用pqos观测CPU的IPC指标：
在128并发写入场景下，V42 CPU的IPC为0.35左右，而V52 CPU的IPC只有0.18

> 说明：IPC是单位时钟周期的指令数，反映当前场景下，CPU的执行效率

MySQL使用innodb_spin_wait_delay控制spin lock等待时间，等待时间时间从0\*50个pause到innodb_spin_wait_delay\*50个pause。
线上innodb_spin_wait_delay默认配置30，对于V42 CPU，等待的最长时间为：
30 \* 50 \* 10=15000 cycles，对于2.5GHz的CPU，等待时间为6us。
对应计算V52 CPU的等待时间：30 \*50 \*140=210000 cycles，CPU主频也是2.5GHz，等待时间84us。

E5-2682 CPU型号在不同的delay参数和不同并发压力下的写入性能数据：

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/9377127947c23dd166f6aa399b6a89b9.png)

Skylake 8163 CPU型号在不同的delay参数和不同并发压力下的写入性能数据：

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/d567449fe52725a9d0b9d4ec9baa372c.png)

因为8163的cycles从10改到了140，所以可以看到delay参数对性能的影响更加陡峻。

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/d0b0687ab72cfb785441bfb343b9f948.png)

#### 不同的架构下的参数


![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/e4a2fb522be7aa65158778b7ea825207.png)

### cache 一致性

Cache Line 是 CPU 和主存之间数据传输的最小单位。当一行 Cache Line 被从内存拷贝到 Cache 里，Cache 里会为这个 Cache Line 创建一个条目。
这个 Cache 条目里既包含了拷贝的内存数据，即 Cache Line，又包含了这行数据在内存里的位置等元数据信息。

处理器都实现了 Cache 一致性 (Cache Coherence）协议。如历史上 x86 曾实现了[ MESI 协议](https://en.wikipedia.org/wiki/MESI_protocol)，以及 MESIF 协议。

假设两个处理器 A 和 B, 都在各自本地 Cache Line 里有同一个变量的拷贝时，此时该 Cache Line 处于 Shared 状态。当处理器 A 在本地修改了变量，除去把本地变量所属的 Cache Line 置为 Modified 状态以外，
还必须在另一个处理器 B 读同一个变量前，对该变量所在的 B 处理器本地 Cache Line 发起 Invaidate 操作，标记 B 处理器的那条 Cache Line 为 Invalidate 状态。
随后，若处理器 B 在对变量做读写操作时，如果遇到这个标记为 Invalidate 的状态的 Cache Line，即会引发 Cache Miss，从而将内存中最新的数据拷贝到 Cache Line 里，然后处理器 B 再对此 Cache Line 对变量做读写操作。

cache ping-pong(cache-line ping-ponging) 是指不同的CPU共享位于同一个cache-line里边的变量，当不同的CPU频繁的对该变量进行读写时，会导致其他CPU cache-line的失效。

#### 查看cache line

```
#飞腾(FT2500), ARMv8架构，主频2.1G，服务器两路，每路64个物理core，没有超线程，总共16个numa，每个numa 8个core
#getconf -a | grep CACHE
LEVEL1_ICACHE_SIZE                 0
LEVEL1_ICACHE_ASSOC                0
LEVEL1_ICACHE_LINESIZE             64  //64 字节
LEVEL1_DCACHE_SIZE                 0
LEVEL1_DCACHE_ASSOC                0
LEVEL1_DCACHE_LINESIZE             64
LEVEL2_CACHE_SIZE                  0
LEVEL2_CACHE_ASSOC                 0
LEVEL2_CACHE_LINESIZE              0
LEVEL3_CACHE_SIZE                  0
LEVEL3_CACHE_ASSOC                 0
LEVEL3_CACHE_LINESIZE              0
LEVEL4_CACHE_SIZE                  0
LEVEL4_CACHE_ASSOC                 0
LEVEL4_CACHE_LINESIZE              0

#intel Xeon Platinum 8269
# getconf -a | grep CACHE
LEVEL1_ICACHE_SIZE                 32768
LEVEL1_ICACHE_ASSOC                8
LEVEL1_ICACHE_LINESIZE             64
LEVEL1_DCACHE_SIZE                 32768
LEVEL1_DCACHE_ASSOC                8
LEVEL1_DCACHE_LINESIZE             64
LEVEL2_CACHE_SIZE                  1048576
LEVEL2_CACHE_ASSOC                 16
LEVEL2_CACHE_LINESIZE              64
LEVEL3_CACHE_SIZE                  37486592
LEVEL3_CACHE_ASSOC                 11
LEVEL3_CACHE_LINESIZE              64
LEVEL4_CACHE_SIZE                  0
LEVEL4_CACHE_ASSOC                 0
LEVEL4_CACHE_LINESIZE              0
```

#### Cache Line 伪共享

Cache Line 伪共享问题，就是由多个 CPU 上的多个线程同时修改自己的变量引发的。这些变量表面上是不同的变量，但是实际上却存储在同一条 Cache Line 里（Cache Line 失效的最小单位是整个Line，而不是一个变量）。
在这种情况下，由于 Cache 一致性协议，两个处理器都存储有相同的 Cache Line 拷贝的前提下，本地 CPU 变量的修改会导致本地 Cache Line 变成 Modified 状态，然后在其它共享此 Cache Line 的 CPU 上，
引发 Cache Line 的 Invaidate 操作，导致 Cache Line 变为 Invalidate 状态，从而使 Cache Line 再次被访问时，发生本地 Cache Miss，从而伤害到应用的性能。
在此场景下，多个线程在不同的 CPU 上高频反复访问这种 Cache Line 伪共享的变量，则会因 Cache 颠簸引发严重的性能问题。

#### [MESI protocol](https://en.wikipedia.org/wiki/MESI_protocol)

MySQL 这里读取Mutex or rw-lock 会导致其它core的cache line 失效，这个读取应该不是一个 Shared读，猜测是一个Exclusive读（加锁成功肯定会Modified），意味着读取就会让其他 cache line失效。

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/2a5245c81a37d166c7e0b2ace45b9e4b.png)

我们举个具体的例子来看看这四个状态的转换：

1. 当 A 号 CPU 核心从内存读取变量 i 的值，数据被缓存在 A 号 CPU 核心自己的 Cache 里面，此时其他 CPU 核心的 Cache 没有缓存该数据，于是标记 Cache Line 状态为「独占」，此时其 Cache 中的数据与内存是一致的；
2. 然后 B 号 CPU 核心也从内存读取了变量 i 的值，此时会发送消息给其他 CPU 核心，由于 A 号 CPU 核心已经缓存了该数据，所以会把数据返回给 B 号 CPU 核心。在这个时候， A 和 B 核心缓存了相同的数据，Cache Line 的状态就会变成「共享」，并且其 Cache 中的数据与内存也是一致的；
3. 当 A 号 CPU 核心要修改 Cache 中 i 变量的值，发现数据对应的 Cache Line 的状态是共享状态，则要向所有的其他 CPU 核心广播一个请求，要求先把其他核心的 Cache 中对应的 Cache Line 标记为「无效」状态，**然后 A 号 CPU 核心才更新 Cache 里面的数据，同时标记 Cache Line 为「已修改」状态，此时 Cache 中的数据就与内存不一致了**。
4. 如果 A 号 CPU 核心「继续」修改 Cache 中 i 变量的值，由于此时的 Cache Line 是「已修改」状态，因此不需要给其他 CPU 核心发送消息，直接更新数据即可。
5. 如果 A 号 CPU 核心的 Cache 里的 i 变量对应的 Cache Line 要被「替换」，发现 Cache Line 状态是「已修改」状态，就会在替换前先把数据同步到内存。

![img](/Users/ren/src/blog/951413iMgBlog/fa98835c78c879ab69fd1f29193e54d1.jpeg)

可以发现当 Cache Line 状态是「已修改」或者「独占」状态时，修改更新其数据不需要发送广播给其他 CPU 核心，这在一定程度上减少了总线带宽压力。 

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/29c4ae48501984787dfc232e4673b86d.png)

如果内存中的数据已经在 CPU Cache 中了，那 CPU 访问一个内存地址的时候，会经历这 4 个步骤：

1. 根据内存地址中索引信息，计算在 CPU Cache 中的索引，也就是找出对应的 CPU Line 的地址；
2. 找到对应 CPU Line 后，判断 CPU Line 中的有效位，确认 CPU Line 中数据是否是有效的，如果是无效的，CPU 就会直接访问内存，并重新加载数据，如果数据有效，则往下执行；
3. 对比内存地址中组标记和 CPU Line 中的组标记，确认 CPU Line 中的数据是我们要访问的内存数据，如果不是的话，CPU 就会直接访问内存，并重新加载数据，如果是的话，则往下执行；
4. 根据内存地址中偏移量信息，从 CPU Line 的数据块中，读取对应的字。

（题外话：**除了提高cache line命中率外还得考虑分支预测准确性，这两对提升cpu运算性能有非常大的帮助**）

在NUMA架构中，多个处理器中的同一个缓存页面必定在其中一个处理器中属于 F 状态(可以修改的状态)，这个页面在这个处理器中没有理由不可以多核心共享(可以多核心共享就意味着这个能进入修改状态的页面的多个有效位被设置为一)。MESIF协议应该是工作在核心(L1+L2)层面而不是处理器(L3)层面，这样同一处理器里多个核心共享的页面，只有其中一个是出于 F 状态(可以修改的状态)。见后面对 NUMA 和 MESIF 的解析。(L1/L2/L3 的同步应该是不需要 MESIF 的同步机制)

## 分析源代码

另外分析了MySQL源代码后，在select中通过使用force index来绕过优化器是可以达到相同的效果（不再走statistics流程，也就不会有这个锁争抢了）

从下面的源代码中可以看到perf top中fil_space_get，在这个函数里面确实会对fil_system_mutex加锁（跟awr监控对应上了）

	/** Look up a tablespace.
	The caller should hold an InnoDB table lock or a MDL that prevents
	the tablespace from being dropped during the operation,
	or the caller should be in single-threaded crash recovery mode
	(no user connections that could drop tablespaces).
	If this is not the case, fil_space_acquire() and fil_space_release()
	should be used instead.
	@param[in]      id      tablespace ID
	@return tablespace, or NULL if not found */
	fil_space_t*
	fil_space_get(
	        ulint   id)
	{
	        mutex_enter(&fil_system->mutex);
	        fil_space_t*    space = fil_space_get_by_id(id);
	        mutex_exit(&fil_system->mutex);
	        ut_ad(space == NULL || space->purpose != FIL_TYPE_LOG);
	        return(space);
	}


btr_estimate_n_rows_in_range_low会调用btr_estimate_n_rows_in_range_on_level, btr_estimate_n_rows_in_range_on_level中调用 fil_space_get

const fil_space_t*      space = fil_space_get(index->space);

	/** Estimates the number of rows in a given index range.
	@param[in]      index           index
	@param[in]      tuple1          range start, may also be empty tuple
	@param[in]      mode1           search mode for range start
	@param[in]      tuple2          range end, may also be empty tuple
	@param[in]      mode2           search mode for range end
	@param[in]      nth_attempt     if the tree gets modified too much while
	we are trying to analyze it, then we will retry (this function will call
	itself, incrementing this parameter)
	@return estimated number of rows; if after rows_in_range_max_retries
	retries the tree keeps changing, then we will just return
	rows_in_range_arbitrary_ret_val as a result (if
	nth_attempt >= rows_in_range_max_retries and the tree is modified between
	the two dives). */
	static
	int64_t
	btr_estimate_n_rows_in_range_low(
	        dict_index_t*   index,
	        const dtuple_t* tuple1,
	        page_cur_mode_t mode1,
	        const dtuple_t* tuple2,
	        page_cur_mode_t mode2,
	        unsigned        nth_attempt)
	
	/*******************************************************************//**
	Estimate the number of rows between slot1 and slot2 for any level on a
	B-tree. This function starts from slot1->page and reads a few pages to
	the right, counting their records. If we reach slot2->page quickly then
	we know exactly how many records there are between slot1 and slot2 and
	we set is_n_rows_exact to TRUE. If we cannot reach slot2->page quickly
	then we calculate the average number of records in the pages scanned
	so far and assume that all pages that we did not scan up to slot2->page
	contain the same number of records, then we multiply that average to
	the number of pages between slot1->page and slot2->page (which is
	n_rows_on_prev_level). In this case we set is_n_rows_exact to FALSE.
	@return number of rows, not including the borders (exact or estimated) */
	static
	int64_t
	btr_estimate_n_rows_in_range_on_level(
	/*==================================*/
	        dict_index_t*   index,                  /*!< in: index */
	        btr_path_t*     slot1,                  /*!< in: left border */
	        btr_path_t*     slot2,                  /*!< in: right border */
	        int64_t         n_rows_on_prev_level,   /*!< in: number of rows
	                                                on the previous level for the
	                                                same descend paths; used to
	                                                determine the number of pages
	                                                on this level */
	        ibool*          is_n_rows_exact)        /*!< out: TRUE if the returned
	                                                value is exact i.e. not an
	                                                estimation */



JOIN::estimate_row_count 是优化器估计行数的调用。 CBO 需要获得扫描行数数量，计算各访问路径的代价，确定哪个访问路径更好。在 MySQL 社区版，支持索引下探 (records_in_range) 和索引 key ndv (records_in_key) 来估计行数，但默认是索引下探（文中 perf 调用栈）。本文的查询是简单查询，而 force index 固定了访问路径，所以可以忽略行数估计，跳过下探逻辑。

顺便说一下， RDS MySQL 8.0 Outline 功能可以在 server 端 force index ，避免对应用代码的侵入。此外 PolarDB MySQL 里新增加了根据直方图来估计行数的功能，并且增强了直方图，可以有效应对这种场景。我们也在开发执行计划的锁定和演进功能，相信这类场景后面都可以系统化地解决掉。

## perf top 和 pause 的案例

案例：

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/864427c491497acb02d37c02cb35eeb2.png)

对如上两个pause指令以及一个 count++（addq），进行perf top：

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/40945b005eb9f716e429fd30be55b6d1.png)

可以看到第一个pasue在perf top中cycles为0，第二个为46.85%，另外一个addq也有48.83%，基本可以猜测perf top在这里数据都往后挪了一个。

**问题总结：**
 我们知道perf top是通过读取PMU的PC寄存器来获取当前执行的指令进而根据汇编的symbol信息获得是执行的哪条指令。所以看起来CPU在执行pause指令的时候，从PMU中看到的PC值指向到了下一条指令，进而导致我们看到的这个现象。通过查阅《Intel® 64 and IA-32 Architectures Optimization Reference Manual》目前还无法得知这是CPU的一个设计缺陷还是PMU的一个bug(需要对pause指令做特殊处理)。**不管怎样，这个实验证明了我们统计spin lock的CPU占比还是准确的，不会因为pause指令导致PMU采样出错导致统计信息的整体失真。只是对于指令级的CPU统计，我们能确定的就是它把pause的执行cycles 数统计到了下一条指令。**

**补充说明：**

​    **经过测试，非skylake CPU也同样存在perf top会把pause(执行数cycles是10)的执行cycles数统计到下一条指令的问题，看来这是X86架构都存在的问题。**

## 总结分析

CPU 架构不同Pause 指令的需要的CPU Cycles不同导致了 MySQL innodb_spin_wait_delay 在spin lock失败的时候（此时需要 pause* innodb_spin_wait_delay*N）delay更久，使得调用方看到了MySQL更大的rt，进而Tomcat Server上并发跑不起来，所以最终压力上不去。

在长链路的排查中，细化定位是哪个节点出了问题是最难的，这里大量的时间都花在了client、slb、Tomcat节点等等有没有问题，就是因为MySQL有32个节点，他们的CPU都不高，让大家很快排除了他的嫌疑。

在一开始排除MySQL嫌疑(主要是这种场景下对抖动太敏感了)后花了大量的工作在简化链路上，实际因为他们都不是瓶颈，所以没有任何效果。

在极端环境下（比如没有网络、工具不健全）排查问题太困难了，比如这个问题MySQL早装perf可能很快就发现了问题。

这种一个查询分成多个查询的业务逻辑受短板影响明显，短板进而受抖动影响明显（比如这里的随机delay）。

应用的Tomcat横向扩展是非常可靠的，应用Tomcat统计出来的物理rt是绝对可信的，经过这次案例后续大家应该会更加相信应用的监控。

增加并发压力的时候MySQL rt增加很明显是最关键的证据（即使MySQL CPU很闲，但是总的MySQL平均rt也才0.9ms让我们一开始有点疏忽了），所以这种场景下还要多看长尾。

欲速则不达，做压测的时候还是要老老实实地从一个并发开始观察QPS、rt，然后一直增加压力到压不上去了，再看QPS、rt变化，然后确认瓶颈点。

关于这个抖动对整体rt的影响计算：

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/c47d2bd0e4d9d0f005d0e1132b385eab.png)

## 参考文章

https://cloud.tencent.com/developer/article/1005284

[mysql doc](https://dev.mysql.com/doc/refman/5.7/en/innodb-performance-spin_lock_polling.html)

[Cache Line 伪共享发现与优化](http://oliveryang.net/2018/01/cache-false-sharing-debug)

[intel spec](https://en.wikichip.org/w/images/e/eb/intel-ref-248966-037.pdf)

[与程序员相关的CPU缓存知识](https://coolshell.cn/articles/20793.html) 

[Intel PAUSE指令变化影响到MySQL的性能，该如何解决？](https://mp.weixin.qq.com/s/dlKC13i9Z8wjDDiU2tig6Q)

https://www.atatech.org/articles/85549

[关于CPU Cache -- 程序猿需要知道的那些事](http://cenalulu.github.io/linux/all-about-cpu-cache/)

[ARM软硬件协同设计：锁优化](https://topic.atatech.org/articles/173194), arm不同于x86，用的是yield来代替pause，yield 指令的实现退化为 nop 指令，执行时间非常非常锻，也就是一个circle。yield指令的IPC能达到3.99，而pause的IPC才0.03(intel 8260芯片)