---
title: AMD Zen CPU 架构
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

# AMD Zen CPU 架构

## 前言

本文先介绍AMD Zen 架构，结合前一篇文章《[CPU的生产和概念](https://www.atatech.org/articles/211563)》一起来看效果会更好，在[CPU的生产和概念](https://www.atatech.org/articles/211563)中主要是以Intel方案来介绍，CPU的生产和概念中的 多核和多个CPU方案2 就是指的AMD Zen2架构。

Zen1 和 Intel 还比较像，只是一个CPU会封装多个小的Die来得到多核能力，导致NUMA node比较多。

AMD 从Zen2开始架构有了比较大的变化，Zen2架构改动比较大，将IO从Core Die中抽离出来，形成一个专门的IO Die，这个IO Die可以用上一代的工艺实现来提升成品率降低成本。剩下的core Die 专注在core和cache的实现上，同时可以通过最新一代的工艺来提升性能。并且在一个CPU上封装一个 IO Die + 8个 core Die这样一块CPU做到像Intel一样就是一个大NUMA，但是成本低了很多，也许在云计算时代这么搞比较合适。当然会被大家笑话为胶水核（用胶水把多个Die拼在一起），性能肯定是不如一个大Die好，但是挡不住便宜啊。这估计就是大家所说的 **AMD YES！**吧

比如Core Die用7nm工艺，IO Die用14nm工艺，一块CPU封装8个Core Die+1个IO Die的话既能得到一个多核的CPU成本有非常低，参考 《CPU的生产和概念》中的良品率和成品部分。

介绍完AMD架构后，会拿海光7280这块CPU（实际是OEM的AMD Zen2 架构）和 Intel的CPU用MySQL 来对比一下实际性能。

网上Intel CPU架构、技术参数等各种资料还是很丰富的，但是AMD EPYC就比较少了，所以先来学习一下EPYC的架构特点。



## AMD EPYC CPU演进路线

![img](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/amd-rome-naples-chiplets.jpg)

后面会针对 第二代的 EPYC来做一个对比测试。

![AMD Accelerated Computing FAD 2020](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/AMD-Packaging-to-X3D-FAD-2020.jpg)

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

![image-20210812204437220](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20210812204437220.png)

或者4个Die封装在一起

![image-20210813085044786](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20210813085044786.png)

### Zen1 Die

下面这块Die集成了两个CCX（每个CCX四个物理core), 同时还有IO接口

![Блоки CCX](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/zeppelin_face_down2.png)

![img](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/515px-zen-1zep.svg.png)

