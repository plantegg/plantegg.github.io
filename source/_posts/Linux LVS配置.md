---
title: Linux LVS 配置
date: 2018-02-24 17:30:03
categories:
    - Linux
tags:
    - Linux
    - LVS
    - keepalived
---

# Linux LVS 配置



## NAT

- Enable IP forwarding. This can be done by adding the following to

  ```
  net.ipv4.ip_forward = 1 
  ```

then

```
ipvsadm -A -t 172.26.137.117:9376 -s rr //创建了一个rr lvs
// -m 表示nat模式，不加的话默认是route模式
ipvsadm -a -t 172.26.137.117:9376 -r 172.20.22.195:9376 -m //往lvs中添加一个RS
ipvsadm -ln
ipvsadm -a -t 172.26.137.117:9376 -r 172.20.22.196:9376 -m //往lvs中添加另外一个RS
ipvsadm -ln

//删除realserver
ipvsadm -a -t 100.81.131.221:18507 -r 100.81.131.237:8507 -m

//服务状态查看
#ipvsadm -L -n --stats|--rate
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port               Conns   InPkts  OutPkts  InBytes OutBytes
  -> RemoteAddress:Port
TCP  11.197.140.20:18089                 5       48       48     2951     6938
  -> 11.197.140.20:28089                 3       33       33     1989     4938
  -> 11.197.141.110:28089                2       15       15      962     2000

#清空统计数据
#ipvsadm --zero
#列出所有连接信息
#/sbin/ipvsadm -L -n --connection

#ipvsadm -L -n
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  11.197.140.20:18089 wlc
  -> 11.197.140.20:28089          Masq    1      0          0
  -> 11.197.141.110:28089         Masq    1      0          0
```

## ipvsadm常用参数

```
添加虚拟服务器
    语法:ipvsadm -A [-t|u|f]  [vip_addr:port]  [-s:指定算法]
    -A:添加
    -t:TCP协议
    -u:UDP协议
    -f:防火墙标记
    -D:删除虚拟服务器记录
    -E:修改虚拟服务器记录
    -C:清空所有记录
    -L:查看
添加后端RealServer
    语法:ipvsadm -a [-t|u|f] [vip_addr:port] [-r ip_addr] [-g|i|m] [-w 指定权重]
    -a:添加
    -t:TCP协议
    -u:UDP协议
    -f:防火墙标记
    -r:指定后端realserver的IP
    -g:DR模式
    -i:TUN模式
    -m:NAT模式
    -w:指定权重
    -d:删除realserver记录
    -e:修改realserver记录
    -l:查看
通用:
    ipvsadm -ln:查看规则
    service ipvsadm save:保存规则
```

## 通过keepalived来检测RealServer的状态

```
# cat /etc/keepalived/keepalived.conf
global_defs {
   notification_email {
   }
   router_id LVS_DEVEL
   vrrp_skip_check_adv_addr
   vrrp_strict
   vrrp_garp_interval 0
   vrrp_gna_interval 0
}
#添加虚拟服务器
#相当于 ipvsadm -A -t 172.26.137.117:9376 -s wrr 
virtual_server 172.26.137.117 9376 {
    delay_loop 3             #服务健康检查周期,单位是秒
    lb_algo wrr                 #调度算法
    lb_kind NAT                 #模式 
#   persistence_timeout 50   #会话保持时间,单位是秒
    protocol TCP             #TCP协议转发

#添加后端realserver
#相当于 ipvsadm -a -t 172.26.137.117:9376 -r 172.20.56.148:9376 -w 1
    real_server 172.20.56.148 9376 {
        weight 1
        TCP_CHECK {               # 通过TcpCheck判断RealServer的健康状态
            connect_timeout 2     # 连接超时时间
            nb_get_retry 3        # 重连次数
            delay_before_retry 1  # 重连时间间隔
            connect_port 9376     # 检测端口
        }
    }
    
    real_server 172.20.248.147 9376 {
        weight 1
        HTTP_GET {
            url { 
              path /
	          status_code 200
            }
            connect_timeout 3
            nb_get_retry 3
            delay_before_retry 3
        }
    }
}
```

修改keepalived配置后只需要执行reload即可生效

> systemctl reload keepalived

## timeout

```
[root@poc117 ~]# ipvsadm -L --timeout
Timeout (tcp tcpfin udp): 900 120 300
[root@poc117 ~]# ipvsadm --set 1 2 1
[root@poc117 ~]# ipvsadm -L --timeout
Timeout (tcp tcpfin udp): 1 2 1
```

## 创建虚拟网卡

```
To make this interface you'd first need to make sure that you have the dummy kernel module loaded. You can do this like so:

$ sudo lsmod | grep dummy
$ sudo modprobe dummy
$ sudo lsmod | grep dummy
dummy                  12960  0 
With the driver now loaded you can create what ever dummy network interfaces you like:

$ sudo ip link add eth10 type dummy
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

https://www.jianshu.com/p/d4222ce9b032

https://www.cnblogs.com/zhangxingeng/p/10595058.html