---
title: ssd/san/sas/磁盘/光纤性能比较
date: 2022-01-25 17:30:03
categories:
    - performance
tags:
    - Linux
    - 磁盘性能
    - san
    - 光纤
    - CPU
---

# ssd/san/sas/磁盘/光纤/RAID性能比较

本文汇总HDD、SSD、SAN、LVM、软RAID等一些性能数据

## 性能比较

正好有机会用到一个san存储设备，跑了一把性能数据，记录一下

![image.png](/images/oss/d57a004c846e193126ca01398e394319.png)

所使用的测试命令：

```
fio -ioengine=libaio -bs=4k -direct=1 -thread -rw=randwrite -size=1000G -filename=/data/fio.test -name="EBS 4K randwrite test" -iodepth=64 -runtime=60
```

ssd（Solid State Drive）和san的比较是在同一台物理机上，所以排除了其他因素的干扰。

简要的结论： 

- 本地ssd性能最好、sas机械盘(RAID10)性能最差

- san存储走特定的光纤网络，不是走tcp的san（至少从网卡看不到san的流量），性能居中

- 从rt来看 ssd:san:sas 大概是 1:3:15

- san比本地sas机械盘性能要好，这也许取决于san的网络传输性能和san存储中的设备（比如用的ssd而不是机械盘）

## NVMe SSD 和 HDD的性能比较

![image.png](/images/oss/d64a0f78ebf471ac69d447ecb46d90f1.png)

表中性能差异比上面测试还要大，SSD 的随机 IO 延迟比传统硬盘快百倍以上，一般在微妙级别；IO 带宽也高很多倍，可以达到每秒几个 GB；随机 IOPS 更是快了上千倍，可以达到几十万。

**HDD只有一个磁头，并发没有意义，但是SSD支持高并发写入读取。SSD没有磁头、不需要旋转，所以随机读取和顺序读取基本没有差别。**

![img](/images/951413iMgBlog/1ab661ee2d3a71f54bae3ecf62982e7e.png)

从上图可以看出如果是随机读写HDD性能极差，但是如果是顺序读写HDD和SDD、内存差异就不那么大了。



## 磁盘类型查看

```
$cat /sys/block/vda/queue/rotational
1  //1表示旋转，非ssd，0表示ssd

或者
lsblk -d -o name,rota,size,label,uuid
```

## fio测试

以下是两块测试的SSD磁盘测试前的基本情况

```
/dev/sda	240.06G  SSD_SATA  //sata
/dev/sfd0n1	3200G	 SSD_PCIE  //PCIE

Filesystem      Size  Used Avail Use% Mounted on
/dev/sda3        49G   29G   18G  63% / 
/dev/sfdv0n1p1  2.0T  803G  1.3T  40% /data

# cat /sys/block/sda/queue/rotational 
0
# cat /sys/block/sfdv0n1/queue/rotational 
0

#测试前的iostat状态
# iostat -d sfdv0n1 sda3 1 -x
Linux 3.10.0-957.el7.x86_64 (nu4d01142.sqa.nu8) 	2021年02月23日 	_x86_64_	(104 CPU)

Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
sda3              0.00    10.67    1.24   18.78     7.82   220.69    22.83     0.03    1.64    1.39    1.66   0.08   0.17
sfdv0n1           0.00     0.21    9.91  841.42   128.15  8237.10    19.65     0.93    0.04    0.25    0.04   1.05  89.52

Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
sda3              0.00    15.00    0.00   17.00     0.00   136.00    16.00     0.03    2.00    0.00    2.00   1.29   2.20
sfdv0n1           0.00     0.00    0.00 11158.00     0.00 54448.00     9.76     1.03    0.02    0.00    0.02   0.09 100.00

Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
sda3              0.00     5.00    0.00   18.00     0.00   104.00    11.56     0.01    0.61    0.00    0.61   0.61   1.10
sfdv0n1           0.00     0.00    0.00 10970.00     0.00 53216.00     9.70     1.02    0.03    0.00    0.03   0.09 100.10

Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
sda3              0.00     0.00    0.00   24.00     0.00   100.00     8.33     0.01    0.58    0.00    0.58   0.08   0.20
sfdv0n1           0.00     0.00    0.00 11206.00     0.00 54476.00     9.72     1.03    0.03    0.00    0.03   0.09  99.90

Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
sda3              0.00    14.00    0.00   21.00     0.00   148.00    14.10     0.01    0.48    0.00    0.48   0.33   0.70
sfdv0n1           0.00     0.00    0.00 10071.00     0.00 49028.00     9.74     1.02    0.03    0.00    0.03   0.10  99.80

```

### NVMe SSD测试数据

对一块ssd进行如下测试(挂载在/data 目录)

```
fio -ioengine=libaio -bs=4k -direct=1 -thread -rw=randwrite -rwmixread=70 -size=16G -filename=./fio.test -name="EBS 4K randwrite test" -iodepth=64 -runtime=60
EBS 4K randwrite test: (g=0): rw=randwrite, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=64
fio-3.7
Starting 1 thread
EBS 4K randwrite test: Laying out IO file (1 file / 16384MiB)
Jobs: 1 (f=1): [w(1)][100.0%][r=0KiB/s,w=63.8MiB/s][r=0,w=16.3k IOPS][eta 00m:00s]
EBS 4K randwrite test: (groupid=0, jobs=1): err= 0: pid=258871: Tue Feb 23 14:12:23 2021
  write: IOPS=18.9k, BW=74.0MiB/s (77.6MB/s)(4441MiB/60001msec)
    slat (usec): min=4, max=6154, avg=48.82, stdev=56.38
    clat (nsec): min=1049, max=12360k, avg=3326362.62, stdev=920683.43
     lat (usec): min=68, max=12414, avg=3375.52, stdev=928.97
    clat percentiles (usec):
     |  1.00th=[ 1483],  5.00th=[ 1811], 10.00th=[ 2114], 20.00th=[ 2376],
     | 30.00th=[ 2704], 40.00th=[ 3130], 50.00th=[ 3523], 60.00th=[ 3785],
     | 70.00th=[ 3949], 80.00th=[ 4080], 90.00th=[ 4293], 95.00th=[ 4490],
     | 99.00th=[ 5604], 99.50th=[ 5997], 99.90th=[ 7111], 99.95th=[ 7832],
     | 99.99th=[ 9634]
   bw (  KiB/s): min=61024, max=118256, per=99.98%, avg=75779.58, stdev=12747.95, samples=120
   iops        : min=15256, max=29564, avg=18944.88, stdev=3186.97, samples=120
  lat (usec)   : 2=0.01%, 100=0.01%, 250=0.01%, 500=0.01%, 750=0.02%
  lat (usec)   : 1000=0.06%
  lat (msec)   : 2=7.40%, 4=66.19%, 10=26.32%, 20=0.01%
  cpu          : usr=5.23%, sys=46.71%, ctx=846953, majf=0, minf=6
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=0.1%, >=64=100.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.1%, >=64=0.0%
     issued rwts: total=0,1136905,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=64

Run status group 0 (all jobs):
  WRITE: bw=74.0MiB/s (77.6MB/s), 74.0MiB/s-74.0MiB/s (77.6MB/s-77.6MB/s), io=4441MiB (4657MB), run=60001-60001msec

Disk stats (read/write):
  sfdv0n1: ios=0/1821771, merge=0/7335, ticks=0/39708, in_queue=78295, util=100.00%
```

如上测试iops为：18944，测试期间的iostat，测试中一直有mysql在导入数据，所以测试开始前util就已经100%了，并且w/s到了13K左右

```
# iostat -d sfdv0n1 3 -x
Linux 3.10.0-957.el7.x86_64 (nu4d01142.sqa.nu8) 	2021年02月23日 	_x86_64_	(104 CPU)

Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
sfdv0n1           0.00     0.18    3.45  769.17   102.83  7885.16    20.68     0.93    0.04    0.26    0.04   1.16  89.46

Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
sfdv0n1           0.00     0.00    0.00 13168.67     0.00 66244.00    10.06     1.05    0.03    0.00    0.03   0.08 100.10

Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
sfdv0n1           0.00     0.00    0.00 12822.67     0.00 65542.67    10.22     1.04    0.02    0.00    0.02   0.08 100.07

//增加压力
Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
sfdv0n1           0.00     0.00    0.00 27348.33     0.00 214928.00    15.72     1.27    0.02    0.00    0.02   0.04 100.17

Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
sfdv0n1           0.00     1.00    0.00 32661.67     0.00 271660.00    16.63     1.32    0.02    0.00    0.02   0.03 100.37

Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
sfdv0n1           0.00     0.00    0.00 31645.00     0.00 265988.00    16.81     1.33    0.02    0.00    0.02   0.03 100.37

Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
sfdv0n1           0.00   574.00    0.00 31961.67     0.00 271094.67    16.96     1.36    0.02    0.00    0.02   0.03 100.13

Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
sfdv0n1           0.00     0.00    0.00 27656.33     0.00 224586.67    16.24     1.28    0.02    0.00    0.02   0.04 100.37

```

从iostat看出，测试开始前util已经100%（因为ssd，util失去参考意义），w/s 13K左右，压力跑起来后w/s能到30K，svctm、await均保持稳定

如下测试中direct=1和direct=0的write avg iops分别为42K、16K

```
# fio -ioengine=libaio -bs=4k -direct=1 -buffered=0 -thread -rw=randrw -rwmixread=70 -size=16G -filename=/data/fio.test -name="EBS 4K randwrite test" -iodepth=64 -runtime=60 
EBS 4K randwrite test: (g=0): rw=randrw, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=64
fio-3.7
Starting 1 thread
Jobs: 1 (f=1): [m(1)][100.0%][r=507MiB/s,w=216MiB/s][r=130k,w=55.2k IOPS][eta 00m:00s] 
EBS 4K randwrite test: (groupid=0, jobs=1): err= 0: pid=415921: Tue Feb 23 14:34:33 2021
   read: IOPS=99.8k, BW=390MiB/s (409MB/s)(11.2GiB/29432msec)
    slat (nsec): min=1043, max=917837, avg=4273.86, stdev=3792.17
    clat (usec): min=2, max=4313, avg=459.80, stdev=239.61
     lat (usec): min=4, max=4328, avg=464.16, stdev=241.81
    clat percentiles (usec):
     |  1.00th=[  251],  5.00th=[  277], 10.00th=[  289], 20.00th=[  310],
     | 30.00th=[  326], 40.00th=[  343], 50.00th=[  363], 60.00th=[  400],
     | 70.00th=[  502], 80.00th=[  603], 90.00th=[  750], 95.00th=[  881],
     | 99.00th=[ 1172], 99.50th=[ 1401], 99.90th=[ 3032], 99.95th=[ 3359],
     | 99.99th=[ 3785]
   bw (  KiB/s): min=182520, max=574856, per=99.24%, avg=395975.64, stdev=119541.78, samples=58
   iops        : min=45630, max=143714, avg=98993.90, stdev=29885.42, samples=58
  write: IOPS=42.8k, BW=167MiB/s (175MB/s)(4915MiB/29432msec)
    slat (usec): min=3, max=263, avg= 9.34, stdev= 4.35
    clat (usec): min=14, max=2057, avg=402.26, stdev=140.67
     lat (usec): min=19, max=2070, avg=411.72, stdev=142.67
    clat percentiles (usec):
     |  1.00th=[  237],  5.00th=[  281], 10.00th=[  293], 20.00th=[  314],
     | 30.00th=[  330], 40.00th=[  343], 50.00th=[  359], 60.00th=[  379],
     | 70.00th=[  404], 80.00th=[  457], 90.00th=[  586], 95.00th=[  717],
     | 99.00th=[  930], 99.50th=[ 1004], 99.90th=[ 1254], 99.95th=[ 1385],
     | 99.99th=[ 1532]
   bw (  KiB/s): min=78104, max=244408, per=99.22%, avg=169671.52, stdev=51142.10, samples=58
   iops        : min=19526, max=61102, avg=42417.86, stdev=12785.51, samples=58
  lat (usec)   : 4=0.01%, 10=0.01%, 20=0.01%, 50=0.02%, 100=0.04%
  lat (usec)   : 250=1.02%, 500=73.32%, 750=17.28%, 1000=6.30%
  lat (msec)   : 2=1.83%, 4=0.19%, 10=0.01%
  cpu          : usr=15.84%, sys=83.31%, ctx=13765, majf=0, minf=7
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=0.1%, >=64=100.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.1%, >=64=0.0%
     issued rwts: total=2936000,1258304,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=64

Run status group 0 (all jobs):
   READ: bw=390MiB/s (409MB/s), 390MiB/s-390MiB/s (409MB/s-409MB/s), io=11.2GiB (12.0GB), run=29432-29432msec
  WRITE: bw=167MiB/s (175MB/s), 167MiB/s-167MiB/s (175MB/s-175MB/s), io=4915MiB (5154MB), run=29432-29432msec

Disk stats (read/write):
  sfdv0n1: ios=795793/1618341, merge=0/11, ticks=218710/27721, in_queue=264935, util=100.00%
[root@nu4d01142 data]# 
[root@nu4d01142 data]# fio -ioengine=libaio -bs=4k -direct=0 -buffered=0 -thread -rw=randrw -rwmixread=70 -size=6G -filename=/data/fio.test -name="EBS 4K randwrite test" -iodepth=64 -runtime=60 
EBS 4K randwrite test: (g=0): rw=randrw, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=64
fio-3.7
Starting 1 thread
Jobs: 1 (f=1): [m(1)][100.0%][r=124MiB/s,w=53.5MiB/s][r=31.7k,w=13.7k IOPS][eta 00m:00s]
EBS 4K randwrite test: (groupid=0, jobs=1): err= 0: pid=437523: Tue Feb 23 14:37:54 2021
   read: IOPS=38.6k, BW=151MiB/s (158MB/s)(4300MiB/28550msec)
    slat (nsec): min=1205, max=1826.7k, avg=13253.36, stdev=17173.87
    clat (nsec): min=236, max=5816.8k, avg=1135969.25, stdev=337142.34
     lat (nsec): min=1977, max=5831.2k, avg=1149404.84, stdev=341232.87
    clat percentiles (usec):
     |  1.00th=[  461],  5.00th=[  627], 10.00th=[  717], 20.00th=[  840],
     | 30.00th=[  938], 40.00th=[ 1029], 50.00th=[ 1123], 60.00th=[ 1221],
     | 70.00th=[ 1319], 80.00th=[ 1434], 90.00th=[ 1565], 95.00th=[ 1680],
     | 99.00th=[ 1893], 99.50th=[ 1975], 99.90th=[ 2671], 99.95th=[ 3261],
     | 99.99th=[ 3851]
   bw (  KiB/s): min=119304, max=216648, per=100.00%, avg=154273.07, stdev=29925.10, samples=57
   iops        : min=29826, max=54162, avg=38568.25, stdev=7481.30, samples=57
  write: IOPS=16.5k, BW=64.6MiB/s (67.7MB/s)(1844MiB/28550msec)
    slat (usec): min=3, max=3565, avg=21.07, stdev=22.23
    clat (usec): min=14, max=9983, avg=1164.21, stdev=459.66
     lat (usec): min=21, max=10011, avg=1185.57, stdev=463.28
    clat percentiles (usec):
     |  1.00th=[  498],  5.00th=[  619], 10.00th=[  709], 20.00th=[  832],
     | 30.00th=[  930], 40.00th=[ 1020], 50.00th=[ 1123], 60.00th=[ 1237],
     | 70.00th=[ 1336], 80.00th=[ 1450], 90.00th=[ 1598], 95.00th=[ 1713],
     | 99.00th=[ 2311], 99.50th=[ 3851], 99.90th=[ 5932], 99.95th=[ 6456],
     | 99.99th=[ 7701]
   bw (  KiB/s): min=50800, max=92328, per=100.00%, avg=66128.47, stdev=12890.64, samples=57
   iops        : min=12700, max=23082, avg=16532.07, stdev=3222.66, samples=57
  lat (nsec)   : 250=0.01%, 500=0.01%, 750=0.01%, 1000=0.01%
  lat (usec)   : 2=0.01%, 4=0.01%, 10=0.01%, 20=0.02%, 50=0.03%
  lat (usec)   : 100=0.04%, 250=0.18%, 500=1.01%, 750=11.05%, 1000=25.02%
  lat (msec)   : 2=61.87%, 4=0.62%, 10=0.14%
  cpu          : usr=10.87%, sys=61.98%, ctx=218415, majf=0, minf=7
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=0.1%, >=64=100.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.1%, >=64=0.0%
     issued rwts: total=1100924,471940,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=64

Run status group 0 (all jobs):
   READ: bw=151MiB/s (158MB/s), 151MiB/s-151MiB/s (158MB/s-158MB/s), io=4300MiB (4509MB), run=28550-28550msec
  WRITE: bw=64.6MiB/s (67.7MB/s), 64.6MiB/s-64.6MiB/s (67.7MB/s-67.7MB/s), io=1844MiB (1933MB), run=28550-28550msec

Disk stats (read/write):
  sfdv0n1: ios=536103/822037, merge=0/1442, ticks=66507/17141, in_queue=99429, util=100.00%

```

