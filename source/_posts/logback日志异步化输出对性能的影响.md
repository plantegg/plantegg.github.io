---
title: logback 日志异步化输出对性能的影响
date: 2019-09-12 12:30:03
categories: 
	- performance
tags:
    - logback
    - AsyncAppender
    - neverBlock
    - immediateFlush
    - lock
    - log4j2
    - Java
---


# logback 日志异步化输出对性能的影响

## 场景

Java在每次请求结束后都会输出日志记录每次请求的相关信息，一个QPS对应一次日志的输出。

异步化基本百利而无一害，特定的场景、机器下可以数倍提升效率

## 结论

- 异步化对性能的影响取决于日志的多少和机器CPU的核数
- logback日志异步化主要是写日志逻辑变成了单线程，没有锁
- 异步化后性能有10-15%的提升(Profiling看到日志相关的CPU占比从13%降到6.5%)
- 异步输出条件下，日志多少对性能的影响有，但是不明显（15%以内）
- 如果是同步输出日志，开启延迟flush log（<immediateFlush>false</immediateFlush> //flush policy）能有5%的性能提升
- 异步化后再开启延迟flush log对性能提升不明显(Profiling看到log flush的CPU从1.2%降到0.4%)
- slf4j只是个接口框架，JUL/log4j2和logback是具体实现，logback是log4j的升级版
- 如果一秒钟日志输出达到6M（主要取决于条数），那么异步化能提升一倍的性能（日志太多的时候同步下CPU跑不满）
- 同步日志输出场景下瓶颈主要在同步锁而不是磁盘写日志（顺序写磁盘）
- 从Profiler堆栈来看异步后锁和日志输出部分占比明显降低
- CPU核数越多意味着并发越多，那么同步异步和immediateFlush的影响越明显
- 异步化输出日志后对avg rt 和 rt 95%线下降影响非常明显，也更稳定
- immediateFlush 对同步影响比较明显（一倍），主要是因为每次刷盘慢导致别的线程等锁时间长，在异步场景下基本不明显
- immediateFlush为false有丢日志的风险，异步后没有必要再设immediateFlush为false
- 延迟Flush的cache取决于JDK的BufferedOutputStream缓冲大小，默认8K，不可更改
- 异步后日志输出的瓶颈在于单核能力，Intel(R) Xeon(R) Platinum 8163 CPU @ 2.50GHz 输出能力大概是每秒20万条日志

## 测试数据

### 4核的机器下性能提升没这么明显，因为锁争抢没这么激烈

![image.png](/images/oss/d38fecd4932266209c6a1ca0265f98aa.png)

4.9内核下, 异步对rt影响明显, 似乎是4.9对锁的处理更好：

![image.png](/images/oss/1566290324749-86d349a5-b647-439c-ac19-f7b772f9e575.png)

2.6.32下异步对rt影响不是很大

![image.png](/images/oss/1566291069825-24063e55-20e8-4689-a0af-b8a7083ca806.png)

![image.png](/images/oss/1566291122368-e60ca95a-ae36-47f8-957c-747f35834233.png)

加大120线程并发，可以看到tps提升明显但是rt仍然不明显

![image.png](/images/oss/1566292019098-60f15294-a001-452e-8ecb-626aada11837.png)

如果将 sql.log 改为error级别，tps上升到30000，rt比info也有将近10%的提升，这个rt的提升是因为tps提升导致的。（都是异步输出的场景下）

![image.png](/images/oss/1566294041222-153fbe62-e503-4d35-b99a-bd2517332592.png)

### 同步情况下的profiler

recordSQL: 12.9%
logback.doAppend: 10%

![image.png](/images/oss/4e0595c173522e37edf87b568eab6e7f.png)

### 异步情况下的profiler:

recordSQL:  3.7%
![image.png](/images/oss/a88a3595d386be2ffeb0652ba2fdeea1.png)

logback.doAppend: 2.63%

![image.png](/images/oss/e3d0200c0edf97540d422252fb23a4c2.png)

### 在16个core的机器上锁争抢更明显

