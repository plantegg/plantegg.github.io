
# CPU的制造和概念

为了让程序能快点，特意了解了CPU的各种原理，比如多核、超线程、NUMA、睿频、功耗、GPU、大小核再到分支预测、cache_line失效、加锁代价、IPC等各种指标（都有对应的代码和测试数据）都会在这系列文章中得到答案。当然一定会有程序员最关心的分支预测案例、Disruptor无锁案例、cache_line伪共享案例等等。

这次让我们从最底层的沙子开始用8篇文章来回答各种疑问以及大量的实验对比案例和测试数据。

大的方面主要是从这几个疑问来写这些文章：

-   同样程序为什么CPU跑到800%还不如CPU跑到200%快？
-   IPC背后的原理和和程序效率的关系？
-   为什么数据库领域都爱把NUMA关了，这对吗？
-   几个国产芯片的性能到底怎么样？

## 系列文章

[CPU的制造和概念](/2021/06/01/CPU%E7%9A%84%E5%88%B6%E9%80%A0%E5%92%8C%E6%A6%82%E5%BF%B5/)

[Perf IPC以及CPU性能](/2021/05/16/Perf IPC以及CPU利用率/)

[CPU性能和CACHE](https://plantegg.github.io/2021/07/19/CPU%E6%80%A7%E8%83%BD%E5%92%8CCACHE/)

[CPU 性能和Cache Line](/2021/05/16/CPU Cache Line 和性能/)

[十年后数据库还是不敢拥抱NUMA？](/2021/05/14/%E5%8D%81%E5%B9%B4%E5%90%8E%E6%95%B0%E6%8D%AE%E5%BA%93%E8%BF%98%E6%98%AF%E4%B8%8D%E6%95%A2%E6%8B%A5%E6%8A%B1NUMA/)

[Intel PAUSE指令变化是如何影响自旋锁以及MySQL的性能的](/2019/12/16/Intel PAUSE指令变化是如何影响自旋锁以及MySQL的性能的/)

[Intel、海光、鲲鹏920、飞腾2500 CPU性能对比](/2021/06/18/%E5%87%A0%E6%AC%BECPU%E6%80%A7%E8%83%BD%E5%AF%B9%E6%AF%94/)

[一次海光物理机资源竞争压测的记录](/2021/03/07/%E4%B8%80%E6%AC%A1%E6%B5%B7%E5%85%89%E7%89%A9%E7%90%86%E6%9C%BA%E8%B5%84%E6%BA%90%E7%AB%9E%E4%BA%89%E5%8E%8B%E6%B5%8B%E7%9A%84%E8%AE%B0%E5%BD%95/)

[飞腾ARM芯片(FT2500)的性能测试](/2021/05/15/%E9%A3%9E%E8%85%BEARM%E8%8A%AF%E7%89%87-FT2500%E7%9A%84%E6%80%A7%E8%83%BD%E6%B5%8B%E8%AF%95/)

![image-20210802161410524](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/image-20210802161410524.png)

## 几个重要概念

为了增加对文章的理解先解释下几个高频概念

Wafer：晶圆，一片大的纯硅圆盘，新闻里常说的12寸、30寸晶圆厂说的就是它，光刻机在晶圆上蚀刻出电路

Die：从晶圆上切割下来的CPU(通常一个Die中包含多个core、L3cache、北桥、GPU等，core里面又包含了L1、L2cache），Die的大小可以自由决定，得考虑成本和性能, Die做成方形便于切割和测试，服务器所用的Intel CPU的Die大小一般是大拇指指甲大小。

封装：将一个或多个Die封装成一个物理上可以售卖的CPU

路：就是socket、也就是封装后的物理CPU

node：同一个Die下的多个core以及他们对应的内存，对应着NUMA

## 售卖的CPU实物

购买到的CPU实体外观和大小，一般是40mm X 50mm大小，可以看出一个CPU比一个Die大多了。

![How to Perform a CPU Stress Test and Push It to the Limit | AVG](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/AFCCC93B-D8A7-400A-9E80-978F8B05CD7E.jpeg)

![Coffee Lake-Refresh Desktop CPU List Surfaces: 35W Core i9-9900T & 8-Core  Xeon E-2200 Confirmed](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/images.jpeg)

![enter image description here](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/yp6cf.jpg)

## 宏观认识集成电路半导体行业

先从市场分布和市场占有率等几个行业宏观概念来了解半导体行业

### 半导体产业的产值分布

下图中的处理器就是我们日常所说的CPU，当然还包含了GPU等

我们常说的内存、固态硬盘这些存储器也是数字IC，后面你会看到一个CPU core里面还会有用于存储的cache电路

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/be159461be7c0a5569be21b30a24db50.png)

### 从一台iPhone来看集成电路和芯片

先看一台iPhone X拆解分析里面的所有芯片：

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/8bbc7b771359dfc07c81ca2a064cb30c.jpg)

### 全球半导体营收分布

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/d3a2690aaf6be233d08404c108fc4449.png)

美光：美国；Hynix海力士：韩国现代；美国双通：高通(CDMA)、博通(各种买买买、并购，网络设备芯片)；欧洲双雄(汽车芯片)：恩智浦和英飞凌

半导体行业近 5 年的行业前十的公司列了如下：

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/639990db9d26a8a54d1baaf3d6e513d4.png)

#### 半导体产品的十大买家

BBK是步步高集团，包含vivo、oppo、oneplus、realme等

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/3bb8531b7ab4c503436838ab15434310.png)

### 国内半导体市场情况

中国半导体协会总结过国产芯片的比例，2014 年出台的《国家集成电路产业发展纲要》和 2015 年的《中国制造 2025》文件中有明确提出：到 2020 年，集成电路产业与国际先进水平的差距逐步缩小；2020 年中国芯片自给率要达到 40%，2025 年要达到 50%。

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/a37bd5e13f2920fb2e85a7907cdc852a.jpeg)

国产化国家主导：紫光， 紫光的策略从收购转为自建，2016 年 12 月，合并武汉新芯，成立长江存储，与西数合资成立紫光西数。

长江存储在量产 64 层 NAND Flash 之后，2020 年首发 192 层 3D NAND，被预测 2021 会拿下 8% 的 NAND Flash 份额。同时，在存储芯片领域，中国还有一家公司叫做长鑫存储，长鑫存储以唯一一家中国公司的名号，杀入 DRAM 领域。在世界著名的行业分析公司 Yole 公司的报告上，显示长江存储和长鑫存储与三星、SK 海力士、美光和 Intel 齐头并进。

