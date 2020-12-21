---
title:  vxlan网络性能测试
date: 2018-08-21 16:30:03
categories: network
tags:
    - Linux
    - docker
    - vxlan
    - performance
    - network
---

# vxlan网络性能测试

----------
## 缘起

> Docker集群中需要给每个容器分配一个独立的IP，同时在不同宿主机环境上的容器IP又要能够互相联通，所以需要一个overlay的网络（vlan也可以解决这个问题）
>
> overlay网络就是把容器之间的网络包重新打包在宿主机的IP包里面，传到目的容器所在的宿主机后，再把这个overlay的网络包还原成容器包交给容器
>
> 这里多了一次封包解包的过程，所以性能上必然有些损耗
>
> 封包解包可以在应用层（比如Flannel的UDP封装），但是需要将每个网络包从内核态复制到应用态进行封包，所以性能非常差
>
> 比较新的Linux内核带了vxlan功能，也就是将网络包直接在内核态完成封包，所以性能要好很多，本文vxlan指的就是这种方式

## 本文主要是比较通过vxlan实现的overlay网络之间的性能（相对宿主机之间而言）

## iperf3 下载和安装

- wget http://downloads.es.net/pub/iperf/iperf-3.0.6.tar.gz
- tar zxvf iperf-3.0.6.tar.gz
- cd iperf-3.0.6
- ./configure
- make install

## 测试环境宿主机的基本配置情况

    conf:
    loc_node   =  e12174.bja
    loc_cpu=  2 Cores: Intel Xeon E5-2430 0 @ 2.20GHz
    loc_os =  Linux 3.10.0-327.ali2010.alios7.x86_64
    loc_qperf  =  0.4.9
    rem_node   =  e26108.bja
    rem_cpu=  2 Cores: Intel Xeon E5-2430 0 @ 2.20GHz
    rem_os =  Linux 3.10.0-327.ali2010.alios7.x86_64
    rem_qperf  =  0.4.9


### 容器到自身宿主机之间, 跟两容器在同一宿主机，速度差不多

	$iperf3 -c 192.168.6.6 
	Connecting to host 192.168.6.6, port 5201
	[  4] local 192.168.6.1 port 21112 connected to 192.168.6.6 port 5201
	[ ID] Interval   Transfer Bandwidth   Retr
	[  4]   0.00-10.00  sec  13.9 GBytes  11.9 Gbits/sec1 sender
	[  4]   0.00-10.00  sec  13.9 GBytes  11.9 Gbits/sec  receiver
	
	[ ID] Interval   Transfer Bandwidth   Retr
	[  4]   0.00-10.00  sec  14.2 GBytes  12.2 Gbits/sec  139 sender
	[  4]   0.00-10.00  sec  14.2 GBytes  12.2 Gbits/sec  receiver
	
	[ ID] Interval   Transfer Bandwidth   Retr
	[  4]   0.00-10.00  sec  13.9 GBytes  11.9 Gbits/sec   96 sender
	[  4]   0.00-10.00  sec  13.9 GBytes  11.9 Gbits/sec  receiver


### 从宿主机A到宿主机B上的容器

    $iperf3 -c 192.168.6.6
    Connecting to host 192.168.6.6, port 5201
    [  4] local 192.168.6.1 port 47940 connected to 192.168.6.6 port 5201
    [ ID] Interval   Transfer Bandwidth   Retr
    [  4]   0.00-10.00  sec   409 MBytes   343 Mbits/sec0 sender
    [  4]   0.00-10.00  sec   405 MBytes   340 Mbits/sec  receiver
    
    [ ID] Interval   Transfer Bandwidth   Retr
    [  4]   0.00-10.00  sec   389 MBytes   326 Mbits/sec   14 sender
    [  4]   0.00-10.00  sec   386 MBytes   324 Mbits/sec  receiver
    
    [ ID] Interval   Transfer Bandwidth   Retr
    [  4]   0.00-10.00  sec   460 MBytes   386 Mbits/sec7 sender
    [  4]   0.00-10.00  sec   458 MBytes   384 Mbits/sec  receiver


