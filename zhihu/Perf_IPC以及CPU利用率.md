
# Perf IPC以及CPU性能

为了让程序能快点，特意了解了CPU的各种原理，比如多核、超线程、NUMA、睿频、功耗、GPU、大小核再到分支预测、cache_line失效、加锁代价、IPC等各种指标（都有对应的代码和测试数据）都会在这系列文章中得到答案。当然一定会有程序员最关心的分支预测案例、Disruptor无锁案例、cache_line伪共享案例等等。

这次让我们从最底层的沙子开始用8篇文章来回答各种疑问以及大量的实验对比案例和测试数据。

大的方面主要是从这几个疑问来写这些文章：

-   同样程序为什么CPU跑到800%还不如CPU跑到200%快？
-   IPC背后的原理和和程序效率的关系？
-   为什么数据库领域都爱把NUMA关了，这对吗？
-   几个国产芯片的性能到底怎么样？

**本篇主要是实践，如何定量观察一块CPU的效率， 看完本文最起码要能理解超线程的原理、CPU为什么出工不出力和用好perf **

![image-20210802161455950](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/Perf_IPC以及CPU利用率/image-20210802161455950.png)

## 程序性能

> 程序的 CPU 执行时间 = 指令数/(主频*IPC)


IPC: insns per cycle  insn/cycles

## CPU 流水线工作原理

cycles：CPU时钟周期。CPU从它的指令集(instruction set)中选择指令执行。

一个指令包含以下的步骤，每个步骤由CPU的一个叫做功能单元(functional unit)的组件来进行处理，每个步骤的执行都至少需要花费一个时钟周期。

-   指令读取(instruction fetch， IF)
-   指令解码(instruction decode， ID)
-   执行(execute， EXE)
-   内存访问(memory access，MEM)
-   寄存器回写(register write-back， WB)

![skylake server block diagram.svg](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/Perf_IPC以及CPU利用率/950px-skylake_server_block_diagram.svg.png)

以上结构简化成流水线就是：

![image-20210511154816751](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/Perf_IPC以及CPU利用率/image-20210511154816751.png)

IF/ID 就是我们常说的前端，他负责不停地取指和译指，然后为后端提供译指之后的指令，最核心的优化就是要做好**分支预测**，终归取指是要比执行慢，只有提前做好预测才能尽量匹配上后端。后端核心优化是要做好执行单元的并发量，以及乱序执行能力，最终要将乱序执行结果正确组合并输出。

五个步骤只能串行，**但是可以做成pipeline提升效率**，也就是第一个指令做第二步的时候，指令读取单元可以去读取下一个指令了，如果有一个指令慢就会造成stall，也就是pipeline有地方卡壳了。

```
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
```

stalled-cycles，则是指令管道未能按理想状态发挥并行作用，发生停滞的时钟周期。stalled-cycles-frontend指指令读取或解码的指令步骤，而stalled-cycles-backend则是指令执行步骤。第二列中的cycles idle其实意思跟stalled是一样的，由于指令执行停滞了，所以指令管道也就空闲了，千万不要误解为CPU的空闲率。这个数值是由stalled-cycles-frontend或stalled-cycles-backend除以上面的cycles得出的。

另外cpu可以同时有多条pipeline，这就是理论上最大的IPC.

### pipeline效率和IPC

虽然一个指令需要5个步骤，也就是完全执行完需要5个cycles，这样一个时钟周期最多能执行0.2条指令，IPC就是0.2，显然太低了。

-   非流水线：

![image-20210511154859711](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/Perf_IPC以及CPU利用率/image-20210511154859711.png)

如果把多个指令的五个步骤用pipeline流水线跑起来，在理想情况下一个时钟周期就能跑完一条指令了，这样IPC就能达到1了。

-   标量流水线, 标量（Scalar）流水计算机是**只有一条指令流水线**的计算机:

![image-20210511155530477](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/Perf_IPC以及CPU利用率/image-20210511155530477.png)

