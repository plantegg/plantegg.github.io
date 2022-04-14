---
title: 飞腾ARM芯片-FT2500的性能测试
date: 2021-05-15 17:30:03
categories:
    - CPU
tags:
    - Linux
    - CPU
    - arm
    - x86
    - perf
    - performance
    - FT2500
---

# 飞腾ARM芯片-FT2500的性能测试

## ARM

 ARM公司最早是由赫尔曼·豪泽（Hermann Hauser）和工程师Chris Curry在1978年创立（早期全称是 Acorn RISC Machine），后来改名为现在的ARM公司（Advanced RISC Machine）

![img](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/ac0bac75ae745316e0c011ffdc5a78a5.png)

### ARM 芯片厂家

查看厂家

> #cat /proc/cpuinfo |grep implementer
> 
> CPU implementer    : 0x70
> 
> #cat /sys/devices/system/cpu/cpu0/regs/identification/midr_el1
> 0x00000000701f6633  // 70 表示厂家

vendor id对应厂家

| Vendor Name      | Vendor ID |
|:---------------- |:--------- |
| ARM              | 0x41      |
| Broadcom         | 0x42      |
| Cavium           | 0x43      |
| DigitalEquipment | 0x44      |
| HiSilicon        | 0x48      |
| Infineon         | 0x49      |
| Freescale        | 0x4D      |
| NVIDIA           | 0x4E      |
| APM              | 0x50      |
| Qualcomm         | 0x51      |
| Marvell          | 0x56      |
| Intel            | 0x69      |
| 飞腾               | 0x70      |

## 飞腾ARM芯片介绍

