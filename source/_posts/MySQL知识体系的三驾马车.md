---
title: MySQL知识体系的三驾马车
date: 2019-05-26 17:30:03
categories:
    - MySQL
tags:
    - MySQL
    - Index
    - log
    - 事务
---


# MySQL知识体系的三驾马车

在我看来要掌握好MySQL的话要理解好这三个东西：

- 索引（B+树）
- 日志（WAL）
- 事务(可见性)

索引决定了查询的性能，也是用户感知到的数据库的关键所在，日常使用过程中抱怨最多的就是查询太慢了；

而日志是一个数据库的灵魂，他决定了数据库为什么可靠，还要保证性能，核心原理就是将随机写转换成顺序写；

事务则是数据库的皇冠。

## 索引

索引主要是解决查询性能的问题，数据一般都是写少查多，而且要满足各种查，所以使用数据库过程中最常见的问题就是索引的优化。

MySQL选择B+树来当索引的数据结构，是因为B+树的树干只有索引，能使得索引保持比较小，更容易加载到内存中；数据全部放在B+树的叶节点上，整个叶节点又是个有序双向链表，这样非常合适区间查找。

如果用平衡二叉树当索引，想象一下一棵 100 万节点的平衡二叉树，树高 20。一次查询可能需要访问 20 个数据块。在机械硬盘时代，从磁盘随机读一个数据块需要 10 ms 左右的寻址时间。也就是说，对于一个 100 万行的表，如果使用二叉树来存储，单独访问一个行可能需要 20 个 10 ms 的时间，这个查询可真够慢的

对比一下 InnoDB 的一个整数字段B+数索引为例，B+树的杈数一般是 1200。这棵树高是 4 的时候，就可以存 1200 的 3 次方个值，这已经 17 亿了。考虑到树根的数据块总是在内存中的，一个 10 亿行的表上一个整数字段的索引，查找一个值最多只需要访问 3 次磁盘。其实，树的第二层也有很大概率在内存中，那么访问磁盘的平均次数就更少了。

明确以下几点：

- B+树是N叉树，以一个整数字段索引来看，N基本等于1200。数据库里的树高一般在2-4层。
- 索引的树根节点一定在内存中，第二层大概率也在内存，再下层基本都是在磁盘中。
- 每往下读一层就要进行一次磁盘IO。 从B+树的检索过程如下图所示： 

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/87f90b5535714486f4e0c86982b54141.png)

每往下读一层就会进行一次磁盘IO，然后会一次性读取一些连续的数据放入内存中。

一个22.1G容量的表， 只需要高度为3的B+树就能存储，如果拓展到4层，可以存放25T的容量。但主要占内存的部分是叶子节点中的整行数据，非叶子节点全部加载到内存只需要18.8M。

### B+树

MySQL的索引结构主要是B+树，也可以选hash

B+树特点：

- 叶子结点才有数据，这些数据形成一个有序链表
- 非叶子节点只有索引，导致非叶子节点小，查询的时候整体IO更小、更稳定（相对B数）
- 删除相对B树快，因为数据有大量冗余，大部分时候不需要改非叶子节点，删除只需要从叶子节点中的链表中删除
- B+树是多叉树，相对二叉树二分查找效率略低，但是树高度大大降低，减少了磁盘IO
- 因为叶子节点的有序链表存在，支持范围查找

B+树的标准结构：

![Image](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/640-9735668.)

innodb实现的B+树用了双向链表，节点内容存储的是页号（每页16K）

![Image](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/640-20211217181055800)

### 联合索引

对于多个查询条件的复杂查询要正确建立多列的联合索引来尽可能多地命中多个查询条件，过滤性好的列要放在联合索引的前面。

MySQL一个查询只能用一个索引。

### 索引下推(index condition pushdown )

对于多个where条件的话，如果索引只能命中一个，剩下的那个条件过滤还是会通过回表来获取到后判断是否符合，但是MySQL5.6后，如果剩下的那个条件在联合索引上（但是因为第一个条件是模糊查询，没法用全联合索引），会将这个条件下推到索引判断上，来减少回表次数。这叫**索引下推优化(index condition pushdown )**

