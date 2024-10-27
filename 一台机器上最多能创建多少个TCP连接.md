
# 到底一台服务器上最多能创建多少个TCP连接

> 经常听到有同学说一台机器最多能创建65535个TCP连接，这其实是错误的理解，为什么会有这个错误的理解呢？


## port range

我们都知道linux下本地随机端口范围由参数控制，也就是listen、connect时候如果没有指定本地端口，那么就从下面的port range中随机取一个可用的

```
# cat /proc/sys/net/ipv4/ip_local_port_range 
2000	65535
```

port range的上限是65535，所以也经常看到这个**误解**：一台机器上最多能创建65535个TCP连接

## 到底一台机器上最多能创建多少个TCP连接

先说**结论**：在内存、文件句柄足够的话可以创建的连接是**没有限制**的（每个TCP连接至少要消耗一个文件句柄）。

那么/proc/sys/net/ipv4/ip_local_port_range指定的端口范围到底是什么意思呢？

核心规则：**一个TCP连接只要保证四元组(src-ip src-port dest-ip dest-port)唯一就可以了，而不是要求src port唯一**

后面所讲都遵循这个规则，所以在心里反复默念：**四元组唯一** 五个大字，就能分析出来到底能创建多少TCP连接了。

比如如下这个机器上的TCP连接实际状态：

```
# netstat -ant |grep 18089
tcp        0      0 192.168.1.79:18089      192.168.1.79:22         ESTABLISHED
tcp        0      0 192.168.1.79:18089      192.168.1.79:18080      ESTABLISHED
tcp        0      0 192.168.0.79:18089      192.168.0.79:22         TIME_WAIT 
tcp        0      0 192.168.1.79:22         192.168.1.79:18089      ESTABLISHED
tcp        0      0 192.168.1.79:18080      192.168.1.79:18089      ESTABLISHED
```

从前三行可以清楚地看到18089被用了三次，第一第二行src-ip、dest-ip也是重复的，但是dest port不一样，第三行的src-port还是18089，但是src-ip变了。他们的四元组均不相同。

所以一台机器能创建的TCP连接是没有限制的，而ip_local_port_range是指没有bind的时候OS随机分配端口的范围，但是分配到的端口要同时满足五元组唯一，这样 ip_local_port_range 限制的是连同一个目标（dest-ip和dest-port一样）的port的数量（请忽略本地多网卡的情况，因为dest-ip为以后route只会选用一个本地ip）。

**那么为什么大家有这样的误解呢？**我总结了下，大概是以下两个原因让大家误解了：

-   如果是listen服务，那么肯定端口不能重复使用，这样就跟我们的误解对应上了，一个服务器上最多能监听65535个端口。比如nginx监听了80端口，那么tomcat就没法再监听80端口了，这里的80端口只能监听一次（如果有个连接用了80连别人，这里80还是不能被listen……想想）。
-   另外如果我们要连的server只有一个，比如：1.1.1.1:80 ，同时本机只有一个ip的话，那么这个时候即使直接调connect 也只能创建出65535个连接，因为四元组中的三个是固定的了。

我们在创建连接前，经常会先调bind，bind后可以调listen当做服务端监听，也可以直接调connect当做client来连服务端。

bind(ip,port=0) 的时候是让系统绑定到某个网卡和自动分配的端口，此时系统没有办法确定接下来这个socket是要去connect还是listen. 如果是listen的话，那么肯定是不能出现端口冲突的，如果是connect的话，只要满足4元组唯一即可。在这种情况下，系统只能尽可能满足更强的要求，就是先要求端口不能冲突，即使之后去connect的时候四元组是唯一的。

但如果我只是个client端，只需要连接server建立连接，也就不需要bind，直接调connect就可以了，这个时候只要保证四元组唯一就行。

bind()的时候内核是还不知道四元组的，只知道src_ip、src_port，所以这个时候单网卡下src_port是没法重复的，但是connect()的时候已经知道了四元组的全部信息，所以只要保证四元组唯一就可以了，那么这里的src_port完全是可以重复使用的。

![Image](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/一台机器上最多能创建多少个TCP连接/b49c1a0210179b37-640-20220224103024676.png)

**是不是加上了 SO_REUSEADDR、SO_REUSEPORT 就能重用端口了呢？**

## TCP SO_REUSEADDR

文档描述：

