---
title: 几款不同的CPU一些数据--备查
date: 2023-12-23 17:30:03
categories:
    - CPU
tags:
    - 海光
    - 超线程
    - AMD
    - Zen
    - hygon
---

# 几款不同的CPU一些数据--备查

## 背景

方便大家对不同的CPU混个脸熟，有个整体概念。本来发布在知识星球，但是知识星球上格式看起来太影响阅读效率了，所以特意拿出来发到博客上



简单查看CPU我一般用 lscpu(默认自带) 命令，或者用复杂点的工具：hwloc 工具安装：

```
yum install hwloc -y
```

安装后生成结构图片命令：

```
lstopo --logical --output-format png > kunpeng_920.png
```

生成字符结构，不要图片：

```
lstopo-no-graphics
```

后面展示的都算是整体机构，所以还会附带有内存怎么接(一个多少条，每条多大，一个Numa node插了几个物理内存条)，这些我博客上都有，就不展开了。一般都是对称的(每个node、socket对称，不对称肯定发挥不出来好性能)



## intel E5 2682

大概是Intel 2012年的主流服务器CPU

```
#lscpu
Architecture:          x86_64
CPU op-mode(s):        32-bit, 64-bit
Byte Order:            Little Endian
CPU(s):                64 //整机总共64核，实际是由32个物理核通过超线程得来
On-line CPU(s) list:   0-63
Thread(s) per core:    2 //一个物理核2个超线程
Core(s) per socket:    16 //每块CPU有16个物理核
Socket(s):             2 //两路，两块物理上能买到的CPU
NUMA node(s):          2
Vendor ID:             GenuineIntel
CPU family:            6
Model:                 79
Model name:            Intel(R) Xeon(R) CPU E5-2682 v4 @ 2.50GHz
Stepping:              1
CPU MHz:               2499.902
CPU max MHz:           3000.0000
CPU min MHz:           1200.0000
BogoMIPS:              4999.76
Virtualization:        VT-x
L1d cache:             32K //L1 data
L1i cache:             32K
L2 cache:              256K
L3 cache:              40960K //40M L3,也有人叫 LLC(last level cache), L3是一个socket下所有核共享
NUMA node0 CPU(s):     0-15,32-47  //node0
NUMA node1 CPU(s):     16-31,48-63 //node1

//进一步详细看看CPU的结构
#lstopo-no-graphics 
Machine (512GB) //机器总共512G内存
  NUMANode L#0 (P#0 256GB) //两路，共两个Numa Node，第一个Node 256G内存
    Socket L#0 + L3 L#0 (40MB) //Node 0的 L3 40MB，32个逻辑核共享
      //第一个物理核，每一个物理核都有自己的L2(256KB)和 L1(32KB+32KB), L1分数据、指令两部分
      L2 L#0 (256KB) + L1d L#0 (32KB) + L1i L#0 (32KB) + Core L#0 
        PU L#0 (P#0)  //第一个逻辑核
        PU L#1 (P#32) //第二个逻辑核，这两逻辑核实际是同一个物理核，第二个逻辑核编号是32

      //以下是第二个物理核，都是一样的结构……
      L2 L#1 (256KB) + L1d L#1 (32KB) + L1i L#1 (32KB) + Core L#1
        PU L#2 (P#1)
        PU L#3 (P#33)
      L2 L#2 (256KB) + L1d L#2 (32KB) + L1i L#2 (32KB) + Core L#2
        PU L#4 (P#2)
        PU L#5 (P#34)
      L2 L#3 (256KB) + L1d L#3 (32KB) + L1i L#3 (32KB) + Core L#3
        PU L#6 (P#3)
        PU L#7 (P#35)
      L2 L#4 (256KB) + L1d L#4 (32KB) + L1i L#4 (32KB) + Core L#4
        PU L#8 (P#4)
        PU L#9 (P#36)
      L2 L#5 (256KB) + L1d L#5 (32KB) + L1i L#5 (32KB) + Core L#5
        PU L#10 (P#5)
        PU L#11 (P#37)
      L2 L#6 (256KB) + L1d L#6 (32KB) + L1i L#6 (32KB) + Core L#6
        PU L#12 (P#6)
        PU L#13 (P#38)
      L2 L#7 (256KB) + L1d L#7 (32KB) + L1i L#7 (32KB) + Core L#7
        PU L#14 (P#7)
        PU L#15 (P#39)
      L2 L#8 (256KB) + L1d L#8 (32KB) + L1i L#8 (32KB) + Core L#8
        PU L#16 (P#8)
        PU L#17 (P#40)
      L2 L#9 (256KB) + L1d L#9 (32KB) + L1i L#9 (32KB) + Core L#9
        PU L#18 (P#9)
        PU L#19 (P#41)
      L2 L#10 (256KB) + L1d L#10 (32KB) + L1i L#10 (32KB) + Core L#10
        PU L#20 (P#10)
        PU L#21 (P#42)
      L2 L#11 (256KB) + L1d L#11 (32KB) + L1i L#11 (32KB) + Core L#11
        PU L#22 (P#11)
        PU L#23 (P#43)
      L2 L#12 (256KB) + L1d L#12 (32KB) + L1i L#12 (32KB) + Core L#12
        PU L#24 (P#12)
        PU L#25 (P#44)
      L2 L#13 (256KB) + L1d L#13 (32KB) + L1i L#13 (32KB) + Core L#13
        PU L#26 (P#13)
        PU L#27 (P#45)
      L2 L#14 (256KB) + L1d L#14 (32KB) + L1i L#14 (32KB) + Core L#14
        PU L#28 (P#14)
        PU L#29 (P#46)
      L2 L#15 (256KB) + L1d L#15 (32KB) + L1i L#15 (32KB) + Core L#15
        PU L#30 (P#15)
        PU L#31 (P#47)
    HostBridge L#0
      PCIBridge
        PCI 144d:a804
      PCIBridge
        PCI 8086:10fb
          Net L#0 "eth2" //两块PCI 万兆网卡插在Socket0上，所有Socket0上的core访问网络效率更高
        PCI 8086:10fb
          Net L#1 "eth3"
      PCIBridge
        PCIBridge
          PCI 1a03:2000
            GPU L#2 "card0"
            GPU L#3 "controlD64"
      PCI 8086:8d02
        Block L#4 "sda" //sda硬盘
  NUMANode L#1 (P#1 256GB) //第二路，也就是第二个Node，内存、cache、核都是对称的
    Socket L#1 + L3 L#1 (40MB)
      L2 L#16 (256KB) + L1d L#16 (32KB) + L1i L#16 (32KB) + Core L#16
        PU L#32 (P#16)
        PU L#33 (P#48)
      L2 L#17 (256KB) + L1d L#17 (32KB) + L1i L#17 (32KB) + Core L#17
        PU L#34 (P#17)
        PU L#35 (P#49)
      L2 L#18 (256KB) + L1d L#18 (32KB) + L1i L#18 (32KB) + Core L#18
        PU L#36 (P#18)
        PU L#37 (P#50)
      L2 L#19 (256KB) + L1d L#19 (32KB) + L1i L#19 (32KB) + Core L#19
        PU L#38 (P#19)
        PU L#39 (P#51)
      L2 L#20 (256KB) + L1d L#20 (32KB) + L1i L#20 (32KB) + Core L#20
        PU L#40 (P#20)
        PU L#41 (P#52)
      L2 L#21 (256KB) + L1d L#21 (32KB) + L1i L#21 (32KB) + Core L#21
        PU L#42 (P#21)
        PU L#43 (P#53)
      L2 L#22 (256KB) + L1d L#22 (32KB) + L1i L#22 (32KB) + Core L#22
        PU L#44 (P#22)
        PU L#45 (P#54)
      L2 L#23 (256KB) + L1d L#23 (32KB) + L1i L#23 (32KB) + Core L#23
        PU L#46 (P#23)
        PU L#47 (P#55)
      L2 L#24 (256KB) + L1d L#24 (32KB) + L1i L#24 (32KB) + Core L#24
        PU L#48 (P#24)
        PU L#49 (P#56)
      L2 L#25 (256KB) + L1d L#25 (32KB) + L1i L#25 (32KB) + Core L#25
        PU L#50 (P#25)
        PU L#51 (P#57)
      L2 L#26 (256KB) + L1d L#26 (32KB) + L1i L#26 (32KB) + Core L#26
        PU L#52 (P#26)
        PU L#53 (P#58)
      L2 L#27 (256KB) + L1d L#27 (32KB) + L1i L#27 (32KB) + Core L#27
        PU L#54 (P#27)
        PU L#55 (P#59)
      L2 L#28 (256KB) + L1d L#28 (32KB) + L1i L#28 (32KB) + Core L#28
        PU L#56 (P#28)
        PU L#57 (P#60)
      L2 L#29 (256KB) + L1d L#29 (32KB) + L1i L#29 (32KB) + Core L#29
        PU L#58 (P#29)
        PU L#59 (P#61)
      L2 L#30 (256KB) + L1d L#30 (32KB) + L1i L#30 (32KB) + Core L#30
        PU L#60 (P#30)
        PU L#61 (P#62)
      L2 L#31 (256KB) + L1d L#31 (32KB) + L1i L#31 (32KB) + Core L#31
        PU L#62 (P#31)
        PU L#63 (P#63)
    HostBridge L#5
      PCIBridge
        PCI 8086:1521
          Net L#5 "enp130s0f0" //两块PCI 千兆网卡
        PCI 8086:1521
          Net L#6 "enp130s0f1"
      PCIBridge
        PCI 144d:a804
      PCIBridge
        PCI 144d:a804
```



intel 还有一个自带的工具：cpuid-topo 可以看结构，以下是其中一个Socket的展示

![img](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/FnS99B0Zq6MFk3q3iXvU2O2tY4pp.png)

## 海光

购买的AMD版权设计等搞出来国产的 x86 架构

```
#lscpu
Architecture:        x86_64
CPU op-mode(s):      32-bit, 64-bit
Byte Order:          Little Endian
Address sizes:       43 bits physical, 48 bits virtual
CPU(s):              48
On-line CPU(s) list: 0-47
Thread(s) per core:  1 //我故意把超线程关掉了
Core(s) per socket:  24
Socket(s):           2
NUMA node(s):        8
Vendor ID:           HygonGenuine
CPU family:          24
Model:               1
Model name:          Hygon C86 7260 24-core Processor
Stepping:            1
Frequency boost:     enabled
CPU MHz:             1070.950
CPU max MHz:         2200.0000
CPU min MHz:         1200.0000
BogoMIPS:            4399.54
Virtualization:      AMD-V
L1d cache:           1.5 MiB //好大，不符合逻辑，后面解释
L1i cache:           3 MiB
L2 cache:            24 MiB  //48个物理核总共24MB L2，但是每个物理核只能用自己的512KB
L3 cache:            128 MiB // 
NUMA node0 CPU(s):   0-5
NUMA node1 CPU(s):   6-11
NUMA node2 CPU(s):   12-17
NUMA node3 CPU(s):   18-23
NUMA node4 CPU(s):   24-29
NUMA node5 CPU(s):   30-35
NUMA node6 CPU(s):   36-41
NUMA node7 CPU(s):   42-47 //搞了8个Numa Node
```



L1、L2太大了，好吓人，这么大不符合逻辑(太贵，没必要)

