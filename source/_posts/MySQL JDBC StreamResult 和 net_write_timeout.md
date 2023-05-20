---
title: MySQL JDBC StreamResult 和 net_write_timeout
date: 2020-07-03 17:30:03
categories:
    - MySQL
tags:
    - MySQL
    - JDBC
    - stream
    - net_write_timeout
    - timeout
---

# MySQL JDBC StreamResult 和 net_write_timeout

## MySQL JDBC 拉取数据的三种方式

MySQL JDBC 在从 MySQL 拉取数据的时候有三种方式：

1. 简单模式，也就是默认模式，数据都先要从MySQL Server发到client的OS TCP buffer，然后JDBC把 OS buffer读取到JVM内存中，读取到JVM内存的过程中憋着不让client读取，全部读完再通知inputStream.read(). 数据大的话容易导致JVM OOM
2. **useCursorFetch=true**，配合FetchSize，也就是MySQL Server把查到的数据先缓存到本地磁盘，然后按照FetchSize挨个发给client。这需要占用MySQL很高的IOPS（先写磁盘缓存），其次每次Fetch需要一个RTT，效率不高。
3. Stream读取，Stream读取是在执行SQL前设置FetchSize：statement.setFetchSize(Integer.MIN_VALUE)，同时确保游标是只读、向前滚动的（为游标的默认值），MySQL JDBC内置的操作方法是将Statement强制转换为：com.mysql.jdbc.StatementImpl，调用其方法：enableStreamingResults()，这2者达到的效果是一致的，都是启动Stream流方式读取数据。这个时候MySQL不停地发数据，inputStream.read()不停地读取。一般来说发数据更快些，很快client的OS TCP recv buffer就满了，这时MySQL停下来等buffer有空闲就继续发数据。等待过程中如果超过 net_write_timeout MySQL就会报错，中断这次查询。

从这里的描述来看，数据小的时候第一种方式还能接受，但是数据大了容易OOM，方式三看起来不错，但是要特别注意 net_write_timeout。

1和3对MySQL Server来说处理上没有啥区别，也感知不到这两种方式的不同。只是对1来说从OS Buffer中的数据复制到JVM内存中速度快，JVM攒多了数据内存就容易爆掉；对3来说JDBC一条条将OS Buffer中的数据复制到JVM(内存复制速度快)同时返回给execute挨个处理（慢），一般来说挨个处理要慢一些，这就导致了从OS Buffer中复制数据较慢，容易导致 TCP Receive Buffer满了，那么MySQL Server感知到的就是TCP 传输窗口为0了，导致暂停传输数据。

在数据量很小的时候方式三没什么优势，因为总是多一次set net_write_tiemout，也就是多了一次RTT。

![img](/images/951413iMgBlog/70.png)

## [MySQL timeout](https://www.cubrid.org/blog/3826470)

