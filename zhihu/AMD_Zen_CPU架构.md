
# AMD Zen CPU 架构

## 前言

本文先介绍AMD Zen 架构，结合前一篇文章《[CPU的生产和概念](https://www.atatech.org/articles/211563)》一起来看效果会更好，在[CPU的生产和概念](https://www.atatech.org/articles/211563)中主要是以Intel方案来介绍，CPU的生产和概念中的 多核和多个CPU方案2 就是指的AMD Zen2架构。

Zen1 和 Intel 还比较像，只是一个CPU会封装多个小的Die来得到多核能力，导致NUMA node比较多。

AMD 从Zen2开始架构有了比较大的变化，Zen2架构改动比较大，将IO从Core Die中抽离出来，形成一个专门的IO Die，这个IO Die可以用上一代的工艺实现来提升成品率降低成本。剩下的core Die 专注在core和cache的实现上，同时可以通过最新一代的工艺来提升性能。并且在一个CPU上封装一个 IO Die + 8个 core Die这样一块CPU做到像Intel一样就是一个大NUMA，但是成本低了很多，也许在云计算时代这么搞比较合适。当然会被大家笑话为胶水核（用胶水把多个Die拼在一起），性能肯定是不如一个大Die好，但是挡不住便宜啊。这估计就是大家所说的 **AMD YES！**吧

比如Core Die用7nm工艺，IO Die用14nm工艺，一块CPU封装8个Core Die+1个IO Die的话既能得到一个多核的CPU成本有非常低，参考 《CPU的生产和概念》中的良品率和成品部分。

介绍完AMD架构后，会拿海光7280这块CPU（实际是OEM的AMD Zen2 架构）和 Intel的CPU用MySQL 来对比一下实际性能。

网上Intel CPU架构、技术参数等各种资料还是很丰富的，但是AMD EPYC就比较少了，所以先来学习一下EPYC的架构特点。

## AMD EPYC CPU演进路线

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/AMD_Zen_CPU架构/amd-rome-naples-chiplets.jpg)

后面会针对 第二代的 EPYC来做一个对比测试。

![AMD Accelerated Computing FAD 2020](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/AMD_Zen_CPU架构/AMD-Packaging-to-X3D-FAD-2020.jpg)

AMD EPYC CPU Families:

<table>
<colgroup>
<col style="width: 20%" />
<col style="width: 20%" />
<col style="width: 20%" />
<col style="width: 20%" />
<col style="width: 20%" />
</colgroup>
<tr class="header">
<th style="text-align: left;">Family Name</th>
<th style="text-align: left;">AMD EPYC Naples</th>
<th style="text-align: left;">AMD EPYC Rome</th>
<th style="text-align: left;">AMD EPYC Milan</th>
<th style="text-align: left;">AMD EPYC Genoa</th>
</tr>
<tr class="odd">
<td style="text-align: left;">Family Branding</td>
<td style="text-align: left;">EPYC 7001</td>
<td style="text-align: left;">EPYC 7002</td>
<td style="text-align: left;">EPYC 7003</td>
<td style="text-align: left;">EPYC 7004?</td>
</tr>
<tr class="even">
<td style="text-align: left;">Family Launch</td>
<td style="text-align: left;">2017</td>
<td style="text-align: left;">2019</td>
<td style="text-align: left;">2021</td>
<td style="text-align: left;">2022</td>
</tr>
<tr class="odd">
<td style="text-align: left;">CPU Architecture</td>
<td style="text-align: left;">Zen 1</td>
<td style="text-align: left;">Zen 2</td>
<td style="text-align: left;">Zen 3</td>
<td style="text-align: left;">Zen 4</td>
</tr>
<tr class="even">
<td style="text-align: left;">Process Node</td>
<td style="text-align: left;">14nm GloFo</td>
<td style="text-align: left;">7nm TSMC</td>
<td style="text-align: left;">7nm TSMC</td>
<td style="text-align: left;">5nm TSMC</td>
</tr>
<tr class="odd">
<td style="text-align: left;">Platform Name</td>
<td style="text-align: left;">SP3</td>
<td style="text-align: left;">SP3</td>
<td style="text-align: left;">SP3</td>
<td style="text-align: left;">SP5</td>
</tr>
<tr class="even">
<td style="text-align: left;">Socket</td>
<td style="text-align: left;">LGA 4094</td>
<td style="text-align: left;">LGA 4094</td>
<td style="text-align: left;">LGA 4094</td>
<td style="text-align: left;">LGA 6096</td>
</tr>
<tr class="odd">
<td style="text-align: left;">Max Core Count</td>
<td style="text-align: left;">32</td>
<td style="text-align: left;">64</td>
<td style="text-align: left;">64</td>
<td style="text-align: left;">96</td>
</tr>
<tr class="even">
<td style="text-align: left;">Max Thread Count</td>
<td style="text-align: left;">64</td>
<td style="text-align: left;">128</td>
<td style="text-align: left;">128</td>
<td style="text-align: left;">192</td>
</tr>
<tr class="odd">
<td style="text-align: left;">Max L3 Cache</td>
<td style="text-align: left;">64 MB</td>
<td style="text-align: left;">256 MB</td>
<td style="text-align: left;">256 MB</td>
<td style="text-align: left;">384 MB?</td>
</tr>
<tr class="even">
<td style="text-align: left;">Chiplet Design</td>
<td style="text-align: left;">4 CCD’s (2 CCX’s per CCD)，4 Die</td>
<td style="text-align: left;">8 CCD’s (2 CCX’s per CCD) + 1 IOD ，9 Die</td>
<td style="text-align: left;">8 CCD’s (1 CCX per CCD) + 1 IOD</td>
<td style="text-align: left;">12 CCD’s (1 CCX per CCD) + 1 IOD</td>
</tr>
<tr class="odd">
<td style="text-align: left;">Memory Support</td>
<td style="text-align: left;">DDR4-2666</td>
<td style="text-align: left;">DDR4-3200</td>
<td style="text-align: left;">DDR4-3200</td>
<td style="text-align: left;">DDR5-5200</td>
</tr>
<tr class="even">
<td style="text-align: left;">Memory Channels</td>
<td style="text-align: left;">8 Channel</td>
<td style="text-align: left;">8 Channel</td>
<td style="text-align: left;">8 Channel</td>
<td style="text-align: left;">12 Channel</td>
</tr>
<tr class="odd">
<td style="text-align: left;">PCIe Gen Support</td>
<td style="text-align: left;">64 Gen 3</td>
<td style="text-align: left;">128 Gen 4</td>
<td style="text-align: left;">128 Gen 4</td>
<td style="text-align: left;">128 Gen 5</td>
</tr>
<tr class="even">
<td style="text-align: left;">TDP Range</td>
<td style="text-align: left;">200W</td>
<td style="text-align: left;">280W</td>
<td style="text-align: left;">280W</td>
<td style="text-align: left;">320W (cTDP 400W)</td>
</tr>
</table>

## Zen1

hygon 5280封装后类似下图(一块CPU封装了2个Die，还有封装4个Die的，core更多更贵而已)

![image-20210812204437220](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/AMD_Zen_CPU架构/image-20210812204437220.png)

或者4个Die封装在一起

![image-20210813085044786](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/AMD_Zen_CPU架构/image-20210813085044786.png)

### Zen1 Die

下面这块Die集成了两个CCX（每个CCX四个物理core), 同时还有IO接口

![Блоки CCX](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/AMD_Zen_CPU架构/zeppelin_face_down2.png)

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/AMD_Zen_CPU架构/515px-zen-1zep.svg.png)

Quad-Zeppelin Configuration, as found in [EPYC](https://en.wikichip.org/wiki/amd/epyc).

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/AMD_Zen_CPU架构/512px-zen-4zep.svg.png)

### Zen CPU Complex(CCX)

hygon 5280使用这个结构， There are 4 cores per CCX and 2 CCXs per die for 8 cores.

-   44 mm² area
-   L3 8 MiB; 16 mm²
-   1,400,000,000 transistors

![amd zen ccx.png](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/AMD_Zen_CPU架构/450px-amd_zen_ccx.png)

![amd zen ccx 2 (/Users/ren/src/blog/951413iMgBlog/700px-amd_zen_ccx_2_(annotated).png).png](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/AMD_Zen_CPU架构/700px-amd_zen_ccx_2_(annotated).png)

### 封装后的Zen1（4Die）

![image-20210813085044786](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/AMD_Zen_CPU架构/image-20210813085044786.png)

详实数据和结构

![Топология процессора](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/AMD_Zen_CPU架构/AMD-EPYC-Infinity-Fabric-Topology-Mapping.webp)

## [Zen2 Rome](https://en.wikichip.org/wiki/amd/microarchitectures/zen_2)

Zen2开始最大的变化就是将IO从Core Die中抽离出来，形成一个专门的IO Die。hygon 7280封装后类似下图：

<img src="/Users/ren/src/blog/951413iMgBlog/image-20210602165525641.png" alt="AMD Rome package with card" style="zoom:50%;" />

