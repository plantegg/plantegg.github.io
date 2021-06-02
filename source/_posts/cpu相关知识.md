---
title: cpu相关知识
date: 2020-05-11 17:30:03
categories:
    - performance
tags:
    - Linux
    - CPU
    - arm
    - x86
    - perf
    - IPC
---

# cpu相关知识

## 指令集

美国的Sun（1982年成立，早期使用摩托罗拉公司芯片，现已被Oracle收购）、日本Fujitsu（富士通）等公司的小型机是基于SPARC处理器架构（该处理器由1985年Sun公司研制，现在Oracle已放弃了SPARCE转用Intel Xeon）,而美国HP公司的则是基于PA-RISC架构，后基于Itanium ，而最新的SuperdomeX也基于Intel Xeon；Compaq公司是Alpha架构。

最开始都是CISC，不同长度的指令能够节省存储空间等

精简指令集RISC(Reduced Instruction Set Computer)和复杂指令集CISC(Complex Instruction Set Computer)的区分是从上个世纪70年代开始的，IBM研究关于CPU如何高效的运行，发现有些常用的指令占比很高。20%的指令完成了80%的工作。

![img](/images/951413iMgBlog/35161ebe1d0b571845c1904abaafa604.png)

把CPU从硬件上设计简单一点，从而使得软件上高效一点，这样就提出了精简指令集这个概念，其最大的特点就是它的**指令宽度是相等的**，每个指令执行的周期几乎也相同，这样把复杂的指令简单化，最后用简单的操作去完成一件复杂的任务。

而复杂指令集(CISC)每一个**指令的长度是不同的，导致机器码、指令码不同，导致每条指令的执行周期不同，从而使得软件流水操作上处理的步骤不一样的**。这样的一个好处是一个指令就能完成一个比较复杂的事情，对上层的程序员来讲，会容易理解一些，特别是汇编程序员。

### RISC(Reduced Instruction Set Computer)特点

​    RISC的主要特点如下:

- 简单、基本的指令:通过简单、基本的指令，组合成复杂指令。
- 同样长度的指令：每条指令的长度都是相同的，可以在一个单独操作里完成。
- 单机器周期指令(易流水线)：大多数的指令都可以在一个机器周期里完成，并且允许处理器在同一时间内执行一系列的指令。便于流水线操作执行。
- 更多的通用寄存器:例如ARM处理器具有31个通用寄存器。大多数数据操作都在寄存器中完成
- 寻址方式简化:由于指令长度固定，指令格式和寻址方式种类减少。
- Load/Store结构:使用load/store指令批量从内存中读写数据，数据传输效率高；
- 体积小，低功耗，低成本;

​    从RISC的特点，我们可以得到RISC体系的优缺点,其实当前很多底层技术相互之间在不断融合，所以以下也只能参考了:

​     优点：在使用相同的芯片技术和相同运行时钟下，RISC 系统的运行速度将是 CISC 的2～4倍。由于RISC处理器的指令集是精简的，所以内存管理单元、浮点单元等都能更容易的设计在同一块芯片上。RISC处理器比相对应的 CISC处理器设计更简单，开发设计周期更短，可以比CISC处理器应用更多先进的技术，更快迭代的下一代处理器。

​     缺点：更多指令的操作使得程序开发者必须小心地选用合适的编译器，编写的代码量会变得非常大。另外RISC体系的处理器需要更快的存储器，这通常都集成于处理器内部(现在处理器当前都有CACHE的)。

### CISC(Complex instruction set computer)

​    复杂指令集(CISC)是伴随着计算机诞生便存在的指令集，拥有较强的处理高级语言的能力，对于提高计算机性能有一定好处。但是日趋复杂的指令系统带来了效率的低下，使系统结构的复杂性增加，也将导致了CISC的通用性不佳。从指令集架构来看，Intel也承认，CISC架构确实限制了CPU的发展。

​    CISC体系的指令特征如下，

- 使用微代码，指令集可以直接在微代码存储器(比主存储器的速度快很多)里执行。
- 庞大的指令集，可以减少编程所需要的代码行数，减轻程序员的负担。包括双运算元格式、寄存器到寄存器、寄存器到存储器以及存储器到寄存器的指令。

​    指令特征也直接显现了CISC体系的优缺点:

​    **优点：**可有效缩短新指令的微代码设计时间，允许设计师实现 CISC 体系机器的向上兼容。新的系统可以使用一个包含早期系统的指令超集合。另外微程序指令的格式与高级语言相匹配，因而编译器并不一定要重新编写。

​    **缺点：**指令集以及芯片的设计比上一代产品更复杂，不同的指令，需要不同的时钟周期来完成，执行较慢的指令，将影响整台机器的执行效率。

目前X86指令集通用寄存器组(CPU的内核)有16个通用寄存器(rax, rbx, rcx, rdx, rbp, rsp, rsi, rdi, r8, r9, r10, r11, r12, r13, r14, r15),与ARM的31个通用寄存器比起来是少了近一半。X86 CPU复杂指令执行时大多数时间是访问存储器中的数据，会直接拖慢指令执行速度。

X86处理器特有解码器(Decode Unit)，把长度不定的x86指令转换为长度固定的类似于RISC的指令，并交给RISC内核。解码分为硬件解码和微解码，**对于简单的x86指令只要硬件解码即可，速度较快，但复杂的x86指令则需要进行微解码，并把它分成若干条简单指令，速度较慢且很复杂。X86指令集严重制约了性能表现**。

 x86 需要将一些工位拆开（这意味着流水线工位更多或者流水线长度更深）。流水线设计可以让指令完成时间更短（理论上受限于流水线执行时间最长的工位），因此将一些工位再拆开的话，虽然依然是每个周期完成一条指令，但是“周期”更短意味着指令吞吐时间进一步缩短，每秒能跑出来的指令数更多，这就是超级流水线的初衷。

#### AMD64

因为AMD知道自己造不出能与IA64兼容的处理器，于是它把x86扩展一下，加入了64位寻址和64位寄存器。最终出来的架构，就是 AMD64，成为了64位版本的x86处理器的标准。这一次AMD又交了一个满分答卷。

也就是64位的x86是AMD做出来的，所以经常看到AMD64、X86_64这种叫法。Intel最早是和惠普合作的安腾64位芯片 IA64，不兼容X86_32, 后放弃

### RISC和CISC比较

**大量的复杂指令、可变的指令长度、多种的寻址方式这些是CISC的特点，也是启缺点。因为这都大大增加了解码的难度，在现在的高速硬件发展下，复杂指令所带来的速度提升已不及在解码上浪费的时间**

**而RISC体系的指令格式种类少，寻址方式种类少，大多数是简单指令且都能在一个时钟周期内完成，易于设计超标量与流水线，寄存器数量多，大量操作在寄存器之间进行，其优点是不言而喻的。**

![img](/images/951413iMgBlog/3e9074d16ebaf8d21d7d5cc64ea9e955.png)



在 RISC 架构里面，CPU 选择把指令“精简”到 20% 的简单指令。而原先的复杂指令，则通过用简单指令组合起来来实现，让软件来实现硬件的功能。这样，CPU 的整个硬件设计就会变得更简单了，在硬件层面提升性能也会变得更容易了。

