---
title: epoll的LT和ET
date: 2019-12-09 12:30:03
categories: Linux
tags:
    - 惊群
    - epoll
    - nginx
    - reuseport
    - EPOLLEXCLUSIVE
    - 条件触发
    - 边缘触发
    - LT
    - ET
---

# epoll的LT和ET

- LT水平触发(翻译为 条件触发 更合适） 
>如果事件来了，不管来了几个，只要仍然有未处理的事件，epoll都会通知你。比如来了，打印一行通知，但是不去处理事件，那么会不停滴打印通知。水平触发模式的 epoll 的扩展性很差。

- ET边沿触发 
>
>   如果事件来了，不管来了几个，你若不处理或者没有处理完，除非下一个事件到来，否则epoll将不会再通知你。 比如事件来了，打印一行通知，但是不去处理事件，那么不再通知，除非下个事件来了

LT比ET会多一次重新加入就绪队列的动作，也就是意味着一定有一次poll不到东西，效率是有影响但是队列长度有限所以基本可以不用考虑。但是LT编程方式上要简单多了，所以LT也是默认的。

### 条件触发的问题：不必要的唤醒

1. 内核：收到一个新建连接的请求
2. 内核：由于 "惊群效应" ，唤醒两个正在 epoll_wait() 的线程 A 和线程 B
3. 线程A：epoll_wait() 返回
4. 线程B：epoll_wait() 返回
5. 线程A：执行 accept() 并且成功
6. 线程B：执行 accept() 失败，accept() 返回 EAGAIN

### 边缘触发的问题：不必要的唤醒以及饥饿

不必要的唤醒：

1. 内核：收到第一个连接请求。线程 A 和 线程 B 两个线程都在 epoll_wait() 上等待。由于采用边缘触发模式，所以只有一个线程会收到通知。这里假定线程 A 收到通知
2. 线程A：epoll_wait() 返回
3. 线程A：调用 accpet() 并且成功
4. 内核：此时 accept queue 为空，所以将边缘触发的 socket 的状态从可读置成不可读
5. 内核：收到第二个建连请求
6. 内核：此时，由于线程 A 还在执行 accept() 处理，只剩下线程 B 在等待 epoll_wait()，于是唤醒线程 B
7. 线程A：继续执行 accept() 直到返回 EAGAIN
8. 线程B：执行 accept()，并返回 EAGAIN，此时线程 B 可能有点困惑("明明通知我有事件，结果却返回 EAGAIN")
9. 线程A：再次执行 accept()，这次终于返回 EAGAIN

饥饿：

1. 内核：接收到两个建连请求。线程 A 和 线程 B 两个线程都在等在 epoll_wait()。由于采用边缘触发模式，只有一个线程会被唤醒，我们这里假定线程 A 先被唤醒
2. 线程A：epoll_wait() 返回
3. 线程A：调用 accpet() 并且成功
4. 内核：收到第三个建连请求。由于线程 A 还没有处理完(没有返回 EAGAIN)，当前 socket 还处于可读的状态，由于是边缘触发模式，所有不会产生新的事件
5. 线程A：继续执行 accept() 希望返回 EAGAIN 再进入 epoll_wait() 等待，然而它又 accept() 成功并处理了一个新连接
6. 内核：又收到了第四个建连请求
7. 线程A：又继续执行 accept()，结果又返回成功


ET的话会要求应用一直要把消息处理完毕，比如nginx用ET模式，来了一个上传大文件并压缩的任务，会造成这么一个循环：

> nginx读数据（未读完）->Gzip(需要时间，套接字又有数据过来)->读数据（未读完）->Gzip .....

新的accpt进来，因为前一个nginx worker已经被唤醒并且还在read(这个时候内核因为accept queue为空所以已经将socket设置成不可读），所以即使其它worker 被唤醒，看到的也是一个不可读的socket，所以很快因为EAGAIN返回了。

这样就会造成nginx的这个worker假死了一样。如果上传速度慢，这个循环无法持续存在，也就是一旦读完nginx切走（再有数据进来等待下次触发），不会造成假死。

JDK中的NIO是条件触发（level-triggered），不支持ET。netty，nginx和redis默认是边缘触发（edge-triggered），netty因为JDK不支持ET，所以自己实现了Netty-native的抽象，不依赖JDK来提供ET。

边缘触发会比条件触发更高效一些，因为边缘触发不会让同一个文件描述符多次被处理,比如有些文件描述符已经不需要再读写了,但是在条件触发下每次都会返回,而边缘触发只会返回一次。

如果设置边缘触发,则必须将对应的文件描述符设置为非阻塞模式并且循环读取数据。否则会导致程序的效率大大下降或丢消息。

poll和epoll默认采用的都是条件触发,只是epoll可以修改成边缘触发。条件触发同时支持block和non-block，使用更简单一些。

### epoll LT惊群的发生

```c
// 否则会阻塞在IO系统调用，导致没有机会再epoll
set_socket_nonblocking(sd);
epfd = epoll_create(64);
event.data.fd = sd;
epoll_ctl(epfd, EPOLL_CTL_ADD, sd, &event);
while (1) {
    epoll_wait(epfd, events, 64, xx);
    ... // 危险区域！如果有共享同一个epfd的进程/线程调用epoll_wait，它们也将会被唤醒！
    // 这个accept将会有多个进程/线程调用，如果并发请求数很少，那么将仅有几个进程会成功：
    // 1. 假设accept队列中有n个请求，则仅有n个进程能成功，其它将全部返回EAGAIN (Resource temporarily unavailable)
    // 2. 如果n很大(即增加请求负载)，虽然返回EAGAIN的比率会降低，但这些进程也并不一定取到了epoll_wait返回当下的那个预期的请求。
    csd = accept(sd, &in_addr, &in_len); 
    ...
}
```

再看一遍LT的描述“如果事件来了，不管来了几个，只要仍然有未处理的事件，epoll都会通知你。”，显然，epoll_wait刚刚取到事件的时候的时候，不可能马上就调用accept去处理，事实上，逻辑在epoll_wait函数调用的ep_poll中还没返回的，这个时候，显然符合“仍然有未处理的事件”这个条件，显然这个时候为了实现这个语义，需要做的就是通知别的同样阻塞在同一个epoll句柄睡眠队列上的进程！在实现上，这个语义由两点来保证：

保证1：在LT模式下，“就绪链表”上取出的epi上报完事件后会重新加回“就绪链表”；
保证2：如果“就绪链表”不为空，且此时有进程阻塞在同一个epoll句柄的睡眠队列上，则唤醒它。

epoll LT模式下有进程被不必要唤醒，这一点并不是内核无意而为之的，内核肯定是知道这件事的，这个并不像之前accept惊群那样算是内核的一个缺陷。epoll LT模式只是提供了一种模式，误用这种模式将会造成类似惊群那样的效应。但是不管怎么说，为了讨论上的方便，后面我们姑且将这种效应称作epoll LT惊群吧。

### epoll ET模式可以解决上面的问题，但是带来了新的麻烦

由于epi entry的callback即ep_poll_callback所做的事情仅仅是将该epi自身加入到epoll句柄的“就绪链表”，同时唤醒在epoll句柄睡眠队列上的task，所以这里并不对事件的细节进行计数，比如说，**如果ep_poll_callback在将一个epi加入“就绪链表”之前发现它已经在“就绪链表”了，那么就不会再次添加，因此可以说，一个epi可能pending了多个事件，注意到这点非常重要！**

一个epi上pending多个事件，这个在LT模式下没有任何问题，因为获取事件的epi总是会被重新添加回“就绪链表”，那么如果还有事件，在下次check的时候总会取到。然而对于ET模式，仅仅将epi从“就绪链表”删除并将事件本身上报后就返回了，因此如果该epi里还有事件，则只能等待再次发生事件，进而调用ep_poll_callback时将该epi加入“就绪队列”。这意味着什么？

这意味着，应用程序，即epoll_wait的调用进程必须自己在获取事件后将其处理干净后方可再次调用epoll_wait，否则epoll_wait不会返回，而是必须等到下次产生事件的时候方可返回。这会导致事件堆积，所以一般会死循环一直拉取事件，直到拉取不到了再返回。



## 参考资料

[Epoll is fundamentally broken](https://www.atatech.org/articles/157349) 

[Epoll is fundamentally broken 1/2](https://idea.popcount.org/2017-02-20-epoll-is-fundamentally-broken-12) 