### SATA SSD测试数据

```
# cat /sys/block/sda/queue/rotational 
0
# lsblk -d -o name,rota
NAME     ROTA
sda         0
sfdv0n1     0
```

-direct=0 -buffered=0读写iops分别为15.8K、6.8K 比ssd差了不少（都是direct=0），如果direct、buffered都是1的话，ESSD性能很差，读写iops分别为4312、1852

```
# fio -ioengine=libaio -bs=4k -direct=0 -buffered=0 -thread -rw=randrw -rwmixread=70 -size=2G -filename=/var/lib/docker/fio.test -name="EBS 4K randwrite test" -iodepth=64 -runtime=60 
EBS 4K randwrite test: (g=0): rw=randrw, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=64
fio-3.7
Starting 1 thread
EBS 4K randwrite test: Laying out IO file (1 file / 2048MiB)
Jobs: 1 (f=1): [m(1)][100.0%][r=68.7MiB/s,w=29.7MiB/s][r=17.6k,w=7594 IOPS][eta 00m:00s]
EBS 4K randwrite test: (groupid=0, jobs=1): err= 0: pid=13261: Tue Feb 23 14:42:41 2021
   read: IOPS=15.8k, BW=61.8MiB/s (64.8MB/s)(1432MiB/23172msec)
    slat (nsec): min=1266, max=7261.0k, avg=7101.88, stdev=20655.54
    clat (usec): min=167, max=27670, avg=2832.68, stdev=1786.18
     lat (usec): min=175, max=27674, avg=2839.93, stdev=1784.42
    clat percentiles (usec):
     |  1.00th=[  437],  5.00th=[  668], 10.00th=[  873], 20.00th=[  988],
     | 30.00th=[ 1401], 40.00th=[ 2442], 50.00th=[ 2835], 60.00th=[ 3195],
     | 70.00th=[ 3523], 80.00th=[ 4047], 90.00th=[ 5014], 95.00th=[ 5866],
     | 99.00th=[ 8160], 99.50th=[ 9372], 99.90th=[13829], 99.95th=[15008],
     | 99.99th=[23725]
   bw (  KiB/s): min=44183, max=149440, per=99.28%, avg=62836.17, stdev=26590.84, samples=46
   iops        : min=11045, max=37360, avg=15709.02, stdev=6647.72, samples=46
  write: IOPS=6803, BW=26.6MiB/s (27.9MB/s)(616MiB/23172msec)
    slat (nsec): min=1566, max=11474k, avg=8460.17, stdev=38221.51
    clat (usec): min=77, max=24047, avg=2789.68, stdev=2042.55
     lat (usec): min=80, max=24054, avg=2798.29, stdev=2040.85
    clat percentiles (usec):
     |  1.00th=[  265],  5.00th=[  433], 10.00th=[  635], 20.00th=[  840],
     | 30.00th=[  979], 40.00th=[ 2212], 50.00th=[ 2671], 60.00th=[ 3130],
     | 70.00th=[ 3523], 80.00th=[ 4228], 90.00th=[ 5342], 95.00th=[ 6456],
     | 99.00th=[ 9241], 99.50th=[10421], 99.90th=[13960], 99.95th=[15533],
     | 99.99th=[23725]
   bw (  KiB/s): min=18435, max=63112, per=99.26%, avg=27012.57, stdev=11299.42, samples=46
   iops        : min= 4608, max=15778, avg=6753.11, stdev=2824.87, samples=46
  lat (usec)   : 100=0.01%, 250=0.23%, 500=3.14%, 750=5.46%, 1000=15.27%
  lat (msec)   : 2=11.47%, 4=43.09%, 10=20.88%, 20=0.44%, 50=0.01%
  cpu          : usr=3.53%, sys=18.08%, ctx=47448, majf=0, minf=6
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=0.1%, >=64=100.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.1%, >=64=0.0%
     issued rwts: total=366638,157650,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=64

Run status group 0 (all jobs):
   READ: bw=61.8MiB/s (64.8MB/s), 61.8MiB/s-61.8MiB/s (64.8MB/s-64.8MB/s), io=1432MiB (1502MB), run=23172-23172msec
  WRITE: bw=26.6MiB/s (27.9MB/s), 26.6MiB/s-26.6MiB/s (27.9MB/s-27.9MB/s), io=616MiB (646MB), run=23172-23172msec

Disk stats (read/write):
  sda: ios=359202/155123, merge=299/377, ticks=946305/407820, in_queue=1354596, util=99.61%
  
# fio -ioengine=libaio -bs=4k -direct=1 -buffered=0 -thread -rw=randrw -rwmixread=70 -size=2G -filename=/var/lib/docker/fio.test -name="EBS 4K randwrite test" -iodepth=64 -runtime=60 
EBS 4K randwrite test: (g=0): rw=randrw, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=64
fio-3.7
Starting 1 thread
Jobs: 1 (f=1): [m(1)][95.5%][r=57.8MiB/s,w=25.7MiB/s][r=14.8k,w=6568 IOPS][eta 00m:01s] 
EBS 4K randwrite test: (groupid=0, jobs=1): err= 0: pid=26167: Tue Feb 23 14:44:40 2021
   read: IOPS=16.9k, BW=65.9MiB/s (69.1MB/s)(1432MiB/21730msec)
    slat (nsec): min=1312, max=4454.2k, avg=8489.99, stdev=15763.97
    clat (usec): min=201, max=18856, avg=2679.38, stdev=1720.02
     lat (usec): min=206, max=18860, avg=2688.03, stdev=1717.19
    clat percentiles (usec):
     |  1.00th=[  635],  5.00th=[  832], 10.00th=[  914], 20.00th=[  971],
     | 30.00th=[ 1090], 40.00th=[ 2114], 50.00th=[ 2704], 60.00th=[ 3064],
     | 70.00th=[ 3392], 80.00th=[ 3851], 90.00th=[ 4817], 95.00th=[ 5735],
     | 99.00th=[ 7767], 99.50th=[ 8979], 99.90th=[13698], 99.95th=[15139],
     | 99.99th=[16581]
   bw (  KiB/s): min=45168, max=127528, per=100.00%, avg=67625.19, stdev=26620.82, samples=43
   iops        : min=11292, max=31882, avg=16906.28, stdev=6655.20, samples=43
  write: IOPS=7254, BW=28.3MiB/s (29.7MB/s)(616MiB/21730msec)
    slat (nsec): min=1749, max=3412.2k, avg=9816.22, stdev=14501.05
    clat (usec): min=97, max=23473, avg=2556.02, stdev=1980.53
     lat (usec): min=107, max=23477, avg=2566.01, stdev=1977.65
    clat percentiles (usec):
     |  1.00th=[  277],  5.00th=[  486], 10.00th=[  693], 20.00th=[  824],
     | 30.00th=[  881], 40.00th=[ 1205], 50.00th=[ 2442], 60.00th=[ 2868],
     | 70.00th=[ 3326], 80.00th=[ 3949], 90.00th=[ 5080], 95.00th=[ 6128],
     | 99.00th=[ 8717], 99.50th=[10159], 99.90th=[14484], 99.95th=[15926],
     | 99.99th=[18744]
   bw (  KiB/s): min=19360, max=55040, per=100.00%, avg=29064.05, stdev=11373.59, samples=43
   iops        : min= 4840, max=13760, avg=7266.00, stdev=2843.41, samples=43
  lat (usec)   : 100=0.01%, 250=0.17%, 500=1.66%, 750=3.74%, 1000=22.57%
  lat (msec)   : 2=12.66%, 4=40.62%, 10=18.20%, 20=0.38%, 50=0.01%
  cpu          : usr=4.17%, sys=22.27%, ctx=14314, majf=0, minf=7
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=0.1%, >=64=100.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.1%, >=64=0.0%
     issued rwts: total=366638,157650,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=64

Run status group 0 (all jobs):
   READ: bw=65.9MiB/s (69.1MB/s), 65.9MiB/s-65.9MiB/s (69.1MB/s-69.1MB/s), io=1432MiB (1502MB), run=21730-21730msec
  WRITE: bw=28.3MiB/s (29.7MB/s), 28.3MiB/s-28.3MiB/s (29.7MB/s-29.7MB/s), io=616MiB (646MB), run=21730-21730msec

Disk stats (read/write):
  sda: ios=364744/157621, merge=779/473, ticks=851759/352008, in_queue=1204024, util=99.61%

# fio -ioengine=libaio -bs=4k -direct=1 -buffered=1 -thread -rw=randrw -rwmixread=70 -size=2G -filename=/var/lib/docker/fio.test -name="EBS 4K randwrite test" -iodepth=64 -runtime=60 
EBS 4K randwrite test: (g=0): rw=randrw, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=64
fio-3.7
Starting 1 thread
Jobs: 1 (f=1): [m(1)][100.0%][r=15.9MiB/s,w=7308KiB/s][r=4081,w=1827 IOPS][eta 00m:00s]
EBS 4K randwrite test: (groupid=0, jobs=1): err= 0: pid=31560: Tue Feb 23 14:46:10 2021
   read: IOPS=4312, BW=16.8MiB/s (17.7MB/s)(1011MiB/60001msec)
    slat (usec): min=63, max=14320, avg=216.76, stdev=430.61
    clat (usec): min=5, max=778861, avg=10254.92, stdev=22345.40
     lat (usec): min=1900, max=782277, avg=10472.16, stdev=22657.06
    clat percentiles (msec):
     |  1.00th=[    6],  5.00th=[    6], 10.00th=[    6], 20.00th=[    7],
     | 30.00th=[    7], 40.00th=[    7], 50.00th=[    7], 60.00th=[    7],
     | 70.00th=[    8], 80.00th=[    8], 90.00th=[    8], 95.00th=[   11],
     | 99.00th=[  107], 99.50th=[  113], 99.90th=[  132], 99.95th=[  197],
     | 99.99th=[  760]
   bw (  KiB/s): min=  168, max=29784, per=100.00%, avg=17390.92, stdev=10932.90, samples=119
   iops        : min=   42, max= 7446, avg=4347.71, stdev=2733.21, samples=119
  write: IOPS=1852, BW=7410KiB/s (7588kB/s)(434MiB/60001msec)
    slat (usec): min=3, max=666432, avg=23.59, stdev=2745.39
    clat (msec): min=3, max=781, avg=10.14, stdev=20.50
     lat (msec): min=3, max=781, avg=10.16, stdev=20.72
    clat percentiles (msec):
     |  1.00th=[    6],  5.00th=[    6], 10.00th=[    6], 20.00th=[    7],
     | 30.00th=[    7], 40.00th=[    7], 50.00th=[    7], 60.00th=[    7],
     | 70.00th=[    7], 80.00th=[    8], 90.00th=[    8], 95.00th=[   11],
     | 99.00th=[  107], 99.50th=[  113], 99.90th=[  131], 99.95th=[  157],
     | 99.99th=[  760]
   bw (  KiB/s): min=   80, max=12328, per=100.00%, avg=7469.53, stdev=4696.69, samples=119
   iops        : min=   20, max= 3082, avg=1867.34, stdev=1174.19, samples=119
  lat (usec)   : 10=0.01%
  lat (msec)   : 2=0.01%, 4=0.01%, 10=94.64%, 20=1.78%, 50=0.11%
  lat (msec)   : 100=1.80%, 250=1.63%, 500=0.01%, 750=0.02%, 1000=0.01%
  cpu          : usr=2.51%, sys=10.98%, ctx=260210, majf=0, minf=7
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=0.1%, >=64=100.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.1%, >=64=0.0%
     issued rwts: total=258768,111147,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=64

Run status group 0 (all jobs):
   READ: bw=16.8MiB/s (17.7MB/s), 16.8MiB/s-16.8MiB/s (17.7MB/s-17.7MB/s), io=1011MiB (1060MB), run=60001-60001msec
  WRITE: bw=7410KiB/s (7588kB/s), 7410KiB/s-7410KiB/s (7588kB/s-7588kB/s), io=434MiB (455MB), run=60001-60001msec

Disk stats (read/write):
  sda: ios=258717/89376, merge=0/735, ticks=52540/564186, in_queue=616999, util=90.07%
```

### ESSD磁盘测试数据

