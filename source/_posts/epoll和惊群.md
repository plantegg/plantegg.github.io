---
title: epoll和惊群
date: 2019-10-31 12:30:03
categories: Linux
tags:
    - 惊群
    - epoll
    - nginx
    - reuseport
    - EPOLLEXCLUSIVE
---

# epoll和惊群

本文尝试追踪不同的内核版本增加的方案来看内核是如何来尝试解决惊群问题的。以及像 SO_REUSEPORT 和EPOLLEXCLUSIVE又带来了什么小问题。

## 先上总结

如果服务器采用accept阻塞调用方式群在2.6内核就通过增加WQ_FLAG_EXCLUSIVE在内核中就行排他解决惊群了；

只有epoll的accept才有惊群，这是因为epoll监听句柄中后续可能是accept，也有可能是read/write网络IO事件，这些IO事件不一定只能由一个进程处理（很少见需要多个进程处理的），所以内核层面没直接解决epoll的惊群，交由上层应用来根据IO事件如何处理。

epoll的惊群在3.10内核加了SO_REUSEPORT来解决惊群，但如果处理accept的worker也要处理read/write（Nginx的工作方式）就可能导致不同的worker有的饥饿有的排队假死一样；4.5的内核增加EPOLLEXCLUSIVE在内核中直接将worker放在一个大queue，同时感知worker状态来派发任务更好滴解决了惊群，但是因为LIFO的机制导致在压力不大的情况下，任务主要派发给少数几个worker（能接受，压力大就会正常了）。

## 什么是惊群

惊群效应也有人叫做雷鸣群体效应，惊群就是多进程（多线程）在同时阻塞等待同一个事件的时候（休眠状态），如果等待的这个事件发生，那么他就会唤醒等待的所有进程（或者线程），但是最终却只可能有一个进程（线程）获得这个事件的“控制权”，对该事件进行处理，而其他进程（线程）获取“控制权”失败，只能重新进入休眠状态，这种现象和性能浪费就叫做惊群。

惊群的本质在于多个线程处理同一个事件。

为了更好的理解何为惊群，举一个很简单的例子，当你往一群鸽子中间扔一粒谷子，所有的鸽子都被惊动前来抢夺这粒食物，但是最终只有一只鸽子抢到食物。这里鸽子表示进程（线程），那粒谷子就是等待处理的事件。

## 无IO复用时Accept

> 无IO复用的accept 不会有惊群，epoll_wait 才会。accept一定是只需要一个进程处理消息，内核可以解决。但是select、epoll就不一定了，所以内核只能唤醒所有的。

在linux2.6版本以后，linux内核已经解决了accept()函数的“惊群”现象，大概的处理方式就是，当内核接收到一个客户连接后，只会唤醒等待队列上的第一个进程（线程）,所以如果服务器采用accept阻塞调用方式，在2.6的linux系统中已经没有“惊群效应”了。

	 /* nr_exclusive的值默认设为1 */
	 #define wake_up_interruptible_sync_poll(x, m)              \
	    __wake_up_sync_key((x), TASK_INTERRUPTIBLE, 1, (void *) (m))
	
	tcp_v4_rcv
	tcp_v4_do_rcv
	tcp_child_process
	sock_def_readable
	wake_up_interruptible_sync_poll
	__wake_up_common
	 /* 从头遍历监听socket的等待队列，唤醒等待进程，有EXCLUSIVE标识时只唤醒一个进程 */
	list_for_each_entry_safe(curr, next, &q->task_list, task_list)
	    /* func最终调用try_to_wake_up，设置进程状态为TASK_RUNNING，并把进程插入CPU运行队列，来唤醒睡眠的进程 */
	    if (curr->func(curr, mode, wake_flags, key) && (flags & WQ_FLAG_EXCLUSIVE)  &&
	       !--nr_exclusive)
	       break; 

