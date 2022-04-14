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

```shell
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
#流量统计
ipvsadm -L -n --stats -t 192.168.1.10:28080 //-t service-address
Prot LocalAddress:Port               Conns   InPkts  OutPkts  InBytes OutBytes
  -> RemoteAddress:Port
TCP  192.168.1.10:28080              39835    1030M  863494K     150G     203G
  -> 172.20.62.78:3306                 774 46173852 38899725    6575M    9250M
  -> 172.20.78.79:3306                 781 45106566 37997254    6421M    9038M
  -> 172.20.81.80:3306                 783 45531236 38387112    6479M    9128M
  
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

### 查看连接对应的RS ip和端口

```shell
# ipvsadm -Lcn |grep "10.68.128.202:1406"
TCP 15:01  ESTABLISHED 10.68.128.202:1406 10.68.128.202:3306 172.20.188.72:3306

# ipvsadm -Lcn | head -10
IPVS connection entries
pro expire state       source             virtual            destination
TCP 15:01  ESTABLISHED 10.68.128.202:1390 10.68.128.202:3306 172.20.185.132:3306
TCP 15:01  ESTABLISHED 10.68.128.202:1222 10.68.128.202:3306 172.20.165.202:3306
TCP 15:01  ESTABLISHED 10.68.128.202:1252 10.68.128.202:3306 172.20.222.65:3306
TCP 15:01  ESTABLISHED 10.68.128.202:1328 10.68.128.202:3306 172.20.149.68:3306

ipvsadm -Lcn
IPVS connection entries
pro expire state       source             virtual            destination
TCP 00:57  NONE        110.184.96.173:0   122.225.32.142:80  122.225.32.136:80
TCP 01:57  FIN_WAIT    110.184.96.173:54568 122.225.32.142:80  122.225.32.136:80
```

当一个client访问vip的时候，ipvs或记录一条状态为NONE的信息，expire初始值是persistence_timeout的值，然后根据时钟主键变小，在以下记录存在期间，同一client ip连接上来，都会被分配到同一个后端。

FIN_WAIT的值就是tcp tcpfin udp的超时时间，当NONE的值为0时，如果FIN_WAIT还存在，那么NONE的值会从新变成60秒，再减少，直到FIN_WAIT消失以后，NONE才会消失，只要NONE存在，同一client的访问，都会分配到统一real server。

## 通过keepalived来检测RealServer的状态

```shell
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

LVS的持续时间有2个

1. 把同一个cip发来请求到同一台RS的持久超时时间。（-p persistent）
2. 一个链接创建后空闲时的超时时间，这个超时时间分为3种。
   - tcp的空闲超时时间。
   - lvs收到客户端tcp fin的超时时间
   - udp的超时时间

连接空闲超时时间的设置如下:

```shell
[root@poc117 ~]# ipvsadm -L --timeout
Timeout (tcp tcpfin udp): 900 120 300
[root@poc117 ~]# ipvsadm --set 1 2 1
[root@poc117 ~]# ipvsadm -L --timeout
Timeout (tcp tcpfin udp): 1 2 1

ipvsadm -Lcn //查看
```

### persistence_timeout

用于保证同一ip client的所有连接在timeout时间以内都发往同一个RS，比如ftp 21port listen认证、20 port传输数据，那么希望同一个client的两个连接都在同一个RS上。

persistence_timeout 会导致负载不均衡，timeout时间越大负载不均衡越严重。大多场景下基本没什么意义

PCC用来实现把某个用户的所有访问在超时时间内定向到同一台REALSERVER，这种方式在实际中不常用

```
ipvsadm -A -t 192.168.0.1:0 -s wlc -p 600(单位是s)     //port为0表示所有端口
ipvsadm -a -t 192.168.0.1:0 -r 192.168.1.2 -w 4 -g
ipvsadm -a -t 192.168.0.1:0 -r 192.168.1.3 -w 2 -g
```

此时测试一下会发现通过HTTP访问VIP和通过SSH登录VIP的时候都被定向到了同一台REALSERVER上面了

## lvs 管理