### 覆盖索引

要查询的列(select后面的列)如果都在索引上，那么这个查询的最终结果都可以直接从索引上读取到，这样读一次索引（数据小、顺序读）性能非常好。否则的话需要回表去获取别的列

前缀索引用不上覆盖索引对查询性能的优化，每次索引命中可能需要做一次回表，确认完整列值

### 回表

select * from table order by id limit  150000,10 这样limit后偏移很大一个值的查询，会因为**回表**导致非常慢。

这是因为根据id列上索引去查询过滤，但是select *要求查所有列的内容，但是索引上只有id的数据，所以导致每次对id索引进行过滤都要求去回表（根据id到表空间取到这个id行所有列的值），每一行都要回表导致这里出现了150000+10次随机磁盘读。

可以通过先用一个子查询(select **id** from order by id limit  150000,10)，子查询中只查id列，而id的值都在索引上，用上了**覆盖索引**来避免回表。

先查到这10个id(扫描行数还是150000+10， 这里的limit因为有deleted记录、每行大小不一样等因素影响，没法一次跳到150000处。但是这次扫描150000行的时候不需要回表，所以速度快多了)，然后再跟整个表做jion（join的时候只需要对这10个id行进行回表），来提升性能。

### 索引的一些其它知识点

多用自增主键是因为自增主键保证的是主键一直是增加的，也就是不会在索引中间插入，这样的话避免的索引页的分裂(代价很高)

写数据除了记录redo-log之外还会在内存（change buffer）中记录下修改后的数据，这样再次修改、读取的话不需要从磁盘读取数据，非唯一索引才能用上change buffer，因为唯一索引一定需要读磁盘验证唯一性，既然读过磁盘这个change buffer的意义就不大了。

```
mysql> insert into t(id,k) values(id1,k1),(id2,k2);//假设k1页在buffer中，k2不在
```

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/d1c817af83ba09c6ee6da2eca87af6d3.png)

### Buffer POOL

（1）缓冲池(buffer pool)是一种**常见的降低磁盘访问的机制；**

（2）缓冲池通常**以页(page)为单位缓存数据；**

（3）缓冲池的**常见管理算法是LRU**，memcache，OS，InnoDB都使用了这种算法；

（4）InnoDB对普通LRU进行了优化：

  \- 将缓冲池分为**老生代和新生代**，入缓冲池的页，优先进入老生代，页被访问，才进入新生代，以解决预读失效的问题

  \- 页被访问（预读的丢到old区），且在老生代**停留时间超过配置阈值（innodb_old_blocks_time）**的，才进入新生代，以解决批量数据访问，大量热数据淘汰的问题

![图片](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/640-8001413.png)

**只有同时满足「被访问」与「在 old 区域停留时间超过 1 秒」两个条件，才会被插入到 young 区域头部**

## 日志

数据库的关键瓶颈在于写，因为每次更新都要落盘防止丢数据，而磁盘最怕的就是随机写。

### Write-Ahead logging（WAL）

写磁盘前先写日志，这样不用担心丢数据问题，写日志又是一个顺序写,性能比随机写好多了，这样将性能很差的随机写转换成了顺序写。然后每过一段时间将这些日志合并后真正写入到表空间，这次是随机写，但是有机会将多个写合并成一个，比如多个写在同一个Page上。

这是数据库优化的关键。

### bin-log

MySQL Server用来记录执行修改数据的SQL，Replication基本就是复制并重放这个日志。有statement、row和混合模式三种。

bin-log保证不了表空间和bin-log的一致性，也就是断电之类的场景下是没法保证数据的一致性。

MySQL 日志刷新策略通过 sync_binlog 参数进行配置，其有 3 个可选配置：

