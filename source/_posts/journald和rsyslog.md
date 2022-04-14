---
title: journald和rsyslogd
date: 2021-01-28 17:30:03
categories:
    - Linux
tags:
    - Linux
    - journald
    - rsyslogd
    - log
---

# journald和rsyslogd

碰到rsyslog-8.24.0-34.1.al7.x86_64 的 rsyslogd 占用内存过高，于是分析了一下原因并学习了一下系统日志、rsyslog、journald之间的关系，流水账记录此文。

## rsyslogd 占用内存过高的分析

rsyslogd使用了大概1.6-2G内存，不正常（正常情况下内存占用30-50M之间）

现象：

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/12d137f9416d7935dbe6540c626ca8b4.png)

```
KiB Mem :  7971268 total,   131436 free,  7712020 used,   127812 buff/cache
KiB Swap:        0 total,        0 free,        0 used.    43484 avail Mem

  PID USER      PR  NI    VIRT    RES    SHR S  %CPU %MEM     TIME+ COMMAND
24850 admin     20   0 8743896   5.1g      0 S   2.0 66.9   1413:55 java
 1318 root      20   0 2380404   1.6g    536 S   0.0 21.6 199:09.36 rsyslogd
 
# systemctl status rsyslog
● rsyslog.service - System Logging Service
   Loaded: loaded (/usr/lib/systemd/system/rsyslog.service; enabled; vendor preset: disabled)
   Active: active (running) since Tue 2020-10-20 16:01:01 CST; 3 months 8 days ago
     Docs: man:rsyslogd(8)
           http://www.rsyslog.com/doc/
 Main PID: 1318 (rsyslogd)
   CGroup: /system.slice/rsyslog.service
           └─1318 /usr/sbin/rsyslogd -n

Jan 28 09:10:07 iZwz95gaul6x9167sqdqz4Z rsyslogd[1318]: sd_journal_get_cursor() failed: 'Cannot assign requested address'  [v8.24.0-34.1.al7]
Jan 28 09:10:07 iZwz95gaul6x9167sqdqz4Z rsyslogd[1318]: imjournal: journal reloaded... [v8.24.0-34.1.al7 try http://www.rsyslog.com/e/0 ]
Jan 28 10:27:48 iZwz95gaul6x9167sqdqz4Z rsyslogd[1318]: sd_journal_get_cursor() failed: 'Cannot assign requested address'  [v8.24.0-34.1.al7]
Jan 28 10:27:49 iZwz95gaul6x9167sqdqz4Z rsyslogd[1318]: imjournal: journal reloaded... [v8.24.0-34.1.al7 try http://www.rsyslog.com/e/0 ]
Jan 28 11:45:23 iZwz95gaul6x9167sqdqz4Z rsyslogd[1318]: sd_journal_get_cursor() failed: 'Cannot assign requested address'  [v8.24.0-34.1.al7]
Jan 28 11:45:24 iZwz95gaul6x9167sqdqz4Z rsyslogd[1318]: imjournal: journal reloaded... [v8.24.0-34.1.al7 try http://www.rsyslog.com/e/0 ]
Jan 28 13:03:00 iZwz95gaul6x9167sqdqz4Z rsyslogd[1318]: sd_journal_get_cursor() failed: 'Cannot assign requested address'  [v8.24.0-34.1.al7]
Jan 28 13:03:01 iZwz95gaul6x9167sqdqz4Z rsyslogd[1318]: imjournal: journal reloaded... [v8.24.0-34.1.al7 try http://www.rsyslog.com/e/0 ]
Jan 28 14:20:42 iZwz95gaul6x9167sqdqz4Z rsyslogd[1318]: sd_journal_get_cursor() failed: 'Cannot assign requested address'  [v8.24.0-34.1.al7]
Jan 28 14:20:42 iZwz95gaul6x9167sqdqz4Z rsyslogd[1318]: imjournal: journal reloaded... [v8.24.0-34.1.al7 try http://www.rsyslog.com/e/0 ] 


# grep HUPed /var/log/messages
Jan 24 03:39:15 iZwz95gaul6x9167sqdqz4Z rsyslogd: [origin software="rsyslogd" swVersion="8.24.0-34.1.al7" x-pid="1318" x-info="http://www.rsyslog.com"] rsyslogd was HUPed

# journalctl --verify
PASS: /var/log/journal/20190829214900434421844640356160/system@efef6fd56e2e4c9f861d0be25c8c0781-0000000001567546-0005b9e2e02a0a4f.journal
PASS: /var/log/journal/20190829214900434421844640356160/system@efef6fd56e2e4c9f861d0be25c8c0781-00000000015ae56b-0005b9ea76e922e9.journal
1be1e0: Data object references invalid entry at 1d03018
File corruption detected at /var/log/journal/20190829214900434421844640356160/system.journal:1d02d80 (of 33554432 bytes, 90%).
FAIL: /var/log/journal/20190829214900434421844640356160/system.journal (Bad message)
```

