---
title: wireshark-dup-ack-issue and keepalive
date: 2017-06-02 17:30:03
tags:
---

# wireshark-dup-ack-issue and keepalive

## 问题：
在wireshark中看到一个tcp会话中的两台机器突然一直互相发dup ack包，但是没有触发重传。每次重复ack都是间隔精确的20秒

## 如下截图：

![](http://i.imgur.com/bm3W68Q.png)


client都一直在回复收到2号包（ack=2）了，可是server跟傻了一样居然还发seq=1的包（按理，应该发比2大的包啊）

## 系统配置：

    net.ipv4.tcp_keepalive_time = 20
    net.ipv4.tcp_keepalive_probes = 5
    net.ipv4.tcp_keepalive_intvl = 3

## 原因：
抓包不全的话wireshark有缺陷，把keepalive包识别成了dup ack包，看内容这种dup ack和keepalive似乎是一样的，flags都是0x010。keep alive的定义的是后退一格(seq少1）。

2、4、6、8……号包，都有一个“tcp acked unseen segment”。这个一般表示它ack的这个包，没有被抓到。Wirshark如何作出此判断呢？前面一个包是seq=1, len=0，所以正常情况下是ack = seq + len = 1，然而Wireshark看到的确是ack = 2, 它只能判断有一个seq =1, len = 1的包没有抓到。
dup ack也是类似道理，这些包完全符合dup ack的定义，因为“ack = ” 某个数连续多次出现了。

这一切都是因为keep alive的特殊性导致的。打开66号包的tcp层（见后面的截图），可以看到它的 next sequence number = 12583，表示正常情况下server发出的下一个包应该是seq = 12583。可是在下一个包，也就是68号包中，却是seq = 12582。keep alive的定义的确是这样，即后退一格。
Wireshark只有在抓到数据包（66号包）和keep alive包的情况下才有可能正确识别，前面的抓包中恰好在keep alive之前丢失了数据包，所以Wireshark就蒙了。

## 构造重现
如果用“frame.number >= 68” 过滤这个包，然后File-->export specified packets保存成一个新文件，再打开那个新文件，就会发现Wireshark又蒙了。本来能够正常识别的keep alive包又被错看成dup ack了，所以一旦碰到这种情况不要慌要稳

下面是知识点啦

## 正常的keep-alive Case：
![](http://i.imgur.com/DsTWFZr.png)

keep-alive 通过发一个比实际seq小1的包，比如server都已经 ack 12583了，client故意发一个seq 12582来标识这是一个keep-Alive包

## Duplication ack是指：
server收到了3和8号包，但是没有收到中间的4/5/6/7，那么server就会ack 3，如果client还是继续发8/9号包，那么server会继续发dup ack 3#1 ; dup ack 3#2 来向客户端说明只收到了3号包，不要着急发后面的大包，把4/5/6/7给我发过来
