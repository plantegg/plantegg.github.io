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

```shell
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

指定 eth0 网卡，来源 ip 是 10.0.1.1，目的端口是 3306 的访问延迟 20ms，上下浮动 2ms  100.100.146.3

```
# 指定 eth0 网卡，来源 ip 是 10.0.1.1，目的端口是 3306 的访问延迟 20ms，上下浮动 2ms
tc qdisc add dev eth0 root handle 1: prio bands 4
tc qdisc add dev eth0 parent 1:4 handle 40: netem delay 20ms 2ms
tc filter add dev bond0 parent 1: protocol ip prio 4 basic match "cmp(u16 at 2 layer transport eq 80)
                            and cmp(u8 at 16 layer network eq 100)
                            and cmp(u8 at 17 layer network eq 100)
                            and cmp(u8 at 18 layer network eq 146)
                            and cmp(u8 at 19 layer network eq 3)" flowid 1:4
                            
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

## 控制网卡的带宽、延时、乱序、丢包

```shell
sudo tc qdisc add dev bond0 root handle 1: netem delay 10ms reorder 25% 50% loss 0.2%
sudo tc qdisc add dev bond0 parent 1: handle 2: tbf rate 1mbit burst 32kbit latency 10ms

/sbin/tc qdisc add dev bond0 root tbf rate 500kbit latency 50ms burst 15kb

// 同时模拟20Mbps带宽，50msRTT和0.1%丢包率  
# tc qdisc add dev bond0 root handle 1:0 tbf rate 20mbit burst 10kb limit 300000  
# tc qdisc add dev bond0 parent 1:0 handle 10:0 netem delay 50ms loss 0.1 limit 300000 

tc qdisc change dev eth0 root netem reorder 50% gap 3 delay 1ms
tc qdisc change dev eth0 root netem delay 1ms reorder 15%

//在eth0上设置一个tbf队列，网络带宽为200kbit，延迟10ms以内，超出的包会被drop掉，缓冲区为1540个字节
sudo /sbin/tc qdisc add dev eth0 root tbf rate 200kbit latency 10ms burst 15kb
sudo /sbin/tc qdisc ls dev eth0
```

在eth0上设置一个tbf队列，网络带宽为200kbit，延迟10ms以内，超出的包会被drop掉，缓冲区为1540个字节

> rate表示令牌的产生速率, *sustained maximum rate*
> latency表示数据包在队列中的最长等待时间, *packets with higher latency get dropped*
> burst参数表示  maximum allowed burst：
>   burst means the maximum amount of bytes that tokens can be available for instantaneously.
>   如果数据包的到达速率与令牌的产生速率一致，即200kbit，则数据不会排队，令牌也不会剩余
>   如果数据包的到达速率小于令牌的产生速率，则令牌会有一定的剩余。
>   如果后续某一会数据包的到达速率超过了令牌的产生速率，则可以一次性的消耗一定量的令牌。
>   burst就是用于限制这“一次性”消耗的令牌的数量的，以字节数为单位。

tbf: *use* the *token buffer filter to manipulate traffic rates*

限制10MB，排队等待超过100ms就触发丢包，只限制了出去的流量，没有限制进来的流量:

```shell
tc qdisc ls dev eth0 // 查看eth0上的队列规则  
sudo tc qdisc add dev eth0 root tbf rate 80mbit burst 1mbit latency 100ms 

//限制80MB
sudo tc qdisc add dev eth0 root tbf rate 80mbps burst 1mbps latency 100ms
```

### 乱序

```
 1001  [2024-08-08 15:12:01] sudo tc qdisc add dev bond0 root handle 1: prio
 1004  [2024-08-08 15:12:44] sudo tc filter add dev bond0 parent 1: protocol ip prio 1 u32 match ip dst 1.2.3.7 flowid 1:1
 1005  [2024-08-08 15:13:17] tc qdisc add dev bond0 parent 1:1 handle 10: netem delay 10ms reorder 5% 10%
```



## 两地三中心模拟

针对不同的ip地址可以限制不同的带宽和网络延时，htb较prio多了一个带宽控制

通过htb 只限制带宽和延时