`journalctl --verify`命令检查发现系统日志卷文件损坏

### 问题根因

[来自redhat官网的描述](https://access.redhat.com/solutions/3705051)

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/e1a1cd75553b5cbe2a64e835ba9f99a7.png)

以下是现场收集到的日志：

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/cdfe3fb8d50ee148b816a82a432f1b88.png)

主要是rsyslogd的sd_journal_get_cursor报错，然后导致内存泄露。

journald 报Bad message, 跟rsyslogd内存泄露完全没关系，实际上升级rsyslogd后也有journald bad message,但是rsyslogd的内存一直稳定在30M以内

[这个CSDN的文章中有完全一样的症状](https://blog.csdn.net/fanren224/article/details/103991748) 但是作者的结论是：这是systemd的bug，在journald需要压缩的时候就会发生这个问题。实际上我用的是 systemd-219-62.6.al7.9.x86_64 比他描述的已经修复的版本还要要新，也还是有这个问题，所以这个结论是不对的

### 解决办法

1、重启rsyslog `systemctl restart rsyslog` 可以释放内存

2、升级rsyslog到rsyslog-8.24.0-38.1.al7.x86_64或更新的版本才能彻底修复这个问题

### 一些配置方法

修改配置/etc/rsyslog.conf，增加如下两行，然后重启`systemctl restart rsyslog`

```
$imjournalRatelimitInterval 0
$imjournalRatelimitBurst 0
12
```

1、关掉journal压缩配置

vi /etc/systemd/journald.conf，把#Compress=yes改成Compress=no，之后systemctl restart systemd-journald即可

2、限制rsyslogd 内存大小

```
cat /etc/systemd/system/multi-user.target.wants/rsyslog.service

在Service配置中添加MemoryAccounting=yes，MemoryMax=80M，MemoryHigh=8M三项如下所示。
[Service]
Type=notify
EnvironmentFile=-/etc/sysconfig/rsyslog
ExecStart=/usr/sbin/rsyslogd -n $SYSLOGD_OPTIONS
Restart=on-failure
UMask=0066
StandardOutput=null
Restart=on-failure
MemoryAccounting=yes
MemoryMax=80M
MemoryHigh=8M
```



## OOM kill

rsyslogd内存消耗过高后导致了OOM Kill

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/c7332f5b48506ea1faa015cfc6ae1709.png)

**RSS对应物理内存，单位是4K（page大小）**，红框两个进程用了5G+2G，总内存是8G，所以触发OOM killer了

每次OOM Kill日志前后总带着systemd-journald的重启