市场份额上，国产存储芯片市场，也许还有望达到 2025 的目标。

以上是我们对集成电路半导体行业的宏观认识。接下来我们从一颗CPU的生产制造开始讲

## 裸片Die 制作

晶圆为什么总是圆的呢？生产过程就是从沙子中提纯硅，硅晶柱生长得到晶圆，生长是以圆柱形式的，所以切割下来的晶圆就是圆的了：

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/weixin15664418828781.gif)

硅晶柱切片：

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/e510d61ed3e648a3ae64be7ac1da26e7.png)

直径为 300 毫米的纯硅晶圆（从硅柱上切割下来的圆片），俗称 12 寸晶圆，大约是 400 美金。但尺寸并不是衡量硅晶圆的最重要指标，纯度才是。日本的信越公司可以生产 13 个 9 纯度的晶圆。

### 光刻

使用特定波长的光，透过光罩（类似印炒里面的母版），照射在涂有光刻胶的晶圆上，光罩上芯片的设计图像，就复制到晶圆上了，这就是光刻，这一步是由光刻机完成的，光刻机是芯片制造中光刻环节的核心设备。你可以把光刻理解为，就是用光罩这个母版，一次次在晶圆上印电路的过程。

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/b62d2a87a74c1ba90a069624bdc91eee.jpeg)

光刻是最贵的一个环节，一方面是光罩越来越多，越来越贵，另一方面光刻机也很贵。光刻机是半导体制造设备中价格占比最大，也是最核心的设备。2020 年荷兰公司 ASML 的极紫外光源（EUV）光刻机每台的平均售价是 1.45 亿欧元，而且全世界独家供货，年产量 31 台，有钱也未必能买得到。

![image-20210601160424815](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/image-20210601160424815.png)

短波长光源是提高光刻机分辨力的有效方，光刻机的发展历史，就从紫外光源（UV）、深紫外光源（DUV），发展到了现在的极紫外光源（EUV）。

回顾光刻机的发展历史，从 1960 年代的接触式光刻机、接近式光刻机，到 1970 年代的投影式光刻机，1980 年代的步进式光刻机，到步进式扫描光刻机、浸入式光刻机和现在的深紫外光源（DUV）和极紫外光源（EUV）光刻机，一边是设备性能的不断提高，另一边是价格逐年上升，且供应商逐渐减少。到了 EUV 光刻机，ASML 就是独家供货了。

品质合格的die切割下去后，原来的晶圆成了下图的样子，是挑剩下的Downgrade Flash Wafer。残余的die是品质不合格的晶圆。黑色的部分是合格的die，会被原厂封装制作为成品NAND颗粒，而不合格的部分，也就是图中留下的部分则当做废品处理掉。

从晶圆上切割检测合格的Die（螺片），所以Die跟Wafer不一样不是圆的，而是是方形的，因为方形的在切割封测工艺上最简单

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/weixin15664418828785.gif)

一个大晶圆，拿走了合格的Die后剩下的次品：

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/bba1cd11728b47103777e2dbcccec3fdfc032348.png)

可见次品率不低，后面会谈到怎么降低次品率，次品率决定了CPU的价格。

台积电一片 5nm 晶圆的加工费高达 12500 美金。根据台积电的财报推算，台积电平均每片晶圆可以产生近 4000 美金（300mm 晶圆）的利润。无论是哪个数字，对比 400 美金的纯硅晶圆原料来说，这都是一个至少增值 10 倍的高价值的加工过程。

随着Die的缩小，浪费的比例也从36%缩小成为12.6%。根据极限知识，我们知道如果Die的大小足够小，我们理论上可以100%用上所有的Wafer大小。从中我们可以看出越小的Die，浪费越小，从而降低CPU价格，对CPU生产者和消费者都是好事。

光刻机有一个加工的最大尺寸，一般是 858mm²，而 Cerebras 和台积电紧密合作，做了一个 46255mm²，1.2T 个晶体管的世界第一大芯片。这也是超摩尔定律的一个突破。

AMD在工艺落后Intel的前提下，又想要堆核，只能采取一个Package封装4个独立Die的做法，推出了EPYC服务器芯片，即不影响良率，又可以核心数目好看，可谓一举两得。

可惜连接四个Die的片外总线终归没有片内通信效率高，在好些benchmark中败下阵来，可见没有免费的午餐。

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/v2-7d77aa1100b77261f2626791954e79ad_720w.jpg)

Intel的Pakcage内部是一个Die, Core之间原来是Ring Bus，在Skylake后改为Mesh。**AMD多Die封装的目的是省钱和增加灵活性！AMD每个Zeppelin Die都比Intel的小，这对良品率提高很大，节约了生产费用。**

这种胶水核强行将多个die拼一起是没考虑跨die之间的延迟，基本上跨die跟intel跨socket（numa）时延一样了。

一颗芯片的 1/3 的成本，是花在封测阶段的

光刻的粒度越来越细，玩家也越来越少，基本主流都是代工模式：

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/beebe27eacd37075dyy37a4182169f04.png)

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/5eb09cde20395b84ff8c746c27d9f7b7.jpg)

晶体管密度比较

![image-20210728095829384](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/image-20210728095829384.png)

### Die和core

One die with multiple cores，下图是一个Die内部图:

![enter image description here](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/xCqqv.jpg)

将两个Die封装成一块CPU(core多，成本低):

![data f1](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/dataf1-1372099277050.jpg)

第4代酷睿（Haswell）的die：

![image-20210601162558479](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/image-20210601162558479.png)

第4代酷睿（Haswell）的die主要分为几个部分：GPU、4个core、System Agent(uncore,类似北桥)、cache和内存控制器和其他小部件。**比如我们发现core 3和4有问题，我们可以直接关闭3和4。坏的关掉就是i5, 都是好的就当i7来卖。**

## 北桥和南桥

早期CPU core和内存硬盘的连接方式(FSB 是瓶颈)：

![image-20210602113401202](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/image-20210602113401202.png)

个人PC主板实物图：

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/northsouth2.jpg)

由于FSB变成了系统性能的瓶颈和对多CPU的制约，在台式机和笔记本电脑中，MCH(Memory Control Hub)被请进CPU中，服务器市场虽然短暂的出现了IOH。

![Image](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/640.jpeg)

集成北桥后的内存实物图：

![image-20210602114931825](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/image-20210602114931825.png)