### 两宿主机之间测试
    $iperf3 -c 10.125.26.108
    Connecting to host 10.125.26.108, port 5201
    [  4] local 10.125.12.174 port 24309 connected to 10.125.26.108 port 5201
    [ ID] Interval   Transfer Bandwidth   Retr
    [  4]   0.00-10.00  sec   471 MBytes   395 Mbits/sec0 sender
    [  4]   0.00-10.00  sec   469 MBytes   393 Mbits/sec  receiver
    
    [ ID] Interval   Transfer Bandwidth   Retr
    [  4]   0.00-10.00  sec   428 MBytes   359 Mbits/sec0 sender
    [  4]   0.00-10.00  sec   426 MBytes   357 Mbits/sec  receiver
    
    [ ID] Interval   Transfer Bandwidth   Retr
    [  4]   0.00-10.00  sec   430 MBytes   360 Mbits/sec0 sender
    [  4]   0.00-10.00  sec   427 MBytes   358 Mbits/sec  receiver


### 两容器之间（跨宿主机）

    $iperf3 -c 192.168.6.6
    Connecting to host 192.168.6.6, port 5201
    [  4] local 192.168.6.5 port 37719 connected to 192.168.6.6 port 5201
    [ ID] Interval   Transfer Bandwidth   Retr
    [  4]   0.00-10.00  sec   403 MBytes   338 Mbits/sec   18 sender
    [  4]   0.00-10.00  sec   401 MBytes   336 Mbits/sec  receiver
    
    [ ID] Interval   Transfer Bandwidth   Retr
    [  4]   0.00-10.00  sec   428 MBytes   359 Mbits/sec   15 sender
    [  4]   0.00-10.00  sec   425 MBytes   356 Mbits/sec  receiver
    
    [ ID] Interval   Transfer Bandwidth   Retr
    [  4]   0.00-10.00  sec   508 MBytes   426 Mbits/sec   11 sender
    [  4]   0.00-10.00  sec   506 MBytes   424 Mbits/sec  receiver



## netperf 安装依赖 automake-1.14, 环境无法升级，放弃

## qperf 测试工具

- sudo yum install qperf -y

### 两台宿主机之间

    $qperf -t 10  10.125.26.108 tcp_bw tcp_lat
    tcp_bw:
    bw  =  50.5 MB/sec
    tcp_lat:
    latency  =  332 us

#### 包的大小分别为1和128
    $qperf  -oo msg_size:1   10.125.26.108 tcp_bw tcp_lat
    tcp_bw:
    bw  =  1.75 MB/sec
    tcp_lat:
    latency  =  428 us
    
    $qperf  -oo msg_size:128   10.125.26.108 tcp_bw tcp_lat
    tcp_bw:
    bw  =  57.8 MB/sec
    tcp_lat:
    latency  =  504 us


#### 两台宿主机之间，包的大小从一个字节每次翻倍测试

    $qperf  -oo msg_size:1:4K:*2 -vu  10.125.26.108 tcp_bw tcp_lat 
    tcp_bw:
    bw=  1.86 MB/sec
    msg_size  = 1 bytes
    tcp_bw:
    bw=  3.54 MB/sec
    msg_size  = 2 bytes
    tcp_bw:
    bw=  6.43 MB/sec
    msg_size  = 4 bytes
    tcp_bw:
    bw=  14.3 MB/sec
    msg_size  = 8 bytes
    tcp_bw:
    bw=  27.1 MB/sec
    msg_size  =16 bytes
    tcp_bw:
    bw=  42.3 MB/sec
    msg_size  =32 bytes
    tcp_bw:
    bw=  51.8 MB/sec
    msg_size  =64 bytes
    tcp_bw:
    bw=  49.7 MB/sec
    msg_size  =   128 bytes
    tcp_bw:
    bw=  48.2 MB/sec
    msg_size  =   256 bytes
    tcp_bw:
    bw=   58 MB/sec
    msg_size  =  512 bytes
    tcp_bw:
    bw=  54.6 MB/sec
    msg_size  = 1 KiB (1,024)
    tcp_bw:
    bw=  48.7 MB/sec
    msg_size  = 2 KiB (2,048)
    tcp_bw:
    bw=  53.6 MB/sec
    msg_size  = 4 KiB (4,096)
    tcp_lat:
    latency   =  432 us
    msg_size  =1 bytes
    tcp_lat:
    latency   =  480 us
    msg_size  =2 bytes
    tcp_lat:
    latency   =  441 us
    msg_size  =4 bytes
    tcp_lat:
    latency   =  487 us
    msg_size  =8 bytes
    tcp_lat:
    latency   =  404 us
    msg_size  =   16 bytes
    tcp_lat:
    latency   =  335 us
    msg_size  =   32 bytes
    tcp_lat:
    latency   =  338 us
    msg_size  =   64 bytes
    tcp_lat:
    latency   =  401 us
    msg_size  =  128 bytes
    tcp_lat:
    latency   =  496 us
    msg_size  =  256 bytes
    tcp_lat:
    latency   =  684 us
    msg_size  =  512 bytes
    tcp_lat:
    latency   =  534 us
    msg_size  =1 KiB (1,024)
    tcp_lat:
    latency   =  681 us
    msg_size  =2 KiB (2,048)
    tcp_lat:
    latency   =  701 us
    msg_size  =4 KiB (4,096)

