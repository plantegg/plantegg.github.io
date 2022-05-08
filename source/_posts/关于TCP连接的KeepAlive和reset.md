---
title: 关于TCP连接的Keepalive和reset
date: 2018-08-26 16:30:03
categories: TCP
tags:
    - Linux
    - TCP
    - reset
    - keepalive
    - troubleshooting
    - network
---

# 关于TCP连接的Keepalive和reset

先来看一个现象，下面是测试代码：

    Server: socat -dd tcp-listen:2000,keepalive,keepidle=10,keepcnt=2,reuseaddr,keepintvl=1 -
    Client: socat -dd - tcp:localhost:2000,keepalive,keepidle=10,keepcnt=2,keepintvl=1
    
    Drop Connection (Unplug Cable, Shut down Link(WiFi/Interface)): sudo iptables -A INPUT -p tcp --dport 2000 -j DROP

server监听在2000端口，支持keepalive， client连接上server后每隔10秒发送一个keepalive包，一旦keepalive包得不对对方的响应，每隔1秒继续发送keepalive, 重试两次，如果一直得不到对方的响应那么这个时候client主动发送一个reset包，那么在client这边这个socket就断开了。server上会一直傻傻的等，直到真正要发送数据了才抛异常。


![image.png](/images/oss/90d1c4919d86764242ab726b4c69f006.png)

假如client连接层是一个Java应用的连接池，那么这个socket断开后Java能感知吗？

https://stackoverflow.com/questions/10240694/java-socket-api-how-to-tell-if-a-connection-has-been-closed

Java对Socket的控制比较弱，比如只能指定是否keepalive，不能用特定的keepalive参数(intvl/cnt等），除非走JNI，不推荐。

如下图（dup ack其实都是keepalive包，这是因为没有抓到握手包导致wireshark识别错误而已）
![image.png](/images/oss/c2893e5ad89ee450c61a370ec7bf6f06.png)

如上图，client 21512在多次keepalive server都不响应后，发送了reset断开这个连接（server没收到），server以为还连着，这个时候当server正常发数据给client，如果防火墙还在就丢掉，server不停地重传，如果防火墙不在，那么对方os收到这个包后知道21512这个端口对应的连接已经关闭了，再次发送reset给server，这时候server抛异常，中断这个连接。

![image.png](/images/oss/78427c329e72d526aa8908942409f092.png)

os层面目前看起来除了用socket去读数据感知到内核已经reset了连接外也没什么好办法检测到。