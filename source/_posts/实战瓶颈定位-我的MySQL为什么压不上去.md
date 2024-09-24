---
title: 实战瓶颈定位-我的MySQL为什么压不上去
date: 2023-06-20 17:30:03
categories:
    - performance
tags:
    - MySQL
    - sysbench
    - network
---

# 实战瓶颈定位-我的MySQL为什么压不上去



## 背景

环境两台云上相同 128C的EC2(有点豪)，一台当压力机一台当服务器，用Sysbench测试MySQL纯读场景，不存在任何修改，也就几乎没有锁

```
#uname -r
5.10.84.aarch64

Server:            MySQL
Server version:        8.0.18 Source distribution
```

EC2机器128核，故意只给MySQLD绑定了其中的24Core，网卡32队列

```
#ethtool -l eth0
Channel parameters for eth0:
Pre-set maximums:
RX:        0
TX:        0
Other:        0
Combined:    32
Current hardware settings:
RX:        0
TX:        0
Other:        0
Combined:    32
```

![img](/images/951413iMgBlog/FlDlXFTuGa0BPv1YxR3KQZaP40de.png)





## 压测过程

走同一交换机内网IP压MySQL跑不满CPU，跑压力和不跑压力时ping rtt 分别是 0.859/0.053(RTT 有增加--注意点), 此时TPS：119956.67 1000并发 RT 8.33

下图是压测时 htop 看到的MySQLD 所在EC2的 CPU使用情况，右边65-88是MySQLD进程(绿色表示us, 红色表示sys+si CPU)

![image-20230511125934259](/images/951413iMgBlog/image-20230511125934259.png)

用top查看详细的每个 core 使用(只展示MySQLD使用的24core ，top 然后按1--还可以试试2/3，有惊喜)

```
 top - 13:49:55 up 160 days, 18:10,  3 users,  load average: 555.26, 720.12, 462.21
 Tasks: 1065 total,   1 running, 499 sleeping,   0 stopped,   0 zombie
 %Node1 : 10.1 us,  5.3 sy,  0.0 ni, 83.3 id,  0.0 wa,  0.0 hi,  1.3 si,  0.0 st
 %Cpu64 : 29.3 us, 16.5 sy,  0.0 ni, 54.2 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
 %Cpu65 : 37.0 us, 18.5 sy,  0.0 ni, 26.9 id,  0.0 wa,  0.0 hi, 17.5 si,  0.0 st
 %Cpu66 : 34.2 us, 17.8 sy,  0.0 ni, 47.9 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
 %Cpu67 : 26.0 us, 15.1 sy,  0.0 ni, 58.9 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
 %Cpu68 : 26.1 us, 14.8 sy,  0.0 ni, 59.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
 %Cpu69 : 27.2 us, 13.8 sy,  0.0 ni, 59.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
 %Cpu70 : 25.7 us, 11.8 sy,  0.0 ni, 62.5 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
 %Cpu71 : 18.3 us, 10.6 sy,  0.0 ni, 71.1 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
 %Cpu72 : 29.7 us, 12.6 sy,  0.0 ni, 57.7 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
 %Cpu73 : 21.2 us, 13.0 sy,  0.0 ni, 65.9 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
 %Cpu74 : 18.9 us, 10.8 sy,  0.0 ni, 70.4 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
 %Cpu75 : 28.9 us, 15.1 sy,  0.0 ni, 36.1 id,  0.0 wa,  0.0 hi, 19.9 si,  0.0 st
 %Cpu76 : 30.3 us, 15.5 sy,  0.0 ni, 54.1 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
 %Cpu77 : 25.1 us, 13.2 sy,  0.0 ni, 61.7 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
 %Cpu78 : 18.2 us, 10.3 sy,  0.0 ni, 71.5 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
 %Cpu79 : 14.9 us,  8.8 sy,  0.0 ni, 76.3 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
 %Cpu80 : 23.4 us, 12.2 sy,  0.0 ni, 64.4 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
 %Cpu81 : 35.3 us, 17.6 sy,  0.0 ni, 30.2 id,  0.0 wa,  0.0 hi, 16.9 si,  0.0 st
 %Cpu82 : 28.2 us, 16.1 sy,  0.0 ni, 55.7 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
 %Cpu83 : 37.5 us, 16.9 sy,  0.0 ni, 27.0 id,  0.0 wa,  0.0 hi, 18.6 si,  0.0 st
 %Cpu84 : 35.4 us, 18.5 sy,  0.0 ni, 46.1 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
 %Cpu85 : 27.9 us, 16.8 sy,  0.0 ni, 55.2 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
 %Cpu86 : 28.2 us, 13.7 sy,  0.0 ni, 58.1 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
 %Cpu87 : 27.2 us, 11.0 sy,  0.0 ni, 61.8 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
 %Cpu88 :  0.0 us,  0.0 sy,  0.0 ni,100.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
```