**飞腾处理器**，又称**银河飞腾处理器**，是由[中国人民解放军国防科学技术大学](https://zh.wikipedia.org/wiki/中國人民解放軍國防科學技術大學)研制的一系列嵌入式[数字信号处理器](https://zh.wikipedia.org/wiki/数字信号处理器)（DSP）和[中央处理器](https://zh.wikipedia.org/wiki/中央处理器)（CPU）芯片。[[1\]](https://zh.wikipedia.org/wiki/飞腾处理器#cite_note-cw-1)这个处理器系列的研发，是由国防科技大的[邢座程](https://zh.wikipedia.org/w/index.php?title=邢座程&action=edit&redlink=1)教授[[2\]](https://zh.wikipedia.org/wiki/飞腾处理器#cite_note-2)带领的团队负责研发。[[3\]](https://zh.wikipedia.org/wiki/飞腾处理器#cite_note-Xing_671-3)其[商业化](https://zh.wikipedia.org/w/index.php?title=商業化&action=edit&redlink=1)[推广](https://zh.wikipedia.org/wiki/推廣)则是由[中国电子信息产业集团有限公司](https://zh.wikipedia.org/wiki/中国电子信息产业集团有限公司)旗下的天津飞腾信息技术有限公司负责。

飞腾公司在早期，考察了SPARC、MIPS、ALPHA架构，这三种指令集架构都可以以极其低廉的价格（据说SPARC的授权价只有99美元，ALPHA不要钱）获得授权，飞腾选择了SPARC架构进行了CPU的研发。

2012年ARM正式推出了自己的第一个64位指令集处理器架构ARMv8，进入服务器等新的领域。此后飞腾放弃了SPARC，拿了ARMv8指令集架构的授权，全面转向了ARM阵营，芯片roadmap如下：

![img](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/3407604faa7ca9a87fa26610606081ab.png)

### [测试芯片详细信息](https://pdf.dfcfw.com/pdf/H3_AP202010201422468889_1.pdf?1603181661000.pdf)

2020 年 7 月 23 日，飞腾发布新一代高可扩展多路服务器芯片腾云 S2500，采用 16nm 工艺， 主频 2.0~2.2Ghz，拥有 64 个 FTC663 内核，片内集成 64MB 三级 Cache，支持 8 个 DDR4-3200 存 储通道，功耗 150W。 

基于 ARM 架构，兼具高可拓展性和低功耗，扩展支持 2 路到 8 路直连。与主流架构 X86 相比， ARM 架构具备低功耗、低发热和低成本的优势，ARM 单核的面积仅为 X86 核的 1/7，同样芯片尺寸下可以继承更多核心数，可以通过增加核心数提高性能，在性能快速提升下，也能保持较低的功耗，符合云计算场景下并行计算上高并发和高效率的要求，也能有效控制服务器的能耗和成本支出。腾云 S2500 增加了 4 个直连接口，总带宽 800Gbps，支持 2 路、4 路和 8 路直连，具备高可 拓展性，可以形成 128 核到 512 核的计算机系统，带动算力提升。

飞腾(FT2500), ARMv8架构，主频2.1G，服务器两路，每路64个物理core，没有超线程，总共16个numa，每个numa 8个core

```
#dmidecode -t processor
# dmidecode 3.0
Getting SMBIOS data from sysfs.
SMBIOS 3.2.0 present.
# SMBIOS implementations newer than version 3.0 are not
# fully supported by this version of dmidecode.

Handle 0x0004, DMI type 4, 48 bytes
Processor Information
    Socket Designation: BGA3576
    Type: Central Processor
    Family: <OUT OF SPEC>
    Manufacturer: PHYTIUM
    ID: 00 00 00 00 70 1F 66 22
    Version: FT2500
    Voltage: 0.8 V
    External Clock: 50 MHz
    Max Speed: 2100 MHz
    Current Speed: 2100 MHz
    Status: Populated, Enabled
    Upgrade: Other
    L1 Cache Handle: 0x0005
    L2 Cache Handle: 0x0007
    L3 Cache Handle: 0x0008
    Serial Number: 1234567
    Asset Tag: No Asset Tag
    Part Number: NULL
    Core Count: 64
    Core Enabled: 64
    Thread Count: 64
    Characteristics:
        64-bit capable
        Multi-Core
        Hardware Thread
        Execute Protection
        Enhanced Virtualization
        Power/Performance Control

#lscpu
Architecture:          aarch64
Byte Order:            Little Endian
CPU(s):                128
On-line CPU(s) list:   0-127
Thread(s) per core:    1
Core(s) per socket:    64
Socket(s):             2
NUMA node(s):          16
Model:                 3
BogoMIPS:              100.00
L1d cache:             32K
L1i cache:             32K
L2 cache:              2048K
L3 cache:              65536K
NUMA node0 CPU(s):     0-7
NUMA node1 CPU(s):     8-15
NUMA node2 CPU(s):     16-23
NUMA node3 CPU(s):     24-31
NUMA node4 CPU(s):     32-39
NUMA node5 CPU(s):     40-47
NUMA node6 CPU(s):     48-55
NUMA node7 CPU(s):     56-63
NUMA node8 CPU(s):     64-71
NUMA node9 CPU(s):     72-79
NUMA node10 CPU(s):    80-87
NUMA node11 CPU(s):    88-95
NUMA node12 CPU(s):    96-103
NUMA node13 CPU(s):    104-111
NUMA node14 CPU(s):    112-119
NUMA node15 CPU(s):    120-127
Flags:                 fp asimd evtstrm aes pmull sha1 sha2 crc32 cpuid

node distances:
node   0   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15
  0:  10  20  40  30  20  30  50  40  100  100  100  100  100  100  100  100
  1:  20  10  30  40  50  20  40  50  100  100  100  100  100  100  100  100
  2:  40  30  10  20  40  50  20  30  100  100  100  100  100  100  100  100
  3:  30  40  20  10  30  20  40  50  100  100  100  100  100  100  100  100
  4:  20  50  40  30  10  50  30  20  100  100  100  100  100  100  100  100
  5:  30  20  50  20  50  10  50  40  100  100  100  100  100  100  100  100
  6:  50  40  20  40  30  50  10  30  100  100  100  100  100  100  100  100
  7:  40  50  30  50  20  40  30  10  100  100  100  100  100  100  100  100
  8:  100  100  100  100  100  100  100  100  10  20  40  30  20  30  50  40
  9:  100  100  100  100  100  100  100  100  20  10  30  40  50  20  40  50
 10:  100  100  100  100  100  100  100  100  40  30  10  20  40  50  20  30
 11:  100  100  100  100  100  100  100  100  30  40  20  10  30  20  40  50
 12:  100  100  100  100  100  100  100  100  20  50  40  30  10  50  30  20
 13:  100  100  100  100  100  100  100  100  30  20  50  20  50  10  50  40
 14:  100  100  100  100  100  100  100  100  50  40  20  40  30  50  10  30
 15:  100  100  100  100  100  100  100  100  40  50  30  50  20  40  30  10
```

![image-20210422121346490](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20210422121346490.png)

cpu详细信息：

![img](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/e177902c-73b2-4535-9c1f-2726451820db.png)

飞腾芯片，按如下distance绑核基本没区别！展示出来的distance是假的一样

![img](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/5a19ff61-68db-4c65-be4c-6b6c155a8a29.png)

FT2500芯片集成的 64 个处理器核心，划分为 8 个 Panel，每个 Panel 中有两个 Cluster (每个 Cluster 包含 4 个处理器核心及共享的 2M 二级 cache)、两个本地目录控 制部件(DCU)、一个片上网络路由器节点(Cell)和一个紧密耦合的访存控制 器(MCU)。Panel 之间通过片上网络接口连接，一致性维护报文、数据报文、 调测试报文、中断报文等统一从同一套网络接口进行路由和通信

一个Panel的实现是FTC663版本，采用四发射乱序超标量流水线结构，兼容 ARMv8 指令集，支持 EL0~EL3 多个特权级。流水线分为取指、译码、分派、执 行和写回五个阶段，采用顺序取指、乱序执行、顺序提交的多发射执行机制，取 值宽度、译码宽度、分派宽度均是 4 条指令，共有 9 个执行部件(或者称为 9 条功能流水线)，分别是 4 个整数部件、2 个浮点部件、1 个 load 部件、1 个 load/store 部件和 1 个系统管理指令执行部件。浮点流水线能够合并执行双路浮点 SIMD 指 令，实现每拍可以执行 4 条双精度浮点操作的峰值性能。

![image-20210910120438276](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20210910120438276.png)

猜测FT2500 64core用的是一个Die, 但是core之间的连接是Ring Bus，而Ring Bus下core太多后延迟会快速增加，所以一个Die 内部做了8个小的Ring Bus，每个Ring Bus下8个core。

### 飞腾官方提供的测试结果

![image-20210909175954574](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20210909175954574.png)

### 飞腾2500 和 鲲鹏9200 参数对比

![image-20210422095217195](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20210422095217195.png)

### FT2000与FT2500差异

下表是FT2000和FT2500产品规格对比表，和芯片的单核内部结构变化较少，多了L3，主频提高了，其他基本没有变化。

| **特征**   | **FT-2000+/64**                                              | **FT-2500**                                                  |
| -------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| 指令       | 兼容 ARM V8 指令集 FTC662 内核                                      | 兼容 ARM V8 指令集FTC663 内核                                       |
| Core数    | 64个                                                          | 64个                                                          |
| 频率       | 2.2GHZ/2.0GHZ/1.8GHZ                                         | **2.0~2.3GHz**                                               |
| 体系架构     | NUMA                                                         | NUMA                                                         |
| RAS      | 无                                                            | 支持                                                           |
| 加解密      | 无                                                            | **ASE128、SHA1、SHA2-256、PMULL**                               |
| L1 Cache | 每个核独占32KB指令Cache与32KB数据Cache                                 | 每个核独占32K指令Cache与32K数据Cache                                   |
| L2 Cache | 共32MB，每4个核共享2MB                                              | 共32MB，每4个核共享2MB                                              |
| L3 Cache | 无                                                            | **64MB**                                                     |
| LMU数量    | 8个                                                           | 8个                                                           |
| 支持最大容量   | 1TB                                                          | 1TB*socket数量                                                 |
| 支持最大频率   | 3200MHZ                                                      | 支持3200MHZ                                                    |
| 外接设备     | 支持带 ECC 的 DDR4 DIMM，支持 RDIMM、UDIMM、SODIMM、 LR-DIMM，电压 1.2V   | 支持带 ECC 的 DDR4 DIMM，支持 RDIMM、UDIMM、SODIMM、LR-DIMM，电压 1.2V    |
| 镜像存储     | 无                                                            | 每两个MCU互为备份                                                   |
| PCIe     | PCIE3.02 个 x16 和 1 个 x1每个 x16 可拆分成 2 个 x8，支持翻转               | PCIE3.01 个 x16 和 1 个 x1x16 可拆分成 2 个 x8，支持翻转                  |
| SPI      | 支持 4 个片选，单片最大支持容量为 512MB，电压 1.8V                             | 支持 4 个片选，单片最大支持容量为 512MB，电压 1.8V                             |
| UART     | 4个 UART，其中 1 个为 9 线全功能串口，3 个为 3 线调试串口                        | 4个 UART，其中 1 个为 9 线全功能串口，3 个为 3 线调试串口                        |
| GPIO     | 4 个 8 位 GPIO 接口，GPIOA[0:7]，GPIOB[0:7]，GPIOC[0:7]， GPIOD[0:7] | 4 个 8 位 GPIO 接口，GPIOA[0:7]，GPIOB[0:7]，GPIOC[0:7]， GPIOD[0:7] |
| LPC      | 1 个 LPC 接口，兼容 Intel Low Pin Count 协议, 电压 1.8V                | 1 个 LPC 接口，兼容 Intel Low Pin Count 协议, 电压 1.8V                |
| I2C      | 2 个 I2C master 控制器                                           | 2 个 I2C master /Slave控制器,2个slave控制器                          |
| 直连       | 无                                                            | 四个直连通路，每路X4个lane，每条lane速率为25Gbps，支持2路、4路、8路                  |

## 飞腾ARM芯片性能测试数据

以下测试场景基本都是运行CPU和网络瓶颈的业务逻辑，绑核前IPC只有0.08

![img](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/16b271c8-5132-4273-a26a-4b35e8f92882.png)

绑核后对性能提升非常明显：

![img](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/4d4fdebb-6146-407e-881d-19170fbfd82b.png)

点查场景：

![image-20210425092158127](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20210425092158127.png)

如上是绑48-63号核

![image-20210425091727122](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20210425091727122.png)

![image-20210425091557750](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20210425091557750.png)

![image-20210425093630438](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20210425093630438.png)

绑不同的核性能差异比较大，比如同样绑第一个socket最后16core和绑第二个socket最后16core，第二个socket的最后16core性能要好25-30%---**这是因为网卡软中断，如果将软中断绑定到0-4号cpu后差异基本消失**,因为网卡队列设置的是60，基本跑在前60core上，也就是第一个socket上。

点查场景绑核和不绑核性能能差1倍, 将table分表后，物理rt稳定了(**截图中物理rt下降是因为压力小了**--待证)

### 点查场景压测16个core的节点

一个节点16core，16个core绑定到14、15号NUMA上，然后压测

```
#perl numa-maps-summary.pl </proc/79694/numa_maps //16core
N0        :         1103 (  0.00 GB)
N1        :       107368 (  0.41 GB)
N10       :       144736 (  0.55 GB)
N11       :        16919 (  0.06 GB)
N12       :       551987 (  2.11 GB)
N13       :        59499 (  0.23 GB)
N14       :      5621573 ( 21.44 GB)  //内存就近分配
N15       :      6200398 ( 23.65 GB)
N2        :          700 (  0.00 GB)
N3        :           89 (  0.00 GB)
N4        :         5784 (  0.02 GB)
N5        :           77 (  0.00 GB)
N6        :          426 (  0.00 GB)
N7        :          472 (  0.00 GB)
N8        :          107 (  0.00 GB)
N9        :         6137 (  0.02 GB)
active    :           85 (  0.00 GB)
anon      :     12712675 ( 48.50 GB)
dirty     :     12712679 ( 48.50 GB)
kernelpagesize_kB:        17444 (  0.07 GB)
mapmax    :         1598 (  0.01 GB)
mapped    :         4742 (  0.02 GB)

#perf stat -e branch-misses,bus-cycles,cache-misses,cache-references,cpu-cycles,instructions,L1-dcache-load-misses,L1-dcache-loads,L1-dcache-store-misses,L1-dcache-stores,L1-icache-load-misses,L1-icache-loads,branch-load-misses,branch-loads,dTLB-load-misses,iTLB-load-misses -a -p 79694
^C
 Performance counter stats for process id '79694':

        1719788217      branch-misses                                                 (39.70%)
      311069393237      bus-cycles                                                    (38.07%)
        2021349865      cache-misses              #    6.669 % of all cache refs      (38.32%)
       30308501243      cache-references                                              (39.67%)
      310980728138      cpu-cycles                                                    (46.46%)
       67298903097      instructions              #    0.22  insns per cycle          (47.63%)
        1983728595      L1-dcache-load-misses     #    6.62% of all L1-dcache hits    (48.76%)
       29943167305      L1-dcache-loads                                               (47.89%)
        1957152091      L1-dcache-store-misses                                        (46.14%)
       29572767575      L1-dcache-stores                                              (44.91%)
        4223808613      L1-icache-load-misses                                         (43.08%)
       49122358099      L1-icache-loads                                               (38.15%)
        1724605628      branch-load-misses                                            (37.63%)
       15225535577      branch-loads                                                  (36.61%)
         997458038      dTLB-load-misses                                              (35.81%)
         542426693      iTLB-load-misses                                              (34.98%)

      10.489297296 seconds time elapsed

[  29s] threads: 160, tps: 0.00, reads/s: 15292.01, writes/s: 0.00, response time: 25.82ms (95%)
[  30s] threads: 160, tps: 0.00, reads/s: 16399.99, writes/s: 0.00, response time: 23.58ms (95%)
[  31s] threads: 160, tps: 0.00, reads/s: 17025.00, writes/s: 0.00, response time: 20.73ms (95%)
[  32s] threads: 160, tps: 0.00, reads/s: 16991.01, writes/s: 0.00, response time: 22.83ms (95%)
[  33s] threads: 160, tps: 0.00, reads/s: 18400.94, writes/s: 0.00, response time: 21.29ms (95%)
[  34s] threads: 160, tps: 0.00, reads/s: 17760.05, writes/s: 0.00, response time: 20.69ms (95%)
[  35s] threads: 160, tps: 0.00, reads/s: 17935.00, writes/s: 0.00, response time: 20.23ms (95%)
[  36s] threads: 160, tps: 0.00, reads/s: 18296.98, writes/s: 0.00, response time: 20.10ms (95%)
[  37s] threads: 160, tps: 0.00, reads/s: 18111.02, writes/s: 0.00, response time: 20.56ms (95%)
[  38s] threads: 160, tps: 0.00, reads/s: 17782.99, writes/s: 0.00, response time: 20.54ms (95%)
[  38s] threads: 160, tps: 0.00, reads/s: 21412.13, writes/s: 0.00, response time: 11.96ms (95%)
[  40s] threads: 160, tps: 0.00, reads/s: 18027.85, writes/s: 0.00, response time: 20.18ms (95%)
[  41s] threads: 160, tps: 0.00, reads/s: 17907.04, writes/s: 0.00, response time: 20.02ms (95%)
[  42s] threads: 160, tps: 0.00, reads/s: 13860.96, writes/s: 0.00, response time: 23.58ms (95%)
[  43s] threads: 160, tps: 0.00, reads/s: 18491.02, writes/s: 0.00, response time: 20.18ms (95%)
[  44s] threads: 160, tps: 0.00, reads/s: 17673.02, writes/s: 0.00, response time: 20.85ms (95%)
[  45s] threads: 160, tps: 0.00, reads/s: 18048.96, writes/s: 0.00, response time: 21.47ms (95%)
[  46s] threads: 160, tps: 0.00, reads/s: 18130.03, writes/s: 0.00, response time: 22.13ms (95%)      
```

### 点查场景压测8个core的节点

因为每个NUMA才8个core，所以测试一下8core的节点绑核前后性能对比。实际结果看起来和16core节点绑核性能提升差不多。

绑核前后对比：绑核后QPS翻倍，绑核后的服务rt从7.5降低到了2.2，rt下降非常明显，可以看出主要是绑核前跨numa访问慢。**实际这个测试是先跑的不绑核，内存分布在所有NUMA上，没有重启再绑核就直接测试了，所以性能提升不明显，因为内存已经跨NUMA分配完毕了**。

![image-20210427093424116](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20210427093424116.png)

```shell
#perl numa-maps-summary.pl </proc/33727/numa_maps //绑定8core后，在如下内存分配下QPS能到11000，但是抖动略大，应该是一个numa内存不够了
N0        :          551 (  0.00 GB)
N1        :      1023418 (  3.90 GB)
N10       :        52065 (  0.20 GB)
N11       :       190737 (  0.73 GB)
N12       :       516115 (  1.97 GB)
N13       :       186556 (  0.71 GB)
N14       :      1677489 (  6.40 GB)
N15       :       324531 (  1.24 GB)
N2        :          397 (  0.00 GB)
N3        :            8 (  0.00 GB)
N4        :          398 (  0.00 GB)
N6        :          349 (  0.00 GB)
N7        :          437 (  0.00 GB)
N8        :       108508 (  0.41 GB)
N9        :        69162 (  0.26 GB)
active    :         2296 (  0.01 GB)
anon      :      4144997 ( 15.81 GB)
dirty     :      4145002 ( 15.81 GB)
kernelpagesize_kB:         7508 (  0.03 GB)
mapmax    :         1548 (  0.01 GB)
mapped    :         5724 (  0.02 GB)

[ 349s] threads: 100, tps: 0.00, reads/s: 11088.99, writes/s: 0.00, response time: 20.18ms (95%)
[ 350s] threads: 100, tps: 0.00, reads/s: 8778.98, writes/s: 0.00, response time: 26.20ms (95%)
[ 351s] threads: 100, tps: 0.00, reads/s: 7995.01, writes/s: 0.00, response time: 31.79ms (95%)
[ 352s] threads: 100, tps: 0.00, reads/s: 9549.01, writes/s: 0.00, response time: 23.90ms (95%)
[ 353s] threads: 100, tps: 0.00, reads/s: 8757.99, writes/s: 0.00, response time: 24.60ms (95%)
[ 354s] threads: 100, tps: 0.00, reads/s: 10288.02, writes/s: 0.00, response time: 21.85ms (95%)
[ 355s] threads: 100, tps: 0.00, reads/s: 11003.97, writes/s: 0.00, response time: 18.90ms (95%)
[ 356s] threads: 100, tps: 0.00, reads/s: 11111.01, writes/s: 0.00, response time: 20.51ms (95%)
[ 357s] threads: 100, tps: 0.00, reads/s: 11426.00, writes/s: 0.00, response time: 17.98ms (95%)
[ 358s] threads: 100, tps: 0.00, reads/s: 11007.01, writes/s: 0.00, response time: 19.35ms (95%)
[ 359s] threads: 100, tps: 0.00, reads/s: 10425.00, writes/s: 0.00, response time: 20.92ms (95%)
[ 360s] threads: 100, tps: 0.00, reads/s: 10024.00, writes/s: 0.00, response time: 23.17ms (95%)
[ 361s] threads: 100, tps: 0.00, reads/s: 10100.98, writes/s: 0.00, response time: 22.94ms (95%)
[ 362s] threads: 100, tps: 0.00, reads/s: 8164.01, writes/s: 0.00, response time: 27.48ms (95%)
[ 363s] threads: 100, tps: 0.00, reads/s: 6593.00, writes/s: 0.00, response time: 37.10ms (95%)
[ 364s] threads: 100, tps: 0.00, reads/s: 7008.00, writes/s: 0.00, response time: 32.32ms (95%)

#调整这个实例到内存充足的NUMA7上 QPS峰值能到14000，稳定在11000-13000之间，RT明显更稳定了
#perl numa-maps-summary.pl </proc/78245/numa_maps
N0        :          551 (  0.00 GB)
N1        :          115 (  0.00 GB)
N11       :          695 (  0.00 GB)
N12       :          878 (  0.00 GB)
N13       :         2019 (  0.01 GB)
N14       :           25 (  0.00 GB)
N15       :           60 (  0.00 GB)
N2        :          394 (  0.00 GB)
N3        :            8 (  0.00 GB)
N4        :       197713 (  0.75 GB)
N6        :          349 (  0.00 GB)
N7        :      3957844 ( 15.10 GB)
N8        :            1 (  0.00 GB)
active    :           10 (  0.00 GB)
anon      :      4154693 ( 15.85 GB)
dirty     :      4154698 ( 15.85 GB)
kernelpagesize_kB:         7452 (  0.03 GB)
mapmax    :         1567 (  0.01 GB)
mapped    :         5959 (  0.02 GB)

[ 278s] threads: 100, tps: 0.00, reads/s: 13410.99, writes/s: 0.00, response time: 15.36ms (95%)
[ 279s] threads: 100, tps: 0.00, reads/s: 14049.99, writes/s: 0.00, response time: 15.54ms (95%)
[ 280s] threads: 100, tps: 0.00, reads/s: 13107.02, writes/s: 0.00, response time: 16.72ms (95%)
[ 281s] threads: 100, tps: 0.00, reads/s: 12431.99, writes/s: 0.00, response time: 17.79ms (95%)
[ 282s] threads: 100, tps: 0.00, reads/s: 13164.01, writes/s: 0.00, response time: 16.33ms (95%)
[ 283s] threads: 100, tps: 0.00, reads/s: 13455.01, writes/s: 0.00, response time: 16.19ms (95%)
[ 284s] threads: 100, tps: 0.00, reads/s: 12932.01, writes/s: 0.00, response time: 16.22ms (95%)
[ 285s] threads: 100, tps: 0.00, reads/s: 12790.99, writes/s: 0.00, response time: 17.00ms (95%)
[ 286s] threads: 100, tps: 0.00, reads/s: 12706.00, writes/s: 0.00, response time: 17.88ms (95%)
[ 287s] threads: 100, tps: 0.00, reads/s: 11886.00, writes/s: 0.00, response time: 19.43ms (95%)
[ 288s] threads: 100, tps: 0.00, reads/s: 12700.00, writes/s: 0.00, response time: 16.97ms (95%)

#perl numa-maps-summary.pl </proc/54723/numa_maps  //54723绑定在NUMA6上
N0        :          551 (  0.00 GB)
N1        :          115 (  0.00 GB)
N11       :          682 (  0.00 GB)
N12       :          856 (  0.00 GB)
N13       :         2018 (  0.01 GB)
N14       :           25 (  0.00 GB)
N15       :           60 (  0.00 GB)
N2        :      1270166 (  4.85 GB) //不应该分配这里的内存，实际是因为N6内存被PageCache使用掉了

N3        :            8 (  0.00 GB)
N4        :          398 (  0.00 GB)
N6        :      3662400 ( 13.97 GB)
N7        :          460 (  0.00 GB)
N8        :            1 (  0.00 GB)
active    :            9 (  0.00 GB)
anon      :      4931796 ( 18.81 GB)
dirty     :      4931801 ( 18.81 GB)
kernelpagesize_kB:         7920 (  0.03 GB)
mapmax    :         1580 (  0.01 GB)
mapped    :         5944 (  0.02 GB)

#cat /proc/meminfo | grep -i active
Active:         22352360 kB
Inactive:       275173756 kB
Active(anon):      16984 kB
Inactive(anon): 240344208 kB
Active(file):   22335376 kB
Inactive(file): 34829548 kB

#echo 3 > /proc/sys/vm/drop_caches

#cat /proc/meminfo | grep -i active
Active:          1865724 kB
Inactive:       242335632 kB
Active(anon):       7108 kB
Inactive(anon): 240199020 kB
Active(file):    1858616 kB  //回收了大量PageCache内存
Inactive(file):  2136612 kB
#perl numa-maps-summary.pl </proc/54723/numa_maps
N0        :          552 (  0.00 GB)
N1        :          115 (  0.00 GB)
N11       :          682 (  0.00 GB)
N12       :          856 (  0.00 GB)
N13       :         2018 (  0.01 GB)
N14       :           25 (  0.00 GB)
N15       :           60 (  0.00 GB)
N2        :         1740 (  0.01 GB)
N3        :            8 (  0.00 GB)
N4        :          398 (  0.00 GB)
N6        :      4972492 ( 18.97 GB)
N7        :          459 (  0.00 GB)
N8        :            1 (  0.00 GB)
active    :           16 (  0.00 GB)
anon      :      4973486 ( 18.97 GB)
dirty     :      4973491 ( 18.97 GB)
kernelpagesize_kB:         8456 (  0.03 GB)
mapmax    :         1564 (  0.01 GB)
mapped    :         5920 (  0.02 GB)
```

![image-20210427164953340](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20210427164953340.png)

绑核前的IPC：

![image-20210427093625575](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20210427093625575.png)

绑核后的IPC：

![image-20210427095130343](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20210427095130343.png)

**如果是两个8core对一个16core在都最优绑核场景下从上面的数据来看能有40-50%的性能提升，并且RT抖动更小**，这两个8core绑定在同一个Socket下，验证是否争抢，同时可以看到**绑核后性能可以随着加节点线性增加**

![image-20210427172612685](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20210427172612685.png)

![image-20210427173047815](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20210427173047815.png)

![image-20210427173417673](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20210427173417673.png)

结论：不绑核一个FT2500的core点查只有500 QPS，绑核后能到1500QPS, 在Intel 8263下一个core能到6000以上(开日志、没开协程)

### MySQL 数据库场景绑核

通过同一台物理上6个Tomcat节点，总共96个core，压6台MySQL，MySQL基本快打挂了。sysbench 点查，32个分表，增加Tomcat节点进来物理rt就增加，从最初的的1.2ms加到6个Tomcat节点后变成8ms。

![image-20210425180535225](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20210425180535225.png)

MySQL没绑好核，BIOS默认关闭了NUMA，外加12个MySQL分布在物理机上不均匀，3个节点3个MySQL，剩下的物理机上只有一个MySQL实例。

MySQL每个实例32core，管控默认已经做了绑核，但是如果两个MySQL绑在了一个socket上竞争会很激烈，ipc比单独的降一半。

比如这三个MySQL，qps基本均匀，上面两个cpu高，但是没效率，每个MySQL绑了32core，上面两个绑在一个socket上，下面的MySQL绑在另一个socket上，第一个socket还有网络软中断在争抢cpu，飞腾环境下性能真要冲高还有很大空间。

![image-20210425180518926](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20210425180518926.png)

```shell
#第二个MySQL IPC只有第三个的30%多点，这就是为什么CPU高这么多，但是QPS差不多
perf stat -e branch-misses,bus-cycles,cache-misses,cache-references,cpu-cycles,instructions,L1-dcache-load-misses,L1-dcache-loads,L1-dcache-store-misses,L1-dcache-stores,L1-icache-load-misses,L1-icache-loads,branch-load-misses,branch-loads,dTLB-load-misses,iTLB-load-misses  -a -p 61238
^C
 Performance counter stats for process id '61238':

        86,491,052      branch-misses                                                 (58.55%)
    98,481,418,793      bus-cycles                                                    (55.64%)
       113,095,618      cache-misses              #    6.169 % of all cache refs      (53.20%)
     1,833,344,484      cache-references                                              (52.00%)
   101,516,165,898      cpu-cycles                                                    (57.09%)
     4,229,190,014      instructions              #    0.04  insns per cycle          (55.91%)
       111,780,025      L1-dcache-load-misses     #    6.34% of all L1-dcache hits    (55.40%)
     1,764,421,570      L1-dcache-loads                                               (52.62%)
       112,261,128      L1-dcache-store-misses                                        (49.34%)
     1,814,998,338      L1-dcache-stores                                              (48.51%)
       219,372,119      L1-icache-load-misses                                         (49.56%)
     2,816,279,627      L1-icache-loads                                               (49.15%)
        85,321,093      branch-load-misses                                            (50.38%)
     1,038,572,653      branch-loads                                                  (50.65%)
        45,166,831      dTLB-load-misses                                              (51.98%)
        29,892,473      iTLB-load-misses                                              (52.56%)

       1.163750756 seconds time elapsed

#第三个MySQL
perf stat -e branch-misses,bus-cycles,cache-misses,cache-references,cpu-cycles,instructions,L1-dcache-load-misses,L1-dcache-loads,L1-dcache-store-misses,L1-dcache-stores,L1-icache-load-misses,L1-icache-loads,branch-load-misses,branch-loads,dTLB-load-misses,iTLB-load-misses  -a -p 53400
^C
 Performance counter stats for process id '53400':

       295,575,513      branch-misses                                                 (40.51%)
   110,934,600,206      bus-cycles                                                    (39.30%)
       537,938,496      cache-misses              #    8.310 % of all cache refs      (38.99%)
     6,473,688,885      cache-references                                              (39.80%)
   110,540,950,757      cpu-cycles                                                    (46.10%)
    14,766,013,708      instructions              #    0.14  insns per cycle          (46.85%)
       538,521,226      L1-dcache-load-misses     #    8.36% of all L1-dcache hits    (48.00%)
     6,440,728,959      L1-dcache-loads                                               (46.69%)
       533,693,357      L1-dcache-store-misses                                        (45.91%)
     6,413,111,024      L1-dcache-stores                                              (44.92%)
       673,725,952      L1-icache-load-misses                                         (42.76%)
     9,216,663,639      L1-icache-loads                                               (38.27%)
       299,202,001      branch-load-misses                                            (37.62%)
     3,285,957,082      branch-loads                                                  (36.10%)
       149,348,740      dTLB-load-misses                                              (35.20%)
       102,444,469      iTLB-load-misses                                              (34.78%)

       8.080841166 seconds time elapsed
```

12个MySQL流量基本均匀：

![image-20210426083033989](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20210426083033989.png)

### numa太多，每个numa下core比较少

导致跨numa高概率发生，如下是在正常部署下的测试perf 数据，可以看到IPC极低，才0.08，同样的场景在其他家芯片都能打到0.6

![img](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/16b271c8-5132-4273-a26a-4b35e8f92882.png)

执行绑核，将一个进程限制在2个numa内，因为进程需要16core，理论上用8core的进程性能会更好

![img](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/4d4fdebb-6146-407e-881d-19170fbfd82b.png)

可以看到IPC从0.08提升到了0.22，实际能到0.27，对应的业务测试QPS也是原来的4倍。 

用numactl 在启动的时候绑定cpu在 node0、1上，优先使用node0、1的内存，不够再用其它node的内存

```
numactl --cpunodebind 0,1 --preferred 0,1 /u01/xcluster80/bin/mysqld_safe  --defaults-file=/polarx/xcluster3308/my.cnf  --basedir=/u01/xcluster80_current  --datadir=/polarx/xcluster3308/data  --plugin-dir=/u01/xcluster80/lib/plugin  --user=mysql  --log-error=/polarx/xcluster3308/log/alert.log  --open-files-limit=615350  --pid-file=/polarx/xcluster3308/run/mysql.pid  --socket=/polarx/xcluster3308/run/mysql.sock  --cluster-info=11.158.239.200:11308@1  --mysqlx-port=13308  --port=3308
```

### 网卡队列调整

这批机器默认都是双网卡做bond，但是两块网卡是HA，默认网卡队列是60，基本都跑在前面60个core上

将MySQL网卡队列从60个改成6个后MySQL性能提升大概10%

![image-20210426085534983](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20210426085534983.png)

默认第一个MySQL都绑在0-31号核上,其实改少队列加大了0-5号core的压力，但是实际数据表现要好。

## 比较其它

绑核的时候还要考虑磁盘、网卡在哪个socket上，相对来说node和磁盘、网卡在同一个socket下性能要好一些。

左边的mysqld绑定在socket1的64core上，磁盘、网卡都在socket1上；右边的mysqld绑定在0-31core上，网卡在socket0上，但是磁盘在socket1上

右边这个刚好是跨socket访问磁盘，不知道是不是巧合log_flush排位比较高

![image-20210910180305752](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20210910180305752.png)

此时对应的IPC：

![image-20210910181820803](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20210910181820803.png)

如果上面两个进程在没有刷日志的场景下时候对应的IPC两者基本一样：

![image-20210910181909962](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20210910181909962.png)

## 结论

FT2500比同主频Intel x86芯片差了快一个数量级的性能，在对FT2500上的业务按node绑核后性能提升了几倍，但是离Intel x86还有很大的距离

用循环跑多个nop指令在飞腾2500下IPC只能跑到1，据说这是因为nop指令被扔掉了，所以一直在跑跳转循环判断；

对寄存器变量进行++运算，IPC是0.5； 

用如下代码能将IPC跑到2.49，也是我能跑出来的最高IPC了，去掉nop那行，IPC是1.99

```
                register unsigned i=0;
        for (i=0;i<(1u<<31);i++) {
                __asm__ ("nop"); 
        }
```

## 系列文章

[CPU的制造和概念](/2021/06/01/CPU的制造和概念/)

[CPU 性能和Cache Line](/2021/05/16/CPU Cache Line 和性能/)

[Perf IPC以及CPU性能](/2021/05/16/Perf IPC以及CPU利用率/)

[Intel、海光、鲲鹏920、飞腾2500 CPU性能对比](/2021/06/18/几款CPU性能对比/)

[飞腾ARM芯片(FT2500)的性能测试](/2021/05/15/飞腾ARM芯片(FT2500)的性能测试/)

[十年后数据库还是不敢拥抱NUMA？](/2021/05/14/十年后数据库还是不敢拥抱NUMA/)

[一次海光物理机资源竞争压测的记录](/2021/03/07/一次海光物理机资源竞争压测的记录/)

[Intel PAUSE指令变化是如何影响自旋锁以及MySQL的性能的](/2019/12/16/Intel PAUSE指令变化是如何影响自旋锁以及MySQL的性能的/)

## 参考资料

[CPU Utilization is Wrong](http://www.brendangregg.com/blog/2017-05-09/cpu-utilization-is-wrong.html)
