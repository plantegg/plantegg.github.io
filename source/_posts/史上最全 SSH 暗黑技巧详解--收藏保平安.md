---
title: 史上最全 SSH 暗黑技巧详解--收藏保平安
date: 2019-06-02 17:30:03
categories: SSH
tags:
    - SSH
    - password
    - forward
    - Linux
---

# 史上最全 SSH 暗黑技巧详解--收藏保平安

我见过太多的老鸟、新手对ssh 基本只限于 ssh到远程机器，实际这个命令我们一天要用很多次，但是对它的了解太少了，他的强大远远超出你的想象。当于你也许会说够用就够了，确实没错，但是你考虑过效率没有，或者还有哪些脑洞大开的功能会让你爱死他，这些功能又仅仅是一行命令就够了。

来，让我们一起走一遍，看看会不会让你大开眼界

## 本文试图解决的问题：

- 如何通过ssh命令科学上网
- docker 镜像、golang仓库总是被墙怎么办
- 公司跳板机要输入动态token，太麻烦了，如何省略掉这个token；
- 比如多机房总是要走跳板机，如何绕过跳板机直连； 
- 我的开发测试机器如何免打通、免密码、直达；
- 如何访问隔离环境中的Web服务 -- 将隔离环境中的web端口映射到本地
- 如何让隔离环境的机器用上yum、apt
- 如何将服务器的图形界面映射到本地(类似vnc的作用)
- ssh如何调试诊断，这才是终极技能……

## 注意事项

- ssh是指的openSSH 命令工具
- 本文仅适用于各种Linux、MacOS，Windows的话各种可视化工具都可以复制session、配置tunnel来实现类似功能。
- 如果文章中提到的文件、文件夹不存在可以直接创建出来。
- 所有配置都是在你的笔记本上（相当于ssh client上，只有日常跳板机免登如要在日常跳板机上配置一下）

## 科学上网

有时候风声比较紧的话公司的网络加速会关闭，这个时候科学上网还得靠自己，一行ssh命令来科学上网:

```
nohup ssh -qTfnN -D 127.0.0.1:38080 root@1.1.1.1 "vmstat 10" 2>&1 >/dev/null &
```

上面的 1.1.1.1 是你在境外的一台服务器，已经做好了免密登陆（免密见后面，要不你每次还得输一下密码），这句话的意思就是在本地启动一个38080的端口，上面收到的任何东西都会转发给 1.1.1.1:22（做了ssh加密），1.1.1.1:22 会解密收到的东西，然后把他们转发给google之类的网站（比如你要访问的是google），结果依然通过原路返回

127.0.0.1:38080  socks5 就是要填入到你的浏览器中的代理服务器，什么都不需要装，非常简单

