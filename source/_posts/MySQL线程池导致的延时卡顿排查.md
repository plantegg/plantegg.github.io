---
title: MySQL线程池导致的延时卡顿排查
date: 2020-06-05 17:30:03
categories:
    - MySQL
tags:
    - Linux
    - MySQL
    - network
    - Performance
    - ThreadPool
---

# MySQL 线程池导致的延时卡顿排查

## 问题描述

简单小表的主键点查SQL，单条执行很快，但是放在业务端，有时快有时慢，取了一条慢sql，在MySQL侧查看，执行时间很短。

通过监控有显示逻辑慢SQL和物理SQL ，取一slow.log里显示有12秒执行时间的SQL，但是这次12秒的执行在MySQL上记录下来的执行时间都不到1ms。

所在节点的tsar监控没有异常，Tomcat manager监控上没有fgc，Tomcat实例规格 16C32g*8, MySQL  32c128g  *32 。

5-28号现象复现，从监控图上CPU、内存、网络都没发现异常，MySQL侧查到的SQL依然执行很快，Tomcat侧记录12S执行时间，当时Tomcat节点的网络流量、CPU压力都很小。

所以客户怀疑Tomcat有问题或者Tomcat上的代码写得有问题导致了这个问题，需要排查和解决掉。

## Tomcat上抓包分析

### 慢的连接

经过抓包分析发现在慢的连接上，所有操作都很慢，包括set 命令，慢的时间主要分布在3秒以上，1-3秒的慢查询比较少，这明显不太符合分布规律。并且目前看慢查询基本都发生在MySQL的0库的部分连接上（后端有一堆MySQL组成的集群），下面抓包的4637端口是MySQL的服务端口：

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/b8ed95b7081ee80eb23465ee0e9acc74.png)

以上两个连接都很慢，对应的慢查询在MySQL里面记录很快。

慢的SQL的response按时间排序基本都在3秒以上：

<img src="https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/36a2a60f64011bc73fee06c291bcd79f.png" alt="image.png" style="zoom:67%;" />

或者只看response time 排序，中间几个1秒多的都是 Insert语句。也就是1秒到3秒之间的没有，主要是3秒以上的查询

!<img src="https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/07146ff29534a1070adbdb8cedd280c9.png" alt="image.png" style="zoom:67%;" />



### 快的连接

同样一个查询SQL，发到同一个MySQL上(4637端口)，下面的连接上的所有操作都很快，下面是两个快的连接上的执行截图

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/d129dfe1a50b182f4d100ac7147f9099.png)

别的MySQL上都比较快，比如5556分片上的所有response RT排序，只有偶尔极个别的慢SQL

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/01531d138b9bc8dafda76b7c8bbb5bc9.png)

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

mysql> 

22 rows in set (0.00 sec)

mysql> show create table XT_SCENES_PARAM \G
*************************** 1. row ***************************
       Table: XT_SCENES_PARAM
