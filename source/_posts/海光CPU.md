---
title: 海光CPU
date: 2021-03-08 17:30:03
categories:
    - CPU
tags:
    - Linux
    - 超线程
    - hygon
---

# 海光CPU

### 海光物理机CPU相关信息

总共有16台如下的海光服务器

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

AMD Zen 架构的CPU是胶水核，也就是把两个die拼一块封装成一块CPU，所以一块CPU内跨die之间延迟还是很高的。

####  64 个 core 的分配策略

```
physical         core      processor
0                0~15         0~15
1                0~15         16~31
0                0~15         32~47
1                0~15         48~63
```

#### 海光bios配置

```
在grub.conf里面加入noibrs noibpb nopti nospectre_v2 nospectre_v1 l1tf=off nospec_store_bypass_disable no_stf_barrier mds=off tsx=on tsx_async_abort=off mitigations=off iommu.passthrough=1；持久化ip；挂盘参数defaults,noatime,nodiratime,lazytime,delalloc,nobarrier,data=writeback（因为后面步骤要重启，把一些OS优化也先做了）
2. bios设置里面
	配置 Hygon 设定 --- DF选项 --- 内存交错 --- Channel
								 --- NB选项 --- 关闭iommu
	打开CPB
	风扇模式设置为高性能模式
```



#### 海光简介

公司成立于2016年3月，当前送测处理器为其第一代1.0版本的7185对标处理器为Intel的E5-2680V4，其服务器样机为曙光H620-G30。

海光CPU的命名规则：
型号71xx
7：高端
1：海光1号
xx：sku

其后续roadmap如下图

![image-20221026100149808](/images/951413iMgBlog/image-20221026100149808.png)

![img](/images/951413iMgBlog/376c93772606e5e237231ede0da64c0c.png)

海光其产品规格如下，产品相对密集，但是产品之间差异化很小，频率总体接近。

![img](/images/951413iMgBlog/bad3d840f2d5017c50b77d47d4292eef.png)

AMD授权Zen IP给海光的操作是先成立合资公司，授权给合资公司基于Zen 研发新的 CPU，而且转让给中国的所有信息都符合美国出口法规**。**天津海光和AMD成立的合资公司可以修改AMD的CPU核，变相享有X86授权，而海光公司可以通过购买合资公司研发的CPU核，开发服务器CPU，不过仅仅局限于中国市场。

AMD与国内公司A成立合资公司B，合资公司B由AMD控股，负责开发CPU核（其实就是拿AMD现成的内核），然后公司A购买合资公司B开发的CPU核，以此为基础开发CPU，最终实现ARM卖IP核的翻版。

![image-20221026100539350](/images/951413iMgBlog/image-20221026100539350.png)

![image-20221026100646800](/images/951413iMgBlog/image-20221026100646800.png)

#### 海光与AMD 的 Ryzen/EPYC 比较

由于在 Zen 1 的基础上进行了大量的修改，海光 CPU 可以不用简单地称之为换壳 AMD 处理器了。但其性能相比同代原版 CPU 略差：整数性能基本相同，浮点性能显著降低——普通指令吞吐量只有基准水平的一半。海光 CPU 的随机数生成机制也被修改，加密引擎已被替换，不再对常见的 AES 指令进行加速，但覆盖了其他面向国内安全性的指令如 SM2、SM3 和 SM4。

##### 相同

与 AMD 的 Ryzen/EPYC 相比，海光处理器究竟有哪些不同？总体而言，核心布局是相同的，缓存大小、TLB 大小和端口分配都相同，在基础级别上两者没有差异。CPU 仍然是 64KB 四路 L1 指令缓存，32KB 八路 L1 数据缓存，512KB 八路 L2 缓存以及 8MB 十六路 L3 缓存，与 Zen 1 核心完全相同。

##### 不同

**加密方式变化**

在 Linux 内核升级中有关加密变化的信息已经明示。这些更新围绕 AMD 虚拟化功能（SEV）的安全加密进行。通常对于 EPYC 处理器来说，SEV 由 AMD 定义的加密协议控制，在这种情况下为 RSA、ECDSA、ECDH、SHA 和 AES。

但在海光 Dhyana 处理器中，SEV 被设计为使用 SM2、SM3 和 SM4 算法。在更新中有关 SM2 的部分声明道，这种算法基于椭圆曲线加密法，且需要其他私钥/公钥交换；SM3 是一种哈希算法，类似于 SHA-256；而 SM4 是类似于 AES-128 的分组密码算法。为支持这些算法所需的额外功能，其他指令也被加入到了 Linux 内核中。在说明文件中指出，这些算法已在 Hygon Dhyana Plus 处理器上成功进行测试，也已在 AMD 的 EPYC CPU 上成功测试。

此外，海光与 AMD 原版芯片最大的设计区别在于**吞吐**量，尽管整数性能相同，但海光芯片对于某些浮点指令并未做流水线处理，这意味着吞吐量和延迟都减小了：

![img](/images/951413iMgBlog/640-6077478.jpeg)

这些对于最基础的任务来说也会有所影响，降低吞吐量的设计会让 CPU 在并行计算时性能受限。另外一个最大的变化，以及 Dhyana 与服务器版的「Dhyana Plus」版本之间的不同在于随机数生成的能力。