```
Jan 28 19:03:04 iZwz95gaul6x9167sqdqz5Z journal: Permanent journal is using 520.0M (max allowed 500.0M, trying to leave 4.0G free of 83.7G available → current limit 520.0M).
Jan 28 19:03:04 iZwz95gaul6x9167sqdqz5Z journal: Journal started
Jan 28 19:03:04 iZwz95gaul6x9167sqdqz5Z kernel: AliYunDun invoked oom-killer: gfp_mask=0x6200ca(GFP_HIGHUSER_MOVABLE), nodemask=(null), order=0, oom_score_adj=0
Jan 28 19:03:04 iZwz95gaul6x9167sqdqz5Z kernel: AliYunDun cpuset=/ mems_allowed=0
Jan 28 19:03:04 iZwz95gaul6x9167sqdqz5Z kernel: CPU: 3 PID: 13296 Comm: AliYunDun Tainted: G           OE     4.19.57-15.1.al7.x86_64 #1
Jan 28 19:03:04 iZwz95gaul6x9167sqdqz5Z kernel: Hardware name: Alibaba Cloud Alibaba Cloud ECS, BIOS 8c24b4c 04/01/2014
Jan 28 19:03:04 iZwz95gaul6x9167sqdqz5Z kernel: Call Trace:
Jan 28 19:03:04 iZwz95gaul6x9167sqdqz5Z kernel: dump_stack+0x5c/0x7b
Jan 28 19:03:04 iZwz95gaul6x9167sqdqz5Z kernel: dump_header+0x77/0x29f
***
Jan 28 19:03:04 iZwz95gaul6x9167sqdqz5Z kernel: [  18118]     0 18118    28218      255   245760        0             0 sshd
Jan 28 19:03:04 iZwz95gaul6x9167sqdqz5Z kernel: Out of memory: Kill process 18665 (java) score 617 or sacrifice child
Jan 28 19:03:04 iZwz95gaul6x9167sqdqz5Z kernel: Killed process 18665 (java) total-vm:8446992kB, anon-rss:4905856kB, file-rss:0kB, shmem-rss:0kB
Jan 28 19:03:04 iZwz95gaul6x9167sqdqz5Z kernel: oom_reaper: reaped process 18665 (java), now anon-rss:0kB, file-rss:0kB, shmem-rss:0kB
Jan 28 19:03:04 iZwz95gaul6x9167sqdqz5Z systemd: systemd-journald.service watchdog timeout (limit 3min)!
Jan 28 19:03:04 iZwz95gaul6x9167sqdqz5Z rsyslogd: sd_journal_get_cursor() failed: 'Cannot assign requested address'  [v8.24.0-34.1.al7]
Jan 28 19:03:04 iZwz95gaul6x9167sqdqz5Z rsyslogd: imjournal: journal reloaded... [v8.24.0-34.1.al7 try http://www.rsyslog.com/e/0 ]
Jan 28 20:14:38 iZwz95gaul6x9167sqdqz5Z rsyslogd: imjournal: journal reloaded... [v8.24.0-57.1.al7 try http://www.rsyslog.com/e/0 ]
```

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/45008a8323742fb7f145211a6281afbc.png)

OOM kill前大概率伴随着systemd-journald 重启是因为watch dog timeout(limit 3min)，造成timeout的原因是journald定期要把日志刷到磁盘上，然后要么是内存不够，要么是io负载太重，导致刷磁盘这个过程非常慢，于是就timeout了。

当然systemd-journald 重启也不一定意味着OOM Killer，只是肯定是内存比较紧张了。



## [What is the difference between syslog, rsyslog and syslog-ng? ](https://serverfault.com/questions/692309/what-is-the-difference-between-syslog-rsyslog-and-syslog-ng)

Basically, they are all the same, in the way they all permit the logging of data from different types of systems in a central repository.

But they are three different project, each project trying to improve the previous one with more reliability and functionalities.

The `Syslog` project was the very first project. It started in 1980. It is the root project to `Syslog` protocol. At this time Syslog is a very simple protocol. At the beginning it only supports UDP for transport, so that it does not guarantee the delivery of the messages.

Next came `syslog-ng` in 1998. It extends basic `syslog` protocol with new features like:

- content-based filtering
- Logging directly into a database
- TCP for transport
- TLS encryption

Next came `Rsyslog` in 2004. It extends `syslog` protocol with new features like:

- RELP Protocol support
- Buffered operation support

## rsyslog和journald的基础知识

`systemd-journald`是用来协助`rsyslog`记录系统启动服务和服务启动失败的情况等等. `systemd-journald`使用内存保存记录, 系统重启记录会丢失. 所有还要用`rsyslog`来记录分类信息, 如上面`/etc/rsyslog.d/listen.conf`中的`syslog`分类.

`systemd-journald`跟随systemd开机就启动，能及时记录所有日志：

```
# systemd-analyze critical-chain systemd-journald.service
The time after the unit is active or started is printed after the "@" character.
The time the unit takes to start is printed after the "+" character.

systemd-journald.service +13ms
└─system.slice
  └─-.slice
```

systemd-journald 由于是使用于内存的登录文件记录方式，因此重新开机过后，开机前的登录文件信息当然就不会被记载了。 为此，我们还是建议启动 rsyslogd 来协助分类记录！也就是说， systemd-journald 用来管理与查询这次开机后的登录信息，而 rsyslogd 可以用来记录以前及现在的所以数据到磁盘文件中，方便未来进行查询喔！

