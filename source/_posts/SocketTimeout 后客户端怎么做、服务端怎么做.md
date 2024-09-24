---
title: SocketTimeout 后客户端怎么做和服务端怎么做
date: 2024-04-10 17:30:03
categories:
    - MySQL
tags:
    - MySQL
    - SocketTimeout
    - tcpdump
---

# SocketTimeout 后客户端怎么做和服务端怎么做

## 背景

希望通过一个极简，几乎是人人都可以上手验证的实验来触及到一些深度的内容，然后再看看是否会激发你进一步自己设计类似实验和验证过程等

关于这种简单类型的实验欢迎给我提意见：比如你会不会做；太难、太容易？能学到东西吗？效果如何？我要如何改进

## 安装JDK和MySQL

```
yum install -y java-1.8.0-openjdk.x86_64 java-1.8.0-openjdk-devel.x86_64  podman-docker.noarch wireshark 

//启动MySQL Server，root密码123
docker run -it -d --net=host -e MYSQL_ROOT_PASSWORD=123 --name=plantegg mysql

docker run --net=host -v /root/mysql/my3306.cnf:/etc/my.cnf -it -d  -e MYSQL_ROOT_PASSWORD=123 --name=mysql3306 mysql:8.0

//可能需要的MySQL 账号命令
//8.0密码问题，可以设置配置：
ALTER USER 'test'@'localhost' IDENTIFIED WITH mysql_native_password BY '123';
ALTER USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY '123';
```