北桥已经集成到CPU中，南桥还没有，主要是因为：集成后Die增大不少，生产良品率下降成本上升；不集成两者采用不同的工艺；另外就是CPU引脚不够了！

![Image](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/640-20210601095028465)

SoC（System on Chip）：南桥北桥都集成在CPU中，单芯片解决方案。ATOM就是SoC

## 一个Core的典型结构

Intel skylake 架构图

![skylake server block diagram.svg](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/950px-skylake_server_block_diagram.svg.png)

iTLB:instruct TLB

dTLB:data TLB

多个core加上L3等组成一个Die：

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/cache-ht-hierarchy-2.jpg)

## 多核和多个CPU

如果要实现一台48core的计算能力的服务器，可以有如下三个方案

### 方案1：一个大Die集成48core：
![Intel Skylake SP Mesh Architecture Conceptual Diagram](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/Intel-Skylake-SP-Mesh-Architecture-Conceptual-Diagram.png)

### [方案2](https://wccftech.com/amd-epyc-rome-zen-2-7nm-server-cpu-162-pcie-gen-4-lanes-report/)
：一个CPU封装4个Die，也叫MCM（Multi-Chip-Module），每个Die12个core

![image-20210602165525641](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/image-20210602165525641.png)

四个Die之间的连接方法：

![image-20210602172555232](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/image-20210602172555232.png)

上图最下面的方案为[Intel采用的EMIB](https://venturebeat.com/2017/03/28/intel-moves-tech-forward-by-putting-two-chips-in-a-single-package/)（Embedded Multi-die Interconnect Bridge）方案，cost 最低。中间的方案是使用“硅中介层”(Interposer，AMD采用的方案)。这意味着你能在两枚主要芯片的下面放置和使用第三枚芯片。这枚芯片的目的是使得多个设备的连接更加容易，但是也带来了更高的成本。

### 方案3：四个物理CPU（多Socket），每个物理CPU（Package）里面一个Die，每个Die12个core：

![image-20210602171352551](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/image-20210602171352551.png)

三者的比较：

性能肯定是大Die最好，但是良品率地，成本高；

方案2的多个Die节省了主板上的大量布线和VR成本，总成本略低，但是方案3更容易堆出更多的core和**内存**

![image-20210602170727459](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/image-20210602170727459.png)

### 面积和性能

我们使用了当时Intel 用在数据中心计算的大核CPU IvyBridge与当时用于 存储系列的小核CPU Avoton（ATOM）, 分别测试阿里巴巴的workload，得到性能吞吐如下：

<table>
<tr class="header">
<th>Intel 大小CPU 核心</th>
<th>阿里 Workload Output(QPS)</th>
</tr>
<tr class="odd">
<td>Avoton(8 cores) 2.4GHZ</td>
<td>10K on single core</td>
</tr>
<tr class="even">
<td>Ivy Bridge(2650 v2 disable HT) 2.6GHZ</td>
<td>20K on single core</td>
</tr>
<tr class="odd">
<td>Ivy Bridge(2650 v2 enable HT) 2.4GHZ</td>
<td>25K on single core</td>
</tr>
<tr class="even">
<td>Ivy Bridge(2650 v2 enable HT) 2.6GHZ</td>
<td>27K on single core</td>
</tr>
</table>

1.  大小核心直观比较：超线程等于将一个大核CPU 分拆成两个小核，Ivy Bridge的数据显示超线程给 Ivy Bridge **1.35倍**(27K/20K) 的提升
1.  性能与芯片面积方面比较：现在我们分别评判 两种CPU对应的性能密度 (performance/core die size) ，该数据越大越好，根据我们的计算和测量发现 Avoton(包含L1D, L1I, and L2 per core)大约是 3~4平方毫米，Ivy Bridge (包含L1D, L1I, L2 )大约是12~13平方毫米, L3/core是 6~7平方毫米, 所以 Ivy Bridge 单核心的芯片面积需要18 ~ 20平方毫米。基于上面的数据我们得到的 Avoton core的性能密度为 2.5 (10K/4sqmm)，而Ivy Bridge的性能密度是1.35 (27K/20sqmm)，因此相同的芯片面积下 Avoton 的性能是 Ivy Bridge的 **1.85倍**(2.5/1.35).
1.  性能与功耗方面比较：  从功耗的角度看性能的提升的对比数据，E5-2650v2(Ivy Bridge) 8core TDP 90w， Avoton 8 core TDP 20瓦， 性能/功耗 Avoton 是 10K QPS/20瓦， Ivy Bridge是 27KQPS/90瓦， 因此 相同的功耗下 Avoton是 Ivy Bridge的 **1.75倍**（10K QPS/20）/ （27KQPS/95）
1.  性能与价格方面比较：  从价格方面再进行比较，E5-2650v2(Ivy Bridge) 8core 官方价格是1107美元， Avoton 8 core官方价格是171美元性能/价格 Avoton是 10KQPS/171美元，Ivy Bridge 是 27KQPS/1107美元， 因此相同的美元 Avoton的性能是 Ivy Bridge 的**2.3倍（**1 10KQPS/171美元）/ （27KQPS/1107美元）

总结：在数据中心的场景下，由于指令数据相关性较高，同时由于内存访问的延迟更多，复杂的CPU体系结构并不能获得相应性能提升，该原因导致我们需要的是更多的小核CPU，以达到高吞吐量的能力，因此2014 年我们向Intel提出数据中心的CPU倾向“小核”CPU，需要将现有的大核CPU的超线程由 2个升级到4个/8个， 或者直接将用更多的小核CPU增加服务器的吞吐能力，经过了近8年，最新数据表明Intel 会在每个大核CPU中引入4个超线程，和在相同的芯片面积下单socket CPU 引入200多个小核CPU，该方案与我们的建议再次吻合

## 为什么这20年主频基本没有提升了

今天的2.5G CPU性能和20年前的2.5G比起来性能差别大吗？

因为能耗导致CPU的主频近些年基本不怎么提升了，不是技术上不能提升，是性价比不高.

在提升主频之外可以提升性能的有：提升跳转预测率，增加Decoded Cache，增加每周期的并发读个数，增加执行通道，增加ROB， RS，Read & Write buffer等等，这些主要是为了增加IPC，当然增加core数量也是提升整体性能的王道。另外就是优化指令所需要的时钟周期、增加并行度更好的指令等等指令集相关的优化。

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/main-qimg-7a34de25ee9d09ba88a1671d22d4b0f1.jpeg)