![image.png](http://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/e4a2fdad5b04542dc657b96e195a2b45.png)



原理图如下(灰色矩形框就是你本地ssh命令，ssh 线就是在穿墙， 国外服务器就是命令中的1.1.1.1)：
![undefined](https://intranetproxy.alipay.com/skylark/lark/0/2019/png/33359/1561367815573-0b793473-67fa-4edc-ae58-04e7c4c51b87.png) 

### 科学上网之http特殊代理

前面所说的代理是socks5代理，一般浏览器都有插件支持，但是比如你的docker（或者其他程序）需要通过http去拉取镜像就会出现如下错误：


    Sending build context to Docker daemon 8.704 kB
    Step 1 : FROM k8s.gcr.io/kube-cross:v1.10.1-1
    Get https://k8s.gcr.io/v1/_ping: dial tcp 108.177.125.82:443: i/o timeout

[如果是git这样的应用内部可以配置socks5和http代理服务器，请参考另外一篇文章](https://www.atatech.org/articles/102153)，但是有些应用就不能配置了，当然最终通过ssh大法还是可以解决这个问题：

    sudo ssh -L 443:108.177.125.82:443 root@1.1.1.1 //在本地监听443，转发给远程108.177.125.82的443端口

然后再在 /etc/hosts 中将域名 k8s.gcr.io 指向 127.0.0.1， 那么本来要访问 k8s.gcr.io:443的，变成了访问本地 127.0.0.1:443 而 127.0.0.1:443 又通过ssh重定向到了 108.177.125.82:443 这样就实现了http代理或者说这种特殊情况下的科学上网。

当然网上也有socks5代理转http代理的，很麻烦，我没有实验成功，上面这个方案不需要装任何东西，但是每个访问目标都要这样处理，好在这种情况不多

## 内部堡垒机、跳板机都需要密码+动态码，太复杂了，怎么解？


    ren@ren-VirtualBox:~$ cat ~/.ssh/config 
    #reuse the same connection --关键配置
    ControlMaster auto
    ControlPath ~/tmp/ssh_mux_%h_%p_%r
    
    #查了下ControlPersist是在OpenSSH5.6加入的，5.3还不支持
    #不支持的话直接把这行删了，不影响功能
    #keep one connection in 72hour
    #ControlPersist 72h
    #复用连接的配置到这里，后面的配置与复用无关
    
    #其它也很有用的配置
    GSSAPIAuthentication=no
    StrictHostKeyChecking=no
    TCPKeepAlive=yes
    CheckHostIP=no
    # "ServerAliveInterval [seconds]" configuration in the SSH configuration so that your ssh client sends a "dummy packet" on a regular interval so that the router thinks that the connection is active even if it's particularly quiet
    ServerAliveInterval=15
    #ServerAliveCountMax=6
    ForwardAgent=yes
    
    UserKnownHostsFile /dev/null

在你的ssh配置文件增加上述参数，意味着72小时内登录同一台跳板机只有第一次需要输入密码，以后都是重用之前的连接，所以也就不再需要输入密码了。

加了如上参数后的登录过程就有这样的东东(默认没有，这是debug信息)：   

```
    debug1: setting up multiplex master socket
    debug3: muxserver_listen: temporary control path   /home/ren/tmp/ssh_mux_10.16.*.*_22_corp.86g3C34vy36tvCtn
    debug2: fd 3 setting O_NONBLOCK
    debug3: fd 3 is O_NONBLOCK
    debug3: fd 3 is O_NONBLOCK
    debug1: channel 0: new [/home/ren/tmp/ssh_mux_10.16.*.*_22_corp]
    debug3: muxserver_listen: mux listener channel 0 fd 3
    debug1: control_persist_detach: backgrounding master process
    debug2: control_persist_detach: background process is 15154
    debug2: fd 3 setting O_NONBLOCK
    debug1: forking to background
    debug1: Entering interactive session.
    debug2: set_control_persist_exit_time: schedule exit in 259200 seconds
    debug1: multiplexing control connection
```

 /home/ren/tmp/ssh_mux_10.16.*.*_22_corp 这个就是保存好的socket，下次可以重用，免密码。 in 259200 seconds 对应 72小时

看动画过程，注意过程中都是通过 -vvv 来看到ssh的debug信息
![ssh-demo.gif](http://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/43c4e0b4ad0f6aa5cb76a7008e53e4cd.gif)

## 我有很多不同机房（或者说不同客户）的机器都需要跳板机来登录，能一次直接ssh上去吗？

比如有一批客户机房的机器IP都是192.168.*.*, 然后需要走跳板机100.10.1.2才能访问到，那么我希望以后**在笔记本上直接 ssh 192.168.1.5 就能直接连上**

    $ cat /etc/ssh/ssh_config
    
    Host 192.168.*.*
    ProxyCommand ssh -l ali-renxijun 100.10.1.2 exec /usr/bin/nc %h %p

上面配置的意思是执行 ssh 192.168.1.5的时候命中规则 Host 192.168.*.* 所以执行 ProxyCommand 先连上跳板机再通过跳板机连向192.168.1.5 。这样在你的笔记本上就跟192.168.*.* 的机器仿佛在一起，ssh可以上去，但是ping不通这个192.168.1.5的ip

**划重点：公司的线上跳板机做了特殊限制，限制了这个技能。日常环境跳板机支持这个功能**

比如我的跳板配置：


    #到美国的机器用美国的跳板机速度更快
    Host 10.74.*
    ProxyCommand ssh -l user us.jump exec /bin/nc %h %p 2>/dev/null
    #到中国的机器用中国的跳板机速度更快
    Host 10.70.*
    ProxyCommand ssh -l user cn.jump exec /bin/nc %h %p 2>/dev/null
       
    Host 192.168.0.*
    ProxyCommand ssh -l user 1.1.1.1 exec /usr/bin/nc %h %p

其实我的配置文件里面还有很多规则，懒得一个个隐藏IP了，这些规则是可以重复匹配的

来看一个例子    
    ren@ren-VirtualBox:/$ ping -c 1 10.16.1.*
        PING 10.16.1.* (10.16.1.*) 56(84) bytes of data.^C
    --- 10.16.1.* ping statistics ---
    1 packets transmitted, 0 received, 100% packet loss, time 0ms
    
    ren@ren-VirtualBox:~$ ssh -l corp 10.16.1.* -vvv
    OpenSSH_6.7p1 Ubuntu-5ubuntu1, OpenSSL 1.0.1f 6 Jan 2014
    debug1: Reading configuration data /home/ren/.ssh/config
    debug1: Reading configuration data /etc/ssh/ssh_config
    debug1: /etc/ssh/ssh_config line 28: Applying options for *
    debug1: /etc/ssh/ssh_config line 44: Applying options for 10.16.*.*
    debug1: /etc/ssh/ssh_config line 68: Applying options for *
    debug1: auto-mux: Trying existing master
    debug1: Control socket "/home/ren/tmp/ssh_mux_10.16.1.*_22_corp" does not exist
    debug1: Executing proxy command: exec ssh -l corp 139.*.*.* exec /usr/bin/nc 10.16.1.* 22

本来我的笔记本跟 10.16.1.* 是不通的(ping 不通），但是ssh可以直接连上，实际ssh登录过程中自动走跳板机139.*.*.* 就连上了

-vvv 参数是debug，把ssh登录过程的日志全部打印出来。 

## ssh 免打通、免登陆跳板机、免密码直接访问日常环境机器

先来看效果图：
![ssh_docker.gif](http://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/0d6bc0800b3dc8b8988f6cb7ab410010.gif)

### 实现过程：

1. 先ssh到线上跳板机：login1.cm10.****
2. 复制 ~/.ssh/id_dsa.pub 和 ~/.ssh/id_dsa到你的笔记本的~/.ssh/ 下
3. 复制 ~/.ssh/id_dsa.pub 和 ~/.ssh/id_dsa到日常跳板机（ login1.et2sqa.*** ）的~/.ssh/ 下
4. 日常跳板机上：echo "eval \`keychain --eval id_dsa\`" >>~/.bash_profile
5. 设置这两个文件权限为600
6. 在你笔记本的 /etc/ssh/ssh_config 中增加如下两行配置 

```
Host 11.239.*.*
ProxyCommand ssh -l xijun.rxj login1.et2sqa.**** exec /usr/bin/nc %h %p
```

**第一次需要输入你的域账户密码，只要你的域账户密码不改以后永远不需要再次输入了。另外你需要在kfc上申请过机器的访问权限，kfc帮你打通了免密登陆，不仅仅是Docker，t4也默认打通了账号**
这个技能基本综合了前面所有技巧，综合性比较强，需要点时间配合-vvv慢慢理解消化

![image.png](http://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/b4e460a501c21eac1e4104b9324910d3.png)

## 将隔离环境中的web端口映射到本地

远程机器部署了WEB Server，需要通过浏览器来访问这个WEB服务，但是server在隔离环境中，只能通过ssh访问到。一般来说会在隔离环境中部署一个windows机器，通过这个windows机器来访问到这个web server。

现在我们试着用ssh来实现本地浏览器直接访问到这个隔离环境中的WEB Server。

假设web server是：10.149.1.132:8083， ssh账号是：aliyun


先配置好本地直接 ssh aliyun@10.149.1.132 （参考前面的 ProxyCommand配置过程，最好是免密也配置好），然后在你的笔记本上执行：


	ssh -CNfL 0.0.0.0:8088:10.149.1.132:8083 aliyun@10.149.1.132

或者：(root@100.67.210.73 -p 54900 是可达132的代理服务器)

	ssh -CNfL 0.0.0.0:8089:10.149.1.132:8083 root@100.67.210.73 -p 54900


这表示在本地启动一个8088的端口，将这个8088端口映射到10.149.1.132的8083端口上，用的ssh账号是aliyun

然后在笔记本上的浏览器中输入： 127.0.0.1：8088 就看到了如下界面：

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/1acbd09b4b45dbd478ddabc0e001a15e.png)

反过来，**也可以让隔离环境机器通过代理上网，比如安装yum**

## 为什么有时候ssh 比较慢，比如总是需要30秒钟后才能正常登录

先了解如下知识点，在 ~/.ssh/config 配置文件中：

    GSSAPIAuthentication=no

禁掉 GSSAPI认证，GSSAPIAuthentication是个什么鬼东西请自行 Google(多一次没必要的授权认证过程，然后等待超时)。 这里要理解ssh登录的时候有很多种认证方式（公钥、密码等等），具体怎么调试请记住强大的命令参数 ssh -vvv 上面讲到的技巧都能通过 -vvv 看到具体过程。

比如我第一次碰到ssh 比较慢总是需要30秒后才登录，不能忍受，于是登录的时候加上 -vvv明显看到控制台停在了：GSSAPIAuthentication 然后Google了一下，禁掉就好了

当然还有去掉每次ssh都需要先输入yes

## 批量打通所有机器之间的ssh登录免密码

**Expect在集团是禁止的，我只用于打通我自己通过docker创建的容器**

ssh免密码的原理是将本机的pub key复制到目标机器的 ~/.ssh/authorized_keys 里面。可以手工复制粘贴，也可以 ssh-copy-id 等

如果有100台机器，互相两两打通还是比较费事（大概需要100*99次copy key）。 下面通过 expect 来解决输入密码，然后配合shell脚本来批量解决这个问题。

![](http://i.imgur.com/S9jLW7B.png)

这个脚本需要四个参数：目标IP、用户名、密码、home目录，也就是ssh到一台机器的时候帮我们自动填上yes，和密码，这样就不需要人肉一个个输入了。

再在外面写一个循环对每个IP执行如下操作：

![](http://i.imgur.com/4SZcnvc.png)

if代码部分检查本机~/.ssh/下有没有id_rsa.pub，也就是是否以前生成过密钥对，没生成的话就帮忙生成一次。

for循环部分一次把生成的密钥对和authorized_keys复制到所有机器上，这样所有机器之间都不需要输入密码就能互相登陆了（当然本机也不需要输入密码登录所有机器）

最后一行代码： 

    ssh $user@$n "hostname -i"

验证一下没有输密码是否能成功ssh上去。

**思考一下，为什么这么做就可以打通两两之间的免密码登录，这里没有把所有机器的pub key复制到其他所有机器上去啊**

> 答案：其实这个脚本做了一个取巧投机的事，那就是让所有机器共享一套公钥、私钥。
> 有时候我也会把我的windows笔记本和我专用的某台虚拟机共享一套秘钥，这样任何新申请的机器打通一次账号就可以在两台机器上随便登录。请保护好自己的私钥

如果免密写入 authorized_keys 成功，但是通过ssh pubkey认证的时候还是有可能失败，这是因为pubkey认证要求：

- authorized_keys  文件权限要对
- .ssh 文件夹权限要对
- /home/user 文件夹权限要对 ----这个容易忽视掉

## 留个作业：第一次ssh某台机器的时候总是出来一个警告，需要yes确认才能往下走，怎么干掉他？

> StrictHostKeyChecking=no
> UserKnownHostsFile=/dev/null

如果按照文章操作不work，推荐就近问身边的同学。问我的话请cat 配置文件  然后把ssh -vvv user@ip (user、ip请替换成你的），再截图发给我。**

测试成功的同学也请留言说下什么os、版本，以及openssl版本，我被问崩溃了

----------
**这里只是帮大家入门了解ssh，掌握好这些配置文件和-vvv后有好多好玩的可以去挖掘，同时也请在留言中说出你的黑技能**

## 调试ssh--终极大招，好多问题我都是debug发现的

- 客户端增加参数 -vvv 会把所有流程在控制台显示出来。卡在哪个环节；密码不对还是key不对一看就知道
- server端还可以：/usr/sbin/sshd -ddd -p 2222 在2222端口对sshd进行debug，看输出信息验证为什么pub key不能login等



## ~/.ssh/config 参考配置

```
#GSSAPIAuthentication=no
StrictHostKeyChecking=no
#TCPKeepAlive=yes
CheckHostIP=no
# "ServerAliveInterval [seconds]" configuration in the SSH configuration so that your ssh client sends a "dummy packet" on a regular interval so that the router thinks that the connection is active even if it's particularly quiet
ServerAliveInterval=15
#ServerAliveCountMax=6
ForwardAgent=yes

UserKnownHostsFile /dev/null

#reuse the same connection
ControlMaster auto
ControlPath ~/tmp/ssh_mux_%h_%p_%r

#keep one connection in 72hour
ControlPersist 72h
```



## /etc/ssh/ssh_config 参考配置

```
Host *
Protocol 2
ServerAliveInterval 30
User admin

host 10.10.55.*
ProxyCommand ssh -l admin admin.jump  exec /usr/bin/nc %h %p

# uos is a hostname
Host 10.10.1.13* 192.168.2.133 uos
ProxyCommand ssh -l root -p 54900 1.1.1.1 exec /usr/bin/nc %h %p

#debug for git proxy
Host github.com
#    LogLevel DEBUG3
#    ProxyCommand ssh  -l root gfw.jump exec /usr/bin/nc %h %p
#    ProxyCommand ssh -oProxyCommand='ssh -l admin gfw.jump:22' -l root gfw.jump2 exec /usr/bin/nc %h %p


ForwardAgent yes
ForwardX11 yes
ForwardX11Trusted yes

    SendEnv LANG LC_*
    HashKnownHosts yes
    GSSAPIAuthentication no
    GSSAPIDelegateCredentials no
    Compression yes
```

## 其他知识点

参数的优先级是：命令行配置选项 > ~/.ssh/config > /etc/ssh/ssh_config

在SSH的**身份验证阶段，SSH只支持服务端保留公钥，客户端保留私钥的方式，**所以方式只有两种：客户端生成密钥对，将公钥分发给服务端；服务端生成密钥对，将私钥分发给客户端。只不过出于安全性和便利性，一般都是客户端生成密钥对并分发公钥（阿里云服务器秘钥对--服务器将一对密钥中的公钥放在 authorized_keys, 私钥给client登陆用）

服务器上的 /etc/ssh/ssh_host* 是用来验证服务器身份的秘钥对（对应client的 known_hosts), **在主机验证阶段，服务端持有的是私钥，客户端保存的是来自于服务端的公钥。注意，这和身份验证阶段密钥的持有方是相反的。**

SSH支持多种身份验证机制，**它们的验证顺序如下：gssapi-with-mic,hostbased,publickey,keyboard-interactive,password**，但常见的是密码认证机制(password)和公钥认证机制(public key). 当公钥认证机制未通过时，再进行密码认证机制的验证。这些认证顺序可以通过ssh配置文件(注意，不是sshd的配置文件)中的指令PreferredAuthentications改变。

### ssh-agent

私钥设置了密码以后，每次使用都必须输入密码，有时让人感觉非常麻烦。比如，连续使用`scp`命令远程拷贝文件时，每次都要求输入密码。

`ssh-agent`命令就是为了解决这个问题而设计的，它让用户在整个 Bash 对话（session）之中，只在第一次使用 SSH 命令时输入密码，然后将私钥保存在内存中，后面都不需要再输入私钥的密码了。



第一步，使用下面的命令新建一次命令行对话。

```
$ eval `ssh-agent`
```

上面命令中，`ssh-agent`会先自动在后台运行，并将需要设置的环境变量输出在屏幕上，类似下面这样。

```
$ ssh-agent
SSH_AUTH_SOCK=/tmp/ssh-barrett/ssh-22841-agent; export SSH_AUTH_SOCK;
SSH_AGENT_PID=22842; export SSH_AGENT_PID;
echo Agent pid 22842;
```

`eval`命令的作用，就是运行上面的`ssh-agent`命令的输出，设置环境变量。

第二步，在新建的 Shell 对话里面，使用`ssh-add`命令添加默认的私钥（比如`~/.ssh/id_rsa`，或`~/.ssh/id_dsa`，或`~/.ssh/id_ecdsa`，或`~/.ssh/id_ed25519`）。

```
$ ssh-add
Enter passphrase for /home/you/.ssh/id_dsa: ********
Identity added: /home/you/.ssh/id_dsa (/home/you/.ssh/id_dsa)
```

上面例子中，添加私钥时，会要求输入密码。以后，在这个对话里面再使用密钥时，就不需要输入私钥的密码了，因为私钥已经加载到内存里面了。

如果添加的不是默认私钥，`ssh-add`命令需要显式指定私钥文件。

```
$ ssh-add my-other-key-file
```

上面的命令中，`my-other-key-file`就是用户指定的私钥文件。



### 安装sshd

sshd 有自己的一对或多对密钥。它使用密钥向客户端证明自己的身份。所有密钥都是公钥和私钥成对出现，公钥的文件名一般是私钥文件名加上后缀`.pub`。

DSA 格式的密钥文件默认为`/etc/ssh/ssh_host_dsa_key`（公钥为`ssh_host_dsa_key.pub`），RSA 格式的密钥为`/etc/ssh/ssh_host_rsa_key`（公钥为`ssh_host_rsa_key.pub`）。如果需要支持 SSH 1 协议，则必须有密钥`/etc/ssh/ssh_host_key`。

如果密钥不是默认文件，那么可以通过配置文件`sshd_config`的`HostKey`配置项指定。默认密钥的`HostKey`设置如下。

```
# HostKey for protocol version 1
# HostKey /etc/ssh/ssh_host_key

# HostKeys for protocol version 2
# HostKey /etc/ssh/ssh_host_rsa_key
# HostKey /etc/ssh/ssh_host_dsa_ke
```

注意，如果重装 sshd，`/etc/ssh`下的密钥都会重新生成（这些密钥对用于验证Server的身份），导致客户端重新 ssh 连接服务器时，会跳出警告，拒绝连接。为了避免这种情况，可以在重装 sshd 时，先备份`/etc/ssh`目录，重装后再恢复这个目录。

> 调试：非后台(-D)和debug(-d)模式启动sshd，同时监听2222和3333端口
>
> sshd -D -d -p 2222 -p 3333



### sshd Banner

`Banner`指定用户登录后，sshd 向其展示的信息文件（`Banner /usr/local/etc/warning.txt`），默认不展示任何内容。

### 动态转发 (-D) 

动态转发指的是，本机与 SSH 服务器之间创建了一个加密连接，然后本机内部针对某个端口的通信，都通过这个加密连接转发。它的一个使用场景就是，访问所有外部网站，都通过 SSH 转发。

动态转发需要把本地端口绑定到 SSH 服务器。**至于 SSH 服务器要去访问哪一个网站，完全是动态的，取决于原始通信，所以叫做动态转发**。

目标还不确定，所以叫动态转发

```
$ ssh -D 2121 tunnel-host -N
```

注意，这种转发采用了 SOCKS5 协议。访问外部网站时，需要把 HTTP 请求转成 SOCKS5 协议，才能把本地端口的请求转发出去。`-N`参数表示，这个 SSH 连接不能执行远程命令，只能充当隧道。

下面是 ssh 隧道建立后的一个使用实例。

```
$ curl -x socks5://localhost:2121 http://www.example.com
```

上面命令中，curl 的`-x`参数指定代理服务器，即通过 SOCKS5 协议的本地`2121`端口，访问`http://www.example.com`。

### 本地转发 (-L)

本地转发（local forwarding）指的是，SSH 服务器作为中介的跳板机，建立本地计算机与特定目标网站之间的加密连接。本地转发是在本地计算机的 SSH 客户端建立的转发规则。

它会指定一个本地端口（local-port），所有发向那个端口的请求，都会转发到 SSH 跳板机（tunnel-host），然后 SSH 跳板机作为中介，将收到的请求发到目标服务器（target-host）的目标端口（target-port）。

```
$ ssh -L local-port:target-host:target-port tunnel-host
```

上面命令中，`-L`参数表示本地转发，`local-port`是本地端口，`target-host`是你想要访问的目标服务器，`target-port`是目标服务器的端口，`tunnel-host`是 SSH 跳板机。

举例来说，现在有一台 SSH 跳板机`tunnel-host`，我们想要通过这台机器，在本地`2121`端口与目标网站`www.example.com`的80端口之间建立 SSH 隧道，就可以写成下面这样。

```
$ ssh -L 2121:www.example.com:80 tunnel-host -N
```

然后，访问本机的`2121`端口，就是访问`www.example.com`的80端口。

```
$ curl http://localhost:2121
```

注意，**本地端口转发采用 HTTP 协议，不用转成 SOCKS5 协议**。

另一个例子是加密访问邮件获取协议 POP3。

```
$ ssh -L 1100:mail.example.com:110 mail.example.com
```

上面命令将本机的1100端口，绑定邮件服务器`mail.example.com`的110端口（POP3 协议的默认端口）。端口转发建立以后，POP3 邮件客户端只需要访问本机的1100端口，请求就会通过 SSH 跳板机（这里是`mail.example.com`），自动转发到`mail.example.com`的110端口。

上面这种情况有一个前提条件，就是`mail.example.com`必须运行 SSH 服务器。否则，就必须通过另一台 SSH 服务器中介，执行的命令要改成下面这样。

```
$ ssh -L 1100:mail.example.com:110 other.example.com
```

上面命令中，本机的1100端口还是绑定`mail.example.com`的110端口，但是由于`mail.example.com`没有运行 SSH 服务器，所以必须通过`other.example.com`中介。本机的 POP3 请求通过1100端口，先发给`other.example.com`的22端口（sshd 默认端口），再由后者转给`mail.example.com`，得到数据以后再原路返回。

注意，采用上面的中介方式，只有本机到`other.example.com`的这一段是加密的，`other.example.com`到`mail.example.com`的这一段并不加密。

这个命令最好加上`-N`参数，表示不在 SSH 跳板机执行远程命令，让 SSH 只充当隧道。另外还有一个`-f`参数表示 SSH 连接在后台运行。

如果经常使用本地转发，可以将设置写入 SSH 客户端的用户个人配置文件。

```
Host test.example.com
LocalForward client-IP:client-port server-IP:server-port
```

### 远程转发(-R)

远程端口指的是在远程 SSH 服务器建立的转发规则。

这种场景比较特殊，主要针对内网的情况。本地计算机在外网，SSH 跳板机和目标服务器都在内网，而且本地计算机无法访问内网之中的 SSH 跳板机，但是 SSH 跳板机可以访问本机计算机。

由于本机无法访问内网 SSH 跳板机，就无法从外网发起 SSH 隧道，建立端口转发。必须反过来，从 SSH 跳板机发起隧道，建立端口转发，这时就形成了远程端口转发。

```
$ ssh -R local-port:target-host:target-port -N local
```

上面的命令，首先需要注意，**不是在本机执行的，而是在 SSH 跳板机执行的**，从跳板机去连接本地计算机。`-R`参数表示远程端口转发，`local-port`是本地计算机的端口，`target-host`和`target-port`是目标服务器及其端口，`local`是本地计算机。

显然，远程端口转发要求本地计算机也安装了 SSH 服务器，这样才能接受 SSH 跳板机的远程登录。

比如，跳板机执行下面的命令，绑定本地计算机的`2121`端口，去访问`www.example.com:80`。

```
$ ssh -R 2121:www.example.com:80 local -N
```

执行上面的命令以后，跳板机到本地计算机的隧道已经建立了。然后，就可以从本机访问目标服务器了，即在本机执行下面的命令。

```
$ curl http://localhost:2121
```

执行上面的命令以后，命令就会输出服务器`www.example.com`的80端口返回的内容。

如果经常执行远程端口转发，可以将设置写入 SSH 客户端的用户个人配置文件。

```
Host test.example.com
RemoteForward local-IP:local-port target-ip:target-port
```

## 参考资料：

http://docs.corp-inc.com/pages/editpage.action?pageId=203555361
https://wiki.archlinux.org/index.php/SSH_keys_(%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87)

https://wangdoc.com/ssh/key.html