**Tips** 虽然 systemd-journald 所记录的数据其实是在内存中，但是系统还是利用文件的型态将它记录到 /run/log/ 下面！ 不过我们从前面几章也知道， /run 在 CentOS 7 其实是内存内的数据，所以重新开机过后，这个 /run/log 下面的数据当然就被刷新，旧的当然就不再存在了！

> 其实鸟哥是这样想的，既然我们还有 rsyslog.service 以及 logrotate 的存在，因此这个 systemd-journald.service 产生的登录文件， 个人建议最好还是放置到 /run/log 的内存当中，以加快存取的速度！而既然 rsyslog.service 可以存放我们的登录文件， 似乎也没有必要再保存一份 journal 登录文件到系统当中就是了。单纯的建议！如何处理，依照您的需求即可喔！

**`system-journal`服务监听 `/dev/log` socket获取日志, 保存在内存中, 并间歇性的写入`/var/log/journal`目录中.**

`rsyslog`服务启动后监听`/run/systemd/journal/socket` 获取syslog类型日志, 并写入`/var/log/messages`文件中. 

获取日志时需要记录日志条目的`position`到`/var/lib/rsyslog/imjournal.state`文件中.

比如haproxy日志配置：

```
# cat /etc/haproxy/haproxy.cfg
global
# log发给journald(journald监听 /dev/log)
        log /dev/log    local1 warning 
```

以下是drds 的iptables日志配置，将tcp reset包记录下来，默认iptable日志输出到/varlog/messages中（dmesg也能看到），然后可以通过rsyslog.d 配置将这部分日志输出到单独的文件中：

```
# 配置iptables 日志，增加 [drds] 标识
# cat /home/admin/drds-worker/install/drds_filter.conf
# Generated by iptables-save v1.4.21 on Wed Apr  1 11:39:31 2020
*filter
:INPUT ACCEPT [557:88127]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [527:171711]
-A INPUT -p tcp -m tcp ! --sport 3406  --tcp-flags RST RST -j LOG --log-prefix "[drds] " --log-level 7 --log-tcp-sequence --log-tcp-options --log-ip-options
# -A INPUT -p tcp -m tcp ! --dport 3406  --tcp-flags RST RST -j LOG --log-prefix "[drds] " --log-level7 --log-tcp-sequence --log-tcp-options --log-ip-options
-A OUTPUT -p tcp -m tcp ! --sport 3406 --tcp-flags RST RST -j LOG --log-prefix "[drds] " --log-level 7 --log-tcp-sequence --log-tcp-options --log-ip-options
COMMIT
# Completed on Wed Apr  1 11:39:31 2020

#通过rsyslogd将日志写出到指定位置(不配置的话默认输出到 dmesg)
# cat /etc/rsyslog.d/drds_filter_log.conf
:msg, startswith, "[drds]" -/home/admin/logs/tcp-rt/drds-tcp.log
```

### journald log持久化

创建 /var/log/journal 文件夹后默认会持久化，设置持久化后 /run/log 里面就没有日志了

```
# cat /etc/systemd/journald.conf
#  This file is part of systemd.
#
#  systemd is free software; you can redistribute it and/or modify it
#  under the terms of the GNU Lesser General Public License as published by
#  the Free Software Foundation; either version 2.1 of the License, or
#  (at your option) any later version.
#
# Entries in this file show the compile time defaults.
# You can change settings by editing this file.
# Defaults can be restored by simply deleting this file.
#
# See journald.conf(5) for details.

[Journal]
#Storage=auto  //默认如果有 /var/log/journal 目录就会持久化到这里
Compress=no
#Seal=yes
#SplitMode=uid
#SyncIntervalSec=5m
#RateLimitInterval=30s
#RateLimitBurst=1000
SystemMaxUse=500M   //最多保留500M日志文件，免得撑爆磁盘
#SystemKeepFree=
#SystemMaxFileSize=
#RuntimeMaxUse=
#RuntimeKeepFree=
#RuntimeMaxFileSize=
#MaxRetentionSec=
#MaxFileSec=1month
#ForwardToSyslog=yes
#ForwardToKMsg=no
#ForwardToConsole=no
#ForwardToWall=yes
#TTYPath=/dev/console
#MaxLevelStore=debug
#MaxLevelSyslog=debug
#MaxLevelKMsg=notice
#MaxLevelConsole=info
#MaxLevelWall=emerg
#LineMax=48K
```

清理日志保留1M：journalctl --vacuum-size=1M 

设置最大保留500M日志： journalctl --vacuum-size=500

### rsyslogd