the industry came up with many different solution to create better computers w/o (or almost without) increasing the clock speed.

Intel 最新的CPU Ice Lake(8380)和其上一代(8280)的性能对比数据：

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/intel-ice-lake-sunny-cove-core-table.jpg)

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/Intel-Ice-Lake-3rd-Gen-Xeon-overview-slide.png)

上图最终结果导致了IPC提升了20%

> But tock Intel did with the [Ice Lake](https://www.nextplatform.com/2021/04/19/deep-dive-into-intels-ice-lake-xeon-sp-architecture/) processors and their Sunny Cove cores, and the tock, at 20 percent instructions per clock (IPC) improvement on integer work


![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/intel-ice-lake-ipc-over-time.jpg)

ICE Lake在网络转发上的延时更小、更稳定了：

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/intel-ice-lake-sunny-cove-dpdk-latency.jpg)

[两代CPU整体性能差异](https://wccftech.com/intel-unveils-ice-lake-sp-xeon-cpu-family-10nm-sunny-cove-cores-28-core-die/)：

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/Intel-Ice-Lake-improved-perf-per-core-April-2021.png)

### 指令集优化

新增等效于某种常见指令组合的指令。原来多个指令执行需要多个时钟周期，合并后的单条指令可以在一个时钟周期执行完成。例如FMA指令，就是一条指令计算A×B+C，而无需分两个时钟周期计算。这种指令一般来说现有程序直接就能用上，无需优化。限制在于只对特定代码有效，还是以FMA为例，更普遍的普通加法、乘法运算都不能从中获益。

#### AVX(Advanced Vector Extension，高级矢量扩展指令集)

英特尔在1996年率先引入了MMX（Multi Media eXtensions）多媒体扩展指令集，也开创了**SIMD**（Single Instruction Multiple Data，单指令多数据）指令集之先河，即在一个周期内一个指令可以完成多个数据操作，MMX指令集的出现让当时的MMX Pentium处理器大出风头。

**SSE**（Streaming SIMD Extensions，流式单指令多数据扩展）指令集是1999年英特尔在Pentium III处理器中率先推出的，并将矢量处理能力从64位扩展到了128位。

AVX 所代表的单指令多数据（Single Instruction Multi Data，SIMD）指令集，是近年来 CPU 提升 IPC（每时钟周期指令数）上为数不多的重要革新。随着每次数据宽度的提升，CPU 的性能都会大幅提升，但同时晶体管数量和能耗也会有相应的提升。因此在对功耗有较高要求的场景，如笔记本电脑或服务器中，CPU 运行 AVX 应用时需要降低频率从而降低功耗。

> 2013 年， 英特尔 发布了**AVX**-**512 指令**集，其**指令**宽度扩展为512bit，每个时钟周期内可打包32 次双精度或64 次单精度浮点运算，因此在图像/ 音视频处理、数据分析、科学计算、数据加密和压缩和 深度学习 等应用场景中，会带来更强大的性能表现，理论上浮点性能翻倍，整数计算则增加约33% 的性能。


Linus Torvalds ：

> AVX512 有很明显的缺点。我宁愿看到那些晶体管被用于其他更相关的事情。即使同样是用于进行浮点数学运算（通过 GPU 来做，而不是通过 AVX512 在 CPU 上），或者直接给我更多的核心（有着更多单线程性能，而且没有 AVX512 这样的垃圾），就像 AMD 所做的一样。
> 
> 我希望通过常规的整数代码来达到自己能力的极限，而不是通过 AVX512 这样的功率病毒来达到最高频率（因为人们最终还是会拿它来做 memory-to-memory copy），还占据了核心的很大面积。


所以今天的2.6G单核skylake，能秒掉20年前2.6G的酷睿, 尤其是复杂场景。

![image-20210715094527563](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/image-20210715094527563.png)

![image-20210715094637227](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/image-20210715094637227.png)

CPU能耗公式：

> P = C V*V * f


C是常数，f就是频率，V 电压。 f频率加大后因为充放电带来的Gate Delay，也就是频率增加，充放电时间短，为了保证信号的完整性就一定要增加电压来加快充放电。

所以最终能耗和f频率是 f^3 的指数关系。

即使不考虑散热问题，Core也没法做到无限大，目前光刻机都有最大加工尺寸限制。光刻机加工的最大尺寸，一般是 858mm²，而 Cerebras 和台积电紧密合作，做了一个 46255mm²，1.2T 个晶体管的世界第一大芯片。这也是超摩尔定律的一个突破。

![image-20210715100609552](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/image-20210715100609552.png)

**主频=外频×倍频系数**

不只是CPU需要一个切换频率，像GPU、cache、内存都需要一个外频来指导他们的电压脉冲的切换频率。CPU的发展比其它设备快，所以没法统一一个，于是就各自在外频的基础上X倍频系数。

超频：认为加大CPU的倍频系数，切换变快以后最大的问题是电容在短时间内充电不完整，这样导致信号失真，所以一般配套需要增加电压（充电更快），带来的后果是温度更高。

睿频：大多时候多核用不上，如果能智能地关掉无用的核同时把这些关掉的核的电源累加到在用的核上（通过增加倍频来实现），这样单核拥有更高的主频。也就是把其它核的电源指标和发热指标给了这一个核来使用。

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/1000.jpeg)

## 多core通讯和NUMA

### uma下cpu访问内存

早期core不多统一走北桥总线访问内存，对所有core时延统一

![x86 UMA](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/numa-fsb-3.png)

### NUMA

如下图，左右两边的是内存条，每个NUMA的cpu访问直接插在自己CPU上的内存必然很快，如果访问插在其它NUMA上的内存条还要走QPI，所以要慢很多。

![undefined](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/1620954546311-096702b9-9929-4f47-8811-dc4d08829f31.png)

如上架构是4路CPU，每路之间通过QPI相连，每个CPU内部8core用的是双Ring Bus相连，Memory Control Hub集成到了Die里面。一路CPU能连4个SMB，每个SMB有两个channel，每个channel最多接三个内存条（图中只画了2个）。

