---
title: mac 路由和DSN相关知识
date: 2021-01-03 17:30:03
categories:
    - 其它
tags:
    - Mac
    - route
    - DNS

---

# mac 路由和DSN相关知识

Mac 下上网,尤其是在双网卡一起使用的时候, 一个网卡连内网，一个网卡连外网，经常会碰到ip不通(路由问题,比较好解决)或者dns解析不了问题. 或者是在通过VPN连公司网络会插入一些内网route,导致部分网络访问不了.

即使对Linux下的DNS解析无比熟悉了，但是在Mac下还是花了一些时间来折腾，配置不好路由和DNS是不配使用Mac的，所以记录下。

## route

如果ip不通就看路由表, 根据内外网IP增加/删除相应的路由信息,常用命令如下:

```shell
 sudo route -n add 10.176/16 192.168.3.1
 sudo route -n add -net 10.176.0.0/16 192.168.3.1 //添加路由, 访问10.176.0.0/16 走192.168.3.1 
 sudo route -n delete -net 10.176.0.0/16 192.168.3.1
 sudo route -n delete 0.0.0.0 192.168.184.1
 sudo route -n add 0.0.0.0 192.168.184.1  //添加默认路由访问外网 
 
 sudo route -n delete 0.0.0.0 192.168.3.1
 sudo route -n add 10.176/16 192.168.3.1
 sudo route -n delete 0.0.0.0 192.168.184.1 -ifscope en0
 sudo route -n add 0.0.0.0 192.168.184.1 
 sudo networksetup -setdnsservers 'Apple USB Ethernet Adapter' 202.106.196.115 202.106.0.20 114.114.114.114
 
 ip route get 8.8.8.8
 netstat -rn  //查看路由  
 netstat -nr -f inet  //只看ipv4相关路由
```

如果本来IP能通,连上VPN后就通不了,那一定是VPN加入了一些更精细的路由导致原来的路由不通了,那么很简单停掉VPN就能恢复或者增加一条更精确的路有记录进去,或者删掉VPN增加的某条路由.

## DNS 解析

mac下DNS解析问题搞起来比较费劲,相应的资料也不多, 经过上面的操作后如果IP能通,域名解析有问题,一般都是DNS解析出了问题

[mac下 /etc/resolv.conf 不再用来解析域名, 只有nslookup能用](https://shockerli.net/post/macos-hostname-scutil/)

```shell
cat /etc/resolv.conf                                                
#
# macOS Notice
#
# This file is not consulted for DNS hostname resolution, address
# resolution, or the DNS query routing mechanism used by most
# processes on this system.
#
# To view the DNS configuration used by this system, use:
#   scutil --dns

scutil --dns //查看DNS 解析器
scutil --nwi //查看网络
```

解析出了问题先检查nameserver

scutil --dns 一般会展示一大堆的resolver, 每个resolver又可以有多个nameserver

> A scoped DNS query can use only specified network interfaces (e.g. Ethernet or WiFi), while non-scoped can use any available interface.
>
> More verbosely, an application that wants to resolve a name, sends a *request* (either scoped or non-scoped) to a resolver (usually a DNS client application), if the resolver does not have the answer cached, it sends a DNS *query* to a particular nameserver (and this goes through one interface, so it is always "scoped").
>
> In your example resolver #1 "for scoped queries" can use only en0 interface (Ethernet).

### 修改 nameserver

默认用第一个resolver, 如果第一个resolver没有nameserver那么域名没法解析, 可以修改dns resolver的nameserver: 

```shell
#networksetup -listallnetworkservices  //列出网卡service, 比如 wifi ,一下是我的macpro输出
An asterisk (*) denotes that a network service is disabled.
USB 10/100/1000 LAN
Apple USB Ethernet Adapter
Wi-Fi
Bluetooth PAN
Thunderbolt Bridge
#sudo networksetup -setdnsservers 'Wi-Fi' 202.106.196.115 202.106.0.20 114.114.114.114 //修改nameserver
#networksetup -getdnsservers Wi-Fi //查看对应的nameserver, 跟 scutil --dns 类似
```

如上,只要是你的nameserver工作正常那么DNS就肯定回复了

删掉所有DNS nameserver:

> One note to anyone wanting to remove the DNS, just write "empty" (without the quotes) instead of the DNS: `sudo networksetup -setdnsservers <networkservice> empty`

## 总结

mac同时连wifi(外网)和有线(内网), 如果内网干扰了访问外部ip, 就检查路由表,调整顺序. 如果内网干扰了dns,可以通过scutil --dns查看dns顺序到系统配置里去掉不必要的resolver