```
//继续看看L2 为啥这么大
#cd /sys/devices/system/cpu/cpu0

#ls cache/index2/
coherency_line_size      number_of_sets           shared_cpu_list          type
id                       physical_line_partition  shared_cpu_map           uevent
level                    power/                   size                     ways_of_associativity

#cat cache/index2/size
512K  //实际是512K， 2M是4个核共享，搞了个花活，但每个核只能用自己的512K

#cat cache/index2/shared_cpu_list
0  //确认 L2只有自己用

#cat cache/index3/shared_cpu_list
0-2 //L3 给0-2这3个物理核共享，一个Die下有6个物理核，每三个共享一个8M的L3

#cat cache/index3/size
8192K //3个物理核共享8M L3

#cat cache/index1/size
64K

#cat cache/index0/size
32K
```

index0/index1 分别代表啥？



海光为啥搞了8个Node，请看：https://plantegg.github.io/2021/03/08/%E6%B5%B7%E5%85%89CPU/

图片可以看高清大图

![img](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/Fnv-AneATqzhd3NYlhXEupxJafLF.png)

对应的字符结构

```
#lstopo
Machine (504GB total)
  Package L#0
    NUMANode L#0 (P#0 63GB)
      L3 L#0 (8192KB)
        L2 L#0 (512KB) + L1d L#0 (32KB) + L1i L#0 (64KB) + Core L#0 + PU L#0 (P#0)
        L2 L#1 (512KB) + L1d L#1 (32KB) + L1i L#1 (64KB) + Core L#1 + PU L#1 (P#1)
        L2 L#2 (512KB) + L1d L#2 (32KB) + L1i L#2 (64KB) + Core L#2 + PU L#2 (P#2)
      L3 L#1 (8192KB)
        L2 L#3 (512KB) + L1d L#3 (32KB) + L1i L#3 (64KB) + Core L#3 + PU L#3 (P#3)
        L2 L#4 (512KB) + L1d L#4 (32KB) + L1i L#4 (64KB) + Core L#4 + PU L#4 (P#4)
        L2 L#5 (512KB) + L1d L#5 (32KB) + L1i L#5 (64KB) + Core L#5 + PU L#5 (P#5)
      HostBridge L#0
        PCIBridge
          PCIBridge
            PCI 1a03:2000
              GPU L#0 "controlD64"
              GPU L#1 "card0"
        PCIBridge
          PCI 1d94:7901
            Block(Disk) L#2 "sda"
    NUMANode L#1 (P#1 63GB)
      L3 L#2 (8192KB)
        L2 L#6 (512KB) + L1d L#6 (32KB) + L1i L#6 (64KB) + Core L#6 + PU L#6 (P#6)
        L2 L#7 (512KB) + L1d L#7 (32KB) + L1i L#7 (64KB) + Core L#7 + PU L#7 (P#7)
        L2 L#8 (512KB) + L1d L#8 (32KB) + L1i L#8 (64KB) + Core L#8 + PU L#8 (P#8)
      L3 L#3 (8192KB)
        L2 L#9 (512KB) + L1d L#9 (32KB) + L1i L#9 (64KB) + Core L#9 + PU L#9 (P#9)
        L2 L#10 (512KB) + L1d L#10 (32KB) + L1i L#10 (64KB) + Core L#10 + PU L#10 (P#10)
        L2 L#11 (512KB) + L1d L#11 (32KB) + L1i L#11 (64KB) + Core L#11 + PU L#11 (P#11)
      HostBridge L#4
        PCIBridge
          PCI 1c5f:0557
            Block(Disk) L#3 "nvme0n1"
        PCIBridge
          PCI 1c5f:0557
            Block(Disk) L#4 "nvme1n1"
    NUMANode L#2 (P#2 63GB)
      L3 L#4 (8192KB)
        L2 L#12 (512KB) + L1d L#12 (32KB) + L1i L#12 (64KB) + Core L#12 + PU L#12 (P#12)
        L2 L#13 (512KB) + L1d L#13 (32KB) + L1i L#13 (64KB) + Core L#13 + PU L#13 (P#13)
        L2 L#14 (512KB) + L1d L#14 (32KB) + L1i L#14 (64KB) + Core L#14 + PU L#14 (P#14)
      L3 L#5 (8192KB)
        L2 L#15 (512KB) + L1d L#15 (32KB) + L1i L#15 (64KB) + Core L#15 + PU L#15 (P#15)
        L2 L#16 (512KB) + L1d L#16 (32KB) + L1i L#16 (64KB) + Core L#16 + PU L#16 (P#16)
        L2 L#17 (512KB) + L1d L#17 (32KB) + L1i L#17 (64KB) + Core L#17 + PU L#17 (P#17)
      HostBridge L#7
        PCIBridge
          PCI 15b3:1015
            Net L#5 "enp33s0f0"
            OpenFabrics L#6 "mlx5_0"
          PCI 15b3:1015
            Net L#7 "enp33s0f1"
            OpenFabrics L#8 "mlx5_1"
    NUMANode L#3 (P#3 63GB)
      L3 L#6 (8192KB)
        L2 L#18 (512KB) + L1d L#18 (32KB) + L1i L#18 (64KB) + Core L#18 + PU L#18 (P#18)
        L2 L#19 (512KB) + L1d L#19 (32KB) + L1i L#19 (64KB) + Core L#19 + PU L#19 (P#19)
        L2 L#20 (512KB) + L1d L#20 (32KB) + L1i L#20 (64KB) + Core L#20 + PU L#20 (P#20)
      L3 L#7 (8192KB)
        L2 L#21 (512KB) + L1d L#21 (32KB) + L1i L#21 (64KB) + Core L#21 + PU L#21 (P#21)
        L2 L#22 (512KB) + L1d L#22 (32KB) + L1i L#22 (64KB) + Core L#22 + PU L#22 (P#22)
        L2 L#23 (512KB) + L1d L#23 (32KB) + L1i L#23 (64KB) + Core L#23 + PU L#23 (P#23)
      HostBridge L#9
        PCIBridge
          PCI 8086:1521
            Net L#9 "eno1"
          PCI 8086:1521
            Net L#10 "eno2"
  Package L#1
    NUMANode L#4 (P#4 63GB)
      L3 L#8 (8192KB)
        L2 L#24 (512KB) + L1d L#24 (32KB) + L1i L#24 (64KB) + Core L#24 + PU L#24 (P#24)
        L2 L#25 (512KB) + L1d L#25 (32KB) + L1i L#25 (64KB) + Core L#25 + PU L#25 (P#25)
        L2 L#26 (512KB) + L1d L#26 (32KB) + L1i L#26 (64KB) + Core L#26 + PU L#26 (P#26)
      L3 L#9 (8192KB)
        L2 L#27 (512KB) + L1d L#27 (32KB) + L1i L#27 (64KB) + Core L#27 + PU L#27 (P#27)
        L2 L#28 (512KB) + L1d L#28 (32KB) + L1i L#28 (64KB) + Core L#28 + PU L#28 (P#28)
        L2 L#29 (512KB) + L1d L#29 (32KB) + L1i L#29 (64KB) + Core L#29 + PU L#29 (P#29)
    NUMANode L#5 (P#5 63GB)
      L3 L#10 (8192KB)
        L2 L#30 (512KB) + L1d L#30 (32KB) + L1i L#30 (64KB) + Core L#30 + PU L#30 (P#30)
        L2 L#31 (512KB) + L1d L#31 (32KB) + L1i L#31 (64KB) + Core L#31 + PU L#31 (P#31)
        L2 L#32 (512KB) + L1d L#32 (32KB) + L1i L#32 (64KB) + Core L#32 + PU L#32 (P#32)
      L3 L#11 (8192KB)
        L2 L#33 (512KB) + L1d L#33 (32KB) + L1i L#33 (64KB) + Core L#33 + PU L#33 (P#33)
        L2 L#34 (512KB) + L1d L#34 (32KB) + L1i L#34 (64KB) + Core L#34 + PU L#34 (P#34)
        L2 L#35 (512KB) + L1d L#35 (32KB) + L1i L#35 (64KB) + Core L#35 + PU L#35 (P#35)
      HostBridge L#11
        PCIBridge
          PCI 1d94:7901
    NUMANode L#6 (P#6 63GB)
      L3 L#12 (8192KB)
        L2 L#36 (512KB) + L1d L#36 (32KB) + L1i L#36 (64KB) + Core L#36 + PU L#36 (P#36)
        L2 L#37 (512KB) + L1d L#37 (32KB) + L1i L#37 (64KB) + Core L#37 + PU L#37 (P#37)
        L2 L#38 (512KB) + L1d L#38 (32KB) + L1i L#38 (64KB) + Core L#38 + PU L#38 (P#38)
      L3 L#13 (8192KB)
        L2 L#39 (512KB) + L1d L#39 (32KB) + L1i L#39 (64KB) + Core L#39 + PU L#39 (P#39)
        L2 L#40 (512KB) + L1d L#40 (32KB) + L1i L#40 (64KB) + Core L#40 + PU L#40 (P#40)
        L2 L#41 (512KB) + L1d L#41 (32KB) + L1i L#41 (64KB) + Core L#41 + PU L#41 (P#41)
    NUMANode L#7 (P#7 63GB)
      L3 L#14 (8192KB)
        L2 L#42 (512KB) + L1d L#42 (32KB) + L1i L#42 (64KB) + Core L#42 + PU L#42 (P#42)
        L2 L#43 (512KB) + L1d L#43 (32KB) + L1i L#43 (64KB) + Core L#43 + PU L#43 (P#43)
        L2 L#44 (512KB) + L1d L#44 (32KB) + L1i L#44 (64KB) + Core L#44 + PU L#44 (P#44)
      L3 L#15 (8192KB)
        L2 L#45 (512KB) + L1d L#45 (32KB) + L1i L#45 (64KB) + Core L#45 + PU L#45 (P#45)
        L2 L#46 (512KB) + L1d L#46 (32KB) + L1i L#46 (64KB) + Core L#46 + PU L#46 (P#46)
        L2 L#47 (512KB) + L1d L#47 (32KB) + L1i L#47 (64KB) + Core L#47 + PU L#47 (P#47)
  Misc(MemoryModule)
  Misc(MemoryModule)
  Misc(MemoryModule)
```



以上是海光的7260，还有一个CPU是海光 7280：

```
#lscpu
Architecture:          x86_64
CPU op-mode(s):        32-bit, 64-bit
Byte Order:            Little Endian
CPU(s):                128
On-line CPU(s) list:   0-127
Thread(s) per core:    2
Core(s) per socket:    32
Socket(s):             2
NUMA node(s):          8
Vendor ID:             HygonGenuine
CPU family:            24
Model:                 1
Model name:            Hygon C86 7280 32-core Processor
Stepping:              1
CPU MHz:               1981.025
CPU max MHz:           2000.0000
CPU min MHz:           1200.0000
BogoMIPS:              3999.55
Virtualization:        AMD-V
L1d cache:             32K
L1i cache:             64K
L2 cache:              512K
L3 cache:              8192K
NUMA node0 CPU(s):     0-7,64-71
NUMA node1 CPU(s):     8-15,72-79
NUMA node2 CPU(s):     16-23,80-87
NUMA node3 CPU(s):     24-31,88-95
NUMA node4 CPU(s):     32-39,96-103
NUMA node5 CPU(s):     40-47,104-111
NUMA node6 CPU(s):     48-55,112-119
NUMA node7 CPU(s):     56-63,120-127
```



作业：7260和7280的区别是？为什么搞了这两个差异很小的CPU？

```
//继续在7280上看看L3的大小和共享，能够识别他的Die设计理念

//7280上 L3 由8个超线程，也就是4个物理核共享
#cat cache/index3/shared_cpu_list
0-3,64-67      //就这里核数不一样
#cat cache/index3/size
8192K          //L3大小和7260一样
```

还记得7260是3个物理核共享一个8M的L3吧，计算机的世界大多是1、2、4、8，看到3我就觉得有些别扭。评论区告诉我为什么会搞出3个核这样一个奇葩设计？（星球图解专栏里有答案）

