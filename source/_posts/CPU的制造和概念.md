---
title: CPU的制造和概念
date: 2021-06-01 17:30:03
categories:
    - CPU
tags:
    - Linux
    - CPU
---

# CPU的制造和概念

购买到的CPU实体外观和大小，一般是40mm X 50mm大小

![How to Perform a CPU Stress Test and Push It to the Limit | AVG](/images/951413iMgBlog/AFCCC93B-D8A7-400A-9E80-978F8B05CD7E.jpeg)

![Coffee Lake-Refresh Desktop CPU List Surfaces: 35W Core i9-9900T & 8-Core  Xeon E-2200 Confirmed](/images/951413iMgBlog/images.jpeg)

![enter image description here](/images/951413iMgBlog/yp6cf.jpg)

## 集成电路和芯片

以一台iPhone X拆解分析里面的芯片：

![img](/images/951413iMgBlog/8bbc7b771359dfc07c81ca2a064cb30c.jpg)

整个半导体产业的产值分布

![img](/images/951413iMgBlog/be159461be7c0a5569be21b30a24db50.png)

![img](/images/951413iMgBlog/d3a2690aaf6be233d08404c108fc4449.png)

## 裸片Die 制作

沙子中提纯硅，硅晶柱生长：

![img](/images/951413iMgBlog/weixin15664418828781.gif)

硅晶柱切片：

![img](/images/951413iMgBlog/e510d61ed3e648a3ae64be7ac1da26e7.png)

直径为 300 毫米的纯硅晶圆（从硅柱上切割下来的圆片），俗称 12 寸晶圆，大约是 400 美金。但尺寸并不是衡量硅晶圆的最重要指标，纯度才是。日本的信越公司可以生产 13 个 9 纯度的晶圆。

### 光刻

使用特定波长的光，透过光罩（类似印炒里面的母版），照射在涂有光刻胶的晶圆上，光罩上芯片的设计图像，就复制到晶圆上了，这就是光刻，这一步是由光刻机完成的，光刻机是芯片制造中光刻环节的核心设备。你可以把光刻理解为，就是用光罩这个母版，一次次在晶圆上印电路的过程。

![img](/images/951413iMgBlog/b62d2a87a74c1ba90a069624bdc91eee.jpeg)

光刻是最贵的一个环节，一方面是光罩越来越多，越来越贵，另一方面光刻机也很贵。光刻机是半导体制造设备中价格占比最大，也是最核心的设备。2020 年荷兰公司 ASML 的极紫外光源（EUV）光刻机每台的平均售价是 1.45 亿欧元，而且全世界独家供货，年产量 31 台，有钱也未必能买得到。

![image-20210601160424815](/images/951413iMgBlog/image-20210601160424815.png)

回顾光刻机的发展历史，从 1960 年代的接触式光刻机、接近式光刻机，到 1970 年代的投影式光刻机，1980 年代的步进式光刻机，到步进式扫描光刻机、浸入式光刻机和现在的深紫外光源（DUV）和极紫外光源（EUV）光刻机，一边是设备性能的不断提高，另一边是价格逐年上升，且供应商逐渐减少。到了 EUV 光刻机，ASML 就是独家供货了。

品质合格的die切割下去后，原来的晶圆成了下图的样子，是挑剩下的Downgrade Flash Wafer。残余的die是品质不合格的晶圆。黑色的部分是合格的die，会被原厂封装制作为成品NAND颗粒，而不合格的部分，也就是图中留下的部分则当做废品处理掉。

从晶圆上切割检测合格的Die

![img](/images/951413iMgBlog/weixin15664418828785.gif)

![img](/images/951413iMgBlog/bba1cd11728b47103777e2dbcccec3fdfc032348.png)





台积电一片 5nm 晶圆的加工费高达 12500 美金。根据台积电的财报推算，台积电平均每片晶圆可以产生近 4000 美金（300mm 晶圆）的利润。无论是哪个数字，对比 400 美金的纯硅晶圆原料来说，这都是一个至少增值 10 倍的高价值的加工过程。

随着Die的缩小，浪费的比例也从36%缩小成为12.6%。根据极限知识，我们知道如果Die的大小足够小，我们理论上可以100%用上所有的Wafer大小。从中我们可以看出越小的Die，浪费越小，从而降低CPU价格，对CPU生产者和消费者都是好事。

AMD在猪队友工艺落后Intel的前提下，又想要堆核怒怼。另辟蹊径，采取一个Package封装4个独立Die的做法，推出了EPYC服务器芯片，即不影响良率，又可以核心数目好看，可谓一举两得。

可惜连接四个Die的片外总线终归没有片内总线效率高，在好些benchmark中败下阵来，可见没有免费的午餐。他也似乎忘记了自己在2005年双核口水大战中调侃Intel是“胶水粘”的双核，自己这次可是“拼积木”式的，为了数据好看也够“拼”的了。

![img](/images/951413iMgBlog/v2-7d77aa1100b77261f2626791954e79ad_720w.jpg)

Intel的Pakcage内部是一个Die, Core之间原来是Ring Bus，在Skylake后改为Mesh。**AMD这样做，在增加灵活性之外，主要的目的是：省钱！！AMD每个Zeppelin Die都比Intel的小，这对良品率提高很大，节约了生产费用。**

这种胶水核强行将多个die拼一起是没考虑跨die之间的延迟，基本上跨die跟intel跨socket（numa）时延一样了。