sock中定义了几个I/O事件，当协议栈遇到这些事件时，会调用它们的处理函数。当监听socket收到新的连接时，会触发有数据可读事件，调用sock_def_readable，唤醒socket等待队列中的进程。进程被唤醒后，会执行accept的后续操作，最终返回新连接的描述符。

这个socket等待队列是一个FIFO，所以最终是均衡的，也不需要惊群，有tcp connection ready的话直接让等待队列中第一个的线程出队就好了。

2.6内核层面添加了一个WQ_FLAG_EXCLUSIVE标记，告诉内核进行排他性的唤醒，即唤醒一个进程后即退出唤醒的过程(适合accept，但是不适合 epoll--因为epoll除了有accept，还有其它IO事件）

所以这就是大家经常看到的accept不存在惊群问题，内核10年前就解决了这个问题的场景，实际指的是非epoll下的accept 惊群。

## epoll的Accept

epoll监听句柄，后续可能是accept，也有可能是read/write网络IO事件，这些IO事件不一定只能由一个进程处理（很少见需要多个进程处理的），所以内核层面没直接解决epoll的惊群，交由上层应用来根据IO事件如何处理。

也就是只要是epoll事件，os默认会唤醒监听这个epoll的所有线程。所以常见的做法是一个epoll绑定到一个thread。

	//主进程中：
	ngx_init_cycle
	ngx_open_listening_sockets
	    socket
	    bind
	    listen
	    epoll_create
	    epoll_ctl
	
	//子进程中：
	ngx_event_process_init
	ngx_prcocess_events_and_timers
	ngx_epoll_process_events
	    epoll_wait
	    rev->handler(rev) // 对于listening socket，handler是ngx_event_accept

和普通的accept不同，使用epoll时，是在epoll_wait()返回后，发现监听socket有可读事件，才调用accept()。由于epoll_wait()是LIFO，导致多个子进程在accept新连接时，也变成了LIFO。

	epoll_wait
	ep_poll
	    /* 创建等待任务，把等待任务加入到epfd等待队列的头部，而不是尾部 */
	    init_waitqueue_entry(&wait, current) 
	    __add_wait_queue_exclusive(&ep->wq, &wait)
	    ...
	    __remove_wait-queue(&ep->wq, &wait) /* 最终从epfd等待队列中删除 */

回调触发逻辑：

	tcp_v4_rcv
	tcp_v4_do_rcv
	tcp_child_process
	sock_def_readable /* sock I/O 有数据可读事件 */
	wake_up_interruptible_sync_poll
	__wake_up_common
	    /* curr->func是等待任务的回调函数，在ep_insert初始化等待任务时，设置为ep_poll_callback */
	    if (curr->func(curr, mode, wake_flags, key) && (flags & WQ_FLAG_EXCLUSIVE)  &&
	        !--nr_exclusive)
	        break;

那么这种情况下内核如何来解决惊群呢？ 

### SO_REUSEPORT

虽然通过将一个epoll绑定到一个thread来解决竞争问题，但是对于高并发的处理一个thread明显不够，所以有时候不得不设置多个thread来处理一个epoll上的所有socket事件（比如accept）

在3.10的内核中通过引入SO_REUSEPORT解决了这个epoll accept惊群的问题。

linux man文档中一段文字描述其作用：
> 
> The new socket option allows multiple sockets on the same host to bind to the same port, and is intended to improve the performance of multithreaded network server applications running on top of multicore systems.

SO_REUSEPORT支持多个进程或者线程绑定到同一端口，提高服务器程序的性能，解决的问题：

- 允许多个套接字 bind()/listen() 同一个TCP/UDP端口
- 每一个线程拥有自己的服务器套接字
- 在服务器套接字上没有了锁的竞争
- 内核层面实现负载均衡，内核通过socket的五元组来hash到不同的socket listener上
- 安全层面，监听同一个端口的套接字只能位于同一个用户下面


其核心的实现主要有三点：

- 扩展 socket option，增加 SO_REUSEPORT 选项，用来设置 reuseport。
- 修改 bind 系统调用实现，以便支持可以绑定到相同的 IP 和端口
- 修改处理新建连接的实现，查找 listener 的时候，能够支持在监听相同 IP 和端口的多个 sock 之间均衡选择。

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/b432f41572f17529d4a1da774d0d34a6.png)

