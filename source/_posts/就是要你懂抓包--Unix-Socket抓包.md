---
title: 就是要你懂Unix Socket 进行抓包解析
date: 2019-04-04 11:30:03
categories: Linux
tags:
    - Linux
    - tcpdump
    - unix-socket
    - sniff
    - socat
    - curl
---


# 通过tcpdump对Unix Socket 进行抓包解析

## 背景介绍

大多时候我们可以通过tcpdump对网络抓包分析一些访问数据，以及反向解析一些数据，也就是希望看到具体请求、想用内容。但是如果程序是通过Unix Socket方式来访问的那么tcpdump就看不到Unix Socket里面具体流淌的内容了，本文希望找到一种方法达到如同查看网卡内容一样来查看Unix Socket上具体的请求、响应数据

## socat工具

类似nc，但是是个超级增强版的nc，[主要用作两个独立数据通道之间的双向数据传输的继电器（或者说代理）](https://payloads.online/tools/socat)

基本原理，通过socat在Unix-Socket和TCP/UDP port之间建立一个代理，然后对代理上的端口进行抓包

## 通过socat 启动一个tcp端口来代理unix socket

启动本地8080端口，将docker.sock映射到8080端口,8080收到的东西都会转给docker.sock，docker.sock收到的东西都通过抓8080的包看到,但是要求应用访问8080而不是docker.sock。

	socat -d -d TCP-LISTEN:8080,fork,bind=127.0.0.1 UNIX:/var/run/docker.sock

**缺点：需要修改客户端的访问方式**

	sudo curl --unix-socket /var/run/docker.sock http://localhost/images/json

上面的访问方式对8080抓包还是抓不到，因为绕过了我们的代理

	sudo curl http://localhost:8080/images/json

只能通过如上方式访问8080端口，然后请求通过socat代理转发给docker.sock，整个结果跟访问--unix-socket是一样的，这个时候通过8080端口抓包能看到--unix-socket的工作数据

## 通过socat启动另外一个unix socket代理，但是不是tcpdump抓包

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

实际流程如下： client -> 新socket -> 8089 -> 原来的socket  这个时候对8089可以任意抓包了.

参考来源：[https://mivehind.net/2018/04/20/sniffing-unix-domain-sockets/](https://mivehind.net/2018/04/20/sniffing-unix-domain-sockets/)	
	

## 一些socat的其它用法

 把监听在远程主机12.34.56.78上的mysql服务unix socket映射到本地的/var/run/mysqld.temp.sock, 这样就可以用mysql -S /var/run/mysqld/mysqld.sock来访问远程主机的mysql服务了。


    socat "UNIX-LISTEN:/var/run/mysqld.temp.sock,reuseaddr,fork" EXEC:"ssh root@12.34.56.78 socat STDIO UNIX-CONNECT:/var/run/mysqld/mysqld.sock"


 还可以用下面的命令把12.34.56.78上的mysql映射到本地的5500端口，然后使用mysql -p 5500命令访问。

	socat TCP-LISTEN:5500 EXEC:'ssh root@12.34.56.78 "socat STDIO UNIX-CONNECT:/var/run/mysqld/mysqld.sock"'

 把12.34.56.78的udp 161端口映射到本地的1611端口

	socat udp-listen:1611 system:'ssh root@12.34.56.78 "socat stdio udp-connect:remotetarget:161"'	

 通过socat启动server，带有各种参数，比nc更灵活

    Server: socat -dd tcp-listen:2000,keepalive,keepidle=10,keepcnt=2,reuseaddr,keepintvl=1 -
    Client: socat -dd - tcp:localhost:2000,keepalive,keepidle=10,keepcnt=2,keepintvl=1

    Drop Connection (Unplug Cable, Shut down Link(WiFi/Interface)): sudo iptables -A INPUT -p tcp --dport 2000 -j DROP



## curl 7.57版本可以直接访问 --unix-socket

7.57之后的版本才支持curl --unix-socket，大大方便了我们的测试

	//Leave 测试断开一个网络
	curl -H "Content-Type: application/json" -X POST -d '{"NetworkID":"47866b0071e3df7e8053b9c8e499986dfe5c9c4947012db2d963c66ca971ed4b","EndpointID":"3d716436e629701d3ce8650e7a85c133b0ff536aed173c624e4f62a381656862"}' --unix-socket /run/docker/plugins/vlan.sock http://localhost/NetworkDriver.Leave

	//取镜像列表
	sudo curl --unix-socket /var/run/docker.sock http://localhost/images/json


## 参考资料：

[https://mivehind.net/2018/04/20/sniffing-unix-domain-sockets/](https://mivehind.net/2018/04/20/sniffing-unix-domain-sockets/)	

[https://superuser.com/questions/484671/can-i-monitor-a-local-unix-domain-socket-like-tcpdump](https://superuser.com/questions/484671/can-i-monitor-a-local-unix-domain-socket-like-tcpdump)