进一步优化，如果我们加大流水线的条数，让多个指令并行执行，就能得到更高的IPC了，但是这种并行必然会有指令之间的依赖，比如第二个指令依赖第一个的结果，所以多个指令并行更容易出现互相等待(stall).

-   超标量流水线：所谓超标量（Superscalar）流 水计算机，是指它**具有两条以上的指令流水线**, 超标流水线数量也就是ALU执行单元的并行度

![image-20210511155708234](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/Perf_IPC以及CPU利用率/image-20210511155708234.png)

一般而言流水线的超标量不能超过单条流水线的深度

每一个功能单元的流水线的长度是不同的。事实上，不同的功能单元的流水线长度本来就不一样。我们平时所说的 14 级流水线，指的通常是进行整数计算指令的流水线长度。如果是浮点数运算，实际的流水线长度则会更长一些。

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/Perf_IPC以及CPU利用率/85f15ec667d09fd2d368822904029b32.jpeg)

### 指令缓存（Instruction Cache）和数据缓存（Data Cache）

在第 1 条指令执行到访存（MEM）阶段的时候，流水线里的第 4 条指令，在执行取指令（Fetch）的操作。访存和取指令，都要进行内存数据的读取。我们的内存，只有一个地址译码器的作为地址输入，那就只能在一个时钟周期里面读取一条数据，没办法同时执行第 1 条指令的读取内存数据和第 4 条指令的读取指令代码。

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/Perf_IPC以及CPU利用率/c2a4c0340cb835350ea954cdc520704e.jpeg)

把内存拆成两部分的解决方案，在计算机体系结构里叫作哈佛架构（Harvard Architecture），来自哈佛大学设计Mark I 型计算机时候的设计。我们今天使用的 CPU，仍然是冯·诺依曼体系结构的，并没有把内存拆成程序内存和数据内存这两部分。因为如果那样拆的话，对程序指令和数据需要的内存空间，我们就没有办法根据实际的应用去动态分配了。虽然解决了资源冲突的问题，但是也失去了灵活性。

在流水线产生依赖的时候必须pipeline stall，也就是让依赖的指令执行NOP。

### Intel X86每个指令需要的cycle

这块的理解必读：[Intel PAUSE指令变化是如何影响自旋锁以及MySQL的性能的](https://www.atatech.org/articles/157681)

Intel xeon

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/Perf_IPC以及CPU利用率/v2-73a5cce599828b6c28f6f29bb310687a_1440w.jpg)

不同架构带来IPC变化：

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/Perf_IPC以及CPU利用率/intel-ice-lake-ipc-over-time.jpg)

Intel 最新的CPU Ice Lake和其上一代的性能对比数据：

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/Perf_IPC以及CPU利用率/intel-ice-lake-sunny-cove-core-table.jpg)

上图最终结果导致了IPC提升了20%，以及整体效率的提升：

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/Perf_IPC以及CPU利用率/Intel-Ice-Lake-improved-perf-per-core-April-2021.png)

## perf 使用

主要是通过采集 PMU（Performance Monitoring Unit -- CPU内部提供）数据来做性能监控

```
sudo perf record -g -a -e skb:kfree_skb //perf 记录丢包调用栈 然后sudo perf script 查看 （网络报文被丢弃时会调用该函数kfree_skb）
perf record -e 'skb:consume_skb' -ag  //记录网络消耗
perf probe --add tcp_sendmsg //增加监听probe  perf record -e probe:tcp_sendmsg -aR sleep 1
sudo perf sched record -- sleep 1 //记录cpu调度的延时
sudo perf sched latency //查看
```

可以通过perf看到cpu的使用情况：

```
$sudo perf stat -a -- sleep 10
```

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

如果同时运行两个如上测试程序，鲲鹏920运行，每个程序的IPC都是3.99

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

## IPC和超线程

ipc是指每个core的IPC

### 超线程(Hyper-Threading)原理