Quad-Zeppelin Configuration, as found in [EPYC](https://en.wikichip.org/wiki/amd/epyc). 

![img](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/512px-zen-4zep.svg.png)

### Zen CPU Complex(CCX)

hygon 5280使用这个结构， There are 4 cores per CCX and 2 CCXs per die for 8 cores.

- 44 mm² area
- L3 8 MiB; 16 mm²
- 1,400,000,000 transistors

![amd zen ccx.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/450px-amd_zen_ccx.png)

![amd zen ccx 2 (https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/700px-amd_zen_ccx_2_(annotated).png).png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/700px-amd_zen_ccx_2_(annotated).png)

### 封装后的Zen1（4Die）

![image-20210813085044786](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20210813085044786.png)

详实数据和结构

![Топология процессора](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/AMD-EPYC-Infinity-Fabric-Topology-Mapping.webp)

## [Zen2 Rome](https://en.wikichip.org/wiki/amd/microarchitectures/zen_2)

Zen2开始最大的变化就是将IO从Core Die中抽离出来，形成一个专门的IO Die。hygon 7280封装后类似下图：

<img src="https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20210602165525641.png" alt="AMD Rome package with card" style="zoom:50%;" />

![AMD Rome layout](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/AMD_Rome_layout-617x486.jpg)

![img](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/amd-rome-feature-chart.jpg)

### Zen2 Core Complex Die 

- TSMC [7-nanometer process](https://en.wikichip.org/wiki/N7)
- 13 metal layers[[1](https://en.wikichip.org/wiki/amd/microarchitectures/zen_2#cite_note-isscc2020j-zen2-1)]
- 3,800,000,000 transistors[[2](https://en.wikichip.org/wiki/amd/microarchitectures/zen_2#cite_note-isscc2020p-chiplet-2)]
- Die size: 74 mm²
- CCX size: 31.3 mm²， 4core per CCX // 16M L3 perf CCX
- 2 × 16 MiB L3 cache: 2 × 16.8 mm² (estimated) // 中间蓝色部分是L3 16M，一个Die封装两个CCX的情况下

![AMD Zen 2 CCD.jpg](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/500px-AMD_Zen_2_CCD.jpg)

## Zen1 VS Zen2

Here is what the Naples and Rome packages look like from the outside:

![img](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/amd-rome-epyc-zen1-zen2.jpg)

numa

![image-20210813091455662](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20210813091455662.png)

zen1 numa distance:

![img](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/OctalNUMA_575px.png)

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

### 对比MySQL sysbench和tpcc性能

分别将MySQL 5.7.34社区版部署到intel+AliOS以及hygon 7280+CentOS上，将mysqld绑定到单核，一样的压力配置均将CPU跑到100%，然后用sysbench测试点查， HT表示将mysqld绑定到一对HT核。

#### sysbench点查

 测试命令类似如下：

```
sysbench --test='/usr/share/doc/sysbench/tests/db/select.lua' --oltp_tables_count=1 --report-interval=1 --oltp-table-size=10000000  --mysql-port=3307 --mysql-db=sysbench_single --mysql-user=root --mysql-password='Bj6f9g96!@#'  --max-requests=0   --oltp_skip_trx=on --oltp_auto_inc=on  --oltp_range_size=5  --mysql-table-engine=innodb --rand-init=on   --max-time=300 --mysql-host=x86.51 --num-threads=4 run
```

测试结果(测试中的差异AMD、Hygon CPU跑在CentOS7.9， intel CPU、Kunpeng 920 跑在AliOS上, xdb表示用集团的xdb替换社区的MySQL Server， 麒麟是国产OS)：

| 测试核数 | AMD EPYC 7H12 2.5G | Hygon 7280 2.1G | Hygon 7280 2.1GHz 麒麟 | Intel 8269 2.50G  | Intel 8163 2.50G | Intel 8163 2.50G XDB5.7      | 鲲鹏 920-4826 2.6G | 鲲鹏 920-4826 2.6G XDB8.0 |
| :------- | ------------------ | :-------------- | ---------------------- | ----------------- | :--------------- | :--------------------------- | ------------------ | ------------------------- |
| 单核     | 24674  0.54        | 13441  0.46     | 10236  0.39            | 28208 0.75        | 25474   0.84     | 29376    0.89                | 9694  0.49         | 8301  0.46                |
| 一对HT   | 36157 0.42         | 21747  0.38     | 19417  0.37            | 36754 0.49        | 35894  0.6       | 40601  0.65                  | 无HT               | 无HT                      |
| 4物理核  | 94132 0.52         | 49822 0.46      | 38033  0.37            | 90434 0.69 350%   | 87254  0.73      | 106472  0.83                 | 34686  0.42        | 28407  0.39               |
| 16物理核 | 325409 0.48        | 171630 0.38     | 134980  0.34           | 371718 0.69 1500% | 332967  0.72     | 446290  0.85 //16核比4核好！ | 116122  0.35       | 94697  0.33               |
| 32物理核 | 542192 0.43        | 298716 0.37     | 255586  0.33           | 642548 0.64 2700% | 588318  0.67     | 598637  0.81 CPU 2400%       | 228601  0.36       | 177424  0.32              |

[^说明]:麒麟OS下CPU很难跑满，大致能跑到90%-95%左右，麒麟上装的社区版MySQL-5.7.29

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

如果在Hygon 7280 2.1GHz 麒麟上起两个MySQLD实例，每个实例各绑定32物理core，性能刚好翻倍：![image-20210823082702539](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20210823082702539.png)

测试过程CPU均跑满（未跑满的话会标注出来），IPC跑不起来性能就必然低，超线程虽然总性能好了但是会导致IPC降低(参考前面的公式)。可以看到对本来IPC比较低的场景，启用超线程后一般对性能会提升更大一些。

CPU核数增加到32核后，MySQL社区版性能追平xdb， 此时sysbench使用120线程压性能较好（AMD得240线程压）

32核的时候对比下MySQL 社区版在Hygon7280和Intel 8163下的表现：

![image-20210817181752243](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20210817181752243.png)

### 三款CPU的性能指标

| 测试项                     | AMD EPYC 7H12 2.5G | Hygon 7280 2.1GHz | Intel 8163 CPU @ 2.50GHz |
| :------------------------- | ------------------ | :---------------- | :----------------------- |
| 内存带宽(MiB/s)            | 12190.50           | 6206.06           | 7474.45                  |
| 内存延时(遍历很大一个数组) | 0.334ms            | 0.336ms           | 0.429ms                  |



### 对比结论

- AMD单核跑分数据比较好
- MySQL 查询场景下Intel的性能好很多
- xdb比社区版性能要好
- MySQL8.0比5.7在多核锁竞争场景下性能要好
- 不知道为啥海光改动这么不给力
- intel最好，AMD接近Intel，海光差的比较远但是又比鲲鹏好很多
- 麒麟OS性能也比CentOS略差一些

==整体来说AMD用领先了一代的工艺（7nm VS 14nm)，在MySQL查询场景中终于可以接近Intel了，但是海光、鲲鹏还是不给力。==

## 参考资料

[CPU的生产和概念](https://www.atatech.org/articles/211563)
[CPU性能和CACHE](https://topic.atatech.org/articles/210128)
[十年后数据库还是不敢拥抱NUMA](https://www.atatech.org/articles/205974)
[一次海光X86物理机资源竞争压测的调优](https://www.atatech.org/articles/205002)
[数据中心CPU探索和分析](https://www.atatech.org/articles/209957)

