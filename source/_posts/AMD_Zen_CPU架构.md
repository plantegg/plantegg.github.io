---
title: AMD Zen CPU 架构以及不同CPU性能大PK
date: 2021-08-13 17:30:03
categories:
    - CPU
tags:
    - 海光
    - 超线程
    - ADM
    - Zen
    - hygon
---

# AMD Zen CPU 架构以及不同CPU性能大PK

## 前言

本文先介绍AMD Zen 架构，结合前一篇文章《[CPU的生产和概念](https://www.atatech.org/articles/211563)》一起来看效果会更好，在[CPU的生产和概念](https://www.atatech.org/articles/211563)中主要是以Intel方案来介绍，CPU的生产和概念中的 多核和多个CPU方案2 就是指的AMD Zen2架构。

Zen1 和 Intel 还比较像，只是一个CPU会封装多个小的Die来得到多核能力，导致NUMA node比较多。

AMD 从Zen2开始架构有了比较大的变化，Zen2架构改动比较大，将IO从Core Die中抽离出来，形成一个专门的IO Die，这个IO Die可以用上一代的工艺实现来提升成品率降低成本。剩下的core Die 专注在core和cache的实现上，同时可以通过最新一代的工艺来提升性能。并且在一个CPU上封装一个 IO Die + 8个 core Die这样一块CPU做到像Intel一样就是一个大NUMA，但是成本低了很多，也许在云计算时代这么搞比较合适。当然会被大家笑话为胶水核（用胶水把多个Die拼在一起），性能肯定是不如一个大Die好，但是挡不住便宜啊。这估计就是大家所说的 **AMD YES！**吧

比如Core Die用7nm工艺，IO Die用14nm工艺，一块CPU封装8个Core Die+1个IO Die的话既能得到一个多核的CPU成本有非常低，参考 《CPU的生产和概念》中的良品率和成品部分。

介绍完AMD架构后，会拿海光7280这块CPU（实际是OEM的AMD Zen2 架构）和 Intel的CPU用MySQL 来对比一下实际性能。

网上Intel CPU架构、技术参数等各种资料还是很丰富的，但是AMD EPYC就比较少了，所以先来学习一下EPYC的架构特点。



## AMD EPYC CPU演进路线

![img](/Users/ren/src/blog/951413iMgBlog/amd-rome-naples-chiplets.jpg)

后面会针对 第二代的 EPYC来做一个对比测试。

![AMD Accelerated Computing FAD 2020](/Users/ren/src/blog/951413iMgBlog/AMD-Packaging-to-X3D-FAD-2020.jpg)

 AMD EPYC CPU Families:

| Family Name      | AMD EPYC Naples                  | AMD EPYC Rome                             | AMD EPYC Milan                  | AMD EPYC Genoa                   |
| :--------------- | :------------------------------- | :---------------------------------------- | :------------------------------ | :------------------------------- |
| Family Branding  | EPYC 7001                        | EPYC 7002                                 | EPYC 7003                       | EPYC 7004?                       |
| Family Launch    | 2017                             | 2019                                      | 2021                            | 2022                             |
| CPU Architecture | Zen 1                            | Zen 2                                     | Zen 3                           | Zen 4                            |
| Process Node     | 14nm GloFo                       | 7nm TSMC                                  | 7nm TSMC                        | 5nm TSMC                         |
| Platform Name    | SP3                              | SP3                                       | SP3                             | SP5                              |
| Socket           | LGA 4094                         | LGA 4094                                  | LGA 4094                        | LGA 6096                         |
| Max Core Count   | 32                               | 64                                        | 64                              | 96                               |
| Max Thread Count | 64                               | 128                                       | 128                             | 192                              |
| Max L3 Cache     | 64 MB                            | 256 MB                                    | 256 MB                          | 384 MB?                          |
| Chiplet Design   | 4 CCD's (2 CCX's per CCD)，4 Die | 8 CCD's (2 CCX's per CCD) + 1 IOD ，9 Die | 8 CCD's (1 CCX per CCD) + 1 IOD | 12 CCD's (1 CCX per CCD) + 1 IOD |
| Memory Support   | DDR4-2666                        | DDR4-3200                                 | DDR4-3200                       | DDR5-5200                        |
| Memory Channels  | 8 Channel                        | 8 Channel                                 | 8 Channel                       | 12 Channel                       |
| PCIe Gen Support | 64 Gen 3                         | 128 Gen 4                                 | 128 Gen 4                       | 128 Gen 5                        |
| TDP Range        | 200W                             | 280W                                      | 280W                            | 320W (cTDP 400W)                 |

## Zen1

hygon 5280封装后类似下图(一块CPU封装了2个Die，还有封装4个Die的，core更多更贵而已)

![image-20210812204437220](/Users/ren/src/blog/951413iMgBlog/image-20210812204437220.png)

或者4个Die封装在一起

![image-20210813085044786](/Users/ren/src/blog/951413iMgBlog/image-20210813085044786.png)

### Zen1 Die

下面这块Die集成了两个CCX（每个CCX四个物理core), 同时还有IO接口

![Блоки CCX](/Users/ren/src/blog/951413iMgBlog/zeppelin_face_down2.png)

![img](/Users/ren/src/blog/951413iMgBlog/515px-zen-1zep.svg.png)

