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

## net_write_timeout

先看下 [`net_write_timeout`](https://dev.mysql.com/doc/refman/5.7/en/server-system-variables.html#sysvar_net_write_timeout)的解释：The number of seconds to wait for a block to be written to a connection before aborting the write. 

| Property            | Value                   |
| ------------------- | ----------------------- |
| Command-Line Format | `--net-write-timeout=#` |
| System Variable     | `net_write_timeout`     |
| Scope               | Global, Session         |
| Dynamic             | Yes                     |
| Type                | Integer                 |
| Default Value       | `60`                    |
| Minimum Value       | `1`                     |

> **案例**：DRDS 到 MySQL 多个分片拉取数据生成了许多 cursor 并发执行,但拉数据的时候是串行拉取的,如果用户端拉取数据过慢会导致最后一个 cursor 执行完成之后要等待很久.会超过 MySQL 的 net_write_timeout 配置从而引发报错. 也就是最后一个cursor打开后一直没有去读取数据，知道MySQL  Server 触发 net_write_timeout，报异常
>
> 首先可以尝试在 DRDS jdbcurl 配置 netTimeoutForStreamingResults 参数,设置为 0 可以使其一直等待,或设置一个合理的值(秒).

从JDBC驱动中可以看到，当调用PreparedStatement的executeQuery（）方法的时候，如果我们是去获取流式resultset的话，就会默认执行SET net_write_timeout= ？ 这个命令去重新设置timeout时间。源代码如下：

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

一般在数据导出场景中容易出现 net_write_timeout 这个错误，比如这个错误堆栈：

![](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/8fe715d3ebb6929afecd19aadbe53e5e.png)

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

## 一些其他的 Timeout

connectTimeout：表示等待和MySQL数据库建立socket链接的超时时间，默认值0，表示不设置超时，单位毫秒，建议30000。 JDBC驱动连接属性

socketTimeout：JDBC参数，表示客户端发送请求给MySQL数据库后block在read的等待数据的超时时间，linux系统默认的socketTimeout为30分钟，可以不设置。要特别注意socketTimeout仅仅是指等待socket数据时间，如果在传输数据那么这个值就没有用了。[socketTimeout通过mysql-connector中的NativeProtocol最终设置在socketOptions上](https://docs.oracle.com/javase/7/docs/api/java/net/SocketOptions.html#SO_TIMEOUT)

![image-20211024171459127](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/image-20211024171459127.png)

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

设置JDBC参数不合理（queryTimeout=10s，socketTimeout=10s），会导致在异常情况下，第二条get获得了第一条的结果，拿到了错误的数据，数据库则表现正常

socketTimeout触发后，连接抛CommunicationsException（严重异常，触发后连接应该断开）, 但JDBC会检查请求是否被cancle了，如果cancle就会抛出MySQLTimeoutException异常，这是一个普通异常，连接会被重新放回连接池重用（导致下一个获取这个连接的线程可能会得到前一个请求的response）。

queryTimeout（queryTimeoutKillsConnection=True--来强制关闭连接）会触发启动一个新的连接向server发送 kill id的命令，**MySQL5.7增加了max_statement_time/max_execution_time来做到在server上直接检测到这种查询，然后结束掉**。



## 参考资料

[MySQL JDBC StreamResult通信原理浅析](https://www.atatech.org/articles/122079)