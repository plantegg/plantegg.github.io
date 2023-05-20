---
title: MySQL 8.0新特性和性能数据
date: 2022-07-03 17:30:03
categories:
    - MySQL
tags:
    - MySQL
    - performance
---

# MySQL 8.0新特性和性能数据

## MySQL 8.0带来了很多新特性

针对性能方面介绍全在这个PPT（ http://dimitrik.free.fr/Presentations/MySQL_Perf-OOW2018-dim.pdf）里面了：

IO_Bound 下性能提升简直非常明显，之前主要是fil_system的锁导致IO的并发上不去，见图1。

因为优化了redo的写入模式，采用了事件的模型，所以写入场景有较好的提升 。

utf8mb4在点查询场景优势不明显，在distinct range查询下有30%提升。

内存只读场景略有提升。

还有傲腾对SSD的数据，不过Intel都放弃了，就不说了。



## 性能

### page size

MySQL的页都是16K, 当查询的行不在内存中时需要按照16K为单位从磁盘读取页,而文件系统中的页是4k，也就是一次数据库请求需要有4次磁盘IO，如过查询比较随机，每次只需要一个页中的几行数据，存在很大的读放大。

那么我们是否可以把MySQL的页设置为4K来减少读放大呢？

在5.7里收益不大，因为每次IO存在 fil_system 的锁，导致IO的并发上不去

8.0中总算优化了这个场景，测试细节可以参考[这篇](http://dimitrik.free.fr/blog/archives/2018/05/mysql-performance-1m-iobound-qps-with-80-ga-on-intel-optane-ssd.html)

16K VS 4K 性能对比（4K接近翻倍）

![img](/images/951413iMgBlog/1547605552845-d406952d-9857-462d-a666-1694b19fbedb.png)

4K会带来的问题：顺序insert慢了10%（因为fsync更多了）；DDL更慢；二级索引更多的场景下4K性能较差；大BP下，刷脏代价大。



### **REDO的优化**

redo的优化似乎是8.0读写性能优于以往的主要原因

redo的模型改成了事件驱动，而不是通过争抢锁实现，专用的flush线程刷完IO后通知用户线程，并且会根据IO的rt自动调整每次flush的data大小，如果io延迟很低，就大量小IO，如果IO延迟高，就用大io刷，也就说redo的刷写能力完全取决于IO的吞吐

但是事件驱动的方式在小并发下性能没有单线程锁的方式高效，这块已经优化了，需要自己测下效果

![image-20220810150929638](/images/951413iMgBlog/image-20220810150929638.png)



## 总结

MySQL 8.0优化总结，从官方给出的数据来看，可以总结如下

- 只读场景没有什么优化
- [utf8mb4的性能提升比较明显](https://yuque.antfin-inc.com/frodo/lyul32/qcggx4#b329a99a)
- 优化了fil_system，[MySQL 可以尝试使用4K的页](https://yuque.antfin-inc.com/frodo/lyul32/qcggx4#26583664)
- 8.0使用新硬件能够获得较好的收益，多socket, optane
- 由于redo的优化以及[新的热点检查算法](https://mysqlserverteam.com/contention-aware-transaction-scheduling-arriving-in-innodb-to-boost-performance/)，关闭binlog下，读写混合的场景性能比5.7好很多，但是生产环境无法关闭binlog，默认的字符集也不是latin，所以具体的数据需要单独测试，官方数据只能参考
- Double Write的问题需要在高并发，低命中率下才会触发，生产环境遇到的不多，该问题预计下个版本就修复了
- 生产环境需要关闭UNDO Auto-Truncate 
- binlog的问题在8.0比较明显，暂时没有解法
- 另外innodb_flush_method=O_DIRECT_NO_FSYNC 在8.0.14版本后可以保障应用的稳定性了



> Prior to 8.0.14, the `O_DIRECT_NO_FSYNC` setting is not recommended for use on Linux systems. It may cause the operating system to hang due to file system metadata becoming unsynchronized. As of MySQL 8.0.14, `InnoDB` calls `fsync()` after creating a new file, after increasing file size, and after closing a file, which permits `O_DIRECT_NO_FSYNC` mode to be safely used on EXT4 and XFS file systems. The `fsync()` system call is still skipped after each write operation.