**概念**：一个核还可以进一步分成几个逻辑核，来执行多个控制流程，这样可以进一步提高并行程度，这一技术就叫超线程，有时叫做 simultaneous multi-threading（SMT）。

超线程技术主要的出发点是，当处理器在运行一个线程，执行指令代码时，很多时候处理器并不会使用到全部的计算能力，部分计算能力就会处于空闲状态。而超线程技术就是通过多线程来进一步“压榨”处理器。**pipeline进入stalled状态就可以切到其它超线程上**

举个例子，如果一个线程运行过程中，必须要等到一些数据加载到缓存中以后才能继续执行，此时 CPU 就可以切换到另一个线程，去执行其他指令，而不用去处于空闲状态，等待当前线程的数据加载完毕。**通常，一个传统的处理器在线程之间切换，可能需要几万个时钟周期。而一个具有 HT 超线程技术的处理器只需要 1 个时钟周期。因此就大大减小了线程之间切换的成本，从而最大限度地让处理器满负荷运转。**

> ARM芯片基本不做超线程，另外请思考为什么有了应用层的多线程切换还需要CPU层面的超线程？


**超线程(Hyper-Threading)物理实现**: 在CPU内部增加寄存器等硬件设施，但是ALU、译码器等关键单元还是共享。在一个物理 CPU 核心内部，会有双份的 PC 寄存器、指令寄存器乃至条件码寄存器。超线程的目的，是在一个线程 A 的指令，在流水线里停顿的时候，让另外一个线程去执行指令。因为这个时候，CPU 的译码器和 ALU 就空出来了，那么另外一个线程 B，就可以拿来干自己需要的事情。这个线程 B 可没有对于线程 A 里面指令的关联和依赖。

CPU超线程设计过程中会引入5%的硬件，但是有30%的提升（经验值，场景不一样效果不一样，阿里的OB/MySQL/ODPS业务经验是提升35%），这是引入超线程的理论基础。如果是一个core 4个HT的话提升会是 50%

### 超线程如何查看

如果physical id和core id都一样的话，说明这两个core实际是一个物理core，其中一个是HT。

![image.png](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/Perf_IPC以及CPU利用率/191276e2a1a1731969da748f1690bc9b.png)

physical id对应socket，也就是物理上购买到的一块CPU； core id对应着每个物理CPU里面的一个物理core，同一个phyiscal id下core id一样说明开了HT

### IPC和超线程的关系

IPC 和一个core上运行多少个进程没有关系。实际测试将两个运行nop指令的进程绑定到一个core上，IPC不变, 因为IPC就是从core里面取到的，不针对具体进程。但是如果是这两个进程绑定到一个物理core以及对应的超线程core上那么IPC就会减半。如果程序是IO bound（比如需要频繁读写内存）首先IPC远远低于理论值4的，这个时候超线程同时工作的话IPC基本能翻倍

![image-20210513123233344](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/Perf_IPC以及CPU利用率/image-20210513123233344.png)

对应的CPU使用率, 两个进程的CPU使用率是200%，实际产出IPC是2.1+1.64=3.75，比单个进程的IPC为3.92小多了。而单个进程CPU使用率才100%

![image-20210513130252565](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/Perf_IPC以及CPU利用率/image-20210513130252565.png)

以上测试CPU为Intel(R) Xeon(R) Platinum 8260 CPU @ 2.40GHz (Thread(s) per core:    2)

### Intel和AMD单核以及HT性能比较