1. sync_binlog=0：MySQL 应用将完全不负责日志同步到磁盘，将缓存中的日志数据刷新到磁盘全权交给操作系统来完成；
2. sync_binlog=1：MySQL 应用在事务提交前将缓存区的日志刷新到磁盘；
3. sync_binlog=N：当 N 不为 0 与 1 时，MySQL 在收集到 N 个日志提交后，才会将缓存区的日志同步到磁盘。

### redo-log

INNODB引擎用来保证事务的完整性，也就是crash-safe。MySQL 默认是保证不了不丢数据的，如果写了表空间还没来得及写bin-log就会造成主从数据不一致；或者在事务中需要执行多个SQL，bin-log保证不了完整性。

而在redo-log中任何修改都会先记录到redo-log中，即使断电MySQL重启后也会先检查redo-log将redo-log中记录了但是没有提交到表空间的数据进行提交（刷脏）

redo-log和bin-log的比较：

- redo log 是 InnoDB 引擎特有的；binlog 是 MySQL 的 Server 层实现的，所有引擎都可以使用。redo-log保证了crash-safe的问题，binlog只能用于归档，保证不了safe。
- redo log 是物理日志，记录的是“在某个数据页上做了什么修改”；binlog 是逻辑日志，记录的是这个语句的原始逻辑，比如“给 ID=2 这一行的 c 字段加 1 ”。
- redo log 是循环写的，空间固定会用完；binlog 是可以追加写入的。“追加写”是指 binlog 文件写到一定大小后会切换到下一个，并不会覆盖以前的日志。

**redo-log中记录的是对页的操作，而不是修改后的数据页**，buffer pool（或者说change buffer）中记录的才是数据页。正常刷脏是指的将change buffer中的脏页刷到表空间的磁盘，如果没来得及刷脏就崩溃了，那么就只能从redo-log来将没有刷盘的操作再执行一次让他们真正落盘。buffer pool中的任何变化都会写入到redo-log中（不管事务是否提交）

只有当commit（非两阶段的commit）的时候才会真正把redo-log写到表空间的磁盘上（不一定是commit的时候刷到表空间）。

如果机器性能很好（内存大、innodb_buffer_pool设置也很大，iops高），但是设置了比较小的innodb_logfile_size那么会造成redo-log很快会被写满，这个时候系统会停止所有更新，全力刷盘去推进ib_logfile checkpoint（位点），这个时候磁盘压力很小，但是数据库性能会出现间歇性下跌（select 反而相对更稳定了--更少的merge）。

redo-log要求数据量尽量少，这样写盘IO小；操作幂等（保证重放幂等）。实际逻辑日志(Logical Log, 也就是bin-log)的特点就是数据量小，而幂等则是基于Page的Physical Logging特点。最终redo-log的形式是**Physiological Logging**的方式，来兼得二者的优势。

所谓Physiological Logging，就是以Page为单位，但在Page内以逻辑的方式记录。举个例子，MLOG_REC_UPDATE_IN_PLACE类型的REDO中记录了对Page中一个Record的修改，方法如下：

> （Page ID，Record Offset，(Filed 1, Value 1) ... (Filed i, Value i) ... )

其中，PageID指定要操作的Page页，Record Offset记录了Record在Page内的偏移位置，后面的Field数组，记录了需要修改的Field以及修改后的Value。

Innodb的默认Page大小是16K，OS文件系统默认都是4KB，对16KB的Page的修改保证不了原子性，因此Innodb又引入**Double Write Buffer**的方式来通过写两次的方式保证恢复的时候找到一个正确的Page状态。

InnoDB给每个REDO记录一个全局唯一递增的标号**LSN(Log Sequence Number)**。Page在修改时，会将对应的REDO记录的LSN记录在Page上（FIL_PAGE_LSN字段），这样恢复重放REDO时，就可以来判断跳过已经应用的REDO，从而实现重放的幂等。

### binlog和redo-log一致性的保证