> SO_REUSEADDR      Indicates that the rules used in validating addresses supplied in a bind(2) call should allow reuse of local addresses.  For AF_INET sockets this means that a socket may bind, except when there is an active listening socket bound to the address. When the listening socket is bound to INADDR_ANY with a specific port then it is not possible to bind to this port for any local address.  Argument is an integer boolean flag.


从这段文档中我们可以知道三个事：

1.  使用这个参数后，bind操作是可以重复使用local address的，注意，这里说的是local address，即ip加端口组成的本地地址，也就是两个本地地址，如果有任意ip或端口部分不一样，它们本身就是可以共存的，不需要使用这个参数。
1.  当local address被一个处于listen状态的socket使用时，加上该参数也不能重用这个地址。
1.  当处于listen状态的socket监听的本地地址的ip部分是INADDR_ANY，即表示监听本地的所有ip，即使使用这个参数，也不能再bind包含这个端口的任意本地地址，这个和 2 中描述的其实是一样的。

==SO_REUSEADDR 可以用本地相同的(sip, sport) 去连connect 远程的不同的（dip、dport）//而 SO_REUSEPORT主要是解决Server端的port重用==

[SO_REUSEADDR 还可以重用TIME_WAIT状态的port](https://mp.weixin.qq.com/s/YWzuKBK3TMclejeN2ziAvQ), 在程序崩溃后之前的TCP连接会进入到TIME_WAIT状态，需要一段时间才能释放，如果立即重启就会抛出<u>Address Already in use</u>的错误导致启动失败。这时候可以通过在调用bind函数之前设置SO_REUSEADDR来解决。

> What exactly does SO_REUSEADDR do?
> 
> This socket option tells the kernel that even if this port is busy (in the TIME_WAIT state), go ahead and reuse it anyway. If it is busy, but with another state, you will still get an address already in use error. It is useful if your server has been shut down, and then restarted right away while sockets are still active on its port. You should be aware that if any unexpected data comes in, it may confuse your server, but while this is possible, it is not likely.
> 
> It has been pointed out that "A socket is a 5 tuple (proto, local addr, local port, remote addr, remote port). SO_REUSEADDR just says that you can reuse local addresses. The 5 tuple still must be unique!" This is true, and this is why it is very unlikely that unexpected data will ever be seen by your server. The danger is that such a 5 tuple is still floating around on the net, and while it is bouncing around, a new connection from the same client, on the same system, happens to get the same remote port.


By setting `SO_REUSEADDR` user informs the kernel of an intention to share the bound port with anyone else, but only if it doesn't cause a conflict on the protocol layer. There are at least three situations when this flag is useful:

1.  Normally after binding to a port and stopping a server it's neccesary to wait for a socket to time out before another server can bind to the same port. With `SO_REUSEADDR` set it's possible to rebind immediately, even if the socket is in a `TIME_WAIT` state.
1.  When one server binds to `INADDR_ANY`, say `0.0.0.0:1234`, it's impossible to have another server binding to a specific address like `192.168.1.21:1234`. With `SO_REUSEADDR` flag this behaviour is allowed.
1.  When using the bind before connect trick only a single connection can use a single outgoing source port. With this flag, it's possible for many connections to reuse the same source port, given that they connect to different destination addresses.

## TCP SO_REUSEPORT

SO_REUSEPORT主要用来解决惊群、性能等问题。通过多个进程、线程来监听同一端口，进来的连接通过内核来hash分发做到负载均衡，避免惊群。

> SO_REUSEPORT is also useful for eliminating the try-10-times-to-bind hack in ftpd's data connection setup routine.  Without SO_REUSEPORT, only one ftpd thread can bind to TCP (lhost, lport, INADDR_ANY, 0) in preparation for connecting back to the client.  Under conditions of heavy load, there are more threads colliding here than the try-10-times hack can accomodate.  With SO_REUSEPORT, things  work nicely and the hack becomes unnecessary.


SO_REUSEPORT使用场景：linux kernel 3.9 引入了最新的SO_REUSEPORT选项，使得多进程或者多线程创建多个绑定同一个ip:port的监听socket，提高服务器的接收链接的并发能力,程序的扩展性更好；此时需要设置SO_REUSEPORT（**注意所有进程都要设置才生效**）。

setsockopt(listenfd, SOL_SOCKET, SO_REUSEPORT,(const void *)&reuse , sizeof(int));

目的：每一个进程有一个独立的监听socket，并且bind相同的ip:port，独立的listen()和accept()；提高接收连接的能力。（例如nginx多进程同时监听同一个ip:port）

> (a) on Linux SO_REUSEPORT is meant to be used *purely* for load balancing multiple incoming UDP packets or incoming TCP connection requests across multiple sockets belonging to the same app.  ie. it's a work around for machines with a lot of cpus, handling heavy load, where a single listening socket becomes a bottleneck because of cross-thread contention on the in-kernel socket lock (and state).
> 
> (b) set IP_BIND_ADDRESS_NO_PORT socket option for tcp sockets before binding to a specific source ip
> with port 0 if you're going to use the socket for connect() rather then listen() this allows the kernel
> to delay allocating the source port until connect() time at which point it is much cheaper


## [The Ephemeral Port Range](http://www.ncftp.com/ncftpd/doc/misc/ephemeral_ports.html)

Ephemeral Port Range就是我们前面所说的Port Range（/proc/sys/net/ipv4/ip_local_port_range）

> A TCP/IPv4 connection consists of two endpoints, and each endpoint consists of an IP address and a port number. Therefore, when a client user connects to a server computer, an established connection can be thought of as the 4-tuple of (server IP, server port, client IP, client port).
> 
> Usually three of the four are readily known -- client machine uses its own IP address and when connecting to a remote service, the server machine's IP address and service port number are required.
> 
> What is not immediately evident is that when a connection is established that the client side of the connection uses a port number. Unless a client program explicitly requests a specific port number, the port number used is an ephemeral port number.
> 
> Ephemeral ports are temporary ports assigned by a machine's IP stack, and are assigned from a designated range of ports for this purpose. When the connection terminates, the ephemeral port is available for reuse, although most IP stacks won't reuse that port number until the entire pool of ephemeral ports have been used.
> 
> So, if the client program reconnects, it will be assigned a different ephemeral port number for its side of the new connection.


## linux 如何选择Ephemeral Port

有资料说是随机从Port Range选择port，有的说是顺序选择，那么实际验证一下。

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

bind逻辑测试代码

```
#include <netinet/in.h>
#include <arpa/inet.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <time.h>

void test_bind(){
    int listenfd = 0, connfd = 0;
    struct sockaddr_in serv_addr;
    char sendBuff[1025];
    time_t ticks;
      socklen_t len;

    listenfd = socket(AF_INET, SOCK_STREAM, 0);
    memset(&serv_addr, '0', sizeof(serv_addr));
    memset(sendBuff, '0', sizeof(sendBuff));

    serv_addr.sin_family = AF_INET;
    serv_addr.sin_addr.s_addr = htonl(INADDR_ANY);
    serv_addr.sin_port = htons(0);

    bind(listenfd, (struct sockaddr*)&serv_addr, sizeof(serv_addr));

    len = sizeof(serv_addr);
      if (getsockname(listenfd, (struct sockaddr *)&serv_addr, &len) == -1) {
    	      perror("getsockname");
    		    return;
      }
      printf("port number %d\n", ntohs(serv_addr.sin_port)); //只是挑选到了port，在系统层面保留，tcp连接还没有，netstat是看不到的
}

int main(int argc, char *argv[])
{
        for (int i = 0; i < 5; i++) {
    		         test_bind();
    				     }
    	    return 0;
}
```

### 3.10.0-327.ali2017.alios7.x86_64

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

### 4.19.91-19.1.al7.x86_64

换个内核版本编译后，执行(4.19.91-19.1.al7.x86_64)：

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

以上测试时的参数

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

之所以都是偶数端口，是因为port_range 从偶数开始, 每次从++变到+2的[原因](https://github.com/plantegg/linux/commit/1580ab63fc9a03593072cc5656167a75c4f1d173)，connect挑选随机端口时都是在起始端口的基础上+2，而bind挑选随机端口的起始端口是系统port_range起始端口+1（这样和connect错开），然后每次仍然尝试+2，这样connect和bind基本一个用偶数另外一个就用奇数，一旦不够了再尝试使用另外一组

```
$cat /proc/sys/net/ipv4/ip_local_port_range
1024    1047

$./bind &  ---bind程序随机挑选5个端口
port number 1039
port number 1043
port number 1045
port number 1041
port number 1047  --用完所有奇数端口

$./bind &    --继续挑选偶数端口
[8] 4170
port number 1044
port number 1042
port number 1046
port number 0    --实在没有了
port number 0
```

可见4.19内核下每次port是+2，在3.10内核版本中是+1. 并且都是递增的，同时即使port不使用，也会随着时间的变化这个起始port增大。

Port Range有点像雷达转盘数字，时间就像是雷达上的扫描指针，这个指针不停地旋转，如果这个时候刚好有应用要申请Port，那么就从指针正好指向的Port开始向后搜索可用port

## tcp_max_tw_buckets

tcp_max_tw_buckets: 在 TIME_WAIT 数量等于 tcp_max_tw_buckets 时，新的连接断开不再进入TIME_WAIT阶段，而是直接断开，并打印warnning.

实际测试发现 在 TIME_WAIT 数量等于 tcp_max_tw_buckets 时 新的连接仍然可以不断地创建和断开，这个参数大小不会影响性能，只是影响TIME_WAIT 数量的展示（当然 TIME_WAIT 太多导致local port不够除外）, 这个值设置小一点会避免出现端口不够的情况

> tcp_max_tw_buckets - INTEGER
>    Maximal number of timewait sockets held by system simultaneously.If this number is exceeded time-wait socket is immediately destroyed and warning is printed. This limit exists only to prevent simple DoS attacks, you *must* not lower the limit artificially, but rather increase it (probably, after increasing installed memory), if network conditions require more than default value.

### 

## 为什么要有 time_wait 状态

> TIME-WAIT - represents waiting for enough time to pass to be sure the remote TCP received the acknowledgment of its connection termination request.


![alt text](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/一台机器上最多能创建多少个TCP连接/99f5dae9de68a749-image-20220721093116395.png)

## 短连接的开销

用ab通过短连接走 lo 网卡压本机 nginx，CPU0是 ab 进程，CPU3/4 是 Nginx 服务，可以看到 si 非常高，QPS 2.2万

![image-20220627154822263](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/一台机器上最多能创建多少个TCP连接/5a7740d45aae847a-image-20220627154822263.png)

再将 ab 改用长连接来压，可以看到si、sy都有下降，并且 si 下降到短连接的20%，QPS 还能提升到 5.2万

![image-20220627154931495](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/一台机器上最多能创建多少个TCP连接/f1a949f9001c604a-image-20220627154931495.png)



## [可用 local port 不够导致对端time_wait 流重用进而卡顿案例](https://ata.alibaba-inc.com/articles/251853)

A进程选择某个端口，并设置了 reuseaddr opt（表示其它进程还能继续用这个端口），这时B进程选了这个端口，并且bind了，如果 A 进程一直不释放这个端口对应的连接，那么这个端口会一直在内核中记录被bind用掉了（能bind的端口 是65535个，四元组不重复的连接你理解可以无限多），这样的端口越来越多后，剩下可供 A 进程发起连接的本地随机端口就越来越少了，这时会造成新建连接的时候这个四元组高概率重复，一般这个时候对端大概率还在 time_wait 状态，会忽略掉握手 syn 包并回复 ack ，进而造成建连接卡顿的现象

## 结论

-   在内存、文件句柄足够的话一台服务器上可以创建的TCP连接数量是没有限制的
-   SO_REUSEADDR 主要用于快速重用 TIME_WAIT状态的TCP端口，避免服务重启就会抛出Address Already in use的错误
-   SO_REUSEPORT主要用来解决惊群、性能等问题
-   全局范围可以用 net.ipv4.tcp_max_tw_buckets = 50000 来限制总 time_wait 数量，但是会掩盖问题
-   local port的选择是递增搜索的，搜索起始port随时间增加也变大

## 参考资料

https://segmentfault.com/a/1190000002396411

[linux中TCP的socket、bind、listen、connect和accept的实现](https://blog.csdn.net/a364572/article/details/40628171)

[How Linux allows TCP introspection The inner workings of bind and listen on Linux.](https://ops.tips/blog/how-linux-tcp-introspection/)

https://idea.popcount.org/2014-04-03-bind-before-connect/

[TCP连接中客户端的端口号是如何确定的？](https://mp.weixin.qq.com/s/C-Eeoeh9GHxugF4J30fz1A)

[对应4.19内核代码解析](https://github.com/plantegg/linux/commit/9b3312bf18f6873e67f1f51dab3364c95c9dc54c)

[How to stop running out of ephemeral ports and start to love long-lived connections](https://blog.cloudflare.com/how-to-stop-running-out-of-ephemeral-ports-and-start-to-love-long-lived-connections/)


