## tcpdump 抓包卡顿分析

### 背景

在ubuntu 机(192.168.104.4) 上抓包，同时从 192.168.104.1 上执行 ping 192.168.104.4 -c 1 ping 命令很快通了

但在192.168.104.4 上的 tcpdump 要卡很久(几十秒)后才输出几十秒前抓到的包 :(，最一开始以为是自己通过 lima 虚拟化的 ubuntu 机器慢/tcpdump 初始化慢导致的，但是发现等了几十秒后能看到几十秒前抓到的包，感觉有点诡异，所以分析了一下原因。

既然几十秒后能看到几十秒前的包，说明抓包正常，只是哪里卡了，所以用 strace 看看卡在了哪里。

下文用到的主要的 Debug 命令：

```
//-r 打印相对时间
//-s 256 表示--string-limit，设置 limit 为 256，可以显示 sendto(下图黄底) 系统调用完整的 DNS 查询字符串(下图绿线)
strace -r -s 256 tcpdump -i eth0 icmp
```

### 步骤 1

如下图是 strace -r -s 256 tcpdump -i eth0 icmp 命令的输出 ，发现抓到包后对 IP 192.168.104.4 去做了 DNS 解析，而这个解析发给 127.0.0.53 后长时间没有响应，5 秒超时后并重试(下图红框)，导致多次 5 秒超时卡顿：

![image-20241008144023596](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io@_md2zhihu_blog_04540fc6/tcpdump抓包卡顿分析/309455e3e3371a9b-image-20241008144023596.png)

于是在 /etc/hosts 添加 192.168.104.4 localhost 后不再对 192.168.104.4 进行解析，但是仍然会对对端的 IP 192.168.104.1 进行解析：

![image-20241008144145663](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io@_md2zhihu_blog_04540fc6/tcpdump抓包卡顿分析/da9964016e1d405a-image-20241008144145663.png)

上图说明：

-   上图最后一个绿线表示 tcpdump 抓到了 ping 包(ICMP 协议包)
-   \0011\003104\003168\003192 表示：192.168.104.1 ，\0011 前面的 \001 表示 1 位，1 表示 ip 地址值的最后一个 //把整个双引号内容丢给 GPT 会给你一个很好的解释

### 步骤 2

从上面两个图中的 connect 内核函数可以看到每次都把 ip 丢给了 127.0.0.53 这个特殊 IP 来解析，下面是 GPT 给出的解释，我试了下将 DNSStubListener=no(修改配置文件：/etc/systemd/resolved.conf 后执行 systemctl restart systemd-resolved） 后 tcpdump 完全不卡了：

systemd-resolved:

1.  systemd-resolved 是一个系统服务，负责为本地应用程序提供网络名称解析。
1.  它作为一个本地 DNS 解析器和缓存，可以提高 DNS 查询的效率。
1.  systemd-resolved 支持多种 DNS 协议，如 DNSSEC、DNS over TLS 等。
1.  它可以管理多个网络接口的 DNS 设置，适合复杂的网络环境。

DNSStubListener 参数:

1.  DNSStubListener 是 systemd-resolved 的一个功能，默认情况下是启用的（yes）。
1.  当启用时，systemd-resolved 会在本地 127.0.0.53 地址上运行一个 DNS 存根监听器。
1.  这个存根监听器会接收本地应用程序的 DNS 查询请求，然后转发给实际的 DNS 服务器。
1.  当设置 DNSStubListener=no 时：
    -   存根监听器被禁用。
    -   本地应用程序的 DNS 查询将直接发送到配置的 DNS 服务器，而不经过 systemd-resolved

现在 tcpdump 虽然不卡了，但是抓包的时候通过 strace 看到还是会走 DNS 解析流程，这个时候的 DNS 解析都发给了 192.168.104.2:53 (配置在 /etc/resolv.conf 中)，也就是 systemd-resolved 的 127.0.0.53:53 udp 端口虽然在监听，但是不响应任何查询导致了超时，而 192.168.104.2:53 服务正常

这个时候的 strace 日志：

```
     0.000308 socket(AF_INET, SOCK_DGRAM|SOCK_CLOEXEC|SOCK_NONBLOCK, IPPROTO_IP) = 5 //SOCK_DGRAM UDP 模式
     0.000134 setsockopt(5, SOL_IP, IP_RECVERR, [1], 4) = 0
     0.000414 connect(5, {sa_family=AF_INET, sin_port=htons(53), sin_addr=inet_addr("192.168.104.2")}, 16) = 0 //目标主机 192.168.104.2
     0.000373 ppoll([{fd=5, events=POLLOUT}], 1, {tv_sec=0, tv_nsec=0}, NULL, 0) = 1 ([{fd=5, revents=POLLOUT}], left {tv_sec=0, tv_nsec=0})
     0.000348 sendto(5, "e\323\1\0\0\1\0\0\0\0\0\0\0014\003104\003168\003192\7in-addr\4arpa\0\0\f\0\1", 44, MSG_NOSIGNAL, NULL, 0) = 44 //发送 DNS 查询，这里可能会超时等待
     0.000610 ppoll([{fd=5, events=POLLIN}], 1, {tv_sec=5, tv_nsec=0}, NULL, 0) = 1 ([{fd=5, revents=POLLIN}], left {tv_sec=4, tv_nsec=999999042})
     0.000203 ioctl(5, FIONREAD, [44])  = 0
     //这次 0.000136 秒后收到了响应
     0.000136 recvfrom(5, "e\323\201\200\0\1\0\0\0\0\0\0\0014\003104\003168\003192\7in-addr\4arpa\0\0\f\0\1", 1024, 0, {sa_family=AF_INET, sin_port=htons(53), sin_addr=inet_addr("192.168.104.2")}, [28 => 16]) = 44
     0.000462 close(5)                  = 0
     0.000249 write(1, "17:01:20.316738 IP 192.168.104.1 > 192.168.104.4: ICMP echo request, id 31, seq 1, length 64\n", 9317:01:20.316738 IP 192.168.104.1 > 192.168.104.4: ICMP echo request, id 31, seq 1, length 64
) = 93
     0.000306 newfstatat(AT_FDCWD, "/etc/localtime", {st_mode=S_IFREG|0644, st_size=561, ...}, 0) = 0
     0.000269 write(1, "17:01:20.316795 IP 192.168.104.4 > 192.168.104.1: ICMP echo reply, id 31, seq 1, length 64\n", 9117:01:20.316795 IP 192.168.104.4 > 192.168.104.1: ICMP echo reply, id 31, seq 1, length 64
```

### 步骤 3

到这里大概理解这是 tcpdump 引入的 DNS 反查，看了下 tcpdump 帮助完全可以用 -n 参数彻底关闭 DNS 反查 IP：

> tcpdump 命令可以关闭 DNS 反查功能。要禁用 DNS 反查,你可以使用 `-n` 选项;// 我用 tcpdump -n 这么久真没留意这个 -n 具体干啥的，每次都是条件反射写上去的 :(


### 小结

其实很多应用中会偶尔卡顿，网络操作超时就是典型的导致这种卡顿的原因，从 CPU 资源使用率上还发现不了。比如[日常 ssh 连服务器有时候就会卡 30 秒](https://plantegg.github.io/2019/06/02/%E5%8F%B2%E4%B8%8A%E6%9C%80%E5%85%A8_SSH_%E6%9A%97%E9%BB%91%E6%8A%80%E5%B7%A7%E8%AF%A6%E8%A7%A3--%E6%94%B6%E8%97%8F%E4%BF%9D%E5%B9%B3%E5%AE%89/#%E4%B8%BA%E4%BB%80%E4%B9%88%E6%9C%89%E6%97%B6%E5%80%99ssh-%E6%AF%94%E8%BE%83%E6%85%A2%EF%BC%8C%E6%AF%94%E5%A6%82%E6%80%BB%E6%98%AF%E9%9C%80%E8%A6%8130%E7%A7%92%E9%92%9F%E5%90%8E%E6%89%8D%E8%83%BD%E6%AD%A3%E5%B8%B8%E7%99%BB%E5%BD%95)

关于 GSSAPIAuthentication 解释如下，一看也是需要走网络进行授权认证，如果没有配置 kerberos 服务就会卡在网络等待上：

> SSH 中的 GSSAPIAuthentication（Generic Security Services Application Program Interface Authentication）是一种身份验证机制，主要用于实现单点登录（Single Sign-On, SSO）功能。它允许用户在已经通过 Kerberos 认证的环境中，无需再次输入密码就可以登录到支持 GSSAPI 的 SSH 服务器。


类似的网络卡顿/DNS 解析卡顿是很常见的，大家掌握好 Debug 手段。

实际生产中可能没这么好重现也不太好分析，比如我就碰到过 Java 程序都卡在 DNS 解析的问题，Java 中这个 DNS 解析是串行的，所以一般可以通过 jstack 看看堆栈，多个锁窜行等待肯定不正常；多次抓到 DNS 解析肯定也不正常

比如下面这个 jstack 堆栈正常是不应该出现的，如果频繁出现就说明在走 DNS 查机器名啥的

```
"Diagnose@diagnose-2-61" #616 daemon prio=5 os_prio=0 tid=0x00007f7668ba6000 nid=0x2fc runnable [0x00007f75dbea8000]
   java.lang.Thread.State: RUNNABLE
    at java.net.Inet4AddressImpl.lookupAllHostAddr(Native Method)
    at java.net.InetAddress$2.lookupAllHostAddr(InetAddress.java:870)
    at java.net.InetAddress.getAddressesFromNameService(InetAddress.java:1312)
    at java.net.InetAddress$NameServiceAddresses.get(InetAddress.java:818)
    - locked <0x0000000500340c10> (a java.net.InetAddress$NameServiceAddresses)
    at java.net.InetAddress.getAllByName0(InetAddress.java:1301)
    at java.net.InetAddress.getAllByName0(InetAddress.java:1221)
    at java.net.InetAddress.getHostFromNameService(InetAddress.java:640)
    at java.net.InetAddress.getHostName(InetAddress.java:565)
    at java.net.InetAddress.getHostName(InetAddress.java:537)
    at java.net.InetSocketAddress$InetSocketAddressHolder.getHostName(InetSocketAddress.java:82)
    at java.net.InetSocketAddress$InetSocketAddressHolder.access$600(InetSocketAddress.java:56)
    at java.net.InetSocketAddress.getHostName(InetSocketAddress.java:345)
    at io.grpc.internal.ProxyDetectorImpl.detectProxy(ProxyDetectorImpl.java:127)
    at io.grpc.internal.ProxyDetectorImpl.proxyFor(ProxyDetectorImpl.java:118)
    at io.grpc.internal.InternalSubchannel.startNewTransport(InternalSubchannel.java:207)
    at io.grpc.internal.InternalSubchannel.obtainActiveTransport(InternalSubchannel.java:188)
    - locked <0x0000000500344d38> (a java.lang.Object)
    at io.grpc.internal.ManagedChannelImpl$SubchannelImpl.requestConnection(ManagedChannelImpl.java:1130)
    at io.grpc.PickFirstBalancerFactory$PickFirstBalancer.handleResolvedAddressGroups(PickFirstBalancerFactory.java:79)
    at io.grpc.internal.ManagedChannelImpl$NameResolverListenerImpl$1NamesResolved.run(ManagedChannelImpl.java:1032)
    at io.grpc.internal.ChannelExecutor.drain(ChannelExecutor.java:73)
    at io.grpc.internal.ManagedChannelImpl$4.get(ManagedChannelImpl.java:403)
    at io.grpc.internal.ClientCallImpl.start(ClientCallImpl.java:238)

"Check@diagnose-1-107" #849 daemon prio=5 os_prio=0 tid=0x00007f600ee44200 nid=0x3e5 runnable [0x00007f5f12545000]
   java.lang.Thread.State: RUNNABLE
        at java.net.Inet4AddressImpl.lookupAllHostAddr(Native Method)
        at java.net.InetAddress$2.lookupAllHostAddr(InetAddress.java:870)
        at java.net.InetAddress.getAddressesFromNameService(InetAddress.java:1312)
        at java.net.InetAddress$NameServiceAddresses.get(InetAddress.java:818)
        - locked <0x000000063ee00098> (a java.net.InetAddress$NameServiceAddresses)
        at java.net.InetAddress.getAllByName0(InetAddress.java:1301)
        at java.net.InetAddress.getAllByName(InetAddress.java:1154)
        at java.net.InetAddress.getAllByName(InetAddress.java:1075)
        at java.net.InetAddress.getByName(InetAddress.java:1025)
        at *.*.*.*.*.check.Utils.isIPv6(Utils.java:59)
        at *.*.*.*.*.check.checker.AbstractCustinsChecker.getVipCheckPoint(AbstractCustinsChecker.java:189)
        at *.*.*.*.*.*.*.MySQLCustinsChecker.getVipCheckPoint(MySQLCustinsChecker.java:160)
        at *.*.*.*.*.*.*.MySQLCustinsChecker.getCheckPoints(MySQLCustinsChecker.java:133)
        at *.*.*.*.*.check.checker.AbstractCustinsChecker.checkNormal(AbstractCustinsChecker.java:314)
        at *.*.*.*.*.check.checker.CheckExecutorImpl.check(CheckExecutorImpl.java:186)
        at *.*.*.*.*.check.checker.CheckExecutorImpl.lambda$0(CheckExecutorImpl.java:118)
        at *.*.*.*.*.check.checker.CheckExecutorImpl$$Lambda$302/130696248.call(Unknown Source)
        at com.google.common.util.concurrent.TrustedListenableFutureTask$TrustedFutureInterruptibleTask.runInterruptibly(TrustedListenableFutureTask.java:111)
        at com.google.common.util.concurrent.InterruptibleTask.run(InterruptibleTask.java:58)
        at com.google.common.util.concurrent.TrustedListenableFutureTask.run(TrustedListenableFutureTask.java:75)
        at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1149)
        at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:624)
        at java.lang.Thread.run(Thread.java:879)
```

这里以后可以加更多的 DNS 解析卡顿/网络卡顿导致的问题案例……



Reference:

