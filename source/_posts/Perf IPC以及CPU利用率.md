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

## CPU 流水线工作原理

cycles：CPU时钟周期。CPU从它的指令集(instruction set)中选择指令执行。一个指令包含以下的步骤，每个步骤由CPU的一个叫做功能单元(functional unit)的组件来进行处理，每个步骤的执行都至少需要花费一个时钟周期。

- 	指令读取(instruction fetch， IF)
- 	指令解码(instruction decode， ID)
- 	执行(execute， EXE)
- 	内存访问(memory access，MEM)
- 	寄存器回写(register write-back， WB)

![image-20210511154816751](/Users/ren/src/blog/951413iMgBlog/image-20210511154816751.png)

五个步骤只能串行，但是可以做成pipeline提升效率，也就是第一个指令做第二步的时候，指令读取单元可以去读取下一个指令了，如果有一个指令慢就会造成stall，也就是pipeline有地方卡壳了。
另外cpu可以同时有多条pipeline，这也就是理论上最大的IPC.
stalled-cycles，则是指令管道未能按理想状态发挥并行作用，发生停滞的时钟周期。stalled-cycles-frontend指指令读取或解码的指令步骤，而stalled-cycles-backend则是指令执行步骤。第二列中的cycles idle其实意思跟stalled是一样的，由于指令执行停滞了，所以指令管道也就空闲了，千万不要误解为CPU的空闲率。这个数值是由stalled-cycles-frontend或stalled-cycles-backend除以上面的cycles得出的

### Back-end Bound

Back-end Bound 分为 Memory Bound 和 Core Bound，通过在每个周期内基于执行单元的占用情况来分析 Back-end 停顿。为了达到尽可能大的 IPC，需要使得执行单元保持繁忙。例如，在一个有4个 slot 的机器中，如果在稳定状态下只能执行三个或更少的 uOps，就不能达到最佳状态，即 IPC 等于4。这些次优周期称为 Execution Stalls。

- 非流水线：

![image-20210511154859711](/Users/ren/src/blog/951413iMgBlog/image-20210511154859711.png)



对于非流水计算机而言，上一条指令的 5 个子过程全部执行完毕后才能开始下一条指令，每隔 5 个时 钟周期才有一个输出结果。因此，图3中用了 15 个时钟周期才完成 3 条指令，每条指令平均用时 5 个时钟周期。 非流水线工作方式的控制比较简单，但部件的利用率较低，系统工作速度较慢。

毫无疑问，非流水线效率很低下，5个单元同时只能有一个单元工作，每隔 5 个时 钟周期才有一个输出结果。每条指令用时5个时间周期。

- 标量流水线, 标量（Scalar）流水计算机是**只有一条指令流水线**的计算机:

![image-20210511155530477](/Users/ren/src/blog/951413iMgBlog/image-20210511155530477.png)

 对标量流水计算机而言，上一条指令与下一条指令的 5 个子过程在时间上可以重叠执行，当流水线满 载时，每一个时钟周期就可以输出一个结果。因此，图中仅用了 9 个时钟周期就完成了 5 条指令，每条指令平均用时 1.8 个时钟周期。

采用标量流水线工作方式，**虽然每条指令的执行时间并未缩短，但 CPU 运行指令的总体速度却能成倍 提高**。当然，作为速度提高的代价，需要增加部分硬件才能实现标量流水。

- 超标量流水线：所谓超标量（Superscalar）流 水计算机，是指它**具有两条以上的指令流水线**

![image-20210511155708234](/Users/ren/src/blog/951413iMgBlog/image-20210511155708234.png)




当流水线满载时，每一个时钟周期可以执行 2 条以上的指令。图中仅用了 9 个时钟周期就完成了 10 条指令，每条指令平均用时 0.9 个时钟周期。 超标量流水计算机是时间并行技术和空间并行技术的综合应用。

在流水计算机中，指令的处理是重叠进行的，前一条指令还没有结束，第二、三条指令就陆续开始工 作。由于多条指令的重叠处理，当后继指令所需的操作数刚好是前一指令的运算结果时，便发生数据相关冲突。由于这两条指令的执行顺序直接影响到操作数读取的内容，必须等前一条指令执行完毕后才能执行后一条指令。