**快速通道互联**[[1]](https://zh.wikipedia.org/wiki/%E5%BF%AB%E9%80%9F%E9%80%9A%E9%81%93%E4%BA%92%E8%81%94#cite_note-1)[[2]](https://zh.wikipedia.org/wiki/%E5%BF%AB%E9%80%9F%E9%80%9A%E9%81%93%E4%BA%92%E8%81%94#cite_note-2)（英语：Intel **Q**uick**P**ath **I**nterconnect，[缩写](https://zh.wikipedia.org/wiki/%E7%B8%AE%E5%AF%AB)：**QPI**）[[3]](https://zh.wikipedia.org/wiki/%E5%BF%AB%E9%80%9F%E9%80%9A%E9%81%93%E4%BA%92%E8%81%94#cite_note-Intel_QPI-3)[[4]](https://zh.wikipedia.org/wiki/%E5%BF%AB%E9%80%9F%E9%80%9A%E9%81%93%E4%BA%92%E8%81%94#cite_note-4)，是一种由英特尔开发并使用的点对点处理器互联架构，用来实现CPU之间的互联。英特尔在2008年开始用QPI取代以往用于[至强](https://zh.wikipedia.org/wiki/Intel_Xeon)、[安腾](https://zh.wikipedia.org/wiki/Intel_Itanium)处理器的[前端总线](https://zh.wikipedia.org/wiki/%E5%89%8D%E7%AB%AF%E5%8C%AF%E6%B5%81%E6%8E%92)（[FSB](https://zh.wikipedia.org/wiki/FSB)），**用来实现芯片之间的直接互联，而不是再通过FSB连接到北桥**。Intel于2017年发布的SkyLake-SP Xeon中，用UPI（**U**ltra**P**ath **I**nterconnect）取代QPI。

#### Ring Bus

2012年英特尔发布了业界期待已久的Intel Sandy Bridge架构至强E5-2600系列处理器。该系列处理器采用 Intel Sandy Bridge微架构和32nm工艺，与前一代的至强5600系列相比，具有更多的内核、更大的缓存、更多的内存通道，Die内采用的是Ring Bus。

Ring Bus设计简单，双环设计可以保证任何两个ring stop之间距离不超过Ring Stop总数的一半，延迟控制在60ns，带宽100G以上，但是core越多，ring bus越长性能下降迅速，在12core之后性能下降明显。

于是采用如下两个Ring Bus并列，然后再通过双向总线把两个Ring Bus连起来。

在至强HCC(High Core Count, 核很多版)版本中，又加入了一个ring bus。两个ring bus各接12个Core，将延迟控制在可控的范围内。俩个Ring Bus直接用两个双向Pipe Line连接，保证通讯顺畅。与此同时由于Ring 0中的模块访问Ring 1中的模块延迟明显高于本Ring，亲缘度不同，所以两个Ring分属于不同的NUMA（Non-Uniform Memory Access Architecture）node。这点在BIOS设计中要特别注意。

![Intel Xeon E5-2600 V4 High Core Count Die](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/Intel-Xeon-E5-2600-V4-High-Core-Count-Die.png)

或者这个更清晰点的图：

![03-05-Broadwell_HCC_Architecture](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/03-05-Broadwell_HCC_Architecture.svg)

#### [Mesh网络](https://www.servethehome.com/the-new-intel-mesh-interconnect-architecture-and-platform-implications/)

Intel在Skylake和Knight Landing中引入了新的片内总线：Mesh。它是一种2D的Mesh网络：

![Intel Skylake SP Mesh Architecture Conceptual Diagram](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/Intel-Skylake-SP-Mesh-Architecture-Conceptual-Diagram.png)

![undefined](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/1620956208262-c20677c5-8bf5-4cd4-81c6-1bf492159394.png)

一个skylake 28core die的实现：

![Skylake SP 28 Core Die Mesh](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/Skylake-SP-28-Core-Die-Mesh-800x666.jpg)

Mesh网络引入片内总线是一个巨大的进步，它有很多优点：

1.  首先当然是灵活性。新的模块或者节点在Mesh中增加十分方便，它带来的延迟不是像ring bus一样线性增加，而是非线性的。从而可以容纳更多的内核。
1.  设计弹性很好，不需要1.5 ring和2ring的委曲求全。
1.  双向mesh网络减小了两个node之间的延迟。过去两个node之间通讯，最坏要绕过半个ring。而mesh整体node之间距离大大缩减。
1.  外部延迟大大缩短

RAM延迟大大缩短：

![Broadwell Ring V Skylake Mesh DRAM Example](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/Broadwell-Ring-v-Skylake-Mesh-DRAM-Example-696x272.jpg)

上图左边的是ring bus，从一个ring里面访问另一个ring里面的内存控制器。最坏情况下是那条绿线，拐了一个大圈才到达内存控制器，需要310个cycle。而在Mesh网络中则路径缩短很多。

Mesh网络带来了这么多好处，那么缺点有没有呢？网格化设计带来复杂性的增加，从而对Die的大小带来了负面影响

CPU的总线为铜薄膜，虽然摩尔定律使单位面积晶体管的密度不断增加，但是对于连接导线的电阻却没有明显的下降，导线的RC延迟几乎决定现有CPU性能，因此数据传输在CPU的角度来看是个极为沉重的负担。 虽然2D-mesh为数据提供了更多的迁移路径减少了数据堵塞，但也同样为数据一致性带来更多问题，例如过去ring-bus 结构下对于存在于某个CPU私用缓存的数据争抢请求只有两个方向（左和右）， 但是在2D-mesh环境下会来自于4个方向（上，下，左，右）

![image-20210602104851803](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/image-20210602104851803.png)

### uncore

"**Uncore**" is a term used by [Intel](https://en.wikipedia.org/wiki/Intel) to describe the functions of a [microprocessor](https://en.wikipedia.org/wiki/Microprocessor) that are not in the core, but which must be closely connected to the core to achieve high performance.[[1]](https://en.wikipedia.org/wiki/Uncore#cite_note-modular_uncore-1) It has been called "**system agent**" since the release of the [Sandy Bridge](https://en.wikipedia.org/wiki/Sandy_Bridge) [microarchitecture](https://en.wikipedia.org/wiki/Microarchitecture).[[2]](https://en.wikipedia.org/wiki/Uncore#cite_note-sandybridge-2)

The core contains the components of the processor involved in executing instructions, including the [ALU](https://en.wikipedia.org/wiki/Arithmetic_logic_unit), [FPU](https://en.wikipedia.org/wiki/Floating_point_unit), [L1](https://en.wikipedia.org/wiki/L1_cache) and [L2 cache](https://en.wikipedia.org/wiki/L2_cache). Uncore functions include [QPI](https://en.wikipedia.org/wiki/Intel_QuickPath_Interconnect) controllers, [L3 cache](https://en.wikipedia.org/wiki/L3_cache), [snoop agent](https://en.wikipedia.org/wiki/Memory_coherence) [pipeline](https://en.wikipedia.org/wiki/Instruction_pipeline), on-die [memory controller](https://en.wikipedia.org/wiki/Memory_controller), on-die [PCI Express Root Complex](https://en.wikipedia.org/wiki/PCI_Express_Root_Complex), and [Thunderbolt controller](https://en.wikipedia.org/wiki/Thunderbolt_(interface)).[[3]](https://en.wikipedia.org/wiki/Uncore#cite_note-thunderbolt-3) Other bus controllers such as [SPI](https://en.wikipedia.org/wiki/Serial_Peripheral_Interface_Bus) and [LPC](https://en.wikipedia.org/wiki/Low_Pin_Count) are part of the [chipset](https://en.wikipedia.org/wiki/Chipset).[[4]](https://en.wikipedia.org/wiki/Uncore#cite_note-Anandtech:_Nehalem:_The_Unwritten_Chapters-4)

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

![Intel processor roadmap](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/neweditor/94d79c38-b577-4d31-b40c-fbec4cdc5f2e.png)

2006年90、65纳米工艺酷睿core Yonah上市，32位架构，仍然算是奔腾Pro系列；

2006年7月[酷睿2](https://zh.wikipedia.org/wiki/%E9%85%B7%E7%9D%BF2)处理器代号为“[Conroe](https://zh.wikipedia.org/w/index.php?title=Conroe&amp;action=edit&amp;redlink=1)”，采用[x86-64](https://zh.wikipedia.org/wiki/X86-64)指令集与65纳米双核心架构。该处理器基于全新的酷睿微架构，虽然时脉大大降低，但在效率方面和性能方面有了重大改进。从这一时期开始，在深度流水线和资源混乱的运行引擎上维持每个周期的高指令（IPC）

2008年的 Nehalem （酷睿i7）是采用 45nm 工艺的新架构，主要优势来自重新设计的I/O和存储系统，这些系统具有新的Intel QuickPath Interconnect和集成的内存控制器，可支持三通道的DDR3内存。

2009年的 Westmere 升级到 32nm；

2010年的 Lynnfield/Clarkdale 基于 45nm/32nm 工艺的新架构，第一代智能酷睿处理器；

2011年的 Sandy Bridge ，基于 32nm 工艺的新架构，第二代智能酷睿处理器，增加AVX指令集扩展， 对虚拟化提供更好支持；

2012年的 IVY Bridge，是 Sandy Bridge 的 22nm 升级版，第三代智能酷睿处理器；

2013年的 Haswell ，基于 22nm 工艺的新架构，第四代智能酷睿处理器；

2014年的 Broadwell，是 Haswell 的 14nm 升级版，第五代智能酷睿处理器；

2015年则推出 SkyLake，基于 14nm 工艺的新架构；

Core 架构代号是 Yonah，把 NetBurst 做深了的流水线级数又砍下来了，主频虽然降下来了（而且即使后来工艺提升到 45nm 之后也没有超过 NetBurst 的水平），但是却提高了整个流水线中的资源利用率，所以性能还是提升了；把奔腾 4 上曾经用过的超线程也砍掉了；对各个部分进行了强化，双核共享 L2 cache 等等。

从 Core 架构开始是真的走向多核了，就不再是以前 “胶水粘的” 伪双核了，这时候已经有最高 4 核的处理器设计了。

Core 从 65nm 改到 45nm 之后，基于 45nm 又推出了新一代架构叫 Nehalem，新架构Nehalem**采用 Intel QPI 来代替原来的前端总线**，**PCIE 和 DMI 控制器直接做到片内了**，不再需要北桥。

**Sandy Bridge 引入核间的ring bus**

感觉Broadwell前面这几代都是在优化cache、通信；接下来的Broadwell和SkyLake就开始改进不大了，疯狂挤牙膏（唯一比较大的改进就是**Ring bus到Mesh**）

![image-20210602154509596](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/image-20210602154509596.png)

### 不同的架构下的参数

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/e4a2fb522be7aa65158778b7ea825207.png)

## UEFI和Bios

**UEFI**，全称Unified Extensible Firmware Interface，即“统一的可扩展固件接口”，是一种详细描述全新类型接口的标准，是适用于电脑的标准固件接口，旨在代替BIOS（基本输入/输出系统）

电脑中有一个BIOS设置，它主要负责开机时检测硬件功能和引导操作系统启动的功能。而UEFI则是用于操作系统自动从预启动的操作环境，加载到一种操作系统上从而节省开机时间。

UEFI启动是一种新的主板引导项，它被看做是bios的继任者。UEFI最主要的特点是图形界面，更利于用户对象图形化的操作选择。

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/webp)

UEFI 图形界面：

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/webp-20210601102242967)

简单的来说UEFI启动是新一代的BIOS，功能更加强大，而且它是以图形图像模式显示，让用户更便捷的直观操作。

如今很多新产品的电脑都支持UEFI启动模式，甚至有的电脑都已抛弃BIOS而仅支持UEFI启动。这不难看出UEFI正在取代传统的BIOS启动。

UEFI固件通过ACPI报告给OS NUMA的组成结构，其中最重要的是SRAT（System Resource Affinity Table）和SLIT（System Locality Information Table）表。

## socket

socket对应主板上的一个插槽，也可以简单理解为一块物理CPU。同一个socket对应着 /proc/cpuinfo 里面的physical id一样。

一个socket至少对应着一个或多个node/NUMA

## GPU

GPU只处理有限的计算指令（主要是浮点运算--矩阵操作），不需要分支预测、乱序执行等，所以将Core里面的电路简化（如下图左边），同时通过SIMT（Single Instruction，Multiple Threads， 类似 SIMD）在取指令和指令译码的阶段，取出的指令可以给到后面多个不同的 ALU 并行进行运算。这样，我们的一个 GPU 的核里，就可以放下更多的 ALU，同时进行更多的并行运算了（如下图右边） 。 在 SIMD 里面，CPU 一次性取出了固定长度的多个数据，放到寄存器里面，用一个指令去执行。**而 SIMT，可以把多条数据，交给不同的线程去处理。**

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/3d7ce9c053815f6a32a6fbf6f7fb9628.jpeg)