## AMD 7T83

整机256核，一路128超线程，单CPU 64个物理核，很猛了

```
#lscpu
Architecture:          x86_64
CPU op-mode(s):        32-bit, 64-bit
Byte Order:            Little Endian
CPU(s):                256
On-line CPU(s) list:   0-255
Thread(s) per core:    2
Core(s) per socket:    64
Socket(s):             2
NUMA node(s):          4
Vendor ID:             AuthenticAMD
CPU family:            25
Model:                 1
Model name:            AMD EPYC 7T83 64-Core Processor
Stepping:              1
CPU MHz:               1638.563    //主频有点低，估计还是核太多了
CPU max MHz:           2550.0000
CPU min MHz:           1500.0000
BogoMIPS:              5090.06
Virtualization:        AMD-V
L1d cache:             32K
L1i cache:             32K
L2 cache:              512K
L3 cache:              32768K
NUMA node0 CPU(s):     0-31,128-159
NUMA node1 CPU(s):     32-63,160-191
NUMA node2 CPU(s):     64-95,192-223
NUMA node3 CPU(s):     96-127,224-255 //这里展示的是4个Node，在Bios中可配置

#lstopo-no-graphics
Machine (2015GB) //2T 内存
  Socket L#0 (1007GB) //单路 1T内存，一路下有两个Numa Node
    NUMANode L#0 (P#0 503GB) //这个Node下有4块独立的L3 
      L3 L#0 (32MB) //看起来16个超线程共享这一个L3，其实这16个核应该是一个独立的Node比较好
        L2 L#0 (512KB) + L1d L#0 (32KB) + L1i L#0 (32KB) + Core L#0
          PU L#0 (P#0)
          PU L#1 (P#128)
        L2 L#1 (512KB) + L1d L#1 (32KB) + L1i L#1 (32KB) + Core L#1
          PU L#2 (P#1)
          PU L#3 (P#129)
        L2 L#2 (512KB) + L1d L#2 (32KB) + L1i L#2 (32KB) + Core L#2
          PU L#4 (P#2)
          PU L#5 (P#130)
        L2 L#3 (512KB) + L1d L#3 (32KB) + L1i L#3 (32KB) + Core L#3
          PU L#6 (P#3)
          PU L#7 (P#131)
        L2 L#4 (512KB) + L1d L#4 (32KB) + L1i L#4 (32KB) + Core L#4
          PU L#8 (P#4)
          PU L#9 (P#132)
        L2 L#5 (512KB) + L1d L#5 (32KB) + L1i L#5 (32KB) + Core L#5
          PU L#10 (P#5)
          PU L#11 (P#133)
        L2 L#6 (512KB) + L1d L#6 (32KB) + L1i L#6 (32KB) + Core L#6
          PU L#12 (P#6)
          PU L#13 (P#134)
        L2 L#7 (512KB) + L1d L#7 (32KB) + L1i L#7 (32KB) + Core L#7
          PU L#14 (P#7)
          PU L#15 (P#135)
      L3 L#1 (32MB)
        L2 L#8 (512KB) + L1d L#8 (32KB) + L1i L#8 (32KB) + Core L#8
          PU L#16 (P#8)
          PU L#17 (P#136)
        L2 L#9 (512KB) + L1d L#9 (32KB) + L1i L#9 (32KB) + Core L#9
          PU L#18 (P#9)
          PU L#19 (P#137)
        L2 L#10 (512KB) + L1d L#10 (32KB) + L1i L#10 (32KB) + Core L#10
          PU L#20 (P#10)
          PU L#21 (P#138)
        L2 L#11 (512KB) + L1d L#11 (32KB) + L1i L#11 (32KB) + Core L#11
          PU L#22 (P#11)
          PU L#23 (P#139)
        L2 L#12 (512KB) + L1d L#12 (32KB) + L1i L#12 (32KB) + Core L#12
          PU L#24 (P#12)
          PU L#25 (P#140)
        L2 L#13 (512KB) + L1d L#13 (32KB) + L1i L#13 (32KB) + Core L#13
          PU L#26 (P#13)
          PU L#27 (P#141)
        L2 L#14 (512KB) + L1d L#14 (32KB) + L1i L#14 (32KB) + Core L#14
          PU L#28 (P#14)
          PU L#29 (P#142)
        L2 L#15 (512KB) + L1d L#15 (32KB) + L1i L#15 (32KB) + Core L#15
          PU L#30 (P#15)
          PU L#31 (P#143)
      L3 L#2 (32MB)
        L2 L#16 (512KB) + L1d L#16 (32KB) + L1i L#16 (32KB) + Core L#16
          PU L#32 (P#16)
          PU L#33 (P#144)
        L2 L#17 (512KB) + L1d L#17 (32KB) + L1i L#17 (32KB) + Core L#17
          PU L#34 (P#17)
          PU L#35 (P#145)
        L2 L#18 (512KB) + L1d L#18 (32KB) + L1i L#18 (32KB) + Core L#18
          PU L#36 (P#18)
          PU L#37 (P#146)
        L2 L#19 (512KB) + L1d L#19 (32KB) + L1i L#19 (32KB) + Core L#19
          PU L#38 (P#19)
          PU L#39 (P#147)
        L2 L#20 (512KB) + L1d L#20 (32KB) + L1i L#20 (32KB) + Core L#20
          PU L#40 (P#20)
          PU L#41 (P#148)
        L2 L#21 (512KB) + L1d L#21 (32KB) + L1i L#21 (32KB) + Core L#21
          PU L#42 (P#21)
          PU L#43 (P#149)
        L2 L#22 (512KB) + L1d L#22 (32KB) + L1i L#22 (32KB) + Core L#22
          PU L#44 (P#22)
          PU L#45 (P#150)
        L2 L#23 (512KB) + L1d L#23 (32KB) + L1i L#23 (32KB) + Core L#23
          PU L#46 (P#23)
          PU L#47 (P#151)
      L3 L#3 (32MB)
        L2 L#24 (512KB) + L1d L#24 (32KB) + L1i L#24 (32KB) + Core L#24
          PU L#48 (P#24)
          PU L#49 (P#152)
        L2 L#25 (512KB) + L1d L#25 (32KB) + L1i L#25 (32KB) + Core L#25
          PU L#50 (P#25)
          PU L#51 (P#153)
        L2 L#26 (512KB) + L1d L#26 (32KB) + L1i L#26 (32KB) + Core L#26
          PU L#52 (P#26)
          PU L#53 (P#154)
        L2 L#27 (512KB) + L1d L#27 (32KB) + L1i L#27 (32KB) + Core L#27
          PU L#54 (P#27)
          PU L#55 (P#155)
        L2 L#28 (512KB) + L1d L#28 (32KB) + L1i L#28 (32KB) + Core L#28
          PU L#56 (P#28)
          PU L#57 (P#156)
        L2 L#29 (512KB) + L1d L#29 (32KB) + L1i L#29 (32KB) + Core L#29
          PU L#58 (P#29)
          PU L#59 (P#157)
        L2 L#30 (512KB) + L1d L#30 (32KB) + L1i L#30 (32KB) + Core L#30
          PU L#60 (P#30)
          PU L#61 (P#158)
        L2 L#31 (512KB) + L1d L#31 (32KB) + L1i L#31 (32KB) + Core L#31
          PU L#62 (P#31)
          PU L#63 (P#159)
      HostBridge L#0
        PCIBridge
          PCI 144d:a80a
        PCIBridge
          PCI 144d:a80a
        PCIBridge
          PCIBridge
            PCI 1a03:2000
              GPU L#0 "controlD64"
              GPU L#1 "card0"
    NUMANode L#1 (P#1 504GB)
      L3 L#4 (32MB)
        L2 L#32 (512KB) + L1d L#32 (32KB) + L1i L#32 (32KB) + Core L#32
          PU L#64 (P#32)
          PU L#65 (P#160)
        L2 L#33 (512KB) + L1d L#33 (32KB) + L1i L#33 (32KB) + Core L#33
          PU L#66 (P#33)
          PU L#67 (P#161)
        L2 L#34 (512KB) + L1d L#34 (32KB) + L1i L#34 (32KB) + Core L#34
          PU L#68 (P#34)
          PU L#69 (P#162)
        L2 L#35 (512KB) + L1d L#35 (32KB) + L1i L#35 (32KB) + Core L#35
          PU L#70 (P#35)
          PU L#71 (P#163)
        L2 L#36 (512KB) + L1d L#36 (32KB) + L1i L#36 (32KB) + Core L#36
          PU L#72 (P#36)
          PU L#73 (P#164)
        L2 L#37 (512KB) + L1d L#37 (32KB) + L1i L#37 (32KB) + Core L#37
          PU L#74 (P#37)
          PU L#75 (P#165)
        L2 L#38 (512KB) + L1d L#38 (32KB) + L1i L#38 (32KB) + Core L#38
          PU L#76 (P#38)
          PU L#77 (P#166)
        L2 L#39 (512KB) + L1d L#39 (32KB) + L1i L#39 (32KB) + Core L#39
          PU L#78 (P#39)
          PU L#79 (P#167)
      L3 L#5 (32MB)
        L2 L#40 (512KB) + L1d L#40 (32KB) + L1i L#40 (32KB) + Core L#40
          PU L#80 (P#40)
          PU L#81 (P#168)
        L2 L#41 (512KB) + L1d L#41 (32KB) + L1i L#41 (32KB) + Core L#41
          PU L#82 (P#41)
          PU L#83 (P#169)
        L2 L#42 (512KB) + L1d L#42 (32KB) + L1i L#42 (32KB) + Core L#42
          PU L#84 (P#42)
          PU L#85 (P#170)
        L2 L#43 (512KB) + L1d L#43 (32KB) + L1i L#43 (32KB) + Core L#43
          PU L#86 (P#43)
          PU L#87 (P#171)
        L2 L#44 (512KB) + L1d L#44 (32KB) + L1i L#44 (32KB) + Core L#44
          PU L#88 (P#44)
          PU L#89 (P#172)
        L2 L#45 (512KB) + L1d L#45 (32KB) + L1i L#45 (32KB) + Core L#45
          PU L#90 (P#45)
          PU L#91 (P#173)
        L2 L#46 (512KB) + L1d L#46 (32KB) + L1i L#46 (32KB) + Core L#46
          PU L#92 (P#46)
          PU L#93 (P#174)
        L2 L#47 (512KB) + L1d L#47 (32KB) + L1i L#47 (32KB) + Core L#47
          PU L#94 (P#47)
          PU L#95 (P#175)
      L3 L#6 (32MB)
        L2 L#48 (512KB) + L1d L#48 (32KB) + L1i L#48 (32KB) + Core L#48
          PU L#96 (P#48)
          PU L#97 (P#176)
        L2 L#49 (512KB) + L1d L#49 (32KB) + L1i L#49 (32KB) + Core L#49
          PU L#98 (P#49)
          PU L#99 (P#177)
        L2 L#50 (512KB) + L1d L#50 (32KB) + L1i L#50 (32KB) + Core L#50
          PU L#100 (P#50)
          PU L#101 (P#178)
        L2 L#51 (512KB) + L1d L#51 (32KB) + L1i L#51 (32KB) + Core L#51
          PU L#102 (P#51)
          PU L#103 (P#179)
        L2 L#52 (512KB) + L1d L#52 (32KB) + L1i L#52 (32KB) + Core L#52
          PU L#104 (P#52)
          PU L#105 (P#180)
        L2 L#53 (512KB) + L1d L#53 (32KB) + L1i L#53 (32KB) + Core L#53
          PU L#106 (P#53)
          PU L#107 (P#181)
        L2 L#54 (512KB) + L1d L#54 (32KB) + L1i L#54 (32KB) + Core L#54
          PU L#108 (P#54)
          PU L#109 (P#182)
        L2 L#55 (512KB) + L1d L#55 (32KB) + L1i L#55 (32KB) + Core L#55
          PU L#110 (P#55)
          PU L#111 (P#183)
      L3 L#7 (32MB)
        L2 L#56 (512KB) + L1d L#56 (32KB) + L1i L#56 (32KB) + Core L#56
          PU L#112 (P#56)
          PU L#113 (P#184)
        L2 L#57 (512KB) + L1d L#57 (32KB) + L1i L#57 (32KB) + Core L#57
          PU L#114 (P#57)
          PU L#115 (P#185)
        L2 L#58 (512KB) + L1d L#58 (32KB) + L1i L#58 (32KB) + Core L#58
          PU L#116 (P#58)
          PU L#117 (P#186)
        L2 L#59 (512KB) + L1d L#59 (32KB) + L1i L#59 (32KB) + Core L#59
          PU L#118 (P#59)
          PU L#119 (P#187)
        L2 L#60 (512KB) + L1d L#60 (32KB) + L1i L#60 (32KB) + Core L#60
          PU L#120 (P#60)
          PU L#121 (P#188)
        L2 L#61 (512KB) + L1d L#61 (32KB) + L1i L#61 (32KB) + Core L#61
          PU L#122 (P#61)
          PU L#123 (P#189)
        L2 L#62 (512KB) + L1d L#62 (32KB) + L1i L#62 (32KB) + Core L#62
          PU L#124 (P#62)
          PU L#125 (P#190)
        L2 L#63 (512KB) + L1d L#63 (32KB) + L1i L#63 (32KB) + Core L#63
          PU L#126 (P#63)
          PU L#127 (P#191)
      HostBridge L#5
        PCIBridge
          PCIBridge
            PCIBridge
              PCI 1af4:1001
            PCIBridge
              PCI 1ded:1001
              PCI ffff:ffff

  Socket L#1 (1008GB)
    NUMANode L#2 (P#2 504GB)
      L3 L#8 (32MB)
        L2 L#64 (512KB) + L1d L#64 (32KB) + L1i L#64 (32KB) + Core L#64
          PU L#128 (P#64)
          PU L#129 (P#192)
        L2 L#65 (512KB) + L1d L#65 (32KB) + L1i L#65 (32KB) + Core L#65
          PU L#130 (P#65)
          PU L#131 (P#193)
        L2 L#66 (512KB) + L1d L#66 (32KB) + L1i L#66 (32KB) + Core L#66
          PU L#132 (P#66)
          PU L#133 (P#194)
        L2 L#67 (512KB) + L1d L#67 (32KB) + L1i L#67 (32KB) + Core L#67
          PU L#134 (P#67)
          PU L#135 (P#195)
        L2 L#68 (512KB) + L1d L#68 (32KB) + L1i L#68 (32KB) + Core L#68
          PU L#136 (P#68)
          PU L#137 (P#196)
        L2 L#69 (512KB) + L1d L#69 (32KB) + L1i L#69 (32KB) + Core L#69
          PU L#138 (P#69)
          PU L#139 (P#197)
        L2 L#70 (512KB) + L1d L#70 (32KB) + L1i L#70 (32KB) + Core L#70
          PU L#140 (P#70)
          PU L#141 (P#198)
        L2 L#71 (512KB) + L1d L#71 (32KB) + L1i L#71 (32KB) + Core L#71
          PU L#142 (P#71)
          PU L#143 (P#199)
      L3 L#9 (32MB)
        L2 L#72 (512KB) + L1d L#72 (32KB) + L1i L#72 (32KB) + Core L#72
          PU L#144 (P#72)
          PU L#145 (P#200)
        L2 L#73 (512KB) + L1d L#73 (32KB) + L1i L#73 (32KB) + Core L#73
          PU L#146 (P#73)
          PU L#147 (P#201)
        L2 L#74 (512KB) + L1d L#74 (32KB) + L1i L#74 (32KB) + Core L#74
          PU L#148 (P#74)
          PU L#149 (P#202)
        L2 L#75 (512KB) + L1d L#75 (32KB) + L1i L#75 (32KB) + Core L#75
          PU L#150 (P#75)
          PU L#151 (P#203)
        L2 L#76 (512KB) + L1d L#76 (32KB) + L1i L#76 (32KB) + Core L#76
          PU L#152 (P#76)
          PU L#153 (P#204)
        L2 L#77 (512KB) + L1d L#77 (32KB) + L1i L#77 (32KB) + Core L#77
          PU L#154 (P#77)
          PU L#155 (P#205)
        L2 L#78 (512KB) + L1d L#78 (32KB) + L1i L#78 (32KB) + Core L#78
          PU L#156 (P#78)
          PU L#157 (P#206)
        L2 L#79 (512KB) + L1d L#79 (32KB) + L1i L#79 (32KB) + Core L#79
          PU L#158 (P#79)
          PU L#159 (P#207)
      L3 L#10 (32MB)
        L2 L#80 (512KB) + L1d L#80 (32KB) + L1i L#80 (32KB) + Core L#80
          PU L#160 (P#80)
          PU L#161 (P#208)
        L2 L#81 (512KB) + L1d L#81 (32KB) + L1i L#81 (32KB) + Core L#81
          PU L#162 (P#81)
          PU L#163 (P#209)
        L2 L#82 (512KB) + L1d L#82 (32KB) + L1i L#82 (32KB) + Core L#82
          PU L#164 (P#82)
          PU L#165 (P#210)
        L2 L#83 (512KB) + L1d L#83 (32KB) + L1i L#83 (32KB) + Core L#83
          PU L#166 (P#83)
          PU L#167 (P#211)
        L2 L#84 (512KB) + L1d L#84 (32KB) + L1i L#84 (32KB) + Core L#84
          PU L#168 (P#84)
          PU L#169 (P#212)
        L2 L#85 (512KB) + L1d L#85 (32KB) + L1i L#85 (32KB) + Core L#85
          PU L#170 (P#85)
          PU L#171 (P#213)
        L2 L#86 (512KB) + L1d L#86 (32KB) + L1i L#86 (32KB) + Core L#86
          PU L#172 (P#86)
          PU L#173 (P#214)
        L2 L#87 (512KB) + L1d L#87 (32KB) + L1i L#87 (32KB) + Core L#87
          PU L#174 (P#87)
          PU L#175 (P#215)
      L3 L#11 (32MB)
        L2 L#88 (512KB) + L1d L#88 (32KB) + L1i L#88 (32KB) + Core L#88
          PU L#176 (P#88)
          PU L#177 (P#216)
        L2 L#89 (512KB) + L1d L#89 (32KB) + L1i L#89 (32KB) + Core L#89
          PU L#178 (P#89)
          PU L#179 (P#217)
        L2 L#90 (512KB) + L1d L#90 (32KB) + L1i L#90 (32KB) + Core L#90
          PU L#180 (P#90)
          PU L#181 (P#218)
        L2 L#91 (512KB) + L1d L#91 (32KB) + L1i L#91 (32KB) + Core L#91
          PU L#182 (P#91)
          PU L#183 (P#219)
        L2 L#92 (512KB) + L1d L#92 (32KB) + L1i L#92 (32KB) + Core L#92
          PU L#184 (P#92)
          PU L#185 (P#220)
        L2 L#93 (512KB) + L1d L#93 (32KB) + L1i L#93 (32KB) + Core L#93
          PU L#186 (P#93)
          PU L#187 (P#221)
        L2 L#94 (512KB) + L1d L#94 (32KB) + L1i L#94 (32KB) + Core L#94
          PU L#188 (P#94)
          PU L#189 (P#222)
        L2 L#95 (512KB) + L1d L#95 (32KB) + L1i L#95 (32KB) + Core L#95
          PU L#190 (P#95)
          PU L#191 (P#223)
    NUMANode L#3 (P#3 504GB)
      L3 L#12 (32MB)
        L2 L#96 (512KB) + L1d L#96 (32KB) + L1i L#96 (32KB) + Core L#96
          PU L#192 (P#96)
          PU L#193 (P#224)
        L2 L#97 (512KB) + L1d L#97 (32KB) + L1i L#97 (32KB) + Core L#97
          PU L#194 (P#97)
          PU L#195 (P#225)
        L2 L#98 (512KB) + L1d L#98 (32KB) + L1i L#98 (32KB) + Core L#98
          PU L#196 (P#98)
          PU L#197 (P#226)
        L2 L#99 (512KB) + L1d L#99 (32KB) + L1i L#99 (32KB) + Core L#99
          PU L#198 (P#99)
          PU L#199 (P#227)
        L2 L#100 (512KB) + L1d L#100 (32KB) + L1i L#100 (32KB) + Core L#100
          PU L#200 (P#100)
          PU L#201 (P#228)
        L2 L#101 (512KB) + L1d L#101 (32KB) + L1i L#101 (32KB) + Core L#101
          PU L#202 (P#101)
          PU L#203 (P#229)
        L2 L#102 (512KB) + L1d L#102 (32KB) + L1i L#102 (32KB) + Core L#102
          PU L#204 (P#102)
          PU L#205 (P#230)
        L2 L#103 (512KB) + L1d L#103 (32KB) + L1i L#103 (32KB) + Core L#103
          PU L#206 (P#103)
          PU L#207 (P#231)
      L3 L#13 (32MB)
        L2 L#104 (512KB) + L1d L#104 (32KB) + L1i L#104 (32KB) + Core L#104
          PU L#208 (P#104)
          PU L#209 (P#232)
        L2 L#105 (512KB) + L1d L#105 (32KB) + L1i L#105 (32KB) + Core L#105
          PU L#210 (P#105)
          PU L#211 (P#233)
        L2 L#106 (512KB) + L1d L#106 (32KB) + L1i L#106 (32KB) + Core L#106
          PU L#212 (P#106)
          PU L#213 (P#234)
        L2 L#107 (512KB) + L1d L#107 (32KB) + L1i L#107 (32KB) + Core L#107
          PU L#214 (P#107)
          PU L#215 (P#235)
        L2 L#108 (512KB) + L1d L#108 (32KB) + L1i L#108 (32KB) + Core L#108
          PU L#216 (P#108)
          PU L#217 (P#236)
        L2 L#109 (512KB) + L1d L#109 (32KB) + L1i L#109 (32KB) + Core L#109
          PU L#218 (P#109)
          PU L#219 (P#237)
        L2 L#110 (512KB) + L1d L#110 (32KB) + L1i L#110 (32KB) + Core L#110
          PU L#220 (P#110)
          PU L#221 (P#238)
        L2 L#111 (512KB) + L1d L#111 (32KB) + L1i L#111 (32KB) + Core L#111
          PU L#222 (P#111)
          PU L#223 (P#239)
      L3 L#14 (32MB)
        L2 L#112 (512KB) + L1d L#112 (32KB) + L1i L#112 (32KB) + Core L#112
          PU L#224 (P#112)
          PU L#225 (P#240)
        L2 L#113 (512KB) + L1d L#113 (32KB) + L1i L#113 (32KB) + Core L#113
          PU L#226 (P#113)
          PU L#227 (P#241)
        L2 L#114 (512KB) + L1d L#114 (32KB) + L1i L#114 (32KB) + Core L#114
          PU L#228 (P#114)
          PU L#229 (P#242)
        L2 L#115 (512KB) + L1d L#115 (32KB) + L1i L#115 (32KB) + Core L#115
          PU L#230 (P#115)
          PU L#231 (P#243)
        L2 L#116 (512KB) + L1d L#116 (32KB) + L1i L#116 (32KB) + Core L#116
          PU L#232 (P#116)
          PU L#233 (P#244)
        L2 L#117 (512KB) + L1d L#117 (32KB) + L1i L#117 (32KB) + Core L#117
          PU L#234 (P#117)
          PU L#235 (P#245)
        L2 L#118 (512KB) + L1d L#118 (32KB) + L1i L#118 (32KB) + Core L#118
          PU L#236 (P#118)
          PU L#237 (P#246)
        L2 L#119 (512KB) + L1d L#119 (32KB) + L1i L#119 (32KB) + Core L#119
          PU L#238 (P#119)
          PU L#239 (P#247)
      L3 L#15 (32MB)
        L2 L#120 (512KB) + L1d L#120 (32KB) + L1i L#120 (32KB) + Core L#120
          PU L#240 (P#120)
          PU L#241 (P#248)
        L2 L#121 (512KB) + L1d L#121 (32KB) + L1i L#121 (32KB) + Core L#121
          PU L#242 (P#121)
          PU L#243 (P#249)
        L2 L#122 (512KB) + L1d L#122 (32KB) + L1i L#122 (32KB) + Core L#122
          PU L#244 (P#122)
          PU L#245 (P#250)
        L2 L#123 (512KB) + L1d L#123 (32KB) + L1i L#123 (32KB) + Core L#123
          PU L#246 (P#123)
          PU L#247 (P#251)
        L2 L#124 (512KB) + L1d L#124 (32KB) + L1i L#124 (32KB) + Core L#124
          PU L#248 (P#124)
          PU L#249 (P#252)
        L2 L#125 (512KB) + L1d L#125 (32KB) + L1i L#125 (32KB) + Core L#125
          PU L#250 (P#125)
          PU L#251 (P#253)
        L2 L#126 (512KB) + L1d L#126 (32KB) + L1i L#126 (32KB) + Core L#126
          PU L#252 (P#126)
          PU L#253 (P#254)
        L2 L#127 (512KB) + L1d L#127 (32KB) + L1i L#127 (32KB) + Core L#127
          PU L#254 (P#127)
          PU L#255 (P#255)
```



