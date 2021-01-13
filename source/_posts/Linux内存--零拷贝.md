---
title: Linux内存--零拷贝
date: 2020-11-15 16:30:03
categories: Linux
tags:
    - Linux
    - free
    - Memory
    - 零拷贝
---

# Linux内存--零拷贝

## 零拷贝

零拷贝可以做到用户空间和内核空间共用同一块内存（Java中的DirectBuffer），这样少做一次拷贝。普通Buffer是在JVM堆上分配的内存，而DirectBuffer是堆外分配的（内核和JVM可以同时读写），这样不需要再多一次内核到用户Buffer的拷贝 

![](http://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/83e2dfbd25d703c58877b2faf71c4944.jpg)

比如通过网络下载文件，普通拷贝的流程会复制4次并有4次上下文切换，上下文切换是因为读写慢导致了IO的阻塞，进而线程被内核挂起，所以发生了上下文切换。在极端情况下如果read/write没有导致阻塞是不会发生上下文切换的：

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/b2d0ffb366ef78faca4b7924c2a66cc1.png)

改成零拷贝后，也就是将read和write合并成一次，直接在内核中完成磁盘到网卡的数据复制

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/ccdc10037d35349293cba8a63ad72af5.png)

零拷贝就是操作系统提供的新函数(sendfile)，同时接收文件描述符和 TCP socket 作为输入参数，这样执行时就可以完全在内核态完成内存拷贝，既减少了内存拷贝次数，也降低了上下文切换次数。

而且，零拷贝取消了用户缓冲区后，不只降低了用户内存的消耗，还通过最大化利用 socket 缓冲区中的内存，间接地再一次减少了系统调用的次数，从而带来了大幅减少上下文切换次数的机会！

应用读取磁盘写入网络的时候还得考虑缓存的大小，一般会设置的比较小，这样一个大文件导致多次小批量的读取，每次读取伴随着多次上下文切换。

零拷贝使我们不必关心 socket 缓冲区的大小（socket缓冲区大小本身默认就是动态调整、或者应用代码指定大小）。比如，调用零拷贝发送方法时，尽可以把发送字节数设为文件的所有未发送字节数，例如 320MB，也许此时 socket 缓冲区大小为 1.4MB，那么一次性就会发送 1.4MB 到客户端，而不是只有 32KB。这意味着对于 1.4MB 的 1 次零拷贝，仅带来 2 次上下文切换，而不使用零拷贝且用户缓冲区为 32KB 时，经历了 176 次（4 * 1.4MB/32KB）上下文切换。

## read+write 和零拷贝

```
read(file, tmp_buf, len);
write(socket, tmp_buf, len);
```

![image-20201104175056589](D:%5Cali%5Ccase%5Cimage%5Cimage-20201104175056589.png)

### 通过mmap替换read优化一下

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/516c11b9b9d3f6092f00645c1742c111.png)

通过使用 `mmap()` 来代替 `read()`， 可以减少一次数据拷贝的过程。

但这还不是最理想的零拷贝，因为仍然需要通过 CPU 把内核缓冲区的数据拷贝到 socket 缓冲区里，而且仍然需要 4 次上下文切换，因为系统调用还是 2 次。

### sendfile

在 Linux 内核版本 2.1 中，提供了一个专门发送文件的系统调用函数 `sendfile()`，函数形式如下：

```c
#include <sys/socket.h>
ssize_t sendfile(int out_fd, int in_fd, off_t *offset, size_t count);
```

它的前两个参数分别是目的端和源端的文件描述符，后面两个参数是源端的偏移量和复制数据的长度，返回值是实际复制数据的长度。

首先，它可以替代前面的 `read()` 和 `write()` 这两个系统调用，这样就可以减少一次系统调用，也就减少了 2 次上下文切换的开销。

其次，该系统调用，可以直接把内核缓冲区里的数据拷贝到 socket 缓冲区里，不再拷贝到用户态，这样就只有 2 次上下文切换，和 3 次数据拷贝。如下图：

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/bd72f4a031bcd88db0ca233e59234832.png)

### SG-DMA（*The Scatter-Gather Direct Memory Access*）技术

如果网卡支持 SG-DMA（*The Scatter-Gather Direct Memory Access*）技术（和普通的 DMA 有所不同），我们可以进一步减少通过 CPU 把内核缓冲区里的数据拷贝到 socket 缓冲区的过程。

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/2361e8c6dcfd20a67f404b684196c160.png)

这就是所谓的**零拷贝（Zero-copy）技术，因为我们没有在内存层面去拷贝数据，也就是说全程没有通过 CPU 来搬运数据，所有的数据都是通过 DMA 来进行传输的。**。

零拷贝技术的文件传输方式相比传统文件传输的方式，减少了 2 次上下文切换和数据拷贝次数，**只需要 2 次上下文切换和数据拷贝次数，就可以完成文件的传输，而且 2 次的数据拷贝过程，都不需要通过 CPU，2 次都是由 DMA 来搬运。**

所以，总体来看，**零拷贝技术可以把文件传输的性能提高至少一倍以上**。

### 零拷贝应用

kafaka就利用了「零拷贝」技术，从而大幅提升了 I/O 的吞吐率，这也是 Kafka 在处理海量数据为什么这么快的原因之一。

如果你追溯 Kafka 文件传输的代码，你会发现，最终它调用了 Java NIO 库里的 `transferTo` 方法：

```java
@Overridepublic 
long transferFrom(FileChannel fileChannel, long position, long count) throws IOException { 
    return fileChannel.transferTo(position, count, socketChannel);
}
```

如果 Linux 系统支持 `sendfile()` 系统调用，那么 `transferTo()` 实际上最后就会使用到 `sendfile()` 系统调用函数。

Nginx 也支持零拷贝技术，一般默认是开启零拷贝技术，这样有利于提高文件传输的效率，是否开启零拷贝技术的配置如下：

```
http {
...
    sendfile on
...
}
```

sendfile 配置的具体意思:

- 设置为 on 表示，使用零拷贝技术来传输文件：sendfile ，这样只需要 2 次上下文切换，和 2 次数据拷贝。
- 设置为 off 表示，使用传统的文件传输技术：read + write，这时就需要 4 次上下文切换，和 4 次数据拷贝。

如果是大文件很容易消耗非常多的PageCache，不推荐使用PageCache（或者说零拷贝），建议使用异步IO+直接IO。

在 nginx 中，我们可以用如下配置，来根据文件的大小来使用不同的方式：

```
location /video/ { 
    sendfile on; 
    aio on; 
    directio 1024m; 
}
```

当文件大小大于 `directio` 值后，使用「异步 I/O + 直接 I/O」，否则使用「零拷贝技术」。



## DMA

什么是 DMA 技术？简单理解就是，**在进行 I/O 设备和内存的数据传输的时候，数据搬运的工作全部交给 DMA 控制器，而 CPU 不再参与任何与数据搬运相关的事情，这样 CPU 就可以去处理别的事务**。	

RDMA

## 参考资料

https://www.atatech.org/articles/66885

https://cloud.tencent.com/developer/article/1087455

https://www.cnblogs.com/xiaolincoding/p/13719610.html