GPU的core在流水线stall的时候和超线程一样，可以调度别的任务给ALU，既然要调度一个不同的任务过来，我们就需要针对这个任务，提供更多的执行上下文。所以，一个 Core 里面的执行上下文的数量，需要比 ALU 多。

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/c971c34e0456dea9e4a87857880bb5b8.jpeg)

在通过芯片瘦身、SIMT 以及更多的执行上下文，我们就有了一个更擅长并行进行暴力运算的 GPU。这样的芯片，也正适合我们今天的深度学习和挖矿的场景。

NVidia 2080 显卡的技术规格，就可以算出，它到底有多大的计算能力。2080 一共有 46 个 SM（Streaming Multiprocessor，流式处理器），这个 SM 相当于 GPU 里面的 GPU Core，所以你可以认为这是一个 46 核的 GPU，有 46 个取指令指令译码的渲染管线。每个 SM 里面有 64 个 Cuda Core。你可以认为，这里的 Cuda Core 就是我们上面说的 ALU 的数量或者 Pixel Shader 的数量，46x64 呢一共就有 2944 个 Shader。然后，还有 184 个 TMU，TMU 就是 Texture Mapping Unit，也就是用来做纹理映射的计算单元，它也可以认为是另一种类型的 Shader。

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/14d05a43f559cecff2b0813e8d5bdde2.png)