测试环境机器是[99块一年购买的aliyun ECS](https://www.aliyun.com/daily-act/ecs/activity_selection)，OS版本选ALinux3，对应内核版本：

```
5.10.134-15.al8.x86_64
```

测试使用的MySQL 版本：

```
mysql> \s
--------------
mysql  Ver 8.0.32 for Linux on x86_64 (Source distribution)

Connection id:		9
Current database:	test
Current user:		root@127.0.0.1
SSL:			Not in use
Current pager:		stdout
Using outfile:		''
Using delimiter:	;
Server version:		8.2.0 MySQL Community Server - GPL
Protocol version:	10
Connection:		127.1 via TCP/IP
Server characterset:	utf8mb4
Db     characterset:	utf8mb4
Client characterset:	utf8mb4
Conn.  characterset:	utf8mb4
TCP port:		3306
Binary data as:		Hexadecimal
Uptime:			15 hours 46 min 24 sec

Threads: 2  Questions: 34  Slow queries: 0  Opens: 176  Flush tables: 3  Open tables: 95  Queries per second avg: 0.000
```

## 客户端

```
测试代码(复制粘贴就可以编译运行了，运行时需要下载jdbc mysql driver，链接见附录)：
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.PreparedStatement;
public class Test { //不要琢磨代码规范、为什么要这么写，就是为了方便改吧改吧做很多不同的验证试验
    public static void main(String args[]) throws NumberFormatException, InterruptedException, ClassNotFoundException {
        Class.forName("com.mysql.jdbc.Driver");
        String url = args[0];
        String user = args[1];
        String pass = args[2];
        String sql = args[3];
        String interval = args[4];
        try {
            Connection conn = DriverManager.getConnection(url, user, pass);
            while (true) {
                PreparedStatement stmt = conn.prepareStatement(sql);
                //stmt.setFetchSize(Integer.MIN_VALUE); //这句是表示开流式读取，但是每条SQL 都会先发set net_write_timeout=600 给Server
                stmt.setString(1, interval);
                ResultSet rs = stmt.executeQuery();
                rs.close();
                stmt.close();

                PreparedStatement stmt2 = conn.prepareStatement(sql);
                stmt2.setString(1, interval);
                rs = stmt2.executeQuery();
								while (rs.next()) {
								    System.out.println("fine");
								}
                rs.close();
                stmt2.close();

                Thread.sleep(Long.valueOf(interval));
								break;
            }
						conn.close();
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }
}

#javac Test.java //编译，需要提前安装JDK
//执行，需要下载jdbc jar驱动，见附录，还需要有一个数据库，随便建个表，或者查里面自带的库都可以
#java -cp .:./mysql-connector-java-5.1.45.jar Test "jdbc:mysql://127.0.0.1:3306/test?useSSL=false&useServerPrepStmts=true&cachePrepStmts=true&connectTimeout=500&socketTimeout=1700" root 123 "select sleep(10), id from sbtest1 where id= ?" 100 //设置了1.7秒超时查询还不返回的话业务代码报错，堆栈如下：
com.mysql.jdbc.exceptions.jdbc4.CommunicationsException: Communications link failure //连接异常

The last packet successfully received from the server was 1,701(1700ms) milliseconds ago.  The last packet sent successfully to the server was 1,701 milliseconds ago.
	at java.base/jdk.internal.reflect.NativeConstructorAccessorImpl.newInstance0(Native Method)
	at java.base/jdk.internal.reflect.NativeConstructorAccessorImpl.newInstance(NativeConstructorAccessorImpl.java:62)
	at java.base/jdk.internal.reflect.DelegatingConstructorAccessorImpl.newInstance(DelegatingConstructorAccessorImpl.java:45)
	at java.base/java.lang.reflect.Constructor.newInstanceWithCaller(Constructor.java:500)
	at java.base/java.lang.reflect.Constructor.newInstance(Constructor.java:481)
	at com.mysql.jdbc.Util.handleNewInstance(Util.java:425)
	at com.mysql.jdbc.SQLError.createCommunicationsException(SQLError.java:990)
	at com.mysql.jdbc.MysqlIO.reuseAndReadPacket(MysqlIO.java:3559)
	at com.mysql.jdbc.MysqlIO.reuseAndReadPacket(MysqlIO.java:3459)
	at com.mysql.jdbc.MysqlIO.checkErrorPacket(MysqlIO.java:3900)
	at com.mysql.jdbc.MysqlIO.sendCommand(MysqlIO.java:2527)
	at com.mysql.jdbc.ServerPreparedStatement.serverExecute(ServerPreparedStatement.java:1283)
	at com.mysql.jdbc.ServerPreparedStatement.executeInternal(ServerPreparedStatement.java:783)
	at com.mysql.jdbc.PreparedStatement.executeQuery(PreparedStatement.java:1966)
	at Test.main(Test.java:30)
Caused by: java.net.SocketTimeoutException: Read timed out // SocketTimeoutException 异常
	at java.base/sun.nio.ch.NioSocketImpl.timedRead(NioSocketImpl.java:284)
	at java.base/sun.nio.ch.NioSocketImpl.implRead(NioSocketImpl.java:310)
	at java.base/sun.nio.ch.NioSocketImpl.read(NioSocketImpl.java:351)
	at java.base/sun.nio.ch.NioSocketImpl$1.read(NioSocketImpl.java:802)
	at java.base/java.net.Socket$SocketInputStream.read(Socket.java:919)
	at com.mysql.jdbc.util.ReadAheadInputStream.fill(ReadAheadInputStream.java:101)
	at com.mysql.jdbc.util.ReadAheadInputStream.readFromUnderlyingStreamIfNecessary(ReadAheadInputStream.java:144)
	at com.mysql.jdbc.util.ReadAheadInputStream.read(ReadAheadInputStream.java:174)
	at com.mysql.jdbc.MysqlIO.readFully(MysqlIO.java:3008)
	at com.mysql.jdbc.MysqlIO.reuseAndReadPacket(MysqlIO.java:3469)
	... 7 more
```

## 服务端对应的抓包

如果OS 比较老，安装的tshark 也较老，那么命令参数略微不一样，主要是 col.Info 这个列，没有 _ws 前缀：

```
#tshark -i eth0 port 3306  -T fields -e frame.number -e frame.time_delta -e tcp.srcport -e tcp.dstport -e col.Info -e mysql.query
```



如果是阿里云 99 买了ECS，安装的内核版本较高比如4.19，那么配套安装的tshark也较高，就用如下命令：

```
#tshark -i eth0 -Y "tcp.port==3306" -T fields -e frame.number -e frame.time -e frame.time_delta -e tcp.srcport -e tcp.dstport -e tcp.len -e _ws.col.Info -e mysql.query
 //第二列是时间间隔
1	0.000000000	30260	3306	kingdomsonline > mysql [SYN] Seq=0 Win=42340 Len=0 MSS=1460 SACK_PERM=1 WS=512
2	0.000024473	3306	30260	mysql > kingdomsonline [SYN, ACK] Seq=0 Ack=1 Win=29200 Len=0 MSS=1460 SACK_PERM=1 WS=128
3	0.000271938	30260	3306	kingdomsonline > mysql [ACK] Seq=1 Ack=1 Win=42496 Len=0 //3次握手
4	0.000660359	3306	30260	Server Greeting proto=10 version=8.2.0 //MySQL server主动发送版本、问候信息等
5	0.000263009	30260	3306	kingdomsonline > mysql [ACK] Seq=1 Ack=78 Win=42496 Len=0
6	0.039698745	30260	3306	Login Request user=test db=test //客户端验证账号密码
7	0.000009044	3306	30260	mysql > kingdomsonline [ACK] Seq=78 Ack=243 Win=30336 Len=0
8	0.000171281	3306	30260	Response
9	0.000260062	30260	3306	kingdomsonline > mysql [ACK] Seq=243 Ack=126 Win=42496 Len=0
10	0.000298127	30260	3306	Request Unknown (168)
11	0.000142114	3306	30260	Response OK 
12	0.000255322	30260	3306	kingdomsonline > mysql [ACK] Seq=267 Ack=137 Win=42496 Len=0
13	0.003596187	30260	3306	Request Query	/* mysql-connector-java-5.1.45 ( Revision: 9131eefa398531c7dc98776e8a3fe839e544c5b2 ) */SELECT  @@session.auto_increment_increment AS auto_increment_increment, @@character_set_client AS character_set_client, @@character_set_connection AS character_set_connection, @@character_set_results AS character_set_results, @@character_set_server AS character_set_server, @@collation_server AS collation_server, @@init_connect AS init_connect, @@interactive_timeout AS interactive_timeout, @@license AS license, @@lower_case_table_names AS lower_case_table_names, @@max_allowed_packet AS max_allowed_packet, @@net_buffer_length AS net_buffer_length, @@net_write_timeout AS net_write_timeout, @@have_query_cache AS have_query_cache, @@sql_mode AS sql_mode, @@system_time_zone AS system_time_zone, @@time_zone AS time_zone, @@transaction_isolation AS transaction_isolation, @@wait_timeout AS wait_timeout
14	0.000328419	3306	30260	Response
15	0.000266581	30260	3306	kingdomsonline > mysql [ACK] Seq=1164 Ack=1208 Win=42496 Len=0
16	0.022407439	30260	3306	Request Query	SHOW WARNINGS
17	0.000058143	3306	30260	Response
18	0.000267585	30260	3306	kingdomsonline > mysql [ACK] Seq=1182 Ack=1411 Win=42496 Len=0
19	0.001776177	30260	3306	Request Query	SET NAMES utf8mb4 //客户端设置charset
20	0.000052102	3306	30260	Response OK
21	0.000263257	30260	3306	kingdomsonline > mysql [ACK] Seq=1204 Ack=1422 Win=42496 Len=0
22	0.000175172	30260	3306	Request Query	SET character_set_results = NULL
23	0.000046756	3306	30260	Response OK
24	0.000258191	30260	3306	kingdomsonline > mysql [ACK] Seq=1241 Ack=1433 Win=42496 Len=0
25	0.000185322	30260	3306	Request Query	SET autocommit=1
26	0.000037833	3306	30260	Response OK
27	0.000255747	30260	3306	kingdomsonline > mysql [ACK] Seq=1262 Ack=1444 Win=42496 Len=0
28	0.011132112	30260	3306	Request Prepare Statement	select sleep(10), id from sbtest1 where id= ?  //进一步学习
29	0.000171861	3306	30260	Response //作业：Prepared Statement 放回了啥？
30	0.000290736	30260	3306	kingdomsonline > mysql [ACK] Seq=1312 Ack=1570 Win=42496 Len=0
31	0.000613187	30260	3306	Request Execute Statement                                           //客户端发送SQL请求
32	0.039923585	3306	30260	mysql > kingdomsonline [ACK] Seq=1570 Ack=1334 Win=32128 Len=0
33	1.675682641	30260	3306	kingdomsonline > mysql [FIN, ACK] Seq=1334 Ack=1570 Win=42496 Len=0 //1.7秒后客户端发fin主动断开
34	0.039320026	3306	30260	mysql > kingdomsonline [ACK] Seq=1570 Ack=1335 Win=32128 Len=0

//MySQL 还完全不知道客户端fin了，继续发送响应结果。tcp断开在OS 层面处理，业务再使用这个已断开的连接时OS 会返回错误
35	3.245406398	3306	30260	Response
36	0.000041708	3306	30260	Server Greeting Error 1158 //MySQL 感知到OS返回的错误，发送错误码(已经没有用了)，不过客户端已经断开收不到了
37	0.000053987	3306	30260	mysql > kingdomsonline [FIN, ACK] Seq=1742 Ack=1335 Win=32128 Len=0
38	0.000165707	30260	3306	kingdomsonline > mysql [RST] Seq=1335 Win=0 Len=0 //连接都断开了，客户端已经退出，客户端的OS代发reset 
39	0.000017860	30260	3306	kingdomsonline > mysql [RST] Seq=1335 Win=0 Len=0
40	0.000082025	30260	3306	kingdomsonline > mysql [RST] Seq=1335 Win=0 Len=0
```

如果你的 tshark 版本较高，以上命令行可以改为：

```
tshark -i lo -Y "tcp.port==3306" -T fields -e frame.number -e frame.time_delta -e tcp.srcport -e tcp.dstport -e _ws.col.Info -e mysql.query
```

GPT4.0 Turbo 对上面这个 tshark 命令的解释：

```
你提到的命令使用tshark捕获在端口3306（MySQL的默认端口）上的网络流量，并提取特定的字段进行显示。tshark是Wireshark的命令行版本，一个非常强大的网络协议分析工具。

这条命令的组成部分解释如下：

-i eth0: 指定tshark监听eth0接口上的流量。这是网络接口的名称，可以根据实际情况进行修改。

port 3306: 指定tshark只捕获目标或源端口为3306的TCP流量，这是MySQL服务器监听的标准端口。

-T fields: 设置tshark的输出格式为字段值（fields），意味着输出将以列的形式显示指定的字段。

-e frame.number: 添加一个字段，显示每个捕获的帧的编号。

-e frame.time_delta: 添加一个字段，显示自上一帧以来经过的时间（以秒为单位）。

-e tcp.srcport: 添加一个字段，显示TCP源端口号。

-e tcp.dstport: 添加一个字段，显示TCP目标端口号。

-e col.Info: 添加一个字段，显示捕获帧的信息列。

-e mysql.query: 添加一个字段，如果捕获的TCP流量是MySQL流量，显示MySQL查询。

这个命令的输出将是以空格分隔的列，每一列代表上述参数指定的一个字段。每一行代表一个捕获的网络帧，其中包含MySQL查询。

请注意，由于这个命令包含了mysql.query，它需要tshark能够解析MySQL协议。而且，如果MySQL流量是加密的（例如使用SSL/TLS），那么tshark将无法直接显示查询内容。

在运行这个命令前，你需要有足够的权限来捕获网络流量，通常需要root权限或者足够的权限来访问网络接口。如果你不是root用户，可以使用sudo运行tshark命令。

sudo tshark -i eth0 port 3306 -T fields -e frame.number -e frame.time_delta -e tcp.srcport -e tcp.dstport -e col.Info -e mysql.query
这个命令将实时显示MySQL查询相关的流量信息。如果你想要保存结果到一个文件，可以使用重定向或-w选项。如果只想要捕获一定数量的包，可以使用-c选项后跟要捕获的包的数量。
```



最后用一张大截图来演示这个实验：

![image-20240111121421625](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/image-20240111121421625.png)



## PreparedStatement 验证

测试代码，用Prepared执行三次查询：

```java
                PreparedStatement stmt = conn.prepareStatement(sql);
//                stmt.setFetchSize(Integer.MIN_VALUE);
                stmt.setString(1, interval);
                ResultSet rs = stmt.executeQuery();
                rs.close();
                stmt.close();

                PreparedStatement stmt2 = conn.prepareStatement(sql);
                stmt2.setString(1, interval);
                rs = stmt2.executeQuery();
                //Thread.sleep(60000);
                while (rs.next()) {
                        System.out.println("fine");
                }
                rs = stmt2.executeQuery();
                //Thread.sleep(60000);
                while (rs.next()) {
                        System.out.println("fine");
                }
                rs.close();
                stmt2.close();
```

如图绿色是Prepared过程不会真执行 Select 查数据，只是把这条SQL 发给Server，让Server 提前编译，可以看出来编译时间0.000146秒(绿色方框)，因为SQL 非常简单；三个红色线分别是3次真正的查询，都走了Prepared(不再传 Select了)，不过时间很不稳定，所以这个统计必须大批量。红色方框是三次通过Prepared 执行 Select 查数据的执行时间：

![image-20240322103643718](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/image-20240322103643718.png)

## 结论

作为一个CRUD boy从以上实验中你可以学到哪些东西？

- 客户端报错堆栈要熟悉，Communications link failure (很多原因可以导致这个错误哈)和 java.net.SocketTimeoutException: Read timed out
- JDBC 连接参数要配置socketTimeout，不配置会导致很多很多故障，显得CRUD boy太业余
- 抓包，从抓包中学到每个动作，反过来分析原因，比如这次报错就是客户端发送了查询过1.7秒主动断开，所以问题在客户端，1.7秒也要敏感
- 最重要的是学到这个实验过程，比如再自己去试试分析 PreparedStatement 的工作原理，如何才能让 PreparedStatement 生效

## 进一步学习

你可以把抓包保存，然后下载到wireshark中，能看到具体每一个包的详细内容，比如加密后的密码、Prepared statement是个啥(一个唯一id)

比如明明MySQL Server感知到了连接断开错误(Message: Got an error reading communication packets) 还要挣扎着返回这个错误信息给客户端有必要吗？

java 跑着，直接kill -9 java-pid 看看服务端收到什么包？(有经验后下次看到这样的症状就知道为啥了)

## 参考

[MySQL 1158错误信息的详细意思](https://fromdual.com/mysql-error-codes-and-messages-1150-1199#error_er_net_read_error)

[mysql jdbc driver](http://www.java2s.com/example/jar/m/download-mysqlconnectorjava5145jar-file.html)



# 后续 Debug

## 为啥我的Java 代码跑半天也不报错：

![image-20240115090336526](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/image-20240115090336526.png)



jstack -p java-pid ，可以看到main 卡在执行SQL 后等结果的堆栈里，所以不是Java sleep了，等看对端MySQL 在干什么

```
"Reference Handler" #2 daemon prio=10 os_prio=0 tid=0x00007f6a5c0db000 nid=0x109d8e in Object.wait() [0x00007f6a60a75000]
   java.lang.Thread.State: WAITING (on object monitor)
        at java.lang.Object.wait(Native Method)
        - waiting on <0x00000000f6b08d90> (a java.lang.ref.Reference$Lock)
        at java.lang.Object.wait(Object.java:502)
        at java.lang.ref.Reference.tryHandlePending(Reference.java:191)
        - locked <0x00000000f6b08d90> (a java.lang.ref.Reference$Lock)
        at java.lang.ref.Reference$ReferenceHandler.run(Reference.java:153)

"main" #1 prio=5 os_prio=0 tid=0x00007f6a5c04b000 nid=0x109d8a runnable [0x00007f6a638e9000]
   java.lang.Thread.State: RUNNABLE
        at java.net.SocketInputStream.socketRead0(Native Method)
        at java.net.SocketInputStream.socketRead(SocketInputStream.java:116)
        at java.net.SocketInputStream.read(SocketInputStream.java:171)
        at java.net.SocketInputStream.read(SocketInputStream.java:141)
        at com.mysql.jdbc.util.ReadAheadInputStream.fill(ReadAheadInputStream.java:101)
        at com.mysql.jdbc.util.ReadAheadInputStream.readFromUnderlyingStreamIfNecessary(ReadAheadInputStream.java:144)
        at com.mysql.jdbc.util.ReadAheadInputStream.read(ReadAheadInputStream.java:174)
        - locked <0x00000000f6b71370> (a com.mysql.jdbc.util.ReadAheadInputStream)
        at com.mysql.jdbc.MysqlIO.readFully(MysqlIO.java:3008)
        at com.mysql.jdbc.MysqlIO.reuseAndReadPacket(MysqlIO.java:3469)
        at com.mysql.jdbc.MysqlIO.reuseAndReadPacket(MysqlIO.java:3459)
        at com.mysql.jdbc.MysqlIO.checkErrorPacket(MysqlIO.java:3900)
        at com.mysql.jdbc.MysqlIO.sendCommand(MysqlIO.java:2527)
        at com.mysql.jdbc.ServerPreparedStatement.serverExecute(ServerPreparedStatement.java:1283)
        - locked <0x00000000f6b0a228> (a com.mysql.jdbc.JDBC4Connection)
        at com.mysql.jdbc.ServerPreparedStatement.executeInternal(ServerPreparedStatement.java:783)
        - locked <0x00000000f6b0a228> (a com.mysql.jdbc.JDBC4Connection)
        at com.mysql.jdbc.PreparedStatement.executeQuery(PreparedStatement.java:1966)
        - locked <0x00000000f6b0a228> (a com.mysql.jdbc.JDBC4Connection)
        at Test.main(Test.java:30)

"VM Thread" os_prio=0 tid=0x00007f6a5c0d1000 nid=0x109d8d runnable

"GC task thread#0 (ParallelGC)" os_prio=0 tid=0x00007f6a5c05e000 nid=0x109d8b runnable

"GC task thread#1 (ParallelGC)" os_prio=0 tid=0x00007f6a5c060000 nid=0x109d8c runnable
```

## 抓包

为啥抓不到任何包？

![image-20240115090420370](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/image-20240115090420370.png)

先确认3306 端口是你的MySQL 在跑：

```
# ss -lntp |grep 3306
LISTEN 0      151                *:3306             *:*    users:(("mysqld",pid=1023638,fd=22))
LISTEN 0      70                 *:33060            *:*    users:(("mysqld",pid=1023638,fd=20))
```

*:3306 中的‘“*” 表示MySQLD 监听本机任何网卡的3306端口，查看一下网卡名字：

```
# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 00:16:3e:39:b5:e0 brd ff:ff:ff:ff:ff:ff
    altname enp0s5
    altname ens5
    inet 172.17.151.5/20 brd 172.17.159.255 scope global dynamic noprefixroute eth0
       valid_lft 309352989sec preferred_lft 309352989sec
    inet6 fe80::216:3eff:fe39:b5e0/64 scope link
       valid_lft forever preferred_lft forever
3: cni-podman0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether de:a8:06:82:76:00 brd ff:ff:ff:ff:ff:ff
    inet 10.88.0.1/16 brd 10.88.255.255 scope global cni-podman0
       valid_lft forever preferred_lft forever
    inet6 fe80::dca8:6ff:fe82:7600/64 scope link
       valid_lft forever preferred_lft forever
4: veth82cad224@if2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master cni-podman0 state UP group default
    link/ether 4e:1b:4a:0d:a9:e2 brd ff:ff:ff:ff:ff:ff link-netns netns-58786150-bf63-2ae1-242f-cf221eed34fe
    inet6 fe80::4c1b:4aff:fe0d:a9e2/64 scope link
       valid_lft forever preferred_lft forever
```

尝试 tshark -i any -- any是个什么鬼，展开学习下抓包参数

这里对select sleep 不确定的话可以Google sleep的单位、用法；也可以MySQL Client 验证一下

```
# mysql -h127.1  -uroot -p123
Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql> select sleep(1.4);
+------------+
| sleep(1.4) |
+------------+
|          0 |
+------------+
1 row in set (1.40 sec)

为什么不用mysql client做这个SocketTimeout的实验：mysql似乎没有SocketTimeout这个参数：
mysql --help |grep -i time
                      and reconnecting may take a longer time. Disable with
  --connect-timeout=# Number of seconds before connection timeout.
connect-timeout                           0
```



## 终于能抓到包了

![image-20240115090938622](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/image-20240115090938622.png)



## Kill Java

```
56	0.014671013	40102	3306	Request Prepare Statement	select sleep(60), id from sbtest1 where id= ?
57	0.000253230	3306	40102	Response
58	0.000173110	40102	3306	40102 → 3306 [ACK] Seq=1312 Ack=1570 Win=65536 Len=0 TSval=478689604 TSecr=478689604
59	0.000602784	40102	3306	Request Execute Statement
60	0.040903127	3306	40102	3306 → 40102 [ACK] Seq=1570 Ack=1334 Win=65536 Len=0 TSval=478689645 TSecr=478689604


77	0.397023820	40102	3306	40102 → 3306 [FIN, ACK] Seq=1334 Ack=1570 Win=65536 Len=0 TSval=478705206 TSecr=478689645
78	0.040424926	3306	40102	3306 → 40102 [ACK] Seq=1570 Ack=1335 Win=65536 Len=0 TSval=478705246 TSecr=478705206
83	0.793390527	3306	40102	Response
84	0.000016522	40102	3306	40102 → 3306 [RST] Seq=1335 Win=0 Len=0

```

## mysql kill pid

```
# tshark -i lo -Y "tcp.port==59636" -T fields -e frame.number -e frame.time_delta -e tcp.srcport -e tcp.dstport -e _ws.col.Info -e mysql.query
Running as user "root" and group "root". This could be dangerous.
Capturing on 'Loopback'
//
85	0.000042261	3306	59636	3306 → 59636 [FIN, ACK] Seq=1 Ack=1 Win=512 Len=0 TSval=478849322 TSecr=478831136
92	0.008106470	59636	3306	59636 → 3306 [FIN, ACK] Seq=1 Ack=2 Win=512 Len=0 TSval=478849333 TSecr=478849322
93	0.000008612	3306	59636	3306 → 59636 [ACK] Seq=2 Ack=2 Win=512 Len=0 TSval=478849333 TSecr=478849333

```

## kill mysqld pid

```
]# tcpdump -i lo port 50436
dropped privs to tcpdump
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on lo, link-type EN10MB (Ethernet), capture size 262144 bytes


09:32:50.138291 IP localhost.mysql > localhost.50436: Flags [F.], seq 206507581, ack 2788331892, win 512, options [nop,nop,TS val 479088777 ecr 479041791], length 0
09:32:50.150621 IP localhost.50436 > localhost.mysql: Flags [F.], seq 1, ack 1, win 512, options [nop,nop,TS val 479088789 ecr 479088777], length 0
09:32:50.150640 IP localhost.mysql > localhost.50436: Flags [.], ack 2, win 512, options [nop,nop,TS val 479088789 ecr 479088789], length 0
```

## 视频学习

如果你也想试试这个实验的话，可以参考我们的视频：https://meeting.tencent.com/user-center/shared-record-info?id=c0962ad4-16bc-4ac8-83ab-2e302c372e73&is-single=false&record_type=2&from=3

## 如果你觉得看完对你很有帮助可以通过如下方式找到我

find me on twitter: [@plantegg](https://twitter.com/plantegg)

知识星球：[https://t.zsxq.com/0cSFEUh2J](https://t.zsxq.com/0cSFEUh2J)

开了一个星球，在里面讲解一些案例、知识、学习方法，肯定没法让大家称为顶尖程序员(我自己都不是)，只是希望用我的方法、知识、经验、案例作为你的垫脚石，帮助你快速、早日成为一个基本合格的程序员。

争取在星球内：

- 养成基本动手能力
- 拥有起码的分析推理能力--按我接触的程序员，大多都是没有逻辑的
- 知识上教会你几个关键的知识点

<img src="https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/image-20240324161113874.png" alt="image-20240324161113874" style="zoom:50%;" />