这台机器改下BIOS设置

![img](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/FrVuhXNHEf2LzigZPHHV6c7UNKrP.png)

白色Channel 那里可以选择Auto/Die/Channel/Socket, 选择Socket后得到如下Node 结构:

```
#lscpu
Architecture:          x86_64
CPU op-mode(s):        32-bit, 64-bit
Byte Order:            Little Endian
CPU(s):                256
On-line CPU(s) list:   0-255
Thread(s) per core:    2
Core(s) per socket:    64
Socket(s):             2
NUMA node(s):          2
Vendor ID:             AuthenticAMD
CPU family:            25
Model:                 1
Model name:            AMD EPYC 7T83 64-Core Processor
Stepping:              1
CPU MHz:               2399.192
CPU max MHz:           2550.0000
CPU min MHz:           1500.0000
BogoMIPS:              5090.50
Virtualization:        AMD-V
L1d cache:             32K
L1i cache:             32K
L2 cache:              512K
L3 cache:              32768K
NUMA node0 CPU(s):     0-63,128-191
NUMA node1 CPU(s):     64-127,192-255 //每个socket下的内存交织，也就是一个Socket是一个独立的 Numa Node
```



## 鲲鹏 920

鲲鹏是ARM架构，一般都没有超线程，因为指令简单流水线较流畅，搞超线程收益不大