1. Creates a statement by calling `Connection.createStatement()`.
2. Calls `Statement.executeQuery()`.
3. The statement transmits the Query to MySqlServer by using the internal connection.
4. The statement creates a new timeout-execution thread for timeout process.
5. For version 5.1.x, it changes to assign 1 thread for each connection.
6. Registers the timeout execution to the thread.
7. Timeout occurs.
8. The timeout-execution thread creates a connection that has the same configurations as the statement.
9. Transmits the cancel Query (KILL QUERY "connectionId“) by using the connection.

![Figure 6: QueryTimeout Execution Process for MySQL JDBC Statement (5.0.8).](/images/951413iMgBlog/1f6df479e83fd2c14ecac4ee6be64a29.png)

## net_read_timeout

| Command-Line Format | `--net-read-timeout=#` |
| :------------------ | ---------------------- |
| System Variable     | `net_read_timeout`     |
| Scope               | Global, Session        |
| Dynamic             | Yes                    |
| Type                | Integer                |
| Default Value       | `30`                   |
| Minimum Value       | `1`                    |
| Maximum Value       | `31536000`             |
| Unit                | seconds                |

The number of seconds to wait for more data from a connection before aborting the read. When the server is reading from the client, [`net_read_timeout`](https://dev.mysql.com/doc/refman/5.7/en/server-system-variables.html#sysvar_net_read_timeout) is the timeout value controlling when to abort.

如下图，MySQL Server监听3017端口，195228号包 客户端发一个SQL 给 MySQL Server，但是似乎这个时候正好网络异常，30秒钟后（从 SQL 请求的前一个 ack 开始算，Server应该一直都没有收到），Server 端触发 net_read_timeout 超时异常（疑问：这里没有 net_read_timeout 描述的读取了一半的现象）

![image-20230209155545142](/images/951413iMgBlog/image-20230209155545142.png)

解决方案：建议调大 net_read_timeout 以应对可能出现的网络丢包

## net_write_timeout

先看下 [`net_write_timeout`](https://dev.mysql.com/doc/refman/5.7/en/server-system-variables.html#sysvar_net_write_timeout)的解释：The number of seconds to wait for a block to be written to a connection before aborting the write. 只针对执行查询中的等待超时，网络不好，tcp buffer满了（应用迟迟不读走数据）等容易导致mysql server端报net_write_timeout错误，指的是mysql server hang在那里长时间无法发送查询结果。

| Property            | Value                   |
| ------------------- | ----------------------- |
| Command-Line Format | `--net-write-timeout=#` |
| System Variable     | `net_write_timeout`     |
| Scope               | Global, Session         |
| Dynamic             | Yes                     |
| Type                | Integer                 |
| Default Value       | `60`                    |
| Minimum Value       | `1`                     |

> **案例**：DRDS 到 MySQL 多个分片拉取数据生成了许多 cursor 并发执行,但拉数据的时候是串行拉取的,如果用户端拉取数据过慢会导致最后一个 cursor 执行完成之后要等待很久.会超过 MySQL 的 net_write_timeout 配置从而引发报错. 也就是最后一个cursor打开后一直没有去读取数据，直到MySQL  Server 触发 net_write_timeout 异常
>
> 首先可以尝试在 DRDS jdbcurl 配置 netTimeoutForStreamingResults 参数,设置为 0 可以使其一直等待,或设置一个合理的值(秒).

从JDBC驱动中可以看到，当调用PreparedStatement的executeQuery() 方法的时候，如果我们是去获取流式resultset的话，就会默认执行SET net_write_timeout= ？ 这个命令去重新设置timeout时间。源代码如下：

```
if (doStreaming && this.connection.getNetTimeoutForStreamingResults() > 0) {  
            java.sql.Statement stmt = null;  
            try {  
                stmt = this.connection.createStatement();                    ((com.mysql.jdbc.StatementImpl)stmt).executeSimpleNonQuery(this.connection, "SET net_write_timeout="   
                        + this.connection.getNetTimeoutForStreamingResults());  
            } finally {  
                if (stmt != null) {  
                    stmt.close();  
                }  
            }  
        }  
```

而 this.connection.getNetTimeoutForStreamingResults() 默认是600秒，或者在JDBC连接串种通过属性 netTimeoutForStreamingResults 来指定。

netTimeoutForStreamingResults 默认值：

What value should the driver automatically set the server setting 'net_write_timeout' to when the streaming result sets feature is in use? Value has unit of seconds, the value "0" means the driver will not try and adjust this value.

| Default Value | 600   |
| :------------ | ----- |
| Since Version | 5.1.0 |

一般在数据导出场景中容易出现 net_write_timeout 这个错误，比如这个错误堆栈：

![](/images/oss/8fe715d3ebb6929afecd19aadbe53e5e.png)

或者：

```
ErrorMessage:
Code:[DBUtilErrorCode-07], Description:[读取数据库数据失败. 请检查您的配置的 column/table/where/querySql或者向 DBA 寻求帮助.].  - 执行的SQL为:/*+TDDL({'extra':{'MERGE_UNION':'false'},'type':'direct','vtab':'C_CONS','dbid':'EASDB_1514548807024CGYFEASDB_ROQH_0005_RDS','realtabs':['C_CONS']})*/select CONS_ID,CUST_ID,USERFLAG,CONS_NO,CONS_NAME,CUST_QUERY_NO,TMP_PAY_RELA_NO,ORGN_CONS_NO,CONS_SORT_CODE,ELEC_ADDR,TRADE_CODE,ELEC_TYPE_CODE,CONTRACT_CAP,RUN_CAP,SHIFT_NO,LODE_ATTR_CODE,VOLT_CODE,HEC_INDUSTRY_CODE,HOLIDAY,BUILD_DATE,PS_DATE,CANCEL_DATE,DUE_DATE,NOTIFY_MODE,SETTLE_MODE,STATUS_CODE,ORG_NO,RRIO_CODE,CHK_CYCLE,LAST_CHK_DATE,CHECKER_NO,POWEROFF_CODE,TRANSFER_CODE,MR_SECT_NO,NOTE_TYPE_CODE,TMP_FLAG,TMP_DATE,DATA_SRC,USER_EATTR,SHARD_NO,INSERT_TIME from C_CONS  具体错误信息为：Communications link failure
The last packet successfully received from the server was 7 milliseconds ago.  The last packet sent successfully to the server was 709,806 milliseconds ago. - com.mysql.jdbc.exceptions.jdbc4.CommunicationsException: Communications link failure
The last packet successfully received from the server was 7 milliseconds ago.  The last packet sent successfully to the server was 709,806 milliseconds ago.
	at sun.reflect.NativeConstructorAccessorImpl.newInstance0(Native Method)
	at sun.reflect.NativeConstructorAccessorImpl.newInstance(NativeConstructorAccessorImpl.java:62)
	at sun.reflect.DelegatingConstructorAccessorImpl.newInstance(DelegatingConstructorAccessorImpl.java:45)
	at java.lang.reflect.Constructor.newInstance(Constructor.java:423)
	at com.mysql.jdbc.Util.handleNewInstance(Util.java:377)
	at com.mysql.jdbc.SQLError.createCommunicationsException(SQLError.java:1036)
	at com.mysql.jdbc.MysqlIO.reuseAndReadPacket(MysqlIO.java:3427)
	at com.mysql.jdbc.MysqlIO.reuseAndReadPacket(MysqlIO.java:3327)
	at com.mysql.jdbc.MysqlIO.checkErrorPacket(MysqlIO.java:3814)
	at com.mysql.jdbc.MysqlIO.checkErrorPacket(MysqlIO.java:870)
	at com.mysql.jdbc.MysqlIO.nextRow(MysqlIO.java:1928)
	at com.mysql.jdbc.RowDataDynamic.nextRecord(RowDataDynamic.java:378)
	at com.mysql.jdbc.RowDataDynamic.next(RowDataDynamic.java:358)
	at com.mysql.jdbc.ResultSetImpl.next(ResultSetImpl.java:6337)
	at com.alibaba.datax.plugin.rdbms.reader.CommonRdbmsReader$Task.startRead(CommonRdbmsReader.java:275)
	at com.alibaba.datax.plugin.reader.drdsreader.DrdsReader$Task.startRead(DrdsReader.java:148)
	at com.alibaba.datax.core.taskgroup.runner.ReaderRunner.run(ReaderRunner.java:62)
	at java.lang.Thread.run(Thread.java:834)
Caused by: java.io.EOFException: Can not read response from server. Expected to read 258 bytes, read 54 bytes before connection was unexpectedly lost.
	at com.mysql.jdbc.MysqlIO.readFully(MysqlIO.java:2914)
	at com.mysql.jdbc.MysqlIO.reuseAndReadPacket(MysqlIO.java:3387)
	... 11 more
```

### 特别注意

JDBC驱动报如下错误

> Application was streaming results when the connection failed. Consider raising value of 'net_write_timeout' on the server. - com.mysql.jdbc.exceptions.jdbc4.CommunicationsException: Application was streaming results when the connection failed. Consider raising value of 'net_write_timeout' on the server.  

不一定是 `net_write_timeout` 设置过小导致的，JDBC 在 streaming 流模式下只要连接异常就会报如上错误，比如：

- 连接被 TCP reset
- 连接因为某种原因(比如 QueryTimeOut) 触发 kill Query导致连接中断

[比如出现内核bug，内核卡死不发包的话，客户端同样报 net_write_timeout 错误](https://plantegg.github.io/2022/10/10/Linux%20BUG%E5%86%85%E6%A0%B8%E5%AF%BC%E8%87%B4%E7%9A%84%20TCP%E8%BF%9E%E6%8E%A5%E5%8D%A1%E6%AD%BB/)

## 一些其他的 Timeout

connectTimeout：表示等待和MySQL数据库建立socket链接的超时时间，默认值0，表示不设置超时，单位毫秒，建议30000。 JDBC驱动连接属性

socketTimeout：JDBC参数，表示客户端发送请求给MySQL数据库后block在read的等待数据的超时时间，linux系统默认的socketTimeout为30分钟，可以不设置。要特别注意socketTimeout仅仅是指等待socket数据时间，如果在传输数据那么这个值就没有用了。[socketTimeout通过mysql-connector中的NativeProtocol最终设置在socketOptions上](https://docs.oracle.com/javase/7/docs/api/java/net/SocketOptions.html#SO_TIMEOUT)

![image-20211024171459127](/images/951413iMgBlog/image-20211024171459127.png)

> static final int SO_TIMEOUT。 **Set a timeout on blocking Socket operations**:
>
>  ServerSocket.accept();
>  SocketInputStream.read();
>  DatagramSocket.receive();
>
> The option must be set prior to entering a blocking operation to take effect. If the timeout expires and the operation would continue to block, **java.io.InterruptedIOException** is raised. The Socket is not closed in this case.

Statement Timeout：用来限制statement的执行时长，timeout的值通过调用JDBC的java.sql.Statement.setQueryTimeout(int timeout) API进行设置。不过现在开发者已经很少直接在代码中设置，而多是通过框架来进行设置。

[`max_execution_time`](https://dev.mysql.com/doc/refman/5.7/en/server-system-variables.html#sysvar_max_execution_time)：The execution timeout for [`SELECT`](https://dev.mysql.com/doc/refman/5.7/en/select.html) statements, in milliseconds. If the value is 0, timeouts are not enabled.  MySQL 属性，可以set修改，一般用来设置一个查询最长不超过多少秒，避免一个慢查询一直在跑，跟statement timeout对应。

| Property            | Value                    |
| ------------------- | ------------------------ |
| Command-Line Format | `--max-execution-time=#` |
| System Variable     | `max_execution_time`     |
| Scope               | Global, Session          |
| Dynamic             | Yes                      |
| Type                | Integer                  |
| Default Value       | `0`                      |

[`wait_timeout`](https://dev.mysql.com/doc/refman/5.7/en/server-system-variables.html#sysvar_wait_timeout) The number of seconds the server waits for activity on a noninteractive connection before closing it. MySQL 属性，一般设置tcp keepalive后这个值基本不会超时（这句话存疑 202110）。

On thread startup, the session [`wait_timeout`](https://dev.mysql.com/doc/refman/5.7/en/server-system-variables.html#sysvar_wait_timeout) value is initialized from the global [`wait_timeout`](https://dev.mysql.com/doc/refman/5.7/en/server-system-variables.html#sysvar_wait_timeout) value or from the global [`interactive_timeout`](https://dev.mysql.com/doc/refman/5.7/en/server-system-variables.html#sysvar_interactive_timeout) value, depending on the type of client (as defined by the `CLIENT_INTERACTIVE` connect option to [`mysql_real_connect()`](https://dev.mysql.com/doc/refman/5.7/en/mysql-real-connect.html)). See also [`interactive_timeout`](https://dev.mysql.com/doc/refman/5.7/en/server-system-variables.html#sysvar_interactive_timeout).

| Property                | Value              |
| ----------------------- | ------------------ |
| Command-Line Format     | `--wait-timeout=#` |
| System Variable         | `wait_timeout`     |
| Scope                   | Global, Session    |
| Dynamic                 | Yes                |
| Type                    | Integer            |
| Default Value           | `28800`            |
| Minimum Value           | `1`                |
| Maximum Value (Other)   | `31536000`         |
| Maximum Value (Windows) | `2147483`          |

一般来说应该设置： max_execution_time/statement timeout < Tranction Timeout < socketTimeout

## 案例

设置JDBC参数不合理（不设置的话默认值是：queryTimeout=10s，socketTimeout=10s），会导致在异常情况下，第二条get获得了第一条的结果，拿到了错误的数据，数据库则表现正常

socketTimeout触发后，连接抛CommunicationsException（严重异常，触发后连接应该断开）, 但JDBC会检查请求是否被cancle了，如果cancle就会抛出MySQLTimeoutException异常，这是一个普通异常，连接会被重新放回连接池重用（导致下一个获取这个连接的线程可能会得到前一个请求的response）。

queryTimeout（queryTimeoutKillsConnection=True--来强制关闭连接）会触发启动一个新的连接向server发送 kill id的命令，**MySQL5.7增加了max_statement_time/max_execution_time来做到在server上直接检测到这种查询，然后结束掉**。

### jdbc 和 dn间 socket_timeout

jdbc驱动设置socketTimeout=1459，如果是socketTimeout触发客户端断开后，server端的SQL会继续执行，如果是client被kill则server端的SQL会被终止

```
# java -cp /home/admin/drds-server/lib/*:. Test "jdbc:mysql://172.16.40.215:3008/bank_000000?socketTimeout=1459" "user" "pass" "select sleep(2)" "1"
com.mysql.jdbc.exceptions.jdbc4.CommunicationsException: Communications link failure

The last packet successfully received from the server was 1,461 milliseconds ago.  The last packet sent successfully to the server was 1,461 milliseconds ago.
	at sun.reflect.NativeConstructorAccessorImpl.newInstance0(Native Method)
	at sun.reflect.NativeConstructorAccessorImpl.newInstance(NativeConstructorAccessorImpl.java:80)
	at sun.reflect.DelegatingConstructorAccessorImpl.newInstance(DelegatingConstructorAccessorImpl.java:45)
	at java.lang.reflect.Constructor.newInstance(Constructor.java:423)
	at com.mysql.jdbc.Util.handleNewInstance(Util.java:425)
	at com.mysql.jdbc.SQLError.createCommunicationsException(SQLError.java:989)
	at com.mysql.jdbc.MysqlIO.reuseAndReadPacket(MysqlIO.java:3749)
	at com.mysql.jdbc.MysqlIO.reuseAndReadPacket(MysqlIO.java:3649)
	at com.mysql.jdbc.MysqlIO.checkErrorPacket(MysqlIO.java:4090)
	at com.mysql.jdbc.MysqlIO.sendCommand(MysqlIO.java:2658)
	at com.mysql.jdbc.MysqlIO.sqlQueryDirect(MysqlIO.java:2811)
	at com.mysql.jdbc.ConnectionImpl.execSQL(ConnectionImpl.java:2806)
	at com.mysql.jdbc.ConnectionImpl.execSQL(ConnectionImpl.java:2764)
	at com.mysql.jdbc.StatementImpl.executeQuery(StatementImpl.java:1399)
	at Test.main(Test.java:29)
Caused by: java.net.SocketTimeoutException: Read timed out
	at java.net.SocketInputStream.socketRead0(Native Method)
	at java.net.SocketInputStream.socketRead(SocketInputStream.java:116)
	at java.net.SocketInputStream.read(SocketInputStream.java:171)
	at java.net.SocketInputStream.read(SocketInputStream.java:141)
	at com.mysql.jdbc.util.ReadAheadInputStream.fill(ReadAheadInputStream.java:101)
	at com.mysql.jdbc.util.ReadAheadInputStream.readFromUnderlyingStreamIfNecessary(ReadAheadInputStream.java:144)
	at com.mysql.jdbc.util.ReadAheadInputStream.read(ReadAheadInputStream.java:174)
	at com.mysql.jdbc.MysqlIO.readFully(MysqlIO.java:3183)
	at com.mysql.jdbc.MysqlIO.reuseAndReadPacket(MysqlIO.java:3659)
	... 8 more
	
	或者开协程后的错误堆栈
	# java  -XX:+UseWisp2 -cp /home/admin/drds-server/lib/*:. Test "jdbc:mysql://172.16.40.215:3008/bank_000000?socketTimeout=1459" "user" "pass" "select sleep(2)" "1"
com.mysql.jdbc.exceptions.jdbc4.CommunicationsException: Communications link failure

The last packet successfully received from the server was 1,460 milliseconds ago.  The last packet sent successfully to the server was 1,459 milliseconds ago.
	at sun.reflect.NativeConstructorAccessorImpl.newInstance0(Native Method)
	at sun.reflect.NativeConstructorAccessorImpl.newInstance(NativeConstructorAccessorImpl.java:80)
	at sun.reflect.DelegatingConstructorAccessorImpl.newInstance(DelegatingConstructorAccessorImpl.java:45)
	at java.lang.reflect.Constructor.newInstance(Constructor.java:423)
	at com.mysql.jdbc.Util.handleNewInstance(Util.java:425)
	at com.mysql.jdbc.SQLError.createCommunicationsException(SQLError.java:989)
	at com.mysql.jdbc.MysqlIO.reuseAndReadPacket(MysqlIO.java:3749)
	at com.mysql.jdbc.MysqlIO.reuseAndReadPacket(MysqlIO.java:3649)
	at com.mysql.jdbc.MysqlIO.checkErrorPacket(MysqlIO.java:4090)
	at com.mysql.jdbc.MysqlIO.sendCommand(MysqlIO.java:2658)
	at com.mysql.jdbc.MysqlIO.sqlQueryDirect(MysqlIO.java:2811)
	at com.mysql.jdbc.ConnectionImpl.execSQL(ConnectionImpl.java:2806)
	at com.mysql.jdbc.ConnectionImpl.execSQL(ConnectionImpl.java:2764)
	at com.mysql.jdbc.StatementImpl.executeQuery(StatementImpl.java:1399)
	at Test.main(Test.java:29)
Caused by: java.net.SocketTimeoutException: time out
	at sun.nio.ch.WispSocketImpl$1$1.read0(WispSocketImpl.java:244)
	at sun.nio.ch.WispSocketImpl$1$1.read(WispSocketImpl.java:208)
	at sun.nio.ch.WispSocketImpl$1$1.read(WispSocketImpl.java:201)
	at com.mysql.jdbc.util.ReadAheadInputStream.fill(ReadAheadInputStream.java:101)
	at com.mysql.jdbc.util.ReadAheadInputStream.readFromUnderlyingStreamIfNecessary(ReadAheadInputStream.java:144)
	at com.mysql.jdbc.util.ReadAheadInputStream.read(ReadAheadInputStream.java:174)
	at com.mysql.jdbc.MysqlIO.readFully(MysqlIO.java:3183)
	at com.mysql.jdbc.MysqlIO.reuseAndReadPacket(MysqlIO.java:3659)
	... 8 more
```

对应抓包，没有 kill动作

<img src="/images/951413iMgBlog/image-20220601141709318.png" alt="image-20220601141709318" style="zoom:50%;" />

### cn 和 dn 间socket_timeout案例

设置CN到DN的socket_timeout为2秒，然后执行一个sleep

CN上抓包分析(stream 5是客户端到CN、stream6是CN到DN）如下，首先CN会计时2秒钟后发送quit给DN，然后断开和DN的连接，然后返回一个错误给client，client发送quit断开连接：

<img src="/images/951413iMgBlog/image-20220601122556415.png" alt="image-20220601122556415" style="zoom:50%;" />

CN完整报错堆栈：

```
2022-06-01 12:10:00.178 [ServerExecutor-bucket-2-19-thread-181] ERROR com.alibaba.druid.pool.DruidPooledStatement - [user=polardbx_root,host=10.101.32.6,port=43947,schema=bank] CommunicationsException, druid version 1.1.24, jdbcUrl : jdbc:mysql://172.16.40.215:3008/bank_000000?maintainTimeStats=false&rewriteBatchedStatements=false&failOverReadOnly=false&cacheResultSetMetadata=true&allowMultiQueries=true&clobberStreamingResults=true&autoReconnect=false&usePsMemOptimize=true&useServerPrepStmts=true&netTimeoutForStreamingResults=0&useSSL=false&metadataCacheSize=256&readOnlyPropagatesToServer=false&prepStmtCacheSqlLimit=4096&connectTimeout=5000&socketTimeout=9000000&cachePrepStmts=true&characterEncoding=utf8&prepStmtCacheSize=256, testWhileIdle true, idle millis 11861, minIdle 5, poolingCount 4, timeBetweenEvictionRunsMillis 60000, lastValidIdleMillis 11861, driver com.mysql.jdbc.Driver, exceptionSorter com.alibaba.polardbx.common.jdbc.sorter.MySQLExceptionSorter
2022-06-01 12:10:00.179 [ServerExecutor-bucket-2-19-thread-181] ERROR com.alibaba.druid.pool.DruidDataSource - [user=polardbx_root,host=10.101.32.6,port=43947,schema=bank] discard connection
com.mysql.jdbc.exceptions.jdbc4.CommunicationsException: Communications link failure
	at sun.reflect.GeneratedConstructorAccessor72.newInstance(Unknown Source)
	at sun.reflect.DelegatingConstructorAccessorImpl.newInstance(DelegatingConstructorAccessorImpl.java:45)
	at java.lang.reflect.Constructor.newInstance(Constructor.java:423)
	at com.mysql.jdbc.Util.handleNewInstance(Util.java:425)
	at com.mysql.jdbc.SQLError.createCommunicationsException(SQLError.java:989)
	at com.mysql.jdbc.MysqlIO.reuseAndReadPacket(MysqlIO.java:3749)
	at com.mysql.jdbc.MysqlIO.reuseAndReadPacket(MysqlIO.java:3649)
	at com.mysql.jdbc.MysqlIO.checkErrorPacket(MysqlIO.java:4090)
	at com.mysql.jdbc.MysqlIO.sendCommand(MysqlIO.java:2658)
	at com.mysql.jdbc.ServerPreparedStatement.serverExecute(ServerPreparedStatement.java:1281)
	at com.mysql.jdbc.ServerPreparedStatement.executeInternal(ServerPreparedStatement.java:782)
	at com.mysql.jdbc.PreparedStatement.execute(PreparedStatement.java:1367)
	at com.alibaba.druid.pool.DruidPooledPreparedStatement.execute(DruidPooledPreparedStatement.java:497)
	at com.alibaba.polardbx.group.jdbc.TGroupDirectPreparedStatement.execute(TGroupDirectPreparedStatement.java:84)
	at com.alibaba.polardbx.repo.mysql.spi.MyJdbcHandler.executeQueryInner(MyJdbcHandler.java:1133)
	at com.alibaba.polardbx.repo.mysql.spi.MyJdbcHandler.executeQuery(MyJdbcHandler.java:990)
	at com.alibaba.polardbx.repo.mysql.spi.MyPhyQueryCursor.doInit(MyPhyQueryCursor.java:83)
	at com.alibaba.polardbx.executor.cursor.AbstractCursor.init(AbstractCursor.java:53)
	at com.alibaba.polardbx.repo.mysql.spi.MyPhyQueryCursor.<init>(MyPhyQueryCursor.java:67)
	at com.alibaba.polardbx.repo.mysql.spi.CursorFactoryMyImpl.repoCursor(CursorFactoryMyImpl.java:42)
	at com.alibaba.polardbx.repo.mysql.handler.MyPhyQueryHandler.handle(MyPhyQueryHandler.java:24)
	at com.alibaba.polardbx.executor.handler.HandlerCommon.handlePlan(HandlerCommon.java:102)
	at com.alibaba.polardbx.executor.AbstractGroupExecutor.executeInner(AbstractGroupExecutor.java:58)
	at com.alibaba.polardbx.executor.AbstractGroupExecutor.execByExecPlanNode(AbstractGroupExecutor.java:36)
	at com.alibaba.polardbx.executor.TopologyExecutor.execByExecPlanNode(TopologyExecutor.java:34)
	at com.alibaba.polardbx.transaction.TransactionExecutor.execByExecPlanNode(TransactionExecutor.java:120)
	at com.alibaba.polardbx.executor.ExecutorHelper.executeByCursor(ExecutorHelper.java:155)
	at com.alibaba.polardbx.executor.ExecutorHelper.execute(ExecutorHelper.java:70)
	at com.alibaba.polardbx.executor.PlanExecutor.execByExecPlanNodeByOne(PlanExecutor.java:130)
	at com.alibaba.polardbx.executor.PlanExecutor.execute(PlanExecutor.java:75)
	at com.alibaba.polardbx.matrix.jdbc.TConnection.executeQuery(TConnection.java:682)
	at com.alibaba.polardbx.matrix.jdbc.TConnection.executeSQL(TConnection.java:457)
	at com.alibaba.polardbx.matrix.jdbc.TPreparedStatement.executeSQL(TPreparedStatement.java:65)
	at com.alibaba.polardbx.matrix.jdbc.TStatement.executeInternal(TStatement.java:133)
	at com.alibaba.polardbx.matrix.jdbc.TPreparedStatement.execute(TPreparedStatement.java:50)
	at com.alibaba.polardbx.server.ServerConnection.innerExecute(ServerConnection.java:1131)
	at com.alibaba.polardbx.server.ServerConnection.execute(ServerConnection.java:883)
	at com.alibaba.polardbx.server.ServerConnection.execute(ServerConnection.java:850)
	at com.alibaba.polardbx.server.ServerConnection.execute(ServerConnection.java:844)
	at com.alibaba.polardbx.server.handler.SelectHandler.handle(SelectHandler.java:82)
	at com.alibaba.polardbx.server.handler.SelectHandler.handle(SelectHandler.java:31)
	at com.alibaba.polardbx.server.ServerQueryHandler.executeSql(ServerQueryHandler.java:155)
	at com.alibaba.polardbx.server.ServerQueryHandler.executeStatement(ServerQueryHandler.java:133)
	at com.alibaba.polardbx.server.ServerQueryHandler.queryRaw(ServerQueryHandler.java:118)
	at com.alibaba.polardbx.net.FrontendConnection.query(FrontendConnection.java:460)
	at com.alibaba.polardbx.net.handler.FrontendCommandHandler.handle(FrontendCommandHandler.java:49)
	at com.alibaba.polardbx.net.FrontendConnection.lambda$handleData$0(FrontendConnection.java:753)
	at com.alibaba.polardbx.common.utils.thread.RunnableWithCpuCollector.run(RunnableWithCpuCollector.java:36)
	at com.alibaba.polardbx.common.utils.thread.ServerThreadPool$RunnableAdapter.run(ServerThreadPool.java:793)
	at java.util.concurrent.Executors$RunnableAdapter.call(Executors.java:511)
	at java.util.concurrent.FutureTask.run(FutureTask.java:266)
	at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1149)
	at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:624)
	at java.lang.Thread.run(Thread.java:874)
	at com.alibaba.wisp.engine.WispTask.runOutsideWisp(WispTask.java:277)
	at com.alibaba.wisp.engine.WispTask.runCommand(WispTask.java:252)
	at com.alibaba.wisp.engine.WispTask.access$100(WispTask.java:33)
	at com.alibaba.wisp.engine.WispTask$CacheableCoroutine.run(WispTask.java:223)
	at java.dyn.CoroutineBase.startInternal(CoroutineBase.java:60)
Caused by: java.net.SocketTimeoutException: time out
	at sun.nio.ch.WispSocketImpl$1$1.read0(WispSocketImpl.java:244)
	at sun.nio.ch.WispSocketImpl$1$1.read(WispSocketImpl.java:208)
	at sun.nio.ch.WispSocketImpl$1$1.read(WispSocketImpl.java:201)
	at com.mysql.jdbc.util.ReadAheadInputStream.fill(ReadAheadInputStream.java:101)
	at com.mysql.jdbc.util.ReadAheadInputStream.readFromUnderlyingStreamIfNecessary(ReadAheadInputStream.java:144)
	at com.mysql.jdbc.util.ReadAheadInputStream.read(ReadAheadInputStream.java:174)
	at com.mysql.jdbc.MysqlIO.readFully(MysqlIO.java:3183)
	at com.mysql.jdbc.MysqlIO.reuseAndReadPacket(MysqlIO.java:3659)
	... 53 common frames omitted
2022-06-01 12:10:00.179 [ServerExecutor-bucket-2-19-thread-181] WARN  com.alibaba.polardbx.repo.mysql.spi.MyJdbcHandler - [user=polardbx_root,host=10.101.32.6,port=43947,schema=bank]  [TDDL] [1461cdf8b2809000]Execute ERROR on GROUP: BANK_000000_GROUP, ATOM: dskey_bank_000000_group#pxc-xdb-s-pxcunrcbmk4g9lcpk0f24#172.16.40.215-3008#bank_000000, MERGE_UNION_SIZE:1, SQL: /*DRDS /10.101.32.6/1461cdf8b2809000/0// */SELECT SLEEP(?) AS `sleep(236)`, PARAM: [236], ERROR: Communications link failure, tddl version: 5.4.13-16522656
com.mysql.jdbc.exceptions.jdbc4.CommunicationsException: Communications link failure
	at sun.reflect.GeneratedConstructorAccessor72.newInstance(Unknown Source)
	at sun.reflect.DelegatingConstructorAccessorImpl.newInstance(DelegatingConstructorAccessorImpl.java:45)
	at java.lang.reflect.Constructor.newInstance(Constructor.java:423)
	at com.mysql.jdbc.Util.handleNewInstance(Util.java:425)
	at com.mysql.jdbc.SQLError.createCommunicationsException(SQLError.java:989)
	at com.mysql.jdbc.MysqlIO.reuseAndReadPacket(MysqlIO.java:3749)
	at com.mysql.jdbc.MysqlIO.reuseAndReadPacket(MysqlIO.java:3649)
	at com.mysql.jdbc.MysqlIO.checkErrorPacket(MysqlIO.java:4090)
	at com.mysql.jdbc.MysqlIO.sendCommand(MysqlIO.java:2658)
	at com.mysql.jdbc.ServerPreparedStatement.serverExecute(ServerPreparedStatement.java:1281)
	at com.mysql.jdbc.ServerPreparedStatement.executeInternal(ServerPreparedStatement.java:782)
	at com.mysql.jdbc.PreparedStatement.execute(PreparedStatement.java:1367)
	at com.alibaba.druid.pool.DruidPooledPreparedStatement.execute(DruidPooledPreparedStatement.java:497)
	at com.alibaba.polardbx.group.jdbc.TGroupDirectPreparedStatement.execute(TGroupDirectPreparedStatement.java:84)
	at com.alibaba.polardbx.repo.mysql.spi.MyJdbcHandler.executeQueryInner(MyJdbcHandler.java:1133)
	at com.alibaba.polardbx.repo.mysql.spi.MyJdbcHandler.executeQuery(MyJdbcHandler.java:990)
	at com.alibaba.polardbx.repo.mysql.spi.MyPhyQueryCursor.doInit(MyPhyQueryCursor.java:83)
	at com.alibaba.polardbx.executor.cursor.AbstractCursor.init(AbstractCursor.java:53)
	at com.alibaba.polardbx.repo.mysql.spi.MyPhyQueryCursor.<init>(MyPhyQueryCursor.java:67)
	at com.alibaba.polardbx.repo.mysql.spi.CursorFactoryMyImpl.repoCursor(CursorFactoryMyImpl.java:42)
	at com.alibaba.polardbx.repo.mysql.handler.MyPhyQueryHandler.handle(MyPhyQueryHandler.java:24)
	at com.alibaba.polardbx.executor.handler.HandlerCommon.handlePlan(HandlerCommon.java:102)
	at com.alibaba.polardbx.executor.AbstractGroupExecutor.executeInner(AbstractGroupExecutor.java:58)
	at com.alibaba.polardbx.executor.AbstractGroupExecutor.execByExecPlanNode(AbstractGroupExecutor.java:36)
	at com.alibaba.polardbx.executor.TopologyExecutor.execByExecPlanNode(TopologyExecutor.java:34)
	at com.alibaba.polardbx.transaction.TransactionExecutor.execByExecPlanNode(TransactionExecutor.java:120)
	at com.alibaba.polardbx.executor.ExecutorHelper.executeByCursor(ExecutorHelper.java:155)
	at com.alibaba.polardbx.executor.ExecutorHelper.execute(ExecutorHelper.java:70)
	at com.alibaba.polardbx.executor.PlanExecutor.execByExecPlanNodeByOne(PlanExecutor.java:130)
	at com.alibaba.polardbx.executor.PlanExecutor.execute(PlanExecutor.java:75)
	at com.alibaba.polardbx.matrix.jdbc.TConnection.executeQuery(TConnection.java:682)
	at com.alibaba.polardbx.matrix.jdbc.TConnection.executeSQL(TConnection.java:457)
	at com.alibaba.polardbx.matrix.jdbc.TPreparedStatement.executeSQL(TPreparedStatement.java:65)
	at com.alibaba.polardbx.matrix.jdbc.TStatement.executeInternal(TStatement.java:133)
	at com.alibaba.polardbx.matrix.jdbc.TPreparedStatement.execute(TPreparedStatement.java:50)
	at com.alibaba.polardbx.server.ServerConnection.innerExecute(ServerConnection.java:1131)
	at com.alibaba.polardbx.server.ServerConnection.execute(ServerConnection.java:883)
	at com.alibaba.polardbx.server.ServerConnection.execute(ServerConnection.java:850)
	at com.alibaba.polardbx.server.ServerConnection.execute(ServerConnection.java:844)
	at com.alibaba.polardbx.server.handler.SelectHandler.handle(SelectHandler.java:82)
	at com.alibaba.polardbx.server.handler.SelectHandler.handle(SelectHandler.java:31)
	at com.alibaba.polardbx.server.ServerQueryHandler.executeSql(ServerQueryHandler.java:155)
	at com.alibaba.polardbx.server.ServerQueryHandler.executeStatement(ServerQueryHandler.java:133)
	at com.alibaba.polardbx.server.ServerQueryHandler.queryRaw(ServerQueryHandler.java:118)
	at com.alibaba.polardbx.net.FrontendConnection.query(FrontendConnection.java:460)
	at com.alibaba.polardbx.net.handler.FrontendCommandHandler.handle(FrontendCommandHandler.java:49)
	at com.alibaba.polardbx.net.FrontendConnection.lambda$handleData$0(FrontendConnection.java:753)
	at com.alibaba.polardbx.common.utils.thread.RunnableWithCpuCollector.run(RunnableWithCpuCollector.java:36)
	at com.alibaba.polardbx.common.utils.thread.ServerThreadPool$RunnableAdapter.run(ServerThreadPool.java:793)
	at java.util.concurrent.Executors$RunnableAdapter.call(Executors.java:511)
	at java.util.concurrent.FutureTask.run(FutureTask.java:266)
	at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1149)
	at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:624)
	at java.lang.Thread.run(Thread.java:874)
	at com.alibaba.wisp.engine.WispTask.runOutsideWisp(WispTask.java:277)
	at com.alibaba.wisp.engine.WispTask.runCommand(WispTask.java:252)
	at com.alibaba.wisp.engine.WispTask.access$100(WispTask.java:33)
	at com.alibaba.wisp.engine.WispTask$CacheableCoroutine.run(WispTask.java:223)
	at java.dyn.CoroutineBase.startInternal(CoroutineBase.java:60)
Caused by: java.net.SocketTimeoutException: time out
	at sun.nio.ch.WispSocketImpl$1$1.read0(WispSocketImpl.java:244)
	at sun.nio.ch.WispSocketImpl$1$1.read(WispSocketImpl.java:208)
	at sun.nio.ch.WispSocketImpl$1$1.read(WispSocketImpl.java:201)
	at com.mysql.jdbc.util.ReadAheadInputStream.fill(ReadAheadInputStream.java:101)
	at com.mysql.jdbc.util.ReadAheadInputStream.readFromUnderlyingStreamIfNecessary(ReadAheadInputStream.java:144)
	at com.mysql.jdbc.util.ReadAheadInputStream.read(ReadAheadInputStream.java:174)
	at com.mysql.jdbc.MysqlIO.readFully(MysqlIO.java:3183)
	at com.mysql.jdbc.MysqlIO.reuseAndReadPacket(MysqlIO.java:3659)
	... 53 common frames omitted
2022-06-01 12:10:00.179 [ServerExecutor-bucket-2-19-thread-181] WARN  com.alibaba.polardbx.repo.mysql.spi.MyJdbcHandler - [user=polardbx_root,host=10.101.32.6,port=43947,schema=bank]  [TDDL] Reset conn socketTimeout failed, lastSocketTimeout is 9000000, tddl version: 5.4.13-16522656
com.mysql.jdbc.exceptions.jdbc4.MySQLNonTransientConnectionException: No operations allowed after connection closed.
	at sun.reflect.NativeConstructorAccessorImpl.newInstance0(Native Method)
	at sun.reflect.NativeConstructorAccessorImpl.newInstance(NativeConstructorAccessorImpl.java:80)
	at sun.reflect.DelegatingConstructorAccessorImpl.newInstance(DelegatingConstructorAccessorImpl.java:45)
	at java.lang.reflect.Constructor.newInstance(Constructor.java:423)
	at com.mysql.jdbc.Util.handleNewInstance(Util.java:425)
	at com.mysql.jdbc.Util.getInstance(Util.java:408)
	at com.mysql.jdbc.SQLError.createSQLException(SQLError.java:918)
	at com.mysql.jdbc.SQLError.createSQLException(SQLError.java:897)
	at com.mysql.jdbc.SQLError.createSQLException(SQLError.java:886)
	at com.mysql.jdbc.SQLError.createSQLException(SQLError.java:860)
	at com.mysql.jdbc.ConnectionImpl.throwConnectionClosedException(ConnectionImpl.java:1326)
	at com.mysql.jdbc.ConnectionImpl.checkClosed(ConnectionImpl.java:1321)
	at com.mysql.jdbc.ConnectionImpl.setNetworkTimeout(ConnectionImpl.java:5888)
	at com.alibaba.polardbx.atom.utils.NetworkUtils.setNetworkTimeout(NetworkUtils.java:18)
	at com.alibaba.polardbx.group.jdbc.TGroupDirectConnection.setNetworkTimeout(TGroupDirectConnection.java:433)
	at com.alibaba.polardbx.repo.mysql.spi.MyJdbcHandler.resetPhyConnSocketTimeout(MyJdbcHandler.java:721)
	at com.alibaba.polardbx.repo.mysql.spi.MyJdbcHandler.executeQueryInner(MyJdbcHandler.java:1173)
	at com.alibaba.polardbx.repo.mysql.spi.MyJdbcHandler.executeQuery(MyJdbcHandler.java:990)
	at com.alibaba.polardbx.repo.mysql.spi.MyPhyQueryCursor.doInit(MyPhyQueryCursor.java:83)
	at com.alibaba.polardbx.executor.cursor.AbstractCursor.init(AbstractCursor.java:53)
	at com.alibaba.polardbx.repo.mysql.spi.MyPhyQueryCursor.<init>(MyPhyQueryCursor.java:67)
	at com.alibaba.polardbx.repo.mysql.spi.CursorFactoryMyImpl.repoCursor(CursorFactoryMyImpl.java:42)
	at com.alibaba.polardbx.repo.mysql.handler.MyPhyQueryHandler.handle(MyPhyQueryHandler.java:24)
	at com.alibaba.polardbx.executor.handler.HandlerCommon.handlePlan(HandlerCommon.java:102)
	at com.alibaba.polardbx.executor.AbstractGroupExecutor.executeInner(AbstractGroupExecutor.java:58)
	at com.alibaba.polardbx.executor.AbstractGroupExecutor.execByExecPlanNode(AbstractGroupExecutor.java:36)
	at com.alibaba.polardbx.executor.TopologyExecutor.execByExecPlanNode(TopologyExecutor.java:34)
	at com.alibaba.polardbx.transaction.TransactionExecutor.execByExecPlanNode(TransactionExecutor.java:120)
	at com.alibaba.polardbx.executor.ExecutorHelper.executeByCursor(ExecutorHelper.java:155)
	at com.alibaba.polardbx.executor.ExecutorHelper.execute(ExecutorHelper.java:70)
	at com.alibaba.polardbx.executor.PlanExecutor.execByExecPlanNodeByOne(PlanExecutor.java:130)
	at com.alibaba.polardbx.executor.PlanExecutor.execute(PlanExecutor.java:75)
	at com.alibaba.polardbx.matrix.jdbc.TConnection.executeQuery(TConnection.java:682)
	at com.alibaba.polardbx.matrix.jdbc.TConnection.executeSQL(TConnection.java:457)
	at com.alibaba.polardbx.matrix.jdbc.TPreparedStatement.executeSQL(TPreparedStatement.java:65)
	at com.alibaba.polardbx.matrix.jdbc.TStatement.executeInternal(TStatement.java:133)
	at com.alibaba.polardbx.matrix.jdbc.TPreparedStatement.execute(TPreparedStatement.java:50)
	at com.alibaba.polardbx.server.ServerConnection.innerExecute(ServerConnection.java:1131)
	at com.alibaba.polardbx.server.ServerConnection.execute(ServerConnection.java:883)
	at com.alibaba.polardbx.server.ServerConnection.execute(ServerConnection.java:850)
	at com.alibaba.polardbx.server.ServerConnection.execute(ServerConnection.java:844)
	at com.alibaba.polardbx.server.handler.SelectHandler.handle(SelectHandler.java:82)
	at com.alibaba.polardbx.server.handler.SelectHandler.handle(SelectHandler.java:31)
	at com.alibaba.polardbx.server.ServerQueryHandler.executeSql(ServerQueryHandler.java:155)
	at com.alibaba.polardbx.server.ServerQueryHandler.executeStatement(ServerQueryHandler.java:133)
	at com.alibaba.polardbx.server.ServerQueryHandler.queryRaw(ServerQueryHandler.java:118)
	at com.alibaba.polardbx.net.FrontendConnection.query(FrontendConnection.java:460)
	at com.alibaba.polardbx.net.handler.FrontendCommandHandler.handle(FrontendCommandHandler.java:49)
	at com.alibaba.polardbx.net.FrontendConnection.lambda$handleData$0(FrontendConnection.java:753)
	at com.alibaba.polardbx.common.utils.thread.RunnableWithCpuCollector.run(RunnableWithCpuCollector.java:36)
	at com.alibaba.polardbx.common.utils.thread.ServerThreadPool$RunnableAdapter.run(ServerThreadPool.java:793)
	at java.util.concurrent.Executors$RunnableAdapter.call(Executors.java:511)
	at java.util.concurrent.FutureTask.run(FutureTask.java:266)
	at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1149)
	at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:624)
	at java.lang.Thread.run(Thread.java:874)
	at com.alibaba.wisp.engine.WispTask.runOutsideWisp(WispTask.java:277)
	at com.alibaba.wisp.engine.WispTask.runCommand(WispTask.java:252)
	at com.alibaba.wisp.engine.WispTask.access$100(WispTask.java:33)
	at com.alibaba.wisp.engine.WispTask$CacheableCoroutine.run(WispTask.java:223)
	at java.dyn.CoroutineBase.startInternal(CoroutineBase.java:60)
2022-06-01 12:10:00.179 [ServerExecutor-bucket-2-19-thread-181] WARN  com.alibaba.polardbx.executor.ExecutorHelper - [user=polardbx_root,host=10.101.32.6,port=43947,schema=bank]  [TDDL] PhyQuery(node="BANK_000000_GROUP", sql="SELECT SLEEP(?) AS `sleep(236)`")
, tddl version: 5.4.13-16522656
2022-06-01 12:10:00.180 [ServerExecutor-bucket-2-19-thread-181] WARN  com.alibaba.polardbx.server.ServerConnection - [user=polardbx_root,host=10.101.32.6,port=43947,schema=bank]  [TDDL] [ERROR-CODE: 3009][1461cdf8b2809000] SQL:  /*+TDDL:node(0)  and SOCKET_TIMEOUT=2000 */ select sleep(236), tddl version: 5.4.13-16522656
com.alibaba.polardbx.common.exception.TddlRuntimeException: ERR-CODE: [TDDL-4614][ERR_EXECUTE_ON_MYSQL] Error occurs when execute on GROUP 'BANK_000000_GROUP' ATOM 'dskey_bank_000000_group#pxc-xdb-s-pxcunrcbmk4g9lcpk0f24#172.16.40.215-3008#bank_000000': Communications link failure
	at com.alibaba.polardbx.repo.mysql.spi.MyJdbcHandler.handleException(MyJdbcHandler.java:1935)
	at com.alibaba.polardbx.repo.mysql.spi.MyJdbcHandler.generalHandlerException(MyJdbcHandler.java:1911)
	at com.alibaba.polardbx.repo.mysql.spi.MyJdbcHandler.executeQueryInner(MyJdbcHandler.java:1168)
	at com.alibaba.polardbx.repo.mysql.spi.MyJdbcHandler.executeQuery(MyJdbcHandler.java:990)
	at com.alibaba.polardbx.repo.mysql.spi.MyPhyQueryCursor.doInit(MyPhyQueryCursor.java:83)
	at com.alibaba.polardbx.executor.cursor.AbstractCursor.init(AbstractCursor.java:53)
	at com.alibaba.polardbx.repo.mysql.spi.MyPhyQueryCursor.<init>(MyPhyQueryCursor.java:67)
	at com.alibaba.polardbx.repo.mysql.spi.CursorFactoryMyImpl.repoCursor(CursorFactoryMyImpl.java:42)
	at com.alibaba.polardbx.repo.mysql.handler.MyPhyQueryHandler.handle(MyPhyQueryHandler.java:24)
	at com.alibaba.polardbx.executor.handler.HandlerCommon.handlePlan(HandlerCommon.java:102)
	at com.alibaba.polardbx.executor.AbstractGroupExecutor.executeInner(AbstractGroupExecutor.java:58)
	at com.alibaba.polardbx.executor.AbstractGroupExecutor.execByExecPlanNode(AbstractGroupExecutor.java:36)
	at com.alibaba.polardbx.executor.TopologyExecutor.execByExecPlanNode(TopologyExecutor.java:34)
	at com.alibaba.polardbx.transaction.TransactionExecutor.execByExecPlanNode(TransactionExecutor.java:120)
	at com.alibaba.polardbx.executor.ExecutorHelper.executeByCursor(ExecutorHelper.java:155)
	at com.alibaba.polardbx.executor.ExecutorHelper.execute(ExecutorHelper.java:70)
	at com.alibaba.polardbx.executor.PlanExecutor.execByExecPlanNodeByOne(PlanExecutor.java:130)
	at com.alibaba.polardbx.executor.PlanExecutor.execute(PlanExecutor.java:75)
	at com.alibaba.polardbx.matrix.jdbc.TConnection.executeQuery(TConnection.java:682)
	at com.alibaba.polardbx.matrix.jdbc.TConnection.executeSQL(TConnection.java:457)
	at com.alibaba.polardbx.matrix.jdbc.TPreparedStatement.executeSQL(TPreparedStatement.java:65)
	at com.alibaba.polardbx.matrix.jdbc.TStatement.executeInternal(TStatement.java:133)
	at com.alibaba.polardbx.matrix.jdbc.TPreparedStatement.execute(TPreparedStatement.java:50)
	at com.alibaba.polardbx.server.ServerConnection.innerExecute(ServerConnection.java:1131)
	at com.alibaba.polardbx.server.ServerConnection.execute(ServerConnection.java:883)
	at com.alibaba.polardbx.server.ServerConnection.execute(ServerConnection.java:850)
	at com.alibaba.polardbx.server.ServerConnection.execute(ServerConnection.java:844)
	at com.alibaba.polardbx.server.handler.SelectHandler.handle(SelectHandler.java:82)
	at com.alibaba.polardbx.server.handler.SelectHandler.handle(SelectHandler.java:31)
	at com.alibaba.polardbx.server.ServerQueryHandler.executeSql(ServerQueryHandler.java:155)
	at com.alibaba.polardbx.server.ServerQueryHandler.executeStatement(ServerQueryHandler.java:133)
	at com.alibaba.polardbx.server.ServerQueryHandler.queryRaw(ServerQueryHandler.java:118)
	at com.alibaba.polardbx.net.FrontendConnection.query(FrontendConnection.java:460)
	at com.alibaba.polardbx.net.handler.FrontendCommandHandler.handle(FrontendCommandHandler.java:49)
	at com.alibaba.polardbx.net.FrontendConnection.lambda$handleData$0(FrontendConnection.java:753)
	at com.alibaba.polardbx.common.utils.thread.RunnableWithCpuCollector.run(RunnableWithCpuCollector.java:36)
	at com.alibaba.polardbx.common.utils.thread.ServerThreadPool$RunnableAdapter.run(ServerThreadPool.java:793)
	at java.util.concurrent.Executors$RunnableAdapter.call(Executors.java:511)
	at java.util.concurrent.FutureTask.run(FutureTask.java:266)
	at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1149)
	at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:624)
	at java.lang.Thread.run(Thread.java:874)
	at com.alibaba.wisp.engine.WispTask.runOutsideWisp(WispTask.java:277)
	at com.alibaba.wisp.engine.WispTask.runCommand(WispTask.java:252)
	at com.alibaba.wisp.engine.WispTask.access$100(WispTask.java:33)
	at com.alibaba.wisp.engine.WispTask$CacheableCoroutine.run(WispTask.java:223)
	at java.dyn.CoroutineBase.startInternal(CoroutineBase.java:60)
Caused by: com.mysql.jdbc.exceptions.jdbc4.CommunicationsException: Communications link failure
	at sun.reflect.GeneratedConstructorAccessor72.newInstance(Unknown Source)
	at sun.reflect.DelegatingConstructorAccessorImpl.newInstance(DelegatingConstructorAccessorImpl.java:45)
	at java.lang.reflect.Constructor.newInstance(Constructor.java:423)
	at com.mysql.jdbc.Util.handleNewInstance(Util.java:425)
	at com.mysql.jdbc.SQLError.createCommunicationsException(SQLError.java:989)
	at com.mysql.jdbc.MysqlIO.reuseAndReadPacket(MysqlIO.java:3749)
	at com.mysql.jdbc.MysqlIO.reuseAndReadPacket(MysqlIO.java:3649)
	at com.mysql.jdbc.MysqlIO.checkErrorPacket(MysqlIO.java:4090)
	at com.mysql.jdbc.MysqlIO.sendCommand(MysqlIO.java:2658)
	at com.mysql.jdbc.ServerPreparedStatement.serverExecute(ServerPreparedStatement.java:1281)
	at com.mysql.jdbc.ServerPreparedStatement.executeInternal(ServerPreparedStatement.java:782)
	at com.mysql.jdbc.PreparedStatement.execute(PreparedStatement.java:1367)
	at com.alibaba.druid.pool.DruidPooledPreparedStatement.execute(DruidPooledPreparedStatement.java:497)
	at com.alibaba.polardbx.group.jdbc.TGroupDirectPreparedStatement.execute(TGroupDirectPreparedStatement.java:84)
	at com.alibaba.polardbx.repo.mysql.spi.MyJdbcHandler.executeQueryInner(MyJdbcHandler.java:1133)
	... 44 common frames omitted
Caused by: java.net.SocketTimeoutException: time out
	at sun.nio.ch.WispSocketImpl$1$1.read0(WispSocketImpl.java:244)
	at sun.nio.ch.WispSocketImpl$1$1.read(WispSocketImpl.java:208)
	at sun.nio.ch.WispSocketImpl$1$1.read(WispSocketImpl.java:201)
	at com.mysql.jdbc.util.ReadAheadInputStream.fill(ReadAheadInputStream.java:101)
	at com.mysql.jdbc.util.ReadAheadInputStream.readFromUnderlyingStreamIfNecessary(ReadAheadInputStream.java:144)
	at com.mysql.jdbc.util.ReadAheadInputStream.read(ReadAheadInputStream.java:174)
	at com.mysql.jdbc.MysqlIO.readFully(MysqlIO.java:3183)
	at com.mysql.jdbc.MysqlIO.reuseAndReadPacket(MysqlIO.java:3659)
	... 53 common frames omitted

```



### kill 案例

#### kill mysql client

mysql client连cn执行一个很慢的SQL，然后kill掉mysql client

cn报错：

```
2022-06-01 11:45:59.063 [ServerExecutor-bucket-0-17-thread-158] ERROR com.alibaba.druid.pool.DruidPooledStatement - [user=polardbx_root,host=10.101.32.6,port=50684,schema=bank] CommunicationsException, druid version 1.1.24, jdbcUrl : jdbc:mysql://172.16.40.215:3008/bank_000000?maintainTimeStats=false&rewriteBatchedStatements=false&failOverReadOnly=false&cacheResultSetMetadata=true&allowMultiQueries=true&clobberStreamingResults=true&autoReconnect=false&usePsMemOptimize=true&useServerPrepStmts=true&netTimeoutForStreamingResults=0&useSSL=false&metadataCacheSize=256&readOnlyPropagatesToServer=false&prepStmtCacheSqlLimit=4096&connectTimeout=5000&socketTimeout=9000000&cachePrepStmts=true&characterEncoding=utf8&prepStmtCacheSize=256, testWhileIdle true, idle millis 72028, minIdle 5, poolingCount 4, timeBetweenEvictionRunsMillis 60000, lastValidIdleMillis 345734, driver com.mysql.jdbc.Driver, exceptionSorter com.alibaba.polardbx.common.jdbc.sorter.MySQLExceptionSorter
2022-06-01 11:45:59.064 [ServerExecutor-bucket-0-17-thread-158] ERROR com.alibaba.druid.pool.DruidDataSource - [user=polardbx_root,host=10.101.32.6,port=50684,schema=bank] discard connection
com.mysql.jdbc.exceptions.jdbc4.CommunicationsException: Communications link failure
	at sun.reflect.GeneratedConstructorAccessor72.newInstance(Unknown Source)
	at sun.reflect.DelegatingConstructorAccessorImpl.newInstance(DelegatingConstructorAccessorImpl.java:45)
	at java.lang.reflect.Constructor.newInstance(Constructor.java:423)
	at com.mysql.jdbc.Util.handleNewInstance(Util.java:425)
	…………
	at com.alibaba.wisp.engine.WispTask$CacheableCoroutine.run(WispTask.java:223)
	at java.dyn.CoroutineBase.startInternal(CoroutineBase.java:60)
Caused by: java.net.SocketException: Socket is closed
	at java.net.Socket.getSoTimeout(Socket.java:1291)
	at sun.nio.ch.WispSocketImpl$1$1.read0(WispSocketImpl.java:249)
	at sun.nio.ch.WispSocketImpl$1$1.read(WispSocketImpl.java:208)
	at sun.nio.ch.WispSocketImpl$1$1.read(WispSocketImpl.java:201)
	at com.mysql.jdbc.util.ReadAheadInputStream.fill(ReadAheadInputStream.java:101)
	at com.mysql.jdbc.util.ReadAheadInputStream.readFromUnderlyingStreamIfNecessary(ReadAheadInputStream.java:144)
	at com.mysql.jdbc.util.ReadAheadInputStream.read(ReadAheadInputStream.java:174)
	at com.mysql.jdbc.MysqlIO.readFully(MysqlIO.java:3183)
	at com.mysql.jdbc.MysqlIO.reuseAndReadPacket(MysqlIO.java:3659)
	... 53 common frames omitted
2022-06-01 11:45:59.065 [ServerExecutor-bucket-0-17-thread-158] WARN  com.alibaba.polardbx.repo.mysql.spi.MyJdbcHandler - [user=polardbx_root,host=10.101.32.6,port=50684,schema=bank]  [TDDL] [1461c86bbe809001]Execute ERROR on GROUP: BANK_000000_GROUP, ATOM: dskey_bank_000000_group#pxc-xdb-s-pxcunrcbmk4g9lcpk0f24#172.16.40.215-3008#bank_000000, MERGE_UNION_SIZE:1, SQL: /*DRDS /10.101.32.6/1461c86bbe809001/0// */SELECT SLEEP(?) AS `sleep(236)`, PARAM: [236], ERROR: Communications link failure, tddl version: 5.4.13-16522656
com.mysql.jdbc.exceptions.jdbc4.CommunicationsException: Communications link failure
	at sun.reflect.GeneratedConstructorAccessor72.newInstance(Unknown Source)
	at sun.reflect.DelegatingConstructorAccessorImpl.newInstance(DelegatingConstructorAccessorImpl.java:45)
	at java.lang.reflect.Constructor.newInstance(Constructor.java:423)
…………
	at java.dyn.CoroutineBase.startInternal(CoroutineBase.java:60)
Caused by: java.net.SocketException: Socket is closed
	at java.net.Socket.getSoTimeout(Socket.java:1291)
	at sun.nio.ch.WispSocketImpl$1$1.read0(WispSocketImpl.java:249)
	at sun.nio.ch.WispSocketImpl$1$1.read(WispSocketImpl.java:208)
	at sun.nio.ch.WispSocketImpl$1$1.read(WispSocketImpl.java:201)
	at com.mysql.jdbc.util.ReadAheadInputStream.fill(ReadAheadInputStream.java:101)
	at com.mysql.jdbc.util.ReadAheadInputStream.readFromUnderlyingStreamIfNecessary(ReadAheadInputStream.java:144)
	at com.mysql.jdbc.util.ReadAheadInputStream.read(ReadAheadInputStream.java:174)
	at com.mysql.jdbc.MysqlIO.readFully(MysqlIO.java:3183)
	at com.mysql.jdbc.MysqlIO.reuseAndReadPacket(MysqlIO.java:3659)
	... 53 common frames omitted
2022-06-01 11:45:59.065 [ServerExecutor-bucket-0-17-thread-158] WARN  com.alibaba.polardbx.repo.mysql.spi.MyJdbcHandler - [user=polardbx_root,host=10.101.32.6,port=50684,schema=bank]  [TDDL] Reset conn socketTimeout failed, lastSocketTimeout is 9000000, tddl version: 5.4.13-16522656
com.mysql.jdbc.exceptions.jdbc4.MySQLNonTransientConnectionException: No operations allowed after connection closed.
	at sun.reflect.NativeConstructorAccessorImpl.newInstance0(Native Method)
	at sun.reflect.NativeConstructorAccessorImpl.newInstance(NativeConstructorAccessorImpl.java:80)
	at sun.reflect.DelegatingConstructorAccessorImpl.newInstance(DelegatingConstructorAccessorImpl.java:45)
	at java.lang.reflect.Constructor.newInstance(Constructor.java:423)
…………
	at com.alibaba.wisp.engine.WispTask$CacheableCoroutine.run(WispTask.java:223)
	at java.dyn.CoroutineBase.startInternal(CoroutineBase.java:60)
2022-06-01 11:45:59.065 [ServerExecutor-bucket-0-17-thread-158] WARN  com.alibaba.polardbx.executor.ExecutorHelper - [user=polardbx_root,host=10.101.32.6,port=50684,schema=bank]  [TDDL] PhyQuery(node="BANK_000000_GROUP", sql="SELECT SLEEP(?) AS `sleep(236)`")
, tddl version: 5.4.13-16522656
2022-06-01 11:45:59.066 [ServerExecutor-bucket-0-17-thread-158] ERROR com.alibaba.polardbx.server.ServerConnection - [user=polardbx_root,host=10.101.32.6,port=50684,schema=bank]  [TDDL] Interrupted unexpectedly for 1461c86bbe809001, tddl version: 5.4.13-16522656
java.lang.InterruptedException: null
	at java.util.concurrent.locks.AbstractQueuedSynchronizer.acquireSharedInterruptibly(AbstractQueuedSynchronizer.java:1310)
	at com.alibaba.polardbx.common.utils.BooleanMutex$Sync.innerGet(BooleanMutex.java:136)
	at com.alibaba.polardbx.common.utils.BooleanMutex.get(BooleanMutex.java:53)
	at com.alibaba.polardbx.common.utils.thread.ServerThreadPool.waitByTraceId(ServerThreadPool.java:445)
	at com.alibaba.polardbx.server.ServerConnection.innerExecute(ServerConnection.java:1291)
	……
	at com.alibaba.wisp.engine.WispTask.access$100(WispTask.java:33)
	at com.alibaba.wisp.engine.WispTask$CacheableCoroutine.run(WispTask.java:223)
	at java.dyn.CoroutineBase.startInternal(CoroutineBase.java:60)
2022-06-01 11:45:59.066 [ServerExecutor-bucket-0-17-thread-158] WARN  com.alibaba.polardbx.server.ServerConnection - [user=polardbx_root,host=10.101.32.6,port=50684,schema=bank]  [TDDL] [ERROR-CODE: 3009][1461c86bbe809001] SQL:  /*+TDDL:node(0)  and SOCKET_TIMEOUT=40000 */ select sleep(236), tddl version: 5.4.13-16522656
com.alibaba.polardbx.common.exception.TddlRuntimeException: ERR-CODE: [TDDL-4614][ERR_EXECUTE_ON_MYSQL] Error occurs when execute on GROUP 'BANK_000000_GROUP' ATOM 'dskey_bank_000000_group#pxc-xdb-s-pxcunrcbmk4g9lcpk0f24#172.16.40.215-3008#bank_000000': Communications link failure
	at com.alibaba.polardbx.repo.mysql.spi.MyJdbcHandler.handleException(MyJdbcHandler.java:1935)
	at com.alibaba.polardbx.repo.mysql.spi.MyJdbcHandler.generalHandlerException(MyJdbcHandler.java:1911)
	at com.alibaba.polardbx.repo.mysql.spi.MyJdbcHandler.executeQueryInner(MyJdbcHandler.java:1168)
	at com.alibaba.polardbx.repo.mysql.spi.MyJdbcHandler.executeQuery(MyJdbcHandler.java:990)
	…………
		at com.alibaba.wisp.engine.WispTask$CacheableCoroutine.run(WispTask.java:223)
	at java.dyn.CoroutineBase.startInternal(CoroutineBase.java:60)
Caused by: com.mysql.jdbc.exceptions.jdbc4.CommunicationsException: Communications link failure
	at sun.reflect.GeneratedConstructorAccessor72.newInstance(Unknown Source)
	at sun.reflect.DelegatingConstructorAccessorImpl.newInstance(DelegatingConstructorAccessorImpl.java:45)
	at java.lang.reflect.Constructor.newInstance(Constructor.java:423)
	at com.mysql.jdbc.Util.handleNewInstance(Util.java:425)
	at com.mysql.jdbc.SQLError.createCommunicationsException(SQLError.java:989)
	at com.mysql.jdbc.MysqlIO.reuseAndReadPacket(MysqlIO.java:3749)
	at com.mysql.jdbc.MysqlIO.reuseAndReadPacket(MysqlIO.java:3649)
	at com.mysql.jdbc.MysqlIO.checkErrorPacket(MysqlIO.java:4090)
	at com.mysql.jdbc.MysqlIO.sendCommand(MysqlIO.java:2658)
	at com.mysql.jdbc.ServerPreparedStatement.serverExecute(ServerPreparedStatement.java:1281)
	at com.mysql.jdbc.ServerPreparedStatement.executeInternal(ServerPreparedStatement.java:782)
	at com.mysql.jdbc.PreparedStatement.execute(PreparedStatement.java:1367)
	at com.alibaba.druid.pool.DruidPooledPreparedStatement.execute(DruidPooledPreparedStatement.java:497)
	at com.alibaba.polardbx.group.jdbc.TGroupDirectPreparedStatement.execute(TGroupDirectPreparedStatement.java:84)
	at com.alibaba.polardbx.repo.mysql.spi.MyJdbcHandler.executeQueryInner(MyJdbcHandler.java:1133)
	... 44 common frames omitted
Caused by: java.net.SocketException: Socket is closed
	at java.net.Socket.getSoTimeout(Socket.java:1291)
	at sun.nio.ch.WispSocketImpl$1$1.read0(WispSocketImpl.java:249)
	at sun.nio.ch.WispSocketImpl$1$1.read(WispSocketImpl.java:208)
	at sun.nio.ch.WispSocketImpl$1$1.read(WispSocketImpl.java:201)
	at com.mysql.jdbc.util.ReadAheadInputStream.fill(ReadAheadInputStream.java:101)
	at com.mysql.jdbc.util.ReadAheadInputStream.readFromUnderlyingStreamIfNecessary(ReadAheadInputStream.java:144)
	at com.mysql.jdbc.util.ReadAheadInputStream.read(ReadAheadInputStream.java:174)
	at com.mysql.jdbc.MysqlIO.readFully(MysqlIO.java:3183)
	at com.mysql.jdbc.MysqlIO.reuseAndReadPacket(MysqlIO.java:3659)
	... 53 common frames omitted
2022-06-01 11:45:59.071 [KillExecutor-15-thread-49] WARN  com.alibaba.polardbx.server.ServerConnection - [user=polardbx_root,host=10.101.32.6,port=50684,schema=bank]  [TDDL] Connection Killed, tddl version: 5.4.13-16522656
```

mysqld报错：

```
2022-06-01T11:45:58.915371+08:00 8218735 [Note] Aborted connection 8218735 to db: 'bank_000000' user: 'rds_polardb_x' host: '172.16.40.214' (Got an error reading communication packets)
```

172.16.40.214是客户端IP

抓包看到CN收到mysql client发过来的fin，CN回复fin断开连接

CN会给DN在新的连接上发Kill Query（stream 1596），同时会在原来的连接(stream 583)上发fin，然后原来的连接收到DN的response（被kill），然后CN发reset给DN

<img src="/images/951413iMgBlog/image-20220601120626629.png" alt="image-20220601120626629" style="zoom:50%;" />

下图是sleep 连接的收发包

<img src="/images/951413iMgBlog/image-20220601120417026.png" alt="image-20220601120417026" style="zoom:50%;" />

#### Kill jdbc client

Java jdbc client被kill后没有错误堆栈，kill后触发socket.close(对应client发送fin断开连接），kill后server端SQL也被立即中断

抓包：

<img src="/images/951413iMgBlog/image-20220601143200253.png" alt="image-20220601143200253" style="zoom:50%;" />

server端报错信息：

```
2022-06-01T14:33:52.204848+08:00 8288839 [Note] Aborted connection 8288839 to db: 'bank_000000' user: 'user' host: '172.16.40.214' (Got an error reading communication packets)
```

### Statement timeout 

```
# java  -XX:+UseWisp2 -cp /home/admin/drds-server/lib/*:. Test "jdbc:mysql://172.16.40.215:3008/bank_000000?socketTimeout=5459" "user" "pass" "select sleep(180)" "1" 3
com.mysql.jdbc.exceptions.MySQLTimeoutException: Statement cancelled due to timeout or client request
	at com.mysql.jdbc.StatementImpl.executeQuery(StatementImpl.java:1419)
	at Test.main(Test.java:31)
```

statement会设置一个timer，到时间还没有返回结果就创建一个新连接发送kill query

server 端收到kill后终止SQL执行，抓包看到Server端主动提前返回了错误

<img src="/images/951413iMgBlog/image-20220601152401387.png" alt="image-20220601152401387" style="zoom:50%;" />

## 参考资料

[MySQL JDBC StreamResult通信原理浅析](https://blog.csdn.net/xieyuooo/article/details/83109971)