bin-log和redo-log的一致性是通过两阶段提交来保证的，bin-log作为事务的协调者，两阶段提交过程中prepare是非常重的，prepare一定会持久化（日志），记录如何commit和rollback，一旦prepare成功就一定能commit和rollback，如果其他节点commit后崩溃，恢复后会有一个协商过程，其它节点发现崩溃节点已经commit，所以会跟随commit；如果崩溃节点还没有prepare那么其它节点只能rollback。

实际崩溃后恢复时MySQL是这样保证redo-log和bin-log的完整性的：

1. 如果redo-log里面的事务是完整的，也就是有了commit标识，那么直接提交
2. 如果redo-log里面事务只有完整的prepare，则去检查事务对应的binlog是否完整
   1. 如果binlog完整则提交事务
   2. 如果不完整则回滚事务
3. redo-log和binlog有一个共同的数据字段叫XID将他们关联起来

### 组提交

在没有开启binlog时，Redo log的刷盘操作将会是最终影响MySQL TPS的瓶颈所在。为了缓解这一问题，MySQL使用了组提交，将多个刷盘操作合并成一个，如果说10个事务依次排队刷盘的时间成本是10，那么将这10个事务一次性一起刷盘的时间成本则近似于1。

但是开启binlog后，binlog作为事务的协调者每次commit都需要落盘，这导致了Redo log的组提交失去了意义。

![image-20211108152328424](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20211108152328424.png)

Group Commit的方案中，其正确性的前提在于一个group内的事务没有并发冲突，因此即便并行也不会破坏事务的执行顺序。这个方案的局限性在于一个group 内的并行度仍然有限

### 刷脏

在内存中修改了，已经写入到redo-log中，但是还没来得及写入表空间的数据叫做脏页，MySQL过一段时间就需要刷脏，刷脏最容易造成MySQL的卡顿。

- redo-log写满后，系统会停止所有更新操作，把checkpoint向前推进也就是将数据写入到表空间。**这时写性能跌0，这个场景对性能影响最大**。
- 系统内存不够，也需要将内存中的脏页释放，释放前需要先刷入到表空间。
- 系统内存不够，但是redo-log空间够，也会刷脏，也就是刷脏不只是脏页写到redo-log，还要考虑读取情况。刷脏页后redo-log位点也一定会向前推荐
- 系统空闲的时候也会趁机刷脏
- 刷脏的时候默认还会连带刷邻居脏页（innodb_flush_neighbors)

当然如果一次性要淘汰的脏页太多，也会导致查询卡顿严重，可以通过设置innodb_io_capacity（一般设置成磁盘的iops），这个值越小的话一次刷脏页的数量越小，如果刷脏页速度还跟不上脏页生成速度就会造成脏页堆积，影响查询、更新性能。

在 MySQL 5.5 及以前的版本，**回滚日志是跟数据字典一起放在 ibdata 文件里的**，即使长事务最终提交，回滚段被清理，文件也不会变小。我见过数据只有 20GB，而回滚段有 200GB 的库。最终只好为了清理回滚段，重建整个库。

长事务意味着系统里面会存在很老的事务视图。由于这些事务随时可能访问数据库里面的任何数据，所以这个事务提交之前，数据库里面它可能用到的回滚记录都必须保留，这就会导致大量占用存储空间。除了对回滚段的影响，长事务还占用锁资源，也可能拖垮整个库。

表空间会刷进去没有提交的事务（比如大事务change buffer和redo-log都不够的时候），这个修改虽然在表空间中，但是通过可见性来控制是否可见。

### 落盘

innodb_flush_method 参数目前有 6 种可选配置值：

1. fdatasync；
2. O_DSYNC
3. O_DIRECT
4. O_DIRECT_NO_FSYNC
5. littlesync
6. nosync

其中，littlesync 与 nosync 仅仅用于内部性能测试，并不建议使用。

- fdatasync，即取值 0，这是默认配置值。对 log files 以及 data files 都采用 fsync 的方式进行同步；
- O_DSYNC，即取值 1。对 log files 使用 O_SYNC 打开与刷新日志文件，使用 fsync 来刷新 data files 中的数据；
- O_DIRECT，即取值 4。利用 Direct I/O 的方式打开 data file，并且每次写操作都通过执行 fsync 系统调用的方式落盘；
- O_DIRECT_NO_FSYNC，即取值 5。利用 Direct I/O 的方式打开 data files，但是每次写操作并不会调用 fsync 系统调用进行落盘；

**为什么有 O_DIRECT 与 O_DIRECT_NO_FSYNC 配置的区别？**

首先，我们需要理解更新操作落盘分为两个具体的子步骤：①文件数据更新落盘②文件元数据更新落盘。O_DIRECT 的在部分操作系统中会导致文件元数据不落盘，除非主动调用 fsync，为此，MySQL 提供了 O_DIRECT 以及 O_DIRECT_NO_FSYNC 这两个配置。

如果你确定在自己的操作系统上，即使不进行 fsync 调用，也能够确保文件元数据落盘，那么请使用 O_DIRECT_NO_FSYNC 配置，这对 MySQL 性能略有帮助。否则，请使用 O_DIRECT，不然文件元数据的丢失可能会导致 MySQL 运行错误。

### Double Write

MySQL默认数据页是16k，而操作系统内核的页目前为4k。因此当一个16k的MySQL页写入过程中突然断电，可能只写入了一部分，即数据存在不一致的情况。MySQL为了防止这种情况，每写一个数据页时，会先写在磁盘上的一个固定位置，然后再写入到真正的位置。如果第二次写入时掉电，MySQL会从第一次写入的位置恢复数据。开启double write之后数据被写入两次，如果能将其优化掉，对用户的性能将会有不小的提升。

MySQL 8.0关掉Double Write能有5%左右的性能提升

## 事务

在 MySQL/InnoDB 中，使用MVCC(Multi Version Concurrency Control) 来实现事务。每个事务修改数据之后，会创建一个新的版本，用事务id作为版本号；一行数据的多个版本会通过指针连接起来，通过指针即可遍历所有版本。

当事务读取数据时，会根据隔离级别选择合适的版本。例如对于 Read Committed 隔离级别来说，每条SQL都会读取最新的已提交版本；而对于Repeatable Read来说，会在事务开始时选择已提交的最新版本，后续的每条SQL都会读取同一个版本的数据。

![img](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/1616899015011-d90d5639-b9d7-43a4-9dcd-a77e00598216.png)

Postgres用Old to New，INNODB使用的是New to Old, 即主表存最新的版本，用链表指向旧的版本。当读取最新版本数据时，由于索引直接指向了最新版本，因此较低；与之相反，读取旧版本的数据代价会随之增加，需要沿着链表遍历。

INNODB中旧版本的数据存储于undo log中。这里的undo log起到了几个目的，一个是事务的回滚，事务回滚时从undo log可以恢复出原先的数据，另一个目的是实现MVCC，对于旧的事务可以从undo 读取旧版本数据。

### 可见性

是基于事务的隔离级别而言的，常用的事务的隔离级别有可重复读RR（Repeatable Read，MySQL默认的事务隔离级别）和读已提交RC（Read Committed）。

### 可重复读

读已提交：A事务能读到B事务已经commit了的结果，即使B事务开始时间晚于A事务

重复读的定义：一个事务启动的时候，能够看到所有已经提交的事务结果。但是之后，这个事务执行期间，其他事务的更新对它不可见。

指的是在一个事务中先后两次读到的结果是一样的，当然这两次读的中间自己没有修改这个数据，如果自己修改了就是当前读了。

如果两次读过程中，有一个别的事务修改了数据并提交了，第二次读到的还是别的事务修改前的数据，也就是这个修改后的数据不可见，因为别的事务在本事务之后。

如果一个在本事务启动之后的事务已经提交了，本事务会读到最新的数据，但是因为隔离级别的设置，会要求MySQL判断这个数据不可见，这样只能按照undo-log去反推修改前的数据，如果有很多这样的已经提交的事务，那么需要反推很多次，也会造成卡顿。