**OoOE— Out-of-Order Execution 乱序执行也是在 Pentium Pro 开始引入的**，它有些类似于多线程的概念。**乱序执行是为了直接提升 ILP(Instruction Level Parallelism)指令级并行化的设计**，在多个执行单元的超标量设计当中，一系列的执行单元可以**同时运行**一些**没有数据关联性的若干指令**，**只有需要等待其他指令运算结果的数据会按照顺序执行**，从而总体提升了运行效率。乱序执行引擎是一个很重要的部分，需要进行复杂的调度管理。



每一个功能单元的流水线的长度是不同的。事实上，不同的功能单元的流水线长度本来就不一样。我们平时所说的 14 级流水线，指的通常是进行整数计算指令的流水线长度。如果是浮点数运算，实际的流水线长度则会更长一些。

![img](/Users/ren/src/blog/951413iMgBlog/85f15ec667d09fd2d368822904029b32.jpeg)



### 指令缓存（Instruction Cache）和数据缓存（Data Cache）

在第 1 条指令执行到访存（MEM）阶段的时候，流水线里的第 4 条指令，在执行取指令（Fetch）的操作。访存和取指令，都要进行内存数据的读取。我们的内存，只有一个地址译码器的作为地址输入，那就只能在一个时钟周期里面读取一条数据，没办法同时执行第 1 条指令的读取内存数据和第 4 条指令的读取指令代码。

![img](/Users/ren/src/blog/951413iMgBlog/c2a4c0340cb835350ea954cdc520704e.jpeg)

把内存拆成两部分的解决方案，在计算机体系结构里叫作哈佛架构（Harvard Architecture），来自哈佛大学设计Mark I 型计算机时候的设计。我们今天使用的 CPU，仍然是冯·诺依曼体系结构的，并没有把内存拆成程序内存和数据内存这两部分。因为如果那样拆的话，对程序指令和数据需要的内存空间，我们就没有办法根据实际的应用去动态分配了。虽然解决了资源冲突的问题，但是也失去了灵活性。

![img](/Users/ren/src/blog/951413iMgBlog/e7508cb409d398380753b292b6df8391.jpeg)

在流水线产生依赖的时候必须pipeline stall，也就是让依赖的指令执行NOP。

## 每个指令需要的cycle

Intel xeon

![img](/Users/ren/src/blog/951413iMgBlog/v2-73a5cce599828b6c28f6f29bb310687a_1440w.jpg)

## perf 使用

```
sudo perf record -g -a -e skb:kfree_skb //perf 记录丢包调用栈 然后sudo perf script 查看 （网络报文被丢弃时会调用该函数kfree_skb）
perf record -e 'skb:consume_skb' -ag  //记录网络消耗
perf probe --add tcp_sendmsg //增加监听probe  perf record -e probe:tcp_sendmsg -aR sleep 1
sudo perf sched record -- sleep 1 //记录cpu调度的延时
sudo perf sched latency //查看
```

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



## IPC测试

实际运行的时候增加如下nop到100个以上

```
void main() {

    while(1) {
         __asm__ ("nop\n\t"
                 "nop\n\t"
                 "nop");
    }
}
```

鲲鹏920运行，ipc是指每个core的IPC，如果同时运行两个如上测试程序，每个程序的IPC都是3.99

```
#perf stat -- ./nop.out
failed to read counter branches

 Performance counter stats for './nop.out':

       8826.948260      task-clock (msec)         #    1.000 CPUs utilized
                 8      context-switches          #    0.001 K/sec
                 0      cpu-migrations            #    0.000 K/sec
                37      page-faults               #    0.004 K/sec
    22,949,862,030      cycles                    #    2.600 GHz
         2,099,719      stalled-cycles-frontend   #    0.01% frontend cycles idle
        18,859,839      stalled-cycles-backend    #    0.08% backend  cycles idle
    91,465,043,922      instructions              #    3.99  insns per cycle
                                                  #    0.00  stalled cycles per insn
   <not supported>      branches
            33,262      branch-misses             #    0.00% of all branches

       8.827886000 seconds time elapsed
```

intel X86 8260

