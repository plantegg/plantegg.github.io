---
title: Git HTTP Proxy and SSH Proxy 
date: 2018-03-14 10:30:03
categories: SSH
tags:
    - Proxy
    - HTTP Proxy
    - SSH Proxy
    - Socks5
---

# 如何设置git Proxy

## git http proxy 


> 首先你要有一个socks5代理服务器，从 github.com 拉代码的话海外的代理速度才快，可以用阿里郎的网络加速，也可以自己配置shadowsocks这样的代理。
> 
> Windows阿里郎会在本地生成socks5代理：127.0.0.1:13658

下面的例子假设你的socks5代理是： 127.0.0.1:13658

### 执行如下命令

    git config --global http.proxy socks5://127.0.0.1:13658

上面的命令实际上是修改了 .gitconfig：

    $cat ~/.gitconfig   
    [http]
    	proxy = socks5://127.0.0.1:13658

现在git的http代理就配置好了， git clone https://github.com/torvalds/linux.git 速度会快到你流泪（取决于你的代理速度），我这里是从每秒10K到了3M 。

注意：

- http.proxy就可以了，不需要配置https.proxy
- 这个http代理仅仅针对 git clone **https://** 的方式生效

## 配置git ssh proxy

如果想要 git clone **git@**github.com:torvalds/linux.git 也要快起来的话 需要配置 ssh proxy

> 这里要求你有一台海外的服务器，能ssh登陆，做好免密码，假设这台服务器的IP是：2.2.2.2


修改（如果没有就创建这个文件）~/.ssh/config, 内容如下：
    
    $cat ~/.ssh/config 
    host github.com
    #LogLevel DEBUG3
    ProxyCommand ssh -l root 2.2.2.2 exec /usr/bin/nc %h %p

然后 git clone git@github.com:torvalds/linux.git 也能飞起来了

需要注意你的代理服务器2.2.2.2上nc有没有安装，没有的话yum装上，装上后再检查一下安装的位置，对应配置中的 /usr/bin/nc
    
写这些主要是从Google上搜索到的一些文章，http的倒还是靠谱，但是ssh的就有点乱，还要在本地安装东西，对nc版本有要求之类的，于是就折腾了一下，上面的方式都是靠谱的。

整个原理还是穿墙术。 可以参考 ：[SSH 高级用法和技巧大全](https://www.atatech.org/articles/76026)  