```shell
  257  [2021-09-13 22:11:26] lscpu
  258  [2021-09-13 22:11:34] dmidecode | grep Ser
  259  [2021-09-13 22:11:53] dmidecode | grep FT
  260  [2021-09-13 22:11:58] dmidecode | grep 2500
  261  [2021-09-13 22:12:03] dmidecode
  262  [2021-09-13 22:12:27] lscpu
  263  [2021-09-13 22:12:37] ipvsadm  -ln
  264  [2021-09-13 22:12:59] ipvsadm  -lnvt 166.100.128.234:3306 --in-vid 1560537
  265  [2021-09-13 22:14:37] base_admin --help
  266  [2021-09-13 22:14:44] base_admin --cpu-usage
  267  [2021-09-13 22:14:56] ip link
  268  [2021-09-13 22:16:04] base_admin --cpu-usage
  269  [2021-09-13 22:16:28] cat /usr/local/etc/nf-var-config
  270  [2021-09-13 22:16:43] base_admin --cpu-usage
  271  [2021-09-13 22:17:35] ipvsadm  -lnvt 166.100.128.234:3306 --in-vid 1560537
  272  [2021-09-13 22:18:17] base_admin --cpu-usage
  273  [2021-09-13 22:22:02] ls
  274  [2021-09-13 22:22:06] ps -aux
  275  [2021-09-13 22:22:17] tsar --help
  276  [2021-09-13 22:22:24] ipvsadm  -lnvt 166.100.128.234:3306 --in-vid 1560537
  277  [2021-09-13 22:22:31] ipvsadm  -lnvt 166.100.128.234:3306 --in-vid 1560537 --stat
  278  [2021-09-13 22:22:33] ipvsadm  -lnvt 166.100.128.234:3306 --in-vid 1560537 --stats
  279  [2021-09-13 22:23:10] tsar --lvs -li1 -D|awk '{print $1,"  ",($6)*8.0}'
  280  [2021-09-13 22:24:29] ipvsadm  -lnvt 166.100.128.234:3306 --in-vid 1560537 --stats
  281  [2021-09-13 22:25:26] tsar --lvs -li1 -D
  282  [2021-09-13 22:25:46] ipvsadm  -lnvt 166.100.128.234:3306 --in-vid 1560537
  283  [2021-09-13 22:26:37] appctl -cas | grep conns
  284  [2021-09-13 22:31:16] ipvsadm  -ln
  286  [2021-09-13 22:31:43] ipvsadm  -lnvt 166.100.128.234:3306 --in-vid 1560537 --stats
  292  [2021-09-13 22:38:16] rpm -qa | grep slb
  293  [2021-09-13 22:42:30] appctl -cas | grep conns
  294  [2021-09-13 22:43:03] base_admin --cpu-usage
  295  [2021-09-13 22:45:42] tsar --lvs -li1 -D|awk '{print $1,"  ",($6)*8.0}'
  296  [2021-09-13 22:57:20] base_admin --cpu-usage
  297  [2021-09-13 22:58:16] tsar --lvs -li1 -D|awk '{print $1,"  ",($6)*8.0}'
  298  [2021-09-13 22:59:38] ipvsadm  -lnvt 166.100.128.234:3306 --in-vid 1560537 --stats
  299  [2021-09-13 23:00:16] appctl -a | grep conn
  300  [2021-09-13 23:00:24] base_admin --cpu-usage
  301  [2021-09-13 23:00:50] appctl -cas | grep conns
  302  [2021-09-13 23:01:15] base_admin --cpu-usage
  303  [2021-09-13 23:01:21] ipvsadm  -lnvt 166.100.128.234:3306 --in-vid 1560537 --stats
  304  [2021-09-13 23:02:09] appctl -cas | grep conns
  305  [2021-09-13 23:03:12] base_admin --cpu-usage
  306  [2021-09-13 23:04:43] ipvsadm  -lnvt 166.100.128.234:3306 --in-vid 1560537 --stats | head -3
  307  [2021-09-13 23:05:38] base_admin --cpu-usage
  308  [2021-09-13 23:06:10] tsar --lvs -li1 -D|awk '{print $1,"  ",($6)*8.0}'
  309  [2021-09-13 23:06:39] base_admin --cpu-usage
  310  [2021-09-13 23:15:59] appctl -a | grep conn_limit_enable
  311  [2021-09-13 23:15:59] appctl -a | grep cps_limit_enable
  312  [2021-09-13 23:15:59] appctl -a | grep inbps_limit_enable
  313  [2021-09-13 23:15:59] appctl -a | grep outbps_limit_enable
  314  [2021-09-13 23:17:13] appctl -w conn_limit_enable=0
  315  [2021-09-13 23:17:13] appctl -w cps_limit_enable=0
  316  [2021-09-13 23:17:13] appctl -w inbps_limit_enable=0
  317  [2021-09-13 23:17:13] appctl -w outbps_limit_enable=0
  318  [2021-09-13 23:17:43] appctl -cas | grep conn
  319  [2021-09-13 23:17:44] appctl -cas | grep conns
  320  [2021-09-13 23:19:30] last=0;while true;do pre=`ipvsadm -lnvt 166.100.128.234:3306 --in-vid 1560537 --stats| grep TCP|awk '{print $4}'`;let cut=pre-last;echo $cut;last=$pre;sleep 1;done
  321  [2021-09-13 23:19:56] ipvsadm -lnvt 166.100.128.234:3306 --in-vid 1560537 --stats| grep TCP|awk '{print $4}'
  322  [2021-09-13 23:20:01] last=0;while true;do pre=`ipvsadm -lnvt 166.100.128.234:3306 --in-vid 1560537 --stats| grep TCP|awk '{print $4}'`;let cut=pre-last;echo $cut;last=$pre;sleep 1;done
  323  [2021-09-13 23:20:55] base_admin --cpu-usage
  324  [2021-09-13 23:22:05] ipvsadm  -lnvt 166.100.129.249:3306 --in-vid 1560537
  325  [2021-09-13 23:22:05] ipvsadm  -lnvt 166.100.128.219:3306 --in-vid 1560537
  326  [2021-09-13 23:22:05] ipvsadm  -lnvt 166.100.129.40:80 --in-vid 1560537
  327  [2021-09-13 23:24:22] base_admin --cpu-usage
  328  [2021-09-13 23:24:29] last=0;while true;do pre=`ipvsadm -lnvt 166.100.128.234:3306 --in-vid 1560537 --stats| grep TCP|awk '{print $4}'`;let cut=pre-last;echo $cut;last=$pre;sleep 1;done
  329  [2021-09-13 23:24:50] ipvsadm  -lnvt 166.100.129.249:3306 --in-vid 1560537
  332  [2021-09-13 23:25:38] ipvsadm  -lnvt 166.100.128.234:3306 --in-vid 1560537 —stats
  333  [2021-09-13 23:25:57] ipvsadm  -lnvt 166.100.129.249:3306 --in-vid 1560537 --stats
  334  [2021-09-13 23:25:58] ipvsadm  -lnvt 166.100.128.219:3306 --in-vid 1560537 --stats
  335  [2021-09-13 23:25:58] ipvsadm  -lnvt 166.100.129.40:80 --in-vid 1560537 --stats
  336  [2021-09-13 23:26:45] last=0;while true;do pre=`ipvsadm -lnvt 166.100.129.40:80 --in-vid 1560537 --stats| grep TCP|awk '{print $4}'`;let cut=pre-last;echo $cut;last=$pre;sleep 1;done
```



