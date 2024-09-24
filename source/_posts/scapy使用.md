---
title: 从一个fin 卡顿问题到 scapy 的使用
date: 2023-04-20 17:30:03
categories:
    - network
tags:
    - scapy
    - 挥手
    - 乱序
---

# 从一个fin 卡顿问题到 scapy 的使用

## scapy 使用

scapy 可以绕过内核构造任意网络包

使用比较简单，git clone  https://github.com/secdev/scapy 然后在有python3的环境直接可以跑(python2官方说也支持)

注意：

scapy会触发内核发送reset，所以先要在iptables条件一条规则把内核的reset干掉，要不影响scapy的测试

```
iptables -A OUTPUT -p tcp --tcp-flags RST RST -s 192.168.0.1 -j DROP

iptables -A OUTPUT -p tcp --tcp-flags RST RST -s 192.168.0.1 -d 192.168.0.2 --sport 1234 --dport 12347 -j DROP
```

因为包是 scapy 绕过OS 够早的，导致 OS 不认 scapy 模拟发出的包，内核里面没有你这个socket记录，只能 reset你，所以还得用iptables把这个OS 触发的reset，测试才能顺利进行



## 三次握手

用scapy 模拟客户端来进行3次握手

代码：

```
sport=random.randint(1024,65535)
ip=IP(dst="127.0.0.1")
SYN=TCP(sport=sport, dport=22345, flags='S', seq=123451000)
c=sr1(ip/SYN)
```

完整案例：

```python
# ./run_scapy
>>> sport=random.randint(1024,65535) //初始化一个本地随机端口
>>> SYN=TCP(sport=sport, dport=22345, flags='S', seq=123451000) //构造一个连 22345 目标端口的 SYN 包 
>>> ip=IP(dst="192.168.0.2") //构造目标地址
>>> sr1(ip/SYN) 发送包
Begin emission:
Finished sending 1 packets.
.*
Received 2 packets, got 1 answers, remaining 0 packets
<IP  version=4 ihl=5 tos=0x0 len=44 id=0 flags=DF frag=0 ttl=64 proto=tcp chksum=0xb978 src=192.168.0.2 dst=192.168.0.1 |<TCP  sport=22345 dport=45814 seq=1599494827 ack=123451001 dataofs=6 reserved=0 flags=SA window=64240 chksum=0x99bb urgptr=0 options=[('MSS', 1460)] |<Padding  load=b'\x00\x00' |>>>
>>>
```

上面的代码是给对端22345 发了个syn包，然后收到了 syn+ack 包并展示在最后，这一来一回的两个握手包都可以用tcpdump 抓到

服务端的话可以起一个标准http server来验证：

```shell
python3 -m http.server 22345
```

对应抓包：

```
15:58:43.301867 IP localhost.44633 > ky2.22345: Flags [S], seq 123451000, win 8192, length 0
15:58:43.301929 IP ky2.22345 > localhost.44633: Flags [S.], seq 106274946, ack 123451001, win 64240, options [mss 1460], length 0
15:58:44.361834 IP ky2.22345 > localhost.44633: Flags [S.], seq 106274946, ack 123451001, win 64240, options [mss 1460], length 0
15:58:46.441862 IP ky2.22345 > localhost.44633: Flags [S.], seq 106274946, ack 123451001, win 64240, options [mss 1460], length 0
```



## fin 挥手端口卡顿案例