```
# lscpu
架构：                           aarch64
CPU 运行模式：                   64-bit
字节序：                         Little Endian
CPU:                             96
在线 CPU 列表：                  0-95
每个核的线程数：                 1
每个座的核数：                   48
座：                             2
NUMA 节点：                      4
厂商 ID：                        HiSilicon
型号：                           0
型号名称：                       Kunpeng-920
步进：                           0x1
CPU 最大 MHz：                   2600.0000
CPU 最小 MHz：                   200.0000
BogoMIPS：                       200.00
L1d 缓存：                       6 MiB
L1i 缓存：                       6 MiB
L2 缓存：                        48 MiB
L3 缓存：                        96 MiB
NUMA 节点0 CPU：                 0-23
NUMA 节点1 CPU：                 24-47
NUMA 节点2 CPU：                 48-71
NUMA 节点3 CPU：                 72-95

#lstopo
Machine (766GB total)
  Package L#0
    NUMANode L#0 (P#0 191GB)
      L3 L#0 (24MB)
        L2 L#0 (512KB) + L1d L#0 (64KB) + L1i L#0 (64KB) + Core L#0 + PU L#0 (P#0)
        L2 L#1 (512KB) + L1d L#1 (64KB) + L1i L#1 (64KB) + Core L#1 + PU L#1 (P#1)
        L2 L#2 (512KB) + L1d L#2 (64KB) + L1i L#2 (64KB) + Core L#2 + PU L#2 (P#2)
        L2 L#3 (512KB) + L1d L#3 (64KB) + L1i L#3 (64KB) + Core L#3 + PU L#3 (P#3)
        L2 L#4 (512KB) + L1d L#4 (64KB) + L1i L#4 (64KB) + Core L#4 + PU L#4 (P#4)
        L2 L#5 (512KB) + L1d L#5 (64KB) + L1i L#5 (64KB) + Core L#5 + PU L#5 (P#5)
        L2 L#6 (512KB) + L1d L#6 (64KB) + L1i L#6 (64KB) + Core L#6 + PU L#6 (P#6)
        L2 L#7 (512KB) + L1d L#7 (64KB) + L1i L#7 (64KB) + Core L#7 + PU L#7 (P#7)
        L2 L#8 (512KB) + L1d L#8 (64KB) + L1i L#8 (64KB) + Core L#8 + PU L#8 (P#8)
        L2 L#9 (512KB) + L1d L#9 (64KB) + L1i L#9 (64KB) + Core L#9 + PU L#9 (P#9)
        L2 L#10 (512KB) + L1d L#10 (64KB) + L1i L#10 (64KB) + Core L#10 + PU L#10 (P#10)
        L2 L#11 (512KB) + L1d L#11 (64KB) + L1i L#11 (64KB) + Core L#11 + PU L#11 (P#11)
        L2 L#12 (512KB) + L1d L#12 (64KB) + L1i L#12 (64KB) + Core L#12 + PU L#12 (P#12)
        L2 L#13 (512KB) + L1d L#13 (64KB) + L1i L#13 (64KB) + Core L#13 + PU L#13 (P#13)
        L2 L#14 (512KB) + L1d L#14 (64KB) + L1i L#14 (64KB) + Core L#14 + PU L#14 (P#14)
        L2 L#15 (512KB) + L1d L#15 (64KB) + L1i L#15 (64KB) + Core L#15 + PU L#15 (P#15)
        L2 L#16 (512KB) + L1d L#16 (64KB) + L1i L#16 (64KB) + Core L#16 + PU L#16 (P#16)
        L2 L#17 (512KB) + L1d L#17 (64KB) + L1i L#17 (64KB) + Core L#17 + PU L#17 (P#17)
        L2 L#18 (512KB) + L1d L#18 (64KB) + L1i L#18 (64KB) + Core L#18 + PU L#18 (P#18)
        L2 L#19 (512KB) + L1d L#19 (64KB) + L1i L#19 (64KB) + Core L#19 + PU L#19 (P#19)
        L2 L#20 (512KB) + L1d L#20 (64KB) + L1i L#20 (64KB) + Core L#20 + PU L#20 (P#20)
        L2 L#21 (512KB) + L1d L#21 (64KB) + L1i L#21 (64KB) + Core L#21 + PU L#21 (P#21)
        L2 L#22 (512KB) + L1d L#22 (64KB) + L1i L#22 (64KB) + Core L#22 + PU L#22 (P#22)
        L2 L#23 (512KB) + L1d L#23 (64KB) + L1i L#23 (64KB) + Core L#23 + PU L#23 (P#23)
      HostBridge L#0
        PCIBridge
          PCI 15b3:1017
            Net L#0 "enp2s0f0"
          PCI 15b3:1017
            Net L#1 "enp2s0f1"
        PCIBridge
          PCI 19e5:1711
            GPU L#2 "controlD64"
            GPU L#3 "card0"
      HostBridge L#3
        2 x { PCI 19e5:a230 }
        PCI 19e5:a235
          Block(Disk) L#4 "sda"
      HostBridge L#4
        PCIBridge
          PCI 19e5:a222
            Net L#5 "enp125s0f0"
            OpenFabrics L#6 "hns_0"
          PCI 19e5:a221
            Net L#7 "enp125s0f1"
          PCI 19e5:a222
            Net L#8 "enp125s0f2"
            OpenFabrics L#9 "hns_1"
          PCI 19e5:a221
            Net L#10 "enp125s0f3"
    NUMANode L#1 (P#1 192GB) + L3 L#1 (24MB)
      L2 L#24 (512KB) + L1d L#24 (64KB) + L1i L#24 (64KB) + Core L#24 + PU L#24 (P#24)
      L2 L#25 (512KB) + L1d L#25 (64KB) + L1i L#25 (64KB) + Core L#25 + PU L#25 (P#25)
      L2 L#26 (512KB) + L1d L#26 (64KB) + L1i L#26 (64KB) + Core L#26 + PU L#26 (P#26)
      L2 L#27 (512KB) + L1d L#27 (64KB) + L1i L#27 (64KB) + Core L#27 + PU L#27 (P#27)
      L2 L#28 (512KB) + L1d L#28 (64KB) + L1i L#28 (64KB) + Core L#28 + PU L#28 (P#28)
      L2 L#29 (512KB) + L1d L#29 (64KB) + L1i L#29 (64KB) + Core L#29 + PU L#29 (P#29)
      L2 L#30 (512KB) + L1d L#30 (64KB) + L1i L#30 (64KB) + Core L#30 + PU L#30 (P#30)
      L2 L#31 (512KB) + L1d L#31 (64KB) + L1i L#31 (64KB) + Core L#31 + PU L#31 (P#31)
      L2 L#32 (512KB) + L1d L#32 (64KB) + L1i L#32 (64KB) + Core L#32 + PU L#32 (P#32)
      L2 L#33 (512KB) + L1d L#33 (64KB) + L1i L#33 (64KB) + Core L#33 + PU L#33 (P#33)
      L2 L#34 (512KB) + L1d L#34 (64KB) + L1i L#34 (64KB) + Core L#34 + PU L#34 (P#34)
      L2 L#35 (512KB) + L1d L#35 (64KB) + L1i L#35 (64KB) + Core L#35 + PU L#35 (P#35)
      L2 L#36 (512KB) + L1d L#36 (64KB) + L1i L#36 (64KB) + Core L#36 + PU L#36 (P#36)
      L2 L#37 (512KB) + L1d L#37 (64KB) + L1i L#37 (64KB) + Core L#37 + PU L#37 (P#37)
      L2 L#38 (512KB) + L1d L#38 (64KB) + L1i L#38 (64KB) + Core L#38 + PU L#38 (P#38)
      L2 L#39 (512KB) + L1d L#39 (64KB) + L1i L#39 (64KB) + Core L#39 + PU L#39 (P#39)
      L2 L#40 (512KB) + L1d L#40 (64KB) + L1i L#40 (64KB) + Core L#40 + PU L#40 (P#40)
      L2 L#41 (512KB) + L1d L#41 (64KB) + L1i L#41 (64KB) + Core L#41 + PU L#41 (P#41)
      L2 L#42 (512KB) + L1d L#42 (64KB) + L1i L#42 (64KB) + Core L#42 + PU L#42 (P#42)
      L2 L#43 (512KB) + L1d L#43 (64KB) + L1i L#43 (64KB) + Core L#43 + PU L#43 (P#43)
      L2 L#44 (512KB) + L1d L#44 (64KB) + L1i L#44 (64KB) + Core L#44 + PU L#44 (P#44)
      L2 L#45 (512KB) + L1d L#45 (64KB) + L1i L#45 (64KB) + Core L#45 + PU L#45 (P#45)
      L2 L#46 (512KB) + L1d L#46 (64KB) + L1i L#46 (64KB) + Core L#46 + PU L#46 (P#46)
      L2 L#47 (512KB) + L1d L#47 (64KB) + L1i L#47 (64KB) + Core L#47 + PU L#47 (P#47)
  Package L#1
    NUMANode L#2 (P#2 192GB)
      L3 L#2 (24MB)
        L2 L#48 (512KB) + L1d L#48 (64KB) + L1i L#48 (64KB) + Core L#48 + PU L#48 (P#48)
        L2 L#49 (512KB) + L1d L#49 (64KB) + L1i L#49 (64KB) + Core L#49 + PU L#49 (P#49)
        L2 L#50 (512KB) + L1d L#50 (64KB) + L1i L#50 (64KB) + Core L#50 + PU L#50 (P#50)
        L2 L#51 (512KB) + L1d L#51 (64KB) + L1i L#51 (64KB) + Core L#51 + PU L#51 (P#51)
        L2 L#52 (512KB) + L1d L#52 (64KB) + L1i L#52 (64KB) + Core L#52 + PU L#52 (P#52)
        L2 L#53 (512KB) + L1d L#53 (64KB) + L1i L#53 (64KB) + Core L#53 + PU L#53 (P#53)
        L2 L#54 (512KB) + L1d L#54 (64KB) + L1i L#54 (64KB) + Core L#54 + PU L#54 (P#54)
        L2 L#55 (512KB) + L1d L#55 (64KB) + L1i L#55 (64KB) + Core L#55 + PU L#55 (P#55)
        L2 L#56 (512KB) + L1d L#56 (64KB) + L1i L#56 (64KB) + Core L#56 + PU L#56 (P#56)
        L2 L#57 (512KB) + L1d L#57 (64KB) + L1i L#57 (64KB) + Core L#57 + PU L#57 (P#57)
        L2 L#58 (512KB) + L1d L#58 (64KB) + L1i L#58 (64KB) + Core L#58 + PU L#58 (P#58)
        L2 L#59 (512KB) + L1d L#59 (64KB) + L1i L#59 (64KB) + Core L#59 + PU L#59 (P#59)
        L2 L#60 (512KB) + L1d L#60 (64KB) + L1i L#60 (64KB) + Core L#60 + PU L#60 (P#60)
        L2 L#61 (512KB) + L1d L#61 (64KB) + L1i L#61 (64KB) + Core L#61 + PU L#61 (P#61)
        L2 L#62 (512KB) + L1d L#62 (64KB) + L1i L#62 (64KB) + Core L#62 + PU L#62 (P#62)
        L2 L#63 (512KB) + L1d L#63 (64KB) + L1i L#63 (64KB) + Core L#63 + PU L#63 (P#63)
        L2 L#64 (512KB) + L1d L#64 (64KB) + L1i L#64 (64KB) + Core L#64 + PU L#64 (P#64)
        L2 L#65 (512KB) + L1d L#65 (64KB) + L1i L#65 (64KB) + Core L#65 + PU L#65 (P#65)
        L2 L#66 (512KB) + L1d L#66 (64KB) + L1i L#66 (64KB) + Core L#66 + PU L#66 (P#66)
        L2 L#67 (512KB) + L1d L#67 (64KB) + L1i L#67 (64KB) + Core L#67 + PU L#67 (P#67)
        L2 L#68 (512KB) + L1d L#68 (64KB) + L1i L#68 (64KB) + Core L#68 + PU L#68 (P#68)
        L2 L#69 (512KB) + L1d L#69 (64KB) + L1i L#69 (64KB) + Core L#69 + PU L#69 (P#69)
        L2 L#70 (512KB) + L1d L#70 (64KB) + L1i L#70 (64KB) + Core L#70 + PU L#70 (P#70)
        L2 L#71 (512KB) + L1d L#71 (64KB) + L1i L#71 (64KB) + Core L#71 + PU L#71 (P#71)
      HostBridge L#6
        PCIBridge
          PCI 19e5:3714
        PCIBridge
          PCI 19e5:3714
        PCIBridge
          PCI 19e5:3714
        PCIBridge
          PCI 19e5:3714
      HostBridge L#11
        PCI 19e5:a230
        PCI 19e5:a235
        PCI 19e5:a230
    NUMANode L#3 (P#3 191GB) + L3 L#3 (24MB)
      L2 L#72 (512KB) + L1d L#72 (64KB) + L1i L#72 (64KB) + Core L#72 + PU L#72 (P#72)
      L2 L#73 (512KB) + L1d L#73 (64KB) + L1i L#73 (64KB) + Core L#73 + PU L#73 (P#73)
      L2 L#74 (512KB) + L1d L#74 (64KB) + L1i L#74 (64KB) + Core L#74 + PU L#74 (P#74)
      L2 L#75 (512KB) + L1d L#75 (64KB) + L1i L#75 (64KB) + Core L#75 + PU L#75 (P#75)
      L2 L#76 (512KB) + L1d L#76 (64KB) + L1i L#76 (64KB) + Core L#76 + PU L#76 (P#76)
      L2 L#77 (512KB) + L1d L#77 (64KB) + L1i L#77 (64KB) + Core L#77 + PU L#77 (P#77)
      L2 L#78 (512KB) + L1d L#78 (64KB) + L1i L#78 (64KB) + Core L#78 + PU L#78 (P#78)
      L2 L#79 (512KB) + L1d L#79 (64KB) + L1i L#79 (64KB) + Core L#79 + PU L#79 (P#79)
      L2 L#80 (512KB) + L1d L#80 (64KB) + L1i L#80 (64KB) + Core L#80 + PU L#80 (P#80)
      L2 L#81 (512KB) + L1d L#81 (64KB) + L1i L#81 (64KB) + Core L#81 + PU L#81 (P#81)
      L2 L#82 (512KB) + L1d L#82 (64KB) + L1i L#82 (64KB) + Core L#82 + PU L#82 (P#82)
      L2 L#83 (512KB) + L1d L#83 (64KB) + L1i L#83 (64KB) + Core L#83 + PU L#83 (P#83)
      L2 L#84 (512KB) + L1d L#84 (64KB) + L1i L#84 (64KB) + Core L#84 + PU L#84 (P#84)
      L2 L#85 (512KB) + L1d L#85 (64KB) + L1i L#85 (64KB) + Core L#85 + PU L#85 (P#85)
      L2 L#86 (512KB) + L1d L#86 (64KB) + L1i L#86 (64KB) + Core L#86 + PU L#86 (P#86)
      L2 L#87 (512KB) + L1d L#87 (64KB) + L1i L#87 (64KB) + Core L#87 + PU L#87 (P#87)
      L2 L#88 (512KB) + L1d L#88 (64KB) + L1i L#88 (64KB) + Core L#88 + PU L#88 (P#88)
      L2 L#89 (512KB) + L1d L#89 (64KB) + L1i L#89 (64KB) + Core L#89 + PU L#89 (P#89)
      L2 L#90 (512KB) + L1d L#90 (64KB) + L1i L#90 (64KB) + Core L#90 + PU L#90 (P#90)
      L2 L#91 (512KB) + L1d L#91 (64KB) + L1i L#91 (64KB) + Core L#91 + PU L#91 (P#91)
      L2 L#92 (512KB) + L1d L#92 (64KB) + L1i L#92 (64KB) + Core L#92 + PU L#92 (P#92)
      L2 L#93 (512KB) + L1d L#93 (64KB) + L1i L#93 (64KB) + Core L#93 + PU L#93 (P#93)
      L2 L#94 (512KB) + L1d L#94 (64KB) + L1i L#94 (64KB) + Core L#94 + PU L#94 (P#94)
      L2 L#95 (512KB) + L1d L#95 (64KB) + L1i L#95 (64KB) + Core L#95 + PU L#95 (P#95)
  Misc(MemoryModule)
  Misc(MemoryModule)
  Misc(MemoryModule)
  
  
Node Distance:
node 0 <------------ socket distance ------------> node 2
    | (die distance)                                  | (die distance)
node 1                                             node 3
```