2080 的主频是 1515MHz，如果自动超频（Boost）的话，可以到 1700MHz。而 NVidia 的显卡，根据硬件架构的设计，每个时钟周期可以执行两条指令。所以，能做的浮点数运算的能力，就是：

> （2944 + 184）× 1700 MHz × 2  = 10.06  TFLOPS


最新的 Intel i9 9900K 的性能是多少呢？不到 1TFLOPS。而 2080 显卡和 9900K 的价格却是差不多的。所以，在实际进行深度学习的过程中，用 GPU 所花费的时间，往往能减少一到两个数量级。而大型的深度学习模型计算，往往又是多卡并行，要花上几天乃至几个月。这个时候，用 CPU 显然就不合适了。

### [为什么GPU比CPU快](https://medium.com/@shachishah.ce/do-we-really-need-gpu-for-deep-learning-47042c02efe2#:~:text=Bandwidth%20is%20one%20of%20the,be%20used%20for%20other%20tasks.)

GPU拥有更多的计算单元

GPU像是大卡车，每次去内存取数据取得多，但是Latency高（AP）；CPU像是法拉利，更在意处理速度而不是一次处理很多数据，所以CPU有多级cache，都是围绕速度在优化（TP）。在GPU中取数据和处理是流水线所以能消除高Latency。

GPU的每个core拥有更小更快的cache和registry，但是整个GPU的registry累加起来能比CPU大30倍，同时带宽也是后者的16倍

![image-20210615105019238](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/image-20210615105019238.png)

总之GPU相对于CPU像是一群小学生和一个大学教授一起比赛计算10以内的加减法。

### 英伟达的GPU出圈

2016年之前英伟达的营收和是指基本跟intel一致，但是2021 年 4 月中旬的数字，Intel 是英伟达的近 5 倍，但是如果论市值，英伟达是 Intel 的 1.5 倍。

**GPGPU：点亮并行计算的科技树**

2007 年，英伟达首席科学家 David Kirk 非常前瞻性地提出 GPGPU 的概念，把英伟达和 GPU 从单纯图形计算拓展为通用计算，强调并行计算，鼓励开发者用 GPU 做计算，而不是局限在图形加速这个传统的领域。GPGPU，前面这个 GP，就是 General Purpose 通用的意思。

CUDA（Compute Unified Device Architecture，统一计算架构），CUDA 不仅仅是一个 GPU 计算的框架，它对下抽象了所有的英伟达出品的 GPU，对上构建了一个通用的编程框架，它实质上制定了一个 GPU 和上层软件之间的接口标准。

在 GPU 市场的早期竞争中，英伟达认识到软硬件之间的标准的重要性，花了 10 年苦功，投入 CUDA 软件生态建设，把软硬件之间的标准，变成自己的核心竞争力。

英伟达可以说是硬件公司中软件做得最好的。同样是生态强大，Wintel 的生态是微软帮忙建的，ARM-Android 的生态是 Google 建的，而 GPU-CUDA 的生态是英伟达自建的。

这个标准有多重要？这么说吧，一流企业定标准，二流企业做品牌，三流企业做产品。在所有的半导体公司中，制定出软件与硬件之间的标准，而且现在还算成功的，只有 3 个，一个是 x86 指令集，一个是 ARM 指令集，还有一个就是 CUDA 了。

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/313d469d57e6b92eyy03dee63614a72c.png)

GPU 相对 CPU 的 TOPS per Watt（花费每瓦特电能可以获得的算力）的差异竞争优势，它的本质就是将晶体管花在计算上，而不是逻辑判断上

2020 年超级计算机 TOP500 更新榜单，可以看到 TOP10 的超级计算机中有 8 台采用了英伟达 GPU、InfiniBand 网络技术，或同时采用了两种技术。TOP500 榜单中，有 333 套（三分之二）采用了英伟达的技术。

挖矿和深度学习撑起了英伟达的市值。

## 现场可编程门阵列FPGA（Field-Programmable Gate Array）

设计芯片十分复杂，还要不断验证。

那么不用单独制造一块专门的芯片来验证硬件设计呢？能不能设计一个硬件，通过不同的程序代码，来操作这个硬件之前的电路连线，通过“编程”让这个硬件变成我们设计的电路连线的芯片呢？这就是FPGA

-   P 代表 Programmable，这个很容易理解。也就是说这是一个可以通过编程来控制的硬件。
-   G 代表 Gate 也很容易理解，它就代表芯片里面的门电路。我们能够去进行编程组合的就是这样一个一个门电路。
-   A 代表的 Array，叫作阵列，说的是在一块 FPGA 上，密密麻麻列了大量 Gate 这样的门电路。
-   最后一个 F，不太容易理解。它其实是说，一块 FPGA 这样的板子，可以在“现场”多次进行编程。它不像 PAL（Programmable Array Logic，可编程阵列逻辑）这样更古老的硬件设备，只能“编程”一次，把预先写好的程序一次性烧录到硬件里面，之后就不能再修改了。

FPGA 通过“软件”来控制“硬件”

## 专用集成电路ASIC（Application-Specific Integrated Circuit）

为解决特定应用问题而定制设计的集成电路，就是 ASIC（Application Specific IC）。当 ASIC 规模够大，逐渐通用起来，某类 ASIC 就会有一个专有名称，成为一个品类。例如现在用来解决人工智能问题的神经网络处理器。

