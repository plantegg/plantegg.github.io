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

### 配置git http proxy

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

### [配置git 走socks](https://superuser.com/questions/454210/how-can-i-use-ssh-with-a-socks-5-proxy)

如果没有海外服务器，但是本地已经有了socks5 服务那么也可以直接走socks5来proxy所有git 流量

```
cat ~/.ssh/config
host github.com
ProxyCommand  /usr/bin/nc -X 5 -x 127.0.0.1:12368 %h %p  //走本地socks5端口来转发代理流量
#ProxyCommand ssh -l root jump exec /usr/bin/nc %h %p    //这个是走 jump
```

nc代理参数-X proxy_version 指定 nc 请求时使用代理服务的协议

- `proxy_version` 为 `4` : 表示使用的代理为 SOCKS4 代理
- `proxy_version` 为 `5` : 表示使用的代理为 SOCKS5 代理
- `proxy_version` 为 `connect` : 表示使用的代理为 HTTPS 代理
- 如果不指定协议, 则默认使用的代理为 SOCKS5 代理

> **-X** *proxy_version*
> Requests that **nc** should use the specified protocol when talking to the proxy server. Supported protocols are ''4'' (SOCKS v.4), ''5'' (SOCKS v.5) and ''connect'' (HTTPS proxy). If the protocol is not specified, SOCKS version 5 is used.



## 我的拉起代理自动脚本

下面的脚本总共拉起了三个socks5代理，端口13657-13659，其中13659是阿里郎网络加速的代理
最后还启动了一个8123的http 代理（有些场景只支持http代理）

macos：
```
listPort=`/usr/sbin/netstat -ant |grep "127.0.0.1.13658" |grep LISTEN`
if [[ "$listPort" != tcp4* ]]; then
    #sh ~/ssh-jump.sh
    nohup ssh -qTfnN -D 13658 root@jump vmstat 10  >/dev/null 2>&1
    echo "start socks5 on port 13658"
fi

listPort=`/usr/sbin/netstat -ant |grep "127.0.0.1.13657" |grep LISTEN`
if [[ "$listPort" != tcp4* ]]; then
    nohup ssh -qTfnN -D 13657 azureuser@yu2 vmstat 10  >/dev/null 2>&1
    echo "start socks5 on port 13657"
fi

listPort=`/usr/sbin/netstat -ant |grep "127.0.0.1.13659" |grep LISTEN`
#if [ "$listPort" != "tcp4       0      0  127.0.0.1.13659        *.*                    LISTEN     " ]; then
if [[ "$listPort" != tcp4* ]]; then
    Applications/AliLang.app/Contents/Resources/AliMgr/AliMgrSockAgent -bd 参数1 -wd 工号 -td 参数2 >~/jump.log 2>&1
    echo "start listPort $listPort"
fi

listPort=`/usr/sbin/netstat -ant |grep "127.0.0.1.8123 " |grep LISTEN`
if [[ "$listPort" != tcp4* ]]; then
    polipo socksParentProxy=127.0.0.1:13659 1>~/jump.log 2>1&
    echo "start polipo http proxy at 8123"
fi

#分别测试http和socks5代理能工作
#curl --proxy http://127.0.0.1:8123 https://www.google.com
#curl -x socks5h://localhost:13657 http://www.google.com/
```