图形化查看（打开大图，和前面的intel 对着看）

![img](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/FkQmi4qpCEyiJ-OlK2MbqfbmbMts.png)

思考：看如上鲲鹏机器的结构你应该知道网卡、硬盘怎么插放的了吧，然后想就近搞点优化也是可以的

## 飞腾2500

飞腾的解读留给大家当作业

https://plantegg.github.io/2021/05/15/%E9%A3%9E%E8%85%BEARM%E8%8A%AF%E7%89%87(FT2500)%E7%9A%84%E6%80%A7%E8%83%BD%E6%B5%8B%E8%AF%95/

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
L2 cache:              2048K   //2M？太大了，不真实，估计和海光一样骚
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



飞腾的核有点多，我省略了一些

```
#lstopo-no-graphics --logical
Machine (503GB total)
  Package L#0 + L3 L#0 (64MB)
    NUMANode L#0 (P#0 31GB)
      L2 L#0 (2048KB)  //4个物理core共享2M，是不是和AMD(海光)那个设计有点像
        L1d L#0 (32KB) + L1i L#0 (32KB) + Core L#0 + PU L#0 (P#0)
        L1d L#1 (32KB) + L1i L#1 (32KB) + Core L#1 + PU L#1 (P#1)
        L1d L#2 (32KB) + L1i L#2 (32KB) + Core L#2 + PU L#2 (P#2)
        L1d L#3 (32KB) + L1i L#3 (32KB) + Core L#3 + PU L#3 (P#3)
      L2 L#1 (2048KB)
        L1d L#4 (32KB) + L1i L#4 (32KB) + Core L#4 + PU L#4 (P#4)
        L1d L#5 (32KB) + L1i L#5 (32KB) + Core L#5 + PU L#5 (P#5)
        L1d L#6 (32KB) + L1i L#6 (32KB) + Core L#6 + PU L#6 (P#6)
        L1d L#7 (32KB) + L1i L#7 (32KB) + Core L#7 + PU L#7 (P#7)
      HostBridge L#0
        PCIBridge
          PCIBridge
            PCIBridge
              PCI 1000:00ac
                Block(Disk) L#0 "sdh"
                Block(Disk) L#1 "sdf"  // 磁盘挂在Node0上
            PCIBridge
              PCI 8086:1521
                Net L#13 "eth0"
              PCI 8086:1521
                Net L#14 "eth1"       //网卡挂在node0上
        PCIBridge
          PCIBridge
            PCI 1a03:2000
              GPU L#15 "controlD64"
              GPU L#16 "card0"
    NUMANode L#1 (P#1 31GB) //都被我省略了
    NUMANode L#2 (P#2 31GB)
    NUMANode L#3 (P#3 31GB)
    NUMANode L#4 (P#4 31GB)
    NUMANode L#5 (P#5 31GB)
    NUMANode L#6 (P#6 31GB)
    NUMANode L#7 (P#7 31GB) //第1个Socket的最后一个Node
      L2 L#14 (2048KB)
        L1d L#56 (32KB) + L1i L#56 (32KB) + Core L#56 + PU L#56 (P#56)
        L1d L#57 (32KB) + L1i L#57 (32KB) + Core L#57 + PU L#57 (P#57)
        L1d L#58 (32KB) + L1i L#58 (32KB) + Core L#58 + PU L#58 (P#58)
        L1d L#59 (32KB) + L1i L#59 (32KB) + Core L#59 + PU L#59 (P#59)
      L2 L#15 (2048KB)
        L1d L#60 (32KB) + L1i L#60 (32KB) + Core L#60 + PU L#60 (P#60)
        L1d L#61 (32KB) + L1i L#61 (32KB) + Core L#61 + PU L#61 (P#61)
        L1d L#62 (32KB) + L1i L#62 (32KB) + Core L#62 + PU L#62 (P#62)
        L1d L#63 (32KB) + L1i L#63 (32KB) + Core L#63 + PU L#63 (P#63)
  Package L#1 + L3 L#1 (64MB)   //第二个Socket，也是8个Node
    NUMANode L#8 (P#8 31GB)
      L2 L#16 (2048KB)
        L1d L#64 (32KB) + L1i L#64 (32KB) + Core L#64 + PU L#64 (P#64)
        L1d L#65 (32KB) + L1i L#65 (32KB) + Core L#65 + PU L#65 (P#65)
        L1d L#66 (32KB) + L1i L#66 (32KB) + Core L#66 + PU L#66 (P#66)
        L1d L#67 (32KB) + L1i L#67 (32KB) + Core L#67 + PU L#67 (P#67)
      L2 L#17 (2048KB)
        L1d L#68 (32KB) + L1i L#68 (32KB) + Core L#68 + PU L#68 (P#68)
        L1d L#69 (32KB) + L1i L#69 (32KB) + Core L#69 + PU L#69 (P#69)
        L1d L#70 (32KB) + L1i L#70 (32KB) + Core L#70 + PU L#70 (P#70)
        L1d L#71 (32KB) + L1i L#71 (32KB) + Core L#71 + PU L#71 (P#71)
      HostBridge L#7
        PCIBridge
          PCIBridge
            PCIBridge
              PCI 15b3:1015
                Net L#17 "eth2"   //node8 上的网卡，eth2、eth3做了bonding
              PCI 15b3:1015
                Net L#18 "eth3"
            PCIBridge
              PCI 144d:a808
            PCIBridge
              PCI 144d:a808
```