除了 CPU、GPU，以及刚刚的 FPGA，我们其实还需要用到很多其他芯片。比如，现在手机里就有专门用在摄像头里的芯片；录音笔里会有专门处理音频的芯片。尽管一个 CPU 能够处理好手机拍照的功能，也能处理好录音的功能，但是我们直接在手机或者录音笔里塞上一个 Intel CPU，显然比较浪费。

因为 ASIC 是针对专门用途设计的，所以它的电路更精简，单片的制造成本也比 CPU 更低。而且，因为电路精简，所以通常能耗要比用来做通用计算的 CPU 更低。而我们上一讲所说的早期的图形加速卡，其实就可以看作是一种 ASIC。

因为 ASIC 的生产制造成本，以及能耗上的优势，过去几年里，有不少公司设计和开发 ASIC 用来“挖矿”。这个“挖矿”，说的其实就是设计专门的数值计算芯片，用来“挖”比特币、ETH 这样的数字货币。

如果量产的ASIC比较小的话可以直接用FPGA来实现

## 张量处理器TPU （tensor processing unit）

**张量处理器**（英语：tensor processing unit，缩写：TPU）是[Google](https://baike.baidu.com/item/Google)为[机器学习](https://baike.baidu.com/item/%E6%9C%BA%E5%99%A8%E5%AD%A6%E4%B9%A0)定制的专用芯片（ASIC），专为Google的[深度学习](https://baike.baidu.com/item/%E6%B7%B1%E5%BA%A6%E5%AD%A6%E4%B9%A0)框架[TensorFlow](https://baike.baidu.com/item/TensorFlow)而设计。

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

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/997341ed0fa9018561c7120c19cfa2a7.jpg)

**虚拟内存地址**：应用代码可执行地址必须是连续，这也就意味着一个应用的内存地址必须连续，实际一个OS上会运行多个应用，没办法保证地址连续，所以可以通过虚拟地址来保证连续，虚拟地址再映射到实际零散的物理地址上（可以解决碎片问题），这个零散地址的最小组织形式就是Page。虚拟地址本来是连续的，使用一阵后数据部分也会变成碎片，代码部分是不可变的，一直连续。另外虚拟地址也方便了OS层面的库共享。

为了扩大虚拟地址到物理地址的映射范围同时又要尽可能少地节约空间，虚拟地址到物理地址的映射一般分成了四级Hash，这样4Kb就能管理256T内存。但是带来的问题就是要通过四次查找使得查找慢，这时引入TLAB来换成映射关系。

**共享库**：在 Windows 下，这些共享库文件就是.dll 文件，也就是 Dynamic-Link Libary（DLL，动态链接库）。在 Linux 下，这些共享库文件就是.so 文件，也就是 Shared Object（一般我们也称之为动态链接库). 不同的进程，调用同样的 lib.so，各自 全局偏移表（GOT，Global Offset Table） 里面指向最终加载的动态链接库里面的虚拟内存地址是不同的, 各个程序各自维护好自己的 GOT，能够找到对应的动态库就好了, 有点像函数指针。

![img](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/CPU的制造和概念/1144d3a2d4f3f4f87c349a93429805c8.jpg)

符号表：/boot/System.map 和 /proc/kallsyms

**超线程（Hyper-Threading）**: 在CPU内部增加寄存器等硬件设施，但是ALU、译码器等关键单元还是共享。在一个物理 CPU 核心内部，会有双份的 PC 寄存器、指令寄存器乃至条件码寄存器。超线程的目的，是在一个线程 A 的指令，在流水线里停顿的时候，让另外一个线程去执行指令。因为这个时候，CPU 的译码器和 ALU 就空出来了，那么另外一个线程 B，就可以拿来干自己需要的事情。这个线程 B 可没有对于线程 A 里面指令的关联和依赖。

## 总结

Wafer：晶圆，一片大的纯硅圆盘，新闻里常说的12寸、30寸晶圆厂说的就是它，光刻机在晶圆上蚀刻出电路

Die：从晶圆上切割下来的裸片(包含多个core、北桥、GPU等)，Die的大小可以自由决定，得考虑成本和性能, Die做成方形便于切割和测试

封装：将一个或多个Die封装成一个物理上可以售卖的CPU

路：就是socket、也就是封装后的物理CPU

node：同一个Die下的多个core以及他们对应的内存，对应着NUMA

现在计算机系统的CPU和芯片组内核Die都是先封装到一个印制板上（PCB，printed circuit board），再通过LGA等等插槽（Socket）连上主板或直接焊接在主板上。这个过程叫做封装（Package），相关技术叫做封装技术。

## 系列文章

[CPU的制造和概念](/2021/06/01/CPU%E7%9A%84%E5%88%B6%E9%80%A0%E5%92%8C%E6%A6%82%E5%BF%B5/)

[CPU 性能和Cache Line](/2021/05/16/CPU Cache Line 和性能/)

[Perf IPC以及CPU性能](/2021/05/16/Perf IPC以及CPU利用率/)

[Intel、海光、鲲鹏920、飞腾2500 CPU性能对比](/2021/06/18/%E5%87%A0%E6%AC%BECPU%E6%80%A7%E8%83%BD%E5%AF%B9%E6%AF%94/)

[飞腾ARM芯片(FT2500)的性能测试](/2021/05/15/%E9%A3%9E%E8%85%BEARM%E8%8A%AF%E7%89%87(FT2500)%E7%9A%84%E6%80%A7%E8%83%BD%E6%B5%8B%E8%AF%95/)

[十年后数据库还是不敢拥抱NUMA？](/2021/05/14/%E5%8D%81%E5%B9%B4%E5%90%8E%E6%95%B0%E6%8D%AE%E5%BA%93%E8%BF%98%E6%98%AF%E4%B8%8D%E6%95%A2%E6%8B%A5%E6%8A%B1NUMA/)

[一次海光物理机资源竞争压测的记录](/2021/03/07/%E4%B8%80%E6%AC%A1%E6%B5%B7%E5%85%89%E7%89%A9%E7%90%86%E6%9C%BA%E8%B5%84%E6%BA%90%E7%AB%9E%E4%BA%89%E5%8E%8B%E6%B5%8B%E7%9A%84%E8%AE%B0%E5%BD%95/)

[Intel PAUSE指令变化是如何影响自旋锁以及MySQL的性能的](/2019/12/16/Intel PAUSE指令变化是如何影响自旋锁以及MySQL的性能的/)



Reference:

