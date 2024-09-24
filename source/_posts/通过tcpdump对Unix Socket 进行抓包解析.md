---
title:  通过tcpdump对Unix Domain Socket 进行抓包解析
date: 2018-01-01 16:30:03
categories: tcpdump
tags:
    - Linux
    - tcpdump
    - socat
    - Unix-Socket
---

# 通过tcpdump对Unix domain Socket 进行抓包解析

## 背景介绍

大多时候我们可以通过tcpdump对网络抓包分析请求、响应数据来排查问题。但是如果程序是通过Unix Domain Socket方式来访问的那么tcpdump就看不到Unix Domain Socket里面具体流淌的内容了，本文希望找到一种方法达到如同抓包查看网卡内容一样来抓包查看Unix Domain Socket上具体的请求、响应数据。

## socat工具

类似nc，但是是个超级增强版的nc，[主要用作两个独立数据通道之间的双向数据传输的继电器（或者说代理）](https://payloads.online/tools/socat)

基本原理，通过socat在Unix-Socket和TCP/UDP port之间建立一个代理，然后对代理上的端口进行抓包。

以下案例通过对 docker.sock 抓包来分析方案。大多时候我们都可以通过curl 来将http post请求发送到docker deamon所监听的端口，这些请求和响应都可以通过tcpdump抓包分析得到。但是我们通过 docker ps / docker run 将命令发给本地 docker-deamon的时候就是将请求翻译成 http请求发给了 docker.sock, 这个时候如果需要排查问题就没法用tcpdump来分析http内容了。

## 通过socat 启动一个tcp端口来代理Unix Domain Socket

启动本地8080端口，将docker.sock映射到8080端口,8080收到的东西都会转给docker.sock，docker.sock收到的东西都通过抓8080的包看到,但是要求应用访问8080而不是docker.sock。

	socat -d -d TCP-LISTEN:8080,fork,bind=127.0.0.1 UNIX:/var/run/docker.sock

**缺点：需要修改客户端的访问方式**

	sudo curl --unix-socket /var/run/docker.sock http://localhost/images/json

上面的访问方式对8080抓包还是抓不到，因为绕过了我们的代理。

只能通过如下方式访问8080端口，然后请求通过socat代理转发给docker.sock，整个结果跟访问--unix-socket是一样的，这个时候通过8080端口抓包能看到--unix-socket的工作数据

	sudo curl http://localhost:8080/images/json



## 通过socat启动另外一个Unix Domain Socket代理，但是不是tcpdump抓包

	sudo mv /var/run/docker.sock /var/run/docker.sock.original
	sudo socat -t100 -d -x -v UNIX-LISTEN:/var/run/docker.sock,mode=777,reuseaddr,fork UNIX-CONNECT:/var/run/docker.sock.original

优点：客户端访问方式不变，还是直接访问--unix-socket
缺点：输出的数据不如tcpdump方便，也就不能用wireshark来分析了

本质也还是socat代理，只是不是用的一个tcp端口来代理了，而是通过一个unix-socet代理了另外一个unix-socket，直接在代理上输出所有收发的数据

## 完美的办法，客户端不用改访问方式，tcpdump也能抓到数据

	sudo mv /var/run/docker.sock /var/run/docker.sock.original
	sudo socat TCP-LISTEN:8089,reuseaddr,fork UNIX-CONNECT:/var/run/docker.sock.original
	sudo socat UNIX-LISTEN:/var/run/docker.sock,fork TCP-CONNECT:127.0.0.1:8089

然后客户端还是直接访问--unix-socket	
	sudo curl --unix-socket /var/run/docker.sock http://localhost/images/json

这个时候通过tcpdump在8089端口上就能抓到数据了

	sudo tcpdump -i lo -netvv port 8089

实际是结合前面两种方法，做了两次代理，先将socket映射到8089端口上，然后再将8089端口映射到一个新的socket上，最后client访问这个新的socket。

实际流程如下： client -> 新socket -> 8089 -> 原来的socket  这个时候对8089可以任意抓包了

参考来源：[https://mivehind.net/2018/04/20/sniffing-unix-domain-sockets/](https://mivehind.net/2018/04/20/sniffing-unix-domain-sockets/)	
	

## 一些socat的其它用法

 把监听在远程主机12.34.56.78上的mysql服务Unix Domain Socket映射到本地的/var/run/mysqld.temp.sock, 这样就可以用mysql -S /var/run/mysqld/mysqld.sock来访问远程主机的mysql服务了。


    socat "UNIX-LISTEN:/var/run/mysqld.temp.sock,reuseaddr,fork" EXEC:"ssh root@12.34.56.78 socat STDIO UNIX-CONNECT:/var/run/mysqld/mysqld.sock"


 还可以用下面的命令把12.34.56.78上的mysql映射到本地的5500端口，然后使用mysql -p 5500命令访问。

	socat TCP-LISTEN:5500 EXEC:'ssh root@12.34.56.78 "socat STDIO UNIX-CONNECT:/var/run/mysqld/mysqld.sock"'

 把12.34.56.78的udp 161端口映射到本地的1611端口

	socat udp-listen:1611 system:'ssh root@12.34.56.78 "socat stdio udp-connect:remotetarget:161"'	

 通过socat启动server，带有各种参数，比nc更灵活

    Server: socat -dd tcp-listen:2000,keepalive,keepidle=10,keepcnt=2,reuseaddr,keepintvl=1 -
    Client: socat -dd - tcp:localhost:2000,keepalive,keepidle=10,keepcnt=2,keepintvl=1
    
    Drop Connection (Unplug Cable, Shut down Link(WiFi/Interface)): sudo iptables -A INPUT -p tcp --dport 2000 -j DROP

启动本地8080端口，将docker.sock映射到8080端口(docker.sock收到的东西都通过抓8080的包看到)。 8080收到的东西都会转给docker.sock

	socat -d -d TCP-LISTEN:8080,fork,bind=99.13.252.208 UNIX:/var/run/docker.sock

### 用socat远程Unix Domain Socket映射

除了将我们本地服务通过端口映射提供给其它人访问，我们还可以通过端口转发玩一些更high的。比如下面这条命令，它把监听在远程主机12.34.56.78上的mysql服务Unix Domain Socket映射到本地的/var/run/mysqld.temp.sock，这样，小明就可以用mysql -S /var/run/mysqld/mysqld.temp.sock来访问远程主机的mysql服务了。

    socat "UNIX-LISTEN:/var/run/mysqld.temp.sock,reuseaddr,fork" EXEC:"ssh root@12.34.56.78 socat STDIO UNIX-CONNECT\:/var/run/mysqld/mysqld.sock"

当然，小明如果不喜欢本地Unix Domain Socket，他还可以用下面的命令把12.34.56.78上的mysql映射到本地的5500端口，然后使用mysql -p 5500命令访问。

	socat TCP-LISTEN:5500 EXEC:'ssh root@12.34.56.78 "socat STDIO UNIX-CONNECT:/var/run/mysqld/mysqld.sock"'
	
	# 把监听在远程主机12.34.56.78上的mysql服务Unix Domain Socket映射到本地的/var/run/mysqld.temp.sock, 这样就可以用mysql -S /var/run/mysqld/mysqld.sock来访问远程主机的mysql服务了。
	socat "UNIX-LISTEN:/var/run/mysqld.temp.sock,reuseaddr,fork" EXEC:"ssh root@12.34.56.78 socat STDIO UNIX-CONNECT:/var/run/mysqld/mysqld.sock"
	# 还可以用下面的命令把12.34.56.78上的mysql映射到本地
	# 的5500端口，然后使用mysql -p 5500命令访问。
	socat TCP-LISTEN:5500 EXEC:'ssh root@12.34.56.78 "socat STDIO UNIX-CONNECT:/var/run/mysqld/mysqld.sock"'
	# 把12.34.56.78的udp 161端口映射到本地的1611端口：
	socat udp-listen:1611 system:'ssh root@12.34.56.78 "socat stdio udp-connect:remotetarget:161"'

## socat启动网络服务

在一个窗口中启动 `socat` 作为服务端，监听在 1000 端口：

```shell
# start a TCP listener at port 1000, and echo back the received data
$ sudo socat TCP4-LISTEN:1000,fork exec:cat
```

另一个窗口用 `nc` 作为客户端来访问服务端，建立 socket：

```shell
# connect to the local TCP listener at port 1000
$ nc localhost 1000
```

## curl 7.57版本可以直接访问 --unix-socket

7.57之后的版本才支持curl --unix-socket，大大方便了我们的测试

	//Leave 测试断开一个网络
	curl -H "Content-Type: application/json" -X POST -d '{"NetworkID":"47866b0071e3df7e8053b9c8e499986dfe5c9c4947012db2d963c66ca971ed4b","EndpointID":"3d716436e629701d3ce8650e7a85c133b0ff536aed173c624e4f62a381656862"}' --unix-socket /run/docker/plugins/vlan.sock http://localhost/NetworkDriver.Leave
	
	//取镜像列表
	sudo curl --unix-socket /var/run/docker.sock http://localhost/images/json
	
	curl 11.239.155.97:2376/debug/pprof/goroutine?debug=2
	echo -e "GET /debug/pprof/goroutine?debug=2 HTTP/1.1\r\n" | sudo nc -U /run/docker/plugins/vlan.sock
	echo -e "GET /debug/pprof/goroutine?debug=2 HTTP/1.1\r\n" | sudo nc -U /var/run/docker.sock
	//升级curl到7.57后支持 --unix-socket
	sudo curl --unix-socket /var/run/docker.sock http://localh卡路里ost/images/json
	sudo curl --unix-socket /run/docker/plugins/vlan.sock http://localhost/NetworkDriver.GetCapabilities
	//Leave
	curl -H "Content-Type: application/json" -X POST -d '{"NetworkID":"47866b0071e3df7e8053b9c8e499986dfe5c9c4947012db2d963c66ca971ed4b","EndpointID":"3d716436e629701d3ce8650e7a85c133b0ff536aed173c624e4f62a381656862"}' --unix-socket /run/docker/plugins/vlan.sock http://localhost/NetworkDriver.Leave
	
	sudo curl --no-buffer -XGET --unix-socket /var/run/docker.sock http://localhost/events

## [Unix Domain Socket工作原理](https://mp.weixin.qq.com/s/fHzKYlW0WMhP2jxh2H_59A)

接收connect 请求的时候，会申请一个新 socket 给 server 端将来使用，和自己的 socket 建立好连接关系以后，就放到服务器正在监听的 socket 的接收队列中。这个时候，服务器端通过 accept 就能获取到和客户端配好对的新 socket 了。

![Image](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/640-0054201.)

主要的连接操作都是在这个函数中完成的。和我们平常所见的 TCP 连接建立过程，这个连接过程简直是太简单了。没有三次握手，也没有全连接队列、半连接队列，更没有啥超时重传。

直接就是将两个 socket 结构体中的指针互相指向对方就行了。就是 unix_peer(newsk) = sk 和 unix_peer(sk) = newsk 这两句。

```C
//file: net/unix/af_unix.c
static int unix_stream_connect(struct socket *sock, struct sockaddr *uaddr,
          int addr_len, int flags)
{
 struct sockaddr_un *sunaddr = (struct sockaddr_un *)uaddr;

 // 1. 为服务器侧申请一个新的 socket 对象
 newsk = unix_create1(sock_net(sk), NULL);

 // 2. 申请一个 skb，并关联上 newsk
 skb = sock_wmalloc(newsk, 1, 0, GFP_KERNEL);
 ...

 // 3. 建立两个 sock 对象之间的连接
 unix_peer(newsk) = sk;
 newsk->sk_state  = TCP_ESTABLISHED;
 newsk->sk_type  = sk->sk_type;
 ...
 sk->sk_state = TCP_ESTABLISHED;
 unix_peer(sk) = newsk;

 // 4. 把连接中的一头（新 socket）放到服务器接收队列中
 __skb_queue_tail(&other->sk_receive_queue, skb);
}

//file: net/unix/af_unix.c
#define unix_peer(sk) (unix_sk(sk)->peer)
```

收发包过程和复杂的 TCP 发送接收过程相比，这里的发送逻辑简单简单到令人发指。申请一块内存（skb），把数据拷贝进去。根据 socket 对象找到另一端，**直接把 skb 给放到对端的接收队列里了**

![Image](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/640-20211221105837677)

Unix Domain Socket和127.0.0.1通信相比，如果包的大小是1K以内，那么性能会有一倍以上的提升，包变大后性能的提升相对会小一些。

## tcpdump原理

![image.png](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/oss/0923eefc85c1bf87f47591222532f1f2.png)

tcpdump 抓包使用的是 libpcap 这种机制。它的大致原理是：在收发包时，如果该包符合 tcpdump 设置的规则（BPF filter），那么该网络包就会被拷贝一份到 tcpdump 的内核缓冲区，然后以 PACKET_MMAP 的方式将这部分内存映射到 tcpdump 用户空间，解析后就会把这些内容给输出了。

通过上图你也可以看到，在收包的时候，如果网络包已经被网卡丢弃了，那么 tcpdump 是抓不到它的；在发包的时候，如果网络包在协议栈里被丢弃了，比如因为发送缓冲区满而被丢弃，tcpdump 同样抓不到它。我们可以将 tcpdump 的能力范围简单地总结为：网卡以内的问题可以交给 tcpdump 来处理；对于网卡以外（包括网卡上）的问题，tcpdump 可能就捉襟见肘了。这个时候，你需要在对端也使用 tcpdump 来抓包。

### tcpdump 技巧

> tcpdump -B/**--buffer-size=***buffer_size:*Set the operating system capture buffer size to *buffer_size*, in units of KiB (1024 bytes). tcpdump 丢包，造成这种丢包的原因是由于libcap抓到包后，tcpdump上层没有及时的取出，导致libcap缓冲区溢出，从而覆盖了未处理包，此处即显示为**dropped by kernel**，注意，这里的kernel并不是说是被linux内核抛弃的，而是被tcpdump的内核，即 libcap 抛弃掉的

### 获取接口设备列表

tcpdump的`-D`获取接口设备列表。看到此列表后，可以决定要在哪个接口上捕获流量。

```
#tcpdump -D
1.eth0
2.bond0
3.docker0
4.nflog (Linux netfilter log (NFLOG) interface)
5.nfqueue (Linux netfilter queue (NFQUEUE) interface)
6.eth1
7.usbmon1 (USB bus number 1)
8.usbmon2 (USB bus number 2)
9.veth6f2ee76
10.veth8cb61c2
11.veth9d9d363
12.veth16c25ac
13.veth190f0fc
14.veth07103d7
15.veth09119c0
16.veth9770e1a
17.any (Pseudo-device that captures on all interfaces)
18.lo [Loopback]

# tcpdump -X //解析内容
```



## TCP 疑难问题的轻量级分析手段：TCP Tracepoints

Tracepoint 是我分析问题常用的手段之一，在遇到一些疑难问题时，我通常都会把一些相关的 Tracepoint 打开，把 Tracepoint 输出的内容保存起来，然后再在线下环境中分析。通常，我会写一些 Python 脚本来分析这些内容，毕竟 Python 在数据分析上还是很方便的。

对于 TCP 的相关问题，我也习惯使用这些 TCP Tracepoints 来分析问题。要想使用这些 Tracepoints，你的内核版本需要为 **4.16** 及以上。这些常用的 TCP Tracepoints 路径位于 /sys/kernel/debug/tracing/events/tcp/ 和 /sys/kernel/debug/tracing/events/sock/，它们的作用如下表所示：

![image.png](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/oss/32f29686127beb5a3279e630259903ae.png)





## 参考资料：

[https://mivehind.net/2018/04/20/sniffing-unix-domain-sockets/](https://mivehind.net/2018/04/20/sniffing-unix-domain-sockets/)	

[https://superuser.com/questions/484671/can-i-monitor-a-local-unix-domain-socket-like-tcpdump](https://superuser.com/questions/484671/can-i-monitor-a-local-unix-domain-socket-like-tcpdump)

[https://payloads.online/tools/socat](https://payloads.online/tools/socat)

[计算机网络](https://gaia.cs.umass.edu/kurose_ross/wireshark.php)（Computer Networking: A Top-Down Approach）