## 不知名的一款CPU

当练习看看,随便看看

```
#lscpu
Architecture:          aarch64
Byte Order:            Little Endian
CPU(s):                128
On-line CPU(s) list:   0-127
Thread(s) per core:    1
Core(s) per socket:    128
Socket(s):             1
NUMA node(s):          2
Model:                 0
BogoMIPS:              100.00
L1d cache:             64K
L1i cache:             64K
L2 cache:              1024K
L3 cache:              65536K
NUMA node0 CPU(s):     0-63
NUMA node1 CPU(s):     64-127

#free -g
              total        used        free      shared  buff/cache   available
Mem:           1007         160         511           0         335         840
Swap:             0           0           0

#lstopo-no-graphics
Machine (1008GB) + Socket L#0 (1008GB)
  NUMANode L#0 (P#0 504GB)
    L3 L#0 (64MB)
      L2 L#0 (1024KB) + L1d L#0 (64KB) + L1i L#0 (64KB) + Core L#0 + PU L#0 (P#0)
      L2 L#1 (1024KB) + L1d L#1 (64KB) + L1i L#1 (64KB) + Core L#1 + PU L#1 (P#1)
      L2 L#2 (1024KB) + L1d L#2 (64KB) + L1i L#2 (64KB) + Core L#2 + PU L#2 (P#2)
      L2 L#3 (1024KB) + L1d L#3 (64KB) + L1i L#3 (64KB) + Core L#3 + PU L#3 (P#3)
      L2 L#4 (1024KB) + L1d L#4 (64KB) + L1i L#4 (64KB) + Core L#4 + PU L#4 (P#4)
      L2 L#5 (1024KB) + L1d L#5 (64KB) + L1i L#5 (64KB) + Core L#5 + PU L#5 (P#5)
      L2 L#6 (1024KB) + L1d L#6 (64KB) + L1i L#6 (64KB) + Core L#6 + PU L#6 (P#6)
      L2 L#7 (1024KB) + L1d L#7 (64KB) + L1i L#7 (64KB) + Core L#7 + PU L#7 (P#7)
      L2 L#8 (1024KB) + L1d L#8 (64KB) + L1i L#8 (64KB) + Core L#8 + PU L#8 (P#8)
      L2 L#9 (1024KB) + L1d L#9 (64KB) + L1i L#9 (64KB) + Core L#9 + PU L#9 (P#9)
      L2 L#10 (1024KB) + L1d L#10 (64KB) + L1i L#10 (64KB) + Core L#10 + PU L#10 (P#10)
      L2 L#11 (1024KB) + L1d L#11 (64KB) + L1i L#11 (64KB) + Core L#11 + PU L#11 (P#11)
      L2 L#12 (1024KB) + L1d L#12 (64KB) + L1i L#12 (64KB) + Core L#12 + PU L#12 (P#12)
      L2 L#13 (1024KB) + L1d L#13 (64KB) + L1i L#13 (64KB) + Core L#13 + PU L#13 (P#13)
      L2 L#14 (1024KB) + L1d L#14 (64KB) + L1i L#14 (64KB) + Core L#14 + PU L#14 (P#14)
      L2 L#15 (1024KB) + L1d L#15 (64KB) + L1i L#15 (64KB) + Core L#15 + PU L#15 (P#15)
      L2 L#16 (1024KB) + L1d L#16 (64KB) + L1i L#16 (64KB) + Core L#16 + PU L#16 (P#16)
      L2 L#17 (1024KB) + L1d L#17 (64KB) + L1i L#17 (64KB) + Core L#17 + PU L#17 (P#17)
      L2 L#18 (1024KB) + L1d L#18 (64KB) + L1i L#18 (64KB) + Core L#18 + PU L#18 (P#18)
      L2 L#19 (1024KB) + L1d L#19 (64KB) + L1i L#19 (64KB) + Core L#19 + PU L#19 (P#19)
      L2 L#20 (1024KB) + L1d L#20 (64KB) + L1i L#20 (64KB) + Core L#20 + PU L#20 (P#20)
      L2 L#21 (1024KB) + L1d L#21 (64KB) + L1i L#21 (64KB) + Core L#21 + PU L#21 (P#21)
      L2 L#22 (1024KB) + L1d L#22 (64KB) + L1i L#22 (64KB) + Core L#22 + PU L#22 (P#22)
      L2 L#23 (1024KB) + L1d L#23 (64KB) + L1i L#23 (64KB) + Core L#23 + PU L#23 (P#23)
      L2 L#24 (1024KB) + L1d L#24 (64KB) + L1i L#24 (64KB) + Core L#24 + PU L#24 (P#24)
      L2 L#25 (1024KB) + L1d L#25 (64KB) + L1i L#25 (64KB) + Core L#25 + PU L#25 (P#25)
      L2 L#26 (1024KB) + L1d L#26 (64KB) + L1i L#26 (64KB) + Core L#26 + PU L#26 (P#26)
      L2 L#27 (1024KB) + L1d L#27 (64KB) + L1i L#27 (64KB) + Core L#27 + PU L#27 (P#27)
      L2 L#28 (1024KB) + L1d L#28 (64KB) + L1i L#28 (64KB) + Core L#28 + PU L#28 (P#28)
      L2 L#29 (1024KB) + L1d L#29 (64KB) + L1i L#29 (64KB) + Core L#29 + PU L#29 (P#29)
      L2 L#30 (1024KB) + L1d L#30 (64KB) + L1i L#30 (64KB) + Core L#30 + PU L#30 (P#30)
      L2 L#31 (1024KB) + L1d L#31 (64KB) + L1i L#31 (64KB) + Core L#31 + PU L#31 (P#31)
      L2 L#32 (1024KB) + L1d L#32 (64KB) + L1i L#32 (64KB) + Core L#32 + PU L#32 (P#32)
      L2 L#33 (1024KB) + L1d L#33 (64KB) + L1i L#33 (64KB) + Core L#33 + PU L#33 (P#33)
      L2 L#34 (1024KB) + L1d L#34 (64KB) + L1i L#34 (64KB) + Core L#34 + PU L#34 (P#34)
      L2 L#35 (1024KB) + L1d L#35 (64KB) + L1i L#35 (64KB) + Core L#35 + PU L#35 (P#35)
      L2 L#36 (1024KB) + L1d L#36 (64KB) + L1i L#36 (64KB) + Core L#36 + PU L#36 (P#36)
      L2 L#37 (1024KB) + L1d L#37 (64KB) + L1i L#37 (64KB) + Core L#37 + PU L#37 (P#37)
      L2 L#38 (1024KB) + L1d L#38 (64KB) + L1i L#38 (64KB) + Core L#38 + PU L#38 (P#38)
      L2 L#39 (1024KB) + L1d L#39 (64KB) + L1i L#39 (64KB) + Core L#39 + PU L#39 (P#39)
      L2 L#40 (1024KB) + L1d L#40 (64KB) + L1i L#40 (64KB) + Core L#40 + PU L#40 (P#40)
      L2 L#41 (1024KB) + L1d L#41 (64KB) + L1i L#41 (64KB) + Core L#41 + PU L#41 (P#41)
      L2 L#42 (1024KB) + L1d L#42 (64KB) + L1i L#42 (64KB) + Core L#42 + PU L#42 (P#42)
      L2 L#43 (1024KB) + L1d L#43 (64KB) + L1i L#43 (64KB) + Core L#43 + PU L#43 (P#43)
      L2 L#44 (1024KB) + L1d L#44 (64KB) + L1i L#44 (64KB) + Core L#44 + PU L#44 (P#44)
      L2 L#45 (1024KB) + L1d L#45 (64KB) + L1i L#45 (64KB) + Core L#45 + PU L#45 (P#45)
      L2 L#46 (1024KB) + L1d L#46 (64KB) + L1i L#46 (64KB) + Core L#46 + PU L#46 (P#46)
      L2 L#47 (1024KB) + L1d L#47 (64KB) + L1i L#47 (64KB) + Core L#47 + PU L#47 (P#47)
      L2 L#48 (1024KB) + L1d L#48 (64KB) + L1i L#48 (64KB) + Core L#48 + PU L#48 (P#48)
      L2 L#49 (1024KB) + L1d L#49 (64KB) + L1i L#49 (64KB) + Core L#49 + PU L#49 (P#49)
      L2 L#50 (1024KB) + L1d L#50 (64KB) + L1i L#50 (64KB) + Core L#50 + PU L#50 (P#50)
      L2 L#51 (1024KB) + L1d L#51 (64KB) + L1i L#51 (64KB) + Core L#51 + PU L#51 (P#51)
      L2 L#52 (1024KB) + L1d L#52 (64KB) + L1i L#52 (64KB) + Core L#52 + PU L#52 (P#52)
      L2 L#53 (1024KB) + L1d L#53 (64KB) + L1i L#53 (64KB) + Core L#53 + PU L#53 (P#53)
      L2 L#54 (1024KB) + L1d L#54 (64KB) + L1i L#54 (64KB) + Core L#54 + PU L#54 (P#54)
      L2 L#55 (1024KB) + L1d L#55 (64KB) + L1i L#55 (64KB) + Core L#55 + PU L#55 (P#55)
      L2 L#56 (1024KB) + L1d L#56 (64KB) + L1i L#56 (64KB) + Core L#56 + PU L#56 (P#56)
      L2 L#57 (1024KB) + L1d L#57 (64KB) + L1i L#57 (64KB) + Core L#57 + PU L#57 (P#57)
      L2 L#58 (1024KB) + L1d L#58 (64KB) + L1i L#58 (64KB) + Core L#58 + PU L#58 (P#58)
      L2 L#59 (1024KB) + L1d L#59 (64KB) + L1i L#59 (64KB) + Core L#59 + PU L#59 (P#59)
      L2 L#60 (1024KB) + L1d L#60 (64KB) + L1i L#60 (64KB) + Core L#60 + PU L#60 (P#60)
      L2 L#61 (1024KB) + L1d L#61 (64KB) + L1i L#61 (64KB) + Core L#61 + PU L#61 (P#61)
      L2 L#62 (1024KB) + L1d L#62 (64KB) + L1i L#62 (64KB) + Core L#62 + PU L#62 (P#62)
      L2 L#63 (1024KB) + L1d L#63 (64KB) + L1i L#63 (64KB) + Core L#63 + PU L#63 (P#63)
    HostBridge L#0
      PCIBridge
        PCIBridge
          PCI 1a03:2000
            GPU L#0 "controlD64"
            GPU L#1 "card0"
      PCIBridge
        PCI 1b4b:9235
    HostBridge L#4
      PCI 1ded:8001
      PCI 1ded:8003
  NUMANode L#1 (P#1 504GB)
    L3 L#1 (64MB)
      L2 L#64 (1024KB) + L1d L#64 (64KB) + L1i L#64 (64KB) + Core L#64 + PU L#64 (P#64)
      L2 L#65 (1024KB) + L1d L#65 (64KB) + L1i L#65 (64KB) + Core L#65 + PU L#65 (P#65)
      L2 L#66 (1024KB) + L1d L#66 (64KB) + L1i L#66 (64KB) + Core L#66 + PU L#66 (P#66)
      L2 L#67 (1024KB) + L1d L#67 (64KB) + L1i L#67 (64KB) + Core L#67 + PU L#67 (P#67)
      L2 L#68 (1024KB) + L1d L#68 (64KB) + L1i L#68 (64KB) + Core L#68 + PU L#68 (P#68)
      L2 L#69 (1024KB) + L1d L#69 (64KB) + L1i L#69 (64KB) + Core L#69 + PU L#69 (P#69)
      L2 L#70 (1024KB) + L1d L#70 (64KB) + L1i L#70 (64KB) + Core L#70 + PU L#70 (P#70)
      L2 L#71 (1024KB) + L1d L#71 (64KB) + L1i L#71 (64KB) + Core L#71 + PU L#71 (P#71)
      L2 L#72 (1024KB) + L1d L#72 (64KB) + L1i L#72 (64KB) + Core L#72 + PU L#72 (P#72)
      L2 L#73 (1024KB) + L1d L#73 (64KB) + L1i L#73 (64KB) + Core L#73 + PU L#73 (P#73)
      L2 L#74 (1024KB) + L1d L#74 (64KB) + L1i L#74 (64KB) + Core L#74 + PU L#74 (P#74)
      L2 L#75 (1024KB) + L1d L#75 (64KB) + L1i L#75 (64KB) + Core L#75 + PU L#75 (P#75)
      L2 L#76 (1024KB) + L1d L#76 (64KB) + L1i L#76 (64KB) + Core L#76 + PU L#76 (P#76)
      L2 L#77 (1024KB) + L1d L#77 (64KB) + L1i L#77 (64KB) + Core L#77 + PU L#77 (P#77)
      L2 L#78 (1024KB) + L1d L#78 (64KB) + L1i L#78 (64KB) + Core L#78 + PU L#78 (P#78)
      L2 L#79 (1024KB) + L1d L#79 (64KB) + L1i L#79 (64KB) + Core L#79 + PU L#79 (P#79)
      L2 L#80 (1024KB) + L1d L#80 (64KB) + L1i L#80 (64KB) + Core L#80 + PU L#80 (P#80)
      L2 L#81 (1024KB) + L1d L#81 (64KB) + L1i L#81 (64KB) + Core L#81 + PU L#81 (P#81)
      L2 L#82 (1024KB) + L1d L#82 (64KB) + L1i L#82 (64KB) + Core L#82 + PU L#82 (P#82)
      L2 L#83 (1024KB) + L1d L#83 (64KB) + L1i L#83 (64KB) + Core L#83 + PU L#83 (P#83)
      L2 L#84 (1024KB) + L1d L#84 (64KB) + L1i L#84 (64KB) + Core L#84 + PU L#84 (P#84)
      L2 L#85 (1024KB) + L1d L#85 (64KB) + L1i L#85 (64KB) + Core L#85 + PU L#85 (P#85)
      L2 L#86 (1024KB) + L1d L#86 (64KB) + L1i L#86 (64KB) + Core L#86 + PU L#86 (P#86)
      L2 L#87 (1024KB) + L1d L#87 (64KB) + L1i L#87 (64KB) + Core L#87 + PU L#87 (P#87)
      L2 L#88 (1024KB) + L1d L#88 (64KB) + L1i L#88 (64KB) + Core L#88 + PU L#88 (P#88)
      L2 L#89 (1024KB) + L1d L#89 (64KB) + L1i L#89 (64KB) + Core L#89 + PU L#89 (P#89)
      L2 L#90 (1024KB) + L1d L#90 (64KB) + L1i L#90 (64KB) + Core L#90 + PU L#90 (P#90)
      L2 L#91 (1024KB) + L1d L#91 (64KB) + L1i L#91 (64KB) + Core L#91 + PU L#91 (P#91)
      L2 L#92 (1024KB) + L1d L#92 (64KB) + L1i L#92 (64KB) + Core L#92 + PU L#92 (P#92)
      L2 L#93 (1024KB) + L1d L#93 (64KB) + L1i L#93 (64KB) + Core L#93 + PU L#93 (P#93)
      L2 L#94 (1024KB) + L1d L#94 (64KB) + L1i L#94 (64KB) + Core L#94 + PU L#94 (P#94)
      L2 L#95 (1024KB) + L1d L#95 (64KB) + L1i L#95 (64KB) + Core L#95 + PU L#95 (P#95)
      L2 L#96 (1024KB) + L1d L#96 (64KB) + L1i L#96 (64KB) + Core L#96 + PU L#96 (P#96)
      L2 L#97 (1024KB) + L1d L#97 (64KB) + L1i L#97 (64KB) + Core L#97 + PU L#97 (P#97)
      L2 L#98 (1024KB) + L1d L#98 (64KB) + L1i L#98 (64KB) + Core L#98 + PU L#98 (P#98)
      L2 L#99 (1024KB) + L1d L#99 (64KB) + L1i L#99 (64KB) + Core L#99 + PU L#99 (P#99)
      L2 L#100 (1024KB) + L1d L#100 (64KB) + L1i L#100 (64KB) + Core L#100 + PU L#100 (P#100)
      L2 L#101 (1024KB) + L1d L#101 (64KB) + L1i L#101 (64KB) + Core L#101 + PU L#101 (P#101)
      L2 L#102 (1024KB) + L1d L#102 (64KB) + L1i L#102 (64KB) + Core L#102 + PU L#102 (P#102)
      L2 L#103 (1024KB) + L1d L#103 (64KB) + L1i L#103 (64KB) + Core L#103 + PU L#103 (P#103)
      L2 L#104 (1024KB) + L1d L#104 (64KB) + L1i L#104 (64KB) + Core L#104 + PU L#104 (P#104)
      L2 L#105 (1024KB) + L1d L#105 (64KB) + L1i L#105 (64KB) + Core L#105 + PU L#105 (P#105)
      L2 L#106 (1024KB) + L1d L#106 (64KB) + L1i L#106 (64KB) + Core L#106 + PU L#106 (P#106)
      L2 L#107 (1024KB) + L1d L#107 (64KB) + L1i L#107 (64KB) + Core L#107 + PU L#107 (P#107)
      L2 L#108 (1024KB) + L1d L#108 (64KB) + L1i L#108 (64KB) + Core L#108 + PU L#108 (P#108)
      L2 L#109 (1024KB) + L1d L#109 (64KB) + L1i L#109 (64KB) + Core L#109 + PU L#109 (P#109)
      L2 L#110 (1024KB) + L1d L#110 (64KB) + L1i L#110 (64KB) + Core L#110 + PU L#110 (P#110)
      L2 L#111 (1024KB) + L1d L#111 (64KB) + L1i L#111 (64KB) + Core L#111 + PU L#111 (P#111)
      L2 L#112 (1024KB) + L1d L#112 (64KB) + L1i L#112 (64KB) + Core L#112 + PU L#112 (P#112)
      L2 L#113 (1024KB) + L1d L#113 (64KB) + L1i L#113 (64KB) + Core L#113 + PU L#113 (P#113)
      L2 L#114 (1024KB) + L1d L#114 (64KB) + L1i L#114 (64KB) + Core L#114 + PU L#114 (P#114)
      L2 L#115 (1024KB) + L1d L#115 (64KB) + L1i L#115 (64KB) + Core L#115 + PU L#115 (P#115)
      L2 L#116 (1024KB) + L1d L#116 (64KB) + L1i L#116 (64KB) + Core L#116 + PU L#116 (P#116)
      L2 L#117 (1024KB) + L1d L#117 (64KB) + L1i L#117 (64KB) + Core L#117 + PU L#117 (P#117)
      L2 L#118 (1024KB) + L1d L#118 (64KB) + L1i L#118 (64KB) + Core L#118 + PU L#118 (P#118)
      L2 L#119 (1024KB) + L1d L#119 (64KB) + L1i L#119 (64KB) + Core L#119 + PU L#119 (P#119)
      L2 L#120 (1024KB) + L1d L#120 (64KB) + L1i L#120 (64KB) + Core L#120 + PU L#120 (P#120)
      L2 L#121 (1024KB) + L1d L#121 (64KB) + L1i L#121 (64KB) + Core L#121 + PU L#121 (P#121)
      L2 L#122 (1024KB) + L1d L#122 (64KB) + L1i L#122 (64KB) + Core L#122 + PU L#122 (P#122)
      L2 L#123 (1024KB) + L1d L#123 (64KB) + L1i L#123 (64KB) + Core L#123 + PU L#123 (P#123)
      L2 L#124 (1024KB) + L1d L#124 (64KB) + L1i L#124 (64KB) + Core L#124 + PU L#124 (P#124)
      L2 L#125 (1024KB) + L1d L#125 (64KB) + L1i L#125 (64KB) + Core L#125 + PU L#125 (P#125)
      L2 L#126 (1024KB) + L1d L#126 (64KB) + L1i L#126 (64KB) + Core L#126 + PU L#126 (P#126)
      L2 L#127 (1024KB) + L1d L#127 (64KB) + L1i L#127 (64KB) + Core L#127 + PU L#127 (P#127)
    HostBridge L#5
      PCIBridge
        PCI 8086:0b60
    HostBridge L#7
      PCIBridge
        PCIBridge
          PCIBridge
            PCI 1af4:1001
          PCIBridge
            PCI 1ded:1001
            PCI ffff:ffff
```



## 总结

希望通过具体又不同的CPU案例展示，让你对CPU的结构有一些整体认识

请问：Hygon C86 7260 这块CPU每个Die的L2、L3分别是多大？



请思考，最近10年CPU的性能没啥大的进不了(如下图红色部分，每年3%)，但是这么多年工艺还在进步，集成的晶体管数量

![img](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/FvXLnPB8aqT7iJJuKdMfc_rpypsa.jpeg)

//这张图每一本计算机体系结构的教材都有引用(没有的话这教材可以扔了)，你知道我博客里哪篇文章放了这图吗？从这个图你还能解析出来哪些东西？