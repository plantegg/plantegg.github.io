---
title: 就是要你懂Linux环境变量 问题汇总
date: 2018-03-24 17:30:03
categories: Linux
tags:
    - Linux
    - ssh
    - env
    - ansible
    - shell
    - no-login
    - bash posix
---

# 就是要你懂Linux环境变量问题汇总


### 测试好的脚本放到 crontab 里就报错: 找不到命令

写好一个脚本，测试没有问题，然后放到crontab 想要定时执行，但是总是报错，去看日志的话显示某些命令找不到，这种一般都是因为PATH环境变量变了导致的

自己在shell命令行下测试的时候当前环境变量就是这个用户的环境变量，可以通过命令：env 看到，脚本放到crontab 里面后一般都加了sudo 这个时候 env 变了。比如你可以在命令行下执行 env 和 sudo env 比较一下就发现他们很不一样

为了解决这个问题 sudo有一个参数 -E （--preserver-env）就是为了解决这个问题的。

这个时候再比较一下 

- env
- sudo env
- sudo -E env

大概就能理解这里的区别了

### 同样一个命令ssh执行不了， 报找不到命令

比如：

ssh user@ip " ip a "  报错： bash: ip: command not found

但是你要是先执行 ssh user@ip 连上服务器后，再执行 ip a 就可以，这里是同一个命令通过两种不同的方式但是环境变量也不一样了。

同样想要解决这个问题的话可以先 ssh 连上服务器，再执行 which ip ; env | grep PATH  

    $ which ip
    /usr/sbin/ip
    $ env | grep PATH
    PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin

很明显这里因为 ip在/usr/sbin下，而/usr/sbin又在PATH变量中，所以可以找到。

那么接下来我们看看 

    $ssh user@ip "env | grep PATH"
    PATH=/usr/local/bin:/usr/bin

很明显这里的PATH比上面的PATH短了一截，/usr/sbin也没有在里面，所以/usr/sbin 下的ip命令自然也找不到了，这里虽然都是同一个用户，但是他们的环境变量还不一样，有点出乎我的意料之外。

主要原因是我们的shell 分为login shell 和 no-login shell , 先ssh 登陆上去再执行命令就是一个login shell，Linux要为这个终端分配资源。

而下面的直接在ssh 里面放执行命令实际上就不需要login，所以这是一个no-login shell.

#### login shell 和 no-login shell又有什么区别呢？


* login shell加载环境变量的顺序是：① /etc/profile ② ~/.bash_profile ③ ~/.bashrc ④ /etc/bashrc 
* 而non-login shell加载环境变量的顺序是： ① ~/.bashrc ② /etc/bashrc


也就是nog-login少了前面两步，我们先看后面两步。

下面是一个 .bashrc 的内容：

    [ ~]$ cat .bashrc 
    # .bashrc
    
    # Source global definitions
    if [ -f /etc/bashrc ]; then
    	. /etc/bashrc
    fi

基本没有什么内容，它主要是去加载 /etc/bashrc  而他里面也没有看到sbin相关的东西

那我们再看non-login少的两步： ① /etc/profile ② ~/.bash_profile 

cat /etc/profile :
    
    if [ "$EUID" = "0" ]; then
	    pathmunge /usr/sbin
	    pathmunge /usr/local/sbin
    else
	    pathmunge /usr/local/sbin after
	    pathmunge /usr/sbin after
    fi

这几行代码就是把 /usr/sbin 添加到 PATH 变量中，正是他们的区别决定了这里的环境变量不一样。

