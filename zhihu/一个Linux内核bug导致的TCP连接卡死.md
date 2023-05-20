
# 一个Linux 内核 bug 导致的 TCP连接卡死

## 问题描述

客户端从 server 拖数据，偶尔会出现 tcp 连接卡死，卡死的现象就是 server 不遵循 tcp 重传逻辑，客户端不停地发 dup ack，但是服务端不响应这些dup ack仍然发新的包，直至服务端不再发任何新包，最终连接闲置过久被reset，客户端抛连接异常

## 分析

服务端抓包可以看到：这个 TCP 流， 17:40:40 后 3306 端口不做任何响应，进入卡死状态，在卡死前有一些重传

![image.png](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/一个Linux内核bug导致的TCP连接卡死/e3cec3e38f3b316e-1662602586968-b20b6006-884e-4c33-9938-0277c012579e.png)

同时通过观察这些连接的实时状态：

![image-20220922092105581](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/一个Linux内核bug导致的TCP连接卡死/a9311d38781d5c9a-image-20220922092105581.png)

rto一直在增加，但是这个时候 server 上抓包到任何包，说明内核在做 rto 重传，但是重传包没有到达本机网卡，应该还是被内核其它环节吃掉了。

再观察 netstat -s 状态，重传的时候，TCPWqueueTooBig 值会增加，也就是重传->TCPWqueueTooBig->重传包未发出->循环->相当于 TCP 连接卡死、静默状态

![image-20220922092321039](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/一个Linux内核bug导致的TCP连接卡死/8584ff37fa4338b5-image-20220922092321039.png)

顺着 TCPWqueueTooBig 查看[内核代码提交记录](https://github.com/torvalds/linux/commit/f070ef2ac66716357066b683fb0baf55f8191a2e)， 红色部分是修 CVE-2019-11478 添加的代码，引入了这个 卡死 的bug，绿色部分增加了更严格的条件又修复了卡死的 bug

![image.png](https://cdn.jsdelivr.net/gh/shareImage/image@_md2zhihu_blog_cee8f3b4/一个Linux内核bug导致的TCP连接卡死/a9bf0dc4e3c796f9-1662698955965-276e9936-6ca4-4269-9fbd-ae05176bf1a6.png)

## 原因

2019-05 为了解决 [CVE-2019-11478](https://www.secrss.com/articles/11570) 增加了这个commit：[f070ef2ac66716357066b683fb0baf55f8191a2e](https://github.com/torvalds/linux/commit/f070ef2ac66716357066b683fb0baf55f8191a2e)，这部分代码在发送 buffer 满的时候忽略要发的包，进入静默

为了解决这个问题 2019-07-20 fix 版本：https://github.com/torvalds/linux/commit/b617158dc096709d8600c53b6052144d12b89fab

4.19.57 是 2019-07-03 发布，完美引入了这个 bug

快速确认：netstat -s | grep TCPWqueueTooBig  如果不为0 就出现过 TCP 卡死，同时还可以看到 tb(待发送队列) 大于 rb（发送队列 buffer）

## 重现条件

必要条件：合并了 commit：[f070ef2ac66716357066b683fb0baf55f8191a2e](https://github.com/torvalds/linux/commit/f070ef2ac66716357066b683fb0baf55f8191a2e) 的内核版本

提高重现概率的其它非必要条件：

1.  数据量大---拖数据任务、大查询；
1.  有丢包---mapping等连接链路偏长，丢包概率大；
1.  多个任务 ---一个失败整个任务失败，客户体感强烈
1.  Server 设置了小buffer，出现概率更高

在这四种情况下出现概率更高。用户单个小查询SQL 睬中这个bug后一般可能就是个连接异常，重试就过去了，所以可能没有抱怨。 得这四个条件一起用户的抱怨就会凸显出来。

## 解决

升级内核到带有2019-07-20 fix 版本：https://github.com/torvalds/linux/commit/b617158dc096709d8600c53b6052144d12b89fab



Reference:

