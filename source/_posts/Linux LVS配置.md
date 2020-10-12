---
title: Linux LVS 配置
date: 2018-02-24 17:30:03
categories:
    - Linux
tags:
    - Linux
    - LVS
---

# Linux LVS 配置



## NAT

- Enable IP forwarding. This can be done by adding the following to

  ```
  net.ipv4.ip_forward = 1 
  ```

then

```
ipvsadm -A -t 11.197.140.20:18089 -s rr //创建了一个rr lvs
// -m 表示nat模式，不加的话默认是route模式
ipvsadm -a -t 11.197.140.20:18089 -r 11.197.141.110:18089 -m //往lvs中添加一个RS
ipvsadm -ln
ipvsadm -a -t 11.197.140.20:18089 -r 11.197.140.20:28089  -m //往lvs中添加另外一个RS
ipvsadm -ln

//服务状态查看
#ipvsadm -L -n --stats --rate
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port               Conns   InPkts  OutPkts  InBytes OutBytes
  -> RemoteAddress:Port
TCP  11.197.140.20:18089                 5       48       48     2951     6938
  -> 11.197.140.20:28089                 3       33       33     1989     4938
  -> 11.197.141.110:28089                2       15       15      962     2000

[root@g71k07160.cloud.sg52 /root]
#ipvsadm -L -n
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  11.197.140.20:18089 wlc
  -> 11.197.140.20:28089          Masq    1      0          0
  -> 11.197.141.110:28089         Masq    1      0          0
```

## LVS 工作原理

1.当客户端的请求到达负载均衡器的内核空间时，首先会到达PREROUTING链。 

2.当内核发现请求数据包的目的地址是本机时，将数据包送往INPUT链。 

3.LVS由用户空间的ipvsadm和内核空间的IPVS组成，ipvsadm用来定义规则，IPVS利用ipvsadm定义的规则工作，IPVS工作在INPUT链上,当数据包到达INPUT链时，首先会被IPVS检查，如果数据包里面的目的地址及端口没有在规则里面，那么这条数据包将被放行至用户空间。 

4.如果数据包里面的目的地址及端口在规则里面，那么这条数据报文将被修改目的地址为事先定义好的后端服务器，并送往POSTROUTING链。 

5.最后经由POSTROUTING链发往后端服务器。

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/08cb9d37f580b03f37fcace92e21d2e3.png)

## netfilter 原理

Netfilter 由多个表(table)组成，每个表又由多个链(chain)组成(此处可以脑补二维数组的矩阵了)，链是存放过滤规则的“容器”，里面可以存放一个或多个iptables命令设置的过滤规则。目前的表有4个：`raw table`, `mangle table`, `nat table`, `filter table`。Netfilter 默认的链有：`INPUT`, `OUTPUT`, `FORWARD`, `PREROUTING`, `POSTROUTING`，根据`表`的不同功能需求，不同的表下面会有不同的链，链与表的关系可用下图直观表示：

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/1039cdda7040f20582f36a6a560e4e2e.png)

## 参考资料

http://www.ultramonkey.org/papers/lvs_tutorial/html/