[99.8%的锁都是doApend](https://yuque.antfin-inc.com/preview/lark/0/2019/svg/33359/1568184395734-ff64a8ee-8b24-45ec-8fc3-024e14b8e7f0.svg) 

![image.png](/images/oss/15879d15dbe876b5ee3bed02dfa18894.png)

### 同步和异步以及immediateFlush的影响

16core的机器

![image.png](/images/oss/f0e39a66b63fe00877b6663f8857a739.png)

结论：同步输出的情况下immediateFlush 为false性能有一倍的提升（但是异常退出的情况下有丢日志风险）
异步输出是同步的4倍（这个差异依赖于cpu核数、业务逻辑的特点等），在异步的情况下immediateFlush无所谓，所以王者还是异步输出，同时异步输出对rt 95%线下降非常明显

### 一个业务逻辑稍微慢点的场景

异步输出日志点查场景tps11万+，同步输出日志后点查tps4万+，同时jstack堆栈也能看到333个BLOCKED堆栈：

```
#[ 210s] threads: 400, tps: 0.00, reads/s: 115845.43, writes/s: 0.00, response time: 7.57ms (95%)
#[ 220s] threads: 400, tps: 0.00, reads/s: 116453.12, writes/s: 0.00, response time: 7.28ms (95%)
#[ 230s] threads: 400, tps: 0.00, reads/s: 116400.31, writes/s: 0.00, response time: 7.33ms (95%)
#[ 240s] threads: 400, tps: 0.00, reads/s: 116025.35, writes/s: 0.00, response time: 7.48ms (95%)
#[ 250s] threads: 400, tps: 0.00, reads/s: 45260.97, writes/s: 0.00, response time: 29.57ms (95%)
#[ 260s] threads: 400, tps: 0.00, reads/s: 41598.41, writes/s: 0.00, response time: 29.07ms (95%)
#[ 270s] threads: 400, tps: 0.00, reads/s: 41939.98, writes/s: 0.00, response time: 28.96ms (95%)
#[ 280s] threads: 400, tps: 0.00, reads/s: 40875.48, writes/s: 0.00, response time: 29.16ms (95%)
#[ 290s] threads: 400, tps: 0.00, reads/s: 41053.73, writes/s: 0.00, response time: 29.07ms (95%)

--- 1687260767618 ns (100.00%), 91083 samples
 [ 0] ch.qos.logback.classic.sift.SiftingAppender
 [ 1] ch.qos.logback.core.AppenderBase.doAppend
 [ 2] ch.qos.logback.core.spi.AppenderAttachableImpl.appendLoopOnAppenders
 [ 3] ch.qos.logback.classic.Logger.appendLoopOnAppenders
 [ 4] ch.qos.logback.classic.Logger.callAppenders
 [ 5] ch.qos.logback.classic.Logger.buildLoggingEventAndAppend
 [ 6] ch.qos.logback.classic.Logger.filterAndLog_0_Or3Plus
 [ 7] ch.qos.logback.classic.Logger.info
 [ 8] com.taobao.tddl.common.utils.logger.slf4j.Slf4jLogger.info
 [ 9] com.taobao.tddl.common.utils.logger.support.FailsafeLogger.info
 [10] com.alibaba.cobar.server.util.LogUtils.recordSql
 [11] com.alibaba.cobar.server.ServerConnection.innerExecute
 [12] com.alibaba.cobar.server.ServerConnection.innerExecute
 [13] com.alibaba.cobar.server.ServerConnection$1.run
 [14] com.taobao.tddl.common.utils.thread.FlowControlThreadPool$RunnableAdapter.run
 [15] java.util.concurrent.Executors$RunnableAdapter.call
 [16] java.util.concurrent.FutureTask.run
 [17] java.util.concurrent.ThreadPoolExecutor.runWorker
 [18] java.util.concurrent.ThreadPoolExecutor$Worker.run
 [19] java.lang.Thread.run
  
"ServerExecutor-3-thread-480" #753 daemon prio=5 os_prio=0 tid=0x00007f8265842000 nid=0x26f1 waiting for monitor entry [0x00007f82270bf000]
  java.lang.Thread.State: BLOCKED (on object monitor)
	at ch.qos.logback.core.AppenderBase.doAppend(AppenderBase.java:64)
	- waiting to lock <0x00007f866dcec208> (a ch.qos.logback.classic.sift.SiftingAppender)
	at ch.qos.logback.core.spi.AppenderAttachableImpl.appendLoopOnAppenders(AppenderAttachableImpl.java:48)
	at ch.qos.logback.classic.Logger.appendLoopOnAppenders(Logger.java:282)
	at ch.qos.logback.classic.Logger.callAppenders(Logger.java:269)
	at ch.qos.logback.classic.Logger.buildLoggingEventAndAppend(Logger.java:470)
	at ch.qos.logback.classic.Logger.filterAndLog_0_Or3Plus(Logger.java:424)
	at ch.qos.logback.classic.Logger.info(Logger.java:628)
	at com.taobao.tddl.common.utils.logger.slf4j.Slf4jLogger.info(Slf4jLogger.java:42)
	at com.taobao.tddl.common.utils.logger.support.FailsafeLogger.info(FailsafeLogger.java:102)
	at com.alibaba.cobar.server.util.LogUtils.recordSql(LogUtils.java:115)
	at com.alibaba.cobar.server.ServerConnection.innerExecute(ServerConnection.java:874)
	- locked <0x00007f87382cb108> (a com.alibaba.cobar.server.ServerConnection)
	at com.alibaba.cobar.server.ServerConnection.innerExecute(ServerConnection.java:569)
	- locked <0x00007f87382cb108> (a com.alibaba.cobar.server.ServerConnection)
	at com.alibaba.cobar.server.ServerConnection$1.run(ServerConnection.java:402)
	at com.taobao.tddl.common.utils.thread.FlowControlThreadPool$RunnableAdapter.run(FlowControlThreadPool.java:480)
	at java.util.concurrent.Executors$RunnableAdapter.call(Executors.java:511)
	at java.util.concurrent.FutureTask.run(FutureTask.java:266)
	at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1152)
	at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:627)
	at java.lang.Thread.run(Thread.java:861)

  - waiting to lock <0x00007f866dcec208> (a ch.qos.logback.classic.sift.SiftingAppender)
	- waiting to lock <0x00007f866dcec208> (a ch.qos.logback.classic.sift.SiftingAppender)
	- waiting to lock <0x00007f866dcec208> (a ch.qos.logback.classic.sift.SiftingAppender)
	- waiting to lock <0x00007f866dcec208> (a ch.qos.logback.classic.sift.SiftingAppender)
	- waiting to lock <0x00007f866dcec208> (a ch.qos.logback.classic.sift.SiftingAppender)
	- waiting to lock <0x00007f866dcec208> (a ch.qos.logback.classic.sift.SiftingAppender)
	- waiting to lock <0x00007f866dcec208> (a ch.qos.logback.classic.sift.SiftingAppender)
	- locked <0x00007f866dcec208> (a ch.qos.logback.classic.sift.SiftingAppender)
	- waiting to lock <0x00007f866dcec208> (a ch.qos.logback.classic.sift.SiftingAppender)
	- waiting to lock <0x00007f866dcec208> (a ch.qos.logback.classic.sift.SiftingAppender)
	- waiting to lock <0x00007f866dcec208> (a ch.qos.logback.classic.sift.SiftingAppender)
	- waiting to lock <0x00007f866dcec208> (a ch.qos.logback.classic.sift.SiftingAppender)
	- waiting to lock <0x00007f866dcec208> (a ch.qos.logback.classic.sift.SiftingAppender)
	- waiting to lock <0x00007f866dcec208> (a ch.qos.logback.classic.sift.SiftingAppender)
	- waiting to lock <0x00007f866dcec208> (a ch.qos.logback.classic.sift.SiftingAppender)
	- waiting to lock <0x00007f866dcec208> (a ch.qos.logback.classic.sift.SiftingAppender)
```

## immediateFlush true/false 以及同步异步对tps的影响

![image.png](/images/oss/a4753f40c89640c4d86a54902b9ed691.png)

结论：同步输出的情况下immediateFlush 为false性能有一倍的提升（但是异常退出的情况下有丢日志风险）异步输出是同步的4倍（这个差异依赖于cpu核数、业务逻辑的特点等），在异步的情况下immediateFlush无所谓，所以王者还是异步输出，同时异步输出对rt 95%线下降非常明显

## 异步配置

	    <appender name="asyncROOT" class="ch.qos.logback.classic.AsyncAppender">
	        <queueSize>1000</queueSize>
	        <maxFlushTime>3000</maxFlushTime>
					<discardingThreshold>0</discardingThreshold>
	        <neverBlock>true</neverBlock>
	        <appender-ref ref="ROOT"/>
			</appender>

## JDK中BufferedOutputStream Buffer大小

	/** 
	 * Creates a new buffered output stream to write data to the 
	 * specified underlying output stream. 
	 * 
	 * @param   out   the underlying output stream. 
	 */  
	public BufferedOutputStream(OutputStream out) {  
	    this(out, 8192);  
	}  

尝试改大buffer基本没什么明显的影响

## 测试环境2个节点的DRDS-Server，每个节点4Core8G（机型sn1）

|                               | tps   | 100秒每个节点输出日志大小 |
| ----------------------------- | ----- | ------------------------- |
| 不输出日志                    | 35097 |                           |
| sql.log+同步                  | 28891 | 292M                      |
| sql.log+异步                  | 32164 | 292M                      |
| sql.log+com.taobao/trace+异步 | 28894 | 670M                      |
| sql.log+com.taobao/trace+同步 | 13248 |                           |

com.taobao/trace 指的是将com.taobao.*设为trace输出，以增加输出日志量。

### 是否开启immediateFlush（默认true）

|                     | tps   | 100秒每个节点输出日志大小 |
| ------------------- | ----- | ------------------------- |
| 同步+immediateFlush | 27610 | 282M                      |
| 同步                | 29554 | 303M                      |
| 异步+immediateFlush | 31100 | 245M                      |
| 异步                | 31150 | 260M                      |

（这个表格和前面的表格整体tps不一致，前一个表格是晚上测试，这个表格是上午测试的，不清楚是否环境受到了影响）

## 总结

关键结论见最前面，但是要结合自己场景输出日志的速度，日志输出越少影响越不明显，机器核数越多会越明显，总的原因就是logback的 AppenderBase的doAppend()函数需要同步

	public synchronized void doAppend(E eventObject)

## 案例

Logback 异步日志处理能力分析

### 环境信息

32C128G

### 单条日志较大 len=1137 

top

```
  PID USER      PR  NI    VIRT    RES    SHR S %CPU %MEM     TIME+ COMMAND
13200 admin     20   0  128.6g  78.6g  22864 R 85.1 63.5  15:13.50 AsyncAppende //异步写日志
13389 admin     20   0  128.6g  78.6g  22864 R 42.1 63.5   1:33.49 logback-5 --压缩

  PID USER      PR  NI    VIRT    RES    SHR S %CPU %MEM     TIME+ COMMAND
13200 admin     20   0  128.6g  78.5g  22864 R 85.1 63.5  15:54.71 AsyncAppender-W
13456 admin     20   0  128.6g  78.5g  22864 R 73.5 63.5   1:49.45 logback-6
```

日志内容

```
[len=1137] select 1 /*skkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkk*/

[ 408s] threads: 360, tps: 0.00, reads/s: 78817.18, writes/s: 0.00, response time: 15.55ms (95%)
[ 409s] threads: 360, tps: 0.00, reads/s: 85020.78, writes/s: 0.00, response time: 12.70ms (95%)
[ 410s] threads: 360, tps: 0.00, reads/s: 86073.08, writes/s: 0.00, response time: 12.83ms (95%)
[ 411s] threads: 360, tps: 0.00, reads/s: 84357.86, writes/s: 0.00, response time: 12.90ms (95%)
```

平均每分钟输出日志内容 13个512MB日志文件，每秒100MB的输出能力

### 每条日志len=150

```
[len=150] SELECT 1 /*skkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkk*/ 

[  10s] threads: 120, tps: 0.00, reads/s: 185004.17, writes/s: 0.00, response time: 1.77ms (95%)
[  11s] threads: 120, tps: 0.00, reads/s: 188139.08, writes/s: 0.00, response time: 1.73ms (95%)
[  12s] threads: 120, tps: 0.00, reads/s: 185597.99, writes/s: 0.00, response time: 1.74ms (95%)
[  13s] threads: 120, tps: 0.00, reads/s: 188732.07, writes/s: 0.00, response time: 1.74ms (95%)
[  14s] threads: 120, tps: 0.00, reads/s: 188982.57, writes/s: 0.00, response time: 1.74ms (95%)
```

减小日志

```
[len=46] SELECT 1 /*skkkkkkkkkkkkkkkkkkkkkkkkkkkkkkk*/ 

  PID USER      PR  NI    VIRT    RES    SHR S %CPU %MEM     TIME+ COMMAND
15646 admin     20   0  128.4g  78.1g  22976 R 82.8 63.2   4:45.75 AsyncAppender-W
15958 admin     20   0  128.4g  78.1g  22976 R 46.0 63.2   0:27.01 logback-5
15664 admin     20   0  128.4g  78.1g  22976 R 29.8 63.2   1:47.70 Processor2-W
15666 admin     20   0  128.4g  78.1g  22976 R 29.8 63.2   1:48.03 Processor3-W

  PID USER      PR  NI    VIRT    RES    SHR S %CPU %MEM     TIME+ COMMAND15646 admin     20   0  128.4g  78.1g  22976 R 82.8 63.2   4:45.75 AsyncAppender-W
15958 admin     20   0  128.4g  78.1g  22976 R 46.0 63.2   0:27.01 logback-515664 admin     20   0  128.4g  78.1g  22976 R 29.8 63.2   1:47.70 Processor2-W15666 admin     20   0  128.4g  78.1g  22976 R 29.8 63.2   1:48.03 Processor3-W
```

### select 1日志

```
[len=8] SELECT 1 

[  10s] threads: 120, tps: 0.00, reads/s: 185004.17, writes/s: 0.00, response time: 1.77ms (95%)
[  11s] threads: 120, tps: 0.00, reads/s: 188139.08, writes/s: 0.00, response time: 1.73ms (95%)
[  12s] threads: 120, tps: 0.00, reads/s: 185597.99, writes/s: 0.00, response time: 1.74ms (95%)
[  13s] threads: 120, tps: 0.00, reads/s: 188732.07, writes/s: 0.00, response time: 1.74ms (95%)
[  14s] threads: 120, tps: 0.00, reads/s: 188982.57, writes/s: 0.00, response time: 1.74ms (95%)

  PID USER      PR  NI    VIRT    RES    SHR S %CPU %MEM     TIME+ COMMAND
15646 admin     20   0  128.3g  78.1g  22976 R 81.5 63.2   3:37.77 AsyncAppender-W
16849 admin     20   0  128.3g  78.1g  22976 R 37.7 63.2   0:26.85 logback-8
16066 admin     20   0  128.3g  78.1g  22976 S 33.8 63.2   0:33.07 logback-7
```

### 点查日志

```
[len=43] SELECT *, pad FROM sbtest1 WHERE id=5000089

[  31s] threads: 360, tps: 0.00, reads/s: 120084.93, writes/s: 0.00, response time: 3.20ms (95%)
[  32s] threads: 360, tps: 0.00, reads/s: 119897.70, writes/s: 0.00, response time: 3.21ms (95%)
[  33s] threads: 360, tps: 0.00, reads/s: 120158.21, writes/s: 0.00, response time: 3.20ms (95%)
[  34s] threads: 360, tps: 0.00, reads/s: 119777.94, writes/s: 0.00, response time: 3.22ms (95%)
[  35s] threads: 360, tps: 0.00, reads/s: 120047.95, writes/s: 0.00, response time: 3.20ms (95%)
[  36s] threads: 360, tps: 0.00, reads/s: 118585.32, writes/s: 0.00, response time: 3.23ms (95%)
[  37s] threads: 360, tps: 0.00, reads/s: 119351.12, writes/s: 0.00, response time: 3.20ms (95%)

  PID USER      PR  NI    VIRT    RES    SHR S %CPU %MEM     TIME+ COMMAND
15644 admin     20   0  128.5g  78.3g  22976 R 99.9 63.3   1:12.14 logback-1
15646 admin     20   0  128.5g  78.3g  22976 R 65.6 63.3   8:46.11 AsyncAppender-W
15659 admin     20   0  128.5g  78.3g  22976 R 25.5 63.3   2:53.82 Processor0-R
15662 admin     20   0  128.5g  78.3g  22976 S 25.5 63.3   3:06.63 Processor1-W
```

后端RDS快打满了

### 案例总结

len表示日志长度

|      | len=43 ，点查   | len=8 select 1           | [len=150] SELECT 1 | [len=1137] select 1 |
| ---- | --------------- | ------------------------ | ------------------ | ------------------- |
| QPS  | 12万（rds瓶颈） | 18.6万(写日志单线程瓶颈) | 18.5万             | 8.5万(磁盘瓶颈)     |

因为**调度问题** 异步写日志进程很难跑满CPU, 最多跑到80%左右

单核按条输出能力在 18万条每秒左右（Intel(R) Xeon(R) Platinum 8269CY CPU @ 2.50GHz）

如果日志太大会受限于物理磁盘写出能力，测试环境最大输出能力是每秒 100MB



## 16core VS 32 Core 案例比较

如果都是用一半超线程，32 Core基本能达到16Core的1.9倍性能

下图上半部分是32C，下半部分是16C

![image-20220810160155192](/images/951413iMgBlog/image-20220810160155192.png)

对应CPU状态

![image-20220810160241298](/images/951413iMgBlog/image-20220810160241298.png)

![image-20220810160249972](/images/951413iMgBlog/image-20220810160249972.png)

如果都改用物理核后，32Core VS 16Core是 25万 VS 15万，大概提升有1.67倍，不到2倍

同时看到perf 也是打了7折，这应该是core太多后应用代码内部锁竞争太激励



## 横向比较

logback、log4j2等横向关系和性能比较分析

### 日志框架

紫色为接口类，蓝色为实现，白色为转换
![image.png](/images/oss/f8f589fd11e4d480162e24b02d95e511.png)

log4j-over-slf4j和slf4j-log4j12之所以不能共存，是因为它俩可以造成循环依赖！从图中可以看到，有不少会造成循环依赖的场景，比如jul-to-slf4j与slf4j-jdk14、jcl-over-slf4j与JCL等，有些jar的共存会让调用方产生困惑，不知道具体调用哪个

![image-20220907151035617](/images/951413iMgBlog/image-20220907151035617.png)

### 性能比较

![image.png](/images/oss/260fd07e702c1a0636d277bbf73607cb.png)

- 可见在同步日志模式下, Logback的性能是最糟糕的.
- 而log4j2的性能无论在同步日志模式还是异步日志模式下都是最佳的.

其根本原因在于log4j2使用了LMAX, 一个无锁的线程间通信库代替了, logback和log4j之前的队列. 并发性能大大提升。有兴趣的同学，可以深入探索。

来自log4j2官方的比较数据（同步，在不同的瓶颈下）

[https://logging.apache.org/log4j/2.x/performance.html](https://logging.apache.org/log4j/2.x/performance.html)：

![image.png](/images/oss/46214ad5378ef5790ad167037a41149d.png)

![image.png](/images/oss/ef794e63ba049e1fa76a1884a6e213a5.png)

#### 异步场景下的性能比较

AsyncAppender to FileAppender
![image.png](/images/oss/29c0786bbcecc092ca7c84cce203453d.png)

### Log4j2中的异步日志(AsyncAppender)

默认用ArrayBlockingQueue.队列大小为128.

#### 关于ArrayBlockingQueue

ArrayBlockingQueue是一种地节省了空间，对于记日志有很好的适用性，同时避免内存的伸缩产生波动，也降低了GC的负担。入队出队时由内部的重入锁来控制并发，同时默认采用非公平锁的性质来处理活跃线程的闯入(Barge)，从而提高吞吐量。
ArrayBlockingQueue在处理数据的入队提供了offer和put方法。两者的区别是：如果队列满了，offer直接返回给调用线程false, 而不用等待，这种场景较适合异步写日志，即使没有入队成功，仍然可以接受。而put方法则会让当前线程进入等待队列，并再次去竞争锁。
类似的，处理出队时提供了poll和take方法，区别也是是否阻塞调用线程。




## 参考资料

[flush cache 大小8K ](https://www.iteye.com/blog/k1280000-2265177)