这是一块虚拟的阿里云网络盘，不能算完整意义的SSD（承诺IOPS 4200），数据仅供参考，磁盘概况：

```
$df -lh
Filesystem      Size  Used Avail Use% Mounted on
/dev/vda1        99G   30G   65G  32% /

$cat /sys/block/vda/queue/rotational
1
```

测试数据：

```
$fio -ioengine=libaio -bs=4k -direct=1 -buffered=1  -thread -rw=randrw  -size=4G -filename=/home/admin/fio.test -name="EBS 4K randwrite test" -iodepth=64 -runtime=60
EBS 4K randwrite test: (g=0): rw=randrw, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=64
fio-3.1
Starting 1 thread
Jobs: 1 (f=1): [m(1)][100.0%][r=10.8MiB/s,w=11.2MiB/s][r=2757,w=2876 IOPS][eta 00m:00s]
EBS 4K randwrite test: (groupid=0, jobs=1): err= 0: pid=25641: Tue Feb 23 16:35:19 2021
   read: IOPS=2136, BW=8545KiB/s (8750kB/s)(501MiB/60001msec)
    slat (usec): min=190, max=830992, avg=457.20, stdev=3088.80
    clat (nsec): min=1792, max=1721.3M, avg=14657528.60, stdev=63188988.75
     lat (usec): min=344, max=1751.1k, avg=15115.20, stdev=65165.80
    clat percentiles (msec):
     |  1.00th=[    8],  5.00th=[    9], 10.00th=[    9], 20.00th=[   10],
     | 30.00th=[   10], 40.00th=[   11], 50.00th=[   11], 60.00th=[   11],
     | 70.00th=[   12], 80.00th=[   12], 90.00th=[   13], 95.00th=[   14],
     | 99.00th=[   17], 99.50th=[   53], 99.90th=[ 1028], 99.95th=[ 1167],
     | 99.99th=[ 1653]
   bw (  KiB/s): min=   56, max=12648, per=100.00%, avg=8598.92, stdev=5289.40, samples=118
   iops        : min=   14, max= 3162, avg=2149.73, stdev=1322.35, samples=118
  write: IOPS=2137, BW=8548KiB/s (8753kB/s)(501MiB/60001msec)
    slat (usec): min=2, max=181, avg= 6.67, stdev= 7.22
    clat (usec): min=628, max=1721.1k, avg=14825.32, stdev=65017.66
     lat (usec): min=636, max=1721.1k, avg=14832.10, stdev=65018.10
    clat percentiles (msec):
     |  1.00th=[    8],  5.00th=[    9], 10.00th=[    9], 20.00th=[   10],
     | 30.00th=[   10], 40.00th=[   11], 50.00th=[   11], 60.00th=[   11],
     | 70.00th=[   12], 80.00th=[   12], 90.00th=[   13], 95.00th=[   14],
     | 99.00th=[   17], 99.50th=[   53], 99.90th=[ 1045], 99.95th=[ 1200],
     | 99.99th=[ 1687]
   bw (  KiB/s): min=   72, max=13304, per=100.00%, avg=8602.99, stdev=5296.31, samples=118
   iops        : min=   18, max= 3326, avg=2150.75, stdev=1324.08, samples=118
  lat (usec)   : 2=0.01%, 500=0.01%, 750=0.01%
  lat (msec)   : 2=0.01%, 4=0.01%, 10=37.85%, 20=61.53%, 50=0.10%
  lat (msec)   : 100=0.06%, 250=0.03%, 500=0.01%, 750=0.03%, 1000=0.25%
  lat (msec)   : 2000=0.14%
  cpu          : usr=0.70%, sys=4.01%, ctx=135029, majf=0, minf=4
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=0.1%, >=64=100.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.1%, >=64=0.0%
     issued rwt: total=128180,128223,0, short=0,0,0, dropped=0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=64

Run status group 0 (all jobs):
   READ: bw=8545KiB/s (8750kB/s), 8545KiB/s-8545KiB/s (8750kB/s-8750kB/s), io=501MiB (525MB), run=60001-60001msec
  WRITE: bw=8548KiB/s (8753kB/s), 8548KiB/s-8548KiB/s (8753kB/s-8753kB/s), io=501MiB (525MB), run=60001-60001msec

Disk stats (read/write):
  vda: ios=127922/87337, merge=0/237, ticks=55122/4269885, in_queue=2209125, util=94.29%

$fio -ioengine=libaio -bs=4k -direct=1 -buffered=0  -thread -rw=randrw  -size=4G -filename=/home/admin/fio.test -name="EBS 4K randwrite test" -iodepth=64 -runtime=60
EBS 4K randwrite test: (g=0): rw=randrw, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=64
fio-3.1
Starting 1 thread
Jobs: 1 (f=1): [m(1)][100.0%][r=9680KiB/s,w=9712KiB/s][r=2420,w=2428 IOPS][eta 00m:00s]
EBS 4K randwrite test: (groupid=0, jobs=1): err= 0: pid=25375: Tue Feb 23 16:33:03 2021
   read: IOPS=2462, BW=9849KiB/s (10.1MB/s)(577MiB/60011msec)
    slat (nsec): min=1558, max=10663k, avg=5900.28, stdev=46286.64
    clat (usec): min=290, max=93493, avg=13054.57, stdev=4301.89
     lat (usec): min=332, max=93497, avg=13060.60, stdev=4301.68
    clat percentiles (usec):
     |  1.00th=[ 1844],  5.00th=[10159], 10.00th=[10290], 20.00th=[10421],
     | 30.00th=[10552], 40.00th=[10552], 50.00th=[10683], 60.00th=[10814],
     | 70.00th=[18482], 80.00th=[19006], 90.00th=[19006], 95.00th=[19268],
     | 99.00th=[19530], 99.50th=[19792], 99.90th=[29492], 99.95th=[30278],
     | 99.99th=[43779]
   bw (  KiB/s): min= 9128, max=30392, per=100.00%, avg=9850.12, stdev=1902.00, samples=120
   iops        : min= 2282, max= 7598, avg=2462.52, stdev=475.50, samples=120
  write: IOPS=2465, BW=9864KiB/s (10.1MB/s)(578MiB/60011msec)
    slat (usec): min=2, max=10586, avg= 6.92, stdev=67.34
    clat (usec): min=240, max=69922, avg=12902.33, stdev=4307.92
     lat (usec): min=244, max=69927, avg=12909.37, stdev=4307.03
    clat percentiles (usec):
     |  1.00th=[ 1729],  5.00th=[10159], 10.00th=[10290], 20.00th=[10290],
     | 30.00th=[10421], 40.00th=[10421], 50.00th=[10552], 60.00th=[10683],
     | 70.00th=[18220], 80.00th=[18744], 90.00th=[19006], 95.00th=[19006],
     | 99.00th=[19268], 99.50th=[19530], 99.90th=[21103], 99.95th=[35390],
     | 99.99th=[50594]
   bw (  KiB/s): min= 8496, max=31352, per=100.00%, avg=9862.92, stdev=1991.48, samples=120
   iops        : min= 2124, max= 7838, avg=2465.72, stdev=497.87, samples=120
  lat (usec)   : 250=0.01%, 500=0.03%, 750=0.02%, 1000=0.02%
  lat (msec)   : 2=1.70%, 4=0.41%, 10=1.25%, 20=96.22%, 50=0.34%
  lat (msec)   : 100=0.01%
  cpu          : usr=0.89%, sys=4.09%, ctx=206337, majf=0, minf=4
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=0.1%, >=64=100.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.1%, >=64=0.0%
     issued rwt: total=147768,147981,0, short=0,0,0, dropped=0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=64

Run status group 0 (all jobs):
   READ: bw=9849KiB/s (10.1MB/s), 9849KiB/s-9849KiB/s (10.1MB/s-10.1MB/s), io=577MiB (605MB), run=60011-60011msec
  WRITE: bw=9864KiB/s (10.1MB/s), 9864KiB/s-9864KiB/s (10.1MB/s-10.1MB/s), io=578MiB (606MB), run=60011-60011msec

Disk stats (read/write):
  vda: ios=147515/148154, merge=0/231, ticks=1922378/1915751, in_queue=3780605, util=98.46%
  
$fio -ioengine=libaio -bs=4k -direct=0 -buffered=1  -thread -rw=randrw  -size=4G -filename=/home/admin/fio.test -name="EBS 4K randwrite test" -iodepth=64 -runtime=60
EBS 4K randwrite test: (g=0): rw=randrw, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=64
fio-3.1
Starting 1 thread
Jobs: 1 (f=1): [m(1)][100.0%][r=132KiB/s,w=148KiB/s][r=33,w=37 IOPS][eta 00m:00s]
EBS 4K randwrite test: (groupid=0, jobs=1): err= 0: pid=25892: Tue Feb 23 16:37:41 2021
   read: IOPS=1987, BW=7949KiB/s (8140kB/s)(467MiB/60150msec)
    slat (usec): min=192, max=599873, avg=479.26, stdev=2917.52
    clat (usec): min=15, max=1975.6k, avg=16004.22, stdev=76024.60
     lat (msec): min=5, max=2005, avg=16.48, stdev=78.00
    clat percentiles (msec):
     |  1.00th=[    8],  5.00th=[    9], 10.00th=[    9], 20.00th=[   10],
     | 30.00th=[   10], 40.00th=[   11], 50.00th=[   11], 60.00th=[   11],
     | 70.00th=[   12], 80.00th=[   12], 90.00th=[   13], 95.00th=[   14],
     | 99.00th=[   19], 99.50th=[  317], 99.90th=[ 1133], 99.95th=[ 1435],
     | 99.99th=[ 1871]
   bw (  KiB/s): min=   32, max=12672, per=100.00%, avg=8034.08, stdev=5399.63, samples=119
   iops        : min=    8, max= 3168, avg=2008.52, stdev=1349.91, samples=119
  write: IOPS=1984, BW=7937KiB/s (8127kB/s)(466MiB/60150msec)
    slat (usec): min=2, max=839634, avg=18.39, stdev=2747.10
    clat (msec): min=5, max=1975, avg=15.64, stdev=73.06
     lat (msec): min=5, max=1975, avg=15.66, stdev=73.28
    clat percentiles (msec):
     |  1.00th=[    8],  5.00th=[    9], 10.00th=[    9], 20.00th=[   10],
     | 30.00th=[   10], 40.00th=[   11], 50.00th=[   11], 60.00th=[   11],
     | 70.00th=[   12], 80.00th=[   12], 90.00th=[   13], 95.00th=[   14],
     | 99.00th=[   18], 99.50th=[  153], 99.90th=[ 1116], 99.95th=[ 1435],
     | 99.99th=[ 1921]
   bw (  KiB/s): min=   24, max=13160, per=100.00%, avg=8021.18, stdev=5405.12, samples=119
   iops        : min=    6, max= 3290, avg=2005.29, stdev=1351.28, samples=119
  lat (usec)   : 20=0.01%
  lat (msec)   : 10=36.51%, 20=62.63%, 50=0.21%, 100=0.12%, 250=0.05%
  lat (msec)   : 500=0.02%, 750=0.02%, 1000=0.19%, 2000=0.26%
  cpu          : usr=0.62%, sys=4.04%, ctx=125974, majf=0, minf=3
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=0.1%, >=64=100.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.1%, >=64=0.0%
     issued rwt: total=119533,119347,0, short=0,0,0, dropped=0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=64

Run status group 0 (all jobs):
   READ: bw=7949KiB/s (8140kB/s), 7949KiB/s-7949KiB/s (8140kB/s-8140kB/s), io=467MiB (490MB), run=60150-60150msec
  WRITE: bw=7937KiB/s (8127kB/s), 7937KiB/s-7937KiB/s (8127kB/s-8127kB/s), io=466MiB (489MB), run=60150-60150msec

Disk stats (read/write):
  vda: ios=119533/108186, merge=0/214, ticks=54093/4937255, in_queue=2525052, util=93.99%
  
$fio -ioengine=libaio -bs=4k -direct=0 -buffered=0  -thread -rw=randrw  -size=4G -filename=/home/admin/fio.test -name="EBS 4K randwrite test" -iodepth=64 -runtime=60
EBS 4K randwrite test: (g=0): rw=randrw, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=64
fio-3.1
Starting 1 thread
Jobs: 1 (f=1): [m(1)][100.0%][r=9644KiB/s,w=9792KiB/s][r=2411,w=2448 IOPS][eta 00m:00s]
EBS 4K randwrite test: (groupid=0, jobs=1): err= 0: pid=26139: Tue Feb 23 16:39:43 2021
   read: IOPS=2455, BW=9823KiB/s (10.1MB/s)(576MiB/60015msec)
    slat (nsec): min=1619, max=18282k, avg=5882.81, stdev=71214.52
    clat (usec): min=281, max=64630, avg=13055.68, stdev=4233.17
     lat (usec): min=323, max=64636, avg=13061.69, stdev=4232.79
    clat percentiles (usec):
     |  1.00th=[ 2040],  5.00th=[10290], 10.00th=[10421], 20.00th=[10421],
     | 30.00th=[10552], 40.00th=[10552], 50.00th=[10683], 60.00th=[10814],
     | 70.00th=[18220], 80.00th=[19006], 90.00th=[19006], 95.00th=[19268],
     | 99.00th=[19530], 99.50th=[20055], 99.90th=[28967], 99.95th=[29754],
     | 99.99th=[30540]
   bw (  KiB/s): min= 8776, max=27648, per=100.00%, avg=9824.29, stdev=1655.78, samples=120
   iops        : min= 2194, max= 6912, avg=2456.05, stdev=413.95, samples=120
  write: IOPS=2458, BW=9835KiB/s (10.1MB/s)(576MiB/60015msec)
    slat (usec): min=2, max=10681, avg= 6.79, stdev=71.30
    clat (usec): min=221, max=70411, avg=12909.50, stdev=4312.40
     lat (usec): min=225, max=70414, avg=12916.40, stdev=4312.05
    clat percentiles (usec):
     |  1.00th=[ 1909],  5.00th=[10159], 10.00th=[10290], 20.00th=[10290],
     | 30.00th=[10421], 40.00th=[10421], 50.00th=[10552], 60.00th=[10683],
     | 70.00th=[18220], 80.00th=[18744], 90.00th=[19006], 95.00th=[19006],
     | 99.00th=[19268], 99.50th=[19530], 99.90th=[28705], 99.95th=[40109],
     | 99.99th=[60031]
   bw (  KiB/s): min= 8568, max=28544, per=100.00%, avg=9836.03, stdev=1737.29, samples=120
   iops        : min= 2142, max= 7136, avg=2458.98, stdev=434.32, samples=120
  lat (usec)   : 250=0.01%, 500=0.03%, 750=0.02%, 1000=0.02%
  lat (msec)   : 2=1.03%, 4=1.10%, 10=0.98%, 20=96.43%, 50=0.38%
  lat (msec)   : 100=0.01%
  cpu          : usr=0.82%, sys=4.32%, ctx=212008, majf=0, minf=4
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=0.1%, >=64=100.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.1%, >=64=0.0%
     issued rwt: total=147386,147564,0, short=0,0,0, dropped=0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=64

Run status group 0 (all jobs):
   READ: bw=9823KiB/s (10.1MB/s), 9823KiB/s-9823KiB/s (10.1MB/s-10.1MB/s), io=576MiB (604MB), run=60015-60015msec
  WRITE: bw=9835KiB/s (10.1MB/s), 9835KiB/s-9835KiB/s (10.1MB/s-10.1MB/s), io=576MiB (604MB), run=60015-60015msec

Disk stats (read/write):
  vda: ios=147097/147865, merge=0/241, ticks=1916703/1915836, in_queue=3791443, util=98.68%
```

