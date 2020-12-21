---
title: windows7的wifi总是报DNS域名异常无法上网
date: 2017-12-13 10:30:03
categories: dns
tags:
    - Windows
    - VirtualBox
    - DNS
---


# 就是要你懂DNS--windows7的wifi总是报DNS域名异常无法上网


Windows7笔记本+公司wifi（dhcp）环境下，用着用着dns服务不可用（无法通过域名上网，通过IP地址可以访问），找到一个跟我一模一样的Case了：https://superuser.com/questions/629559/why-is-my-computer-suddenly-using-nbns-instead-of-dns 一样的环境，看来这个问题也不只是我一个人碰到了。

其实之前一直有，一个月偶尔出来一两次，以为是其他原因就没管，这次换了新电脑还是这个毛病有点不能忍，于是决定彻底解决一下


这个问题出现后，通过下面三个办法都可以让DNS恢复正常：

1. 重启大法，恢复正常
2. 禁用wifi驱动再启用，恢复正常
3. 不用DHCP，而是手工填入一个DNS服务器，比如114.114.114.114【公司域名就无法解析了】

如果只是停用一下wifi再启用问题还在。

## 找IT升级了网卡驱动不管用

## 重现的时候抓包看看

![image.png](http://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/c110f232829cbea9d5503166531d7f1d.png)

这肯定不对了，254上根本就没有跑DNS服务，可是当时没有检查 ipconfig，看看是否将网关IP动态配置到dns server里面去了，等下次重现后再确认吧。

第二次重现后抓包，发现不一样了：

![image.png](http://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/295797df3c311d6902d68fb16f6212d8.png)

出来一个 NBNS 的鬼东西，赶紧查了一下，把它禁掉，如下图所示：

![image.png](http://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/9f06b680ae1f8b4cb781360f7c0ac2eb.png)

把NBNS服务关了就能上网了，同时也能抓到各种DNS Query包

## 事情没有这么简单

过一段时间后还是会出现上面的症状，但是因为NBNS关闭了，所以这次 ping www.baidu.com 的时候没有任何包了，没有DNS Query包，也没有NBNS包，这下好尴尬。

尝试Enable NBNS，又恢复了正常，看来开关 NBNS 仍然只是一个workaround，他不是导致问题的根因，开关一下没有真正解决问题，只是临时相当于重启了dns修复了问题而已。

继续在网络不通的时候尝试直接ping dns server ip，发现一个奇怪的现象，丢包很多，丢包的时候还总是从 192.168.0.11返回来的，这就奇怪了，我的笔记本基本IP是30开头的，dns server ip也是30开头的，route 路由表也是对的，怎么就走到 192.168.0.11 上了啊（[参考我的另外一篇文章，网络到底通不通](https://www.atatech.org/articles/80573)），赶紧 ipconfig /all | grep 192 

![image.png](http://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/5212ee5e7496dafb122ce144293184e1.png)

发现这个IP是VirtualBox虚拟机在笔记本上虚拟出来的网卡IP，这下我倒是能理解为啥总是我碰到这个问题了，因为我的工作笔记本一拿到后第一件事情就是装VirtualBox 跑虚拟机。

VirtualBox为啥导致了这个问题就是一个很偏的方向，我实在无能为力了，尝试找到了一个和VirtualBox的DNS相关的开关命令，只能死马当或马医了（像极了算命大师和老中医）

    ./VBoxManage.exe  modifyvm "ubuntu" --natdnshostresolver1 on

执行完上面的命令观察了一个多月了，暂时没有再出现这个问题，忐忑中啊……

## 另外DHCP也许可以做一些事情

下面是来自微软官方的建议：

>  One big advise – do not disable the DHCP Client service on any server, whether the machine is a DHCP client or statically configured. Somewhat of a misnomer, this service performs Dynamic DNS registration and is tied in with the client resolver service. If disabled on a DC, you’ll get a slew of errors, and no DNS queries will get resolved.
> 
> No DNS Name Resolution If DHCP Client Service Is Not Running. When you try to resolve a host name using Domain Name Service (DNS), the attempt is unsuccessful. Communication by Internet Protocol (IP) address (even to …
> 
> http://support.microsoft.com/kb/268674

from： https://blogs.msmvps.com/acefekay/2009/11/29/dns-wins-netbios-amp-the-client-side-resolver-browser-service-disabling-netbios-direct-hosted-smb-directsmb-if-one-dc-is-down-does-a-client-logon-to-another-dc-and-dns-forwarders-algorithm/#section4

## NBNS也许会导致nslookup OK but ping fail的问题

https://www.experts-exchange.com/questions/28894006/NetBios-name-resolution-instead-of-DNS.html



## 总结

碰到问题绕过去也不是长久之计，还是要从根本上了解问题的本质，这个问题在其它公司没有碰到过，我觉得跟公司的DNS、DHCP的配置也有点关系吧，但是这个我不好确认，应该还有好多用Windows本本的同学同样会碰到这个问题的，希望对你们有些帮助

https://support.microsoft.com/en-us/help/172218/microsoft-tcp-ip-host-name-resolution-order

http://www.man7.org/linux/man-pages/man5/resolv.conf.5.html

----------

## 本文附带鸡汤：

**有些技能初学很难，大家水平都差不多，但是日积月累就会形成极强的优势，而且一旦突破某个临界点，它就会突飞猛进，这种技能叫指数型技能，是值得长期投资的，比如物理学就是一种指数型技能。**

那么抓包算不算呢？​​