```
#perf stat -- ./nop.out

 Performance counter stats for './nop.out':

      65061.160345      task-clock (msec)         #    1.001 CPUs utilized
                46      context-switches          #    0.001 K/sec
                92      cpu-migrations            #    0.001 K/sec
               108      page-faults               #    0.002 K/sec
   155,659,827,263      cycles                    #    2.393 GHz
   <not supported>      stalled-cycles-frontend
   <not supported>      stalled-cycles-backend
   603,247,401,995      instructions              #    3.88  insns per cycle
     4,742,051,659      branches                  #   72.886 M/sec
         1,799,428      branch-misses             #    0.04% of all branches

      65.012821629 seconds time elapsed

```

这两块CPU理论IPC最大值都是4，实际x86离理论值更远一些. 增加while循环中的nop数量（从132增加到432个）IPC能提升到3.92

### IPC和超线程的关系

IPC 和一个core上运行多少个进程没有关系。实际测试将两个nop绑定到一个core上，IPC不变, 因为IPC就是从core里面取到的，不针对具体进程。但是如果是两个进程绑定到一个物理core以及对应的超线程core上那么IPC就会减半。如果程序是IO bound（比如需要频繁读写内存）首先IPC远远低于理论值4的，这个时候超线程同时工作的话IPC基本能翻倍

![image-20210513123233344](/Users/ren/src/blog/951413iMgBlog/image-20210513123233344.png)

对应的CPU使用率, 两个进程的CPU使用率是200%，实际产出IPC是2.1+1.64=3.75，比单个进程的IPC为3.92小多了。而单个进程CPU使用率才100%

![image-20210513130252565](/Users/ren/src/blog/951413iMgBlog/image-20210513130252565.png)

以上测试CPU为Intel(R) Xeon(R) Platinum 8260 CPU @ 2.40GHz (Thread(s) per core:    2)

## perf 和火焰图

调用 perf record 采样几秒钟，一般需要加 -g 参数，也就是 call-graph，还需要抓取函数的调用关系。在多核的机器上，还要记得加上 -a 参数，保证获取所有 CPU Core 上的函数运行情况。至于采样数据的多少，在讲解 perf 概念的时候说过，我们可以用 -c 或者 -F 参数来控制。


	   83  07/08/19 13:56:26 sudo perf record -ag -p 4759
	   84  07/08/19 13:56:50 ls /tmp/
	   85  07/08/19 13:57:06 history |tail -16
	   86  07/08/19 13:57:20 sudo chmod 777 perf.data
	   87  07/08/19 13:57:33 perf script >out.perf
	   88  07/08/19 13:59:24 ~/tools/FlameGraph-master/./stackcollapse-perf.pl ~/out.perf >out.folded
	   89  07/08/19 14:01:01 ~/tools/FlameGraph-master/flamegraph.pl out.folded > kernel-perf.svg
	   90  07/08/19 14:01:07 ls -lh
	   91  07/08/19 14:03:33 history


	$ sudo perf record -F 99 -a -g -- sleep 60 //-F 99 指采样每秒钟做 99 次

　　执行这个命令将生成一个 perf.data 文件：

执行sudo perf report -n可以生成报告的预览。
执行sudo perf report -n --stdio可以生成一个详细的报告。
执行sudo perf script可以 dump 出 perf.data 的内容。


	# 折叠调用栈
	$ FlameGraph/stackcollapse-perf.pl out.perf > out.folded
	# 生成火焰图
	$ FlameGraph/flamegraph.pl out.folded > out.svg



## ECS和perf 

在ECS会采集不到 cycles等，cpu-clock、page-faults都是内核中的软事件，cycles/instructions得采集cpu的PMU数据，ECS采集不到这些PMU数据。

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/a120388ff72d712a4fd176e7cea005cf.png)

## CPU cache

![image-20210511160107225](/Users/ren/src/blog/951413iMgBlog/image-20210511160107225.png)

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/f5728a2afb29c653a3e1bf21f4d56056.png)

查看cpu cache数据

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

超线程技术主要的出发点是，当处理器在运行一个线程，执行指令代码时，很多时候处理器并不会使用到全部的计算能力，部分计算能力就会处于空闲状态。而超线程技术就是通过多线程来进一步“压榨”处理器。**pipeline进入stalled状态就可以切到其它超线程上**

