---
title: Linux tc qdisc的使用案例
date: 2016-08-24 17:30:03
categories:
    - Linux   
tags:
    - Linux
    - tc
    - network
---

# Linux tc qdisc的使用案例

在linux下通过tc qdisc 很容易对rt延时、丢包、带宽进行控制，这样的话方便重现各种网络问题

## 延时

```
1. give packets from eth0 a delay of 2ms
bash$ tc qdisc add dev eth0 root netem delay 2ms
 
2.change the delay to 300ms
bash$ tc qdisc change dev eth0 root netem delay 3ms

3.display eth0 delay setting
bash$ tc qdisc show dev eth0
 
4.stop the delay
bash$ tc qdisc del dev eth0 root

#corrupt
The following rule corrupts 5% of the packets by introducing single bit error at a random offset in the packet:
tc qdisc change dev eth0 root netem corrupt 5%
```



## 模拟网络丢包

```
tc qdisc add dev eth0 root netem loss 1%
```

指定ip 172.31.65.30延时17ms， 测试发现181和183这两句命令顺序无所谓。恢复正常：179行命令

```
  179  tc qdisc del dev eth0 root
  180  tc qdisc add dev eth0 root handle 1: prio
  181  tc filter add dev eth0 parent 1:0 protocol ip pref 55 handle ::55 u32 match ip dst 172.31.65.30 flowid 2:1
  182  tc qdisc ls
  183  tc qdisc add dev eth0 parent 1:1 handle 2: netem delay 17ms
```

## 指定ip和端口延时

指定 eth0 网卡，来源 ip 是 10.10.200.45，目的端口是 3306 的访问延迟 20ms，上下浮动 2ms 

```
# 指定 eth0 网卡，来源 ip 是 10.0.200.45，目的端口是 3306 的访问延迟 20ms，上下浮动 2ms
tc qdisc add dev eth0 root handle 1: prio bands 4
tc qdisc add dev eth0 parent 1:4 handle 40: netem delay 20ms 2ms
tc filter add dev eth0 parent 1: protocol ip prio 4 basic match "cmp(u16 at 2 layer transport eq 3306)
                            and cmp(u8 at 16 layer network eq 10)
                            and cmp(u8 at 17 layer network eq 0)
                            and cmp(u8 at 18 layer network eq 200)
                            and cmp(u8 at 19 layer network eq 45)" flowid 1:4
                            
# 删除过滤
sudo tc filter del dev eth0 parent 1: prio 4 basic
sudo tc qdisc  del dev eth0 root                            
```

0 layer 代表 sport
2 layer 代表 dport

## 指定端口34001上，延时5ms

```
tc qdisc add dev eth0 root handle 1: prio
tc qdisc add dev eth0 parent 1:3 handle 30: netem delay 5ms
tc filter add dev eth0 protocol ip parent 1:0 u32 match ip sport 34001 0xffff flowid 1:3
```

## 限制eth0网卡的带宽为500kbit：网速 延时、乱序、丢包

```
sudo tc qdisc add dev bond0 root handle 1: netem delay 10ms reorder 25% 50% loss 0.2%
sudo tc qdisc add dev bond0 parent 1: handle 2: tbf rate 1mbit burst 32kbit latency 10ms

/sbin/tc qdisc add dev eth0 root tbf rate 500kbit latency 50ms burst 15kb

// 同时模拟20Mbps带宽，50msRTT和0.1%丢包率  
# tc qdisc add dev eth5 root handle 1:0 tbf rate 20mbit burst 10kb limit 300000  
# tc qdisc add dev eth5 parent 1:0 handle 10:0 netem delay 50ms loss 0.1 limit 300000 

tc qdisc change dev eth0 root netem reorder 50% gap 3 delay 1ms
tc qdisc change dev eth0 root netem delay 1ms reorder 15%


//限制网卡vb603d4dd412d 带宽500kb
sudo /sbin/tc qdisc add dev vb603d4dd412d root tbf rate 500kbit latency 50ms burst 15kb
sudo /sbin/tc qdisc ls dev vb603d4dd412d
```



在eth0上设置一个tbf队列，网络带宽为200kbit，延迟10ms以内，超出的包会被drop掉，缓冲区为1540个字节
rate表示令牌的产生速率
latency表示数据包在队列中的最长等待时间
对burst参数解释一下：
  burst means the maximum amount of bytes that tokens can be available for instantaneously.
  如果数据包的到达速率与令牌的产生速率一致，即200kbit，则数据不会排队，令牌也不会剩余
  如果数据包的到达速率小于令牌的产生速率，则令牌会有一定的剩余。
  如果后续某一会数据包的到达速率超过了令牌的产生速率，则可以一次性的消耗一定量的令牌。
  burst就是用于限制这“一次性”消耗的令牌的数量的，以字节数为单位。

```
tc qdisc add dev eth0 root tbf rate 200kbit latency 10ms burst 1540  

tc qdisc ls dev eth0 // 查看eth0上的队列规则  
```



## 参考资料