总结下，可见性的关键在于两个事务开始的先后关系：

- 如果是可重复读RR（Repeatable Read），后开始的事务提交的结果对前面的事务**不**可见
- 如果是读已提交RC（Read Committed），后开始的事务提交的结果对前面的事务可见

### 当前读

**更新数据都是先读后写的**，而这个读，只能读当前的值，称为"**当前读**"（current read）。除了 update 语句外，select 语句如果加锁，也是当前读。

事务的可重复读的能力是怎么实现的？

可重复读的核心就是一致性读（consistent read）；而**事务更新数据的时候，只能用当前读**。如果当前的记录的行锁被其他事务占用的话，就需要进入锁等待。

而读提交的逻辑和可重复读的逻辑类似，它们最主要的区别是：

- 在可重复读隔离级别下，只需要在事务开始的时候创建一致性视图，之后事务里的其他查询都共
  用这个一致性视图；
- 在读提交隔离级别下，每一个语句执行前都会重新算出一个新的视图。

### 幻读

幻读指的是一个事务中前后两次读到的数据不一致（读到了新插入的行）

可重复读是不会出现幻读的，但是更新数据时只能用当前读，当前读要求读到其它事务的修改（新插入行）

**Innodb 引擎为了解决「可重复读」隔离级别使用「当前读」而造成的幻读问题，就引出了 next-key 锁**，就是记录锁和间隙锁的组合。

- 记录锁，锁的是记录本身；
- 间隙锁，锁的就是两个值之间的空隙，以防止其他事务在这个空隙间插入新的数据，从而避免幻读现象。

### 可重复读、当前读以及行锁案例

案例表结构

```

mysql> CREATE TABLE `t` (
  `id` int(11) NOT NULL,
  `k` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;
insert into t(id, k) values(1,1),(2,2);
```

上表执行如下三个事务

![img](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/823acf76e53c0bdba7beab45e72e90d6.png)

> begin/start transaction 命令并不是一个事务的起点，在执行到它们之后的第一个操作 InnoDB 表的语句，事务才真正启动。如果你想要马上启动一个事务，可以使用 start transaction with consistent snapshot 这个命令。
>
> “start transaction with consistent snapshot; ”的意思是从这个语句开始，创建一个持续整个事务的一致性快照
>
> 在读提交隔离级别(RC)下，这个用法就没意义了，等效于普通的 start transaction。

因为以上案例是RR(start transaction with consistent snapshot;), 也就是可重复读隔离级别。

那么事务B select到的K是3，因为事务C已提交，事务B update的时候不会等锁了，同时update必须要做当前读，这是因为update不做当前读而是可重复性读的话读到的K是1，这样覆盖了事务C的提交！也就是更新数据伴随的是当前读。

事务A开始在事务C之前， 而select是可重复性读，所以事务C提交了但是对A不可见，也就是select要保持可重复性读仍然读到的是1.

如果这个案例改成RC，事务B看到的还是3，事务A看到的就是2了(这个2是事务C提交的)，因为隔离级别是RC。select 执行时间点事务才开始。

#### MySQL和PG事务实现上的差异

这两个数据库对MVCC实现上选择了不同方案，上面讲了MySQL选择的是redo-log去反推多个事务的不同数据，这个方案实现简单。但是PG选择的是保留多个不同的数据版本，优点就是查询不同版本数据效率高，缺点就是对这些数据要做压缩、合并之类的。

## 总结

理解好索引是程序员是否掌握数据库的最关键知识点，理解好索引才会写出更高效的SQL，避免慢查询搞死MySQL。

对日志的理解可以看到一个数据库为了提升性能（刷磁盘的瓶颈）采取的各种手段。也是最重要的一些设计思想所在。

事务则是数据库皇冠。

## 参考资料

https://explainextended.com/2009/10/23/mysql-order-by-limit-performance-late-row-lookups/ 回表

https://stackoverflow.com/questions/1243952/how-can-i-speed-up-a-mysql-query-with-a-large-offset-in-the-limit-clause