```
//对10.0.3.228、229延时1ms，对 10.0.3.232延时30ms 两地三中心限制延时和带宽
tc qdisc add dev eth0 root handle 1: htb

tc class add dev eth0 parent 1: classid 1:1 htb rate 600Gbps
tc filter add dev eth0 parent 1: protocol ip prio 1 u32 flowid 1:1 match ip dst 10.0.3.228
tc qdisc add dev eth0 parent 1:1 handle 10: netem delay 1ms

tc class add dev eth0 parent 1: classid 1:2 htb rate 600Gbps
tc filter add dev eth0 parent 1: protocol ip prio 1 u32 flowid 1:2 match ip dst 10.0.3.229
tc qdisc add dev eth0 parent 1:2 handle 20: netem delay 1ms

tc class add dev eth0 parent 1: classid 1:3 htb rate 600Gbps
tc filter add dev eth0 parent 1: protocol ip prio 1 u32 flowid 1:3 match ip dst 10.0.3.232
tc qdisc add dev eth0 parent 1:3 handle 30: netem delay 30ms
```

![image-20230607152951762](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/image-20230607152951762.png)

![img](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/TX_path_tc_mqprio-1.png)

通过prio 只限制延时

```
//两地三中心限制不同的延时，htb才可以加带宽限制
tc qdisc add dev eth0 root handle 1: prio

//10.0.3.228/10.0.3.229 延时1ms
tc filter add dev eth0 parent 1: protocol ip prio 1 u32 flowid 1:1 match ip dst 10.0.3.228/31
tc qdisc add dev eth0 parent 1:1 handle 10: netem delay 1ms

tc filter add dev eth0 parent 1: protocol ip prio 1 u32 flowid 1:2 match ip dst 10.0.3.232
tc qdisc add dev eth0 parent 1:2 handle 20: netem delay 30ms
```



## [qdisc的类别](https://cloud.tencent.com/developer/article/1409664)

QDisc(排队规则)是queueing discipline的简写，它是理解流量控制(traffic control)的基础。无论何时，内核如果需要通过某个网络接口发送数据包，它都需要按照为这个接口配置的qdisc(排队规则)把数据包加入队列。然后，内核会尽可能多地从qdisc里面取出数据包，把它们交给网络适配器驱动模块。最简单的QDisc是pfifo它不对进入的数据包做任何的处理，数据包采用先入先出的方式通过队列。不过，它会保存网络接口一时无法处理的数据包。


一个网络接口上如果没有设置QDisc，pfifo_fast就作为缺省的QDisc。

CLASSFUL QDISC(分类QDisc)，可分类的qdisc包括： 

- CBQ： CBQ是Class Based Queueing(基于类别排队)的缩写。它实现了一个丰富的连接共享类别结构，既有限制(shaping)带宽的能力，也具有带宽优先级管理的能力。带宽限制是通过计算连接的空闲时间完成的。空闲时间的计算标准是数据包离队事件的频率和下层连接(数据链路层)的带宽。
- HTB： HTB是Hierarchy Token Bucket的缩写。通过在实践基础上的改进，它实现了一个丰富的连接共享类别体系。使用HTB可以很容易地保证每个类别的带宽，它也允许特定的类可以突破带宽上限，占用别的类的带宽。HTB可以通过TBF(Token Bucket Filter)实现带宽限制，也能够划分类别的优先级。
- PRIO： PRIO QDisc 不能限制带宽，因为属于不同类别的数据包是顺序离队的。使用PRIO QDisc可以很容易对流量进行优先级管理，只有属于高优先级类别的数据包全部发送完毕，才会发送属于低优先级类别的数据包。为了方便管理，需要使用iptables或者ipchains处理数据包的服务类型(Type Of Service,ToS)。

### htb分类 qdisc

tbf能对流量无差别控制，htb可以进一步进行更精细的控制

#### 针对IP、端口限速案例

```shell
$cat qdisc_bw.sh
#!/bin/bash
#针对不同的ip进行限速

#清空原有规则
tc qdisc del dev eth0 root

#创建根序列
tc qdisc add dev eth0 root handle 1: htb default 1

#创建一个主分类绑定所有带宽资源（60M）
tc class add dev eth0 parent 1:0 classid 1:1 htb rate 60Mbps burst 15k
#到这里可以使用了，整机速度限制到了60M

#创建子分类，ceil表示最大带宽
tc class add dev eth0 parent 1:1 classid 1:10 htb rate 2Mbps ceil 1Mbps burst 15k
tc class add dev eth0 parent 1:1 classid 1:20 htb rate 20Mbps ceil 30Mbps burst 15k

#为了避免一个会话永占带宽,添加随即公平队列sfq.
#perturb：是多少秒后重新配置一次散列算法，默认为10秒
#sfq,他可以防止一个段内的一个ip占用整个带宽
tc qdisc add dev eth0 parent 1:10 handle 10: sfq perturb 10
tc qdisc add dev eth0 parent 1:20 handle 20: sfq perturb 10

#创建过滤器
#对所有ip限速到1Mbps
tc filter add dev eth0 protocol ip parent 1:0 prio 2 u32 match ip dst 0.0.0.0/0 flowid 1:10
#对10.0.186.140限速在30Mbps
tc filter add dev eth0 protocol ip parent 1:0 prio 1 u32 match ip dst 10.0.186.140 flowid 1:20

#对端口进行filter限流
#tc filter add dev eth0 protocol ip parent 1:0 prio 1 u32 match ip sport 22 flowid 1:10

#查看以上规则
sudo tc class show dev eth0
sudo tc filter show dev eth0
```