一颗芯片的 1/3 的成本，是花在封测阶段的

![img](/images/951413iMgBlog/beebe27eacd37075dyy37a4182169f04.png)

![img](/images/951413iMgBlog/5eb09cde20395b84ff8c746c27d9f7b7.jpg)

### Die和core

One die with multiple cores:

![enter image description here](/images/951413iMgBlog/xCqqv.jpg)

CPU Package containing 2 separate DIEs:

![data f1](/images/951413iMgBlog/dataf1-1372099277050.jpg)

第4代酷睿（Haswell）的die：

![image-20210601162558479](/images/951413iMgBlog/image-20210601162558479.png)



主要分为几个部分：GPU、4个内核、System Agent(uncore,类似北桥)、cache和内存控制器和其他小部件。譬如我们发现core 3和4有问题，我们可以直接关闭3和4。坏的关掉就是i5,都是好的就是i7。



## 北桥和南桥

早期CPU core和内存硬盘的连接方式(FSB 是瓶颈)：

![image-20210602113401202](/images/951413iMgBlog/image-20210602113401202.png)

实物图：

![img](/images/951413iMgBlog/northsouth2.jpg)

由于FSB变成了系统性能的瓶颈和对多CPU的制约，在台式机和笔记本电脑中，MCH被请进CPU中，服务器市场虽然短暂的出现了IOH。

![Image](/images/951413iMgBlog/640.jpeg)

集成北桥后的内存实物图：

![image-20210602114931825](/images/951413iMgBlog/image-20210602114931825.png)

北桥已经集成到CPU中，南桥还没有，主要是因为：集成后Die增大不少，生产良品率下降成本上升；不集成两者采用不同的工艺；另外就是CPU引脚不够了！

![Image](/images/951413iMgBlog/640-20210601095028465)

SoC（System on Chip）：南桥北桥都集成在CPU中，单芯片解决方案。ATOM就是SoC

## 一个Core的典型结构

Intel skylake 架构图

![skylake server block diagram.svg](/images/951413iMgBlog/950px-skylake_server_block_diagram.svg.png)



iTLB:instruct TLB 

dTLB:data TLB

多个core加上L3等组成一个Die：

![img](/images/951413iMgBlog/cache-ht-hierarchy-2.jpg)



## 多核和多个CPU

如果要实现48core的计算能力，可以有如下三个方案

#### 方案1：一个大Die集成48core：![Intel Skylake SP Mesh Architecture Conceptual Diagram](/images/951413iMgBlog/Intel-Skylake-SP-Mesh-Architecture-Conceptual-Diagram.png)

#### [方案2](https://wccftech.com/amd-epyc-rome-zen-2-7nm-server-cpu-162-pcie-gen-4-lanes-report/)：一个CPU封装4个Die，也叫MCM（Multi-Chip-Module），每个Die12个core

![image-20210602165525641](/images/951413iMgBlog/image-20210602165525641.png)

四个Die之间的连接方法：

![image-20210602172555232](/images/951413iMgBlog/image-20210602172555232.png)