RISC 的 CPU 里完成指令的电路变得简单了，于是也就腾出了更多的空间。这个空间，常常被拿来放通用寄存器。因为 RISC 完成同样的功能，执行的指令数量要比 CISC 多，所以，如果需要反复从内存里面读取指令或者数据到寄存器里来，那么很多时间就会花在访问内存上。于是，RISC 架构的 CPU 往往就有更多的通用寄存器。

除了寄存器这样的存储空间，RISC 的 CPU 也可以把更多的晶体管，用来实现更好的分支预测等相关功能，进一步去提升 CPU 实际的执行效率。

![img](/images/951413iMgBlog/d69a1e753fa1523df054573f13516277.jpeg)

 总体上来看：

​    执行时间和空间:CISC 因指令复杂，故采用微指令码控制单元的设计，而RISC的指令90%是由硬件直接完成，只有10%的指令是由软件以组合的方式完成，因此指令执行时间上RISC较短，但RISC所须ROM空间相对的比较大。

​    寻址方面：CISC的需要较多的寻址模式，而RISC只有少数的寻址模式，因此CPU在计算存储器有效位址时，CISC占用的周期较多。

​    指令执行：CISC指令的格式长短不一，执行时的周期次数也不统一，而RISC结构刚好相反，适合采用流水线处理架构的设计，进而可以达到平均一周期完成一指令。

​    设计上:RISC较CISC简单，同时因为CISC的执行步骤过多，闲置的单元电路等待时间增长，不利于平行处理的设计，所以就效能而言RISC较CISC还是占了上风，但**RISC因指令精简化后造成应用程式码变大，需要较大的存储器空间**。

​    RISC是为了提高处理器运行速度而设计的芯片设计体系,关键技术在于流水线操作(Pipelining)：在一个时钟周期里完成多条指令。目前，超流水线以及超标量设计技术已普遍在芯片设计中使用。

​    而ARM的优势不在于性能强大而在于效率，ARM采用RISC流水线指令集，在**完成综合性工作方面可能就处于劣势，而在一些任务相对固定的应用场合其优势就能发挥得淋漓尽致**。