更加细致数据请参考： [AMD/海光/鲲鹏/Intel CPU性能大比拼](https://www.atatech.org/articles/212194)

测试命令，这个测试命令无论在哪个CPU下，用2个物理核用时都是一个物理核的一半，所以这个计算是可以完全并行的

```
taskset -c 1,53 /usr/bin/sysbench --num-threads=2 --test=cpu --cpu-max-prime=50000 run //单核用一个threads，绑核， HT用2个threads，绑一对HT
```

测试结果为耗时，单位秒，Hygon 7280 就是Zen2架构

<table>
<colgroup>
<col style="width: 25%" />
<col style="width: 25%" />
<col style="width: 25%" />
<col style="width: 25%" />
</colgroup>
<tr class="header">
<th style="text-align: left;">Family Name</th>
<th style="text-align: left;">Intel 8269CY CPU @ 2.50GHz</th>
<th style="text-align: left;">Intel E5-2682 v4 @ 2.50GHz</th>
<th style="text-align: left;">Hygon 7280 2.1G</th>
</tr>
<tr class="odd">
<td style="text-align: left;">单核 prime 50000</td>
<td style="text-align: left;">83</td>
<td style="text-align: left;">109</td>
<td style="text-align: left;">89</td>
</tr>
<tr class="even">
<td style="text-align: left;">HT prime 50000</td>
<td style="text-align: left;">48</td>
<td style="text-align: left;">74</td>
<td style="text-align: left;">87</td>
</tr>
</table>
## perf 和火焰图

调用 perf record 采样几秒钟，一般需要加 -g 参数，也就是 call-graph，还需要抓取函数的调用关系。在多核的机器上，还要记得加上 -a 参数，保证获取所有 CPU Core 上的函数运行情况。至于采样数据的多少，在讲解 perf 概念的时候说过，我们可以用 -c 或者 -F 参数来控制。

```
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

```

执行这个命令将生成一个 perf.data 文件：

执行sudo perf report -n可以生成报告的预览。
执行sudo perf report -n --stdio可以生成一个详细的报告。
执行sudo perf script可以 dump 出 perf.data 的内容。

```
# 折叠调用栈
$ FlameGraph/stackcollapse-perf.pl out.perf > out.folded
# 生成火焰图
$ FlameGraph/flamegraph.pl out.folded > out.svg

```

## ECS和perf

在ECS会采集不到 cycles等，cpu-clock、page-faults都是内核中的软事件，cycles/instructions得采集cpu的PMU数据，ECS采集不到这些PMU数据。

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/a120388ff72d712a4fd176e7cea005cf.png)



## 系列文章

[AMD/海光/鲲鹏/Intel CPU性能大比拼](https://www.atatech.org/articles/212194)
[CPU的生产和概念](https://www.atatech.org/articles/211563)
[CPU性能和CACHE](https://topic.atatech.org/articles/210128)
[十年后数据库还是不敢拥抱NUMA](https://www.atatech.org/articles/205974)
[一次海光X86物理机资源竞争压测的调优--AMD Zen1架构CPU](https://www.atatech.org/articles/205002)
[Intel PAUSE指令变化是如何影响自旋锁以及MySQL的性能的](https://www.atatech.org/articles/157681)



## 参考资料

[perf详解]( https://zhengheng.me/2015/11/12/perf-stat/)
[CPU体系结构](https://www.atatech.org/articles/109158)
[震惊，用了这么多年的 CPU 利用率，其实是错的](https://mp.weixin.qq.com/s/KaDJ1EF5Y-ndjRv2iUO3cA)cpu占用不代表在做事情，可能是stalled，也就是流水线卡顿，但是cpu占用了，实际没事情做。
[CPU Utilization is Wrong](http://www.brendangregg.com/blog/2017-05-09/cpu-utilization-is-wrong.html)
https://mp.weixin.qq.com/s?__biz=MzUxNjE3MTcwMg==&mid=2247483755&idx=1&sn=5324f7e46c91739b566dfc1d0847fc4a&chksm=f9aa33b2ceddbaa478729383cac89967cc515bafa472001adc4ad42fb37e3ce473eddc3b591a&mpshare=1&scene=1&srcid=0127mp3WJ6Kd1UOQISFg3SIC#rd 
https://kernel.taobao.org/2019/03/Top-down-Microarchitecture-Analysis-Method/
[数据中心CPU探索和分析](https://www.atatech.org/articles/209957)