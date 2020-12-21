---
title: Perf IPC以及CPU利用率
date: 2020-05-31 12:30:03
categories: Linux
tags:
    - perf
    - IPC
    - CPU
    - pipeline
---

# Perf IPC以及CPU利用率

## perf 使用

可以通过perf看到cpu的使用情况：

	$sudo perf stat -a -- sleep 10

 	Performance counter stats for 'system wide':

     239866.330098      task-clock (msec)         #   23.985 CPUs utilized    /10*1000        (100.00%)
            45,709      context-switches          #    0.191 K/sec                    (100.00%)
             1,715      cpu-migrations            #    0.007 K/sec                    (100.00%)
            79,586      page-faults               #    0.332 K/sec
     3,488,525,170      cycles                    #    0.015 GHz                      (83.34%)
     9,708,140,897      stalled-cycles-frontend   #  278.29% /cycles frontend cycles idle     (83.34%)
     9,314,891,615      stalled-cycles-backend    #  267.02% /cycles backend  cycles idle     (66.68%)
     2,292,955,367      instructions              #    0.66  insns per cycle  insn/cycles
                                                 #    4.23  stalled cycles per insn stalled-cycles-frontend/insn (83.34%)
       447,584,805      branches                  #    1.866 M/sec                    (83.33%)
         8,470,791      branch-misses             #    1.89% of all branches          (83.33%)


![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/f96e50b5f3d0825b68be5b654624f839.png)

cycles：CPU时钟周期。CPU从它的指令集(instruction set)中选择指令执行。一个指令包含以下的步骤，每个步骤由CPU的一个叫做功能单元(functional unit)的组件来进行处理，每个步骤的执行都至少需要花费一个时钟周期。

- 	指令读取(instruction fetch， IF)
- 	指令解码(instruction decode， ID)
- 	执行(execute， EXE)
- 	内存访问(memory access，MEM)
- 	寄存器回写(register write-back， WB)