上图最下面的方案为[Intel采用的EMIB](https://venturebeat.com/2017/03/28/intel-moves-tech-forward-by-putting-two-chips-in-a-single-package/)（Embedded Multi-die Interconnect Bridge）方案，cost 最低。中间的方案是使用“硅中介层”(Interposer，AMD采用的方案)。这意味着你能在两枚主要芯片的下面放置和使用第三枚芯片。这枚芯片的目的是使得多个设备的连接更加容易，但是也带来了更高的成本。

#### 方案3：四个物理CPU（多Socket），每个物理CPU（Package）里面一个Die，每个Die12个core：

![image-20210602171352551](/images/951413iMgBlog/image-20210602171352551.png)

三者的比较：

性能肯定是大Die最好，但是良品率地，成本高；

方案2的多个Die节省了主板上的大量布线和VR成本，总成本略低，但是方案3更容易堆出更多的core和**内存**

![image-20210602170727459](/images/951413iMgBlog/image-20210602170727459.png)



## 多core通讯和NUMA

### uma下cpu访问内存

早期core不多统一走北桥总线访问内存，对所有core时延统一

![x86 UMA](/images/951413iMgBlog/numa-fsb-3.png)

### NUMA

如下图，左右两边的是内存条，每个NUMA的cpu访问直接插在自己CPU上的内存必然很快，如果访问插在其它NUMA上的内存条还要走QPI，所以要慢很多。

![undefined](/images/951413iMgBlog/1620954546311-096702b9-9929-4f47-8811-dc4d08829f31.png) 

如上架构是4路CPU，每路之间通过QPI相连，每个CPU内部8core用的是双Ring Bus相连，Memory Control Hub集成到了Die里面。一路CPU能连4个SMB，每个SMB有两个channel，每个channel最多接三个内存条（图中只画了2个）。

**快速通道互联**[[1\]](https://zh.wikipedia.org/wiki/快速通道互联#cite_note-1)[[2\]](https://zh.wikipedia.org/wiki/快速通道互联#cite_note-2)（英语：Intel **Q**uick**P**ath **I**nterconnect，[缩写](https://zh.wikipedia.org/wiki/縮寫)：**QPI**）[[3\]](https://zh.wikipedia.org/wiki/快速通道互联#cite_note-Intel_QPI-3)[[4\]](https://zh.wikipedia.org/wiki/快速通道互联#cite_note-4)，是一种由英特尔开发并使用的点对点处理器互联架构，用来实现CPU之间的互联。英特尔在2008年开始用QPI取代以往用于[至强](https://zh.wikipedia.org/wiki/Intel_Xeon)、[安腾](https://zh.wikipedia.org/wiki/Intel_Itanium)处理器的[前端总线](https://zh.wikipedia.org/wiki/前端匯流排)（[FSB](https://zh.wikipedia.org/wiki/FSB)），**用来实现芯片之间的直接互联，而不是再通过FSB连接到北桥**。Intel于2017年发布的SkyLake-SP Xeon中，用UPI（**U**ltra**P**ath **I**nterconnect）取代QPI。

#### Ring Bus

Ring Bus设计简单，双环设计可以保证任何两个ring stop之间距离不超过Ring Stop总数的一半，延迟控制在60ns，带宽100G以上，但是core越多，ring bus越长性能下降迅速，在12core之后性能下降明显。

于是采用如下两个Ring Bus并列，然后再通过双向总线把两个Ring Bus连起来。

在至强HCC(High Core Count, 核很多版)版本中，又加入了一个ring bus。两个ring bus各接12个Core，将延迟控制在可控的范围内。俩个Ring Bus直接用两个双向Pipe Line连接，保证通讯顺畅。于此同时由于Ring 0中的模块访问Ring 1中的模块延迟明显高于本Ring，亲缘度不同，所以两个Ring分属于不同的NUMA（Non-Uniform Memory Access Architecture）node。这点在BIOS设计中要特别注意。

![Intel Xeon E5-2600 V4 High Core Count Die](/images/951413iMgBlog/Intel-Xeon-E5-2600-V4-High-Core-Count-Die.png)



#### [Mesh网络](https://www.servethehome.com/the-new-intel-mesh-interconnect-architecture-and-platform-implications/)

Intel在Skylake和Knight Landing中引入了新的片内总线：Mesh。它是一种2D的Mesh网络：

![Intel Skylake SP Mesh Architecture Conceptual Diagram](/images/951413iMgBlog/Intel-Skylake-SP-Mesh-Architecture-Conceptual-Diagram.png)

一个skylake 28core die的实现：

![Skylake SP 28 Core Die Mesh](/images/951413iMgBlog/Skylake-SP-28-Core-Die-Mesh-800x666.jpg)

Mesh网络引入片内总线是一个巨大的进步，它有很多优点：

1. 首先当然是灵活性。新的模块或者节点在Mesh中增加十分方便，它带来的延迟不是像ring bus一样线性增加，而是非线性的。从而可以容纳更多的内核。
2. 设计弹性很好，不需要1.5 ring和2ring的委曲求全。
3. 双向mesh网络减小了两个node之间的延迟。过去两个node之间通讯，最坏要绕过半个ring。而mesh整体node之间距离大大缩减。
4. 外部延迟大大缩短

RAM延迟大大缩短：

![Broadwell Ring V Skylake Mesh DRAM Example](/images/951413iMgBlog/Broadwell-Ring-v-Skylake-Mesh-DRAM-Example-696x272.jpg)



左边的是ring bus，从一个ring里面访问另一个ring里面的内存控制器。最坏情况下是那条绿线，拐了一个大圈才到达内存控制器，需要310个cycle。而在Mesh网络中则路径缩短很多。

Mesh网络带来了这么多好处，那么缺点有没有呢？它网格化设计带来复杂性的增加，从而对Die的大小带来了负面影响

![image-20210602104851803](/images/951413iMgBlog/image-20210602104851803.png)



### uncore

"**Uncore**" is a term used by [Intel](https://en.wikipedia.org/wiki/Intel) to describe the functions of a [microprocessor](https://en.wikipedia.org/wiki/Microprocessor) that are not in the core, but which must be closely connected to the core to achieve high performance.[[1\]](https://en.wikipedia.org/wiki/Uncore#cite_note-modular_uncore-1) It has been called "**system agent**" since the release of the [Sandy Bridge](https://en.wikipedia.org/wiki/Sandy_Bridge) [microarchitecture](https://en.wikipedia.org/wiki/Microarchitecture).[[2\]](https://en.wikipedia.org/wiki/Uncore#cite_note-sandybridge-2)

The core contains the components of the processor involved in executing instructions, including the [ALU](https://en.wikipedia.org/wiki/Arithmetic_logic_unit), [FPU](https://en.wikipedia.org/wiki/Floating_point_unit), [L1](https://en.wikipedia.org/wiki/L1_cache) and [L2 cache](https://en.wikipedia.org/wiki/L2_cache). Uncore functions include [QPI](https://en.wikipedia.org/wiki/Intel_QuickPath_Interconnect) controllers, [L3 cache](https://en.wikipedia.org/wiki/L3_cache), [snoop agent](https://en.wikipedia.org/wiki/Memory_coherence) [pipeline](https://en.wikipedia.org/wiki/Instruction_pipeline), on-die [memory controller](https://en.wikipedia.org/wiki/Memory_controller), on-die [PCI Express Root Complex](https://en.wikipedia.org/wiki/PCI_Express_Root_Complex), and [Thunderbolt controller](https://en.wikipedia.org/wiki/Thunderbolt_(interface)).[[3\]](https://en.wikipedia.org/wiki/Uncore#cite_note-thunderbolt-3) Other bus controllers such as [SPI](https://en.wikipedia.org/wiki/Serial_Peripheral_Interface_Bus) and [LPC](https://en.wikipedia.org/wiki/Low_Pin_Count) are part of the [chipset](https://en.wikipedia.org/wiki/Chipset).[[4\]](https://en.wikipedia.org/wiki/Uncore#cite_note-Anandtech:_Nehalem:_The_Unwritten_Chapters-4)

### LLC Miss

#### Metric Description

The LLC (last-level cache) is the last, and longest-latency, level in the memory hierarchy before main memory (DRAM). Any memory requests missing here must be serviced by local or remote DRAM, with significant latency. The LLC Miss metric shows a ratio of cycles with outstanding LLC misses to all cycles.

## 一些Intel CPU NUMA结构参考

Intel Xeon Platinum 8163（Skylake）阿里云第四代服务器采用的CPU，Skylake架构，主频2.5GHz，计算性能问题。8163这款型号在intel官网上并没有相关信息，应该是阿里云向阿里云定制的，与之相近的Intel Xeon Platinum 8168，价格是$5890，约合￥38900元。

```
lscpu:
      Architecture:        x86_64
      CPU op-mode(s):      32-bit, 64-bit
      Byte Order:          Little Endian
      CPU(s):              96
      On-line CPU(s) list: 0-95
      Thread(s) per core:  2
      Core(s) per socket:  24
      Socket(s):           2
      NUMA node(s):        4
      Vendor ID:           GenuineIntel
      CPU family:          6
      Model:               85
      Model name:          Intel(R) Xeon(R) Platinum 8260 CPU @ 2.40GHz
      Stepping:            6
      CPU MHz:             2400.000
      CPU max MHz:         3900.0000
      CPU min MHz:         1000.0000
      BogoMIPS:            4800.00
      Virtualization:      VT-x
      L1d cache:           32K
      L1i cache:           32K
      L2 cache:            1024K
      L3 cache:            36608K
      NUMA node0 CPU(s):   0-3,7-9,13-15,19,20,48-51,55-57,61-63,67,68
      NUMA node1 CPU(s):   4-6,10-12,16-18,21-23,52-54,58-60,64-66,69-71
      NUMA node2 CPU(s):   24-27,31-33,37-39,43,44,72-75,79-81,85-87,91,92
      NUMA node3 CPU(s):   28-30,34-36,40-42,45-47,76-78,82-84,88-90,93-95
      
 Model: 85
 Model name: Intel(R) Xeon(R) Platinum 8268 CPU @ 2.90GHz
 Stepping: 6
 CPU MHz: 3252.490
 BogoMIPS: 5800.00
 Virtualization: VT-x
 L1d cache: 32K
 L1i cache: 32K
 L2 cache: 1024K
 L3 cache: 36608K
 NUMA node0 CPU(s):
 0,4,8,12,16,20,24,28,32,36,40,44,48,52,56,60,64,68,72,76,80,84,88,92
 NUMA node1 CPU(s):
 1,5,9,13,17,21,25,29,33,37,41,45,49,53,57,61,65,69,73,77,81,85,89,93
 NUMA node2 CPU(s):
 2,6,10,14,18,22,26,30,34,38,42,46,50,54,58,62,66,70,74,78,82,86,90,94
 NUMA node3 CPU(s):
 3,7,11,15,19,23,27,31,35,39,43,47,51,55,59,63,67,71,75,79,83,87,91,95   
 
 
  lscpu:
 Architecture: x86_64
 CPU op-mode(s): 32-bit, 64-bit
 Byte Order: Little Endian
 CPU(s): 192
 On-line CPU(s) list: 0-191
 Thread(s) per core: 1
 Core(s) per socket: 24
 Socket(s): 8 //每个物理CPU 24个物理core，这24个core应该是分布在2个Die中
 NUMA node(s): 16
 Vendor ID: GenuineIntel
 CPU family: 6
 Model: 85
 Model name: Intel(R) Xeon(R) Platinum 8260 CPU @ 2.40GHz
 Stepping: 7
 CPU MHz: 2400.000
 CPU max MHz: 3900.0000
 CPU min MHz: 1000.0000
 BogoMIPS: 4800.00
 Virtualization: VT-x
 L1d cache: 32K
 L1i cache: 32K
 L2 cache: 1024K
 L3 cache: 36608K
 NUMA node0 CPU(s): 0-3,7-9,13-15,19,20
 NUMA node1 CPU(s): 4-6,10-12,16-18,21-23
 NUMA node2 CPU(s): 24-27,31-33,37-39,43,44
 NUMA node3 CPU(s): 28-30,34-36,40-42,45-47
 NUMA node4 CPU(s): 48-51,55,56,60-62,66-68
 NUMA node5 CPU(s): 52-54,57-59,63-65,69-71
 NUMA node6 CPU(s): 72-75,79-81,85-87,91,92
 NUMA node7 CPU(s): 76-78,82-84,88-90,93-95
 NUMA node8 CPU(s): 96-99,103,104,108-110,114-116
 NUMA node9 CPU(s): 100-102,105-107,111-113,117-119
 NUMA node10 CPU(s): 120-123,127,128,132-134,138-140
 NUMA node11 CPU(s): 124-126,129-131,135-137,141-143
 NUMA node12 CPU(s): 144-147,151-153,157-159,163,164
 NUMA node13 CPU(s): 148-150,154-156,160-162,165-167
 NUMA node14 CPU(s): 168-171,175-177,181-183,187,188
 NUMA node15 CPU(s): 172-174,178-180,184-186,189-191
 
 //v62
 #lscpu
Architecture:          x86_64
CPU op-mode(s):        32-bit, 64-bit
Byte Order:            Little Endian
CPU(s):                104
On-line CPU(s) list:   0-103
Thread(s) per core:    2
Core(s) per socket:    26
Socket(s):             2
NUMA node(s):          2
Vendor ID:             GenuineIntel
CPU family:            6
Model:                 85
Model name:            Intel(R) Xeon(R) Platinum 8269CY CPU @ 2.50GHz
Stepping:              7
CPU MHz:               3200.097
CPU max MHz:           3800.0000
CPU min MHz:           1200.0000
BogoMIPS:              4998.89
Virtualization:        VT-x
L1d cache:             32K
L1i cache:             32K
L2 cache:              1024K
L3 cache:              36608K
NUMA node0 CPU(s):     0-25,52-77
NUMA node1 CPU(s):     26-51,78-103

//2016Intel开始出售Intel Xeon E5-2682 v4。 这是一种基于Broadwell架构的桌面处理器，主要为办公系统而设计。 它具有16 核心和32 数据流并使用, 售价约为7000人民币
#lscpu
Architecture:          x86_64
CPU op-mode(s):        32-bit, 64-bit
Byte Order:            Little Endian
CPU(s):                64
On-line CPU(s) list:   0-63
Thread(s) per core:    2
Core(s) per socket:    16
Socket(s):             2
NUMA node(s):          2
Vendor ID:             GenuineIntel
CPU family:            6
Model:                 79
Model name:            Intel(R) Xeon(R) CPU E5-2682 v4 @ 2.50GHz
Stepping:              1
CPU MHz:               2499.902
CPU max MHz:           3000.0000
CPU min MHz:           1200.0000
BogoMIPS:              5000.06
Virtualization:        VT-x
L1d cache:             32K
L1i cache:             32K
L2 cache:              256K
L3 cache:              40960K
NUMA node0 CPU(s):     0-15,32-47
NUMA node1 CPU(s):     16-31,48-63
Flags:                 fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good nopl xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 ds_cpl vmx smx est tm2 ssse3 fma cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic movbe popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm abm 3dnowprefetch ida arat epb invpcid_single pln pts dtherm spec_ctrl ibpb_support tpr_shadow vnmi flexpriority ept vpid fsgsbase tsc_adjust bmi1 hle avx2 smep bmi2 erms invpcid rtm cqm rdt rdseed adx smap xsaveopt cqm_llc cqm_occup_llc cqm_mbm_total cqm_mbm_local cat_l3
```

### [intel 架构迭代](https://jcf94.com/2018/02/13/2018-02-13-intel/)

![Intel processor roadmap](/images/oss/94d79c38-b577-4d31-b40c-fbec4cdc5f2e.png)

2008年的 Nehalem 是采用 45nm 工艺的新架构；

2009年的 Westmere 升级到 32nm；

2010年的 Lynnfield/Clarkdale 基于 45nm/32nm 工艺的新架构，第一代智能酷睿处理器；

2011年的 Sandy Bridge ，基于 32nm 工艺的新架构，第二代智能酷睿处理器；

2012年的 IVY Bridge，是 Sandy Bridge 的 22nm 升级版，第三代智能酷睿处理器；

2013年的 Haswel ，基于 22nm 工艺的新架构，第四代智能酷睿处理器；

2014年的 Broadwell，是 Haswell 的 14nm 升级版，第五代智能酷睿处理器；

2015年则推出 SkyLake，基于 14nm 工艺的新架构；

Core 架构代号是 Yonah，把 NetBurst 做深了的流水线级数又砍下来了，主频虽然降下来了（而且即使后来工艺提升到 45nm 之后也没有超过 NetBurst 的水平），但是却提高了整个流水线中的资源利用率，所以性能还是提升了；把奔腾 4 上曾经用过的超线程也砍掉了；对各个部分进行了强化，双核共享 L2 cache 等等。

从 Core 架构开始是真的走向多核了，就不再是以前 “胶水粘的” 伪双核了，这时候已经有最高 4 核的处理器设计了。

Core 从 65nm 改到 45nm 之后，基于 45nm 又推出了新一代架构叫 Nehalem，新架构Nehalem**采用 Intel QPI 来代替原来的前端总线**，**PCIE 和 DMI 控制器直接做到片内了**，不再需要北桥。

**Sandy Bridge 引入核间的ring bus**

感觉前面这几代都是在优化cache、通信；接下来的Broadwell和SkyLake就开始改进不大了，疯狂挤牙膏（唯一比较大的改进就是**Ring bus到Mesh**）

![image-20210602154509596](/images/951413iMgBlog/image-20210602154509596.png)

### 不同的架构下的参数


![image.png](/images/oss/e4a2fb522be7aa65158778b7ea825207.png)

## 主频睿频超频

**主频=外频×倍频系数**

不只是CPU需要一个切换频率，像GPU、cache、内存都需要一个外频来指导他们的电压脉冲的切换频率。CPU的发展比其它设备快，所以没法统一一个，于是就各自在外频的基础上X倍频系数。

超频：认为加大CPU的倍频系数，切换变快以后最大的问题是电容在短时间内充电不完整，这样导致信号失真，所以一般配套需要增加电压（充电更快），带来的后果是温度更高。

睿频：大多时候多核用不上，如果能智能地关掉无用的核同时把这些关掉的核的电源累加到在用的核上（通过增加倍频来实现），这样单核拥有更高的主频。也就是把其它核的电源指标和发热指标给了这一个核来使用。

![img](/images/951413iMgBlog/1000.jpeg)



CPU能耗公式：

> P = C V*V f

C是常数，f就是频率，V 电压。 f频率加大后因为充放电带来的Gate Delay，也就是频率加到，充放电时间短，为了保证信号的完整性就一定要增加电压来加快充放电。

所以最终能耗和f频率是 f^3 的指数关系。

即使不考虑散热问题，Core也没法做到无限大，必须要考虑光速不可超越的影响。也就是1GHz电信号智能传播30cm， 10GHz的话电信号只能传播3cm，也就是Die的大小不能超过3cm。当然这个推论简化了很多其他因素

## UEFI和Bios

**UEFI**，全称Unified Extensible Firmware Interface，即“统一的可扩展固件接口”，是一种详细描述全新类型接口的标准，是适用于电脑的标准固件接口，旨在代替BIOS（基本输入/输出系统）

电脑中有一个BIOS设置，它主要负责开机时检测硬件功能和引导操作系统启动的功能。而UEFI则是用于操作系统自动从预启动的操作环境，加载到一种操作系统上从而节省开机时间。

UEFI启动是一种新的主板引导项，它被看做是bios的继任者。UEFI最主要的特点是图形界面，更利于用户对象图形化的操作选择。

![img](/images/951413iMgBlog/webp)

UEFI 图形界面：

![img](/images/951413iMgBlog/webp-20210601102242967)

简单的来说UEFI启动是新一代的BIOS，功能更加强大，而且它是以图形图像模式显示，让用户更便捷的直观操作。

如今很多新产品的电脑都支持UEFI启动模式，甚至有的电脑都已抛弃BIOS而仅支持UEFI启动。这不难看出UEFI正在取代传统的BIOS启动。

UEFI固件通过ACPI报告给OS NUMA的组成结构，其中最重要的是SRAT（System Resource Affinity Table）和SLIT（System Locality Information Table）表。

## socket

socket对应主板上的一个插槽，也可以简单理解为一块物理CPU。同一个socket对应着 /proc/cpuinfo 里面的physical id一样。

一个socket至少对应着一个或多个node/NUMA

## GPU

GPU只处理有限的计算指令，不需要分支预测、乱序执行等，所以将Core里面的电路简化（如下图左边），同时通过SIMT（Single Instruction，Multiple Threads， 类似 SIMD）在取指令和指令译码的阶段，取出的指令可以给到后面多个不同的 ALU 并行进行运算。这样，我们的一个 GPU 的核里，就可以放下更多的 ALU，同时进行更多的并行运算了（如下图右边） 。 在 SIMD 里面，CPU 一次性取出了固定长度的多个数据，放到寄存器里面，用一个指令去执行。而 SIMT，可以把多条数据，交给不同的线程去处理。

![img](/images/951413iMgBlog/3d7ce9c053815f6a32a6fbf6f7fb9628.jpeg)

GPU的core在流水线stall的时候和超线程一样，可以调度别的任务给ALU，既然要调度一个不同的任务过来，我们就需要针对这个任务，提供更多的执行上下文。所以，一个 Core 里面的执行上下文的数量，需要比 ALU 多。

![img](/images/951413iMgBlog/c971c34e0456dea9e4a87857880bb5b8.jpeg)

在通过芯片瘦身、SIMT 以及更多的执行上下文，我们就有了一个更擅长并行进行暴力运算的 GPU。这样的芯片，也正适合我们今天的深度学习和挖矿的场景。

NVidia 2080 显卡的技术规格，就可以算出，它到底有多大的计算能力。2080 一共有 46 个 SM（Streaming Multiprocessor，流式处理器），这个 SM 相当于 GPU 里面的 GPU Core，所以你可以认为这是一个 46 核的 GPU，有 46 个取指令指令译码的渲染管线。每个 SM 里面有 64 个 Cuda Core。你可以认为，这里的 Cuda Core 就是我们上面说的 ALU 的数量或者 Pixel Shader 的数量，46x64 呢一共就有 2944 个 Shader。然后，还有 184 个 TMU，TMU 就是 Texture Mapping Unit，也就是用来做纹理映射的计算单元，它也可以认为是另一种类型的 Shader。

![img](/images/951413iMgBlog/14d05a43f559cecff2b0813e8d5bdde2.png)

2080 的主频是 1515MHz，如果自动超频（Boost）的话，可以到 1700MHz。而 NVidia 的显卡，根据硬件架构的设计，每个时钟周期可以执行两条指令。所以，能做的浮点数运算的能力，就是：

>  （2944 + 184）× 1700 MHz × 2  = 10.06  TFLOPS

最新的 Intel i9 9900K 的性能是多少呢？不到 1TFLOPS。而 2080 显卡和 9900K 的价格却是差不多的。所以，在实际进行深度学习的过程中，用 GPU 所花费的时间，往往能减少一到两个数量级。而大型的深度学习模型计算，往往又是多卡并行，要花上几天乃至几个月。这个时候，用 CPU 显然就不合适了。

## 现场可编程门阵列FPGA（Field-Programmable Gate Array）

设计芯片十分复杂，还要不断验证。

那么不用单独制造一块专门的芯片来验证硬件设计呢？能不能设计一个硬件，通过不同的程序代码，来操作这个硬件之前的电路连线，通过“编程”让这个硬件变成我们设计的电路连线的芯片呢？这就是FPGA

- P 代表 Programmable，这个很容易理解。也就是说这是一个可以通过编程来控制的硬件。
- G 代表 Gate 也很容易理解，它就代表芯片里面的门电路。我们能够去进行编程组合的就是这样一个一个门电路。
- A 代表的 Array，叫作阵列，说的是在一块 FPGA 上，密密麻麻列了大量 Gate 这样的门电路。
- 最后一个 F，不太容易理解。它其实是说，一块 FPGA 这样的板子，可以在“现场”多次进行编程。它不像 PAL（Programmable Array Logic，可编程阵列逻辑）这样更古老的硬件设备，只能“编程”一次，把预先写好的程序一次性烧录到硬件里面，之后就不能再修改了。

FPGA 通过“软件”来控制“硬件”

## ASIC（Application-Specific Integrated Circuit）专用集成电路

为解决特定应用问题而定制设计的集成电路，就是 ASIC（Application Specific IC）。当 ASIC 规模够大，逐渐通用起来，某类 ASIC 就会有一个专有名称，成为一个品类。例如现在用来解决人工智能问题的神经网络处理器。

除了 CPU、GPU，以及刚刚的 FPGA，我们其实还需要用到很多其他芯片。比如，现在手机里就有专门用在摄像头里的芯片；录音笔里会有专门处理音频的芯片。尽管一个 CPU 能够处理好手机拍照的功能，也能处理好录音的功能，但是我们直接在手机或者录音笔里塞上一个 Intel CPU，显然比较浪费。

因为 ASIC 是针对专门用途设计的，所以它的电路更精简，单片的制造成本也比 CPU 更低。而且，因为电路精简，所以通常能耗要比用来做通用计算的 CPU 更低。而我们上一讲所说的早期的图形加速卡，其实就可以看作是一种 ASIC。

因为 ASIC 的生产制造成本，以及能耗上的优势，过去几年里，有不少公司设计和开发 ASIC 用来“挖矿”。这个“挖矿”，说的其实就是设计专门的数值计算芯片，用来“挖”比特币、ETH 这样的数字货币。

如果量产的ASIC比较小的话可以直接用FPGA来实现

## TPU 张量处理器（tensor processing unit）

**张量处理器**（英语：tensor processing unit，缩写：TPU）是[Google](https://baike.baidu.com/item/Google)为[机器学习](https://baike.baidu.com/item/机器学习)定制的专用芯片（ASIC），专为Google的[深度学习](https://baike.baidu.com/item/深度学习)框架[TensorFlow](https://baike.baidu.com/item/TensorFlow)而设计。

在性能上，TPU 比现在的 CPU、GPU 在深度学习的推断任务上，要快 15～30 倍。而在能耗比上，更是好出 30～80 倍。另一方面，Google 已经用 TPU 替换了自家数据中心里 95% 的推断任务，可谓是拿自己的实际业务做了一个明证。

## 其它基础知识

**晶振频率**：控制CPU上的晶体管开关切换频率。一次晶振就是一个cycle。

从最简单的单指令周期 CPU 来说，其实时钟周期应该是放下最复杂的一条指令的时间长度。但是，我们现在实际用的都没有单指令周期 CPU 了，而是采用了流水线技术。采用了流水线技术之后，单个时钟周期里面，能够执行的就不是一个指令了。我们会把一条机器指令，拆分成很多个小步骤。不同的指令的步骤数量可能还不一样。不同的步骤的执行时间，也不一样。所以，一个时钟周期里面，能够放下的是最耗时间的某一个指令步骤。

不过没有pipeline，一条指令最少也要N个circle（N就是流水线深度）；但是理想情况下流水线跑满的话一个指令也就只需要一个circle了，也就是IPC能到理论最大值1； 加上超标流水线一般IPC都能4，就是一般CPU的超标量。

**制程**：7nm、14nm、4nm都是指的晶体大小，用更小的晶体可以在相同面积CPU上集成更多的晶体数量，那么CPU的运算能力也更强。增加晶体管可以增加硬件能够支持的指令数量，增加数字通路的位数，以及利用好电路天然的并行性，从硬件层面更快地实现特定的指。打个比方，比如我们最简单的电路可以只有加法功能，没有乘法功能。乘法都变成很多个加法指令，那么实现一个乘法需要的指令数就比较多。但是如果我们增加晶体管在电路层面就实现了这个，那么需要的指令数就变少了，执行时间也可以缩短。



> 功耗 ~= 1/2 ×负载电容×电压的平方×开关频率×晶体管数量

功耗和电压的平方是成正比的。这意味着电压下降到原来的 1/5，整个的功耗会变成原来的 1/25。

堆栈溢出：函数调用用压栈来保存地址、变量等相关信息。没有选择直接嵌套扩展代码是避免循环调用下嵌套是个无尽循环，inline函数内联就是一种嵌套代码扩展优化。



windows下的exe文件之所以没法放到linux上运行（都是intel x86芯片），是因为可执行程序要经过链接，将所依赖的库函数调用合并进来形成可执行文件。这个可执行文件在Linux 下的 ELF（Execuatable and Linkable File Format） 文件格式，而 Windows 的可执行文件格式是一种叫作 PE（Portable Executable Format）的文件格式。Linux 下的装载器只能解析 ELF 格式而不能解析 PE 格式。而且windows和linux的库函数必然不一样，没法做到兼容。

**链接器**: 扫描所有输入的目标文件，然后把所有符号表里的信息收集起来，构成一个全局的符号表。然后再根据重定位表，把所有不确定要跳转地址的代码，根据符号表里面存储的地址，进行一次修正。最后，把所有的目标文件的对应段进行一次合并，变成了最终的可执行代码。这也是为什么，可执行文件里面的函数调用的地址都是正确的。

![img](/images/951413iMgBlog/997341ed0fa9018561c7120c19cfa2a7.jpg)

**虚拟内存地址**：应用代码可执行地址必须是连续，这也就意味着一个应用的内存地址必须连续，实际一个OS上会运行多个应用，没办法保证地址连续，所以可以通过虚拟地址来保证连续，虚拟地址再映射到实际零散的物理地址上（可以解决碎片问题），这个零散地址的最小组织形式就是Page。虚拟地址本来是连续的，使用一阵后数据部分也会变成碎片，代码部分是不可变的，一直连续。另外虚拟地址也方便了OS层面的库共享。

为了扩大虚拟地址到物理地址的映射范围同时又要尽可能少地节约空间，虚拟地址到物理地址的映射一般分成了四级Hash，这样4Kb就能管理256T内存。但是带来的问题就是要通过四次查找使得查找慢，这时引入TLAB来换成映射关系。

**共享库**：在 Windows 下，这些共享库文件就是.dll 文件，也就是 Dynamic-Link Libary（DLL，动态链接库）。在 Linux 下，这些共享库文件就是.so 文件，也就是 Shared Object（一般我们也称之为动态链接库). 不同的进程，调用同样的 lib.so，各自 全局偏移表（GOT，Global Offset Table） 里面指向最终加载的动态链接库里面的虚拟内存地址是不同的, 各个程序各自维护好自己的 GOT，能够找到对应的动态库就好了, 有点像函数指针。

![img](/images/951413iMgBlog/1144d3a2d4f3f4f87c349a93429805c8.jpg)

符号表：/boot/System.map 和 /proc/kallsyms 

**超线程（Hyper-Threading）**: 在CPU内部增加寄存器等硬件设施，但是ALU、译码器等关键单元还是共享。在一个物理 CPU 核心内部，会有双份的 PC 寄存器、指令寄存器乃至条件码寄存器。超线程的目的，是在一个线程 A 的指令，在流水线里停顿的时候，让另外一个线程去执行指令。因为这个时候，CPU 的译码器和 ALU 就空出来了，那么另外一个线程 B，就可以拿来干自己需要的事情。这个线程 B 可没有对于线程 A 里面指令的关联和依赖。

## 分支预测案例

这个案例循环次数少, 在arm下case1反而更快，如截图

```
#include "stdio.h"
#include <stdlib.h>
#include <time.h>

long timediff(clock_t t1, clock_t t2) {
    long elapsed;
    elapsed = ((double)t2 - t1) / CLOCKS_PER_SEC * 1000;
    return elapsed;
}

int main(int argc, char *argv[])
{
    int j=0;
    int k=0;
    int c=0;
    clock_t start=clock();
    for(j=0; j<100000; j++){
        for(k=0; k<1000; k++){
					for(c=0; c<100; c++){
			}
		}
    }
    clock_t end =clock();
    printf("%lu\n", timediff(start,end));    //case1

    start=clock();
    for(j=0; j<100; j++){
        for(k=0; k<1000; k++){
					for(c=0; c<100000; c++){
			}
		}
    }
    end =clock();
    printf("%lu\n", timediff(start,end));   //case2
    return 0;
}
```

![image-20210512132121856](/images/951413iMgBlog/image-20210512132121856.png)

x86_64下的执行结果，确实是case2略快

```
#taskset -c 0 ./for_prediction.out
25560
23420

#taskset -c 0 ./for_prediction.out
25510
23410
```

case1的branch miss大概接近1%（看0 core上的 BrchMiss%， 数据由xperf 1.3.8采集）

![image-20210517111209985](/images/951413iMgBlog/image-20210517111209985.png)

case2的branch miss降到了0，不过两者在x86上的IPC都是0.49，所以最终的执行时间差异不大

![image-20210517111244550](/images/951413iMgBlog/image-20210517111244550.png)

![image-20210512133536939](/images/951413iMgBlog/image-20210512133536939.png)



## 总结

路：就是socket、也就是封装后的物理CPU

Die：从晶圆上切割下来的CPU(包含多个core、北桥、GPU等)，Die的大小可以自由决定，得考虑成本和性能, Die做成方形便于切割和测试

封装：将一个或多个Die封装成一个物理上可以售卖的CPU

node：同一个Die下的多个core以及他们对应的内存

现在计算机系统的CPU和芯片组内核Die都是先封装到一个印制板上（PCB，printed circuit board），再通过LGA等等插槽（Socket）连上主板或直接焊接在主板上。这个过程叫做封装（Package），相关技术叫做封装技术。