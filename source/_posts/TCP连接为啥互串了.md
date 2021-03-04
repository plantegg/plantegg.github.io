---
title: 活久见，TCP连接互串了
date: 2020-11-18 17:30:03
categories:
    - TCP
tags:
    - Linux
    - TCP
    - network
    - reset
---

# 活久见，TCP连接互串了

## 背景

应用每过一段时间总是会抛出几个连接异常的错误，需要查明原因。

排查后发现是TCP连接互串了，这个案例实在是很珍惜，所以记录一下。

## 抓包

业务结构： 应用->MySQL(10.112.61.163)

在 应用 机器上抓包这个异常连接如下（3269为MySQL服务端口）：

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/dd657fee9d961a786c05e8d3cccbc297.png)

粗一看没啥奇怪的，就是应用发查询给3269，但是一直没收到3269的ack，所以一直重传。这里唯一的解释就是网络不通。最后MySQL的3269还回复了一个rst，这个rst的id是42889，引起了我的好奇，跟前面的16439不连贯，正常应该是16440才对。（请记住上图中的绿框中的数字）

于是我过滤了一下端口61902上的所有包：

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/8ca7da8ccec0041dd5d3f66f94d1f574.png)

可以看到绿框中的查询从61902端口发给3269后，很奇怪居然收到了一个来自别的IP+3306端口的reset，这个包对这个连接来说自然是不认识（这个连接只接受3269的回包），就扔掉了。但是也没收到3269的ack，所以只能不停地重传，然后每次都收到3306的reset，reset包的seq、id都能和上图的绿框对应上。

明明他们应该是两个连接：

>  61902->10.141.16.0:3306
>
>  61902->10.112.61.163:3269

他们虽然用的本地ip端口（61902）是一样的， 但是根据四元组不一样，还是不同的TCP连接，所以应该是不会互相干扰的。但是实际看起来**seq、id都重复了**，不会有这么巧，非常像是TCP互串了。

## 分析原因

10.141.16.0 这个ip看起来像是lvs的ip，查了一下系统，果然是lvs，然后这个lvs 后面的rs就是10.112.61.163

那么这个连结构就是10.141.16.0:3306：

> 应用 -> lvs(10.141.16.0:3306)-> 10.112.61.163:3269  跟应用直接连MySQL是一回事了

所以这里的疑问就变成了：**10.141.16.0 这个IP的3306端口为啥能知道 10.112.61.163:3269端口的seq和id，也许是TCP连接串了**

接着往下排查

### [先打个岔，分析下这里的LVS的原理](https://plantegg.github.io/2019/06/20/就是要你懂负载均衡--lvs和转发模式/)

这里使用的是 full NAT模型(full NetWork Address Translation-全部网络地址转换)

基本流程（类似NAT）：

1. client发出请求（sip 200.200.200.2 dip 200.200.200.1）
2. 请求包到达lvs，lvs修改请求包为**（sip 200.200.200.1， dip rip）** 注意这里sip/dip都被修改了
3. 请求包到达rs， rs回复（sip rip，dip 200.200.200.1）
4. 这个回复包的目的IP是VIP(不像NAT中是 cip)，所以LVS和RS不在一个vlan通过IP路由也能到达lvs
5. lvs修改sip为vip， dip为cip，修改后的回复包（sip 200.200.200.1，dip 200.200.200.2）发给client

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/94d55b926b5bb1573c4cab8353428712.png)

**注意上图中绿色的进包和红色的出包他们的地址变化**

本来这个模型下都是正常的，但是为了Real Server能拿到client ip，也就是Real Server记录来源ip的时候希望记录的是client ip而不是LVS ip。这个时候LVS会将client ip放在tcp的options里面，然后在RealServer机器的内核里面将options中的client ip取出替换掉 lvs ip。所以Real Server上感知到的对端ip就是client ip。

回包的时候RealServer上的内核模块同样将目标地址从client ip改成lvs ip，同时将client ip放入options中。



## 回到问题

看完理论，再来分析这两个连接的行为

fulnat模式下连接经过lvs到达mysql后，mysql上看到的连接信息是，cip+port，也就是在MySQL上的连接

**lvs-ip:port -> 10.112.61.163:3269  被修改成了 **client-ip:61902 **-> 10.112.61.163:3269

那么跟不走LVS的连接：

