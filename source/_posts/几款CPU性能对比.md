---
title: Intel、海光、鲲鹏920、飞腾2500 CPU性能对比
date: 2021-06-18 17:30:03
categories:
    - CPU
tags:
    - Linux
    - CPU
    - 海光
    - 飞腾
    - Intel
---

# Intel 海光 鲲鹏920 飞腾2500 CPU性能对比

为了让程序能快点，特意了解了CPU的各种原理，比如多核、超线程、NUMA、睿频、功耗、GPU、大小核再到分支预测、cache_line失效、加锁代价、IPC等各种指标（都有对应的代码和测试数据）都会在这系列文章中得到答案。当然一定会有程序员最关心的分支预测案例、Disruptor无锁案例、cache_line伪共享案例等等。

这次让我们从最底层的沙子开始用8篇文章来回答各种疑问以及大量的实验对比案例和测试数据。



大的方面主要是从这几个疑问来写这些文章：

- 同样程序为什么CPU跑到800%还不如CPU跑到200%快？
- IPC背后的原理和和程序效率的关系？
- 为什么数据库领域都爱把NUMA关了，这对吗？
- 几个国产芯片的性能到底怎么样？

## 系列文章

[CPU的制造和概念](https://plantegg.github.io/2021/06/01/CPU的制造和概念/)

[Perf IPC以及CPU性能](https://plantegg.github.io/2021/05/16/Perf IPC以及CPU利用率/)

[CPU 性能和Cache Line](https://plantegg.github.io/2021/05/16/CPU Cache Line 和性能/)

[十年后数据库还是不敢拥抱NUMA？](https://plantegg.github.io/2021/05/14/十年后数据库还是不敢拥抱NUMA/)

[Intel PAUSE指令变化是如何影响自旋锁以及MySQL的性能的](https://plantegg.github.io/2019/12/16/Intel PAUSE指令变化是如何影响自旋锁以及MySQL的性能的/)

[Intel、海光、鲲鹏920、飞腾2500 CPU性能对比](https://plantegg.github.io/2021/06/18/几款CPU性能对比/)

[一次海光物理机资源竞争压测的记录](https://plantegg.github.io/2021/03/07/一次海光物理机资源竞争压测的记录/)

[飞腾ARM芯片(FT2500)的性能测试](https://plantegg.github.io/2021/05/15/飞腾ARM芯片(FT2500)的性能测试/)



本篇是收尾篇，横向对比一下x86和ARM芯片，以及不同方案权衡下的性能比较

## CPU基本信息

### 海光

```
#lscpu
Architecture:          x86_64
CPU op-mode(s):        32-bit, 64-bit
Byte Order:            Little Endian
CPU(s):                64
On-line CPU(s) list:   0-63
Thread(s) per core:    2      //每个物理core有两个超线程
Core(s) per socket:    16     //每路16个物理core
Socket(s):             2      //2路
NUMA node(s):          4
Vendor ID:             HygonGenuine
CPU family:            24
Model:                 1
Model name:            Hygon C86 5280 16-core Processor
Stepping:              1
CPU MHz:               2455.552
CPU max MHz:           2500.0000
CPU min MHz:           1600.0000
BogoMIPS:              4999.26
Virtualization:        AMD-V
L1d cache:             32K
L1i cache:             64K
L2 cache:              512K
L3 cache:              8192K
NUMA node0 CPU(s):     0-7,32-39
NUMA node1 CPU(s):     8-15,40-47
NUMA node2 CPU(s):     16-23,48-55
NUMA node3 CPU(s):     24-31,56-63
Flags:                 fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush mmx fxsr sse sse2 ht syscall nx mmxext fxsr_opt pdpe1gb rdtscp lm constant_tsc rep_good nopl nonstop_tsc cpuid extd_apicid amd_dcm aperfmperf pni pclmulqdq monitor ssse3 fma cx16 sse4_1 sse4_2 movbe popcnt xsave avx f16c rdrand lahf_lm cmp_legacy svm extapic cr8_legacy abm sse4a misalignsse 3dnowprefetch osvw skinit wdt tce topoext perfctr_core perfctr_nb bpext perfctr_llc mwaitx cpb hw_pstate sme ssbd sev ibpb vmmcall fsgsbase bmi1 avx2 smep bmi2 MySQLeed adx smap clflushopt sha_ni xsaveopt xsavec xgetbv1 xsaves clzero irperf xsaveerptr arat npt lbrv svm_lock nrip_save tsc_scale vmcb_clean flushbyasid decodeassists pausefilter pfthreshold avic v_vmsave_vmload vgif overflow_recov succor smca

#numactl -H
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

这CPU据说是胶水核，也就是把两个die拼一块封装成一块CPU，所以一块CPU内跨die之间延迟还是很高的。

####  64 个 core 的分配策略

```
physical         core      processor
0                0~15         0~15
1                0~15         16~31
0                0~15         32~47
1                0~15         48~63
```

### Intel CPU

```
#lscpu
Architecture:          x86_64
CPU op-mode(s):        32-bit, 64-bit
Byte Order:            Little Endian
CPU(s):                104
On-line CPU(s) list:   0-103
Thread(s) per core:    2
Core(s) per socket:    26
座：                 2
NUMA 节点：         1
厂商 ID：           GenuineIntel
CPU 系列：          6
型号：              85
型号名称：        Intel(R) Xeon(R) Platinum 8269CY CPU @ 2.50GHz
步进：              7
CPU MHz：             1200.000
CPU max MHz:           2501.0000
CPU min MHz:           1200.0000
BogoMIPS：            5000.00
虚拟化：           VT-x
L1d 缓存：          32K
L1i 缓存：          32K
L2 缓存：           1024K
L3 缓存：           36608K
NUMA 节点0 CPU：    0-103
Flags:                 fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc art arch_perfmon pebs bts rep_good nopl xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 sdbg fma cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic movbe popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm abm 3dnowprefetch epb cat_l3 cdp_l3 intel_ppin intel_pt ssbd mba ibrs ibpb stibp ibrs_enhanced tpr_shadow vnmi flexpriority ept vpid fsgsbase tsc_adjust bmi1 hle avx2 smep bmi2 erms invpcid rtm cqm mpx rdt_a avx512f avx512dq rdseed adx smap clflushopt clwb avx512cd avx512bw avx512vl xsaveopt xsavec xgetbv1 cqm_llc cqm_occup_llc cqm_mbm_total cqm_mbm_local dtherm ida arat pln pts pku ospke avx512_vnni spec_ctrl intel_stibp flush_l1d arch_capabilities

# numactl -H
available: 1 nodes (0)
node 0 cpus: 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69 70 71 72 73 74 75 76 77 78 79 80 81 82 83 84 85 86 87 88 89 90 91 92 93 94 95 96 97 98 99 100 101 102 103
node 0 size: 785826 MB
node 0 free: 108373 MB
node distances:
node   0
  0:  10  
```

### 鲲鹏920

```
#lscpu
Architecture:          aarch64
Byte Order:            Little Endian
CPU(s):                96
On-line CPU(s) list:   0-95
Thread(s) per core:    1
Core(s) per socket:    48
Socket(s):             2
NUMA node(s):          1
Model:                 0
CPU max MHz:           2600.0000
CPU min MHz:           200.0000
BogoMIPS:              200.00
L1d cache:             64K
L1i cache:             64K
L2 cache:              512K
L3 cache:              49152K
NUMA node0 CPU(s):     0-95
Flags:                 fp asimd evtstrm aes pmull sha1 sha2 crc32 atomics fphp asimdhp cpuid asimdrdm jscvt fcma dcpop asimddp asimdfhm

#numactl -H
available: 4 nodes (0-3)
node 0 cpus: 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23
node 0 size: 192832 MB
node 0 free: 187693 MB
node 1 cpus: 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47
node 1 size: 193533 MB
node 1 free: 191827 MB
node 2 cpus: 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69 70 71
node 2 size: 193533 MB
node 2 free: 192422 MB
node 3 cpus: 72 73 74 75 76 77 78 79 80 81 82 83 84 85 86 87 88 89 90 91 92 93 94 95
node 3 size: 193532 MB
node 3 free: 193139 MB
node distances:
node   0   1   2   3
  0:  10  12  20  22
  1:  12  10  22  24
  2:  20  22  10  12
  3:  22  24  12  10

#dmidecode -t processor | grep Version
	Version: Kunpeng 920-4826
	Version: Kunpeng 920-4826  
```

### 飞腾2500

```
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
```

## openssl speed aes-256-ige性能比较

测试脚本

> openssl speed aes-256-ige -multi 1

单核能力

| Intel (52物理core)   | aes-256 ige      89602.86k    97498.37k    98271.49k    98399.91k    89101.65k |
| -------------------- | ------------------------------------------------------------ |
| 海光（32物理core）   | aes-256 ige      76919.66k    77935.81k    79201.88k    79529.30k    79555.24k |
| 鲲鹏920（96物理core) | aes-256 ige     133174.89k   140578.99k   142156.46k   142663.34k   143196.16k |

测试32个线程并行

| Intel (52物理core)   | aes-256 ige    2642742.25k  2690638.98k  2703860.74k  2734114.82k  2680422.40 |
| -------------------- | ------------------------------------------------------------ |
| 海光（32物理core）   | aes-256 ige    2464568.75k  2499381.80k  2528665.34k  2544845.14k  2550723.93k |
| 鲲鹏920（96物理core) | aes-256 ige    4261589.92k  4501245.55k  4552731.56k  4570456.75k  4584330.58k |

将所有核跑满包括HT

| Intel (52物理core)   | aes-256 ige    4869950.82k  5179884.71k  5135412.14k  5211367.08k  5247858.60k |
| -------------------- | ------------------------------------------------------------ |
| 海光（32物理core）   | aes-256 ige    2730195.74k  2836759.53k  2865252.35k  2857900.71k  2884302.17k |
| 鲲鹏920（96物理core) | aes-256 ige   12788358.79k 13502288.53k 13657385.98k 13710908.76k 13751432.53k |

## 单核计算 7^999999" 的性能对比

测试命令：bash -c 'echo "7^999999" | bc > /dev/null'

|          | 执行时间(秒) | IPC  | 主频 |
| -------- | ------------ | ---- | ---- |
| 海光     | 26.729972414 | 0.92 | 2.5G |
| 鲲鹏920  | 24.604603640 | 1.84 | 2.6G |
| 飞腾2500 | 39.654819568 | 0.43 | 2.1G |
| Intel    | 18.603323495 | 2.19 | 2.5G |

当然也可以通过计算pi值来测试

> bash -c ' echo "scale=5000; 4*a(1)" | bc -l -q >/dev/null '

多核一起跑的话可以这样:

> for i in {0..95}; do time echo "scale=5000; 4*a(1)" | bc -l -q >/dev/null & done
>
> perf stat -e branch-misses,bus-cycles,cache-misses,cache-references,cpu-cycles,instructions,stalled-cycles-backend,stalled-cycles-frontend,L1-dcache-load-misses,L1-dcache-loads,L1-dcache-store-misses,L1-dcache-stores,L1-icache-load-misses,L1-icache-loads,branch-load-misses,branch-loads,dTLB-load-misses,dTLB-loads,iTLB-load-misses,iTLB-loads -- 

### intel

耗时18.60秒，ipc 2.19

```
# sudo perf stat -e branch-instructions,branch-misses,bus-cycles,cache-misses,cache-references,cpu-cycles,instructions,ref-cycles,L1-dcache-load-misses,L1-dcache-loads,L1-dcache-stores,L1-icache-load-misses,LLC-load-misses,LLC-loads,LLC-store-misses,LLC-stores,branch-load-misses,branch-loads,dTLB-load-misses,dTLB-loads,dTLB-store-misses,dTLB-stores,iTLB-load-misses,iTLB-loads,node-load-misses,node-loads,node-store-misses,node-stores -- bash -c 'echo "7^999999" | bc > /dev/null'

 Performance counter stats for 'bash -c echo "7^999999" | bc > /dev/null':

    25,130,886,211      branch-instructions                                           (10.72%)
     1,200,086,175      branch-misses             #    4.78% of all branches          (14.29%)
       460,824,074      bus-cycles                                                    (14.29%)
         1,983,459      cache-misses              #   46.066 % of all cache refs      (14.30%)
         4,305,730      cache-references                                              (14.30%)
    58,626,314,801      cpu-cycles                                                    (17.87%)
   128,284,870,917      instructions              #    2.19  insn per cycle           (21.45%)
    46,040,656,499      ref-cycles                                                    (25.02%)
        22,821,794      L1-dcache-load-misses     #    0.10% of all L1-dcache hits    (25.02%)
    23,041,732,649      L1-dcache-loads                                               (25.01%)
     5,386,243,625      L1-dcache-stores                                              (25.00%)
        12,443,154      L1-icache-load-misses                                         (25.00%)
           178,790      LLC-load-misses           #   30.52% of all LL-cache hits     (14.28%)
           585,724      LLC-loads                                                     (14.28%)
           469,381      LLC-store-misses                                              (7.14%)
           664,865      LLC-stores                                                    (7.14%)
     1,201,547,113      branch-load-misses                                            (10.71%)
    25,139,625,428      branch-loads                                                  (14.28%)
            63,334      dTLB-load-misses          #    0.00% of all dTLB cache hits   (14.28%)
    23,023,969,089      dTLB-loads                                                    (14.28%)
            17,355      dTLB-store-misses                                             (14.28%)
     5,378,496,562      dTLB-stores                                                   (14.28%)
           341,119      iTLB-load-misses          #  119.92% of all iTLB cache hits   (14.28%)
           284,445      iTLB-loads                                                    (14.28%)
           151,608      node-load-misses                                              (14.28%)
            37,553      node-loads                                                    (14.29%)
           434,537      node-store-misses                                             (7.14%)
            65,709      node-stores                                                   (7.14%)

      18.603323495 seconds time elapsed

      18.525904000 seconds user
       0.015197000 seconds sys

```

### 鲲鹏920

耗时24.6秒, IPC 1.84

```
#perf stat -e branch-misses,bus-cycles,cache-misses,cache-references,cpu-cycles,instructions,stalled-cycles-backend,stalled-cycles-frontend,L1-dcache-load-misses,L1-dcache-loads,L1-dcache-store-misses,L1-dcache-stores,L1-icache-load-misses,L1-icache-loads,branch-load-misses,branch-loads,dTLB-load-misses,dTLB-loads,iTLB-load-misses,iTLB-loads -- bash -c 'echo "7^999999" | bc > /dev/null'

 Performance counter stats for 'bash -c echo "7^999999" | bc > /dev/null':

     1,467,769,425      branch-misses                                                 (59.94%)
    63,866,536,853      bus-cycles                                                    (59.94%)
         6,571,273      cache-misses              #    0.021 % of all cache refs      (59.94%)
    30,768,754,927      cache-references                                              (59.96%)
    63,865,354,560      cpu-cycles                                                    (64.97%)
   117,790,453,518      instructions              #    1.84  insns per cycle
                                                  #    0.07  stalled cycles per insn  (64.98%)
       833,090,930      stalled-cycles-backend    #    1.30% backend  cycles idle     (65.00%)
     7,918,227,782      stalled-cycles-frontend   #   12.40% frontend cycles idle     (65.01%)
         6,962,902      L1-dcache-load-misses     #    0.02% of all L1-dcache hits    (65.03%)
    30,804,266,645      L1-dcache-loads                                               (65.05%)
         6,960,157      L1-dcache-store-misses                                        (65.06%)
    30,807,954,068      L1-dcache-stores                                              (65.06%)
         1,012,171      L1-icache-load-misses                                         (65.06%)
    45,256,066,296      L1-icache-loads                                               (65.04%)
     1,470,467,198      branch-load-misses                                            (65.03%)
    27,108,794,972      branch-loads                                                  (65.01%)
           475,707      dTLB-load-misses          #    0.00% of all dTLB cache hits   (65.00%)
    35,159,826,836      dTLB-loads                                                    (59.97%)
               912      iTLB-load-misses          #    0.00% of all iTLB cache hits   (59.96%)
    45,325,885,822      iTLB-loads                                                    (59.94%)

      24.604603640 seconds time elapsed
```

### 海光

耗时 26.73秒, IPC 0.92

```
sudo perf stat -e branch-instructions,branch-misses,cache-references,cpu-cycles,instructions,stalled-cycles-backend,stalled-cycles-frontend,L1-dcache-load-misses,L1-dcache-loads,L1-dcache-prefetches,L1-icache-load-misses,L1-icache-loads,branch-load-misses,branch-loads,dTLB-load-misses,dTLB-loads,iTLB-load-misses,iTLB-loads -a -- bash -c 'echo "7^999999" | bc > /dev/null'

 Performance counter stats for 'system wide':

    57,795,675,025      branch-instructions                                           (27.78%)
     2,459,509,459      branch-misses             #    4.26% of all branches          (27.78%)
    12,171,133,272      cache-references                                              (27.79%)
   317,353,262,523      cpu-cycles                                                    (27.79%)
   293,162,940,548      instructions              #    0.92  insn per cycle
                                                  #    0.19  stalled cycles per insn  (27.79%)
    55,152,807,029      stalled-cycles-backend    #   17.38% backend cycles idle      (27.79%)
    44,410,732,991      stalled-cycles-frontend   #   13.99% frontend cycles idle     (27.79%)
     4,065,273,083      L1-dcache-load-misses     #    3.58% of all L1-dcache hits    (27.79%)
   113,699,208,151      L1-dcache-loads                                               (27.79%)
     1,351,513,191      L1-dcache-prefetches                                          (27.79%)
     2,091,035,340      L1-icache-load-misses     #    4.43% of all L1-icache hits    (27.79%)
    47,240,289,316      L1-icache-loads                                               (27.79%)
     2,459,838,728      branch-load-misses                                            (27.79%)
    57,855,156,991      branch-loads                                                  (27.78%)
        69,731,473      dTLB-load-misses          #   20.40% of all dTLB cache hits   (27.78%)
       341,773,319      dTLB-loads                                                    (27.78%)
        26,351,132      iTLB-load-misses          #   15.91% of all iTLB cache hits   (27.78%)
       165,656,863      iTLB-loads                                                    (27.78%)

      26.729972414 seconds time elapsed
```

### 飞腾

```
time perf stat -e branch-misses,bus-cycles,cache-misses,cache-references,cpu-cycles,instructions,L1-dcache-load-misses,L1-dcache-loads,L1-dcache-store-misses,L1-dcache-stores,L1-icache-load-misses,L1-icache-loads,branch-load-misses,branch-loads,dTLB-load-misses,iTLB-load-misses -a -- bash -c 'echo "7^999999" | bc > /dev/null'

 Performance counter stats for 'system wide':

        2552812813      branch-misses                                                 (38.08%)
      602038279874      bus-cycles                                                    (37.54%)
        1742826523      cache-misses              #    2.017 % of all cache refs      (37.54%)
       86400294181      cache-references                                              (37.55%)
      612467194375      cpu-cycles                                                    (43.79%)
      263691445872      instructions              #    0.43  insns per cycle          (43.79%)
        1706247569      L1-dcache-load-misses     #    2.00% of all L1-dcache hits    (43.78%)
       85122454139      L1-dcache-loads                                               (43.77%)
        1711243358      L1-dcache-store-misses                                        (39.38%)
       86288158984      L1-dcache-stores                                              (37.52%)
        2006641212      L1-icache-load-misses                                         (37.51%)
      146380907111      L1-icache-loads                                               (37.51%)
        2560208048      branch-load-misses                                            (37.52%)
       63127187342      branch-loads                                                  (41.38%)
         768494735      dTLB-load-misses                                              (43.77%)
         124424415      iTLB-load-misses                                              (43.77%)

      39.654819568 seconds time elapsed

real	0m39.763s
user	0m39.635s
sys	0m0.127s
```

## perf 数据对比

### Intel

intel的cpu随着线程的增加，ipc稳定减少，但不是线性的

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/dcb68dff74ace2cf6f9c30378acdb377.png)

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/d0151c855011b24590efd672398bd9eb.png)

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/175a1df9274a830d4a7157dfda96c180.png)

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/e63a992fcd1df547568eb93f515a5c99.png)



### 海光

如下数据可以看到在用满32个物理core之前，ipc保持稳定，超过32core后随着兵法增加ipc相应减少，性能再也上不去了。

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/ded1ee0ed8d5d2fa3822e6fdfa4335f1.png)

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/0f2410165932835a36d8c0611877ae77.png)

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/67df9ff04209a00bd864ba21b7593477.png)

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/1bc01f6e880c7e49672170f940ff40a0.png)

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/307d30c2b3507d5561d774f96b13e67a.png)

### 鲲鹏920

可以看到**鲲鹏920多核跑openssl是没有什么争抢的，所以还能保证完全线性**

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/39720b5eb41937b462e1772854e2d832.png)

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/a98a482a10f09bccd4a6ac49fd2850b9.png)

### 小结

intel的流水线适合跑高带宽应用，不适合跑密集计算应用，也就是intel的pipeline数量少，但是内存读写上面优化好，乱序优化好。跑纯计算，不是intel的强项。

数据库场景下鲲鹏920大概相当于X86的70%的能力

prime计算一般走的fpu，不走cpu

## intel x86 cpu bound和memory bond数据

测试代码

```
#include <stdlib.h>
#include <emmintrin.h>
#include <stdio.h>
#include <signal.h>

char a = 1;

void memory_bound() {
        register unsigned i=0;
        register char b;

        for (i=0;i<(1u<<24);i++) {
                // evict cacheline containing a
                 _mm_clflush(&a);
                 b = a;
        }
}
void cpu_bound() {
        register unsigned i=0;
        for (i=0;i<(1u<<31);i++) {
                __asm__ ("nop\nnop\nnop");
        }
}
int main() {
        int i=0;
	      for(i=0;i<10; ++i){
	             //cpu_bound();
        	     memory_bound();
	      }
        return 0;
}
```

### **测试结果**

**cpu_bound部分飞腾只有intel性能的30%**

如下测试perf数据可以看到IPC的明显差异

```
# sudo perf stat -e branch-instructions,branch-misses,bus-cycles,cache-misses,cache-references,cpu-cycles,instructions,ref-cycles,L1-dcache-load-misses,L1-dcache-loads,L1-dcache-stores,L1-icache-load-misses,LLC-load-misses,LLC-loads,LLC-store-misses,LLC-stores,branch-load-misses,branch-loads,dTLB-load-misses,dTLB-loads,dTLB-store-misses,dTLB-stores,iTLB-load-misses,iTLB-loads,node-load-misses,node-loads,node-store-misses,node-stores -a ./memory_bound

 Performance counter stats for 'system wide':

    36,162,872,212      branch-instructions                                           (14.21%)
       586,644,153      branch-misses             #    1.62% of all branches          (12.95%)
     4,632,787,085      bus-cycles                                                    (14.40%)
       476,189,785      cache-misses              #   17.714 % of all cache refs      (14.38%)
     2,688,284,129      cache-references                                              (14.35%)
   258,946,713,506      cpu-cycles                                                    (17.93%)
   181,069,328,200      instructions              #    0.70  insn per cycle           (21.51%)
   456,889,428,341      ref-cycles                                                    (22.31%)
     3,928,434,098      L1-dcache-load-misses     #    7.46% of all L1-dcache hits    (14.21%)
    52,656,559,902      L1-dcache-loads                                               (14.31%)
    26,711,751,387      L1-dcache-stores                                              (14.30%)
     2,618,739,340      L1-icache-load-misses                                         (18.05%)
       154,326,888      LLC-load-misses           #    8.60% of all LL-cache hits     (19.84%)
     1,795,112,198      LLC-loads                                                     (9.81%)
        66,802,375      LLC-store-misses                                              (10.19%)
       206,810,811      LLC-stores                                                    (11.16%)
       586,120,789      branch-load-misses                                            (14.28%)
    36,121,237,395      branch-loads                                                  (14.29%)
       114,927,298      dTLB-load-misses          #    0.22% of all dTLB cache hits   (14.29%)
    52,902,163,128      dTLB-loads                                                    (14.29%)
         7,010,297      dTLB-store-misses                                             (14.29%)
    26,587,353,417      dTLB-stores                                                   (18.00%)
       106,209,281      iTLB-load-misses          #  174.17% of all iTLB cache hits   (19.33%)
        60,978,626      iTLB-loads                                                    (21.53%)
       117,197,042      node-load-misses                                              (19.71%)
        35,764,508      node-loads                                                    (11.65%)
        57,655,994      node-store-misses                                             (7.80%)
        11,563,328      node-stores                                                   (9.45%)

      16.700731355 seconds time elapsed
      
# sudo perf stat -e branch-instructions,branch-misses,bus-cycles,cache-misses,cache-references,cpu-cycles,instructions,ref-cycles,L1-dcache-load-misses,L1-dcache-loads,L1-dcache-stores,L1-icache-load-misses,LLC-load-misses,LLC-loads,LLC-store-misses,LLC-stores,branch-load-misses,branch-loads,dTLB-load-misses,dTLB-loads,dTLB-store-misses,dTLB-stores,iTLB-load-misses,iTLB-loads,node-load-misses,node-loads,node-store-misses,node-stores -a ./cpu_bound

 Performance counter stats for 'system wide':

    43,013,055,562      branch-instructions                                           (14.33%)
       436,722,063      branch-misses             #    1.02% of all branches          (11.58%)
     3,154,327,457      bus-cycles                                                    (14.31%)
       306,977,772      cache-misses              #   17.837 % of all cache refs      (14.42%)
     1,721,062,233      cache-references                                              (14.39%)
   176,119,834,487      cpu-cycles                                                    (17.98%)
   276,038,539,571      instructions              #    1.57  insn per cycle           (21.55%)
   309,334,354,268      ref-cycles                                                    (22.31%)
     2,551,915,790      L1-dcache-load-misses     #    6.78% of all L1-dcache hits    (13.12%)
    37,638,319,334      L1-dcache-loads                                               (14.32%)
    19,132,537,445      L1-dcache-stores                                              (15.73%)
     1,834,976,400      L1-icache-load-misses                                         (18.90%)
       131,307,343      LLC-load-misses           #   11.46% of all LL-cache hits     (19.94%)
     1,145,964,874      LLC-loads                                                     (16.60%)
        45,561,247      LLC-store-misses                                              (8.11%)
       140,236,535      LLC-stores                                                    (9.60%)
       423,294,349      branch-load-misses                                            (14.27%)
    46,645,623,485      branch-loads                                                  (14.28%)
        73,377,533      dTLB-load-misses          #    0.19% of all dTLB cache hits   (14.28%)
    37,905,428,246      dTLB-loads                                                    (15.69%)
         4,969,973      dTLB-store-misses                                             (17.21%)
    18,729,947,580      dTLB-stores                                                   (19.71%)
        72,073,313      iTLB-load-misses          #  167.86% of all iTLB cache hits   (20.60%)
        42,935,532      iTLB-loads                                                    (19.16%)
       112,306,453      node-load-misses                                              (15.35%)
        37,239,267      node-loads                                                    (7.44%)
        37,455,335      node-store-misses                                             (10.00%)
         8,134,155      node-stores                                                   (8.87%)

      10.838808208 seconds time elapsed      
```

### 飞腾

ipc 大概是intel的30%，加上主频也要差一些，

```
#time perf stat -e branch-misses,bus-cycles,cache-misses,cache-references,cpu-cycles,instructions,L1-dcache-load-misses,L1-dcache-loads,L1-dcache-store-misses,L1-dcache-stores,L1-icache-load-misses,L1-icache-loads,branch-load-misses,branch-loads,dTLB-load-misses,iTLB-load-misses -a ./cpu_bound

 Performance counter stats for 'system wide':

       10496356859      branch-misses                                                 (37.60%)
     2813170983911      bus-cycles                                                    (37.58%)
       17604745519      cache-misses              #    3.638 % of all cache refs      (37.55%)
      483878256161      cache-references                                              (37.54%)
     2818545529083      cpu-cycles                                                    (43.78%)
     1280497827941      instructions              #    0.45  insns per cycle          (43.78%)
       17623592806      L1-dcache-load-misses     #    3.65% of all L1-dcache hits    (43.78%)
      482429613337      L1-dcache-loads                                               (41.83%)
       17604561232      L1-dcache-store-misses                                        (37.53%)
      484126081882      L1-dcache-stores                                              (37.52%)
       17774514325      L1-icache-load-misses                                         (37.50%)
      641046300400      L1-icache-loads                                               (37.50%)
       10574973722      branch-load-misses                                            (39.45%)
      273851009656      branch-loads                                                  (43.76%)
        9457594390      dTLB-load-misses                                              (43.77%)
        1813954093      iTLB-load-misses                                              (43.77%)

      31.172754504 seconds time elapsed

real	0m31.284s
user	0m31.096s
sys	0m0.165s
```

## 总结

- 对纯CPU 运算场景，并发不超过物理core时，比如Prime运算，比如DRDS(CPU bound，IO在网络，可以加并发弥补)
  - 海光的IPC能保持稳定；
  - intel的IPC有所下降，但是QPS在IPC下降后还能完美线性
- 在openssl和MySQL oltp_read_only场景下
  - 如果并发没超过物理core数时，海光和Intel都能随着并发的翻倍性能能增加80%
  - 如果并发超过物理core数后，Intel还能随着并发的翻倍性能增加50%，海光增加就只有20%了
  - 简单理解在这两个场景下Intel的HT能发挥半个物理core的作用，海光的HT就只能发挥0.2个物理core的作用了
- 海光zen1的AMD 架构，每个core只有一个fpu，综上在多个场景下HT基本上都可以忽略
- 飞腾2500性能比较差

## 系列文章

[CPU的制造和概念](https://plantegg.github.io/2021/06/01/CPU的制造和概念/)

[CPU 性能和Cache Line](https://plantegg.github.io/2021/05/16/CPU Cache Line 和性能/)

[Perf IPC以及CPU性能](https://plantegg.github.io/2021/05/16/Perf IPC以及CPU利用率/)

[Intel、海光、鲲鹏920、飞腾2500 CPU性能对比](https://plantegg.github.io/2021/06/18/几款CPU性能对比/)

[飞腾ARM芯片(FT2500)的性能测试](https://plantegg.github.io/2021/05/15/飞腾ARM芯片(FT2500)的性能测试/)

[十年后数据库还是不敢拥抱NUMA？](https://plantegg.github.io/2021/05/14/十年后数据库还是不敢拥抱NUMA/)

[一次海光物理机资源竞争压测的记录](https://plantegg.github.io/2021/03/07/一次海光物理机资源竞争压测的记录/)

[Intel PAUSE指令变化是如何影响自旋锁以及MySQL的性能的](https://plantegg.github.io/2019/12/16/Intel PAUSE指令变化是如何影响自旋锁以及MySQL的性能的/)

## 参考资料

[Intel PAUSE指令变化是如何影响自旋锁以及MySQL的性能的](https://www.atatech.org/articles/157681)

[华为TaiShan服务器ARMNginx应用调优案例 大量绑核、中断、Numa等相关调优信息](https://bbs.huaweicloud.com/blogs/146367)

[主流处理器内部单核微架构细节1——AMD ZEN(即海光)微架构](https://topic.atatech.org/articles/178985)

[主流处理器内部单核微架构细节2——Skylake微架构](https://topic.atatech.org/articles/178986)