- Nginx的accept_mutex通过抢锁来控制是否将监听套接字加入到epoll 中。监听套接字只在一个子进程的 epoll 中，当新的连接来到时，其他子进程当然不会惊醒了。通过 accept_mutex加锁性能要比reuseport差
- Linux内核解决了epoll_wait 惊群的问题，Nginx 1.9.1利用Linux3.10 的reuseport也能解决惊群、提升性能。
- 内核的reuseport中相当于所有listen同一个端口的多个进程是一个组合，**内核收包时不管查找到哪个socket，都能映射到他们所属的 reuseport 数组，再通过五元组哈希选择一个socket，这样只有这个socket队列里有数据，所以即便所有的进程都添加了epoll事件，也只有一个进程会被唤醒。**



当有包进来，根据5元组，如果socket是ESTABLISHED那么直接给对应的socket，如果是握手，根据**SO_REUSEPORT**匹配到对应的监听port的多个线程中的一个

![](https://mmbiz.qpic.cn/mmbiz_png/yiaiaFLiaflYRTRy6F9YcnuFfYn7ESbWldtibYIVFRL84nRwtZuOgWYdOTI4BuRodRdR7LvWLlDXZl5cZ23l3AUgOQ/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

对于Established socket的读写事件一般是只有一个worker在监听对应的epoll事件。

#### Nginx下SO_REUSEPORT 带来的小问题

从下图可以看出Nginx的一个worker即处理上面的accept也处理对应socket的read/write，如果一个read/write比较耗时的话也会影响到别的socket上的read/write或者accept

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/912854ed07613bbef1feaede37508548.png)

SO_REUSEPORT打开后，去掉了上图的共享锁，变成了如下结构：

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/b432f41572f17529d4a1da774d0d34a6.png)

再有请求进来不再是各个进程一起去抢，而是内核通过五元组Hash来分配，所以不再会惊群了。但是可能会导致撑死或者饿死的问题，比如一个cpu一直在做一件耗时的任务（比如压缩），但是内核通过hash分配过来的时候是不知道的（抢锁就不会发生这种情况，你没空就不会去抢），以Nginx为例

[因为Nginx是ET模式，epoll要一直将事件处理完毕才能进入epoll_wait（才能响应新的请求）。带来了新的问题：如果有一个慢请求（比如gzip压缩文件需要2分钟），那么处理这个慢请求的进程在reuseport模式下还是会被内核分派到，但是这个时候他如同hang死了，新分配进来的请求无法处理。如果不是reuseport模式，他在处理慢请求就根本腾不出来时间去在惊群中抢到锁。但是还是会影响Established 连接上的请求，这个影响和Reuseport没有关系，是一个线程处理多个Socket带来的必然结果](https://www.atatech.org/articles/89653) 当然这里如果Nginx把accept和read/write分开用不同的线程来处理也不会有这个问题，毕竟accept正常都很快。

如果不开启SO_REUSEPORT模式，那么即使有一个进程在处理慢请求，那么他就不会去抢accept锁，也就没有accept新连接，这样就不应影响新连接的处理。当然也有极低的概率阻塞accept（准确来说是刚accept，还没处理完accept后的请求，就又切换到耗时的处理去了，导致这个新accept的请求没得到处理）

**单worker同时会处理多个连接上的所有请求**，accept_mutex 只是控制连接创建的时候哪个worker来accept，避免建连接惊群。连接建立好后这个连接的所有请求就一直会在这个worker上（当然还有其它连接的请求也在这个worker上）。SO_REUSEPORT只是不让worker去抢accept了，改成内核无差别轮询派发。如果这个时候某个连接一直是很耗CPU的请求（比如gzip），会导致这个worker比价卡顿，如果这个gzip能切走也还是可以照顾到别的连接的请求的。

开了reuse_port 之后每个worker 都单独有个syn 队列，能按照nginx worker 数成倍提升抗synflood 攻击能力。

但是开启了SO_REUSEPORT后，内核没法感知你的worker是不是特别忙，只是按Hash逻辑派发accept连接。也就是SO_REUSEPORT会导致rt偏差更大（抖动明显一些）。[这跟MySQL Thread Pool导致的卡顿原理类似，多个Pool类似这里的SO_REUSEPORT。](/2020/06/05/MySQL%E7%BA%BF%E7%A8%8B%E6%B1%A0%E5%AF%BC%E8%87%B4%E7%9A%84%E5%BB%B6%E6%97%B6%E5%8D%A1%E9%A1%BF%E6%8E%92%E6%9F%A5/)

用图形展示大概如下：

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/49d19ef1eaf13638b488ad126beb58ef.png)