以下内容来自鸟哥的书：

CentOS 7 除了保有既有的 rsyslog.service 之外，其实最上游还使用了 systemd 自己的登录文件日志管理功能喔！他使用的是 systemd-journald.service 这个服务来支持的。基本上，系统由 systemd 所管理，那所有经由 systemd 启动的服务，如果再启动或结束的过程中发生一些问题或者是正常的讯息， 就会将该讯息由 systemd-journald.service 以二进制的方式记录下来，之后再将这个讯息发送给 rsyslog.service 作进一步的记载。

基本上， rsyslogd 针对各种服务与讯息记录在某些文件的配置文件就是 /etc/rsyslog.conf， 这个文件规定了“（1）什么服务 （2）的什么等级讯息 （3）需要被记录在哪里（设备或文件）” 这三个咚咚，所以设置的语法会是这样：

```
$cat /etc/rsyslog.conf
服务名称[.=!]讯息等级        讯息记录的文件名或设备或主机
# 下面以 mail 这个服务产生的 info 等级为例：
mail.info            /var/log/maillog_info
# 这一行说明：mail 服务产生的大于等于 info 等级的讯息，都记录到
# /var/log/maillog_info 文件中的意思。
```

![syslog 所制订的服务名称与软件调用的方式](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/1cce7612a84cf1a1addceeff6032cb5c.png)



 CentOS 7.x 默认的 rsyslogd 本身就已经具有远程日志服务器的功能了， 只是默认并没有启动该功能而已。你可以通过 man rsyslogd 去查询一下相关的选项就能够知道啦！ 既然是远程日志服务器，那么我们的 Linux 主机当然会启动一个端口来监听了，那个默认的端口就是 UDP 或 TCP 的 port 514 

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/40740cd5cfc8896c07c15b959420646f.png)

Server配置如下：

```
$ cat /etc/rsyslog.conf
# 找到下面这几行：
# Provides UDP syslog reception
#$ModLoad imudp
#$UDPServerRun 514

# Provides TCP syslog reception
#$ModLoad imtcp
#$InputTCPServerRun 514
# 上面的是 UDP 端口，下面的是 TCP 端口！如果你的网络状态很稳定，就用 UDP 即可。
# 不过，如果你想要让数据比较稳定传输，那么建议使用 TCP 啰！所以修改下面两行即可！
$ModLoad imtcp
$InputTCPServerRun 514

# 2\. 重新启动与观察 rsyslogd 喔！
[root@study ~]# systemctl restart rsyslog.service
[root@study ~]# netstat -ltnp &#124; grep syslog
Proto Recv-Q Send-Q Local Address  Foreign Address   State    PID/Program name
tcp        0      0 0.0.0.0:514    0.0.0.0:*         LISTEN   2145/rsyslogd
tcp6       0      0 :::514         :::*              LISTEN   2145/rsyslogd
# 嘿嘿！你的登录文件主机已经设置妥当啰！很简单吧！
```

client配置：

```
$ cat /etc/rsyslog.conf
*.*       @@192.168.1.100
#*.*       @192.168.1.100  # 若用 UDP 传输，设置要变这样！
```

常见的几个系统日志有哪些呢？一般而言，有下面几个：