Quad-Zeppelin Configuration, as found in [EPYC](https://en.wikichip.org/wiki/amd/epyc). 

![img](/Users/ren/src/blog/951413iMgBlog/512px-zen-4zep.svg.png)

### Zen CPU Complex(CCX)

hygon 5280使用这个结构， There are 4 cores per CCX and 2 CCXs per die for 8 cores.

- 44 mm² area
- L3 8 MiB; 16 mm²
- 1,400,000,000 transistors

![amd zen ccx.png](/Users/ren/src/blog/951413iMgBlog/450px-amd_zen_ccx.png)

![amd zen ccx 2](/Users/ren/src/blog/951413iMgBlog/700px-amd_zen_ccx_2_annotated.png)

### 封装后的Zen1（4Die）

![image-20210813085044786](/Users/ren/src/blog/951413iMgBlog/image-20210813085044786.png)

详实数据和结构

![Топология процессора](/Users/ren/src/blog/951413iMgBlog/AMD-EPYC-Infinity-Fabric-Topology-Mapping.webp)

## [Zen2 Rome](https://en.wikichip.org/wiki/amd/microarchitectures/zen_2)

Zen2开始最大的变化就是将IO从Core Die中抽离出来，形成一个专门的IO Die。hygon 7280封装后类似下图：

<img src="/Users/ren/src/blog/951413iMgBlog/image-20210602165525641.png" alt="AMD Rome package with card" style="zoom:50%;" />

![AMD Rome layout](/Users/ren/src/blog/951413iMgBlog/AMD_Rome_layout-617x486.jpg)

![img](/Users/ren/src/blog/951413iMgBlog/amd-rome-feature-chart.jpg)

### Zen2 Core Complex Die 

- TSMC [7-nanometer process](https://en.wikichip.org/wiki/N7)
- 13 metal layers[[1](https://en.wikichip.org/wiki/amd/microarchitectures/zen_2#cite_note-isscc2020j-zen2-1)]
- 3,800,000,000 transistors[[2](https://en.wikichip.org/wiki/amd/microarchitectures/zen_2#cite_note-isscc2020p-chiplet-2)]
- Die size: 74 mm²
- CCX size: 31.3 mm²， 4core per CCX // 16M L3 perf CCX
- 2 × 16 MiB L3 cache: 2 × 16.8 mm² (estimated) // 中间蓝色部分是L3 16M，一个Die封装两个CCX的情况下

![AMD Zen 2 CCD.jpg](/Users/ren/src/blog/951413iMgBlog/500px-AMD_Zen_2_CCD.jpg)

## Zen1 VS Zen2

Here is what the Naples and Rome packages look like from the outside:

![img](/Users/ren/src/blog/951413iMgBlog/amd-rome-epyc-zen1-zen2.jpg)

numa

![image-20210813091455662](/Users/ren/src/blog/951413iMgBlog/image-20210813091455662.png)

zen1 numa distance:

![img](/Users/ren/src/blog/951413iMgBlog/OctalNUMA_575px.png)

Zen2 numa distance:

```
# numactl -H  //Zen2 hygon 7280  2 socket
available: 2 nodes (0-1)
node 0 cpus: 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 64 65 66 67 68 69 70 71 72 73 74 75 76 77 78 79 80 81 82 83 84 85 86 87 88 89 90 91 92 93 94 95
node 0 size: 257578 MB
node 0 free: 115387 MB
node 1 cpus: 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 96 97 98 99 100 101 102 103 104 105 106 107 108 109 110 111 112 113 114 115 116 117 118 119 120 121 122 123 124 125 126 127
node 1 size: 257005 MB
node 1 free: 221031 MB
node distances:
node   0   1
  0:  10  22
  1:  22  10
  
  #numactl -H //Zen1 hygon 5280  2 socket
available: 4 nodes (0-3)
node 0 cpus: 0 1 2 3 4 5 6 7 32 33 34 35 36 37 38 39
node 0 size: 128854 MB
node 0 free: 89350 MB
node 1 cpus: 8 9 10 11 12 13 14 15 40 41 42 43 44 45 46 47
node 1 size: 129019 MB
node 1 free: 89326 MB
node 2 cpus: 16 17 18 19 20 21 22 23 48 49 50 51 52 53 54 55
node 2 size: 128965 MB
node 2 free: 86542 MB
node 3 cpus: 24 25 26 27 28 29 30 31 56 57 58 59 60 61 62 63
node 3 size: 129020 MB
node 3 free: 98227 MB
node distances:
node   0   1   2   3
  0:  10  16  28  22
  1:  16  10  22  28
  2:  28  22  10  16
  3:  22  28  16  10
```

看完这些结构上的原理，让我们实际来看看AMD的性能怎么样。

## hygon 7280 PCM数据

pcm(performance counter monitor) 工具由芯片公司提供

```shell
[root@hygon3 16:58 /root/PCM]
#./pcm.x -r -topdown -i=1 -nc -ns -l2

 Processor Counter Monitor  (2019-08-21 17:07:31 +0800 ID=378f2fc)

Number of physical cores: 64
Number of logical cores: 128
Number of online logical cores: 128
Threads (logical cores) per physical core: 2
Num sockets: 2
Physical cores per socket: 32
Core PMU (perfmon) version: 3
Number of core PMU generic (programmable) counters: 6
Width of generic (programmable) counters: 64 bits
Ccxs per Node: 8
Logical cores per Ccx: 8
Physical Cores per Ccx: 4
Nodes per socket: 4
Number of core PMU fixed counters: 0
Width of fixed counters: 0 bits
Nominal core frequency: 2000000000 Hz
Package thermal spec power: -1 Watt; Package minimum power: -1 Watt; Package maximum power: -1 Watt;

 Resetting PMU configuration
 Zeroed PMU registers

Detected Hygon C86 7280 32-core Processor  "Hygon(r) microarchitecture codename DHYANA" stepping 1

 EXEC  : instructions per nominal CPU cycle
 IPC   : instructions per CPU cycle
 FREQ  : relation to nominal CPU frequency='unhalted clock ticks'/'invariant timer ticks' (includes Intel Turbo Boost)
 AFREQ : relation to nominal CPU frequency while in active state (not in power-saving C state)='unhalted clock ticks'/'invariant timer ticks while in C0-state'  (includes Intel Turbo Boost)
 L3MISS: L3 (read) cache misses
 L3MPKI: L3 misses per kilo instructions
 L3HIT : L3 (read) cache hit ratio (0.00-1.00)
 L2DMISS:L2 data cache misses
 L2DHIT :L2 data cache hit ratio (0.00-1.00)
 L2DMPKI:number of L2 data cache misses per kilo instruction
 L2IMISS:L2 instruction cache misses
 L2IHIT :L2 instructoon cache hit ratio (0.00-1.00)
 L2IMPKI:number of L2  instruction cache misses per kilo instruction
 L2MPKI :number of both L2 instruction and data cache misses per kilo instruction

 Core (SKT) |  EXEC  |   IPC  |  FREQ  |  AFREQ | L2DMISS| L2DHIT | L2DMPKI| L2IMISS| L2IHIT | L2IMPKI| L2MPKI | L3MISS | L3MPKI |  L3HIT | TEMP

---------------------------------------------------------------------------------------------------------------
 TOTAL  *     1.29     1.20     1.08     1.00     12 M     0.73     0.04     10 M     0.87     0.03     0.07     19 M     0.00     0.55     N/A

 Instructions retired:  336 G ; Active cycles:  281 G ; Time (TSC): 2082 Mticks ; C0 (active,non-halted) core residency: 107.90 %


 PHYSICAL CORE IPC                 : 2.39 => corresponds to 34.14 % utilization for cores in active state
 Instructions per nominal CPU cycle: 2.58 => corresponds to 36.84 % core utilization over time interval
---------------------------------------------------------------------------------------------------------------

Cleaning up
 Zeroed PMU registers
```

在本地启动benchmarksql压力，并将进程绑定到0-8core，然后采集到数据：

```shell
#./pcm.x -r -topdown -i=1 -l2

 Processor Counter Monitor  (2019-08-21 17:07:31 +0800 ID=378f2fc)


Number of physical cores: 64
Number of logical cores: 128
Number of online logical cores: 128
Threads (logical cores) per physical core: 2
Num sockets: 2
Physical cores per socket: 32
Core PMU (perfmon) version: 3
Number of core PMU generic (programmable) counters: 6
Width of generic (programmable) counters: 64 bits
Ccxs per Node: 8
Logical cores per Ccx: 8
Physical Cores per Ccx: 4
Nodes per socket: 4
Number of core PMU fixed counters: 0
Width of fixed counters: 0 bits
Nominal core frequency: 2000000000 Hz
Package thermal spec power: -1 Watt; Package minimum power: -1 Watt; Package maximum power: -1 Watt;

 Resetting PMU configuration
 Zeroed PMU registers

Detected Hygon C86 7280 32-core Processor  "Hygon(r) microarchitecture codename DHYANA" stepping 1

 EXEC  : instructions per nominal CPU cycle
 IPC   : instructions per CPU cycle
 FREQ  : relation to nominal CPU frequency='unhalted clock ticks'/'invariant timer ticks' (includes Intel Turbo Boost)
 AFREQ : relation to nominal CPU frequency while in active state (not in power-saving C state)='unhalted clock ticks'/'invariant timer ticks while in C0-state'  (includes Intel Turbo Boost)
 L3MISS: L3 (read) cache misses
 L3MPKI: L3 misses per kilo instructions
 L3HIT : L3 (read) cache hit ratio (0.00-1.00)
 L2DMISS:L2 data cache misses
 L2DHIT :L2 data cache hit ratio (0.00-1.00)
 L2DMPKI:number of L2 data cache misses per kilo instruction
 L2IMISS:L2 instruction cache misses
 L2IHIT :L2 instructoon cache hit ratio (0.00-1.00)
 L2IMPKI:number of L2  instruction cache misses per kilo instruction
 L2MPKI :number of both L2 instruction and data cache misses per kilo instruction

 Core (SKT) |  EXEC  |   IPC  |  FREQ  |  AFREQ | L2DMISS| L2DHIT | L2DMPKI| L2IMISS| L2IHIT | L2IMPKI| L2MPKI | L3MISS | L3MPKI |  L3HIT | TEMP

   0    0     1.34     1.26     1.06     1.00   8901 K     0.72     3.15     15 M     0.68     5.43     8.58     71 M     4.00     0.60      N/A
   1    0     1.42     1.33     1.06     1.00   8491 K     0.73     2.83     14 M     0.68     4.67     7.50     71 M     4.00     0.60      N/A
   2    0     1.41     1.33     1.06     1.00   8206 K     0.74     2.75     12 M     0.72     4.25     7.00     71 M     4.00     0.60      N/A
   3    0     1.46     1.38     1.06     1.00   7464 K     0.75     2.40     11 M     0.68     3.81     6.21     71 M     4.00     0.60      N/A
   4    0     1.31     1.24     1.06     1.00   9118 K     0.71     3.28     15 M     0.69     5.61     8.88     70 M     4.00     0.61      N/A
   5    0     1.41     1.33     1.06     1.00   8700 K     0.74     2.92     13 M     0.69     4.66     7.57     70 M     4.00     0.61      N/A
   6    0     1.41     1.33     1.06     1.00   8094 K     0.74     2.79     12 M     0.70     4.40     7.18     70 M     4.00     0.61      N/A
   7    0     1.43     1.35     1.06     1.00   7873 K     0.74     2.68     12 M     0.71     4.13     6.81     70 M     4.00     0.61      N/A
   8    0     1.44     1.36     1.06     1.00   8544 K     0.73     2.79     14 M     0.67     4.87     7.66     20 M     1.00     0.61      N/A
   9    0     1.24     1.16     1.06     1.00    524 K     0.51     0.21     86 K     0.94     0.03     0.24     20 M     1.00     0.61      N/A
  10    0     1.26     1.18     1.07     1.00    379 K     0.50     0.15     60 K     0.95     0.02     0.17     20 M     1.00     0.61      N/A
  11    0     1.24     1.16     1.07     1.00    533 K     0.50     0.20     96 K     0.94     0.04     0.24     20 M     1.00     0.61      N/A
  12    0     1.22     1.14     1.07     1.00   1180 K     0.34     0.47     98 K     0.94     0.04     0.51   3872 K     0.12     0.46      N/A
  13    0     1.24     1.16     1.07     1.00    409 K     0.49     0.16     64 K     0.94     0.03     0.19   3872 K     0.12     0.46      N/A
  
  ---------------------------------------------------------------------------------------------------------------
 SKT    0     1.18     1.11     1.06     1.00    113 M     0.67     0.73    139 M     0.71     0.89     1.62    186 M     1.12     0.59      N/A
 SKT    1     1.23     1.14     1.08     1.00     33 M     0.53     0.21     11 M     0.89     0.07     0.28     38 M     0.12     0.45      N/A
---------------------------------------------------------------------------------------------------------------
 TOTAL  *     1.21     1.13     1.07     1.00    147 M     0.65     0.46    150 M     0.74     0.47     0.93    224 M     0.62     0.57     N/A

 Instructions retired:  319 G ; Active cycles:  283 G ; Time (TSC): 2108 Mticks ; C0 (active,non-halted) core residency: 107.12 %


 PHYSICAL CORE IPC                 : 2.25 => corresponds to 32.18 % utilization for cores in active state
 Instructions per nominal CPU cycle: 2.41 => corresponds to 34.48 % core utilization over time interval
---------------------------------------------------------------------------------------------------------------

Cleaning up
 Zeroed PMU registers
```



## 几款CPU性能比较

IPC的说明：

> IPC: insns per cycle  insn/cycles  也就是每个时钟周期能执行的指令数量，越大程序跑的越快
>
> 程序的执行时间 = 指令数/(主频*IPC) //单核下，多核的话再除以核数

Hygon 7280 就是AMD Zen2架构，最大IPC能到5. 

```shell
# lscpu
Architecture:          x86_64
CPU op-mode(s):        32-bit, 64-bit
Byte Order:            Little Endian
CPU(s):                128
On-line CPU(s) list:   0-127
Thread(s) per core:    2
Core(s) per socket:    32
座：                 2
NUMA 节点：         2
厂商 ID：           HygonGenuine
CPU 系列：          24
型号：              1
型号名称：        Hygon C86 7280 32-core Processor
步进：              1
CPU MHz：             1999.715
BogoMIPS：            3999.43
虚拟化：           AMD-V
L1d 缓存：          32K
L1i 缓存：          64K
L2 缓存：           512K
L3 缓存：           8192K
NUMA 节点0 CPU：    0-31,64-95
NUMA 节点1 CPU：    32-63,96-127
```

AMD EPYC 7H12 64-Core（ECS，非物理机），最大IPC能到5. 

```shell
# lscpu
Architecture:          x86_64
CPU op-mode(s):        32-bit, 64-bit
Byte Order:            Little Endian
CPU(s):                64
On-line CPU(s) list:   0-63
Thread(s) per core:    2
Core(s) per socket:    16
座：                 2
NUMA 节点：         2
厂商 ID：           AuthenticAMD
CPU 系列：          23
型号：              49
型号名称：        AMD EPYC 7H12 64-Core Processor
步进：              0
CPU MHz：             2595.124
BogoMIPS：            5190.24
虚拟化：           AMD-V
超管理器厂商：  KVM
虚拟化类型：     完全
L1d 缓存：          32K
L1i 缓存：          32K
L2 缓存：           512K
L3 缓存：           16384K
NUMA 节点0 CPU：    0-31
NUMA 节点1 CPU：    32-63
```

这次对比测试的Intel 8163 CPU信息如下，最大IPC 是4：

```shell
#lscpu
Architecture:          x86_64
CPU op-mode(s):        32-bit, 64-bit
Byte Order:            Little Endian
CPU(s):                96
On-line CPU(s) list:   0-95
Thread(s) per core:    2
Core(s) per socket:    24
Socket(s):             2
NUMA node(s):          1
Vendor ID:             GenuineIntel
CPU family:            6
Model:                 85
Model name:            Intel(R) Xeon(R) Platinum 8163 CPU @ 2.50GHz
Stepping:              4
CPU MHz:               2499.121
CPU max MHz:           3100.0000
CPU min MHz:           1000.0000
BogoMIPS:              4998.90
Virtualization:        VT-x
L1d cache:             32K
L1i cache:             32K
L2 cache:              1024K
L3 cache:              33792K
NUMA node0 CPU(s):     0-95

-----8269CY
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
CPU MHz:               3200.000
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
```

飞腾2500用nop去跑IPC的话，只能到1，但是跑其它代码能到2.33

```
#perf stat ./nop
failed to read counter stalled-cycles-frontend
failed to read counter stalled-cycles-backend
failed to read counter branches

 Performance counter stats for './nop':

      78638.700540      task-clock (msec)         #    0.999 CPUs utilized
              1479      context-switches          #    0.019 K/sec
                55      cpu-migrations            #    0.001 K/sec
                37      page-faults               #    0.000 K/sec
      165127619524      cycles                    #    2.100 GHz
   <not supported>      stalled-cycles-frontend
   <not supported>      stalled-cycles-backend
      165269372437      instructions              #    1.00  insns per cycle
   <not supported>      branches
           3057191      branch-misses             #    0.00% of all branches

      78.692839007 seconds time elapsed
      
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
	Version: S2500
	Voltage: 0.8 V
	External Clock: 50 MHz
	Max Speed: 2100 MHz
	Current Speed: 2100 MHz
	Status: Populated, Enabled
	Upgrade: Other
	L1 Cache Handle: 0x0005
	L2 Cache Handle: 0x0007
	L3 Cache Handle: 0x0008
	Serial Number: N/A
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
```



### 单核以及HT计算Prime性能比较

以上两款CPU但从物理上的指标来看似乎AMD要好很多，从工艺上AMD也要领先一代(2年），从单核参数上来说是2.0 VS 2.5GHz，但是IPC 是5 VS 4，算下来理想的单核性能刚好一致（2*5=2.5 *4）。

从外面的一些跑分结果显示也是AMD 要好，但是实际性能怎么样呢？

测试命令，这个测试命令无论在哪个CPU下，用2个物理核用时都是一个物理核的一半，所以这个计算是可以完全并行的

```
taskset -c 1 /usr/bin/sysbench --num-threads=1 --test=cpu --cpu-max-prime=50000 run //单核用一个threads，绑核; HT用2个threads，绑一对HT
```

测试结果为耗时，单位秒

| 测试项                 | AMD EPYC 7H12 2.5G CentOS 7.9 | Hygon 7280 2.1GHz CentOS | Hygon 7280 2.1GHz 麒麟 | Intel 8269 2.50G | Intel 8163 CPU @ 2.50GHz | Intel E5-2682 v4 @ 2.50GHz |
| :--------------------- | ----------------------------- | ------------------------ | :--------------------- | ---------------- | :----------------------- | :------------------------- |
| 单核  prime 50000 耗时 | 59秒  IPC 0.56                | 77秒 IPC 0.55            | 89秒  IPC 0.56;        | 83 0.41          | 105秒  IPC 0.41          | 109秒  IPC 0.39            |
| HT  prime 50000 耗时   | 57秒  IPC 0.31                | 74秒 IPC 0.29            | 87秒  IPC 0.29         | 48 0.35          | 60秒   IPC 0.36          | 74秒    IPC 0.29           |

相同CPU下的 指令数 基本= 耗时 * IPC * 核数

以上测试结果显示Hygon 7280单核计算能力是要强过Intel 8163的，但是超线程在这个场景下太不给力，相当于没有。

当然上面的计算Prime太单纯了，代表不了复杂的业务场景，所以接下来用MySQL的查询场景来看看。

如果是arm芯片在计算prime上明显要好过x86，猜测是除法取余指令上有优化

```
#taskset -c 11 sysbench cpu --threads=1 --events=50000  run
sysbench 1.0.20 (using bundled LuaJIT 2.1.0-beta2)
```

测试结果为10秒钟的event

| 测试项                  | FT2500 2.1G     | 鲲鹏920-4826 2.6GHz | Intel 8163 CPU @ 2.50GHz | Hygon C86 7280 2.1GHz |
| :---------------------- | --------------- | ------------------- | :----------------------- | --------------------- |
| 单核  prime 10秒 events | 21626  IPC 0.89 | 30299 IPC 1.01      | 8435  IPC 0.41           | 10349  IPC 0.63       |

### 对比MySQL sysbench和tpcc性能

分别将MySQL 5.7.34社区版部署到intel+AliOS以及hygon 7280+CentOS上，将mysqld绑定到单核，一样的压力配置均将CPU跑到100%，然后用sysbench测试点查， HT表示将mysqld绑定到一对HT核。

#### sysbench点查

 测试命令类似如下：

```
sysbench --test='/usr/share/doc/sysbench/tests/db/select.lua' --oltp_tables_count=1 --report-interval=1 --oltp-table-size=10000000  --mysql-port=3307 --mysql-db=sysbench_single --mysql-user=root --mysql-password='Bj6f9g96!@#'  --max-requests=0   --oltp_skip_trx=on --oltp_auto_inc=on  --oltp_range_size=5  --mysql-table-engine=innodb --rand-init=on   --max-time=300 --mysql-host=x86.51 --num-threads=4 run
```

测试结果(测试中的差异AMD、Hygon CPU跑在CentOS7.9， intel CPU、Kunpeng 920 跑在AliOS上, xdb表示用集团的xdb替换社区的MySQL Server， 麒麟是国产OS)：

| 测试核数 | AMD EPYC 7H12 2.5G | Hygon 7280 2.1G | Hygon 7280 2.1GHz 麒麟 | Intel 8269 2.50G  | Intel 8163 2.50G | Intel 8163 2.50G XDB5.7      | 鲲鹏 920-4826 2.6G | 鲲鹏 920-4826 2.6G XDB8.0 | FT2500 alisql 8.0 本地--socket |
| :------- | ------------------ | :-------------- | ---------------------- | ----------------- | :--------------- | :--------------------------- | ------------------ | ------------------------- | ------------------------------ |
| 单核     | 24674  0.54        | 13441  0.46     | 10236  0.39            | 28208 0.75        | 25474   0.84     | 29376    0.89                | 9694  0.49         | 8301  0.46                | 3602 0.53                      |
| 一对HT   | 36157 0.42         | 21747  0.38     | 19417  0.37            | 36754 0.49        | 35894  0.6       | 40601  0.65                  | 无HT               | 无HT                      | 无HT                           |
| 4物理核  | 94132 0.52         | 49822 0.46      | 38033  0.37            | 90434 0.69 350%   | 87254  0.73      | 106472  0.83                 | 34686  0.42        | 28407  0.39               | 14232 0.53                     |
| 16物理核 | 325409 0.48        | 171630 0.38     | 134980  0.34           | 371718 0.69 1500% | 332967  0.72     | 446290  0.85 //16核比4核好！ | 116122  0.35       | 94697  0.33               | 59199  0.6  8core:31210 0.59   |
| 32物理核 | 542192 0.43        | 298716 0.37     | 255586  0.33           | 642548 0.64 2700% | 588318  0.67     | 598637  0.81 CPU 2400%       | 228601  0.36       | 177424  0.32              | 114020 0.65                    |

- [^说明]:麒麟OS下CPU很难跑满，大致能跑到90%-95%左右，麒麟上装的社区版MySQL-5.7.29；飞腾要特别注意mysqld所在socket，同时以上飞腾数据都是走--socket压测锁的，32core走网络压测QPS为：99496（15%的网络损耗）

#### Mysqld 二进制代码所在 page cache带来的性能影响

如果是飞腾跨socket影响很大，mysqld二进制跨socket性能会下降30%以上

对于鲲鹏920，双路服务器上测试，mysqld绑在node0, 但是分别将mysqld二进制load进不同的node上的page cache，然后执行点查

| mysqld | node0           | node1           | node2           | node3           |
| ------ | --------------- | --------------- | --------------- | --------------- |
| QPS    | 190120 IPC 0.40 | 182518 IPC 0.39 | 189046 IPC 0.40 | 186533 IPC 0.40 |

以上数据可以看出这里node0到node1还是很慢的，居然比跨socket还慢，反过来说鲲鹏跨socket性能很好

绑定mysqld到不同node的page cache操作

```
#systemctl stop mysql-server

[root@poc65 /root/vmtouch]
#vmtouch -e /usr/local/mysql/bin/mysqld
           Files: 1
     Directories: 0
   Evicted Pages: 5916 (23M)
         Elapsed: 0.00322 seconds

#vmtouch -v /usr/local/mysql/bin/mysqld
/usr/local/mysql/bin/mysqld
[                                                            ] 0/5916

           Files: 1
     Directories: 0
  Resident Pages: 0/5916  0/23M  0%
         Elapsed: 0.000204 seconds

#taskset -c 24 md5sum /usr/local/mysql/bin/mysqld

#grep mysqld /proc/`pidof mysqld`/numa_maps  //检查mysqld具体绑定在哪个node上
00400000 default file=/usr/local/mysql/bin/mysqld mapped=3392 active=1 N0=3392 kernelpagesize_kB=4
0199b000 default file=/usr/local/mysql/bin/mysqld anon=10 dirty=10 mapped=134 active=10 N0=134 kernelpagesize_kB=4
01a70000 default file=/usr/local/mysql/bin/mysqld anon=43 dirty=43 mapped=120 active=43 N0=120 kernelpagesize_kB=4
```



#### 网卡以及node距离带来的性能差异

在鲲鹏920+mysql5.7+alios，将内存分配锁在node0上，然后分别绑核在1、24、48、72core，进行sysbench点查对比

|      | Core1 | Core24 | Core48 | Core72 |
| ---- | ----- | ------ | ------ | ------ |
| QPS  | 10800 | 10400  | 7700   | 7700   |

以上测试的时候业务进程分配的内存全限制在node0上（下面的网卡中断测试也是同样内存结构）

```
#/root/numa-maps-summary.pl </proc/123853/numa_maps
N0        :      5085548 ( 19.40 GB)
N1        :         4479 (  0.02 GB)
N2        :            1 (  0.00 GB)
active    :            0 (  0.00 GB)
anon      :      5085455 ( 19.40 GB)
dirty     :      5085455 ( 19.40 GB)
kernelpagesize_kB:         2176 (  0.01 GB)
mapmax    :          348 (  0.00 GB)
mapped    :         4626 (  0.02 GB)
```

对比测试，将内存锁在node3上，重复进行以上测试结果如下：

|      | Core1 | Core24 | Core48 | Core72 |
| ---- | ----- | ------ | ------ | ------ |
| QPS  | 10500 | 10000  | 8100   | 8000   |

```
#/root/numa-maps-summary.pl </proc/54478/numa_maps
N0        :           16 (  0.00 GB)
N1        :         4401 (  0.02 GB)
N2        :            1 (  0.00 GB)
N3        :      1779989 (  6.79 GB)
active    :            0 (  0.00 GB)
anon      :      1779912 (  6.79 GB)
dirty     :      1779912 (  6.79 GB)
kernelpagesize_kB:         1108 (  0.00 GB)
mapmax    :          334 (  0.00 GB)
mapped    :         4548 (  0.02 GB)
```

机器上网卡eth1插在node0上，由以上两组对比测试发现网卡影响比内存跨node影响更大，网卡影响有20%。而内存的影响基本看不到（就近好那么一点点，但是不明显，只能解释为cache命中率很高了）

此时软中断都在node0上，如果将软中断绑定到node3上，第72core的QPS能提升到8500，并且非常稳定。同时core0的QPS下降到10000附近。

##### 网卡软中断以及网卡远近的测试结论

测试机器只是用了一块网卡，网卡插在node0上。

一般网卡中断会占用一些CPU，如果把网卡中断挪到其它node的core上，在鲲鹏920上测试，业务跑在node3（使用全部24core），网卡中断分别在node0和node3，QPS分别是：179000 VS 175000 （此时把中断放到node0或者是和node3最近的node2上差别不大）

如果将业务跑在node0上（全部24core），网卡中断分别在node0和node1上得到的QPS分别是：204000 VS 212000 



#### tpcc 1000仓

测试结果(测试中Hygon 7280分别跑在CentOS7.9和麒麟上， 鲲鹏/intel CPU 跑在AliOS、麒麟是国产OS)：

tpcc测试数据，结果为1000仓，tpmC (NewOrders) ，未标注CPU 则为跑满了

| 测试核数 | Intel 8269 2.50G | Intel 8163 2.50G  | Hygon 7280 2.1GHz 麒麟 | Hygon 7280 2.1G CentOS 7.9 | 鲲鹏 920-4826 2.6G | 鲲鹏 920-4826 2.6G XDB8.0 |
| -------- | ---------------- | ----------------- | ---------------------- | -------------------------- | ------------------ | ------------------------- |
| 1物理核  | 12392            | 9902              | 4706                   | 7011                       | 6619               | 4653                      |
| 一对HT   | 17892            | 15324             | 8950                   | 11778                      | 无HT               | 无HT                      |
| 4物理核  | 51525            | 40877             | 19387 380%             | 30046                      | 23959              | 20101                     |
| 8物理核  | 100792           | 81799             | 39664 750%             | 60086                      | 42368              | 40572                     |
| 16物理核 | 160798 抖动      | 140488 CPU抖动    | 75013 1400%            | 106419 1300-1550%          | 70581  1200%       | 79844                     |
| 24物理核 | 188051           | 164757 1600-2100% | 100841 1800-2000%      | 130815 1600-2100%          | 88204  1600%       | 115355                    |
| 32物理核 | 195292           | 185171 2000-2500% | 116071 1900-2400%      | 142746 1800-2400%          | 102089  1900%      | 143567                    |
| 48物理核 | 19969l           | 195730 2100-2600% | 128188  2100-2800%     | 149782 2000-2700%          | 116374  2500%      | 206055  4500%             |

tpcc并发到一定程度后主要是锁导致性能上不去，所以超多核意义不大。

如果在Hygon 7280 2.1GHz 麒麟上起两个MySQLD实例，每个实例各绑定32物理core，性能刚好翻倍：![image-20210823082702539](/Users/ren/src/blog/951413iMgBlog/image-20210823082702539.png)

测试过程CPU均跑满（未跑满的话会标注出来），IPC跑不起来性能就必然低，超线程虽然总性能好了但是会导致IPC降低(参考前面的公式)。可以看到对本来IPC比较低的场景，启用超线程后一般对性能会提升更大一些。

CPU核数增加到32核后，MySQL社区版性能追平xdb， 此时sysbench使用120线程压性能较好（AMD得240线程压）

32核的时候对比下MySQL 社区版在Hygon7280和Intel 8163下的表现：

![image-20210817181752243](/Users/ren/src/blog/951413iMgBlog/image-20210817181752243.png)

### 三款CPU的性能指标

| 测试项                     | AMD EPYC 7H12 2.5G | Hygon 7280 2.1GHz | Intel 8163 CPU @ 2.50GHz |
| :------------------------- | ------------------ | :---------------- | :----------------------- |
| 内存带宽(MiB/s)            | 12190.50           | 6206.06           | 7474.45                  |
| 内存延时(遍历很大一个数组) | 0.334ms            | 0.336ms           | 0.429ms                  |

## 在lmbench上的测试数据

stream主要用于测试带宽，对应的时延是在带宽跑满情况下的带宽。

lat_mem_rd用来测试操作不同数据大小的时延。总的来说带宽看stream、时延看lat_mem_rd

### 飞腾2500

用stream测试带宽和latency，可以看到带宽随着numa距离不断减少、对应的latency不断增加，到最近的numa node有10%的损耗，这个损耗和numactl给出的距离完全一致。跨socket访问内存latency是node内的3倍，带宽是三分之一，但是socket1性能和socket0性能完全一致

```
time for i in $(seq 7 8 128); do echo $i; numactl -C $i -m 0 ./bin/stream -W 5 -N 5 -M 64M; done

#numactl -C 7 -m 0 ./bin/stream  -W 5 -N 5 -M 64M
STREAM copy latency: 2.84 nanoseconds
STREAM copy bandwidth: 5638.21 MB/sec
STREAM scale latency: 2.72 nanoseconds
STREAM scale bandwidth: 5885.97 MB/sec
STREAM add latency: 2.26 nanoseconds
STREAM add bandwidth: 10615.13 MB/sec
STREAM triad latency: 4.53 nanoseconds
STREAM triad bandwidth: 5297.93 MB/sec

#numactl -C 7 -m 1 ./bin/stream  -W 5 -N 5 -M 64M
STREAM copy latency: 3.16 nanoseconds
STREAM copy bandwidth: 5058.71 MB/sec
STREAM scale latency: 3.15 nanoseconds
STREAM scale bandwidth: 5074.78 MB/sec
STREAM add latency: 2.35 nanoseconds
STREAM add bandwidth: 10197.36 MB/sec
STREAM triad latency: 5.12 nanoseconds
STREAM triad bandwidth: 4686.37 MB/sec

#numactl -C 7 -m 2 ./bin/stream  -W 5 -N 5 -M 64M
STREAM copy latency: 3.85 nanoseconds
STREAM copy bandwidth: 4150.98 MB/sec
STREAM scale latency: 3.95 nanoseconds
STREAM scale bandwidth: 4054.30 MB/sec
STREAM add latency: 2.64 nanoseconds
STREAM add bandwidth: 9100.12 MB/sec
STREAM triad latency: 6.39 nanoseconds
STREAM triad bandwidth: 3757.70 MB/sec

#numactl -C 7 -m 3 ./bin/stream  -W 5 -N 5 -M 64M
STREAM copy latency: 3.69 nanoseconds
STREAM copy bandwidth: 4340.24 MB/sec
STREAM scale latency: 3.62 nanoseconds
STREAM scale bandwidth: 4422.18 MB/sec
STREAM add latency: 2.47 nanoseconds
STREAM add bandwidth: 9704.82 MB/sec
STREAM triad latency: 5.74 nanoseconds
STREAM triad bandwidth: 4177.85 MB/sec

[root@101a05001.cloud.a05.am11 /root/lmbench3]
#numactl -C 7 -m 7 ./bin/stream  -W 5 -N 5 -M 64M
STREAM copy latency: 3.95 nanoseconds
STREAM copy bandwidth: 4051.51 MB/sec
STREAM scale latency: 3.94 nanoseconds
STREAM scale bandwidth: 4060.63 MB/sec
STREAM add latency: 2.54 nanoseconds
STREAM add bandwidth: 9434.51 MB/sec
STREAM triad latency: 6.13 nanoseconds
STREAM triad bandwidth: 3913.36 MB/sec

[root@101a05001.cloud.a05.am11 /root/lmbench3]
#numactl -C 7 -m 10 ./bin/stream  -W 5 -N 5 -M 64M
STREAM copy latency: 8.80 nanoseconds
STREAM copy bandwidth: 1817.78 MB/sec
STREAM scale latency: 8.59 nanoseconds
STREAM scale bandwidth: 1861.65 MB/sec
STREAM add latency: 5.55 nanoseconds
STREAM add bandwidth: 4320.68 MB/sec
STREAM triad latency: 13.94 nanoseconds
STREAM triad bandwidth: 1721.76 MB/sec

[root@101a05001.cloud.a05.am11 /root/lmbench3]
#numactl -C 7 -m 11 ./bin/stream  -W 5 -N 5 -M 64M
STREAM copy latency: 9.27 nanoseconds
STREAM copy bandwidth: 1726.52 MB/sec
STREAM scale latency: 9.31 nanoseconds
STREAM scale bandwidth: 1718.10 MB/sec
STREAM add latency: 5.65 nanoseconds
STREAM add bandwidth: 4250.89 MB/sec
STREAM triad latency: 14.09 nanoseconds
STREAM triad bandwidth: 1703.66 MB/sec

[root@101a05001.cloud.a05.am11 /root/lmbench3]
#numactl -C 88 -m 11 ./bin/stream  -W 5 -N 5 -M 64M //在另外一个socket上测试本numa，和node0性能完全一致
STREAM copy latency: 2.93 nanoseconds
STREAM copy bandwidth: 5454.67 MB/sec
STREAM scale latency: 2.96 nanoseconds
STREAM scale bandwidth: 5400.03 MB/sec
STREAM add latency: 2.28 nanoseconds
STREAM add bandwidth: 10543.42 MB/sec
STREAM triad latency: 4.52 nanoseconds
STREAM triad bandwidth: 5308.40 MB/sec

[root@101a05001.cloud.a05.am11 /root/lmbench3]
#numactl -C 7 -m 15 ./bin/stream  -W 5 -N 5 -M 64M
STREAM copy latency: 8.73 nanoseconds
STREAM copy bandwidth: 1831.77 MB/sec
STREAM scale latency: 8.81 nanoseconds
STREAM scale bandwidth: 1815.13 MB/sec
STREAM add latency: 5.63 nanoseconds
STREAM add bandwidth: 4265.21 MB/sec
STREAM triad latency: 13.09 nanoseconds
STREAM triad bandwidth: 1833.68 MB/sec
```

Lat_mem_rd 用cpu7访问node0和node15对比结果，随着数据的加大，延时在加大，64M时能有3倍差距，和上面测试一致

![image-20210924185044090](/Users/ren/src/blog/951413iMgBlog/image-20210924185044090.png)

```
numactl -C 7 -m 0 ./bin/lat_mem_rd -W 5 -N 5 -t 64M  //-C 7 cpu 7, -m 0 node0, -W 热身 -t stride
```

同样的机型，开关numa的测试结果，关numa 时延、带宽都差了几倍

![image-20210924192330025](/Users/ren/src/blog/951413iMgBlog/image-20210924192330025.png)

关闭numa的机器上测试结果随机性很强，这应该是和内存分配在那里有关系，不过如果机器一直保持这个状态反复测试的话，快的core一直快，慢的core一直慢，这是因为物理地址分配有一定的规律，在物理内存没怎么变化的情况下，快的core恰好分到的内存比较近。

同时不同机器状态（内存使用率）测试结果也不一样

### 鲲鹏920

```
[root@ARM 19:15 /root/lmbench3]
#numactl -H
available: 4 nodes (0-3)
node 0 cpus: 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23
node 0 size: 192832 MB
node 0 free: 146830 MB
node 1 cpus: 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47
node 1 size: 193533 MB
node 1 free: 175354 MB
node 2 cpus: 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69 70 71
node 2 size: 193533 MB
node 2 free: 175718 MB
node 3 cpus: 72 73 74 75 76 77 78 79 80 81 82 83 84 85 86 87 88 89 90 91 92 93 94 95
node 3 size: 193532 MB
node 3 free: 183643 MB
node distances:
node   0   1   2   3
  0:  10  12  20  22
  1:  12  10  22  24
  2:  20  22  10  12
  3:  22  24  12  10
  
#for i in $(seq 0 15); do echo core:$i; numactl -N $i -m 7 ./bin/stream  -W 5 -N 5 -M 64M; done
STREAM copy latency: 1.84 nanoseconds
STREAM copy bandwidth: 8700.75 MB/sec
STREAM scale latency: 1.86 nanoseconds
STREAM scale bandwidth: 8623.60 MB/sec
STREAM add latency: 2.18 nanoseconds
STREAM add bandwidth: 10987.04 MB/sec
STREAM triad latency: 3.03 nanoseconds
STREAM triad bandwidth: 7926.87 MB/sec

#numactl -C 7 -m 1 ./bin/stream  -W 5 -N 5 -M 64M
STREAM copy latency: 2.05 nanoseconds
STREAM copy bandwidth: 7802.45 MB/sec
STREAM scale latency: 2.08 nanoseconds
STREAM scale bandwidth: 7681.87 MB/sec
STREAM add latency: 2.19 nanoseconds
STREAM add bandwidth: 10954.76 MB/sec
STREAM triad latency: 3.17 nanoseconds
STREAM triad bandwidth: 7559.86 MB/sec

#numactl -C 7 -m 2 ./bin/stream  -W 5 -N 5 -M 64M
STREAM copy latency: 3.51 nanoseconds
STREAM copy bandwidth: 4556.86 MB/sec
STREAM scale latency: 3.58 nanoseconds
STREAM scale bandwidth: 4463.66 MB/sec
STREAM add latency: 2.71 nanoseconds
STREAM add bandwidth: 8869.79 MB/sec
STREAM triad latency: 5.92 nanoseconds
STREAM triad bandwidth: 4057.12 MB/sec

[root@ARM 19:14 /root/lmbench3]
#numactl -C 7 -m 3 ./bin/stream  -W 5 -N 5 -M 64M
STREAM copy latency: 3.94 nanoseconds
STREAM copy bandwidth: 4064.25 MB/sec
STREAM scale latency: 3.82 nanoseconds
STREAM scale bandwidth: 4188.67 MB/sec
STREAM add latency: 2.86 nanoseconds
STREAM add bandwidth: 8390.70 MB/sec
STREAM triad latency: 4.78 nanoseconds
STREAM triad bandwidth: 5024.25 MB/sec

#numactl -C 24 -m 3 ./bin/stream  -W 5 -N 5 -M 64M
STREAM copy latency: 4.10 nanoseconds
STREAM copy bandwidth: 3904.63 MB/sec
STREAM scale latency: 4.03 nanoseconds
STREAM scale bandwidth: 3969.41 MB/sec
STREAM add latency: 3.07 nanoseconds
STREAM add bandwidth: 7816.08 MB/sec
STREAM triad latency: 5.06 nanoseconds
STREAM triad bandwidth: 4738.66 MB/sec
```

### 海光7280

可以看到跨numa（一个numa也就是一个socket，等同于跨socket）RT从1.5上升到2.5，这个数据比鲲鹏920要好很多

```
[root@hygon3 14:32 /root/lmbench-master]
#lscpu
架构：                           x86_64
CPU 运行模式：                   32-bit, 64-bit
字节序：                         Little Endian
Address sizes:                   43 bits physical, 48 bits virtual
CPU:                             128
在线 CPU 列表：                  0-127
每个核的线程数：                 2
每个座的核数：                   32
座：                             2
NUMA 节点：                      2
厂商 ID：                        HygonGenuine
CPU 系列：                       24
型号：                           1
型号名称：                       Hygon C86 7280 32-core Processor
步进：                           1
CPU MHz：                        2141.204
BogoMIPS：                       3999.35
虚拟化：                         AMD-V
L1d 缓存：                       2 MiB
L1i 缓存：                       4 MiB
L2 缓存：                        32 MiB
L3 缓存：                        128 MiB
NUMA 节点0 CPU：                 0-31,64-95
NUMA 节点1 CPU：                 32-63,96-127

[root@hygon3 14:32 /root/lmbench-master]
#time for i in $(seq 0 4 64); do echo $i; numactl -C $i -m 0 ./bin/stream -W 5 -N 5 -M 64M; done
0
STREAM copy latency: 1.54 nanoseconds
STREAM copy bandwidth: 10395.17 MB/sec
STREAM scale latency: 1.33 nanoseconds
STREAM scale bandwidth: 12042.21 MB/sec
STREAM add latency: 1.50 nanoseconds
STREAM add bandwidth: 15997.89 MB/sec
STREAM triad latency: 1.62 nanoseconds
STREAM triad bandwidth: 14825.14 MB/sec
---中间省略一些相同的数据，0-31core距离都一样
28
STREAM copy latency: 1.52 nanoseconds
STREAM copy bandwidth: 10509.57 MB/sec
STREAM scale latency: 1.28 nanoseconds
STREAM scale bandwidth: 12483.04 MB/sec
STREAM add latency: 1.47 nanoseconds
STREAM add bandwidth: 16346.08 MB/sec
STREAM triad latency: 1.61 nanoseconds
STREAM triad bandwidth: 14906.45 MB/sec
32
STREAM copy latency: 2.52 nanoseconds
STREAM copy bandwidth: 6348.03 MB/sec
STREAM scale latency: 2.55 nanoseconds
STREAM scale bandwidth: 6266.90 MB/sec
STREAM add latency: 1.79 nanoseconds
STREAM add bandwidth: 13443.65 MB/sec
STREAM triad latency: 3.53 nanoseconds
STREAM triad bandwidth: 6799.48 MB/sec
36
STREAM copy latency: 2.48 nanoseconds
STREAM copy bandwidth: 6464.62 MB/sec
STREAM scale latency: 2.54 nanoseconds
STREAM scale bandwidth: 6308.07 MB/sec
STREAM add latency: 1.77 nanoseconds
STREAM add bandwidth: 13552.37 MB/sec
STREAM triad latency: 3.52 nanoseconds
STREAM triad bandwidth: 6817.81 MB/sec
```

### intel 8269CY

```
lscpu
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
CPU MHz:               3200.000
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


[root@numaopen.cloud.et93 /home/ren/lmbench3]
#time for i in $(seq 0 8 51); do echo $i; numactl -C $i -m 0 ./bin/stream -W 5 -N 5 -M 64M; done
0
STREAM copy latency: 1.15 nanoseconds
STREAM copy bandwidth: 13941.80 MB/sec
STREAM scale latency: 1.16 nanoseconds
STREAM scale bandwidth: 13799.89 MB/sec
STREAM add latency: 1.31 nanoseconds
STREAM add bandwidth: 18318.23 MB/sec
STREAM triad latency: 1.56 nanoseconds
STREAM triad bandwidth: 15356.72 MB/sec
16
STREAM copy latency: 1.12 nanoseconds
STREAM copy bandwidth: 14293.68 MB/sec
STREAM scale latency: 1.13 nanoseconds
STREAM scale bandwidth: 14162.47 MB/sec
STREAM add latency: 1.31 nanoseconds
STREAM add bandwidth: 18293.27 MB/sec
STREAM triad latency: 1.53 nanoseconds
STREAM triad bandwidth: 15692.47 MB/sec
32
STREAM copy latency: 1.52 nanoseconds
STREAM copy bandwidth: 10551.71 MB/sec
STREAM scale latency: 1.52 nanoseconds
STREAM scale bandwidth: 10508.33 MB/sec
STREAM add latency: 1.38 nanoseconds
STREAM add bandwidth: 17363.22 MB/sec
STREAM triad latency: 2.00 nanoseconds
STREAM triad bandwidth: 12024.52 MB/sec
40
STREAM copy latency: 1.49 nanoseconds
STREAM copy bandwidth: 10758.50 MB/sec
STREAM scale latency: 1.50 nanoseconds
STREAM scale bandwidth: 10680.17 MB/sec
STREAM add latency: 1.34 nanoseconds
STREAM add bandwidth: 17948.34 MB/sec
STREAM triad latency: 1.98 nanoseconds
STREAM triad bandwidth: 12133.22 MB/sec
48
STREAM copy latency: 1.49 nanoseconds
STREAM copy bandwidth: 10736.56 MB/sec
STREAM scale latency: 1.50 nanoseconds
STREAM scale bandwidth: 10692.93 MB/sec
STREAM add latency: 1.34 nanoseconds
STREAM add bandwidth: 17902.85 MB/sec
STREAM triad latency: 1.96 nanoseconds
STREAM triad bandwidth: 12239.44 MB/sec
```

### 对比数据

总结下四个CPU用stream测试访问内存的RT以及抖动和带宽对比数据

|                          | 最小RT | 最大RT | 最大copy bandwidth | 最小copy bandwidth |
| ------------------------ | ------ | ------ | ------------------ | ------------------ |
| 飞腾2500(16 numa node)   | 2.84   | 10.34  | 5638.21 MB/sec     | 1546.68 MB/sec     |
| 鲲鹏920(4 numa node)     | 1.84   | 3.87   | 8700.75 MB/sec     | 4131.81 MB/sec     |
| 海光7280(2 numa node)    | 1.52   | 2.33   | 10509.57 MB/sec    | 6875.55 MB/sec     |
| Intel8269CY(2 numa node) | 1.12   | 1.52   | 14293.68 MB/sec    | 10551.71 MB/sec    |
| 申威3231(2numa node)     | 7.09   | 8.75   | 2256.59 MB/sec     | 1827.88 MB/sec     |

从以上数据可以看出这4款CPU性能一款比一款好，飞腾2500慢的core上延时快到intel 8269的10倍了，平均延时5倍以上了。延时数据基本和单核上测试sysbench TPS一致。性能差不多就是：常数*主频/RT

用不同的node上的core 跑lat_mem_rd测试访问node0内存的RT，只取最大64M的时延，时延和node距离完全一致

|                           | RT变化                                                       |
| ------------------------- | ------------------------------------------------------------ |
| 飞腾2500(16 numa node)    | core:0	  149.976<br/>core:8	  168.805<br/>core:16	 191.415<br/>core:24	 178.283<br/>core:32	 170.814<br/>core:40	 185.699<br/>core:48	 212.281<br/>core:56	 202.479<br/>core:64	 426.176<br/>core:72	 444.367<br/>core:80	 465.894<br/>core:88	 452.245<br/>core:96	 448.352<br/>core:104   460.603<br/>core:112   485.989<br/>core:120	490.402 |
| 鲲鹏920(4 numa node)      | core:0        117.323<br/>core:24      135.337<br/>core:48      197.782<br/>core:72      219.416 |
| 海光7280(2 numa node)     | core:0        149.065<br/>core:32      270.484               |
| Intel 8269CY(2 numa node) | core:0        69.792<br/>core:26      93.107                 |
| 申威3231(2numa node)      | core:0     215.146<br/>core:32   282.443                     |
|                           |                                                              |

测试命令：

```
for i in $(seq 0 8 127); do echo core:$i; numactl -C $i -m 0 ./bin/lat_mem_rd -W 5 -N 5 -t 64M; done >lat.log 2>&1
```



### 对比结论

- AMD单核跑分数据比较好
- MySQL 查询场景下Intel的性能好很多
- xdb比社区版性能要好
- MySQL8.0比5.7在多核锁竞争场景下性能要好
- 不知道为啥海光改动这么不给力
- intel最好，AMD接近Intel，海光差的比较远但是又比鲲鹏好很多，飞腾最差，尤其是跨socket简直是灾难
- 麒麟OS性能也比CentOS略差一些

整体来说AMD用领先了一代的工艺（7nm VS 14nm)，在MySQL查询场景中终于可以接近Intel了，但是海光、鲲鹏、飞腾还是不给力。

## 参考资料

[CPU的生产和概念](https://www.atatech.org/articles/211563)
[CPU性能和CACHE](https://topic.atatech.org/articles/210128)
[十年后数据库还是不敢拥抱NUMA](https://www.atatech.org/articles/205974)
[一次海光X86物理机资源竞争压测的调优](https://www.atatech.org/articles/205002)
[数据中心CPU探索和分析](https://www.atatech.org/articles/209957)

[lmbench测试要考虑cache等](https://blog.csdn.net/xuanjian_bjtu/article/details/107178226) 

