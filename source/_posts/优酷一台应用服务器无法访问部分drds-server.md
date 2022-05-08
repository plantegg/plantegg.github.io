---
title: 部分机器网络不通
date: 2018-08-26 16:30:03
categories: troubleshooting
tags:
    - Linux
    - performance
    - troubleshooting
    - network
---

# 部分机器网络不通

## 问题

应用机器： 10.100.10.201 这台机器抛502异常比较多，进一步诊断发现 ping youku.tddl.tbsite.net 的时候解析到 10.100.53.15/16就不通

直接ping 10.100.53.15/16 也不通，经过诊断发现是交换机上记录了两个 10.100.10.201的mac地址导致网络不通。

![youku-mac-ip.gif](/images/oss/9deff3045e3213df81c3ad785cfddefa.gif)

**上图是不通的IP，下图是正常IP**

经过调查发现是土豆业务也用了10.100.10.201这个IP导致交换机的ARP mac table冲突，土豆删除这个IP后故障就恢复了。

### 当时交换机上发现的两条记录：

    00:18:51:38:b1:cd 10.100.10.201 
    8c:dc:d4:b3:af:14 10.100.10.201
	
	
	