- /var/log/boot.log： 开机的时候系统核心会去侦测与启动硬件，接下来开始各种核心支持的功能启动等。这些流程都会记录在 /var/log/boot.log 里面哩！ 不过这个文件只会存在这次开机启动的信息，前次开机的信息并不会被保留下来！
- /var/log/cron： 还记得[第十五章例行性工作调度](https://wizardforcel.gitbooks.io/vbird-linux-basic-4e/Text/index.html)吧？你的 crontab 调度有没有实际被进行？ 进行过程有没有发生错误？你的 /etc/crontab 是否撰写正确？在这个登录文件内查询看看。
- /var/log/dmesg： 记录系统在开机的时候核心侦测过程所产生的各项信息。由于 CentOS 默认将开机时核心的硬件侦测过程取消显示， 因此额外将数据记录一份在这个文件中；
- /var/log/lastlog： 可以记录系统上面所有的帐号最近一次登陆系统时的相关信息。[第十三章讲到的 lastlog](https://wizardforcel.gitbooks.io/vbird-linux-basic-4e/Text/index.html#uselinux_find) 指令就是利用这个文件的记录信息来显示的。
- /var/log/maillog 或 /var/log/mail/*： 记录邮件的往来信息，其实主要是记录 postfix （SMTP 协定提供者） 与 dovecot （POP3 协定提供者） 所产生的讯息啦。 SMTP 是发信所使用的通讯协定， POP3 则是收信使用的通讯协定。 postfix 与 dovecot 则分别是两套达成通讯协定的软件。
- /var/log/messages： 这个文件相当的重要，几乎系统发生的错误讯息 （或者是重要的信息） 都会记录在这个文件中； 如果系统发生莫名的错误时，这个文件是一定要查阅的登录文件之一。
- /var/log/secure： 基本上，只要牵涉到“需要输入帐号密码”的软件，那么当登陆时 （不管登陆正确或错误） 都会被记录在此文件中。 包括系统的 login 程序、图形接口登陆所使用的 gdm 程序、 su, sudo 等程序、还有网络连线的 ssh, telnet 等程序， 登陆信息都会被记载在这里；
- /var/log/wtmp, /var/log/faillog： 这两个文件可以记录正确登陆系统者的帐号信息 （wtmp） 与错误登陆时所使用的帐号信息 （faillog） ！ 我们在[第十章谈到的 last](https://wizardforcel.gitbooks.io/vbird-linux-basic-4e/Text/index.html#last) 就是读取 wtmp 来显示的， 这对于追踪一般帐号者的使用行为很有帮助！
- /var/log/httpd/*, /var/log/samba/*： 不同的网络服务会使用它们自己的登录文件来记载它们自己产生的各项讯息！上述的目录内则是个别服务所制订的登录文件。

## [journalctl 常用参数](https://linuxhint.com/journalctl-tail-and-cheatsheet/)

```
-n or –lines= Show the most recent **n** number of log lines

-f or –follow Like a tail operation for viewing live updates

-S, –since=, -U, –until= Search based on a date. “2019-07-04 13:19:17”, “00:00:00”, “yesterday”, “today”, “tomorrow”, “now” are valid formats. For complete time and date specification, see systemd.time(7)

-u service unit
```

清理journald日志

>  journalctl --vacuum-size=1M && journalctl --vacuum-size=500

## logrotate

```
/var/log/cron
{
    sharedscripts
    postrotate
        /bin/kill -HUP `cat /var/run/syslogd.pid 2> /dev/null` 2> /dev/null || true
    endscript
}

```

### [kill -HUP](https://unix.stackexchange.com/questions/440004/why-is-kill-hup-used-in-logrotate-in-rhel-is-it-necessary-in-all-cases)

Generally services keep the log files opened while they are running. This mean that they do not care if the log files are renamed/moved or deleted they will continue to write to the open file handled.

When logrotate move the files, the services keep writing to the same file.

Example: syslogd will write to /var/log/cron.log. Then logrotate will rename the file to /var/log/cron.log.1, so syslogd will keep writing to the open file /var/log/cron.log.1.

Sending the HUP signal to syslogd will force him to close existing file handle and open new file handle to the original path /var/log/cron.log which will create a new file.

The use of the HUP signal instead of another one is at the discretion of the program. Some services like php-fpm will listen to the USR1 signal to reopen it's file handle without terminating itself.

不过还得看应用是否屏蔽了 HUP 信号

## systemd

sudo systemctl list-unit-files --type=service | grep enabled //列出启动项

 journalctl -b -1 //复审前一次启动， -2 复审倒数第 2 次启动. 重演你的系统启动的所有消息

sudo systemd-analyze blame   **sudo systemd-analyze critical-chain**

systemd-analyze critical-chain --fuzz 1h

sudo systemd-analyze blame networkd

systemd-analyze critical-chain network.target local-fs.target

![img](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/bb21293e-9b52-40f9-9ab2-7c5aeb7beca1.png)

## 参考资料

一模一样的症状，但是根因找错了：[rsyslog占用内存高](https://blog.csdn.net/fanren224/article/details/103991748) 

https://access.redhat.com/solutions/3705051

https://sunsea.im/rsyslogd-systemd-journald-high-memory-solution.html

[鸟哥 journald 介绍](https://wizardforcel.gitbooks.io/vbird-linux-basic-4e/content/160.html)

[journalctl tail and cheatsheet](https://linuxhint.com/journalctl-tail-and-cheatsheet/)

[Journal的由来](https://lp007819.wordpress.com/2015/01/17/systemd-journal-介绍/)

