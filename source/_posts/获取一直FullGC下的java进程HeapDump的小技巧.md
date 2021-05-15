---
title: 获取一直FullGC下的java进程HeapDump的小技巧
date: 2020-01-04 17:30:03
categories:
    - Java
tags:
    - FullGC
    - HeapDumpBeforeFullGC
    - java
    - gdb
---

# 获取一直FullGC下的java进程HeapDump的小技巧

就是小技巧，操作步骤需要查询，随手记录

- 找到java进程，gdb attach上去， 例如 `gdb -p 22443`
- 找到这个`HeapDumpBeforeFullGC`的地址（这个flag如果为true，会在FullGC之前做HeapDump，默认是false）

```
(gdb) p &HeapDumpBeforeFullGC
$2 = (<data variable, no debug info> *) 0x7f7d50fc660f <HeapDumpBeforeFullGC>
```

- Copy 地址：0x7f7d50fc660f
- 然后把他设置为true，这样下次FGC之前就会生成一份dump文件

```
(gdb) set *0x7f7d50fc660f = 1
(gdb) quit
```

- 最后，等一会，等下次FullGC触发，你就有HeapDump了！
  (如果没有指定heapdump的名字，默认是 java_pidxxx.hprof)

(PS. `jstat -gcutil pid` 可以查看gc的概况)

(操作完成后记得gdb上去再设置回去，不然可能一直fullgc，导致把磁盘打满).

## 其它

在jvm还有响应的时候可以： jinfo -flag +HeapDumpBeforeFullGC pid 设置HeapDumpBeforeFullGC 为true（- 为false，+-都不要为只打印值）

kill -3 产生coredump  存放在 kernel.core_pattern=/root/core （/etc/sysctl.conf)

得到core文件后，采用 gdb -c 执行文件 core文件 进入调试模式，对于java，有以下2个技巧：

进入gdb调试模式后，输入如下命令： info threads，观察异常的线程，定位到异常的线程后，则可以输入如下命令：thread 线程编号，则会打印出当前java代码的工作流程。

 而对于这个core，亦可以用jstack jmap打印出堆信息，线程信息，具体命令：

  jmap -heap 执行文件 core文件   jstack -F -l 执行文件 core文件

 

**容器中的进程的话需要到宿主机操作，并且将容器中的 jdk文件夹复制到宿主机对应的位置。**

  **ps auxff |grep 容器id -A10 找到JVM在宿主机上的进程id**