举个例子，如果一个线程运行过程中，必须要等到一些数据加载到缓存中以后才能继续执行，此时 CPU 就可以切换到另一个线程，去执行其他指令，而不用去处于空闲状态，等待当前线程的数据加载完毕。**通常，一个传统的处理器在线程之间切换，可能需要几万个时钟周期。而一个具有 HT 超线程技术的处理器只需要 1 个时钟周期。因此就大大减小了线程之间切换的成本，从而最大限度地让处理器满负荷运转。**

> ARM芯片基本不做超线程，另外请思考为什么有了应用层的多线程切换还需要CPU层面的超线程？

如果physical id和core id都一样的话，说明这两个core实际是一个物理core，其中一个是HT

![image.png](/Users/ren/src/blog/951413iMgBlog/191276e2a1a1731969da748f1690bc9b.png)

## 测试工具 toplev

`toplev`是一个基于`perf`和TMAM(Top-down Microarchitecture Analysis Method)方法的应用性能分析工具。从之前的[介绍文章 ](https://decodezp.github.io/2019/01/27/quickwords13-tma/)中可以了解到TMAM本质上是对CPU Performance Counter的整理和加工。取得Performance Counter的读数需要`perf`来协助，对读数的计算进而明确是Frondend bound还是Backend bound等等。

在最终计算之前，你大概需要做三件事：

- 明确CPU型号，因为不同的CPU，对应的PMU也不一样（依赖网络）
- 读取TMAM需要的`perf event`读数
- 按TMAM规定的算法计算，具体算法在这个[Excel表格](https://share.weiyun.com/5jNsb6o)里

这三步可以自动化地由程序来做。本质上`toplev`就是在做这件事。

`toplev`的[Github地址](https://github.com/andikleen/pmu-tools)：https://github.com/andikleen/pmu-tools

另外补充一下，TMAM作为一种`Top-down`方法，它一定是分级的。通过上一级的结果下钻，最终定位性能瓶颈。那么`toplev`在执行的时候，也一定是包含这个“等级”概念的。

pmu-tools 的工具在第一次运行的时会通过 `event_download.py` 把本机环境的 PMU 映射表自动下载下来, 但是前提是你的机器能正常连接 01.day 的网络. 很抱歉我司内部的服务器都是不行的, 因此 pmu-tools 也提供了手动下载的方式.

因此当我们的环境根本无法连接外部网络的时候, 我们只能通过其他机器下载实际目标环境的事件映射表下载到另一个系统上, 有点交叉编译的意思.

### [首先获取目标机器的 CPU 型号](https://oskernellab.com/2021/01/24/2021/0127-0001-Topdown_analysis_as_performed_on_Intel_CPU_using_pmu-tools/)

```
printf "GenuineIntel-6-%X\n" $(awk '/model\s+:/ { print $3 ; exit } ' /proc/cpuinfo )
```

> cpu的型号信息是由 vendor_id/cpu_family/model/stepping 等几个标记的.
>
> 他其实标记了当前 CPU 是哪个系列那一代的产品, 对应的就是其微架构以及版本信息.
>
> 注意我们使用了 %X 按照 16 进制来打印
>
> 注意上面的命令显示制定了 vendor_id 等信息, 因为当前服务器端的 CPU 前面基本默认是 GenuineIntel-6 等.
>
> 不过如果我们是其他机器, 最好查看下 cpufino 信息确认.

比如我这边机器的 CPU 型号为 :

```
processor       : 7
vendor_id       : GenuineIntel`
cpu family      : 6
model           : 85
model name      : Intel(R) Xeon(R) Gold 6161 CPU @ 2.20GHz
stepping        : 4
microcode       : 0x1
```

对应的结果就是 `GenuineIntel-6-55-4`.

我们也可以直接用 `-v` 打出来 CPU 信息.

```
$ python ./event_download.py  -v

My CPU GenuineIntel-6-55-4
```

### TMAM(Top-down Microarchitecture Analysis Method)

在最近的英特尔微体系结构上，流水线的 Front-end 每个 CPU 周期（cycle）可以分配4个 uOps ，而 Back-end 可以在每个周期中退役4个 uOps。 流水线槽（pipeline slot）代表处理一个 uOp 所需的硬件资源。 TMAM 假定对于每个 CPU 核心，在每个 CPU 周期内，有4个 pipeline slot 可用，然后使用专门设计的 PMU 事件来测量这些 pipeline slot 的使用情况。在每个 CPU 周期中，pipeline slot 可以是空的或者被 uOp 填充。 如果在一个 CPU 周期内某个 pipeline slot 是空的，称之为一次停顿（stall）。如果 CPU 经常停顿，系统性能肯定是受到影响的。TMAM 的目标就是确定系统性能问题的主要瓶颈。



下图展示并总结了乱序执行微体系架构中自顶向下确定性能瓶颈的分类方法。这种自顶向下的分析框架的优点是一种结构化的方法，有选择地探索可能的性能瓶颈区域。 带有权重的层次化节点，使得我们能够将分析的重点放在确实重要的问题上，同时无视那些不重要的问题。

![topdown.PNG](https://kernel.taobao.org/2019/03/Top-down-Microarchitecture-Analysis-Method/topdown.PNG)

例如，如果应用程序性能受到指令提取问题的严重影响， TMAM 将它分类为 Front-end Bound 这个大类。 用户或者工具可以向下探索并仅聚焦在 Front-end Bound 这个分类上，直到找到导致应用程序性能瓶颈的直接原因或一类原因。

### toplev实例

配置对应cpu型号的事件

> export EVENTMAP=/root/.cache/pmu-events/GenuineIntel-6-55-7-core.json  这样就可以了,上述资料中的两个export是可选的



```
# python toplev.py --core C0 --no-desc -l1 taskset -c 0  bash -c 'echo "7^199999" | bc > /dev/null'
Will measure complete system.
Using level 1.
# 4.2-full-perf on Intel(R) Xeon(R) Platinum 8269CY CPU @ 2.50GHz [clx/skylake]
S0-C0    BAD            Bad_Speculation  % Slots                   36.9  <==
S1-C0    BE             Backend_Bound    % Slots                   56.2  <==
Run toplev --describe Bad_Speculation^ Backend_Bound^ to get more information on bottlenecks
Add --nodes '!+Bad_Speculation*/2,+Backend_Bound*/2,+MUX' for breakdown.


```

## [Linux 调度策略](http://linuxperf.com/?p=197)

Linux kernel支持两种实时(real-time)调度策略(scheduling policy)：SCHED_FIFO和SCHED_RR

- /proc/sys/kernel/sched_rt_period_us

缺省值是1,000,000 μs (1秒)，表示实时进程的运行粒度为1秒。（注：修改这个参数请谨慎，太大或太小都可能带来问题）。

- /proc/sys/kernel/sched_rt_runtime_us

缺省值是 950,000 μs (0.95秒)，表示在1秒的运行周期里所有的实时进程一起最多可以占用0.95秒的CPU时间。

如果sched_rt_runtime_us=-1，表示取消限制，意味着实时进程可以占用100%的CPU时间（慎用，有可能使系统失去控制）。

所以，Linux kernel默认情况下保证了普通进程无论如何都可以得到5%的CPU时间，尽管系统可能会慢如蜗牛，但管理员仍然可以利用这5%的时间设法恢复系统，比如停掉失控的实时进程，或者给自己的shell进程赋予更高的实时优先级以便执行管理任务，等等。

进程自愿切换(Voluntary)和强制切换(Involuntary)的次数被统计在 /proc//status 中，其中voluntary_ctxt_switches表示自愿切换的次数，nonvoluntary_ctxt_switches表示强制切换的次数，两者都是自进程启动以来的累计值。 或pidstat -w 1 来统计  http://linuxperf.com/?cat=10

- 自愿切换发生的时候，进程不再处于运行状态，比如由于等待IO而阻塞(TASK_UNINTERRUPTIBLE)，或者因等待资源和特定事件而休眠(TASK_INTERRUPTIBLE)，又或者被debug/trace设置为TASK_STOPPED/TASK_TRACED状态；
- 强制切换发生的时候，进程仍然处于运行状态(TASK_RUNNING)，通常是由于被优先级更高的进程抢占(preempt)，或者进程的时间片用完了

如果一个进程的自愿切换占多数，意味着它对CPU资源的需求不高。如果一个进程的强制切换占多数，意味着对它来说CPU资源可能是个瓶颈，这里需要排除进程频繁调用sched_yield()导致强制切换的情况

spinlock(自旋锁)是内核中最常见的锁，它的特点是：等待锁的过程中不休眠，而是占着CPU空转，优点是避免了上下文切换的开销，缺点是该CPU空转属于浪费, 同时还有可能导致cache ping-pong，**spinlock适合用来保护快进快出的临界区**。持有spinlock的CPU不能被抢占，持有spinlock的代码不能休眠 http://linuxperf.com/?p=138

从操作系统的角度讲，os会维护一个ready queue（就绪的线程队列）。并且在某一时刻cpu只为ready queue中位于队列头部的线程服务。

sleep()使当前线程进入停滞状态，所以执行sleep()的线程在指定的时间内肯定不会执行；yield()只是使当前线程重新回到可执行状态，所以执行yield()的线程有可能在进入到可执行状态后马上又被执行。




NMI(non-maskable interrupt)，就是不可屏蔽的中断. NMI通常用于通知操作系统发生了无法恢复的硬件错误，也可以用于系统调试与采样，大多数服务器还提供了人工触发NMI的接口，比如NMI按钮或者iLO命令等。

http://cenalulu.github.io/linux/numa/ numa原理和优缺点案例讲解

正在运行中的用户程序被中断之后，必须等到中断处理例程完成之后才能恢复运行，在此期间即使其它CPU是空闲的也不能换个CPU继续运行，就像被中断牢牢钉在了当前的CPU上，动弹不得，中断处理需要多长时间，用户进程就被冻结多长时间。

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/1d20b6172d4effb7e27feedc06a820f9.png)

Linux kernel把中断分为两部分：hard IRQ和soft IRQ，hard IRQ只处理中断最基本的部分，保证迅速响应，尽量在最短的时间里完成，把相对耗时的工作量留给soft IRQ；soft IRQ可以被hard IRQ中断，如果soft IRQ运行时间过长，也可能会被交给内核线程ksoftirqd去继续完成。
https://mp.weixin.qq.com/s/AzcB1DwqRCoiofOOI88T9Q softirq导致一路CPU使用过高，其它CPU还是闲置，整个系统比较慢

Linux的进程调度有一个不太为人熟知的特性，叫做wakeup affinity，它的初衷是这样的：如果两个进程频繁互动，那么它们很有可能共享同样的数据，把它们放到亲缘性更近的scheduling domain有助于提高缓存和内存的访问性能，所以当一个进程唤醒另一个的时候，被唤醒的进程可能会被放到相同的CPU core或者相同的NUMA节点上。这个特性缺省是打开的，它有时候很有用，但有时候却对性能有伤害作用。设想这样一个应用场景：一个主进程给成百上千个辅进程派发任务，这成百上千个辅进程被唤醒后被安排到与主进程相同的CPU core或者NUMA节点上，就会导致负载严重失衡，CPU忙的忙死、闲的闲死，造成性能下降。https://mp.weixin.qq.com/s/DG1v8cUjcXpa0x2uvrRytA

http://linuxperf.com/?p=197



## 参考资料

[perf详解]( https://zhengheng.me/2015/11/12/perf-stat/)

[CPU体系结构](https://www.atatech.org/articles/109158)

[震惊，用了这么多年的 CPU 利用率，其实是错的](https://mp.weixin.qq.com/s/KaDJ1EF5Y-ndjRv2iUO3cA)cpu占用不代表在做事情，可能是stalled，也就是流水线卡顿，但是cpu占用了，实际没事情做。

https://mp.weixin.qq.com/s?__biz=MzUxNjE3MTcwMg==&mid=2247483755&idx=1&sn=5324f7e46c91739b566dfc1d0847fc4a&chksm=f9aa33b2ceddbaa478729383cac89967cc515bafa472001adc4ad42fb37e3ce473eddc3b591a&mpshare=1&scene=1&srcid=0127mp3WJ6Kd1UOQISFg3SIC#rd 

https://kernel.taobao.org/2019/03/Top-down-Microarchitecture-Analysis-Method/