## LVS 工作原理

1.当客户端的请求到达负载均衡器的内核空间时，首先会到达PREROUTING链。 

2.当内核发现请求数据包的目的地址是本机时，将数据包送往INPUT链。 

3.LVS由用户空间的ipvsadm和内核空间的IPVS组成，ipvsadm用来定义规则，IPVS利用ipvsadm定义的规则工作，IPVS工作在INPUT链上,当数据包到达INPUT链时，首先会被IPVS检查，如果数据包里面的目的地址及端口没有在规则里面，那么这条数据包将被放行至用户空间。 

4.如果数据包里面的目的地址及端口在规则里面，那么这条数据报文将被修改目的地址为事先定义好的后端服务器，并送往POSTROUTING链。 

5.最后经由POSTROUTING链发往后端服务器。

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/oss/08cb9d37f580b03f37fcace92e21d2e3.png)

## netfilter 原理

Netfilter 由多个表(table)组成，每个表又由多个链(chain)组成(此处可以脑补二维数组的矩阵了)，链是存放过滤规则的“容器”，里面可以存放一个或多个iptables命令设置的过滤规则。目前的表有4个：`raw table`, `mangle table`, `nat table`, `filter table`。Netfilter 默认的链有：`INPUT`, `OUTPUT`, `FORWARD`, `PREROUTING`, `POSTROUTING`，根据`表`的不同功能需求，不同的表下面会有不同的链，链与表的关系可用下图直观表示：

![image.png](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/1039cdda7040f20582f36a6a560e4e2e.png)

## OSPF + LVS

OSPF：Open Shortest Path First 开放最短路径优先，SPF算法也被称为Dijkstra算法，这是因为最短路径优先算法SPF是由荷兰计算机科学家狄克斯特拉于1959年提出的。

通过OSPF来替换keepalived，解决两个LVS节点的高可用，以及流量负载问题。keepalived两个节点只能是master-slave模式，而OSPF两个节点都是master，同时都有流量

![img](https://bbsmax.ikafan.com/static/L3Byb3h5L2h0dHAvczMuNTFjdG8uY29tL3d5ZnMwMi9NMDEvMjMvRkUvd0tpb20xTktBSnpqN2JNS0FBRTRQTzI1LVh3ODY2LmpwZw==.jpg)



这个架构与LVS+keepalived 最明显的区别在于，两台Director都是Master 状态，而不是Master-Backup，如此一来，两台Director 地位就平等了。剩下的问题，就是看如何在这两台Director 间实现负载均衡了。这里会涉及路由器领域的一个概念：等价多路径

### **ECMP（等价多路径）**

ECMP（Equal-CostMultipathRouting）等价多路径，存在多条不同链路到达同一目的地址的网络环境中，如果使用传统的路由技术，发往该目的地址的数据包只能利用其中的一条链路，其它链路处于备份状态或无效状态，并且在动态路由环境下相互的切换需要一定时间，而等值多路径路由协议可以在该网络环境下**同时**使用多条链路，不仅增加了传输带宽，并且可以无时延无丢包地备份失效链路的数据传输。

ECMP最大的特点是实现了等值情况下，多路径负载均衡和链路备份的目的，在静态路由和OSPF中基本上都支持ECMP功能。



## 参考资料

http://www.ultramonkey.org/papers/lvs_tutorial/html/

https://www.jianshu.com/p/d4222ce9b032

https://www.cnblogs.com/zhangxingeng/p/10595058.html

[lvs持久性工作原理和配置](http://xstarcd.github.io/wiki/sysadmin/lvs_persistence.html)