比如中间的worker即使处理得很慢，内核还是正常派连接过来，即使其它worker空闲

#### SO_REUSEPORT另外的问题

在OS层面一个连接hash到了某个socket fd，但是正好这个 listen socket fd 被关了，已经被分到这个 listen socket fd 的 accept 队列上的请求会被丢掉，具体可以[参考](https://engineeringblog.yelp.com/2015/04/true-zero-downtime-haproxy-reloads.html ) 和 LWN 上的 [comment](https://lwn.net/Articles/542866/)

从 Linux 4.5 开始引入了 SO_ATTACH_REUSEPORT_CBPF 和 SO_ATTACH_REUSEPORT_EBPF 这两个 BPF 相关的 socket option。通过巧妙的设计，应该可以避免掉建连请求被丢掉的情况。

### EPOLLEXCLUSIVE

epoll引起的accept惊群，在4.5内核中再次引入**EPOLLEXCLUSIVE**来解决，且需要应用层的配合，Ngnix 在 1.11.3 之后添加了NGX_EXCLUSIVE_EVENT来支持。像tengine尚不支持，所以只能在应用层面上来避免惊群，开启accept_mutex才可避免惊群。

在epoll_ctl ADD描述符时设置 EPOLLEXCLUSIVE 标识。 

	epoll_ctl
	ep_insert
	ep_ptable_queue_proc
	    /* 在这里，初始化等待任务，把等待任务加入到socket等待队列的头部 */
	     * 注意，和标准accept的等待任务不同，这里并没有给等待任务设置WQ_FLAG_EXCLUSIVE。
	     */
	    init_waitqueue_func_entry(&pwq->wait, ep_poll_callback);
	    /* 检查应用程序是否设置了EPOLLEXCLUSIVE标识 */
	    if (epi->event.events & EPOLLEXCLUSIVE)
	        /* 新增逻辑，等待任务携带WQ_FLAG_EXCLUSIVE标识，之后只唤醒一个进程 */
	        add_wait_queue_exclusive(whead, &pwq->wait);
	    else
	        /* 原来逻辑，等待任务没有WQ_FLAG_EXCLUSIVE标识，会唤醒所有等待进程 */
	        add_wait_queue(whead, &pwq->wait);

在加入listen socket的sk_sleep队列的唤醒队列里使用了 add_wait_queue_exculsive()函数，当tcp收到三次握手最后一个 ack 报文时调用sock_def_readable时，只唤醒一个等待源，从而避免‘惊群’.
调用栈如下：

	//  tcp_v4_do_rcv()
	//  -->tcp_child_process()
	//  --->sock_def_readable()
	//  ---->wake_up_interruptible_sync_poll()
	//  ----->__wake_up_sync_key()

EPOLLEXCLUSIVE可以在单个Listen Queue对多个Worker Process的时候均衡压力，不会惊群。

![](https://blog.cloudflare.com/content/images/2017/10/worker2.png)

连接从一个队列里由内核分发，不需要惊群，对worker是否忙也能感知（忙的worker就不分发连接过去）

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/9bbf15909be8d1bffd3ee1958463c041.png)

图中的电话机相当于一个worker，只是**实际内核中空闲的worker像是在一个堆栈中（LIFO），有连接过来，worker堆栈会出栈，处理完毕又入栈，如此反复**。而需要处理的消息是一个队列（FIFO），所以总会发现栈顶的几个worker做的事情更多。

#### EPOLLEXCLUSIVE 带来的问题

下面这个case是观察发现Nginx在压力不大的情况下会导致最后几个核cpu消耗时间更多一些，如下图看到的：

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/6551777f24be3da9d2b41ceb20a2b040.png)