继续尝试用2000并发，TPS、CPU、ping rtt都和1000并发没有区别，当然按照我们以前QPS、RT理论2000并发的时候RT应该翻倍，实际确实是16.66，**所以这里的问题就是翻倍的 RT哪里来的瓶颈就在哪里**。

也试过用两个压力机每个压力机分别用1000并发同时压，QPS一样稳定——目的快速排除压力端、链路上有瓶颈。

写到这里RT 刚好翻倍16.66=8.33*2 数字精准得好像编故事一样，不得不贴一下原始数据证实一下：

![image-20230511130851332](/images/951413iMgBlog/image-20230511130851332.png)

1000 并发和2000并发时的ping RTT对比(ttl 64说明内网直达)

```
#ping mysqld27
PING yt27 (mysqld217) 56(84) bytes of data.
---以下是2000并发
64 bytes from mysqld27 (mysqld217): icmp_seq=1 ttl=64 time=0.867 ms
64 bytes from mysqld27 (mysqld217): icmp_seq=2 ttl=64 time=0.952 ms
64 bytes from mysqld27 (mysqld217): icmp_seq=3 ttl=64 time=0.849 ms
64 bytes from mysqld27 (mysqld217): icmp_seq=4 ttl=64 time=0.857 ms
64 bytes from mysqld27 (mysqld217): icmp_seq=5 ttl=64 time=0.987 ms
64 bytes from mysqld27 (mysqld217): icmp_seq=6 ttl=64 time=0.860 ms
64 bytes from mysqld27 (mysqld217): icmp_seq=7 ttl=64 time=0.909 ms
64 bytes from mysqld27 (mysqld217): icmp_seq=8 ttl=64 time=0.875 ms
64 bytes from mysqld27 (mysqld217): icmp_seq=9 ttl=64 time=0.979 ms  
---终止压测，无无压力的rtt
64 bytes from mysqld27 (mysqld217): icmp_seq=10 ttl=64 time=0.104 ms
64 bytes from mysqld27 (mysqld217): icmp_seq=11 ttl=64 time=0.079 ms
64 bytes from mysqld27 (mysqld217): icmp_seq=12 ttl=64 time=0.075 ms
64 bytes from mysqld27 (mysqld217): icmp_seq=13 ttl=64 time=0.075 ms 
64 bytes from mysqld27 (mysqld217): icmp_seq=14 ttl=64 time=0.074 ms
64 bytes from mysqld27 (mysqld217): icmp_seq=15 ttl=64 time=0.078 ms
64 bytes from mysqld27 (mysqld217): icmp_seq=16 ttl=64 time=0.075 ms
---开启1000并发时的rtt
64 bytes from mysqld27 (mysqld217): icmp_seq=17 ttl=64 time=0.872 ms 
64 bytes from mysqld27 (mysqld217): icmp_seq=18 ttl=64 time=0.969 ms
64 bytes from mysqld27 (mysqld217): icmp_seq=19 ttl=64 time=0.862 ms
64 bytes from mysqld27 (mysqld217): icmp_seq=20 ttl=64 time=0.877 ms
64 bytes from mysqld27 (mysqld217): icmp_seq=21 ttl=64 time=0.961 ms
64 bytes from mysqld27 (mysqld217): icmp_seq=22 ttl=64 time=0.828 ms
64 bytes from mysqld27 (mysqld217): icmp_seq=23 ttl=64 time=0.098 ms
64 bytes from mysqld27 (mysqld217): icmp_seq=24 ttl=64 time=0.083 ms
```

### 抓包证明

在抓保证明前推荐一个工具快速绕过抓包(原理也是通过pcap lib去分析网络包，tcpdump也会调用pcap lib)

