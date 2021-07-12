---
title: MySQL线程池导致的延时卡顿排查
date: 2020-11-17 07:30:03
categories:
    - MySQL
tags:
    - Linux
    - MySQL
    - network
    - nginx
    - ThreadPool
    - 卡顿
---

# MySQL 线程池导致的延时卡顿排查

## 问题描述

简单小表的主键点查SQL，单条执行很快，但是放在业务端，有时快有时慢，取了一条慢sql，在MySQL侧查看，执行时间很短。

通过Tomcat业务端监控有显示慢SQL，取slow.log里显示有12秒执行时间的SQL，但是这次12秒的执行在MySQL上记录下来的执行时间都不到1ms。

所在节点的tsar监控没有异常，Tomcat manager监控上没有fgc，Tomcat实例规格 16C32g*8, MySQL  32c128g  *32 。

5-28号现象复现，从监控图上CPU、内存、网络都没发现异常，MySQL侧查到的SQL依然执行很快，Tomcat侧记录12S执行时间，当时Tomcat节点的网络流量、CPU压力都很小。

所以客户怀疑Tomcat有问题或者Tomcat上的代码写得有问题导致了这个问题，需要排查和解决掉。

## Tomcat上抓包分析

### 慢的连接

经过抓包分析发现在慢的连接上，所有操作都很慢，包括set 命令，慢的时间主要分布在3秒以上，1-3秒的慢查询比较少，这明显不太符合分布规律。并且目前看慢查询基本都发生在MySQL的0库的部分连接上（后端有一堆MySQL组成的集群），下面抓包的4637端口是MySQL的服务端口：

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/b8ed95b7081ee80eb23465ee0e9acc74.png)

以上两个连接都很慢，对应的慢查询在MySQL里面记录很快。

慢的SQL的response按时间排序基本都在3秒以上：

<img src="https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/36a2a60f64011bc73fee06c291bcd79f.png" alt="image.png" style="zoom:67%;" />

或者只看response time 排序，中间几个1秒多的都是 Insert语句。也就是1秒到3秒之间的没有，主要是3秒以上的查询

!<img src="https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/07146ff29534a1070adbdb8cedd280c9.png" alt="image.png" style="zoom:67%;" />

### 快的连接

同样一个查询SQL，发到同一个MySQL上(4637端口)，下面的连接上的所有操作都很快，下面是两个快的连接上的执行截图

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/d129dfe1a50b182f4d100ac7147f9099.png)

别的MySQL上都比较快，比如5556分片上的所有response RT排序，只有偶尔极个别的慢SQL

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/01531d138b9bc8dafda76b7c8bbb5bc9.png)

## MySQL相关参数

```
mysql> show variables like '%thread%';
+--------------------------------------------+-----------------+
| Variable_name                              | Value           |
+--------------------------------------------+-----------------+
| innodb_purge_threads                       | 1               |
| innodb_MySQL_thread_extra_concurrency        | 0               |
| innodb_read_io_threads                     | 16              |
| innodb_thread_concurrency                  | 0               |
| innodb_thread_sleep_delay                  | 10000           |
| innodb_write_io_threads                    | 16              |
| max_delayed_threads                        | 20              |
| max_insert_delayed_threads                 | 20              |
| myisam_repair_threads                      | 1               |
| performance_schema_max_thread_classes      | 50              |
| performance_schema_max_thread_instances    | -1              |
| pseudo_thread_id                           | 12882624        |
| MySQL_is_dump_thread                         | OFF             |
| MySQL_threads_running_ctl_mode               | SELECTS         |
| MySQL_threads_running_high_watermark         | 50000           |
| rocksdb_enable_thread_tracking             | OFF             |
| rocksdb_enable_write_thread_adaptive_yield | OFF             |
| rocksdb_signal_drop_index_thread           | OFF             |
| thread_cache_size                          | 100             |
| thread_concurrency                         | 10              |
| thread_handling                            | pool-of-threads |
| thread_pool_high_prio_mode                 | transactions    |
| thread_pool_high_prio_tickets              | 4294967295      |
| thread_pool_idle_timeout                   | 60              |
| thread_pool_max_threads                    | 100000          |
| thread_pool_oversubscribe                  | 10              |
| thread_pool_size                           | 96              |
| thread_pool_stall_limit                    | 30              |
| thread_stack                               | 262144          |
| threadpool_workaround_epoll_bug            | OFF             |
| tokudb_cachetable_pool_threads             | 0               |
| tokudb_checkpoint_pool_threads             | 0               |
| tokudb_client_pool_threads                 | 0               |
+--------------------------------------------+-----------------+
33 rows in set (0.00 sec)
```

