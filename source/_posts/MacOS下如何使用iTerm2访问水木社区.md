---
title: MacOS下如何使用iTerm2访问水木社区
date: 2021-03-05 17:30:03
categories:
    - Linux

tags:
    - SSH
    - MacOS
---

# MacOS下如何使用iTerm2访问水木社区



关键字： MacOS、iTerm 、Dracula、ssh、bbs.newsmth.net



windows下有各种Term软件来帮助我们通过ssh访问bbs.newsmth.net, 但是工作环境切换到MacOS后发现FTerm、CTerm这样的工具都没有对应的了。但是term下访问 bbs.newsmth.net 简直是太爽了，所以本文希望解决这个问题。



## 问题

ssh 访问 bbs.newsmth.net 是没问题的，但是**要解决配色和字符编码问题**

### 解决编码

在iTerm2的配置中增加一个profile，如下图 smth，主要是改字符编码集为 GB 18030，然后修改配色方案，我喜欢的Dracula不适合SMTH，十大完全看不了。

![image.png](/images/oss/c86ee5401de32e6692d3d65ccfe0041a.png)

然后增加一个profile切换脚本：

```
cat ~/src/script/encode.sh
#!/bin/bash
# 使用GBK Profile
echo -e "\033]50;SetProfile=smth\a"
# 更改当前 iTerm2 tab title
echo -ne "\033]0;"$@"\007"
$@
echo -ne "\033]0;"${PWD/#$HOME/~}"\007"
echo -e "\033]50;SetProfile=Default\a"
```

Encode.sh用来解决profile切换，连smth前切换成GB 18030，断开的时候恢复成UTF-8，要不然的话正常工作的命令行就乱码了。



这行命令保存为可执行文件smth, 用于通过 ssh连上 bbs.newsmth.net 

> /Users/ren/src/script/encode.sh sshpass -p'密码' ssh -o ServerAliveInterval=60 水木id@bbs.newsmth.net



最终执行命令如下：

```
cat /usr/local/bin/smth
/Users/ren/src/script/encode.sh sshpass -p'密码' ssh -o ServerAliveInterval=60 水木id@bbs.newsmth.net
```



### 解决配色问题

然后还是在profile里面把smth的配色方案改成：Tango Dark, 一切简直是完美，工作灌水两不误，别人还发现不了



## 最终效果

目录（右边是工作窗口）：

![image.png](/images/oss/0265ed7a728bfdd6be940d838fc1feaf.png)



十大，这个十大颜色和右边工作模式的配色方案不一样

![image.png](/images/oss/252b9295375f6e6078278a6e64e1d68c.png)



断开后恢复成 Dracula 配色和UTF-8编码，不影响工作，别的工作tab也还是正常使用utf8

![image.png](/images/oss/cf8912c0634182b44fa92eeb9f854362.png)



别的term网站也是类似，比如小百合、byr、ptt等