![](http://static.oschina.net/uploads/space/2018/0330/193750_LPcO_2896894.png)

五个步骤只能串行，但是可以做成pipeline提升效率，也就是第一个指令做第二步的时候，指令读取单元可以去读取下一个指令了，如果有一个指令慢就会造成stall，也就是pipeline有地方卡壳了。
另外cpu可以同时有多条pipeline，这也就是理论上最大的ipc.
stalled-cycles，则是指令管道未能按理想状态发挥并行作用，发生停滞的时钟周期。stalled-cycles-frontend指指令读取或解码的指令步骤，而stalled-cycles-backend则是指令执行步骤。第二列中的cycles idle其实意思跟stalled是一样的，由于指令执行停滞了，所以指令管道也就空闲了，千万不要误解为CPU的空闲率。这个数值是由stalled-cycles-frontend或stalled-cycles-backend除以上面的cycles得出的

- 非流水线：

![img](http://static.oschina.net/uploads/space/2018/0330/195430_76ME_2896894.png)

对于非流水计算机而言，上一条指令的 5 个子过程全部执行完毕后才能开始下一条指令，每隔 5 个时 钟周期才有一个输出结果。因此，图3中用了 15 个时钟周期才完成 3 条指令，每条指令平均用时 5 个时钟周期。 非流水线工作方式的控制比较简单，但部件的利用率较低，系统工作速度较慢。

毫无疑问，非流水线效率很低下，5个单元同时只能有一个单元工作，每隔 5 个时 钟周期才有一个输出结果。每条指令用时5个时间周期。

- 标量流水线, 标量（Scalar）流水计算机是**只有一条指令流水线**的计算机:


![](http://static.oschina.net/uploads/space/2018/0330/195701_ce0y_2896894.png)

 对标量流水计算机而言，上一条指令与下一条指令的 5 个子过程在时间上可以重叠执行，当流水线满 载时，每一个时钟周期就可以输出一个结果。因此，图中仅用了 9 个时钟周期就完成了 5 条指令，每条指令平均用时 1.8 个时钟周期。

采用标量流水线工作方式，**虽然每条指令的执行时间并未缩短，但 CPU 运行指令的总体速度却能成倍 提高**。当然，作为速度提高的代价，需要增加部分硬件才能实现标量流水。

- 超标量流水线：所谓超标量（Superscalar）流 水计算机，是指它**具有两条以上的指令流水线**


![](http://static.oschina.net/uploads/space/2018/0330/200055_5w6G_2896894.png)

当流水线满载时，每一个时钟周期可以执行 2 条以上的指令。图中仅用了 9 个时钟周期就完成了 10 条指令，每条指令平均用时 0.9 个时钟周期。 超标量流水计算机是时间并行技术和空间并行技术的综合应用。

在流水计算机中，指令的处理是重叠进行的，前一条指令还没有结束，第二、三条指令就陆续开始工 作。由于多条指令的重叠处理，当后继指令所需的操作数刚好是前一指令的运算结果时，便发生数据相关冲突。由于这两条指令的执行顺序直接影响到操作数读取的内容，必须等前一条指令执行完毕后才能执行后一条指令。

**OoOE— Out-of-Order Execution 乱序执行也是在 Pentium Pro 开始引入的**，它有些类似于多线程的概念。**乱序执行是为了直接提升 ILP(Instruction Level Parallelism)指令级并行化的设计**，在多个执行单元的超标量设计当中，一系列的执行单元可以**同时运行**一些**没有数据关联性的若干指令**，**只有需要等待其他指令运算结果的数据会按照顺序执行**，从而总体提升了运行效率。乱序执行引擎是一个很重要的部分，需要进行复杂的调度管理。

## ECS和perf 

在ECS会采集不到 cycles等，cpu-clock、page-faults都是内核中的软事件，cycles/instructions得采集cpu的PMU数据，ECS采集不到这些。

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/a120388ff72d712a4fd176e7cea005cf.png)

## 调度


NMI(non-maskable interrupt)，就是不可屏蔽的中断. NMI通常用于通知操作系统发生了无法恢复的硬件错误，也可以用于系统调试与采样，大多数服务器还提供了人工触发NMI的接口，比如NMI按钮或者iLO命令等。

http://cenalulu.github.io/linux/numa/ numa原理和优缺点案例讲解

正在运行中的用户程序被中断之后，必须等到中断处理例程完成之后才能恢复运行，在此期间即使其它CPU是空闲的也不能换个CPU继续运行，就像被中断牢牢钉在了当前的CPU上，动弹不得，中断处理需要多长时间，用户进程就被冻结多长时间。

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/1d20b6172d4effb7e27feedc06a820f9.png)

Linux kernel把中断分为两部分：hard IRQ和soft IRQ，hard IRQ只处理中断最基本的部分，保证迅速响应，尽量在最短的时间里完成，把相对耗时的工作量留给soft IRQ；soft IRQ可以被hard IRQ中断，如果soft IRQ运行时间过长，也可能会被交给内核线程ksoftirqd去继续完成。
https://mp.weixin.qq.com/s/AzcB1DwqRCoiofOOI88T9Q softirq导致一路CPU使用过高，其它CPU还是闲置，整个系统比较慢

Linux的进程调度有一个不太为人熟知的特性，叫做wakeup affinity，它的初衷是这样的：如果两个进程频繁互动，那么它们很有可能共享同样的数据，把它们放到亲缘性更近的scheduling domain有助于提高缓存和内存的访问性能，所以当一个进程唤醒另一个的时候，被唤醒的进程可能会被放到相同的CPU core或者相同的NUMA节点上。这个特性缺省是打开的，它有时候很有用，但有时候却对性能有伤害作用。设想这样一个应用场景：一个主进程给成百上千个辅进程派发任务，这成百上千个辅进程被唤醒后被安排到与主进程相同的CPU core或者NUMA节点上，就会导致负载严重失衡，CPU忙的忙死、闲的闲死，造成性能下降。https://mp.weixin.qq.com/s/DG1v8cUjcXpa0x2uvrRytA


http://linuxperf.com/?p=197
Linux kernel支持两种实时(real-time)调度策略(scheduling policy)：SCHED_FIFO和SCHED_RR
/proc/sys/kernel/sched_rt_period_us
缺省值是1,000,000 μs (1秒)，表示实时进程的运行粒度为1秒。（注：修改这个参数请谨慎，太大或太小都可能带来问题）。
/proc/sys/kernel/sched_rt_runtime_us
缺省值是 950,000 μs (0.95秒)，表示在1秒的运行周期里所有的实时进程一起最多可以占用0.95秒的CPU时间。
如果sched_rt_runtime_us=-1，表示取消限制，意味着实时进程可以占用100%的CPU时间（慎用，有可能使系统失去控制）。
所以，Linux kernel默认情况下保证了普通进程无论如何都可以得到5%的CPU时间，尽管系统可能会慢如蜗牛，但管理员仍然可以利用这5%的时间设法恢复系统，比如停掉失控的实时进程，或者给自己的shell进程赋予更高的实时优先级以便执行管理任务，等等。

进程自愿切换(Voluntary)和强制切换(Involuntary)的次数被统计在 /proc/<pid>/status 中，其中voluntary_ctxt_switches表示自愿切换的次数，nonvoluntary_ctxt_switches表示强制切换的次数，两者都是自进程启动以来的累计值。 或pidstat -w 1 来统计  http://linuxperf.com/?cat=10
自愿切换发生的时候，进程不再处于运行状态，比如由于等待IO而阻塞(TASK_UNINTERRUPTIBLE)，或者因等待资源和特定事件而休眠(TASK_INTERRUPTIBLE)，又或者被debug/trace设置为TASK_STOPPED/TASK_TRACED状态；
强制切换发生的时候，进程仍然处于运行状态(TASK_RUNNING)，通常是由于被优先级更高的进程抢占(preempt)，或者进程的时间片用完了
如果一个进程的自愿切换占多数，意味着它对CPU资源的需求不高。如果一个进程的强制切换占多数，意味着对它来说CPU资源可能是个瓶颈，这里需要排除进程频繁调用sched_yield()导致强制切换的情况

spinlock(自旋锁)是内核中最常见的锁，它的特点是：等待锁的过程中不休眠，而是占着CPU空转，优点是避免了上下文切换的开销，缺点是该CPU空转属于浪费, 同时还有可能导致cache ping-pong，spinlock适合用来保护快进快出的临界区。持有spinlock的CPU不能被抢占，持有spinlock的代码不能休眠 http://linuxperf.com/?p=138

每个逻辑 CPU 都维护着一个可运行队列，用来存放可运行的线程来调度。

## CPU cache

![](https://images.gitbook.cn/227f3af0-5075-11e9-aece-c5816949b340)

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/f5728a2afb29c653a3e1bf21f4d56056.png)

	cat /proc/cpuinfo |grep -i cache

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/ad19b92ccc97763aa7f78d8d1d514c84.png)

如下 Linux getconf 命令的输出，除了 *_LINESIZE 指示了系统的 Cache Line 的大小是 64 字节外，还给出了 Cache 类别，大小。 其中 *_ASSOC 则指示了该 Cache 是几路关联 (Way Associative) 的。

	$sudo getconf -a |grep CACHE
	LEVEL1_ICACHE_SIZE                 32768
	LEVEL1_ICACHE_ASSOC                8
	LEVEL1_ICACHE_LINESIZE             64
	LEVEL1_DCACHE_SIZE                 32768
	LEVEL1_DCACHE_ASSOC                8
	LEVEL1_DCACHE_LINESIZE             64
	LEVEL2_CACHE_SIZE                  262144
	LEVEL2_CACHE_ASSOC                 4
	LEVEL2_CACHE_LINESIZE              64
	LEVEL3_CACHE_SIZE                  3145728
	LEVEL3_CACHE_ASSOC                 12
	LEVEL3_CACHE_LINESIZE              64
	LEVEL4_CACHE_SIZE                  0
	LEVEL4_CACHE_ASSOC                 0
	LEVEL4_CACHE_LINESIZE              0

## Socket、核

一个Socket理解一个CPU，一个CPU又可以是多核的



## 超线程（Hyperthreading，HT）

一个核还可以进一步分成几个逻辑核，来执行多个控制流程，这样可以进一步提高并行程度，这一技术就叫超线程，有时叫做 simultaneous multi-threading（SMT）。

超线程技术主要的出发点是，当处理器在运行一个线程，执行指令代码时，很多时候处理器并不会使用到全部的计算能力，部分计算能力就会处于空闲状态。而超线程技术就是通过多线程来进一步“压榨”处理器。pipeline进入stalled状态就可以切到其它超线程上

举个例子，如果一个线程运行过程中，必须要等到一些数据加载到缓存中以后才能继续执行，此时 CPU 就可以切换到另一个线程，去执行其他指令，而不用去处于空闲状态，等待当前线程的数据加载完毕。通常，一个传统的处理器在线程之间切换，可能需要几万个时钟周期。而一个具有 HT 超线程技术的处理器只需要 1 个时钟周期。因此就大大减小了线程之间切换的成本，从而最大限度地让处理器满负荷运转。

## 参考资料

[perf详解]( https://zhengheng.me/2015/11/12/perf-stat/)

[CPU体系结构](https://www.atatech.org/articles/109158)

[震惊，用了这么多年的 CPU 利用率，其实是错的](https://mp.weixin.qq.com/s/KaDJ1EF5Y-ndjRv2iUO3cA)cpu占用不代表在做事情，可能是stalled，也就是流水线卡顿，但是cpu占用了，实际没事情做。