[ARM和X86的系统架构差异分析——中篇(狭路相逢)](https://topic.atatech.org/articles/176546)

因为 RISC 降低了 CPU 硬件的设计和开发难度，所以从 80 年代开始，大部分新的 CPU 都开始采用 RISC 架构。从 IBM 的 PowerPC，到 SUN 的 SPARC，都是 RISC 架构。

#### 能耗

**ARM 和 x86 之间的功耗差异，并不是来自于 CISC 和 RISC 的指令集差异，而是因为两类芯片的设计，本就是针对不同的性能目标而进行的**，和指令集是 CISC 还是 RISC 并没有什么关系。

X86为了保持高性能，使用乱序执行，这样会让大部分的模块都保持开启，并且时钟也保持切换，直接后果就是耗电高。而ARM的指令确定执行顺序(移动设备)，并且依靠多核而不是单核多线程来执行，容易保持子模块和时钟信号的关闭，显然就会更省电一点(当然目前ARM也是支持乱序的)。

一条指令被解码并准备执行时，Intel和ARM的处理器都使用流水线，就是说解码的过程是并行的。为了更快地执行指令，这些流水线可以被设计成允许指令们不按照程序的顺序被执行（乱序执行）。一些巧逻辑结构可以判断下一条指令是否依赖于当前的指令执行的结果。Intel和ARM都提供乱序执行逻辑结构，由于这结构复杂，直接会导致更多的功耗。

在服务器领域，ARM为追求性能，其功耗优势应该会渐渐消失。

能效方面ARM还是相比Intel 的X86也是优势很多，给出的是64core期soc功率是105w(安培80核心的官方数据是210W)，而Intel 8163的 TDP是165W。

一个 4 核的 Intel i7 的 CPU，设计的时候功率就是 130W。而一块 ARM A8 的单个核心的 CPU，设计功率只有 2W。两者之间差出了 100 倍。

#### 微指令

在微指令架构的 CPU 里面，编译器编译出来的机器码和汇编代码并没有发生什么变化。但在指令译码的阶段，指令译码器“翻译”出来的，不再是某一条 CPU 指令。译码器会把一条机器码，“翻译”成好几条“微指令”。这里的一条条微指令，就不再是 CISC 风格的了，而是变成了固定长度的 RISC 风格的了。

这些 RISC 风格的微指令，会被放到一个微指令缓冲区里面，然后再从缓冲区里面，分发给到后面的超标量，并且是乱序执行的流水线架构里面。不过这个流水线架构里面接受的，就不是复杂的指令，而是精简的指令了。在这个架构里，我们的指令译码器相当于变成了设计模式里的一个“适配器”（Adaptor）。这个适配器，填平了 CISC 和 RISC 之间的指令差异。

![img](/images/951413iMgBlog/3c4ceec254e765462b09f393153f4476.jpeg)

这样一个能够把 CISC 的指令译码成 RISC 指令的指令译码器，比原来的指令译码器要复杂。这也就意味着更复杂的电路和更长的译码时间：本来以为可以通过 RISC 提升的性能，结果又有一部分浪费在了指令译码上。

Intel 就在 CPU 里面加了一层 L0 Cache。这个 Cache 保存的就是指令译码器把 CISC 的指令“翻译”成 RISC 的微指令的结果。于是，在大部分情况下，CPU 都可以从 Cache 里面拿到译码结果，而不需要让译码器去进行实际的译码操作。这样不仅优化了性能，因为译码器的晶体管开关动作变少了，还减少了功耗。

### RISC-V指令架构，开源

平头哥玄铁系列CPU，基于RISC-V指令架构

RISC-V目前主要是布局大数据、人工智能等领域，从ARM和X86尚未完全占领的市场起步。以目前RISC-V在业界掀起的巨大波澜来看，将来很可能足以挑战x86和ARM的地位。

RISC-V指令集由一个非常小的基础指令集和一系列可选的扩展指令集。最基础的指令集只包含40条指令，通过扩展还支持64位和128位的运算以及变长指令，扩展包括了乘除运算、原子操作、浮点运算等，以及开发中的指令集包括压缩指令、位运算、事务存储、矢量计算等。指令集的开发也遵循开源软件的开发方式。

RISC-V架构精简，现阶段已经可以对应执行64位元运算模式，相比ARM Cortex-A5架构设计的处理器，RISC-V架构打造的处理器约可在运算效能提升10%，并且在占用面积精简49%，用于嵌入式装置可带来不少竞争优势。

在商业授权方面，通过指令集扩展，任何企业都可以构建适用于任何领域的微处理器，比如云计算、存储、并行计算、虚拟化/容器、MCU、应用处理器、DSP处理器等等。目前Berkeley开发了多款开源的处理器，可覆盖从高性能计算到嵌入式等应用领域，并孵化出了初创公司SiFive并获得了风投。

RISC-V ---“CPU 届的 Linux”

## ARM

 ARM公司最早是由赫尔曼·豪泽（Hermann Hauser）和工程师Chris Curry在1978年创立（早期全称是 Acorn RISC Machine），后来改名为现在的ARM公司（Advanced RISC Machine）

![img](/images/951413iMgBlog/ac0bac75ae745316e0c011ffdc5a78a5.png)



### ARM 芯片厂家

查看厂家

> cat /proc/cpuinfo |grep implementer
>
> CPU implementer	: 0x70
>
> #cat /sys/devices/system/cpu/cpu0/regs/identification/midr_el1
> 0x00000000701f6633  // 70 表示厂家

vendor id对应厂家

| Vendor Name      | Vendor ID |
| :--------------- | :-------- |
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
| 飞腾             | 0x70      |

## X86

Intel x86从开始就定位于PC机，应用多是计算密集型的，如多媒体、科研计算、模拟等(在1999年市值突破了5000亿美金，当然没有一家企业是顺风顺水的，在Intel 奔腾四（高频、高压、高功耗）年代(2005年+)，基本是被AMD的速龙XP摁在地上打，而且后来的奔腾四双核为了追进度也是直接是**胶水双核，就是将两个DIE直接封装在一起，没有专用总线**，成为其历史上最愚蠢的决定之一)。从2006年的酷睿架构开始搭载笔记本电脑，Intel才开始再次的腾飞，并开始甩开AMD。

CISC架构也会使得硬件的逻辑复杂，晶体管数量庞大。为了进一步高效地进行运算，x86架构会有较长的流水线以达到指令级并行(ILP)，而长流水线也会带来了弊端，当遇到分支时，如果预载入分支指令不是未来真实的分支，那么要清空整个流水。因此，x86有引入了复杂的分支预测机构，来确保流水线的效率。再加上多级cache，超线程、虚拟化等等技术，使得x86的复杂度越来越高，而向后兼容性也使得Intel历史包袱越来越大。

![cascade lake naming scheme.svg](/images/951413iMgBlog/750px-cascade_lake_naming_scheme.svg.png)



Intel skylake 架构图

![skylake server block diagram.svg](/images/951413iMgBlog/950px-skylake_server_block_diagram.svg.png)



iTLB:instruct TLB 

dTLB:data TLB

![img](/images/951413iMgBlog/cache-ht-hierarchy-2.jpg)

uma下cpu访问内存：

![x86 UMA](/images/951413iMgBlog/numa-fsb-3.png)

### numa下

[Non-Uniform Memory Access (NUMA)](http://en.wikipedia.org/wiki/Non-Uniform_Memory_Access)

![img](/images/951413iMgBlog/numa-imc-iio-smb-4.png)

在两路及以上的服务器，远程 DRAM 的访问延迟，远远高于本地 DRAM 的访问延迟，有些系统可以达到 2 倍的差异。即使服务器 BIOS 里关闭了 NUMA 特性，也只是对 OS 内核屏蔽了这个特性，这种延迟差异还是存在的

如果 BIOS 打开了 NUMA 支持，Linux 内核则会根据 ACPI 提供的表格，针对 NUMA 节点做一系列的 NUMA 亲和性的优化。

[Like Skylake, there are two sub-NUMA clusters in each Cascade Lake socket](https://www.nas.nasa.gov/hecc/support/kb/cascade-lake-processors_579.html), creating two localization domains. There are three memory channels per sub-NUMA cluster. Each channel can be connected with up to two memory DIMMs. For the Aitken Cascade Lake configuration, there is one 16-gigabyte (GB) dual rank DDR4 DIMM with error correcting code (ECC) support per channel. In total, the amount of memory is 48 GB per sub-NUMA cluster, 96 GB per socket, and 192 GB per node.

The speed of each memory channel is increased from 2,666 MHz in Skylake to 2,933 MHz in Cascade Lake. An 8-byte read or write can take place per cycle per channel. With a total of six memory channels, the total half-duplex memory bandwidth is approximately 141 GB/s per socket.

![SLN316864_en_US__1image001(1)](/images/951413iMgBlog/ka02R000000oNBPQA2_en_US_1.jpeg)

[性能测试数据](https://www.dell.com/support/kbdoc/en-sg/000176921/bios-characterization-for-hpc-with-intel-cascade-lake-processors)

ob在鲲鹏920上测试，如果BIOS 里enable NUMA，NUMA-Aware 的就近内存分配和使用能提升性能，在我们的测试中，性能提高8%

![img](/images/951413iMgBlog/e475286bef0d734feca8fba300a501e6.png)

sysctl -w kernel.numa_balancing=0 TPS是72W，sysctl -w kernel.numa_balancing=1 TPS为57W

#### UMA和NUMA对比

The SMP/UMA architecture

![img](/images/951413iMgBlog/uma-architecture.png)

The NUMA architecture

![img](/images/951413iMgBlog/uma-architecture-20210511183000204.png)



## 不同CPU的一些性能数据对比

以Skylake的IPC（图中表示为GPC）为1.0，那么Apple的M1或者A14的Firestorm大核心，大致上是Skylake的两倍，而Intel Tiger Lake U的最好表现是1.3最差1.20，综合下表现应该是符合Willow Cove是Skylake 1.25X IPC附近的条件的。所以说Firestorm也是Intel Willow Cove的1.5~1.6X的IPC的，排除Geekbench的权威性不足以及测试误差，也可以说苹果Firestorm显著超过现有X86的。

对于处理器来说，跑高频的能力固然重要，但是高频也会造成功耗的快速上升，一个跑4.8G的CPU只比跑3.2G时高了50%性能，但是功耗可能是3倍乃至更多（比如你看AMD）。

![img](/images/951413iMgBlog/v2-22ac73d34a31de0c98d773199448be24_1440w.jpg)

接下来通过实际测试来探讨一下不同CPU架构的性能，以及NUMA和绑核对性能的影响。

## 飞腾ARM芯片案例

ARMv64 架构CPU，基本都是运行网络瓶颈的业务逻辑，绑核前IPC只有0.08

![img](/images/oss/16b271c8-5132-4273-a26a-4b35e8f92882.png)

cpu详细信息：

![img](/images/oss/e177902c-73b2-4535-9c1f-2726451820db.png)

飞腾芯片，按如下distance绑核基本没区别！展示出来的distance是假的一样

![img](/images/oss/5a19ff61-68db-4c65-be4c-6b6c155a8a29.png)



![image-20210422095217195](/images/951413iMgBlog/image-20210422095217195.png)



绑核后对性能提升非常明显：

![img](/images/oss/4d4fdebb-6146-407e-881d-19170fbfd82b.png)

点查场景：

![image-20210425092158127](/images/951413iMgBlog/image-20210425092158127.png)

如上是绑48-63号核

![image-20210425091727122](/images/951413iMgBlog/image-20210425091727122.png)

![image-20210425091557750](/images/951413iMgBlog/image-20210425091557750.png)

![image-20210425093630438](/images/951413iMgBlog/image-20210425093630438.png)



绑不同的核性能差异比较大，比如同样绑第一个socket最后16core和绑第二个socket最后16core，第二个socket的最后16core性能要好25-30%---**这是因为网卡软中断，如果将软中断绑定到0-4号cpu后差异基本消失**,因为网卡队列设置的是60，基本跑在前60core上，也就是第一个socket上。

点查场景绑核和不绑核性能能差1倍, 将table分表后，物理rt稳定了(**截图中物理rt下降是因为压力小了**)



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

绑核前后对比：绑核后QPS翻倍，DRDS上的rt从7.5降低到了2.2，rt下降非常明显，可以看出主要是绑核前跨numa访问慢。**实际这个测试是先跑的不绑核，内存分布在所有NUMA上，没有重启再绑核就直接测试了，所以性能提升不明显，因为内存已经跨NUMA分配完毕了**。

![image-20210427093424116](/images/951413iMgBlog/image-20210427093424116.png)

```
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

![image-20210427164953340](/images/951413iMgBlog/image-20210427164953340.png)



绑核前的IPC：

![image-20210427093625575](/images/951413iMgBlog/image-20210427093625575.png)

绑核后的IPC：

![image-20210427095130343](/images/951413iMgBlog/image-20210427095130343.png)



**如果是两个8core对一个16core在都最优绑核场景下从上面的数据来看能有40-50%的性能提升，并且RT抖动更小**，这两个8core绑定在同一个Socket下，验证是否争抢，同时可以看到**绑核后性能可以随着加节点线性增加**

![image-20210427172612685](/images/951413iMgBlog/image-20210427172612685.png)

![image-20210427173047815](/images/951413iMgBlog/image-20210427173047815.png)

![image-20210427173417673](/images/951413iMgBlog/image-20210427173417673.png)

结论：不绑核一个FT2500的core点查只有500 QPS，绑核后能到1500QPS, 在Intel 8263下一个core能到6000以上(开日志、没开协程)



### RDS 数据库场景绑核

通过同一台物理上6个drds节点，总共96个core，压6台RDS，RDS基本快打挂了。sysbench 点查，32个分表，增加drds节点进来物理rt就增加，从最初的的1.2ms加到6个drds节点后变成8ms。



![image-20210425180535225](/images/951413iMgBlog/image-20210425180535225.png)





RDS没绑好核，BIOS默认关闭了NUMA，外加12个rds分布在物理机上不均匀，3个节点3个rds，剩下的物理机上只有一个RDS实例。

RDS每个实例32core，管控默认已经做了绑核，但是如果两个RDS绑在了一个socket上竞争会很激烈，ipc比单独的降一半。

比如这三个rds，qps基本均匀，上面两个cpu高，但是没效率，每个rds绑了32core，上面两个绑在一个socket上，下面的RDS绑在另一个socket上，第一个socket还有网络软中断在争抢cpu，飞腾环境下性能真要冲高还有很大空间。

![image-20210425180518926](/images/951413iMgBlog/image-20210425180518926.png)

```
#第二个RDS IPC只有第三个的30%多点，这就是为什么CPU高这么多，但是QPS差不多
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

#第三个RDS
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

12个RDS流量基本均匀：

![image-20210426083033989](/images/951413iMgBlog/image-20210426083033989.png)

### 网卡队列调整

这批机器默认都是双网卡做bond，但是两块网卡是HA，默认网卡队列是60，基本都跑在前面60个core上

将RDS网卡队列从60个改成6个后RDS性能提升大概10%

![image-20210426085534983](/images/951413iMgBlog/image-20210426085534983.png)

默认第一个RDS都绑在0-31号核上,其实改少队列加大了0-5号core的压力，但是实际数据表现要好。



### 查看网卡和numa的关系

```
#yum install lshw -y
#lshw -C network -short
H/W path               Device          Class      Description
=============================================================
/0/100/0/9/0           eth0            network    MT27710 Family [ConnectX-4 Lx]
/0/100/0/9/0.1         eth1            network    MT27710 Family [ConnectX-4 Lx]
/1                     e41358fae4ee_h  network    Ethernet interface
/2                     86b0637ef1e1_h  network    Ethernet interface
/3                     a6706e785f53_h  network    Ethernet interface
/4                     d351290e50a0_h  network    Ethernet interface
/5                     1a9e5df98dd1_h  network    Ethernet interface
/6                     766ec0dab599_h  network    Ethernet interface
/7                     bond0.11        network    Ethernet interface
/8                     ea004888c217_h  network    Ethernet interface
```

以及：

```
lscpu | grep -i numa
numactl --hardware
cat /proc/interrupts | egrep -i "CPU|rx"
```

[Check if the network interfaces are tied to Numa](https://ixnfo.com/en/how-to-find-out-on-which-numa-node-network-interfaces.html) (if -1 means not tied, if 0, then to numa0):

```
cat /sys/class/net/eth0/device/numa_node
```

You can see which NAMA the network card belongs to, for example, using lstopo:

```
yum install hwloc -y
lstopo
lstopo --logical
lstopo --logical --output-format png > lstopo.png
```

如果cpu core太多, interrupts 没法看的话，通过cut只看其中一部分core

```
cat /proc/interrupts | grep -i 'eth4\|CPU' | cut -c -8,865-995,1425-
```



## 内存和cache的latency对比

![latency](/images/951413iMgBlog/latency.png)

## NUMA

### zone_reclaim_mode

事实上Linux识别到NUMA架构后，默认的内存分配方案就是：优先尝试在请求线程当前所处的CPU的Local内存上分配空间。**如果local内存不足，优先淘汰local内存中无用的Page（Inactive，Unmapped）**。然后才到其它NUMA上分配内存。

intel 芯片跨node延迟远低于其他家，所以跨node性能损耗不大

zone_reclaim_mode，它用来管理当一个内存区域(zone)内部的内存耗尽时，是从其内部进行内存回收还是可以从其他zone进行回收的选项：

- 0 关闭zone_reclaim模式，可以从其他zone或NUMA节点回收内存
- 1 打开zone_reclaim模式，这样内存回收只会发生在本地节点内
- 2 在本地回收内存时，可以将cache中的脏数据写回硬盘，以回收内存
- 4 在本地回收内存时，表示可以用Swap 方式回收内存

```
# cat /proc/sys/vm/zone_reclaim_mode
0
```

### zone_reclaim_mode调整的影响

- 默认情况下，`zone_reclaim模式`是关闭的。这在很多应用场景下可以提高效率，比如文件服务器，或者依赖内存中`cache`比较多的应用场景。这样的场景对内存`cache`速度的依赖要高于进程进程本身对内存速度的依赖，所以我们宁可让内存从其他`zone`申请使用，也不愿意清本地`cache`。
- 如果确定应用场景是**内存需求大于缓存**，而且尽量要避免内存访问跨越`NUMA`节点造成的性能下降的话，则可以打开`zone_reclaim`模式。此时页分配器会优先回收容易回收的可回收内存（**主要是当前不用的`page cache`页**），然后再回收其他内存。
- 打开本地回收模式的写回可能会引发其他内存节点上的大量的脏数据写回处理。如果一个内存`zone`已经满了，那么脏数据的写回也会导致进程处理速度收到影响，产生处理瓶颈。这会降低某个内存节点相关的进程的性能，因为进程不再能够使用其他节点上的内存。但是会增加节点之间的隔离性，其他节点的相关进程运行将不会因为另一个节点上的内存回收导致性能下降。

实际从kernel代码提交记录来看在2014年前默认是1，之后改成了0：

```
#git show 4f9b16a
diff --git a/Documentation/sysctl/vm.txt b/Documentation/sysctl/vm.txt
index dd9d0e33b443..5b6da0fb5fbf 100644
--- a/Documentation/sysctl/vm.txt
+++ b/Documentation/sysctl/vm.txt
@@ -772,16 +772,17 @@ This is value ORed together of
 2      = Zone reclaim writes dirty pages out
 4      = Zone reclaim swaps pages

-zone_reclaim_mode is set during bootup to 1 if it is determined that pages
-from remote zones will cause a measurable performance reduction. The
-page allocator will then reclaim easily reusable pages (those page
-cache pages that are currently not used) before allocating off node pages.
-
-It may be beneficial to switch off zone reclaim if the system is
-used for a file server and all of memory should be used for caching files
-from disk. In that case the caching effect is more important than
+zone_reclaim_mode is disabled by default.  For file servers or workloads
+that benefit from having their data cached, zone_reclaim_mode should be
+left disabled as the caching effect is likely to be more important than
 data locality.

+zone_reclaim may be enabled if it's known that the workload is partitioned
+such that each partition fits within a NUMA node and that accessing remote
+memory would cause a measurable performance reduction.  The page allocator
+will then reclaim easily reusable pages (those page cache pages that are
+currently not used) before allocating off node pages.
+

diff --git a/mm/page_alloc.c b/mm/page_alloc.c
index 7cfdcd808f52..dfe954fbb48a 100644
--- a/mm/page_alloc.c
+++ b/mm/page_alloc.c
@@ -1860,8 +1860,6 @@ static void __paginginit init_zone_allows_reclaim(int nid)
        for_each_node_state(i, N_MEMORY)
                if (node_distance(nid, i) <= RECLAIM_DISTANCE)
                        node_set(i, NODE_DATA(nid)->reclaim_nodes);
-               else
-                       zone_reclaim_mode = 1;  //代码写死了只要开NUMA，就是用1 ？
 }
```

**开启NUMA亲和性后让内存访问速度大大加快了，但是带来的最大问题是容易造成某个NUMA下内存水位太高，进而经常触发PageCache 回收，造成系统卡顿。**

### Intel NUMA 性能测试

 用sysbench对一亿条记录跑点查，数据都加载到内存中了：

- 不绑核qps 不到8万，总cpu跑到5000%，降低并发的话qps能到11万；
- 如果绑0-31core qps 12万，总cpu跑到3200%；
- 如果绑同一个numa下的32core，qps飙到27万，总CPU跑到3200%；
- 绑0-15个物理core，qps能到17万，绑32-47也是一样的效果；

```
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
CPU MHz:               2500.000
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

#numastat
                           node0           node1
numa_hit               129600200        60501102
numa_miss                      0               0
numa_foreign                   0               0
interleave_hit            108648          108429
local_node             129576548        60395061
other_node                 23652          106041

[root@k28a11352.eu95sqa /root]
#./numa-maps-summary.pl </proc/30698/numa_maps
N0        :     14443569 ( 55.10 GB)
N1        :       351919 (  1.34 GB)
active    :            0 (  0.00 GB)
anon      :     14793210 ( 56.43 GB)
dirty     :     14793210 ( 56.43 GB)
kernelpagesize_kB:         1652 (  0.01 GB)
mapmax    :          308 (  0.00 GB)
mapped    :         2337 (  0.01 GB)
```

![image-20210513193951647](/images/951413iMgBlog/image-20210513193951647.png)

### [Understanding what triggers zone reclaim](https://engineering.linkedin.com/performance/optimizing-linux-memory-management-low-latency-high-throughput-databases)

When a process requests a page, the kernel checks whether its preferred NUMA zone has enough free memory and if more than 1% of its pages are reclaimable. The percentage is tunable and is determined by the [vm.min_unmapped_ratio sysctl](http://lxr.free-electrons.com/source/Documentation/sysctl/vm.txt#L412). Reclaimable pages are file backed pages (ie. pages which are allocated through mmapped files) which are not currently mapped to any process. In particular, from `/proc/meminfo`, the 'reclaimable pages' are 'Active(file)+Inactive(file)-Mapped' ([source](http://lxr.free-electrons.com/source/mm/vmscan.c#L3433)).

How does the kernel determine how much free memory is enough? The kernel uses zone 'watermarks' ([source](http://lxr.free-electrons.com/source/include/linux/mmzone.h#L235)) which are determined through the value in `/proc/sys/vm/min_free_kbytes` ([source](http://lwn.net/Articles/422291/)). They are also determined by `/proc/sys/vm/lowmem_reserve_ratio` value ([source](http://lxr.free-electrons.com/source/Documentation/sysctl/vm.txt#L238)). The computed values on a given host can be found from `/proc/zoneinfo` under the 'low/min/high' labels as seen below:

```
Node 1, zone Normal
 pages free 17353
 min 11284
 low 14105
 high 16926
 scanned 0
 spanned 6291456
 present 6205440
```

The kernel reclaims pages when the number of free pages in a zone falls below the low water mark. The page reclaim stops when the number of free pages rise above the 'low' watermark. *Further, these computations are per-zone: a zone reclaim can be triggered on a particular zone even if other zones on the host have plenty of free memory.*

Here is a graph that demonstrates this behavior from our experiment. Some points worth noting:

- the black line denotes page scans on the zone and is plotted against the y-axis on the right.
- the red line denotes the number of free pages in the zone.
- the 'low' watermark for the zone is in green.

![img](/images/951413iMgBlog/app0610-node0.png)

#### Characteristics of systems experiencing zone reclaims

We observed similar patterns on our production hosts. In all cases, we see that the page scan plot is virtually a mirror image of the free pages plot. In other words, Linux predictably triggers zone reclaims when the free pages fall below the 'low' watermark of the zone.

Our first observation was that, with zone reclaim enabled, Linux performed mostly direct reclaims (ie. reclaims performed in the context of application threads and counted as direct page scans). Once zone reclaim was disabled, the direct reclaims stopped, but the number of reclaims performed by kswapd increased. This would explain the high pgscand/s we observed from sar:

![img](/images/951413iMgBlog/app0610-pagescans.png)

we observed that the number of expensive memory accesses in the program dropped significantly once we disabled zone reclaim mode. The graph below shows the memory access latency in milliseconds, along with the amount of time spent in system and user CPU. We see that the program spent most of its time waiting for I/O while occasionally being blocked in system CPU.

![img](/images/951413iMgBlog/usr-sys-elapsed-times-app0610.png)

#### How zone reclaim impacts read performance

Based on the evidence above, it seems that the direct reclaim path triggered by zone reclaim is too aggressive in removing pages from the active list and adding them to the inactive list. In particular, with zone reclaim enabled, active pages seem to wind up on the inactive list, and then are subsequently paged out. Consequently, reads suffer a higher rate of major faults, and hence are more expensive.

### [NUMA的“七宗罪”](http://cenalulu.github.io/linux/numa/)

几乎所有的运维都会多多少少被NUMA坑害过，让我们看看究竟有多少种在NUMA上栽的方式：

- [MySQL – The MySQL “swap insanity” problem and the effects of the NUMA architecture](http://blog.jcole.us/2010/09/28/mysql-swap-insanity-and-the-numa-architecture/)
- [PostgreSQL – PostgreSQL, NUMA and zone reclaim mode on linux](http://frosty-postgres.blogspot.com/2012/08/postgresql-numa-and-zone-reclaim-mode.html)
- [Oracle – Non-Uniform Memory Access (NUMA) architecture with Oracle database by examples](http://blog.yannickjaquier.com/hpux/non-uniform-memory-access-numa-architecture-with-oracle-database-by-examples.html)
- [Java – Optimizing Linux Memory Management for Low-latency / High-throughput Databases](http://engineering.linkedin.com/performance/optimizing-linux-memory-management-low-latency-high-throughput-databases)

究其原因几乎都和：“因为CPU亲和策略导致的内存分配不平均”及“NUMA Zone Claim内存回收”有关，而和数据库种类并没有直接联系。所以下文我们就拿MySQL为例，来看看重内存操作应用在NUMA架构下到底会出现什么问题。

MySQL “swap insanity” problem and the effects of the NUMA architecture 总结：

- CPU规模因摩尔定律指数级发展，而总线发展缓慢，导致多核CPU通过一条总线共享内存成为瓶颈
- 于是NUMA出现了，CPU平均划分为若干个Chip（不多于4个），每个Chip有自己的内存控制器及内存插槽
- CPU访问自己Chip上所插的内存时速度快，而访问其他CPU所关联的内存（下文称Remote Access）的速度相较慢三倍左右
- 于是Linux内核默认使用CPU亲和的内存分配策略，使内存页尽可能的和调用线程处在同一个Core/Chip中
- 由于内存页没有动态调整策略，使得大部分内存页都集中在`CPU 0`上
- **又因为PageCache占用了大量可以释放的内存，`Reclaim`默认策略优先淘汰/Swap本Chip上的内存，使得大量有用内存被换出**
- 当被换出页被访问时问题就以数据库响应时间飙高甚至阻塞的形式出现了

用图片描述上述问题就是：

![img](/images/951413iMgBlog/numa-imbalanced-allocation.png)

Node0内存基本用完，但是Node1还有比较多的内存，但是kernel在内存不够的时候没有优先去用Node1，而是尝试回收Node0上的内存，这样就造成了高的swap和暂停。



怎么解决这个问题，文章给出的方案：

- `numactl --interleave=all`
- 在MySQL进程启动前，使用`sysctl -q -w vm.drop_caches=3`清空文件缓存所占用的空间
- Innodb在启动时，就完成整个`Innodb_buffer_pool_size`的内存分配

或者另外几个进阶方案

- 配置`vm.zone_reclaim_mode = 0`使得内存不足时`去remote memory分配`优先于`swap out local page`   //默认配置
- `echo -15 > /proc/<pid_of_mysqld>/oom_adj`调低MySQL进程被`OOM_killer`强制Kill的可能
- [memlock](http://dev.mysql.com/doc/refman/5.6/en/server-options.html#option_mysqld_memlock)
- 对MySQL使用Huge Page（黑魔法，**巧用了Huge Page不会被swap的特性**）

### NUMA Interleave真的好么？

**为什么`Interleave`的策略就解决了问题？** 借用两张 [Carrefour性能测试](https://www.cs.sfu.ca/~fedorova/papers/asplos284-dashti.pdf) 的结果图，可以看到几乎所有情况下`Interleave`模式下的程序性能都要比默认的亲和模式要高，有时甚至能高达30%。究其根本原因是Linux服务器的大多数workload分布都是随机的：即每个线程在处理各个外部请求对应的逻辑时，所需要访问的内存是在物理上随机分布的。而`Interleave`模式就恰恰是针对这种特性将内存page随机打散到各个CPU Core上，使得每个CPU的负载和`Remote Access`的出现频率都均匀分布。相较NUMA默认的内存分配模式，死板的把内存都优先分配在线程所在Core上的做法，显然普遍适用性要强很多。 

![perf1](/images/951413iMgBlog/perf1.png) ![perf2](/images/951413iMgBlog/perf2.png)

也就是说，像MySQL这种外部请求随机性强，各个线程访问内存在地址上平均分布的这种应用，`Interleave`的内存分配模式相较默认模式可以带来一定程度的性能提升。 此外 [各种](https://www.cs.sfu.ca/~fedorova/papers/asplos284-dashti.pdf) [论文](http://www.lst.inf.ethz.ch/people/alumni/zmajo/publications/11-systor.pdf) 中也都通过实验证实，真正造成程序在NUMA系统上性能瓶颈的并不是`Remote Acess`带来的响应时间损耗，而是内存的不合理分布导致`Remote Access`将inter-connect这个小水管塞满所造成的结果。而`Interleave`恰好，把这种不合理分布情况下的Remote Access请求平均分布在了各个小水管中。所以这也是`Interleave`效果奇佳的一个原因。

这是说Numa默认优先本地分配后，会导致某个NUMA内存使用过高，进而使得NUMA到这些内存访问频率高，最终导致内存访问带宽不够。

### [centos NUMA 内存分配策略](https://access.redhat.com/documentation/zh-cn/red_hat_enterprise_linux/7/html/virtualization_tuning_and_optimization_guide/sect-virtualization_tuning_optimization_guide-numa-allocation_policy)

以下三种策略定义了系统中节点对内存的分配：

- *`Strict`*

  目标节点中不能分配内存时，分配将被默认操作转进至其他节点。严格的策略意味着，当目标节点中不能分配内存时，分配将会失效。

- *`Interleave`*

  内存页面将被分配至一项节点掩码指定的节点，但将以轮循机制的方式分布。

- *`Preferred`*

  内存将从单一最优内存节点分配。如果内存并不充足，内存可以从其他节点分配。

### NUMA下内存分布查看

```
#perl numa-maps-summary.pl < /proc/110609/numa_maps //已经绑核后的DRDS节点,绑在8、9号NUMA上
N0        :          723 (  0.00 GB)
N1        :          534 (  0.00 GB)
N10       :          346 (  0.00 GB)
N11       :       317175 (  1.21 GB)
N12       :       394490 (  1.50 GB)
N13       :       740577 (  2.83 GB)
N14       :         1528 (  0.01 GB)
N15       :        12540 (  0.05 GB)
N2        :          185 (  0.00 GB)
N3        :          975 (  0.00 GB)
N4        :          759 (  0.00 GB)
N5        :       203231 (  0.78 GB)
N6        :          143 (  0.00 GB)
N7        :          433 (  0.00 GB)
N8        :      6900962 ( 26.33 GB)
N9        :      6164248 ( 23.51 GB)
active    :          218 (  0.00 GB)
anon      :     14734638 ( 56.21 GB)
dirty     :     14734640 ( 56.21 GB)
kernelpagesize_kB:        17452 (  0.07 GB)
mapmax    :         1347 (  0.01 GB)
mapped    :         4211 (  0.02 GB)

#perl numa-maps-summary.pl </proc/61238/numa_maps //同样的物理机上，BIOS中关闭了NUMA，RDS绑了32core
N0        :     24239251 ( 92.47 GB)
active    :         1199 (  0.00 GB)
anon      :     24231673 ( 92.44 GB)
dirty     :     24231673 ( 92.44 GB)
kernelpagesize_kB:        11036 (  0.04 GB)
mapmax    :          608 (  0.00 GB)
mapped    :         7775 (  0.03 GB)
#perl numa-maps-summary.pl </proc/53400/numa_maps //和61238在同一个物理机上，但是绑定的是另外一个socket，性能好
N0        :     18301536 ( 69.81 GB)
active    :         1171 (  0.00 GB)
anon      :     18293958 ( 69.79 GB)
dirty     :     18293958 ( 69.79 GB)
kernelpagesize_kB:        10988 (  0.04 GB)
mapmax    :          582 (  0.00 GB)
mapped    :         7775 (  0.03 GB)
```

看起来**飞腾在同一个socket下的跨NUMA内存访问性能跟distence差别不大，是本地访问的80%，同一个socket下的不同NUMA之间的代价基本一样。但是跨socket的远程代价就非常大了，也就是本地的30%左右，抖动还大。**

或者[通过numastat来查看本地内存是否充足](https://www.kernel.org/doc/html/latest/admin-guide/numastat.html?spm=ata.21736010.0.0.65b56bbdVhT9AI):

```
#numastat
                           node0           node1
numa_hit               108951315        37286047
numa_miss                      0               0
numa_foreign                   0               0
interleave_hit            108648          108429
local_node             108932960        37180664
other_node                 18355          105383

#cat /proc/30698/sched
mysqld (30698, #threads: 20)
-------------------------------------------------------------------
se.exec_start                                :       8136806.468893
se.vruntime                                  :        178093.158543
se.sum_exec_runtime                          :         43884.911838
se.statistics.wait_start                     :             0.000000
se.statistics.sleep_start                    :       8136806.468893
se.statistics.block_start                    :             0.000000
se.statistics.sleep_max                      :          1001.948309
se.statistics.block_max                      :             0.917016
se.statistics.exec_max                       :             1.336926
se.statistics.slice_max                      :             0.265414
se.statistics.wait_max                       :             0.225658
se.statistics.wait_sum                       :             2.092366
se.statistics.parent_wait_contrib            :             0.000000
se.statistics.wait_count                     :                22786
se.statistics.iowait_sum                     :             7.162572
se.statistics.iowait_count                   :                  157
se.nr_migrations                             :                12257
se.statistics.nr_migrations_cold             :                    0
se.statistics.nr_failed_migrations_affine    :                   27
se.statistics.nr_failed_migrations_running   :                  318
se.statistics.nr_failed_migrations_hot       :                    4
se.statistics.nr_forced_migrations           :                    0
se.statistics.nr_wakeups                     :                22712
se.statistics.nr_wakeups_sync                :                22420
se.statistics.nr_wakeups_migrate             :                12239
se.statistics.nr_wakeups_local               :                12754
se.statistics.nr_wakeups_remote              :                 9958
se.statistics.nr_wakeups_affine              :                    3
se.statistics.nr_wakeups_affine_attempts     :                  134
se.statistics.nr_wakeups_passive             :                    0
se.statistics.nr_wakeups_idle                :                    0
avg_atom                                     :             1.926297
avg_per_cpu                                  :             3.580395
preempt_delay                                :             0.000000
nr_switches                                  :                22782
nr_voluntary_switches                        :                22711
nr_involuntary_switches                      :                   71
se.load.weight                               :                 1024
se.avg.runnable_avg_sum                      :                  755
se.avg.runnable_avg_period                   :                47852
se.avg.load_avg_contrib                      :                    7
se.avg.decay_count                           :              7759864
policy                                       :                    0
prio                                         :                  120
clock-delta                                  :                   23
mm->numa_scan_seq                            :                   25
numa_migrations, 121
numa_faults_memory, 0, 0, 0, 1, 4
numa_faults_memory, 1, 0, 0, 1, 34
numa_faults_memory, 0, 1, 1, 0, 1
numa_faults_memory, 1, 1, 0, 0, 113
```



![img](/images/951413iMgBlog/802b8f4607f1addf17ad24747fda7fb6.png)

### 内存分配

[In a nutshell, Linux maintains a set of 3 lists of pages per NUMA zone](https://engineering.linkedin.com/performance/optimizing-linux-memory-management-low-latency-high-throughput-databases): the active list, the inactive list, and the free list. New page allocations move pages from the free list onto the active list. An LRU algorithm moves pages from the active list to the inactive list, and then from the inactive list to the free list. The following is the best place to learn about Linux's management of the page cache:

- Mel Gorman: [Understanding the Linux Virtual Memory Manager](https://www.kernel.org/doc/gorman/html/understand/), chapter 13: [Page Frame Reclamation](https://www.kernel.org/doc/gorman/html/understand/understand013.html).

#### Linux内存分配模式(mode)

- NODE LOCAL （系统默认）
  在当前代码执行的地方分配内存
- Interleave
  第一页分配在node 0,下一页在node 1，再下一页node 0，如此轮换。适合被多个线程访问的数据

进程的Numa分配可通过`/proc/<pid>/numa_maps`查看，单个node分配查看`/sys/devices/system/node/node<X>/meminfo`

#### 关于NUMA内存回收

当内存很低时，内核会考虑回收pages。具体回收哪些页取决于page类别，如mlock的page就不能回收。对于NUMA内存来讲，不同node剩余的内存很有可能不一样，当当前node不能分配所需内存而远程node可分配时，有两种策略：

- 在local node上做回收
  但这会增加内核处理开销
- 从远程分配

对于小型的numa系统，如2 nodes，内核默认第二种策略，对于大型numa系统(4 nodes以上)，选择第一种。（这一点未在linux内核上确认，但存在这种可选策略是可以理解的）

通过查看`/proc/sys/vm/zone_reclaim`可知系统是否支持回收，它的值可以在启动时测量NUMA nodes之间的距离得到；如果被enabled，内核会尽可能少地执行此过程，且默认只回收**unmapped page-cache pages**,用户还可以通过`/proc/sys/vm/min_unmapped_ratio`来设置最小的回收比例来进一步限制reclaim频次；当然，也可以设置地更加aggressive ，比如允许剔除dirty pages, annoymous pages

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

除了 CPU、GPU，以及刚刚的 FPGA，我们其实还需要用到很多其他芯片。比如，现在手机里就有专门用在摄像头里的芯片；录音笔里会有专门处理音频的芯片。尽管一个 CPU 能够处理好手机拍照的功能，也能处理好录音的功能，但是我们直接在手机或者录音笔里塞上一个 Intel CPU，显然比较浪费。

因为 ASIC 是针对专门用途设计的，所以它的电路更精简，单片的制造成本也比 CPU 更低。而且，因为电路精简，所以通常能耗要比用来做通用计算的 CPU 更低。而我们上一讲所说的早期的图形加速卡，其实就可以看作是一种 ASIC。

因为 ASIC 的生产制造成本，以及能耗上的优势，过去几年里，有不少公司设计和开发 ASIC 用来“挖矿”。这个“挖矿”，说的其实就是设计专门的数值计算芯片，用来“挖”比特币、ETH 这样的数字货币。

如果量产的ASIC比较小的话可以直接用FPGA来实现

## TPU 张量处理器（tensor processing unit）

**张量处理器**（英语：tensor processing unit，缩写：TPU）是[Google](https://baike.baidu.com/item/Google)为[机器学习](https://baike.baidu.com/item/机器学习)定制的专用芯片（ASIC），专为Google的[深度学习](https://baike.baidu.com/item/深度学习)框架[TensorFlow](https://baike.baidu.com/item/TensorFlow)而设计。

在性能上，TPU 比现在的 CPU、GPU 在深度学习的推断任务上，要快 15～30 倍。而在能耗比上，更是好出 30～80 倍。另一方面，Google 已经用 TPU 替换了自家数据中心里 95% 的推断任务，可谓是拿自己的实际业务做了一个明证。

## SRAM（Static Random-Access Memory，静态随机存取存储器）的芯片

CPU Cache 用的是一种叫作 SRAM（Static Random-Access Memory，静态随机存取存储器）的芯片。

SRAM 之所以被称为“静态”存储器，是因为只要处在通电状态，里面的数据就可以保持存在。而一旦断电，里面的数据就会丢失了。在 SRAM 里面，一个比特的数据，需要 6～8 个晶体管。所以 SRAM 的存储密度不高。同样的物理空间下，能够存储的数据有限。不过，因为 SRAM 的电路简单，所以访问速度非常快。

## DRAM（Dynamic Random Access Memory，动态随机存取存储器）的芯片

内存用的芯片和 Cache 有所不同，它用的是一种叫作 DRAM（Dynamic Random Access Memory，动态随机存取存储器）的芯片，比起 SRAM 来说，它的密度更高，有更大的容量，而且它也比 SRAM 芯片便宜不少。

DRAM 被称为“动态”存储器，是因为 DRAM 需要靠不断地“刷新”，才能保持数据被存储起来。DRAM 的一个比特，只需要一个晶体管和一个电容就能存储。所以，DRAM 在同样的物理空间下，能够存储的数据也就更多，也就是存储的“密度”更大。但是，因为数据是存储在电容里的，电容会不断漏电，所以需要定时刷新充电，才能保持数据不丢失。DRAM 的数据访问电路和刷新电路都比 SRAM 更复杂，所以访问延时也就更长。

![img](/images/951413iMgBlog/d39b0f2b3962d646133d450541fb75a6.png)

## 直接内存访问（Direct Memory Access）DMA

其实 DMA 技术很容易理解，本质上，DMA 技术就是我们在主板上放一块独立的芯片。在进行内存和 I/O 设备的数据传输的时候，我们不再通过 CPU 来控制数据传输，而直接通过 DMA 控制器（DMA Controller，简称 DMAC）。这块芯片，我们可以认为它其实就是一个协处理器（Co-Processor）。

在从硬盘读取数据的时候CPU发出指令给DMAC然后就不用管了，毕竟硬盘太慢，DMAC来将数据读取到内存完毕后再通知CPU。

### Kafka和DMA

Kafka 是一个用来处理实时数据的管道，我们常常用它来做一个消息队列，或者用来收集和落地海量的日志。作为一个处理实时数据和日志的管道，瓶颈自然也在 I/O 层面。

Kafka 里面会有两种常见的海量数据传输的情况。一种是从网络中接收上游的数据，然后需要落地到本地的磁盘上，确保数据不丢失。另一种情况呢，则是从本地磁盘上读取出来，通过网络发送出去。

比如在如下代码过程中，数据一共发生了四次传输的过程。其中两次是 DMA 的传输，另外两次，则是通过 CPU 控制的传输

```
File.read(fileDesc, buf, len);
Socket.send(socket, buf, len);
```

![img](/images/951413iMgBlog/e0e85505e793e804e3b396fc50871cd5.jpg)

类似零拷贝和bypass

最终kafka会利用Java NIO库里面的transferTo来将上面的4次搬运改成2次，并且这两次都不需要CPU参与

```
@Override
public long transferFrom(FileChannel fileChannel, long position, long count) throws IOException {
    return fileChannel.transferTo(position, count, socketChannel);
}
```

![img](/images/951413iMgBlog/596042d111ad9b871045d970a10464ab.jpg)

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
#./a.out
25560
23420

[root@043h08216.cloud.h10.amtest93 /root]
#./a.out
25510
23410
```

![image-20210512133536939](/images/951413iMgBlog/image-20210512133536939.png)

## cache_line 案例

x86和arm下执行时间都是循环2是循环1的四分之一左右，实际循环次数是十六分之一。之所以执行时间不是十六分之一是因为循环一重用了cache_line. Xeon(R) Platinum 8260跑这个程序的性能是鲲鹏920的2倍左右。

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
	long length=64*1024*1024;
	int* arr=malloc(64*1024*1024 * sizeof(int));
	long i=0;
	long j=0;
	for (i = 0; i < length; i++) arr[i] = i;

	clock_t start=clock();
	// 循环1
	for(j=0; j<10; j++){
	    for (i = 0; i < length; i++) arr[i] *= 3; //每取一次arr[i], 通过cache_line顺便把后面15个arr[i]都取过来了
	}
    clock_t end =clock();
	printf("%lu\n", timediff(start,end));

  start=clock();
	// 循环2
	for(j=0; j<10; j++){
	    for (i = 0; i < length; i += 16) arr[i] *= 3;
	}
  end =clock();
  printf("%lu\n", timediff(start,end));
}
```

循环一的perf结果：

```
#perf stat -- ./cache_line_loop.out
2790
0
failed to read counter branches

 Performance counter stats for './cache_line_loop.out':

       3238.892820      task-clock (msec)         #    1.000 CPUs utilized
                 4      context-switches          #    0.001 K/sec
                 0      cpu-migrations            #    0.000 K/sec
            65,582      page-faults               #    0.020 M/sec
     8,420,900,487      cycles                    #    2.600 GHz
        23,284,432      stalled-cycles-frontend   #    0.28% frontend cycles idle
     4,709,527,283      stalled-cycles-backend    #   55.93% backend  cycles idle
    14,553,892,976      instructions              #    1.73  insns per cycle
                                                  #    0.32  stalled cycles per insn //因为有cache_line的命中，stall是循环二的四分之一
   <not supported>      branches
           141,482      branch-misses             #    0.00% of all branches

       3.239729660 seconds time elapsed

```

循环二的perf结果：

```
#perf stat -- ./cache_line_loop.out
0
730
failed to read counter branches

 Performance counter stats for './cache_line_loop.out':

       1161.126720      task-clock (msec)         #    0.999 CPUs utilized
                 1      context-switches          #    0.001 K/sec
                 0      cpu-migrations            #    0.000 K/sec
            65,583      page-faults               #    0.056 M/sec
     3,018,882,346      cycles                    #    2.600 GHz
        21,846,222      stalled-cycles-frontend   #    0.72% frontend cycles idle
     2,456,150,941      stalled-cycles-backend    #   81.36% backend  cycles idle
     1,970,906,199      instructions              #    0.65  insns per cycle
                                                  #    1.25  stalled cycles per insn
   <not supported>      branches
           138,051      branch-misses             #    0.00% of all branches

       1.161791340 seconds time elapsed
```

 Xeon(R) Platinum 8260 CPU @ 2.40GHz 性能：

```
#perf stat -- ./cache_line_loop.out
1770
370
```

## lmbench 测试

[内存测试命令，以及华为海思arm处理器：­Hisilicon Hi1620， 海光处理器Hygon C86 7185，Intel处理器8163性能比较](https://topic.atatech.org/articles/175032)

```
总带宽：
#taskset -c 0-96 -W 5 -N 5 -M 64M //其中a表示系统中逻辑核总数。

Die2Die测试命令, 其中j表示遍历Dide的内存节点，nodenum表示die中所包含的逻辑cpu数量。
numactl -C j ./stream -v1 -P $nodenum -W 5 -N 5 -M 64M

socket2socket测试命令, 其中cpusocket[表示第个中的逻辑数量，j]表示遍历所有socket的内存节点。
numactl -C {cpusocket[i]} -m {memsocket[j]} ./stream -v1 -P {numsocket[i]} -W 5 -N 5 -M 64M
```

内存延时测试命令：

```
延时测试命令, 其中cpus为die所在的某个cpu, j表示遍历所有die。
numactl -C j ./lat_mem_rd -P 1 -W 5 -N 5 -t 1024M
```

参考：https://winddoing.github.io/post/54953.html

[内存延时测试](https://topic.atatech.org/articles/107682)：

```
#./bin/lat_mem_rd 1 16 //1(范围, 单位M) 16(步长)
"stride=16
0.00049 1.540
0.00098 1.540
0.00195 1.540
0.00293 1.540
```



## 参考资料

[CPU Utilization is Wrong](http://www.brendangregg.com/blog/2017-05-09/cpu-utilization-is-wrong.html)