## 综上结论

问题原因跟MySQL线程池比较相关，慢的连接总是慢，快的连接总是快。需要到MySQL Server下排查线程池相关参数。

同一个慢的连接上的回包，所有 ack 就很快（OS直接回，不需要进到MySQL），但是set就很慢，基本理解只要进到MySQL的就慢了，所以排除了网络原因（流量本身也很小，也没看到乱序、丢包之类的）

## 问题解决

18点的时候将4637端口上的MySQL thread_pool_oversubscribe 从10调整到20后，基本没有慢查询了：

<img src="https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/92069e7521368e4d2519b3b861cc7faa.png" alt="image.png" style="zoom:50%;" />

当时从MySQL的观察来看，并发压力很小，很难抓到running thread比较高的情况（update: 可能是任务积压在队列中，只是96个thread pool中的一个thread全部running，导致整体running不高）

MySQL记录的执行时间是指SQL语句开始解析后统计，中间的等锁、等Worker都不会记录在执行时间中，所以当时对应的SQL在MySQL日志记录中很快。

*这里表现出高 RT 而不是超时，原因是 MySQL 线程池有另一个参数 thread_pool_stall_limit 防止线程卡死．请求如果在分组内等待超过 thread_pool_stall_limit 时间没被处理，则会退回传统模式，创建新线程来处理请求．这个参数的默认值是 500ms。另外这个等待时间是不会被记录到MySQL的慢查询日志中的*

## Thread Pool原理

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/6fbe1c10f07dd1c26eba0c0e804fa9a8.png)

MySQL 原有线程调度方式有每个连接一个线程(one-thread-per-connection)和所有连接一个线程（no-threads）。

no-threads一般用于调试，生产环境一般用one-thread-per-connection方式。one-thread-per-connection 适合于低并发长连接的环境，而在高并发或大量短连接环境下，大量创建和销毁线程，以及线程上下文切换，会严重影响性能。另外 one-thread-per-connection 对于大量连接数扩展也会影响性能。

为了解决上述问题，MariaDB、Percona、Oracle MySQL 都推出了线程池方案，它们的实现方式大体相似，这里以 Percona 为例来简略介绍实现原理，同时会介绍我们在其基础上的一些改进。

线程池由一系列 worker 线程组成，这些worker线程被分为`thread_pool_size`个group。用户的连接按 round-robin 的方式映射到相应的group 中，一个连接可以由一个group中的一个或多个worker线程来处理。

thread_pool_oversubscribe  一个group中活跃线程和等待中的线程超过`thread_pool_oversubscribe`时，不会创建新的线程。 此参数可以控制系统的并发数，同时可以防止调度上的死锁，考虑如下情况，A、B、C三个事务，A、B 需等待C提交。A、B先得到调度，同时活跃线程数达到了`thread_pool_max_threads`上限，随后C继续执行提交，此时已经没有线程来处理C提交，从而导致A、B一直等待。`thread_pool_oversubscribe`控制group中活跃线程和等待中的线程总数，从而防止了上述情况。

`thread_pool_stall_limit` timer线程检测间隔。此参数设置过小，会导致创建过多的线程，从而产生较多的线程上下文切换，但可以及时处理锁等待的场景，避免死锁。参数设置过大，对长语句有益，但会阻塞短语句的执行。参数设置需视具体情况而定，例如99%的语句10ms内可以完成，那么我们可以将就`thread_pool_stall_limit`设置为10ms。

**MySQL Thread Pool之所以分成多个小的Thread Group Pool而不是一个大的Pool，是为了分解锁（每个group中都有队列，队列需要加锁。类似ConcurrentHashMap提高并发的原理），提高并发效率。**

group中的队列是用来区分优先级的，事务中的语句会放到高优先队列（非事务语句和autocommit 都会在低优先队列）；等待太久的SQL也会挪到高优先队列，防止饿死。