一个奇葩的tcp连接断开的卡顿问题(来自这里 https://mp.weixin.qq.com/s/BxU246Btm2FLt1pppBgYQg )，下面是我对这篇文章问题描述的总结：

> 1 两端几乎同时发fin, client收到fin回了一个ack 
>
> 2 client发的ack先fin到达server，server收到ack直接进入time_wait 
>
> 3 fin到达server被扔掉----接下来就是要用scapy验证这个fin包被扔掉/忽略了，导致client不能立即断开要等200ms
>
> 4 client认为关闭失败，等了200ms重传fin然后关闭成功 

这个问题的总结就是：TCP连接断开的四次挥手中，由于fin包和ack包乱序，导致等了一次timeout才关闭连接，但是上层业务设置了200ms超时，导致业务报错了，现在需要重现这个问题！

> 出现这种问题的场景：比如在 OVS/MOC 等网络场景下，SYN/FIN 等关键包需要更新路由(session flow)，会走 slowpath(送到更高层的复杂逻辑处理，比如 SYN 就创建一个新的 session 记录，以后普通包直接命中这个 session 就快了；同样 FIN 需要走高层逻辑去释放这条 session 记录)
>
> 影响：因为 ack 比 FIN 先到，导致应用连接已被释放，但是后面的 FIN 被重传，从而可能使得应用记录的连接断开时间要晚甚至超时

原作者怎么分析定位，花了几周，这个过程大家可以去看上面的原因，本篇的目的是对这个问题用Scapy 来重现，目标掌握好 Scapy 这个工具，以后对各种其他问题大家自己都能快速定位



用scapy来模拟这个问题，server端用python实现，重点注意server端的断开方式有两个shutdown/close:

```python
import socket

server_ip = "0.0.0.0"
server_port = 22345

server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server_socket.bind((server_ip, server_port))
server_socket.listen(5)

connection, client_address = server_socket.accept()

connection.shutdown(socket.SHUT_RDWR) //比较shutdown和close的不同
#connection.close()

time.sleep(3)
server_socket.close()
```

对应的client 测试代码，引入了scapy，代码首先是和服务端3次握手，然后抓取(sniff)所有服务端的来包，看看是不是fin，是的话故意先回ack再回fin人为制造乱序：

```python
from scapy.all import *
import time
import sys

target_ip = "127.0.0.1"
target_port = 22345
#src_port=random.randint(1024,65535)
src_port=54322

ip = IP(dst=target_ip)
syn = TCP(sport=src_port, dport=target_port, flags="S", seq=4294967293)
syn_ack = sr1(ip / syn)
if syn_ack and TCP in syn_ack and syn_ack[TCP].flags == "SA":
    print("Received SYN-ACK")
    ack = TCP(sport=src_port, dport=target_port,
              flags="A", seq=4322, ack=syn_ack.seq+1)
    send(ip / ack)
    data="rrrrrrrrrrrrrrrrrrrr"
    payload=TCP(sport=src_port, dport=22345, flags='S', seq=4294967294)
    send(ip/payload()/Raw(load=data))
    print("Send ACK")
else:
    print("Failed to establish TCP connection")
    
  

def handle_packet(packet):
    print("handle fin packet")
    print(Ether(raw(packet)))
    if  TCP in packet and packet[TCP].flags & 0x011 and packet[TCP].sport == 22345:
        print("Received FIN packet")
        ack = TCP(sport=src_port, dport=target_port,
		  flags="A", seq=packet.ack+1, ack=packet.seq+1)
        send(ip / ack)

        time.sleep(0.1)
        fin = TCP(sport=src_port, dport=target_port,
                  flags="FA", seq=packet.ack, ack=packet.seq)
        send(ip / fin)
        sys.exit(0)
#抓包，抓到的包给handle_packet处理
#sniff(filter="tcp port 22345", prn=handle_packet)
sniff(filter="tcp port 22345", iface="lo",prn=handle_packet)
```

下图是服务端 shutdown时模拟挥手断开时ack包和fin包乱序了，也就是先回ack，sleep一段时间后再回fin包，如图：

![image-20231009101444587](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/image-20231009101444587.png)

如果server端代码中将shutdown改成close 并做个对比，关键是上面绿框回复ack是4322(challenge_ack 表示seq=4322的fin包被忽略了)，而下面close时的seq=4322的fin包会被正确接收并回复ack 4323 确认，那么这时client 可以断开了。而上图绿框表示fin 被忽略了，那么内核要继续等200ms 再次发 fin，等收到ack后client 才能断开

![image-20231008175355835](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/image-20231008175355835.png)

server上通过 netstat 观察连接的状态变化：

```
//shutdown，可以看到server 发fin进入FIN_WAIT1，然后收到ack 进入 FIN_WAIT2，此时收到fin了，但是被扔掉了，无法断开进入TIME_WAIT
# sh test.sh
tcp        0      0 192.168.0.2:22345       192.168.0.1:54322       SYN_RECV
tcp        0      1 192.168.0.2:22345       192.168.0.1:54322       FIN_WAIT1
tcp        0      0 192.168.0.2:22345       192.168.0.1:54322       FIN_WAIT2
tcp        0      0 192.168.0.2:22345       192.168.0.1:54322       FIN_WAIT2
tcp        0      0 192.168.0.2:22345       192.168.0.1:54322       FIN_WAIT2
tcp        0      0 192.168.0.2:22345       192.168.0.1:54322       FIN_WAIT2
tcp        0      0 192.168.0.2:22345       192.168.0.1:54322       FIN_WAIT2

//close 可以看到server 发fin进入FIN_WAIT1，然后收到ack 进入 FIN_WAIT2，此时收到fin了没有被扔掉，所以很快连接断开进入了TIME_WAIT 
tcp        0      0 192.168.0.2:22345       192.168.0.1:54322       SYN_RECV
tcp        0      1 192.168.0.2:22345       192.168.0.1:54322       FIN_WAIT1
tcp        0      0 192.168.0.2:22345       192.168.0.1:54322       FIN_WAIT2
tcp        0      0 192.168.0.2:22345       192.168.0.1:54322       TIME_WAIT
tcp        0      0 192.168.0.2:22345       192.168.0.1:54322       TIME_WAIT
```

## seq 回绕到0 会导致丢包吗？

首先学习下 seq 是一个无符号32位的整数，最大值是4294967295 

如图，有人发现探活连接不通，导致了一次非正常切换，所以需要分析连接为什么断开，抓包发现重传的时候正好seq 为0，于是他就奇怪了是不是这个seq溢出搞的鬼？怎么这么巧seq 刚好为0了？

![image-20231130113732507](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/image-20231130113732507.png)

要想正好巧合在 seq 回绕的时候刚好回绕到 0 还是非常不容易的，不过好在用 scapy 来模拟这事就简单了

重现代码：

```
from scapy.all import *
import time
import sys

target_ip = "server_host_ip"
target_port = 22345
src_port=random.randint(1024,65535)

#接近最大值 4294967295
start_seq=4294967292 

ip = IP(dst=target_ip)
syn = TCP(sport=src_port, dport=target_port, flags="S", seq=start_seq)
syn_ack = sr1(ip / syn)
if syn_ack and TCP in syn_ack and syn_ack[TCP].flags == "SA":
    print("Received SYN-ACK")
    ack = TCP(sport=src_port, dport=target_port,
              flags="A", seq=syn_ack.ack, ack=syn_ack.seq+1)
    print(syn_ack.seq)
    print(syn_ack.ack)
    print(ack)
    send(ip/ack)
    print("Send ACK")
else:
    print("Failed to establish TCP connection")

print("send payload")
#4294967293+3(3个r) 正好是无符号整数溢出(最大 4294967295)，回绕到0
data="rrr"
payload=TCP(sport=src_port, dport=22345,flags="AP", seq=syn_ack.ack,  ack=syn_ack.seq+1)
payload2=TCP(sport=src_port, dport=22345,flags="AP", seq=0,  ack=syn_ack.seq+1)
syn_ack=send(ip/payload/Raw(load=data))
syn_ack=send(ip/payload2/Raw(load=data))
```

对应的抓包：

![image-20231130114200515](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/image-20231130114200515.png)

从上面的实验来看内核能正确处理这种 seq 回绕到 0 的场景，所以问题不在内核处理上。进一步分析发现是交换机的 bug 导致的

### 交换机丢掉seq=0的包

最后发现这个问题是中兴 9900系列交换机存在seq=0 push 发送模式下报文存在丢失缺陷， 丢包原因是中兴交换机从安全角度考量是支持antidos防攻击功能，该功能开启后会将 TCP seq 为 0 的报文作为非法报文并丢弃。中兴 9900交换机上该功能默认是关闭的但是未生效，需要重新触发关闭（现场看配置是关闭的，实际是开启的，现在执行将配置先打开再关闭）。
临时规避方案：（中兴内部验证测试针对此报文有效，现场环境可能有差异，需要现场验证确认）

```
先执行 (config)#anti-dos abnormal enable
再执行 (config)#anti-dos abnormal disable  
```

现场实施完毕后，发包验证恢复正常，后续持续观察业务。

彻底解决方案：将该版本升级至V2.00.00R8P16  

#### 华为交换机针对默认连接丢包 bug

借着中兴这个交换机问题，说一下华为交换机的的 bug，华为 CE12800系列，V200R022C00SPC500之前的版本

当大规格路由反复震荡场景下会小概率

1. 出现优先级更高的(子网掩码范围更小)路由表项残留，导致整个子网不通
2. 某个接口下发的路由表和其他接口(芯片)不一致，导致某条连接一直丢包

可以重启单板修复表项异常问题，该问题在新版本上（V200R022C00SPC500）已经补丁修复（SPH220）

根因：残留表项或表项异常导致，老版本在大规格路由反复震荡场景下会小概率触发，是软件多线程处理路由下发或删除时，出现线程读取数据异常，导致芯片表项错误。

## scapy 构造全连接队列溢出

server 端用python 起一个WEB 服务：

```
nohup python3 -m http.server 22345 &
```

然后client端用如下scapy 代码不断去3次握手建立连接，试几次后就抓到如下现象：

![image-20231130111028268](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/image-20231130111028268.png)

抓包效果：

![image-20231130133248747](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/image-20231130133248747.png)

## 总结

我觉得scapy还是挺好用的，比packetdrill好用一万倍，直观明了，还有命令行可以交互测试

但是要注意 scapy 是绕过内核在模拟发包，收包靠 sniff，所以内核收到这些回包会认为连接不存在，直接reset，需要在iptables 里处理一下

这个问题是别人推荐给我看的，一般10分钟就看完了，但是我差不多花了2天时间，不断地想和去实验重现

## 参考资料

https://wizardforcel.gitbooks.io/scapy-docs/content/3.html

https://www.osgeo.cn/scapy/usage.html

https://zhuanlan.zhihu.com/p/51002301

## 如果你觉得看完对你很有帮助可以通过如下方式找到我

find me on twitter: [@plantegg](https://twitter.com/plantegg)

知识星球：[https://t.zsxq.com/0cSFEUh2J](https://t.zsxq.com/0cSFEUh2J)

开了一个星球，在里面讲解一些案例、知识、学习方法，肯定没法让大家称为顶尖程序员(我自己都不是)，只是希望用我的方法、知识、经验、案例作为你的垫脚石，帮助你快速、早日成为一个基本合格的程序员。

争取在星球内：

- 养成基本动手能力
- 拥有起码的分析推理能力--按我接触的程序员，大多都是没有逻辑的
- 知识上教会你几个关键的知识点

<img src="https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/image-20240324161113874.png" alt="image-20240324161113874" style="zoom:50%;" />