**用一张图来表述他们的结构，箭头代表加载顺序，红框代表不同的shell的初始入口**：
![image.png](http://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/ae3095f063dede80a8c1ee79ec25685c.png)

像 ansible 这种自动化工具，或者我们自己写的自动化脚本，底层通过ssh这种non-login的方式来执行的话，那么都有可能碰到这个问题，如何修复呢？

在 /etc/profile.d/ 下创建一个文件：/etc/profile.d/my_bashenv.sh 内容如下：
    
    $cat /etc/profile.d/my_bashenv.sh 
    
    pathmunge () {
    if ! echo $PATH | /bin/egrep -q "(^|:)$1($|:)" ; then
       if [ "$2" = "after" ] ; then
      PATH=$PATH:$1
       else
      PATH=$1:$PATH
       fi
    fi
    }
     
    pathmunge /sbin
    pathmunge /usr/sbin
    pathmunge /usr/local/sbin
    pathmunge /usr/local/bin
    pathmunge /usr/X11R6/bin after
     
    unset pathmunge
    
    complete -cf sudo
     
    
    alias chgrp='chgrp --preserve-root'
    alias chown='chown --preserve-root'
    alias chmod='chmod --preserve-root'
    alias rm='rm -i --preserve-root'
     
    
    HISTTIMEFORMAT='[%F %T] '
    HISTSIZE=1000
    
    export EDITOR=vim
    
    
    export PS1='\n\e[1;37m[\e[m\e[1;32m\u\e[m\e[1;33m@\e[m\e[1;35m\H\e[m \e[4m`pwd`\e[m\e[1;37m]\e[m\e[1;36m\e[m\n\$'
    
   
通过前面我们可以看到 /etc/bashrc 总是会去加载 /etc/profile.d/ 下的所有 *.sh 文件，同时我们还可以在这个文件中修改我们喜欢的 shell 配色方案和环境变量等等 

### BASH 

1、交互式的登录shell （bash –il xxx.sh）
载入的信息：
/etc/profile
~/.bash_profile（ ->  ~/.bashrc  ->  /etc/bashrc）
~/.bash_login
~/.profile

2、非交互式的登录shell （bash –l xxx.sh）
载入的信息：
/etc/profile
~/.bash_profile （ ->  ~/.bashrc  ->  /etc/bashrc）
~/.bash_login
~/.profile
$BASH_ENV

3、交互式的非登录shell （bash –i xxx.sh）
载入的信息：
~/.bashrc （ ->  /etc/bashrc）

4、非交互式的非登录shell （bash xxx.sh）
载入的信息：
$BASH_ENV

### SH

1、交互式的登录shell
载入的信息：
/etc/profile
~/.profile

2、非交互式的登录shell
载入的信息：
/etc/profile
~/.profile

3、交互式的非登录shell
载入的信息：
$ENV

#### 练习验证一下bash、sh和login、non-login

- sudo ll 或者 sudo cd 是不是都报找不到命令
- 先sudo bash 然后执行 ll或者cd就可以了
- 先sudo sh   然后执行 ll或者cd还是报找不到命令
- sudo env | grep PATH 然后 sudo bash 后再执行 env | grep PATH 看到的PATH环境变量不一样了


4、非交互式的非登录shell
载入的信息：
nothing

### export命令的作用 

Linux 中export是一种命令工具通过export命令把shell变量中包含的用户变量导入给子程序.**默认情况下子程序仅会继承父程序的环境变量**，子程序不会继承父程序的自定义变量，所以需要export让父程序中的**自定义变量**变成环境变量，然后子程序就能继承过来了。

我们来看一个例子， 有一个变量，名字 abc 内容123 如果没有export ，那么通过bash创建一个新的shell（新shell是之前bash的子程序），在新的shell里面就没有abc这个变量， export之后在新的 shell 里面才可以看到这个变量，但是退出重新login后（产生了一个新的bash，只会加载env）abc变量都不在了


    $echo $abc
    
    
    $abc="123"
    
    
    $echo $abc
    123
    
    $bash
    
    $echo $abc
    
    
    $exit
    exit
    
    $export abc
    
    $echo $abc
    123
    
    $bash
    
    $echo $abc
    123

## 一些常见问题

###  执行好好地shell 脚本换台服务器就：source: not found

source 是bash的一个内建命令（所以你找不到一个/bin/source 这样的可执行文件），也就是他是bash自带的，如果我们执行脚本是这样： sh shell.sh 而shell.sh中用到了source命令的话就会报 source: not found

这是因为bash 和 sh是两个东西，sh是 POSIX shell，你可以把它看成是一个兼容某个规范的shell，而bash是 Bourne-Again shell script， bash是 POSIX shell的扩展，就是bash支持所有符合POSIX shell的规范，但是反过来就不一定了，而这里的 source 恰好就是 bash内建的，不符合 POSIX shell的规范（**POSIX shell 中用 . 来代替source**)

### 在centos执行好好的脚本放到Ubuntu上就不行了，报语法错误

同上，如果到ubuntu上用 bash shell.sh是可以的，但是sh shell.sh就报语法错误，但是在centos上执行：sh或者bash shell.sh 都可以通过。 在centos上执行 ls -lh /usr/bin/sh 可以看到 /usr/bin/sh link到了 /usr/bin/bash 也就是sh等同于bash，所以都可以通过不足为奇。 

但是在ubuntu上执行 ls -lh /usr/bin/sh 可以看到 /usr/bin/sh link到了 **/usr/bin/dash** ， 这就是为什么ubuntu上会报错

### source shell.sh 和 bash shell.sh以及 ./shell.sh的区别

source shell.sh就在本shell中展开执行
bash shell.sh表示在本shell启动一个子程序（bash），在子程序中执行 shell.sh (shell.sh中产生的一些环境变量就没法带回父shell进程了)， 有读 shell.sh 权限就可以执行
./shell.sh 跟bash shell.sh类似，但是必须要求shell.sh有rx权限，然后根据shell.sh前面的 #! 后面的指示来确定用bash还是sh 

    $cat test.sh 
    echo $$
    
    $echo $$
    2299
    
    $source test.sh 
    2299
    
    $bash test.sh 
    4037
    
    $./test.sh 
    4040

如上实例，只有source的时候进程ID和bash进程ID一样，其它方式都创建了一个新的bash进程，所以ID也变了



### 参考文章：

[关于ansible远程执行的环境变量问题](https://blog.csdn.net/u010871982/article/details/78525367)

[Bash和Sh的区别](http://bbs.chinaunix.net/thread-1068678-1-1.html)

[什么是交互式登录 Shell what-is-interactive-and-login-shell](http://kodango.com/what-is-interactive-and-login-shell)

[Shell 默认选项 himBH 的解释](http://kodango.com/explain-shell-default-options)

[useful-documents-about-shell](http://kodango.com/useful-documents-about-shell)