### 两个容器之间（分别在两台宿主机上）

    $qperf -t 10  192.168.6.6 tcp_bw tcp_lat 
    tcp_bw:
    bw  =  44.4 MB/sec
    tcp_lat:
    latency  =  512 us

#### 包的大小分别为1和128

    $qperf -oo msg_size:1  192.168.6.6 tcp_bw tcp_lat 
    tcp_bw:
    bw  =  1.13 MB/sec
    tcp_lat:
    latency  =  630 us
    
    $qperf -oo msg_size:128  192.168.6.6 tcp_bw tcp_lat 
    tcp_bw:
    bw  =  44.2 MB/sec
    tcp_lat:
    latency  =  526 us


#### 两个容器之间，包的大小从一个字节每次翻倍测试

    $qperf -oo msg_size:1:4K:*2  192.168.6.6 -vu tcp_bw tcp_lat 
    tcp_bw:
    bw=  1.06 MB/sec
    msg_size  = 1 bytes
    tcp_bw:
    bw=  2.29 MB/sec
    msg_size  = 2 bytes
    tcp_bw:
    bw=  3.79 MB/sec
    msg_size  = 4 bytes
    tcp_bw:
    bw=  7.66 MB/sec
    msg_size  = 8 bytes
    tcp_bw:
    bw=  14 MB/sec
    msg_size  =  16 bytes
    tcp_bw:
    bw=  24.4 MB/sec
    msg_size  =32 bytes
    tcp_bw:
    bw=  36 MB/sec
    msg_size  =  64 bytes
    tcp_bw:
    bw=  46.7 MB/sec
    msg_size  =   128 bytes
    tcp_bw:
    bw=   56 MB/sec
    msg_size  =  256 bytes
    tcp_bw:
    bw=  42.2 MB/sec
    msg_size  =   512 bytes
    tcp_bw:
    bw=  57.6 MB/sec
    msg_size  = 1 KiB (1,024)
    tcp_bw:
    bw=  52.3 MB/sec
    msg_size  = 2 KiB (2,048)
    tcp_bw:
    bw=  41.7 MB/sec
    msg_size  = 4 KiB (4,096)
    tcp_lat:
    latency   =  447 us
    msg_size  =1 bytes
    tcp_lat:
    latency   =  417 us
    msg_size  =2 bytes
    tcp_lat:
    latency   =  503 us
    msg_size  =4 bytes
    tcp_lat:
    latency   =  488 us
    msg_size  =8 bytes
    tcp_lat:
    latency   =  452 us
    msg_size  =   16 bytes
    tcp_lat:
    latency   =  537 us
    msg_size  =   32 bytes
    tcp_lat:
    latency   =  712 us
    msg_size  =   64 bytes
    tcp_lat:
    latency   =  521 us
    msg_size  =  128 bytes
    tcp_lat:
    latency   =  450 us
    msg_size  =  256 bytes
    tcp_lat:
    latency   =  442 us
    msg_size  =  512 bytes
    tcp_lat:
    latency   =  630 us
    msg_size  =1 KiB (1,024)
    tcp_lat:
    latency   =  519 us
    msg_size  =2 KiB (2,048)
    tcp_lat:
    latency   =  621 us
    msg_size  =4 KiB (4,096)


​    
## 结论

- iperf3测试带宽方面vxlan网络基本和宿主机一样，没有什么损失
- qperf测试vxlan的带宽只相当于宿主机的60-80%
- qperf测试一个字节的小包vxlan的带宽只相当于宿主机的60-65%
- 由上面的结论猜测：物理带宽更大的情况下vxlan跟宿主机的差别会扩大


**qperf安装更容易； iperf3 可以多连接并发测试，可以控制包的大小、nodelay等等**

## 参考文章：

[https://linoxide.com/monitoring-2/install-iperf-test-network-speed-bandwidth/](https://linoxide.com/monitoring-2/install-iperf-test-network-speed-bandwidth/)

[http://blog.yufeng.info/archives/2234](http://blog.yufeng.info/archives/2234)