[监控tcprstat](https://github.com/y123456yz/tcprstat)，从网络层抓包来对比两个并发下的RT：

```
#tcprstat -p 14822 -t 1 -n 0 -l mysqld217 -f "%T\t\t%n\t\t%a\n"
timestamp        count        avg
1683785023        50743        626
1683785024        120004        100
1683785025        120051        103
1683785026        120042        102
1683785027        120031        103
1683785028        120034        104
1683785029        120034        104
1683785030         55209        103    ---以上是2000并发
1683785038        0        0
1683785039        0        0
1683785040         55224        614    ---以下是1000并发
1683785041        119998        104
1683785042        120039        105
1683785043        120039        105
1683785044        120026        107
1683785045        120039        108
1683785046        120047        108
1683785047        120037        108
1683785048        120032        108
1683785049        120041        108
```

也就是网卡层面**确认了压不上去瓶颈不在MySQL** 上，加并发后网卡的RT没变(网卡RT包含MySQLD RT)，因为ping RTT 在1000和2000并发也没有差异，推测交换机不是瓶颈，大概率出网卡的虚拟层面

在客户端的机器上抓包，上面我们说过了1000并发的RT是8.33毫秒：

![image-20230511141508811](/images/951413iMgBlog/image-20230511141508811.png)

注意上图，我把RT排序了，明显看到5ms到17ms 中间没有这个RT范围的包，但是有很多25ms的RT，平均下来确实是8.33毫秒，留下一个疑问：RT分布不符合正态，而且中间有很大一段范围镂空了！这是不应该的。

同样我们再到MySQLD 所在机器抓包分析(注：正常路径先抓MySQLD上的包就行了)：

![image-20230511141925557](/images/951413iMgBlog/image-20230511141925557.png)

同样是对RT 排序了，但是慢的RT都是对端发慢了(注意最右边的select， MySQL相应是 response)，同样对这个抓包求平均时间就是tcprstat 看到的103微秒，也就是0.1毫秒。如下图红框是请求，请求的间隔是11毫米，绿框是响应，响应的间隔都是0.2ms不到

![image-20230513084610300](/images/951413iMgBlog/image-20230513084610300.png)

同样在2000并发时也对MySQLD所在网卡抓包对比，response 的RT 没有变化，从这里可以看出瓶颈点在sysbench 和 MySQLD 的网卡之间的链路上，似乎有限流、管控

<img src="/images/951413iMgBlog/image-20230512084446715.png" alt="image-20230512084446715" style="zoom:35%;" />

### 快速验证

到这里我们已经找到了有力的证据，RT是在离开MySQLD网卡后增加上去的，先验证下走走本机127.0.0.1快速压一把，让sysbench 跑在0-7 core上，这时可以看到MySQL跑满了CPU，下图左边1-8核是压力进程，右边65-88是业务进程，TPS：239969.91 1000并发 RT 4.16

htop状态：

![image-20230511125346066](/images/951413iMgBlog/image-20230511125346066.png)

各CPU 详细分析：

- us MySQL解析SQL、处理查询
- si  网络软中断
- sy OS 的sys API 消耗，一般用户进程会调用系统 API, 比如读写文件、分配内存、网络访问等

```
//sysbench
top - 13:44:27 up 160 days, 18:04,  3 users,  load average: 792.17, 619.09, 311.58
Tasks: 1073 total,   1 running, 500 sleeping,   0 stopped,   0 zombie
%Cpu0  : 14.0 us, 29.1 sy,  0.0 ni, 33.3 id,  0.0 wa,  0.0 hi, 23.5 si,  0.0 st
%Cpu1  : 12.5 us, 33.0 sy,  0.0 ni, 33.7 id,  0.0 wa,  0.0 hi, 20.8 si,  0.0 st
%Cpu2  : 11.2 us, 32.7 sy,  0.0 ni, 34.2 id,  0.0 wa,  0.0 hi, 21.9 si,  0.0 st
%Cpu3  : 13.4 us, 31.2 sy,  0.0 ni, 34.4 id,  0.0 wa,  0.0 hi, 21.0 si,  0.0 st
%Cpu4  : 12.1 us, 31.3 sy,  0.0 ni, 34.2 id,  0.0 wa,  0.0 hi, 22.4 si,  0.0 st
%Cpu5  : 10.5 us, 31.8 sy,  0.0 ni, 33.6 id,  0.0 wa,  0.0 hi, 24.1 si,  0.0 st
%Cpu6  : 12.9 us, 31.3 sy,  0.0 ni, 34.2 id,  0.0 wa,  0.0 hi, 21.6 si,  0.0 st
%Cpu7  : 12.3 us, 31.4 sy,  0.0 ni, 34.3 id,  0.0 wa,  0.0 hi, 22.0 si,  0.0 st
%Cpu8  :  0.0 us,  0.0 sy,  0.0 ni,100.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st

//MySQLD
Tasks: 1073 total,   1 running, 505 sleeping,   0 stopped,   1 zombie
%Node1 : 22.6 us, 10.1 sy,  0.0 ni, 62.4 id,  0.0 wa,  0.0 hi,  4.8 si,  0.0 st
%Cpu64 : 57.9 us, 29.1 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi, 12.9 si,  0.0 st
%Cpu65 : 60.3 us, 26.2 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi, 13.6 si,  0.0 st
%Cpu66 : 57.6 us, 28.1 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi, 14.2 si,  0.0 st
%Cpu67 : 60.9 us, 25.5 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi, 13.6 si,  0.0 st
%Cpu68 : 59.9 us, 26.2 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi, 13.9 si,  0.0 st
%Cpu69 : 57.9 us, 27.5 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi, 14.6 si,  0.0 st
%Cpu70 : 61.3 us, 26.2 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi, 12.6 si,  0.0 st
%Cpu71 : 64.0 us, 23.4 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi, 12.5 si,  0.0 st
%Cpu72 : 61.3 us, 26.8 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi, 11.9 si,  0.0 st
%Cpu73 : 63.0 us, 22.8 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi, 14.2 si,  0.0 st
%Cpu74 : 61.4 us, 27.4 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi, 11.2 si,  0.0 st
%Cpu75 : 63.9 us, 26.5 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  9.6 si,  0.0 st
%Cpu76 : 61.3 us, 27.2 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi, 11.6 si,  0.0 st
%Cpu77 : 55.0 us, 30.5 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi, 14.6 si,  0.0 st
%Cpu78 : 60.9 us, 26.8 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi, 12.3 si,  0.0 st
%Cpu79 : 58.4 us, 26.7 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi, 14.9 si,  0.0 st
%Cpu80 : 58.7 us, 29.0 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi, 12.2 si,  0.0 st
%Cpu81 : 62.6 us, 27.2 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi, 10.3 si,  0.0 st
%Cpu82 : 61.9 us, 25.5 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi, 12.6 si,  0.0 st
%Cpu83 : 58.7 us, 27.4 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi, 13.9 si,  0.0 st
%Cpu84 : 59.4 us, 27.7 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi, 12.9 si,  0.0 st
%Cpu85 : 58.9 us, 28.5 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi, 12.6 si,  0.0 st
%Cpu86 : 58.4 us, 28.4 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi, 13.2 si,  0.0 st
%Cpu87 : 61.1 us, 27.4 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi, 11.6 si,  0.0 st
```

就以上sysbench VS  MySQLD 的CPU 消耗来看，因为sysbench 处理逻辑简单，就是发SQL给MySQLD，所以 sysbench自身US很少，大部分都是调用OS的网络操作，而MySQLD有 60% CPU用于US，也就是自身业务逻辑，MySQLD收到SQL要做SQL解析，要去查找数据，这些都是用户态消耗，找到数据后走网络发给Sysbench，这部分是sy 

到这里可以拿着证据去VIP通道(土豪+专业的客户得有VIP通道)找做网络管控的了，不会再有撕逼和甩锅

### sysbench 结果不是正态分布

把所有请求RT 分布进行图形化，此时平均 RT 8.33，理论上是一个正态分布，下图是有限速时：

```
       3.615 |                                         2177
       3.681 |**                                       14738
       3.748 |*******                                  55690
       3.816 |*************                            109713
       3.885 |***************                          121830
       3.956 |***************                          124851
       4.028 |*******************                      154927
       4.101 |***********************                  188826
       4.176 |***************************              226206
       4.252 |************************************     302617
       4.329 |**************************************** 333310  //这里以4.329为中心符合正态
       4.407 |*******************************          257048
       4.487 |********************                     163100
       4.569 |************                             101785
       4.652 |********                                 63871
       4.737 |*****                                    43998
       4.823 |*****                                    40854
       4.910 |*****                                    42189
       4.999 |*****                                    41182
       5.090 |****                                     35652
       5.183 |****                                     30343
       5.277 |***                                      28573
       5.373 |***                                      24763
       5.470 |***                                      22210
       5.570 |***                                      21808
       5.671 |***                                      25606
       5.774 |***                                      26994
       5.879 |***                                      24672
       5.986 |***                                      22087
       6.095 |**                                       18466
       6.205 |**                                       14822
       6.318 |**                                       13688
       6.433 |**                                       15381
       6.550 |**                                       13573
       6.669 |*                                        11325
       6.790 |*                                        9442
       6.913 |*                                        7412
       省略一大堆
      20.736 |*                                        11407
      21.112 |*                                        9755
      21.496 |*                                        8957
      21.886 |*                                        9434
      22.284 |*                                        9715
      22.689 |**                                       12774
      23.101 |**                                       17000
      23.521 |***                                      22937
      23.948 |*****                                    40401
      24.384 |********                                 65370
      24.827 |**********                               82186
      25.278 |**********                               85505
      25.737 |***********                              94347 //以25.7附近大概又是一个新正态
      26.205 |**********                               82958
      26.681 |****                                     30760
      27.165 |                                         2222
      27.659 |                                         69
      28.162 |                                         16
      28.673 |                                         15
      29.194 |                                         20
      29.725 |                                         17       
```

去掉限速后平均 RT 3.26(比下图中大概的中位数2.71大了不少)  完美正态

```
       1.857 |**                                       19894
       1.891 |***                                      23569
       1.925 |***                                      27912
       1.960 |****                                     33720
       1.996 |****                                     39892
       2.032 |*****                                    48289
       2.069 |******                                   57649
       2.106 |********                                 69437
       2.145 |*********                                83611
       2.184 |***********                              99507
       2.223 |*************                            119275
       2.264 |****************                         141013
       2.305 |*******************                      165450
       2.347 |**********************                   191778
       2.389 |*************************                219706
       2.433 |****************************             250885
       2.477 |*******************************          278379
       2.522 |**********************************       303931
       2.568 |*************************************    325777
       2.615 |***************************************  342948
       2.662 |**************************************** 354029
       2.710 |**************************************** 356295
       2.760 |**************************************** 353068
       2.810 |**************************************   341345
       2.861 |************************************     324600
       2.913 |**********************************       303525
       2.966 |*******************************          280221
       3.020 |*****************************            255042
       3.075 |**************************               230861
       3.130 |***********************                  206909
       3.187 |*********************                    184616
       3.245 |*******************                      164903
       3.304 |****************                         146199
       3.364 |***************                          131427
       3.425 |*************                            117059
       3.488 |************                             104954
       3.551 |***********                              94404
       3.615 |*********                                83739
       3.681 |********                                 75705
       3.748 |********                                 67944
       3.816 |*******                                  60727
       3.885 |******                                   53757
       3.956 |*****                                    47053
       4.028 |*****                                    42130
       4.101 |****                                     38069
       4.176 |****                                     33666
       4.252 |***                                      30048
       4.329 |***                                      26923
       4.407 |***                                      23886
       4.487 |**                                       21615
       4.569 |**                                       19897
       4.652 |**                                       18458
       4.737 |**                                       17729
       4.823 |**                                       17041
       4.910 |**                                       16011
       4.999 |**                                       16099
       5.090 |**                                       16090
       5.183 |**                                       16393
       5.277 |**                                       16729
       5.373 |**                                       17412
```

## 用其他网络业务验证

先测试一下网络下载时的ping：

```
--无流量
64 bytes from 172.16.0.205: icmp_seq=11 ttl=64 time=0.075 ms
64 bytes from 172.16.0.205: icmp_seq=12 ttl=64 time=0.080 ms
--从有网络限速的机器下载，带宽100MB
64 bytes from 172.16.0.205: icmp_seq=13 ttl=64 time=0.738 ms 
64 bytes from 172.16.0.205: icmp_seq=14 ttl=64 time=0.873 ms
64 bytes from 172.16.0.205: icmp_seq=15 ttl=64 time=0.993 ms
64 bytes from 172.16.0.205: icmp_seq=16 ttl=64 time=0.859 ms
64 bytes from 172.16.0.205: icmp_seq=17 ttl=64 time=0.892 ms
64 bytes from 172.16.0.205: icmp_seq=18 ttl=64 time=0.972 ms
64 bytes from 172.16.0.205: icmp_seq=19 ttl=64 time=1.05 ms
64 bytes from 172.16.0.205: icmp_seq=20 ttl=64 time=0.973 ms
64 bytes from 172.16.0.205: icmp_seq=21 ttl=64 time=0.997 ms
64 bytes from 172.16.0.205: icmp_seq=22 ttl=64 time=0.915 ms
64 bytes from 172.16.0.205: icmp_seq=23 ttl=64 time=0.892 ms
64 bytes from 172.16.0.205: icmp_seq=24 ttl=64 time=0.960 ms
64 bytes from 172.16.0.205: icmp_seq=25 ttl=64 time=1.05 ms
64 bytes from 172.16.0.205: icmp_seq=26 ttl=64 time=0.089 ms
64 bytes from 172.16.0.205: icmp_seq=27 ttl=64 time=0.097 ms
64 bytes from 172.16.0.205: icmp_seq=28 ttl=64 time=0.081 ms 
--从没有网络限速的机器下载，带宽1000MB
64 bytes from 172.16.0.205: icmp_seq=29 ttl=64 time=0.078 ms
64 bytes from 172.16.0.205: icmp_seq=30 ttl=64 time=0.077 ms
64 bytes from 172.16.0.205: icmp_seq=31 ttl=64 time=0.073 ms
64 bytes from 172.16.0.205: icmp_seq=32 ttl=64 time=0.072 ms
64 bytes from 172.16.0.205: icmp_seq=33 ttl=64 time=0.079 ms
64 bytes from 172.16.0.205: icmp_seq=34 ttl=64 time=0.074 ms
64 bytes from 172.16.0.205: icmp_seq=35 ttl=64 time=0.080 ms
64 bytes from 172.16.0.205: icmp_seq=36 ttl=64 time=0.077 ms
```

有限速方向，尝试了BBR和cubic 拥塞算法：

```
#tcpperf -c 172.16.0.205 -t 100
Connected mysqld217:51254 -> 172.16.0.205:2009, congestion control: cubic
Time (s)  Throughput   Bitrate    Cwnd    Rwnd  sndbuf  ssthresh  Retr  CA  Pacing  rtt/var
  0.000s   0.00kB/s   0.00kbps  14.3Ki  41.3Ki  85.0Ki    2048Mi     0   0  65.2Mi  427us/213
  1.029s    122MB/s    975Mbps  1595Ki  1595Ki  9512Ki     576Ki     0   0   123Mi  15.2ms/8
  2.005s    105MB/s    843Mbps  1595Ki  1595Ki  9512Ki     576Ki     0   0   123Mi  15.2ms/10
  3.010s    105MB/s    843Mbps  1595Ki  1595Ki  9512Ki     576Ki     0   0   123Mi  15.2ms/17
  4.016s    105MB/s    843Mbps  1595Ki  1595Ki  9512Ki     576Ki     0   0   123Mi  15.2ms/13
  5.022s    105MB/s    843Mbps  1595Ki  1595Ki  9512Ki     576Ki     0   0   123Mi  15.2ms/14
  6.028s    105MB/s    842Mbps  1595Ki  1595Ki  9512Ki     576Ki     0   0   123Mi  15.2ms/17
  7.003s    105MB/s    843Mbps  1595Ki  1595Ki  9512Ki     576Ki     0   0   123Mi  15.2ms/15
  8.009s    105MB/s    843Mbps  1595Ki  1595Ki  9512Ki     576Ki     0   0   123Mi  15.2ms/13
 #tcpperf -c 172.16.0.205 -t 100
Connected mysqld217:51932 -> 172.16.0.205:2009, congestion control: bbr
Time (s)  Throughput   Bitrate    Cwnd    Rwnd  sndbuf  ssthresh  Retr  CA  Pacing  rtt/var
  0.000s   0.00kB/s   0.00kbps  14.3Ki  41.3Ki   128Ki    2048Mi     0   0  98.0Mi  406us/203
  1.011s    120MB/s    957Mbps   271Ki  2281Ki  10.4Mi     560Ki  2244   0   108Mi  2427us/11
  2.033s    104MB/s    831Mbps   271Ki  2281Ki  10.4Mi     560Ki  1056   0   109Mi  2417us/18
  3.021s    104MB/s    830Mbps   274Ki  2281Ki  10.4Mi     560Ki  1056   0   109Mi  2428us/18
  4.014s    103MB/s    827Mbps   271Ki  2281Ki  10.4Mi     560Ki  1452   0   108Mi  2423us/19
  5.031s    104MB/s    835Mbps   274Ki  2281Ki  10.4Mi     560Ki   660   0  80.2Mi  2435us/22
  6.033s    102MB/s    818Mbps   271Ki  2272Ki  10.4Mi     560Ki  2112   0   109Mi  2426us/17
  7.030s    103MB/s    823Mbps   274Ki  2281Ki  10.4Mi     560Ki  1716   0   117Mi  2430us/18
  8.023s    103MB/s    826Mbps   274Ki  2281Ki  10.4Mi     560Ki  1452   0   109Mi  2428us/20
  9.016s    103MB/s    827Mbps   271Ki  2281Ki  10.4Mi     560Ki  1452   0   108Mi  2423us/15   
```

跑tcpperf触发限速时的监控(上下两个窗口是同一台机器)，红色是丢包率挺高的，绿色丢包就没了，应该是拥塞算法和限速管控达成了平衡

![image-20230511215940306](/images/951413iMgBlog/image-20230511215940306.png)

反过来限速被我去掉了(限速可以进出双向单独控制)

```
#tcpperf -c mysqld217 -t 1000
Connected 172.16.0.205:32186 -> mysqld217:2009, congestion control: bbr
Time (s)  Throughput   Bitrate    Cwnd    Rwnd  sndbuf  ssthresh  Retr  CA  Pacing  rtt/var
  0.000s   0.00kB/s   0.00kbps  14.3Ki  41.3Ki   128Ki    2048Mi     0   0   100Mi  397us/198
  1.001s   1107MB/s   8859Mbps   471Ki   985Ki  4641Ki     277Ki     0   0  1083Mi  390us/22
  2.001s   1103MB/s   8823Mbps   465Ki   985Ki  4641Ki     277Ki     0   0  1089Mi  393us/16
  3.000s   1111MB/s   8892Mbps   465Ki   985Ki  4641Ki     277Ki     0   0  1072Mi  403us/25
  4.000s   1099MB/s   8789Mbps   459Ki   985Ki  4794Ki     277Ki     0   0   799Mi  399us/18
  5.001s   1098MB/s   8786Mbps   459Ki   985Ki  4794Ki     277Ki     0   0  1066Mi  387us/12
  6.000s   1100MB/s   8799Mbps   462Ki   974Ki  4794Ki     277Ki     0   0  1069Mi  399us/16
  7.001s   1135MB/s   9078Mbps   453Ki   985Ki  4794Ki     277Ki     0   0  1059Mi  377us/19
```

查看限速配置如下：

```
{txcmbps:844.000, txckpps:120.000}

//限速解释
0-31 我猜这是网卡队列(可以修改);
txcmbps:844.000 105.5MB/s     每秒带宽105.5MB
txckpps:120.000 120K packet/s 每秒12万网络包
```

sysbench(主键查询-小包) 12万QPS 正好命中 txckpps:120，tcpperf (大包)稳定的105MB带宽命中txcmbps:844

去掉后长这样：

```
#ovsctl -n set_out_pps -v -1  //把pps限制为-1==不限制
#ovsctl set_tx -p {} -r -1;   //带宽不限制

{vport:  2 {map:  0, prio:L, weight:   0}meter: {-}queue: [  0- 31L]}
```

对这块网络管控感兴趣可以去了解一下 ovs 这个开源项目(open virtual switch)

### 去掉网卡限速后的结果

实际结构如下：

![image-20230513132101185](/images/951413iMgBlog/image-20230513132101185.png)

放开所有网络控制后，1000并发压力 30万QPS，RT 3.28，此时从sysbench 以及空闲机器ping MySQLD机器的 RTT和没压力基本一致

![image-20230512090205685](/images/951413iMgBlog/image-20230512090205685.png)

top状态：

```
%Node1 : 23.4 us, 12.3 sy,  0.0 ni, 61.4 id,  0.0 wa,  0.0 hi,  3.0 si,  0.0 st
%Cpu64 : 63.2 us, 36.8 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu65 : 44.4 us, 21.9 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi, 33.8 si,  0.0 st
%Cpu66 : 66.6 us, 33.4 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu67 : 63.4 us, 36.6 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu68 : 64.2 us, 35.8 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu69 : 64.9 us, 35.1 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu70 : 66.6 us, 33.4 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu71 : 65.3 us, 34.7 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu72 : 67.7 us, 32.3 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu73 : 63.6 us, 36.4 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu74 : 66.7 us, 33.3 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu75 : 42.4 us, 19.9 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi, 37.7 si,  0.0 st
%Cpu76 : 63.9 us, 36.1 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu77 : 67.0 us, 33.0 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu78 : 68.3 us, 31.7 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu79 : 64.9 us, 35.1 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu80 : 65.2 us, 34.8 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu81 : 44.4 us, 21.5 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi, 34.1 si,  0.0 st
%Cpu82 : 63.9 us, 36.1 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu83 : 44.2 us, 23.4 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi, 32.3 si,  0.0 st
%Cpu84 : 65.7 us, 34.3 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu85 : 68.3 us, 31.7 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu86 : 67.5 us, 32.5 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu87 : 62.4 us, 37.6 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu88 :  0.0 us,  0.0 sy,  0.0 ni,100.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
```

![image-20230512092713141](/images/951413iMgBlog/image-20230512092713141.png)

小思考：

> 我们中间尝试走本机127.0.0.1 压测时QPS 是24万，比跨机器压的 30万打了8折，想想为什么？网络延时消耗完全没影响？

### 总结

简单可复制的证明办法：抓包，快速撕逼和分析

肯定有很多人想到：内存、磁盘、线程池、队列、网络等等原因，但是这些所有原因有一个共同的爹：RT，所有这些影响因素最后体现出来就是RT 高了，你CPU资源不够、内存慢最后总表现就是在客户端看来你的 RT 太高。

所以我们去掉这些复杂因素先在MySQLD所在EC2 的网卡上抓一个包看看RT，再对比一下1000/2000并发时抓包看到的 RT 有没有升高，如果有升高说明问题在MySQLD这端(含OS、MySQLD的问题)，如果 RT 不变那么问题不在MySQLD这端，并且从EC2网卡出去都是很快的，那么问题只能是在路上或者客户端的sysbench自己慢了。

这是我们星球里说的无招胜有招--抓包大法，扯皮过程中我还没见过几个不认网络抓包的，也有那么一两个扯上是不是网卡驱动有问题，我的代码不会有问题

两个限速条件：pps 120k(每秒最多12万网络包)，带宽 844mbps=105.5MB/s

Sysbench 查询都是小包，触发第一个条件，tcpperf触发第二个条件

ping ping神功失效了吗？也没有，我后来又测试了100、200并发，rtt 0.2ms和0.4ms，也就是说随着并发的增加rtt 增加到0.8ms后就不再增加了。上来1000并发已经到了天花板

```
64 bytes from polardbxyt27 (mysqld217): icmp_seq=159 ttl=64 time=0.226 ms
64 bytes from polardbxyt27 (mysqld217): icmp_seq=160 ttl=64 time=0.334 ms
64 bytes from polardbxyt27 (mysqld217): icmp_seq=161 ttl=64 time=0.336 ms
64 bytes from polardbxyt27 (mysqld217): icmp_seq=162 ttl=64 time=0.213 ms
64 bytes from polardbxyt27 (mysqld217): icmp_seq=163 ttl=64 time=0.104 ms
64 bytes from polardbxyt27 (mysqld217): icmp_seq=164 ttl=64 time=0.096 ms
64 bytes from polardbxyt27 (mysqld217): icmp_seq=165 ttl=64 time=0.101 ms
64 bytes from polardbxyt27 (mysqld217): icmp_seq=166 ttl=64 time=0.116 ms
64 bytes from polardbxyt27 (mysqld217): icmp_seq=167 ttl=64 time=0.104 ms--以上 100并发，QPS 119K
64 bytes from polardbxyt27 (mysqld217): icmp_seq=168 ttl=64 time=0.093 ms
64 bytes from polardbxyt27 (mysqld217): icmp_seq=169 ttl=64 time=0.088 ms
64 bytes from polardbxyt27 (mysqld217): icmp_seq=170 ttl=64 time=0.405 ms--以下 200并发，QPS 119K
64 bytes from polardbxyt27 (mysqld217): icmp_seq=171 ttl=64 time=0.419 ms
64 bytes from polardbxyt27 (mysqld217): icmp_seq=172 ttl=64 time=0.386 ms
64 bytes from polardbxyt27 (mysqld217): icmp_seq=173 ttl=64 time=0.474 ms
64 bytes from polardbxyt27 (mysqld217): icmp_seq=174 ttl=64 time=0.462 ms
64 bytes from polardbxyt27 (mysqld217): icmp_seq=175 ttl=64 time=0.410 ms
```