各类型云盘的性能比较如下表所示。

| 性能类别                                | ESSD AutoPL云盘（邀测）    | ESSD PL-X云盘（邀测） | ESSD云盘 PL3                  | ESSD云盘 PL0                | ESSD云盘 PL1               | ESSD云盘 PL0                 | SSD云盘                    | 高效云盘                 | 普通云盘 |
| :-------------------------------------- | :------------------------- | :-------------------- | :---------------------------- | :-------------------------- | :------------------------- | :--------------------------- | -------------------------- | ------------------------ | -------- |
| 单盘容量范围（GiB）                     | 40~32,768                  | 40~32,768             | 1261~32,768                   | 461~32,768                  | 20~32,768                  | 40~32,768                    | 20~32,768                  | 20~32,768                | 5~2,000  |
| 最大IOPS                                | 100,000                    | 3,000,000             | 1,000,000                     | 100,000                     | 50,000                     | 10,000                       | 25,000                     | 5,000                    | 数百     |
| 最大吞吐量（MB/s）                      | 1,131                      | 12,288                | 4,000                         | 750                         | 350                        | 180                          | 300                        | 140                      | 30~40    |
| 单盘IOPS性能计算公式                    | min{1,800+50*容量, 50,000} | 预配置IOPS            | min{1,800+50*容量, 1,000,000} | min{1,800+50*容量, 100,000} | min{1,800+50*容量, 50,000} | min{ 1,800+12*容量, 10,000 } | min{1,800+30*容量, 25,000} | min{1,800+8*容量, 5,000} | 无       |
| 单盘吞吐量性能计算公式（MB/s）          | min{120+0.5*容量, 350}     | 4 KB*预配置IOPS/1024  | min{120+0.5*容量, 4,000}      | min{120+0.5*容量, 750}      | min{120+0.5*容量, 350}     | min{100+0.25*容量, 180}      | min{120+0.5*容量, 300}     | min{100+0.15*容量, 140}  | 无       |
| 单路随机写平均时延（ms），Block Size=4K | 0.2                        | 0.03                  | 0.2                           | 0.2                         | 0.2                        | 0.3~0.5                      | 0.5~2                      | 1~3                      | 5~10     |
| API参数取值                             | cloud_auto                 | cloud_plx             | cloud_essd                    | cloud_essd                  | cloud_essd                 | cloud_essd                   | cloud_ssd                  | cloud_efficiency         | cloud    |

#### ESSD PL3测试

测试命令

```
fio -ioengine=libaio -bs=4k -buffered=1 -thread -rw=randwrite -rwmixread=70 -size=160G -filename=./fio.test -name="EBS 4K randwrite test" -iodepth=64 -runtime=60
```

ESSD 是PL3，LVM是海光物理机下两块本地NVMe SSD做的LVM，测试基于ext4文件系统，阿里云官方提供ESSD的IOPS是裸盘（不含文件系统的）

|                                                              | 本地LVM                                                      | ESSD                                                         |
| ------------------------------------------------------------ | ------------------------------------------------------------ | ------------------------------------------------------------ |
| fio -ioengine=libaio -bs=4k -buffered=1 read                 | bw=36636KB/s, iops=9159<br/>nvme0n1:util=42.31%<br/>nvme1n1: util=41.63% | IOPS=3647, BW=14.2MiB/s<br/>util=88.08%                      |
| fio -ioengine=libaio -bs=4k -buffered=1 write                | bw=383626KB/s, iops=95906<br/>nvme0n1:util=37.16%<br/>nvme1n1: util=33.58% | IOPS=104k, BW=406MiB/s<br/>util=39.06%                       |
| fio -ioengine=libaio -bs=4k -buffered=1 randrw rwmixread=70  | write: bw=12765KB/s, iops=3191<br/>read : bw=29766KB/s, iops=7441<br/>nvme0n1:util=35.18%<br/>nvme1n1: util=35.04% | write:IOPS=1701, BW=6808KiB/s<br/>read: IOPS=3962, BW=15.5MiB/s<br/> nvme7n1: util=99.35% |
| fio -ioengine=libaio -bs=4k -direct=1 -buffered=0 read       | bw=67938KB/s, iops=16984<br/>nvme0n1:util=43.17%<br/>nvme1n1: util=39.18% | IOPS=4687, BW=18.3MiB/s<br/>util=99.75%                      |
| fio -ioengine=libaio -bs=4k -direct=1 -buffered=0 write      | bw=160775KB/s, iops=40193<br/>nvme0n1:util=28.66%<br/>nvme1n1: util=21.67% | IOPS=7153, BW=27.9MiB/s<br/>util=99.85%                      |
| fio -ioengine=libaio -bs=4k -direct=1 -buffered=0 randrw rwmixread=70 | write: bw=23087KB/s, iops=5771<br/>read : bw=53849KB/s, iops=13462 | write:IOPS=1511, BW=6045KiB/s<br/>read: IOPS=3534, BW=13.8MiB/s |

结论：

- ESSD只要有随机读性能就很差,纯读是本地盘（LVM）的40%，纯写和本地盘差不多
- direct 读是本地盘的四分之一
- direct 写是本地盘的六分之一，写16K Page差距缩小到五分之一（5749/25817）
- intel direct 写本地intel SSDPE2KX040T8 iops=55826（比海光好40%，海光是memblaze）
- ESSD带buffer读写抖动很大
- ESSD出现过多次ESSD卡死，表现就是磁盘不响应任何操作，大概N分钟后恢复，原因未知

PL3单盘IOPS性能计算公式  min{1800+50*容量, 1000000}



```
[essd_pl3]# fio -ioengine=libaio -bs=4k -direct=1 -buffered=1 -thread -rw=randwrite -rwmixread=70 -size=160G -filename=./fio.test -name="EBS 4K randwrite test" -iodepth=64 -runtime=60
EBS 4K randwrite test: (g=0): rw=randwrite, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=64
fio-3.7
Starting 1 thread
Jobs: 1 (f=1): [w(1)][100.0%][r=0KiB/s,w=566MiB/s][r=0,w=145k IOPS][eta 00m:00s]
EBS 4K randwrite test: (groupid=0, jobs=1): err= 0: pid=2416234: Thu Apr  7 17:03:07 2022
  write: IOPS=96.2k, BW=376MiB/s (394MB/s)(22.0GiB/60000msec)
    slat (usec): min=2, max=530984, avg= 8.27, stdev=1104.96
    clat (usec): min=2, max=944103, avg=599.25, stdev=9230.93
     lat (usec): min=7, max=944111, avg=607.60, stdev=9308.81
    clat percentiles (usec):
     |  1.00th=[   392],  5.00th=[   400], 10.00th=[   404], 20.00th=[   408],
     | 30.00th=[   412], 40.00th=[   416], 50.00th=[   420], 60.00th=[   424],
     | 70.00th=[   433], 80.00th=[   441], 90.00th=[   457], 95.00th=[   482],
     | 99.00th=[   627], 99.50th=[   766], 99.90th=[  1795], 99.95th=[  4228],
     | 99.99th=[488637]
   bw (  KiB/s): min=  168, max=609232, per=100.00%, avg=422254.17, stdev=257181.75, samples=108
   iops        : min=   42, max=152308, avg=105563.63, stdev=64295.48, samples=108
  lat (usec)   : 4=0.01%, 10=0.01%, 50=0.01%, 100=0.01%, 250=0.01%
  lat (usec)   : 500=96.35%, 750=3.11%, 1000=0.26%
  lat (msec)   : 2=0.19%, 4=0.03%, 10=0.02%, 250=0.01%, 500=0.03%
  lat (msec)   : 750=0.01%, 1000=0.01%
  cpu          : usr=13.56%, sys=60.78%, ctx=1455, majf=0, minf=9743
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=0.1%, >=64=100.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.1%, >=64=0.0%
     issued rwts: total=0,5771972,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=64

Run status group 0 (all jobs):
  WRITE: bw=376MiB/s (394MB/s), 376MiB/s-376MiB/s (394MB/s-394MB/s), io=22.0GiB (23.6GB), run=60000-60000msec

Disk stats (read/write):
  vdb: ios=0/1463799, merge=0/7373, ticks=0/2011879, in_queue=2011879, util=27.85%
  
[essd_pl3]# fio -ioengine=libaio -bs=4k -direct=1 -buffered=1 -thread -rw=randread -rwmixread=70 -size=160G -filename=./fio.test -name="EBS 4K randwrite test" -iodepth=64 -runtime=60
EBS 4K randwrite test: (g=0): rw=randread, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=64
fio-3.7
Starting 1 thread
Jobs: 1 (f=1): [r(1)][100.0%][r=15.9MiB/s,w=0KiB/s][r=4058,w=0 IOPS][eta 00m:00s]
EBS 4K randwrite test: (groupid=0, jobs=1): err= 0: pid=2441598: Thu Apr  7 17:05:10 2022
   read: IOPS=3647, BW=14.2MiB/s (14.9MB/s)(855MiB/60001msec)
    slat (usec): min=183, max=10119, avg=239.01, stdev=110.20
    clat (usec): min=2, max=54577, avg=15170.17, stdev=1324.10
     lat (usec): min=237, max=55110, avg=15409.34, stdev=1338.09
    clat percentiles (usec):
     |  1.00th=[13960],  5.00th=[14091], 10.00th=[14222], 20.00th=[14484],
     | 30.00th=[14615], 40.00th=[14746], 50.00th=[14877], 60.00th=[15139],
     | 70.00th=[15270], 80.00th=[15533], 90.00th=[16057], 95.00th=[16712],
     | 99.00th=[20317], 99.50th=[22152], 99.90th=[26346], 99.95th=[30802],
     | 99.99th=[52691]
   bw (  KiB/s): min= 6000, max=17272, per=100.00%, avg=16511.28, stdev=1140.64, samples=105
   iops        : min= 1500, max= 4318, avg=4127.81, stdev=285.16, samples=105
  lat (usec)   : 4=0.01%, 250=0.01%, 500=0.01%, 750=0.01%, 1000=0.01%
  lat (msec)   : 2=0.01%, 4=0.01%, 10=0.01%, 20=98.91%, 50=1.05%
  lat (msec)   : 100=0.02%
  cpu          : usr=0.18%, sys=17.18%, ctx=219041, majf=0, minf=4215
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=0.1%, >=64=100.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.1%, >=64=0.0%
     issued rwts: total=218835,0,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=64

Run status group 0 (all jobs):
   READ: bw=14.2MiB/s (14.9MB/s), 14.2MiB/s-14.2MiB/s (14.9MB/s-14.9MB/s), io=855MiB (896MB), run=60001-60001msec

Disk stats (read/write):
  vdb: ios=218343/7992, merge=0/8876, ticks=50566/3749, in_queue=54315, util=88.08%  
 
[essd_pl3]# fio -ioengine=libaio -bs=4k -direct=1 -buffered=1 -thread -rw=randrw -rwmixread=70 -size=160G -filename=./fio.test -name="EBS 4K randwrite test" -iodepth=64 -runtime=60
EBS 4K randwrite test: (g=0): rw=randrw, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=64
fio-3.7
Starting 1 thread
Jobs: 1 (f=1): [m(1)][100.0%][r=15.7MiB/s,w=7031KiB/s][r=4007,w=1757 IOPS][eta 00m:00s]
EBS 4K randwrite test: (groupid=0, jobs=1): err= 0: pid=2641414: Thu Apr  7 17:21:10 2022
   read: IOPS=3962, BW=15.5MiB/s (16.2MB/s)(929MiB/60001msec)
    slat (usec): min=182, max=7194, avg=243.23, stdev=116.87
    clat (usec): min=2, max=235715, avg=11020.01, stdev=3366.61
     lat (usec): min=253, max=235991, avg=11263.40, stdev=3375.49
    clat percentiles (msec):
     |  1.00th=[    9],  5.00th=[   10], 10.00th=[   10], 20.00th=[   11],
     | 30.00th=[   11], 40.00th=[   11], 50.00th=[   11], 60.00th=[   12],
     | 70.00th=[   12], 80.00th=[   12], 90.00th=[   13], 95.00th=[   14],
     | 99.00th=[   16], 99.50th=[   18], 99.90th=[   31], 99.95th=[   36],
     | 99.99th=[  234]
   bw (  KiB/s): min=10808, max=17016, per=100.00%, avg=15977.89, stdev=895.35, samples=118
   iops        : min= 2702, max= 4254, avg=3994.47, stdev=223.85, samples=118
  write: IOPS=1701, BW=6808KiB/s (6971kB/s)(399MiB/60001msec)
    slat (usec): min=3, max=221631, avg=10.16, stdev=693.59
    clat (usec): min=486, max=235772, avg=11029.42, stdev=3590.93
     lat (usec): min=493, max=235780, avg=11039.67, stdev=3659.04
    clat percentiles (msec):
     |  1.00th=[    9],  5.00th=[   10], 10.00th=[   10], 20.00th=[   11],
     | 30.00th=[   11], 40.00th=[   11], 50.00th=[   11], 60.00th=[   12],
     | 70.00th=[   12], 80.00th=[   12], 90.00th=[   13], 95.00th=[   14],
     | 99.00th=[   16], 99.50th=[   18], 99.90th=[   31], 99.95th=[   37],
     | 99.99th=[  234]
   bw (  KiB/s): min= 4480, max= 7728, per=100.00%, avg=6862.60, stdev=475.79, samples=118
   iops        : min= 1120, max= 1932, avg=1715.64, stdev=118.97, samples=118
  lat (usec)   : 4=0.01%, 500=0.01%, 750=0.01%
  lat (msec)   : 2=0.01%, 4=0.01%, 10=20.77%, 20=78.89%, 50=0.31%
  lat (msec)   : 100=0.01%, 250=0.02%
  cpu          : usr=0.65%, sys=7.20%, ctx=239089, majf=0, minf=8292
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=0.1%, >=64=100.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.1%, >=64=0.0%
     issued rwts: total=237743,102115,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=64

Run status group 0 (all jobs):
   READ: bw=15.5MiB/s (16.2MB/s), 15.5MiB/s-15.5MiB/s (16.2MB/s-16.2MB/s), io=929MiB (974MB), run=60001-60001msec
  WRITE: bw=6808KiB/s (6971kB/s), 6808KiB/s-6808KiB/s (6971kB/s-6971kB/s), io=399MiB (418MB), run=60001-60001msec

Disk stats (read/write):
  vdb: ios=237216/118960, merge=0/8118, ticks=55191/148225, in_queue=203416, util=99.35%
  
[essd_pl3]# fio  -bs=4k -direct=1 -buffered=0 -thread -rw=randwrite -rwmixread=70 -size=16G -filename=./fio.test -name="EBS 4K randwrite test" -iodepth=64 -runtime=30
EBS 4K randwrite test: (g=0): rw=randwrite, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=psync, iodepth=64
fio-3.7
Starting 1 thread
Jobs: 1 (f=1): [w(1)][100.0%][r=0KiB/s,w=28.3MiB/s][r=0,w=7249 IOPS][eta 00m:00s]
EBS 4K randwrite test: (groupid=0, jobs=1): err= 0: pid=2470117: Fri Apr  8 15:35:20 2022
  write: IOPS=7222, BW=28.2MiB/s (29.6MB/s)(846MiB/30001msec)
    clat (usec): min=115, max=7155, avg=137.29, stdev=68.48
     lat (usec): min=115, max=7156, avg=137.36, stdev=68.49
    clat percentiles (usec):
     |  1.00th=[  121],  5.00th=[  123], 10.00th=[  125], 20.00th=[  126],
     | 30.00th=[  127], 40.00th=[  129], 50.00th=[  130], 60.00th=[  133],
     | 70.00th=[  135], 80.00th=[  139], 90.00th=[  149], 95.00th=[  163],
     | 99.00th=[  255], 99.50th=[  347], 99.90th=[  668], 99.95th=[  947],
     | 99.99th=[ 3589]
   bw (  KiB/s): min=23592, max=30104, per=99.95%, avg=28873.29, stdev=1084.49, samples=59
   iops        : min= 5898, max= 7526, avg=7218.32, stdev=271.12, samples=59
  lat (usec)   : 250=98.95%, 500=0.81%, 750=0.17%, 1000=0.03%
  lat (msec)   : 2=0.02%, 4=0.02%, 10=0.01%
  cpu          : usr=0.72%, sys=5.08%, ctx=216767, majf=0, minf=148
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=0,216677,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=64

Run status group 0 (all jobs):
  WRITE: bw=28.2MiB/s (29.6MB/s), 28.2MiB/s-28.2MiB/s (29.6MB/s-29.6MB/s), io=846MiB (888MB), run=30001-30001msec

Disk stats (read/write):
  vdb: ios=0/219122, merge=0/3907, ticks=0/29812, in_queue=29812, util=99.52% 
  
[root@hygon8 14:44 /polarx/lvm]
#fio  -bs=4k -direct=1 -buffered=0 -thread -rw=randwrite -rwmixread=70 -size=16G -filename=./fio.test -name="EBS 4K randwrite test" -iodepth=64 -runtime=30
EBS 4K randwrite test: (g=0): rw=randwrite, bs=4K-4K/4K-4K/4K-4K, ioengine=sync, iodepth=64
fio-2.2.8
Starting 1 thread
Jobs: 1 (f=1): [w(1)] [100.0% done] [0KB/157.2MB/0KB /s] [0/40.3K/0 iops] [eta 00m:00s]
EBS 4K randwrite test: (groupid=0, jobs=1): err= 0: pid=3486352: Fri Apr  8 14:45:43 2022
  write: io=4710.4MB, bw=160775KB/s, iops=40193, runt= 30001msec
    clat (usec): min=18, max=4164, avg=22.05, stdev= 7.33
     lat (usec): min=19, max=4165, avg=22.59, stdev= 7.36
    clat percentiles (usec):
     |  1.00th=[   20],  5.00th=[   20], 10.00th=[   21], 20.00th=[   21],
     | 30.00th=[   21], 40.00th=[   21], 50.00th=[   21], 60.00th=[   22],
     | 70.00th=[   22], 80.00th=[   22], 90.00th=[   23], 95.00th=[   25],
     | 99.00th=[   36], 99.50th=[   40], 99.90th=[   62], 99.95th=[   99],
     | 99.99th=[  157]
    bw (KB  /s): min=147568, max=165400, per=100.00%, avg=160803.12, stdev=2704.22
    lat (usec) : 20=0.08%, 50=99.70%, 100=0.17%, 250=0.04%, 500=0.01%
    lat (usec) : 750=0.01%, 1000=0.01%
    lat (msec) : 2=0.01%, 10=0.01%
  cpu          : usr=6.95%, sys=31.18%, ctx=1205994, majf=0, minf=1573
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued    : total=r=0/w=1205849/d=0, short=r=0/w=0/d=0, drop=r=0/w=0/d=0
     latency   : target=0, window=0, percentile=100.00%, depth=64

Run status group 0 (all jobs):
  WRITE: io=4710.4MB, aggrb=160774KB/s, minb=160774KB/s, maxb=160774KB/s, mint=30001msec, maxt=30001msec

Disk stats (read/write):
    dm-2: ios=0/1204503, merge=0/0, ticks=0/15340, in_queue=15340, util=50.78%, aggrios=0/603282, aggrmerge=0/463, aggrticks=0/8822, aggrin_queue=0, aggrutil=28.66%
  nvme0n1: ios=0/683021, merge=0/474, ticks=0/9992, in_queue=0, util=28.66%
  nvme1n1: ios=0/523543, merge=0/452, ticks=0/7652, in_queue=0, util=21.67%
  
[root@x86.170 /polarx/lvm]
#/usr/sbin/nvme list
Node             SN                   Model                                    Namespace Usage                      Format           FW Rev
---------------- -------------------- ---------------------------------------- --------- -------------------------- ---------------- --------
/dev/nvme0n1     BTLJ932205P44P0DGN   INTEL SSDPE2KX040T8                      1           3.84  TB /   3.84  TB    512   B +  0 B   VDV10131
/dev/nvme1n1     BTLJ932207H04P0DGN   INTEL SSDPE2KX040T8                      1           3.84  TB /   3.84  TB    512   B +  0 B   VDV10131
/dev/nvme2n1     BTLJ932205AS4P0DGN   INTEL SSDPE2KX040T8                      1           3.84  TB /   3.84  TB    512   B +  0 B   VDV10131
[root@x86.170 /polarx/lvm]
#fio  -bs=4k  -direct=1 -buffered=0 -thread -rw=randwrite -rwmixread=70 -size=16G -filename=./fio.test -name="EBS 4K randwrite test" -iodepth=64 -runtime=30
EBS 4K randwrite test: (g=0): rw=randwrite, bs=4K-4K/4K-4K/4K-4K, ioengine=sync, iodepth=64
fio-2.2.8
Starting 1 thread
Jobs: 1 (f=1): [w(1)] [100.0% done] [0KB/240.2MB/0KB /s] [0/61.5K/0 iops] [eta 00m:00s]
EBS 4K randwrite test: (groupid=0, jobs=1): err= 0: pid=11516: Fri Apr  8 15:44:36 2022
  write: io=7143.3MB, bw=243813KB/s, iops=60953, runt= 30001msec
    clat (usec): min=10, max=818, avg=14.96, stdev= 4.14
     lat (usec): min=10, max=818, avg=15.14, stdev= 4.15
    clat percentiles (usec):
     |  1.00th=[   11],  5.00th=[   12], 10.00th=[   12], 20.00th=[   14],
     | 30.00th=[   15], 40.00th=[   15], 50.00th=[   15], 60.00th=[   15],
     | 70.00th=[   15], 80.00th=[   16], 90.00th=[   16], 95.00th=[   16],
     | 99.00th=[   20], 99.50th=[   32], 99.90th=[   78], 99.95th=[   84],
     | 99.99th=[  105]
    bw (KB  /s): min=236768, max=246424, per=99.99%, avg=243794.17, stdev=1736.82
    lat (usec) : 20=98.96%, 50=0.73%, 100=0.29%, 250=0.01%, 500=0.01%
    lat (usec) : 750=0.01%, 1000=0.01%
  cpu          : usr=10.65%, sys=42.66%, ctx=1828699, majf=0, minf=7
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued    : total=r=0/w=1828662/d=0, short=r=0/w=0/d=0, drop=r=0/w=0/d=0
     latency   : target=0, window=0, percentile=100.00%, depth=64

Run status group 0 (all jobs):
  WRITE: io=7143.3MB, aggrb=243813KB/s, minb=243813KB/s, maxb=243813KB/s, mint=30001msec, maxt=30001msec

Disk stats (read/write):
    dm-0: ios=0/1823575, merge=0/0, ticks=0/13666, in_queue=13667, util=45.56%, aggrios=0/609558, aggrmerge=0/2, aggrticks=0/4280, aggrin_queue=4198, aggrutil=14.47%
  nvme0n1: ios=0/609144, merge=0/6, ticks=0/4438, in_queue=4353, util=14.47%
  nvme1n1: ios=0/609470, merge=0/0, ticks=0/4186, in_queue=4109, util=13.65%
  nvme2n1: ios=0/610060, merge=0/0, ticks=0/4216, in_queue=4134, util=13.74% 
```



### HDD性能测试数据

![img](/images/951413iMgBlog/0868d560-067f-4302-bc60-bffc3d4460ed.png)

从上图可以看到这个磁盘的IOPS 读 935 写 400，读rt 10731nsec 大约10us, 写 17us。如果IOPS是1000的话，rt应该是1ms，实际比1ms小两个数量级，~~应该是cache、磁盘阵列在起作用。~~

SATA硬盘，10K转

万转机械硬盘组成RAID5阵列，在顺序条件最好的情况下，带宽可以达到1GB/s以上，平均延时也非常低，最低只有20多us。但是在随机IO的情况下，机械硬盘的短板就充分暴露了，零点几兆的带宽，将近5ms的延迟，IOPS只有200左右。其原因是因为

- 随机访问直接让RAID卡缓存成了个摆设
- 磁盘不能并行工作，因为我的机器RAID宽度Strip Size为128 KB
- 机械轴也得在各个磁道之间跳来跳去。

理解了磁盘顺序IO时候的几十M甚至一个GB的带宽，随机IO这个真的是太可怜了。

从上面的测试数据中我们看到了机械硬盘在顺序IO和随机IO下的巨大性能差异。在顺序IO情况下，磁盘是最擅长的顺序IO,再加上Raid卡缓存命中率也高。这时带宽表现有几十、几百M，最好条件下甚至能达到1GB。IOPS这时候能有2-3W左右。到了随机IO的情形下，机械轴也被逼的跳来跳去寻道，RAID卡缓存也失效了。带宽跌到了1MB以下，最低只有100K，IOPS也只有可怜巴巴的200左右。

## 测试数据总结

|          | -direct=1 -buffered=1 | -direct=0 -buffered=1 | -direct=1 -buffered=0 | -direct=0 -buffered=0 |
| -------- | --------------------- | --------------------- | --------------------- | --------------------- |
| NVMe SSD | R=10.6k W=4544        | R=10.8K W=4642        | R=99.8K W=42.8K       | R=38.6k W=16.5k       |
| SATA SSD | R=4312 W=1852         | R=5389 W=2314         | R=16.9k W=7254        | R=15.8k W=6803        |
| ESSD     | R=2149 W=2150         | R=1987 W=1984         | R=2462 W=2465         | R=2455 W=2458         |

看起来，**对于SSD如果buffered为1的话direct没啥用，如果buffered为0那么direct为1性能要好很多**

**SATA SSD的IOPS比NVMe性能差很多**。

SATA SSD当-buffered=1参数下SATA SSD的latency在7-10us之间。 

NVMe SSD以及SATA SSD当buffered=0的条件下latency均为2-3us,  NVMe SSD latency参考文章第一个表格， 和本次NVMe测试结果一致.  

ESSD的latency基本是13-16us。

以上NVMe SSD测试数据是在测试过程中还有mysql在全力导入数据的情况下，用fio测试所得。所以空闲情况下测试结果会更好。

### [网上测试数据参考](https://zhuanlan.zhihu.com/p/40497397)

我们来一起看一下具体的数据。首先来看NVＭe如何减小了协议栈本身的时间消耗，我们用*blktrace*工具来分析一组传输在应用程序层、操作系统层、驱动层和硬件层消耗的时间和占比，来了解AHCI和NVMe协议的性能区别：

![img](/images/951413iMgBlog/v2-8b37f236d5c754efabe17aa9706f99a3_720w.jpg)

硬盘HDD作为一个参考基准，它的时延是非常大的，达到14ms，而AHCI SATA为125us，NVMe为111us。我们从图中可以看出，NVMe相对AHCI，协议栈及之下所占用的时间比重明显减小，应用程序层面等待的时间占比很高，这是因为SSD物理硬盘速度不够快，导致应用空转。NVMe也为将来Optane硬盘这种低延迟介质的速度提高留下了广阔的空间。

## 对比LVM 、RAID0和 一块NVMe SSD

曙光H620-G30A机型下测试

各拿两块nvme，分别作LVM和RAID0，另外单独拿一块nvme直接读写，条带用的是4块nvme做的，然后比较顺序、随机读写，测试结果如下：