限流100MB后的实际监控效果

![image-20211031205539407](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images/951413iMgBlog/image-20211031205539407.png)



## docker 中使用 tc

docker里无法使用的bug 可以参考 https://bugzilla.redhat.com/show_bug.cgi?id=1152231，解决方法就是升级tc版本，tc qdisc add 时加上direct_qlen参数

### 场景： 

故障注入的docker: 10.1.1.149

10.1.1.149上会模拟各种网络故障，但是中控机到该docker的连接需要不受影响



DEVICE_NAME=eth0

```
# 根规则，direct_qlen 1000必须加，否则在docker的虚拟网络跑不了
tc qdisc add dev ${DEVICE_NAME} root handle 1: htb  default 1024 direct_qlen 1000


# 建立两个类继承root
tc class add dev ${DEVICE_NAME} parent 1:0 classid 1:1 htb rate 10000mbit
tc class add dev ${DEVICE_NAME} parent 1:0 classid 1:2 htb rate 10000mbit


#新版本的tc在filter设置完后，所有网络都会断，类似黑名单，需要加qdisc才能恢复, 所以先让两个通道都能跑
# 队列采用公平的调度算法，保证网络通畅，perturb参数是每隔10秒换一次hash，进一步保障平均
tc qdisc add dev ${DEVICE_NAME} parent 1:1 sfq perturb 10
tc qdisc add dev ${DEVICE_NAME} parent 1:2 sfq perturb 10


# 加过滤规则
#1.队列1是和跳板机交互的网络，需要保持通畅
tc filter add dev ${DEVICE_NAME} protocol ip parent 1: prio 10 u32 match ip dst 10.0.0.200/32 flowid 1:1


#2.其他所有主机走队列2，实现网络模拟
tc filter add dev ${DEVICE_NAME} protocol ip parent 1: prio 10 u32 match ip dst 0.0.0.0/0 flowid 1:2

#队列2 开始网络模拟
#该命令将${DEVICE_NAME}网卡的耗时随机delay 100ms，延迟的尖刺在标准值的正负30ms, 最后的百分比数字是尖刺的相关系数

# 这边用replace是因为之前已经用add加过规则了
tc qdisc replace dev ${DEVICE_NAME} parent 1:2 netem delay 100ms 30ms 25%


#该命令将 ${DEVICE_NAME} 网卡的传输设置为随机丢掉10%的数据包, 成功率为50%
tc qdisc replace dev ${DEVICE_NAME} parent 1:2 netem loss 10% 50%


#该命令将 ${DEVICE_NAME} 网卡的传输设置为随机产生10%的重复数据包。
tc qdisc replace dev ${DEVICE_NAME} parent 1:2 netem duplicate 10%


#该命令将 ${DEVICE_NAME} 网卡的传输设置为:有25%的数据包会被立即发送,其他的延迟10ms,相关性是10%,产生乱序
tc qdisc replace dev ${DEVICE_NAME} parent 1:2 netem delay 10ms reorder 25% 10% 


#该命令将 ${DEVICE_NAME} 网卡的传输设置为随机产生9%的损坏的数据包
tc qdisc replace dev ${DEVICE_NAME} parent 1:2 netem corrupt 9%
```

恢复网络

```
#让网络恢复正常
tc qdisc replace dev ${DEVICE_NAME} parent 1:2 sfq perturb 10

# =================== 查看规则 ======================
tc filter show dev ${DEVICE_NAME}
tc class show dev ${DEVICE_NAME}
tc qdisc show dev ${DEVICE_NAME}

#====================== 清理 ======================
tc filter delete dev ${DEVICE_NAME} parent 1:0 protocol ip pref 10
tc qdisc del dev ${DEVICE_NAME} parent 1:2 netem
tc class del dev ${DEVICE_NAME} parent 1:0 classid 1:2
tc class del dev ${DEVICE_NAME} parent 1:0 classid 1:1
tc qdisc del dev ${DEVICE_NAME} root handle 1
```



## 参考资料

https://netbeez.net/blog/how-to-use-the-linux-traffic-control/

https://bootlin.com/blog/multi-queue-improvements-in-linux-kernel-ethernet-mvneta/