**client-ip:61902 ->  10.112.61.163:3269 (直连) 完全重复了。**

MySQL端看到的两个连接四元组一模一样了：

> 10.112.61.163:3269 -> client-ip:61902 (走LVS，本来应该是lvs ip的，但是被替换成了client ip) 
>
> 10.112.61.163:3269 -> client-ip:61902 (直连) 

这个时候应用端看到的还是两个连接：

> client-ip:61902 -> 10.141.16.0:3306 （走LVS） 
>
> client-ip:61902 ->  10.112.61.163:3269 (直连) 

总结下，也就是这个连接经过LVS转换后在服务端（MYSQL）跟直连MySQL的连接四元组完全重复了，也就是MySQL会认为这两个连接就是同一个连接，所以必然出问题了。

实际两个连接建立的情况：

>  和mysqlserver的61902是04:22建起来的，和lvs的61902端口 是42:10建起来的，和lvs的61902建起来之后马上就出问题了

## 问题出现的条件

- fulnat模式的LVS，RS上装有slb_toa内核模块（RS上会将LVS ip还原成client ip）
- client端正好重用一个相同的本地端口分别和RS以及LVS建立了两个连接

这个时候这两个连接在MySQL端就会变成一个，然后两个连接的内容互串，必然导致rst

这个问题还挺有意思的，估计没几个程序员一辈子能碰上一次。推荐另外一个好玩的连接：[如何创建一个自己连自己的TCP连接](https://plantegg.github.io/2020/07/01/如何创建一个自己连自己的TCP连接/)

## 一台机器上最多能创建多少个TCP连接 ip_local_port_range

在内存、文件句柄足够的话可以创建的连接是没有限制的，那么/proc/sys/net/ipv4/ip_local_port_range指定的端口范围到底是什么意思呢？

一个TCP连接只要保证四元组(src-ip src-port dest-ip dest-port)唯一就可以了，而不是要求src port唯一.

一台机器能创建的TCP连接是没有限制的，而ip_local_port_range是指没有bind的时候OS随机分配端口的范围，但是分配到的端口要同时满足五元组唯一，这样 ip_local_port_range 限制的是连同一个目标（dest-ip和dest-port一样）的port的数量（请忽略本地多网卡的情况，因为dest-ip为以后route只会选用一个本地ip）。

但是如果程序调用的是bind函数(bind(ip,port=0))这个时候是让系统绑定到某个网卡和自动分配的端口，此时系统没有办法确定接下来这个socket是要去connect还是listen. 如果是listen的话，那么肯定是不能出现端口冲突的，如果是connect的话，只要满足4元组唯一即可。在这种情况下，系统只能尽可能满足更强的要求，就是先要求端口不能冲突，即使之后去connect的时候4元组是唯一的。

bind()的时候内核是还不知道四元组的，只知道src_ip、src_port，所以这个时候单网卡下src_port是没法重复的，但是connect()的时候已经知道了四元组的全部信息，所以只要保证四元组唯一就可以了，那么这里的src_port完全是可以重复使用的。

### [The Ephemeral Port Range](http://www.ncftp.com/ncftpd/doc/misc/ephemeral_ports.html#Windows)

> A TCP/IPv4 connection consists of two endpoints, and each endpoint consists of an IP address and a port number. Therefore, when a client user connects to a server computer, an established connection can be thought of as the 4-tuple of (server IP, server port, client IP, client port).
>
> Usually three of the four are readily known -- client machine uses its own IP address and when connecting to a remote service, the server machine's IP address and service port number are required.
>
> What is not immediately evident is that when a connection is established that the client side of the connection uses a port number. Unless a client program explicitly requests a specific port number, the port number used is an ephemeral port number.
>
> Ephemeral ports are temporary ports assigned by a machine's IP stack, and are assigned from a designated range of ports for this purpose. When the connection terminates, the ephemeral port is available for reuse, although most IP stacks won't reuse that port number until the entire pool of ephemeral ports have been used.
>
> So, if the client program reconnects, it will be assigned a different ephemeral port number for its side of the new connection.



### linux 如何选择Ephemeral Port

如下测试代码：

```
#include <stdio.h>      // printf
#include <stdlib.h>     // atoi
#include <unistd.h>     // close
#include <arpa/inet.h>  // ntohs
#include <sys/socket.h> // connect, socket

void sample() {
    // Create socket
    int sockfd;
    if (sockfd = socket(AF_INET, SOCK_STREAM, 0), -1 == sockfd) {
        perror("socket");
    }

    // Connect to remote. This does NOT actually send a packet.
    const struct sockaddr_in raddr = {
        .sin_family = AF_INET,
        .sin_port   = htons(8080),     // arbitrary remote port
        .sin_addr   = htonl(INADDR_ANY)  // arbitrary remote host
    };
    if (-1 == connect(sockfd, (const struct sockaddr *)&raddr, sizeof(raddr))) {
        perror("connect");
    }

    // Display selected ephemeral port
    const struct sockaddr_in laddr;
    socklen_t laddr_len = sizeof(laddr);
    if (-1 == getsockname(sockfd, (struct sockaddr *)&laddr, &laddr_len)) {
        perror("getsockname");
    }
    printf("local port: %i\n", ntohs(laddr.sin_port));

    // Close socket
    close(sockfd);
}

int main() {
    for (int i = 0; i < 5; i++) {
        sample();
    }

    return 0;
}
```

编译后，执行(3.10.0-327.ali2017.alios7.x86_64)：

```
#date; ./client && echo "+++++++" ; ./client && sleep 0.1 ; echo "-------" && ./client && sleep 10; date; ./client && echo "+++++++" ; ./client && sleep 0.1 && echo "******"; ./client;
Fri Nov 27 10:52:52 CST 2020
local port: 17448
local port: 17449
local port: 17451
local port: 17452
local port: 17453
+++++++
local port: 17455
local port: 17456
local port: 17457
local port: 17458
local port: 17460
-------
local port: 17475
local port: 17476
local port: 17477
local port: 17478
local port: 17479
Fri Nov 27 10:53:02 CST 2020
local port: 17997
local port: 17998
local port: 17999
local port: 18000
local port: 18001
+++++++
local port: 18002
local port: 18003
local port: 18004
local port: 18005
local port: 18006
******
local port: 18010
local port: 18011
local port: 18012
local port: 18013
local port: 18014
```

从测试看起来linux下端口选择跟时间有关系，起始端口肯定是顺序增加，起始端口应该是在Ephemeral Port范围内并且和时间戳绑定的某个值（也是递增的），即使没有使用任何端口，起始端口也会随时间增加而增加。

编译后，执行(4.19.91-19.1.al7.x86_64)：

```
$date; ./client && echo "+++++++" ; ./client && sleep 0.1 ; echo "-------" && ./client && sleep 10; date; ./client && echo "+++++++" ; ./client && sleep 0.1 && echo "******"; ./client;
Fri Nov 27 14:10:47 CST 2020
local port: 7890
local port: 7892
local port: 7894
local port: 7896
local port: 7898
+++++++
local port: 7900
local port: 7902
local port: 7904
local port: 7906
local port: 7908
-------
local port: 7910
local port: 7912
local port: 7914
local port: 7916
local port: 7918
Fri Nov 27 14:10:57 CST 2020
local port: 7966
local port: 7968
local port: 7970
local port: 7972
local port: 7974
+++++++
local port: 7976
local port: 7978
local port: 7980
local port: 7982
local port: 7984
******
local port: 7988
local port: 7990
local port: 7992
local port: 7994
local port: 7996
```

之所以都是偶数端口，是因为port_range 从偶数开始：

```
$cat /proc/sys/net/ipv4/ip_local_port_range
1024    65535
```

将1024改成1025后，分配出来的都是奇数端口了：

```
$cat /proc/sys/net/ipv4/ip_local_port_range
1025    1034

$./client
local port: 1033
local port: 1025
local port: 1027
local port: 1029
local port: 1031
local port: 1033
local port: 1025
local port: 1027
local port: 1029
local port: 1031
local port: 1033
local port: 1025
local port: 1027
local port: 1029
local port: 1031
```



## 参考资料

[就是要你懂负载均衡--lvs和转发模式](https://plantegg.github.io/2019/06/20/就是要你懂负载均衡--lvs和转发模式/)

https://idea.popcount.org/2014-04-03-bind-before-connect/

[no route to host](https://github.com/kubernetes/kubernetes/issues/81775 )

[另一种形式的tcp连接互串，新连接重用了time_wait的port，导致命中lvs内核表中的维护的旧连接发给了老的realserver](https://zhuanlan.zhihu.com/p/127099484)