|                                                   | RAID0（2块盘）                                               | NVMe                                               | LVM                                                          | RAID0（4块盘）                                               | 条带（4块 linear）                                           |
| ------------------------------------------------- | ------------------------------------------------------------ | -------------------------------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------ | ------------------------------------------------------------ |
| dd write bs=1M count=10240 conv=fsync             | 10.9秒                                                       | 23秒                                               | 24.6秒                                                       | 10.9秒                                                       | 11.9秒                                                       |
| fio -ioengine=libaio -bs=4k  -buffered=1          | bw=346744KB/s, iops=86686 <br/> nvme6n1: util=38.43%<br/> nvme7n1: util=38.96% | bw=380816KB/s, iops=95203<br/>nvme2n1: util=68.31% | bw=175704KB/s, iops=43925<br/>nvme0n1:util=29.60%<br/>nvme1n1: util=25.64% | bw=337495KB/s, iops=84373<br/> nvme6n1: util=20.93%<br/> nvme5n1: util=21.30%<br/> nvme4n1: util=21.12%<br/> nvme7n1: util=20.95% | bw=329721KB/s, iops=82430<br/> nvme0n1: util=67.22%<br/> nvme3n1: util=0%<br/>条带每次只写一块盘 |
| fio -ioengine=libaio -bs=4k -direct=1 -buffered=0 | bw=121556KB/s, iops=30389 <br/> nvme6n1: util=18.70%<br/> nvme7n1: util=18.91% | bw=126215KB/s, iops=31553<br/>nvme2n1: util=37.27% | bw=117192KB/s, iops=29297<br/>nvme0n1:util=21.16%<br/>nvme1n1: util=13.35% | bw=119145KB/s, iops=29786<br/> nvme6n1: util=9.19%<br/> nvme5n1: util=9.45%<br/> nvme4n1: util=9.45%<br/> nvme7n1: util=9.30% | bw=116688KB/s, iops=29171<br/> nvme0n1: util=37.87%<br/> nvme3n1: util=0%<br/>条带每次只写一块盘 |
| fio -bs=4k -direct=1 -buffered=0                  | bw=104107KB/s, iops=26026 <br/> nvme6n1: util=15.55%<br/> nvme7n1: util=15.00% | bw=105115KB/s, iops=26278<br/>nvme2n1: util=31.25% | bw=101936KB/s, iops=25484<br/>nvme0n1:util=17.76%<br/>nvme1n1: util=12.07% | bw=102517KB/s, iops=25629<br/> nvme6n1: util=8.13%<br/> nvme5n1: util=7.65%<br/> nvme4n1: util=7.57%<br/> nvme7n1: util=7.75% | bw=87280KB/s, iops=21820<br/> nvme0n1: util=31.27%<br/> nvme3n1: util=0%<br/>条带每次只写一块盘 |

- 整体看 nvme 最好(顺序写除外)，raid0性能接近nvme，LVM最差
- 顺序写raid0是nvme、LVM的两倍
- 随机读写带buffered的话 nvme最好，raid0略差（猜测是软件消耗），LVM只有前两者的一半
- 关掉buffered 三者性能下降都很大，最终差异变小
- raid0下两块盘非常均衡，LVM下两块盘负载差异比较大
- 性能不在单块盘到了瓶颈，当阵列中盘数变多后，软件实现的LVM、RAID性能都有下降
- 开buffer对性能提升非常大
- 每次测试前都会echo 3 > /proc/sys/vm/drop_caches ; rm -f ./fio.test ;测试跑多次，取稳定值

### 顺序读写

然后同时做dd写入测试

```shell
time taskset -c 0 dd if=/dev/zero of=./tempfile2 bs=1M count=40240 &
```

下图上面两块nvme做的LVM，下面两块nvme做成RAID0，同时开始测试，可以看到RAID0的两块盘写入速度更快

![image-20211231205730735](/images/951413iMgBlog/image-20211231205730735.png)

测试结果

![image-20211231205842753](/images/951413iMgBlog/image-20211231205842753.png)

实际单独写一块nvme也比写两块nvme做的LVM要快一倍，对dd这样的顺序读写，软RAID0还是能提升一倍速度的

```
[root@hygon33 14:02 /nvme]
#echo 3 > /proc/sys/vm/drop_caches ; rm -f ./tempfile2 ; time taskset -c 16 dd if=/dev/zero of=./tempfile2 bs=1M count=10240 conv=fsync
记录了10240+0 的读入
记录了10240+0 的写出
10737418240字节（11 GB，10 GiB）已复制，23.0399 s，466 MB/s

real	0m23.046s
user	0m0.004s
sys	0m8.033s

[root@hygon33 14:08 /nvme]
#cd ../md0/

[root@hygon33 14:08 /md0]
#echo 3 > /proc/sys/vm/drop_caches ; rm -f ./tempfile2 ; time taskset -c 16 dd if=/dev/zero of=./tempfile2 bs=1M count=10240 conv=fsync
记录了10240+0 的读入
记录了10240+0 的写出
10737418240字节（11 GB，10 GiB）已复制，10.9632 s，979 MB/s

real	0m10.967s
user	0m0.004s
sys	0m10.899s

[root@hygon33 14:08 /md0]
#cd /polarx/

[root@hygon33 14:08 /polarx]
#echo 3 > /proc/sys/vm/drop_caches ; rm -f ./tempfile2 ; time taskset -c 16 dd if=/dev/zero of=./tempfile2 bs=1M count=10240 conv=fsync
记录了10240+0 的读入
记录了10240+0 的写出
10737418240字节（11 GB，10 GiB）已复制，24.6481 s，436 MB/s

real	0m24.653s
user	0m0.008s
sys	0m24.557s
```

### 随机读写

SSD单独的随机读IOPS大概是随机写IOPS的10%, 应该是因为write有cache

RAID0是使用mdadm做的软raid，系统层面还是有消耗，没法和RAID卡硬件比较

左边是一块nvme，中间是两块nvme做了LVM，右边是两块nvme做RAID0，看起来速度差不多，一块nvme似乎要好一点点

```
fio -ioengine=libaio -bs=4k -buffered=1 -thread -rw=randwrite -rwmixread=70 -size=16G -filename=./fio.test -name="EBS 4K randwrite test" -iodepth=64 -runtime=60
```

![image-20220101104145331](/images/951413iMgBlog/image-20220101104145331.png)

从观察来看，RAID0的两块盘读写、iops都非常均衡，LVM的两块盘

三个测试分开跑，独立nvme性能最好，LVM最差并且不均衡

![image-20220101110016074](/images/951413iMgBlog/image-20220101110016074.png)

三个测试分开跑，去掉 aio，性能都只有原来的一半

```
fio  -bs=4k -direct=1 -buffered=0 -thread -rw=randwrite -rwmixread=70 -size=16G -filename=./fio.test -name="EBS 4K randwrite test" -iodepth=64 -runtime=60
```

![image-20220101110708888](/images/951413iMgBlog/image-20220101110708888.png)

修改fio参数，用最快的 direct=0 buffered=1 aio 结论是raid0最快，直接写nvme略慢，LVM只有raid0的一半

```
[root@hygon33 13:43 /md0]
#echo 3 > /proc/sys/vm/drop_caches ; rm -f ./fio.test; fio -ioengine=libaio -bs=4k -direct=0 -buffered=1 -thread -rw=randwrite -rwmixread=70 -size=16G -filename=./fio.test -name="EBS 4K randwrite test" -iodepth=64 -runtime=60
EBS 4K randwrite test: (g=0): rw=randwrite, bs=4K-4K/4K-4K/4K-4K, ioengine=libaio, iodepth=64
fio-2.2.8
Starting 1 thread
EBS 4K randwrite test: Laying out IO file(s) (1 file(s) / 16384MB)
Jobs: 1 (f=1): [w(1)] [98.1% done] [0KB/394.3MB/0KB /s] [0/101K/0 iops] [eta 00m:01s]
EBS 4K randwrite test: (groupid=0, jobs=1): err= 0: pid=21016: Sat Jan  1 13:45:25 2022
  write: io=16384MB, bw=329974KB/s, iops=82493, runt= 50844msec
    slat (usec): min=3, max=1496, avg= 9.00, stdev= 2.76
    clat (usec): min=5, max=2272, avg=764.73, stdev=101.63
     lat (usec): min=10, max=2282, avg=774.19, stdev=103.15
    clat percentiles (usec):
     |  1.00th=[  510],  5.00th=[  612], 10.00th=[  644], 20.00th=[  684],
     | 30.00th=[  700], 40.00th=[  716], 50.00th=[  772], 60.00th=[  820],
     | 70.00th=[  844], 80.00th=[  860], 90.00th=[  884], 95.00th=[  908],
     | 99.00th=[  932], 99.50th=[  940], 99.90th=[  988], 99.95th=[ 1064],
     | 99.99th=[ 1336]
    bw (KB  /s): min=277928, max=490720, per=99.84%, avg=329447.45, stdev=40386.54
    lat (usec) : 10=0.01%, 20=0.01%, 50=0.01%, 100=0.01%, 250=0.01%
    lat (usec) : 500=0.17%, 750=48.67%, 1000=51.08%
    lat (msec) : 2=0.08%, 4=0.01%
  cpu          : usr=17.79%, sys=81.97%, ctx=113, majf=0, minf=5526
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=0.1%, >=64=100.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.1%, >=64=0.0%
     issued    : total=r=0/w=4194304/d=0, short=r=0/w=0/d=0, drop=r=0/w=0/d=0
     latency   : target=0, window=0, percentile=100.00%, depth=64

Run status group 0 (all jobs):
  WRITE: io=16384MB, aggrb=329974KB/s, minb=329974KB/s, maxb=329974KB/s, mint=50844msec, maxt=50844msec

Disk stats (read/write):
    md0: ios=0/2883541, merge=0/0, ticks=0/0, in_queue=0, util=0.00%, aggrios=0/1232592, aggrmerge=0/219971, aggrticks=0/44029, aggrin_queue=0, aggrutil=38.91%
  nvme6n1: ios=0/1228849, merge=0/219880, ticks=0/43940, in_queue=0, util=37.19%
  nvme7n1: ios=0/1236335, merge=0/220062, ticks=0/44119, in_queue=0, util=38.91%
  
[root@hygon33 13:46 /nvme]
#echo 3 > /proc/sys/vm/drop_caches ; rm -f ./fio.test; fio -ioengine=libaio -bs=4k -direct=0 -buffered=1 -thread -rw=randwrite -rwmixread=70 -size=16G -filename=./fio.test -name="EBS 4K randwrite test" -iodepth=64 -runtime=60
EBS 4K randwrite test: (g=0): rw=randwrite, bs=4K-4K/4K-4K/4K-4K, ioengine=libaio, iodepth=64
fio-2.2.8
Starting 1 thread
EBS 4K randwrite test: Laying out IO file(s) (1 file(s) / 16384MB)
Jobs: 1 (f=1): [w(1)] [100.0% done] [0KB/314.3MB/0KB /s] [0/80.5K/0 iops] [eta 00m:00s]
EBS 4K randwrite test: (groupid=0, jobs=1): err= 0: pid=21072: Sat Jan  1 13:47:32 2022
  write: io=16384MB, bw=309554KB/s, iops=77388, runt= 54198msec
    slat (usec): min=3, max=88800, avg= 9.83, stdev=44.88
    clat (usec): min=5, max=89662, avg=815.09, stdev=381.75
     lat (usec): min=27, max=89748, avg=825.38, stdev=385.05
    clat percentiles (usec):
     |  1.00th=[  470],  5.00th=[  612], 10.00th=[  652], 20.00th=[  684],
     | 30.00th=[  716], 40.00th=[  756], 50.00th=[  796], 60.00th=[  836],
     | 70.00th=[  876], 80.00th=[  932], 90.00th=[ 1012], 95.00th=[ 1096],
     | 99.00th=[ 1272], 99.50th=[ 1368], 99.90th=[ 1688], 99.95th=[ 1912],
     | 99.99th=[ 3920]
    bw (KB  /s): min=247208, max=523840, per=99.99%, avg=309507.85, stdev=34709.01
    lat (usec) : 10=0.01%, 50=0.01%, 100=0.01%, 250=0.01%, 500=1.73%
    lat (usec) : 750=37.71%, 1000=49.60%
    lat (msec) : 2=10.91%, 4=0.03%, 10=0.01%, 100=0.01%
  cpu          : usr=16.00%, sys=79.36%, ctx=138668, majf=0, minf=5522
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=0.1%, >=64=100.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.1%, >=64=0.0%
     issued    : total=r=0/w=4194304/d=0, short=r=0/w=0/d=0, drop=r=0/w=0/d=0
     latency   : target=0, window=0, percentile=100.00%, depth=64

Run status group 0 (all jobs):
  WRITE: io=16384MB, aggrb=309554KB/s, minb=309554KB/s, maxb=309554KB/s, mint=54198msec, maxt=54198msec

Disk stats (read/write):
    dm-0: ios=77/1587455, merge=0/0, ticks=184/244940, in_queue=245124, util=98.23%, aggrios=77/1584444, aggrmerge=0/5777, aggrticks=183/193531, aggrin_queue=76, aggrutil=81.60%
  sda: ios=77/1584444, merge=0/5777, ticks=183/193531, in_queue=76, util=81.60%
  
[root@hygon33 13:50 /polarx]
#echo 3 > /proc/sys/vm/drop_caches ; rm -f ./fio.test; fio -ioengine=libaio -bs=4k -direct=0 -buffered=1 -thread -rw=randwrite -rwmixread=70 -size=16G -filename=./fio.test -name="EBS 4K randwrite test" -iodepth=64 -runtime=60
EBS 4K randwrite test: (g=0): rw=randwrite, bs=4K-4K/4K-4K/4K-4K, ioengine=libaio, iodepth=64
fio-2.2.8
Starting 1 thread
EBS 4K randwrite test: Laying out IO file(s) (1 file(s) / 16384MB)
Jobs: 1 (f=1): [w(1)] [100.0% done] [0KB/293.2MB/0KB /s] [0/75.1K/0 iops] [eta 00m:00s]
EBS 4K randwrite test: (groupid=0, jobs=1): err= 0: pid=22787: Sat Jan  1 13:51:16 2022
  write: io=10270MB, bw=175269KB/s, iops=43817, runt= 60001msec
    slat (usec): min=4, max=2609, avg=19.43, stdev=19.84
    clat (usec): min=4, max=6420, avg=1438.87, stdev=483.15
     lat (usec): min=17, max=6718, avg=1458.80, stdev=490.29
    clat percentiles (usec):
     |  1.00th=[  700],  5.00th=[  788], 10.00th=[  852], 20.00th=[  964],
     | 30.00th=[ 1080], 40.00th=[ 1208], 50.00th=[ 1368], 60.00th=[ 1560],
     | 70.00th=[ 1752], 80.00th=[ 1944], 90.00th=[ 2128], 95.00th=[ 2224],
     | 99.00th=[ 2416], 99.50th=[ 2480], 99.90th=[ 2672], 99.95th=[ 3248],
     | 99.99th=[ 5088]
    bw (KB  /s): min=109992, max=308016, per=99.40%, avg=174219.83, stdev=56844.59
    lat (usec) : 10=0.01%, 20=0.01%, 50=0.01%, 100=0.01%, 250=0.01%
    lat (usec) : 500=0.01%, 750=2.87%, 1000=20.63%
    lat (msec) : 2=59.43%, 4=17.03%, 10=0.03%
  cpu          : usr=9.11%, sys=57.07%, ctx=762410, majf=0, minf=1769
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=0.1%, >=64=100.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.1%, >=64=0.0%
     issued    : total=r=0/w=2629079/d=0, short=r=0/w=0/d=0, drop=r=0/w=0/d=0
     latency   : target=0, window=0, percentile=100.00%, depth=64

Run status group 0 (all jobs):
  WRITE: io=10270MB, aggrb=175269KB/s, minb=175269KB/s, maxb=175269KB/s, mint=60001msec, maxt=60001msec

Disk stats (read/write):
    dm-2: ios=1/3185487, merge=0/0, ticks=0/86364, in_queue=86364, util=46.24%, aggrios=0/1576688, aggrmerge=0/16344, aggrticks=0/40217, aggrin_queue=0, aggrutil=29.99%
  nvme0n1: ios=0/1786835, merge=0/16931, ticks=0/44447, in_queue=0, util=29.99%
  nvme1n1: ios=1/1366541, merge=0/15758, ticks=0/35987, in_queue=0, util=25.44%
  
```