Create Table: CREATE TABLE `xt_scenes_param` (
  `SCENES` varchar(150) COLLATE utf8mb4_bin NOT NULL COMMENT '????',
  `CURRENT_USABLE_FLAG` varchar(150) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '????????',
  `NEXT_USABLE_FLAG` varchar(150) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '????????????',
  `PREVIOUS_USABLE_FLAG` varchar(150) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '????????',
  `LAST_UPDATE_TIME` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '???????',
  `CHANGE_FLAG` char(1) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '?????1???? 2?????',
  `SCENES_DESC` varchar(150) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '????',
  PRIMARY KEY (`SCENES`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='????????'
1 row in set (0.00 sec)

mysql> explain SELECT `XT_SCENES_PARAM`.`SCENES` AS `SCENES`, `XT_SCENES_PARAM`.`CURRENT_USABLE_FLAG` AS `currentUseFlag`, `XT_SCENES_PARAM`.`PREVIOUS_USABLE_FLAG` AS `previousUseFlag`, `XT_SCENES_PARAM`.`LAST_UPDATE_TIME` AS `lastUpdateTime`, `XT_SCENES_PARAM`.`SCENES_DESC` AS `scenesDesc` FROM `XT_SCENES_PARAM` AS `XT_SCENES_PARAM` WHERE (`XT_SCENES_PARAM`.`SCENES` = 'QYXXCX');

+----+-------------+-----------------+-------+---------------+---------+---------+-------+------+-------+
| id | select_type | table           | type  | possible_keys | key     | key_len | ref   | rows | Extra |
+----+-------------+-----------------+-------+---------------+---------+---------+-------+------+-------+
|  1 | SIMPLE      | XT_SCENES_PARAM | const | PRIMARY       | PRIMARY | 602     | const |    1 | NULL  |
+----+-------------+-----------------+-------+---------------+---------+---------+-------+------+-------+
1 row in set (0.00 sec)
```

## 综上结论

问题原因跟MySQL线程池比较相关，慢的连接总是慢，快的连接总是快。需要到MySQL Server下排查线程池相关参数。

同一个慢的连接上的回包，所有 ack 就很快（OS直接回，不需要进到MySQL），但是set就很慢，基本理解只要进到MySQL的就慢了，所以排除了网络原因（流量本身也很小，也没看到乱序、丢包之类的）

## 问题解决

18点的时候将4637端口对应的MySQL的 thread_pool_oversubscribe 从10调整到20后，基本没有慢查询了：

<img src="https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/92069e7521368e4d2519b3b861cc7faa.png" alt="image.png" style="zoom:50%;" />

但是不太能理解的是从MySQL的观察来看，并发压力很小，很难抓到running thread比较高的情况。

MySQL记录的执行时间是指SQL语句开始解析后统计，中间的等锁、等Worker都不会记录在执行时间中，所以当时对应的SQL在MySQL日志记录中很快。

*这里表现出高 RT 而不是超时，原因是 MySQL 线程池有另一个参数 thread_pool_stall_limit 防止线程卡死．请求如果在分组内等待超过 thread_pool_stall_limit 时间没被处理，则会退回传统模式，创建新线程来处理请求．这个参数的默认值是 500ms。另外这个等待时间是不会被记录到MySQL的慢查询日志中的*

## Thread Pool原理

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/6fbe1c10f07dd1c26eba0c0e804fa9a8.png)

MySQL 原有线程调度方式有每个连接一个线程(one-thread-per-connection)和所有连接一个线程（no-threads）。

no-threads一般用于调试，生产环境一般用one-thread-per-connection方式。one-thread-per-connection 适合于低并发长连接的环境，而在高并发或大量短连接环境下，大量创建和销毁线程，以及线程上下文切换，会严重影响性能。另外 one-thread-per-connection 对于大量连接数扩展也会影响性能。

为了解决上述问题，MariaDB、Percona、Oracle MySQL 都推出了线程池方案，它们的实现方式大体相似，这里以 Percona 为例来简略介绍实现原理，同时会介绍我们在其基础上的一些改进。

线程池由一系列 worker 线程组成，这些worker线程被分为`thread_pool_size`个group。用户的连接按 round-robin 的方式映射到相应的group 中，一个连接可以由一个group中的一个或多个worker线程来处理。

`thread_pool_stall_limit` timer线程检测间隔。此参数设置过小，会导致创建过多的线程，从而产生较多的线程上下文切换，但可以及时处理锁等待的场景，避免死锁。参数设置过大，对长语句有益，但会阻塞短语句的执行。参数设置需视具体情况而定，例如99%的语句10ms内可以完成，那么我们可以将就`thread_pool_stall_limit`设置为10ms。

thread_pool_oversubscribe  一个group中活跃线程和等待中的线程超过`thread_pool_oversubscribe`时，不会创建新的线程。 此参数可以控制系统的并发数，同时可以防止调度上的死锁，考虑如下情况，A、B、C三个事务，A、B 需等待C提交。A、B先得到调度，同时活跃线程数达到了`thread_pool_max_threads`上限，随后C继续执行提交，此时已经没有线程来处理C提交，从而导致A、B一直等待。`thread_pool_oversubscribe`控制group中活跃线程和等待中的线程总数，从而防止了上述情况。

一包在手，万事无忧

## 参考文章

https://www.atatech.org/articles/36343

http://mysql.taobao.org/monthly/2016/02/09/

https://dbaplus.cn/news-11-1989-1.html