比如启用Thread Pool后，如果出现多个慢查询，容易导致拨测类请求超时，进而出现Server异常的判断（类似Nginx 边缘触发问题）；或者某个group满后导致慢查询和拨测失败之类的问题

### thread_pool_size过小的案例

应用出现大量1秒超时报错：

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/52dbeb1c1058e6dbff0a790b4b4ba477.png)

分析代码，这个报错是是数据库连接池在创建到MySQL的连接后会发送一个ping来验证下连接是否有效，有效后才给应用使用。说明连接创建成功，但是MySQL处理指令缓慢。

继续分析MySQL的参数：

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/8987545cc311fdd3ae232aee8c3f855a.png)

可以看到thread_pool_size是1，太小了，将所有MySQL线程都放到一个buffer里面来抢锁，锁冲突的概率太高。调整到16后可以明显看到MySQL的RT从原来的12ms下降到了3ms不到，整个QPS大概有8%左右的提升。这是因为pool size为1的话所有sql都在一个队列里面，多个worker thread加锁等待比较严重，导致rt延迟增加。

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/114b5b71468b33128e76129bbc7fb8f4.png)

这个问题发现是因为压力一上来的时候要创建大量新的连接，这些连结创建后会去验证连接的有效性，也就是给MySQL发一个ping指令，一般都很快，这个ping验证过程设置的是1秒超时，但是实际看到大量超时异常堆栈，从而发现MySQL内部响应有问题。

### MySQL ping和MySQL协议相关知识

> [Ping](https://dev.mysql.com/doc/connector-j/8.0/en/connector-j-usagenotes-j2ee-concepts-connection-pooling.html#idm47306928802368) use the JDBC method [Connection.isValid(int timeoutInSecs)](http://docs.oracle.com/javase/7/docs/api/java/sql/Connection.html#isValid(int)). Digging into the MySQL Connector/J source, the actual implementation uses com.mysql.jdbc.ConnectionImpl.pingInternal() to send a simple ping packet to the DB and returns true as long as a valid response is returned.

MySQL ping protocol是发送了一个 `0e` 的byte标识给Server，整个包加上2byte的Packet Length（内容为：1），2byte的Packet Number（内容为：0），总长度为5 byte

```
public class MySQLPingPacket implements CommandPacket {
    private final WriteBuffer buffer = new WriteBuffer();
    public MySQLPingPacket() {
        buffer.writeByte((byte) 0x0e);
    }
    public int send(final OutputStream os) throws IOException {
        os.write(buffer.getLengthWithPacketSeq((byte) 0)); // Packet Number
        os.write(buffer.getBuffer(),0,buffer.getLength()); // Packet Length 固定为1
        os.flush();
        return 0;
    }
}
```

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/7cf291546a167b0ca6a017e98db5a821.png)

也就是一个TCP包中的Payload为 MySQL协议中的内容长度 + 4（Packet Length+Packet Number）



## 总结

这个问题的本质在于 MySQL线程池开启后，因为会将多个连接分配在一个池子中共享这个池子中的几个线程。导致一个池子中的线程特别慢的时候会影响这个池子中所有的查询都会卡顿。即使别的池子很空闲也不会将任务调度过去。

MySQL线程池设计成多个池子（Group）的原因是为了将任务队列拆成多个，这样每个池子中的线程只是内部竞争锁，跟其他池子不冲突，当然这个设计带来的问题就是多个池子中的任务不能均衡了。

同时从案例我们也可以清楚地看到这个池子太小会造成锁冲突严重的卡顿，池子太大（每个池子中的线程数量就少）容易造成等线程的卡顿。

**类似地这个问题也会出现在Nginx的多worker中，一旦一个连接分发到了某个worker，就会一直在这个worker上处理，如果这个worker上的某个连接有一些慢操作，会导致这个worker上的其它连接的所有操作都受到影响，特别是会影响一些探活任务的误判。**

Nginx的worker这么设计也是为了将单worker绑定到固定的cpu，然后避免多核之间的上下文切换。



一包在手，万事无忧



## 参考文章

https://www.atatech.org/articles/36343

http://mysql.taobao.org/monthly/2016/02/09/

https://dbaplus.cn/news-11-1989-1.html