将RAID0从两块nvme改成四块后，整体性能略微下降

```
#fio  -bs=4k -direct=1 -buffered=0 -thread -rw=randwrite -rwmixread=70 -size=16G -filename=./fio.test -name="EBS 4K randwrite test" -iodepth=64 -runtime=60
EBS 4K randwrite test: (g=0): rw=randwrite, bs=4K-4K/4K-4K/4K-4K, ioengine=sync, iodepth=64
fio-2.2.8
Starting 1 thread
EBS 4K randwrite test: Laying out IO file(s) (1 file(s) / 16384MB)
Jobs: 1 (f=1): [w(1)] [100.0% done] [0KB/99756KB/0KB /s] [0/24.1K/0 iops] [eta 00m:00s]
EBS 4K randwrite test: (groupid=0, jobs=1): err= 0: pid=30608: Sat Jan  1 12:09:29 2022
  write: io=5733.9MB, bw=97857KB/s, iops=24464, runt= 60001msec
    clat (usec): min=29, max=2885, avg=37.95, stdev=12.19
     lat (usec): min=30, max=2886, avg=38.49, stdev=12.20
    clat percentiles (usec):
     |  1.00th=[   32],  5.00th=[   33], 10.00th=[   34], 20.00th=[   35],
     | 30.00th=[   36], 40.00th=[   36], 50.00th=[   37], 60.00th=[   37],
     | 70.00th=[   38], 80.00th=[   39], 90.00th=[   40], 95.00th=[   49],
     | 99.00th=[   65], 99.50th=[   76], 99.90th=[  109], 99.95th=[  125],
     | 99.99th=[  203]
    bw (KB  /s): min=92968, max=108344, per=99.99%, avg=97846.18, stdev=2085.73
    lat (usec) : 50=95.20%, 100=4.61%, 250=0.18%, 500=0.01%, 750=0.01%
    lat (usec) : 1000=0.01%
    lat (msec) : 2=0.01%, 4=0.01%
  cpu          : usr=4.67%, sys=56.35%, ctx=1467919, majf=0, minf=1144
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued    : total=r=0/w=1467872/d=0, short=r=0/w=0/d=0, drop=r=0/w=0/d=0
     latency   : target=0, window=0, percentile=100.00%, depth=64

Run status group 0 (all jobs):
  WRITE: io=5733.9MB, aggrb=97856KB/s, minb=97856KB/s, maxb=97856KB/s, mint=60001msec, maxt=60001msec

Disk stats (read/write):
    md0: ios=0/1553786, merge=0/0, ticks=0/0, in_queue=0, util=0.00%, aggrios=0/370860, aggrmerge=0/17733, aggrticks=0/6539, aggrin_queue=0, aggrutil=8.41%
  nvme6n1: ios=0/369576, merge=0/17648, ticks=0/6439, in_queue=0, util=7.62%
  nvme5n1: ios=0/370422, merge=0/17611, ticks=0/6600, in_queue=0, util=7.72%
  nvme4n1: ios=0/371559, merge=0/18092, ticks=0/6511, in_queue=0, util=8.41%
  nvme7n1: ios=0/371886, merge=0/17584, ticks=0/6606, in_queue=0, util=8.17%
```

### raid6测试

raid6开buffer性能比raid0还要好10-20%，实际是将刷盘延迟异步在做，如果用-buffer=0 raid6的性能只有raid0的一半

![image-20220105173206915](/images/951413iMgBlog/image-20220105173206915.png)

```
[root@hygon33 17:19 /md6]
#echo 3 > /proc/sys/vm/drop_caches ; rm -f ./fio.test; fio -ioengine=libaio -bs=4k -direct=1 -buffered=1 -thread -rw=randwrite -rwmixread=70 -size=16G -filename=./fio.test -name="EBS 4K randwrite test" -iodepth=64 -runtime=60
EBS 4K randwrite test: (g=0): rw=randwrite, bs=4K-4K/4K-4K/4K-4K, ioengine=libaio, iodepth=64
fio-2.2.8
Starting 1 thread
EBS 4K randwrite test: Laying out IO file(s) (1 file(s) / 16384MB)
Jobs: 1 (f=1): [w(1)] [100.0% done] [0KB/424.9MB/0KB /s] [0/109K/0 iops] [eta 00m:00s]
EBS 4K randwrite test: (groupid=0, jobs=1): err= 0: pid=117679: Wed Jan  5 17:21:13 2022
  write: io=16384MB, bw=432135KB/s, iops=108033, runt= 38824msec
    slat (usec): min=4, max=7289, avg= 6.06, stdev= 5.28
    clat (usec): min=3, max=7973, avg=584.23, stdev=45.35
     lat (usec): min=10, max=7986, avg=590.77, stdev=45.75
    clat percentiles (usec):
     |  1.00th=[  548],  5.00th=[  556], 10.00th=[  564], 20.00th=[  572],
     | 30.00th=[  580], 40.00th=[  580], 50.00th=[  580], 60.00th=[  588],
     | 70.00th=[  588], 80.00th=[  596], 90.00th=[  604], 95.00th=[  612],
     | 99.00th=[  636], 99.50th=[  660], 99.90th=[  796], 99.95th=[  820],
     | 99.99th=[  916]
    bw (KB  /s): min=423896, max=455400, per=99.97%, avg=432015.17, stdev=6404.92
    lat (usec) : 4=0.01%, 20=0.01%, 50=0.01%, 100=0.01%, 250=0.01%
    lat (usec) : 500=0.01%, 750=99.78%, 1000=0.21%
    lat (msec) : 2=0.01%, 4=0.01%, 10=0.01%
  cpu          : usr=21.20%, sys=78.56%, ctx=57, majf=0, minf=1769
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=0.1%, >=64=100.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.1%, >=64=0.0%
     issued    : total=r=0/w=4194304/d=0, short=r=0/w=0/d=0, drop=r=0/w=0/d=0
     latency   : target=0, window=0, percentile=100.00%, depth=64

Run status group 0 (all jobs):
  WRITE: io=16384MB, aggrb=432135KB/s, minb=432135KB/s, maxb=432135KB/s, mint=38824msec, maxt=38824msec

Disk stats (read/write):
    md6: ios=0/162790, merge=0/0, ticks=0/0, in_queue=0, util=0.00%, aggrios=83058/153522, aggrmerge=1516568/962072, aggrticks=29792/16802, aggrin_queue=2425, aggrutil=44.71%
  nvme0n1: ios=83410/144109, merge=1517412/995022, ticks=31218/16718, in_queue=2416, util=43.62%
  nvme3n1: ios=83301/162626, merge=1517086/927594, ticks=24190/17067, in_queue=2364, util=34.14%
  nvme2n1: ios=81594/144341, merge=1514750/992273, ticks=32204/16646, in_queue=2504, util=44.71%
  nvme1n1: ios=83929/163013, merge=1517025/933399, ticks=31559/16780, in_queue=2416, util=42.83%

[root@hygon33 17:21 /md6]
#echo 3 > /proc/sys/vm/drop_caches ; rm -f ./fio.test; fio -ioengine=libaio -bs=4k -direct=1 -buffered=0 -thread -rw=randwrite -rwmixread=70 -size=16G -filename=./fio.test -name="EBS 4K randwrite test" -iodepth=64 -runtime=60
EBS 4K randwrite test: (g=0): rw=randwrite, bs=4K-4K/4K-4K/4K-4K, ioengine=libaio, iodepth=64
fio-2.2.8
Starting 1 thread
EBS 4K randwrite test: Laying out IO file(s) (1 file(s) / 16384MB)
Jobs: 1 (f=0): [w(1)] [22.9% done] [0KB/51034KB/0KB /s] [0/12.8K/0 iops] [eta 03m:25s]
EBS 4K randwrite test: (groupid=0, jobs=1): err= 0: pid=164871: Wed Jan  5 17:25:17 2022
  write: io=3743.6MB, bw=63887KB/s, iops=15971, runt= 60003msec
    slat (usec): min=11, max=123152, avg=29.39, stdev=283.93
    clat (usec): min=261, max=196197, avg=3975.22, stdev=3526.29
     lat (usec): min=300, max=196223, avg=4005.13, stdev=3554.65
    clat percentiles (msec):
     |  1.00th=[    3],  5.00th=[    3], 10.00th=[    4], 20.00th=[    4],
     | 30.00th=[    4], 40.00th=[    4], 50.00th=[    4], 60.00th=[    4],
     | 70.00th=[    5], 80.00th=[    5], 90.00th=[    5], 95.00th=[    6],
     | 99.00th=[    7], 99.50th=[    7], 99.90th=[   39], 99.95th=[   88],
     | 99.99th=[  167]
    bw (KB  /s): min=41520, max=78176, per=100.00%, avg=64093.14, stdev=6896.65
    lat (usec) : 500=0.02%, 750=0.03%, 1000=0.02%
    lat (msec) : 2=0.73%, 4=64.28%, 10=34.72%, 20=0.06%, 50=0.08%
    lat (msec) : 100=0.02%, 250=0.05%
  cpu          : usr=4.11%, sys=48.69%, ctx=357564, majf=0, minf=2653
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=0.1%, >=64=100.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.1%, >=64=0.0%
     issued    : total=r=0/w=958349/d=0, short=r=0/w=0/d=0, drop=r=0/w=0/d=0
     latency   : target=0, window=0, percentile=100.00%, depth=64

Run status group 0 (all jobs):
  WRITE: io=3743.6MB, aggrb=63886KB/s, minb=63886KB/s, maxb=63886KB/s, mint=60003msec, maxt=60003msec

Disk stats (read/write):
    md6: ios=0/1022450, merge=0/0, ticks=0/0, in_queue=0, util=0.00%, aggrios=262364/764703, aggrmerge=430291/192464, aggrticks=38687/55432, aggrin_queue=317, aggrutil=42.63%
  nvme0n1: ios=262282/759874, merge=430112/209613, ticks=43304/55197, in_queue=324, util=42.63%
  nvme3n1: ios=260535/771153, merge=430415/176326, ticks=25263/55664, in_queue=280, util=26.11%
  nvme2n1: ios=263663/758974, merge=430349/208189, ticks=42754/55761, in_queue=280, util=42.14%
  nvme1n1: ios=262976/768813, merge=430289/175731, ticks=43430/55109, in_queue=384, util=42.00%
```

测试完成很久后ssd还维持高水位的读写

```
avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           0.28    0.00    1.15    0.05    0.00   98.51

Device            r/s     rkB/s   rrqm/s  %rrqm r_await rareq-sz     w/s     wkB/s   wrqm/s  %wrqm w_await wareq-sz     d/s     dkB/s   drqm/s  %drqm d_await dareq-sz  aqu-sz  %util
dm-0             5.00     56.00     0.00   0.00    0.53    11.20   39.00    292.33     0.00   0.00    0.00     7.50    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.27
md6              0.00      0.00     0.00   0.00    0.00     0.00   14.00   1794.67     0.00   0.00    0.00   128.19    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.00
nvme0n1       1164.67 144488.00 34935.33  96.77    0.74   124.06 3203.67  53877.83 10267.00  76.22    0.16    16.82    0.00      0.00     0.00   0.00    0.00     0.00    0.32  32.13
nvme1n1       1172.33 144402.67 34925.00  96.75    0.74   123.18 3888.67  46635.17  7771.33  66.65    0.13    11.99    0.00      0.00     0.00   0.00    0.00     0.00    0.33  29.60
nvme2n1       1166.67 144372.00 34914.00  96.77    0.74   123.75 3263.00  53699.17 10162.67  75.70    0.14    16.46    0.00      0.00     0.00   0.00    0.00     0.00    0.33  27.87
nvme3n1       1157.67 144414.67 34934.33  96.79    0.64   124.75 3894.33  47073.83  7875.00  66.91    0.13    12.09    0.00      0.00     0.00   0.00    0.00     0.00    0.31  20.80
sda              5.00     56.00     0.00   0.00    0.13    11.20   39.00    204.17     0.00   0.00    0.12     5.24    0.00      0.00     0.00   0.00    0.00     0.00    0.00   0.27
```



## fio 结果解读

slat，异步场景下才有

> 其中slat指的是发起IO的时间，在异步IO模式下，发起IO以后，IO会异步完成。例如调用一个异步的write，虽然write返回成功了，但是IO还未完成，slat约等于发起write的耗时；
>
> slat (usec): min=4, max=6154, avg=48.82, stdev=56.38： The first latency metric you'll see is the 'slat' or submission latency. It is pretty much what it sounds like, meaning "how long did it take to submit this IO to the kernel for processing?"

clat

> clat指的是完成时间，从发起IO后到完成IO的时间，在同步IO模式下，clat是指整个写动作完成时间

lat

> lat是总延迟时间，指的是IO单元创建到完成的总时间，通常这项数据关注较多。同步场景几乎等于clat，异步场景等于clat+slat
> 这项数据需要关注的是max，看看有没有极端的高延迟IO；另外还需要关注stdev，这项数据越大说明，IO响应时间波动越大，反之越小，波动越小

clat percentiles (usec)：处于某个百分位的io操作时延

cpu          : usr=9.11%, sys=57.07%, ctx=762410, majf=0, minf=1769  //用户和系统的CPU占用时间百分比，线程切换次数，major以及minor页面错误的数量。



direct和buffered参数是冲突的，用一个就行，应该是direct=0性能更好，实际不是这样，这里还需要找资料求证下

> - `direct``=bool`
>
>   If value is true, use non-buffered I/O. This is usually O_DIRECT. Note that OpenBSD and ZFS on Solaris don’t support direct I/O. On Windows the synchronous ioengines don’t support direct I/O. Default: false.
>
> - `buffered``=bool`
>
>   If value is true, use buffered I/O. This is the opposite of the [`direct`](https://fio.readthedocs.io/en/latest/fio_man.html#cmdoption-arg-direct) option. Defaults to true.

## [iostat 结果解读](linuxtools-rst.readthedocs.io/zh_CN/latest/tool/iostat.html)

Dm-0就是lvm

```
avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           0.32    0.00    3.34    0.13    0.00   96.21

Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
sda               0.00    11.40   66.00    7.20  1227.20    74.40    35.56     0.03    0.43    0.47    0.08   0.12   0.88
nvme0n1           0.00  8612.00    0.00 51749.60     0.00 241463.20     9.33     4.51    0.09    0.00    0.09   0.02  78.56
dm-0              0.00     0.00    0.00 60361.80     0.00 241463.20     8.00   152.52    2.53    0.00    2.53   0.01  78.26

avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           0.36    0.00    3.46    0.17    0.00   96.00

Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
sda               0.00     8.80    9.20    5.20  1047.20    67.20   154.78     0.01    0.36    0.46    0.19   0.33   0.48
nvme0n1           0.00 11354.20    0.00 50876.80     0.00 248944.00     9.79     5.25    0.10    0.00    0.10   0.02  80.06
dm-0              0.00     0.00    0.00 62231.00     0.00 248944.80     8.00   199.49    3.21    0.00    3.21   0.01  78.86
```

avgqu_sz，是iostat的一项比较重要的数据。如果队列过长，则表示有大量IO在处理或等待，但是这还不足以说明后端的存储系统达到了处理极限。例如后端存储的并发能力是4096，客户端并发发送了256个IO下去，那么队列长度就是256。即使长时间队列长度是256，也不能说明什么，仅仅表明队列长度是256，有256个IO在处理或者排队。

那么怎么判断IO是在调度队列排队等待，还是在设备上处理呢？iostat有两项数据可以给出一个大致的判断。svctime，这项数据的指的是IO在设备处理中耗费的时间。另外一项数据await，指的是IO从排队到完成的时间，包括了svctime和排队等待的时间。那么通过对比这两项数据，如果两项数据差不多，则说明IO基本没有排队等待，耗费的时间都是设备处理。如果await远大于svctime，则说明有大量的IO在排队，并没有发送给设备处理。

## 不同厂家SSD性能对比

国产SSD指的是AliFlash

![img](/images/951413iMgBlog/1638359029693-73b42c13-2649-4f20-9112-a7c4c5dd5432.png)

![img](/images/951413iMgBlog/1638358969626-507f34aa-201b-4fd3-91de-66c88c6ce04a.png)

## rq_affinity

参考[aliyun测试文档](https://help.aliyun.com/knowledge_detail/65077.html#title-x10-2c0-yll) , rq_affinity增加2的commit： git show 5757a6d76c

```
function RunFio
{
 numjobs=$1   # 实例中的测试线程数，例如示例中的10
 iodepth=$2   # 同时发出I/O数的上限，例如示例中的64
 bs=$3        # 单次I/O的块文件大小，例如示例中的4k
 rw=$4        # 测试时的读写策略，例如示例中的randwrite
 filename=$5  # 指定测试文件的名称，例如示例中的/dev/your_device
 nr_cpus=`cat /proc/cpuinfo |grep "processor" |wc -l`
 if [ $nr_cpus -lt $numjobs ];then
     echo “Numjobs is more than cpu cores, exit!”
     exit -1
 fi
 let nu=$numjobs+1
 cpulist=""
 for ((i=1;i<10;i++))
 do
     list=`cat /sys/block/your_device/mq/*/cpu_list | awk '{if(i<=NF) print $i;}' i="$i" | tr -d ',' | tr '\n' ','`
     if [ -z $list ];then
         break
     fi
     cpulist=${cpulist}${list}
 done
 spincpu=`echo $cpulist | cut -d ',' -f 2-${nu}`
 echo $spincpu
 fio --ioengine=libaio --runtime=30s --numjobs=${numjobs} --iodepth=${iodepth} --bs=${bs} --rw=${rw} --filename=${filename} --time_based=1 --direct=1 --name=test --group_reporting --cpus_allowed=$spincpu --cpus_allowed_policy=split
}
echo 2 > /sys/block/your_device/queue/rq_affinity
sleep 5
RunFio 10 64 4k randwrite filename
```

对NVME SSD进行测试，左边rq_affinity是2，右边rq_affinity为1，在这个测试参数下rq_affinity为1的性能要好(后许多次测试两者性能差不多)

![image-20210607113709945](/images/951413iMgBlog/image-20210607113709945.png)

## 磁盘挂载参数

内核一般配置的脏页回写超时时间是30s，理论上page cache能buffer住所有的脏页，但是ext4文件系统的默认挂载参数开始支持日志（journal），文件的inode被修改后，需要刷到journal里，这样系统crash了文件系统能恢复过来，内核配置默认5s刷一次journal，ext4还有一个配置项叫挂载方式，有ordered和writeback两个选项，区别是ordered在把inode刷到journal里之前，会把inode的所有脏页先回写到磁盘里，如果不希望inode这么快写回到磁盘则可以用writeback参数。当SSD开始写盘的时候会严重影响SSD读能力

```
# 编辑/etc/fstab，挂载参数设置为defaults,noatime,nodiratime,delalloc,nobarrier,data=writeback
/dev/lvm1 /data    ext4    defaults,noatime,nodiratime,delalloc,nobarrier,data=writeback 0 0
```

`noatime` 读取文件时，将禁用对元数据的更新。它还启用了 nodiratime 行为，该行为会在读取目录时禁用对元数据的更新

### 优化case

10个GB的原始文件里面都是随机数，如何快速建索引支持分页查询top(k,n)场景，机器配置是24核，JVM堆内存限制2.5G，磁盘读写为490-500MB/s左右。

最后成绩在22.9s，去掉评测方法引入的1.1s，5次查询含建索引总时间21.8s，因为读10GB文件就需要21.5s时间。当向SSD开始写索引文件后SSD读取性能下降厉害，实际期望的是写出索引到SSD的时候会被PageCache，没触发刷脏。但是这里的刷盘就是ext4挂载参数 ordered 导致了刷盘。

整个方案是：原始文件切割成小分片，喂给24个worker；每个worker读数据，处理数据，定期批量写索引出去；最后查询会去读每个worker生成的所有索引文件，通过跳表快速seek。

![img](/images/951413iMgBlog/586fef765e3f08f6183907f311a76259.png)

## LVM性能对比

磁盘信息

```
#lsblk
NAME         MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
sda            8:0    0 223.6G  0 disk
├─sda1         8:1    0     3M  0 part
├─sda2         8:2    0     1G  0 part /boot
├─sda3         8:3    0    96G  0 part /
├─sda4         8:4    0    10G  0 part /tmp
└─sda5         8:5    0 116.6G  0 part /home
nvme0n1      259:4    0   2.7T  0 disk
└─nvme0n1p1  259:5    0   2.7T  0 part
  └─vg1-drds 252:0    0   5.4T  0 lvm  /drds
nvme1n1      259:0    0   2.7T  0 disk
└─nvme1n1p1  259:2    0   2.7T  0 part /u02
nvme2n1      259:1    0   2.7T  0 disk
└─nvme2n1p1  259:3    0   2.7T  0 part
  └─vg1-drds 252:0    0   5.4T  0 lvm  /drds
```

单块nvme SSD盘跑mysql server，运行sysbench导入测试数据

```
#iostat -x nvme1n1 1
Linux 3.10.0-327.ali2017.alios7.x86_64 (k28a11352.eu95sqa) 	05/13/2021 	_x86_64_	(64 CPU)

avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           0.32    0.00    0.17    0.07    0.00   99.44

Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
nvme1n1           0.00    47.19    0.19  445.15     2.03 43110.89   193.62     0.31    0.70    0.03    0.70   0.06   2.85

avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           1.16    0.00    0.36    0.17    0.00   98.31

Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
nvme1n1           0.00   122.00    0.00 3290.00     0.00 271052.00   164.77     1.65    0.50    0.00    0.50   0.05  17.00

#iostat 1
Linux 3.10.0-327.ali2017.alios7.x86_64 (k28a11352.eu95sqa) 	05/13/2021 	_x86_64_	(64 CPU)

avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           0.14    0.00    0.13    0.05    0.00   99.67

Device:            tps    kB_read/s    kB_wrtn/s    kB_read    kB_wrtn
sda              49.21       554.51      2315.83    1416900    5917488
nvme1n1           5.65         2.34       844.73       5989    2158468
nvme2n1           0.06         1.13         0.00       2896          0
nvme0n1           0.06         1.13         0.00       2900          0
dm-0              0.02         0.41         0.00       1036          0

avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           1.39    0.00    0.23    0.08    0.00   98.30

Device:            tps    kB_read/s    kB_wrtn/s    kB_read    kB_wrtn
sda               8.00         0.00        60.00          0         60
nvme1n1         868.00         0.00    132100.00          0     132100
nvme2n1           0.00         0.00         0.00          0          0
nvme0n1           0.00         0.00         0.00          0          0
dm-0              0.00         0.00         0.00          0          0

avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           1.44    0.00    0.14    0.09    0.00   98.33

Device:            tps    kB_read/s    kB_wrtn/s    kB_read    kB_wrtn
sda               0.00         0.00         0.00          0          0
nvme1n1         766.00         0.00    132780.00          0     132780
nvme2n1           0.00         0.00         0.00          0          0
nvme0n1           0.00         0.00         0.00          0          0
dm-0              0.00         0.00         0.00          0          0

avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           1.41    0.00    0.16    0.09    0.00   98.34

Device:            tps    kB_read/s    kB_wrtn/s    kB_read    kB_wrtn
sda             105.00         0.00       532.00          0        532
nvme1n1         760.00         0.00    122236.00          0     122236
nvme2n1           0.00         0.00         0.00          0          0
nvme0n1           0.00         0.00         0.00          0          0
dm-0              0.00         0.00         0.00          0          0
```

如果同样写lvm，由两块nvme组成

```
Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
nvme2n1           0.00     0.00    0.00    0.00     0.00     0.00     0.00     0.00    0.00    0.00    0.00   0.00   0.00
nvme0n1           0.00   137.00    0.00 5730.00     0.00 421112.00   146.98     2.95    0.52    0.00    0.52   0.05  27.30

avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           1.17    0.00    0.34    0.19    0.00   98.30

Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
nvme2n1           0.00     0.00    0.00    0.00     0.00     0.00     0.00     0.00    0.00    0.00    0.00   0.00   0.00
nvme0n1           0.00   109.00    0.00 2533.00     0.00 271236.00   214.16     1.08    0.43    0.00    0.43   0.06  15.90

avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           1.38    0.00    0.42    0.20    0.00   98.00

Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
nvme2n1           0.00     0.00    0.00    0.00     0.00     0.00     0.00     0.00    0.00    0.00    0.00   0.00   0.00
nvme0n1           0.00   118.00    0.00 3336.00     0.00 320708.00   192.27     1.50    0.45    0.00    0.45   0.06  20.00

[root@k28a11352.eu95sqa /var/lib]
#iostat  1
Linux 3.10.0-327.ali2017.alios7.x86_64 (k28a11352.eu95sqa) 	05/13/2021 	_x86_64_	(64 CPU)

avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           0.40    0.00    0.20    0.07    0.00   99.33

Device:            tps    kB_read/s    kB_wrtn/s    kB_read    kB_wrtn
sda              38.96       334.64      1449.68    1419236    6148304
nvme1n1         324.95         1.43     31201.30       6069  132329072
nvme2n1           0.07         0.90         0.00       3808          0
nvme0n1         256.24         1.60     22918.46       6801   97200388
dm-0            266.98         1.38     22918.46       5849   97200388

avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           1.20    0.00    0.42    0.25    0.00   98.12

Device:            tps    kB_read/s    kB_wrtn/s    kB_read    kB_wrtn
sda               0.00         0.00         0.00          0          0
nvme1n1           0.00         0.00         0.00          0          0
nvme2n1           0.00         0.00         0.00          0          0
nvme0n1        4460.00         0.00    332288.00          0     332288
dm-0           4608.00         0.00    332288.00          0     332288

avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           1.35    0.00    0.38    0.22    0.00   98.06

Device:            tps    kB_read/s    kB_wrtn/s    kB_read    kB_wrtn
sda              48.00         0.00       200.00          0        200
nvme1n1           0.00         0.00         0.00          0          0
nvme2n1           0.00         0.00         0.00          0          0
nvme0n1        4187.00         0.00    332368.00          0     332368
dm-0           4348.00         0.00    332368.00          0     332368
```



## 数据总结

- 性能排序 NVMe SSD > SATA SSD > SAN > ESSD > HDD
- 本地ssd性能最好、sas机械盘(RAID10)性能最差
- san存储走特定的光纤网络，不是走tcp的san（至少从网卡看不到san的流量），性能居中
- 从rt来看 ssd:san:sas 大概是 1:3:15
- san比本地sas机械盘性能要好，这也许取决于san的网络传输性能和san存储中的设备（比如用的ssd而不是机械盘）
- NVMe SSD比SATA SSD快很多，latency更稳定
- 阿里云的云盘ESSD比本地SAS RAID10阵列性能还好
- 软RAID、LVM等阵列都会导致性能损耗，即使多盘一起读写也不如单盘性能
- 不同测试场景(4K/8K/ 读写、随机与否)会导致不同品牌性能数据差异较大

## 参考资料

http://cizixs.com/2017/01/03/how-slow-is-disk-and-network

https://tobert.github.io/post/2014-04-17-fio-output-explained.html 

https://zhuanlan.zhihu.com/p/40497397

[块存储NVMe云盘原型实践](https://www.atatech.org/articles/167736?spm=ata.home.0.0.11fd75362qwsg7&flag_data_from=home_algorithm_article)

[机械硬盘随机IO慢的超乎你的想象](https://mp.weixin.qq.com/s?__biz=MjM5Njg5NDgwNA==&mid=2247483999&idx=1&sn=238d3d1a8cf24443db0da4aa00c9fb7e&chksm=a6e3036491948a72704e0b114790483f227b7ce82f5eece5dd870ef88a8391a03eca27e8ff61&scene=178&cur_album_id=1371808335259090944#rd)

[搭载固态硬盘的服务器究竟比搭机械硬盘快多少？](https://mp.weixin.qq.com/s?__biz=MjM5Njg5NDgwNA==&mid=2247484023&idx=1&sn=1946b4c286ed72da023b402cc30908b6&chksm=a6e3034c91948a5aa3b0e6beb31c1d3804de9a11c668400d598c2a6b12462e179cf9f1dc33e2&scene=178&cur_album_id=1371808335259090944#rd)

[SSD基本工作原理](http://www.360doc.com/content/15/0318/15/16824943_456186965.shtml)

[SSD原理解读](https://zhuanlan.zhihu.com/p/347599423)