这是如前面所述，所有worker像是在一个栈（LIFO）中等着任务处理，在压力不大的时候会导致连接总是在少数几个worker上（栈底的worker没什么机会出栈），如果并发任务多，导致worker栈经常空掉，这个问题就不存在了。当然最终来看EPOLLEXCLUSIVE没有产生什么实质性的不好的影响。值得推荐

epoll的accept模型为LIFO，倾向于唤醒最活跃的进程。多进程场景下：默认的accept(非复用)是FIFO，进程加入到监听socket等待队列的尾部，唤醒时从头部开始唤醒；epoll的accept是LIFO，在epoll_wait时把进程加入到监听socket等待队列的头部，唤醒时从头部开始唤醒。

当并发数较小时，只有最后几个进程会被唤醒，它们使用的CPU时间会远高于其它进程。当并发数较大时，所有的进程都有机会被唤醒，各个进程之间的差距不大。内核社区中关于epoll accept是使用LIFO还是RR有过讨论，在4.9内核和最新版本中使用的都是LIFO。

比如这个case，压力低的worker进程和压力高的worker进程差异比较大：

![](https://blog.cloudflare.com/content/images/2017/10/sharedqueue.png)

### 比较下EPOLLEXCLUSIVE 和 SO_REUSEPORT

EPOLLEXCLUSIVE 和 SO_REUSEPORT 都是在内核层面将连接分到多个worker，解决了epoll下的惊群，SO_REUSEPORT 会更均衡一些，EPOLLEXCLUSIVE在压力不大的时候会导致连接总是在少数几个worker上（但这个不会产生任何不利影响）。 SO_REUSEPORT在最坏的情况下会导致一个worker即使Hang了，OS也依然会派连接过去，这是非常致命的，所以4.5内核引入了 EPOLLEXCLUSIVE（总是给闲置等待队列的第一个worker派连接）

相对 SO_REUSEPORT导致的stuck, EPOLLEXCLUSIV 还是更好接受一些。


## 参考资料

[Linux惊群效应详解（最详细的了吧）](https://blog.csdn.net/lyztyycode/article/details/78648798)

[再谈Linux epoll惊群问题的原因和解决方案](https://blog.csdn.net/dog250/article/details/80837278)

[epoll lifo引发的nginx “负载不均”](https://www.atatech.org/articles/117111) 

[Why does one NGINX worker take all the load?](https://blog.cloudflare.com/the-sad-state-of-linux-socket-balancing/)

[一次Nginx Gzip 导致的诡异健康检查失败问题调查](https://www.atatech.org/articles/89653) 

[Gzip 导致 Nginx worker Hang 问题解法](https://www.atatech.org/articles/174248)

[Socket多进程分发原理](https://www.atatech.org/articles/112471)

[从SO_REUSEPORT服务器的一个弊端看多队列服务模型](https://blog.csdn.net/dog250/article/details/107227145)

https://my.oschina.net/alchemystar/blog/3008840