![AMD Rome layout](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/AMD_Zen_CPU架构/AMD_Rome_layout-617x486.jpg)

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/AMD_Zen_CPU架构/amd-rome-feature-chart.jpg)

### Zen2 Core Complex Die

-   TSMC [7-nanometer process](https://en.wikichip.org/wiki/N7)
-   13 metal layers[[1](https://en.wikichip.org/wiki/amd/microarchitectures/zen_2#cite_note-isscc2020j-zen2-1)]
-   3,800,000,000 transistors[[2](https://en.wikichip.org/wiki/amd/microarchitectures/zen_2#cite_note-isscc2020p-chiplet-2)]
-   Die size: 74 mm²
-   CCX size: 31.3 mm²， 4core per CCX // 16M L3 perf CCX
-   2 × 16 MiB L3 cache: 2 × 16.8 mm² (estimated) // 中间蓝色部分是L3 16M，一个Die封装两个CCX的情况下

![AMD Zen 2 CCD.jpg](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/AMD_Zen_CPU架构/500px-AMD_Zen_2_CCD.jpg)

## Zen1 VS Zen2

Here is what the Naples and Rome packages look like from the outside:

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/AMD_Zen_CPU架构/amd-rome-epyc-zen1-zen2.jpg)

numa

![image-20210813091455662](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/AMD_Zen_CPU架构/image-20210813091455662.png)

zen1 numa distance:

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/AMD_Zen_CPU架构/OctalNUMA_575px.png)

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

## Intel和AMD单核以及HT性能比较

IPC的说明：

> IPC: insns per cycle  insn/cycles  也就是每个时钟周期能执行的指令数量，越大程序跑的越快
> 
> 程序的执行时间 = 指令数/(主频*IPC) //单核下，多核的话再除以核数


Hygon 7280 就是AMD Zen2架构，最大IPC能到5.

```
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

```
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

```
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
```

以上两款CPU但从物理上的指标来看似乎AMD要好很多，从工艺上AMD也要领先一代(2年），从单核参数上来说是2.0 VS 2.5GHz，但是IPC 是5 VS 4，算下来理想的单核性能刚好一致（2*5=2.5 *4）。

从外面的一些跑分结果显示也是AMD 要好，但是实际性能怎么样呢？

测试命令，这个测试命令无论在哪个CPU下，用2个物理核用时都是一个物理核的一半，所以这个计算是可以完全并行的

```
taskset -c 1,49 /usr/bin/sysbench --num-threads=2 --test=cpu --cpu-max-prime=50000 run //单核用一个threads，绑核; HT用2个threads，绑一对HT
```

测试结果为耗时，单位秒

<table style="width:100%;">
<colgroup>
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
</colgroup>
<tr class="header">
<th style="text-align: left;">测试项</th>
<th>AMD EPYC 7H12 2.5G CentOS 7.9</th>
<th>Hygon 7280 2.1GHz CentOS</th>
<th style="text-align: left;">Hygon 7280 2.1GHz 麒麟</th>
<th style="text-align: left;">Intel 8163 CPU @ 2.50GHz</th>
<th style="text-align: left;">Intel E5-2682 v4 @ 2.50GHz</th>
</tr>
<tr class="odd">
<td style="text-align: left;">单核 prime 50000 耗时</td>
<td>59秒 IPC 0.56</td>
<td>77秒 IPC 0.55</td>
<td style="text-align: left;">89秒 IPC 0.56;</td>
<td style="text-align: left;">105秒 IPC 0.41</td>
<td style="text-align: left;">109秒 IPC 0.39</td>
</tr>
<tr class="even">
<td style="text-align: left;">HT prime 50000 耗时</td>
<td>57秒 IPC 0.31</td>
<td>74秒 IPC 0.29</td>
<td style="text-align: left;">87秒 IPC 0.29</td>
<td style="text-align: left;">60秒 IPC 0.36</td>
<td style="text-align: left;">74秒 IPC 0.29</td>
</tr>
</table>

相同CPU下的 指令数 基本= 耗时 * IPC * 核数

以上测试结果显示Hygon 7280单核计算能力是要强过Intel 8163的，但是超线程在这个场景下太不给力，相当于没有。

当然上面的计算Prime太单纯了，代表不了复杂的业务场景，所以接下来用MySQL的查询场景来看看。

### 对比MySQL 5.7.34 查询性能

分别将MySQL 5.7.34社区版部署到intel+AliOS以及hygon 7280+CentOS上，将mysqld绑定到单核，一样的压力配置均将CPU跑到100%，然后用sysbench测试点查， HT表示将mysqld绑定到一对HT核。

测试命令类似如下：

```
sysbench --test='/usr/share/doc/sysbench/tests/db/select.lua' --oltp_tables_count=1 --report-interval=1 --oltp-table-size=10000000  --mysql-port=3307 --mysql-db=sysbench_single --mysql-user=root --mysql-password='Bj6f9g96!@#'  --max-requests=0   --oltp_skip_trx=on --oltp_auto_inc=on  --oltp_range_size=5  --mysql-table-engine=innodb --rand-init=on   --max-time=300 --mysql-host=x86.51 --num-threads=4 run
```

测试结果(这个测试有点小差异Hygon CPU跑在CentOS7.9， intel CPU跑在AliOS上, xdb表示用集团的xdb替换社区的MySQL Server)：

<table>
<colgroup>
<col style="width: 20%" />
<col style="width: 20%" />
<col style="width: 20%" />
<col style="width: 20%" />
<col style="width: 20%" />
</colgroup>
<tr class="header">
<th style="text-align: left;">测试核数</th>
<th>AMD EPYC 7H12 2.5G</th>
<th style="text-align: left;">Hygon 7280 2.1GHz CentOS</th>
<th style="text-align: left;">Intel 8163 CPU @ 2.50GHz</th>
<th style="text-align: left;">Intel 8163 CPU @ 2.50GHz+xdb</th>
</tr>
<tr class="odd">
<td style="text-align: left;">单核</td>
<td>QPS: 24674.48 IPC 0.54</td>
<td style="text-align: left;">QPS: 13441.89 IPC 0.46</td>
<td style="text-align: left;">QPS: 25474.07 IPC 0.84</td>
<td style="text-align: left;">QPS: 29376.46 IPC 0.89</td>
</tr>
<tr class="even">
<td style="text-align: left;">一对HT</td>
<td>QPS: 36157.65 IPC 0.42</td>
<td style="text-align: left;">QPS: 21747.82 IPC 0.38</td>
<td style="text-align: left;">QPS: 35894.33 IPC 0.6</td>
<td style="text-align: left;">QPS: 40601.02 IPC 0.65</td>
</tr>
<tr class="odd">
<td style="text-align: left;">4物理核</td>
<td>QPS: 94132.07 IPC 0.52</td>
<td style="text-align: left;">QPS: 49822.16 IPC 0.46</td>
<td style="text-align: left;">QPS: 87254.60 IPC 0.73</td>
<td style="text-align: left;">QPS:106472.38 IPC 0.83</td>
</tr>
<tr class="even">
<td style="text-align: left;">16物理核</td>
<td>QPS: 325409.44 IPC 0.48</td>
<td style="text-align: left;">QPS: 171630.25 IPC 0.38</td>
<td style="text-align: left;">QPS:332967.20 IPC 0.72</td>
<td style="text-align: left;">QPS:446290.52 IPC 0.85 //16核比4核好！</td>
</tr>
<tr class="odd">
<td style="text-align: left;">32物理核</td>
<td>QPS: 542192.97 IPC 0.43</td>
<td style="text-align: left;">QPS: 276682.08 IPC 0.38</td>
<td style="text-align: left;">QPS:588318.23 IPC 0.67</td>
<td style="text-align: left;">QPS:598637.39 IPC 0.81 CPU 2400%</td>
</tr>
</table>

测试过程CPU均跑满（未跑满的话会标注出来），IPC跑不起来性能就必然低，超线程虽然总性能好了但是会导致IPC降低(参考前面的公式)。可以看到对本来IPC比较低的场景，启用超线程后一般对性能会提升更大一些。

CPU核数增加到32核后，MySQL社区版性能追平xdb， 此时sysbench使用120线程压性能较好

32核的时候对比下MySQL 社区版在Hygon7280和Intel 8163下的表现：

![image-20210817181752243](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/AMD_Zen_CPU架构/image-20210817181752243.png)

### 对比结论

-   AMD单核跑分数据比较好
-   MySQL 查询场景下Intel的性能好很多
-   xdb比社区版性能要好
-   xdb比社区版多核性能下要好很多
-   不知道为啥海光改动这么不给力

整体来说AMD用领先了一代的工艺（7nm VS 14nm)，在MySQL场景中终于可以接近Intel了，但是海光还是不给力。

## 参考资料

[CPU的生产和概念](https://www.atatech.org/articles/211563)

[CPU性能和CACHE](https://topic.atatech.org/articles/210128)
[十年后数据库还是不敢拥抱NUMA](https://www.atatech.org/articles/205974)
[一次海光X86物理机资源竞争压测的调优](https://www.atatech.org/articles/205002)

[数据中心CPU探索和分析](https://www.atatech.org/articles/209957)



Reference:

