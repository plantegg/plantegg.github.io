---
title: Linux环境变量问题汇总
date: 2018-03-24 17:30:03
categories: Linux
tags:
    - Linux
    - ssh
    - env
    - Ansible
    - shell
    - no-login
    - bash posix
---

# Linux环境变量问题汇总

### 测试好的脚本放到 crontab 里就报错: 找不到命令

写好一个脚本，测试没有问题，然后放到crontab 想要定时执行，但是总是报错，去看日志的话显示某些命令找不到，这种一般都是因为PATH环境变量变了导致的

自己在shell命令行下测试的时候当前环境变量就是这个用户的环境变量，可以通过命令：env 看到，脚本放到crontab 里面后一般都加了sudo 这个时候 env 变了。比如你可以在命令行下执行 env 和 sudo env 比较一下就发现他们很不一样

sudo有一个参数 -E （--preserver-env）就是为了解决这个问题的。

这个时候再比较一下 

- env
- sudo env
- sudo -E env

大概就能理解这里的区别了。

本文后面的回复中有同学提到了：

> 第一个问题，sudo -E在集团的容器中貌似是不行的，没有特别好的解，我们最后是通过在要执行的脚本中手动source "/etc/profile.d/dockerenv.sh"才行

我也特意去测试了一下官方的Docker容器，也有同样的问题，/etc/profile.d/dockerenv.sh 中的脚本没有生效，然后debug看了看，主要是因为bashrc中的 . 和 source 不同导致的，不能说没有生效，而是加载 /etc/profile.d/dockerenv.sh 是在一个独立的bash 进程中，加载完毕进程结束，所有加载过的变量都完成了生命周期释放了，类似我文章中的export部分提到的。我尝试把 ~/.bashrc 中的 .  /etc/bashrc 改成 source /etc/bashrc , 同时也把 /etc/bashrc 中的 . 改成 source，就可以了，再次进到容器不需要任何操作就能看到所有：/etc/profile.d/dockerenv.sh 中的变量了，所以我们制作镜像的时候考虑改改这里

### docker 容器中admin取不到env参数

docker run的时候带入一堆参数，用root能env中能看到这些参数，admin用户也能看见这些参数，但是通过crond用admin就没法启动应用了，因为读不到这些env。

### 同样一个命令ssh执行不了， 报找不到命令

比如：

ssh user@ip " ip a "  报错： bash: ip: command not found

但是你要是先执行 ssh user@ip 连上服务器后，再执行 ip a 就可以，这里是同一个命令通过两种不同的方式使用，但是环境变量也不一样了。

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

    $ cat .bashrc 
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
![image.png](/images/oss/ae3095f063dede80a8c1ee79ec25685c.png)

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

**找不到ll、cd命令不是因为login/non-login而是因为这两个命令是bash内部定义的，所以sh找不到，通过type -a cd 可以看到一个命令到底是哪里来的**

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
bash shell.sh表示在本shell启动一个子程序（bash），在子程序中执行 shell.sh (shell.sh中产生的一些环境变量就没法带回父shell进程了)， 只需要有读 shell.sh 权限就可以执行
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

如上实例，只有source的时候进程ID和bash进程ID一样，其它方式都创建了一个新的bash进程，所以ID也变了。

bash test.sh 产生一个新的bash，但是这个新的bash中不会加载 .bashrc 需要加载的话必须 bash -l test.sh.

### 通过ssh 执行命令（命令前有sudo）的时候报错：sudo: sorry, you must have a tty to run sudo

这是因为 /etc/sudoers (Linux控制sudo行为、权限的配置文件）中指定了 requiretty（[Redhat、Fedora默认行为](https://www.shell-tips.com/2014/09/08/sudo-sorry-you-must-have-a-tty-to-run-sudo/)），但是 通过ssh远程执行命令是没有tty的（不需要交互）。
解决办法可以试试 ssh -t or -tt (强制分配tty）或者先修改 /etc/sudoers把 requiretty 删掉或者改成 !requiretty

### cp 命令即使使用了 -f force参数，overwrite的时候还是弹出交互信息，必须手工输入Y、yes等

Google搜索一下别人给出的方案是这样 echo yes | cp -rf xxx yyy 算是笨办法，但是没有找到这里为什么-f 不管用。
type -a cp 先确认一下 cp到底是个什么东西：

		#type -a cp
		cp is aliased to `cp -i'
		cp is /usr/bin/cp

这下算是有点清楚了，原来默认cp 都是-i了（-i, --interactive prompt before overwrite (overrides a previous -n option)），看起来就是默认情况下为了保护我们的目录不经意间被修改了。所以真的确认要overwrite的话直接用 /usr/bin/cp -f 就不需要每次yes确认了

### 重定向

sudo docker logs swarm-agent-master >master.log 2>&1 输出重定向http://www.kissyu.org/2016/12/25/shell%E4%B8%AD%3E%20:dev:null%202%20%3E%20&1%E6%98%AF%E4%BB%80%E4%B9%88%E9%AC%BC%EF%BC%9F/

	>/dev/null 2>&1 标准输出丢弃 错误输出丢弃
	2>&1 >/dev/null 标准输出丢弃 错误输出屏幕

http://kodango.com/bash-one-liners-explained-part-three

### umask

创建文件的默认权限是 666 文件夹是777 但是都要跟 umask做运算（按位减法） 一般umask是002 
所以创建出来文件最终是664，文件夹是775，如果umask 是027的话最终文件是 640 文件夹是750
『尽量不要以数字相加减啦！』你应该要这样想(-rw-rw- rw-) – (——–wx)=-rw-rw-r–这样就对啦！不要用十进制的数字喔！够能力的话，用二进制来算，不晓得的话，用 rwx 来算喔！

### 其它

	echo $-   // himBH 

“$-” 中含有“i”代表“交互式shell”
“$0”的显示结果为“-bash”，bash前面多个“-”，代表“登录shell”.
没有“i“和“-”的，是“非交互式的非登录shell”

set +o histexpand （！ 是history展开符号， histexpand 可以打开或者关闭这个展开符）
alias 之后，想要用原来的命令：\+alias  （命令前加\)


bash程序执行，当“$0”是“sh”的时候，则要求下面的代码遵循一定的规范，当不符合规范的语法存在时，则会报错，所以可以这样理解，“sh”并不是一个程序，而是一种标准（POSIX），这种标准，在一定程度上（具体区别见下面的“Things bash has that sh does not”）保证了脚本的跨系统性（跨UNIX系统）

Linux 分 shell变量(set)，用户变量(env)， shell变量包含用户变量，export是一种命令工具，是显式那些通过export命令把shell变量中包含的用户变量导入给用户变量的那些变量.

set -euxo pipefail //-u unset -e 异常退出  http://www.ruanyifeng.com/blog/2017/11/bash-set.html

### 引号

shell 中：单引号的处理是比较简单的，被单引号包括的所有字符都保留原有的意思，例如'$a'不会被展开, '`cmd`'也不会执行命令；而双引号，则相对比较松，在双引号中，以下几个字符 $, \`, \ 依然有其特殊的含义，比如$可以用于变量展开, 反引号\`可以执行命令，反斜杠\可以用于转义。但是，在双引号包围的字符串里，反斜杠的转义也是有限的，它只能转义$, `, ", \或者newline（回车）这几个字符，后面如果跟着的不是这几个字符，只不会被黑底，反斜杠会被保留  http://kodango.com/simple-bash-programming-skills-2

### su 和 su - 的区别

su命令和su -命令最大的本质区别就是：前者只是切换了root身份，但Shell环境仍然是普通用户的Shell；而后者连用户和Shell环境一起切换成root身份了。只有切换了Shell环境才不会出现PATH环境变量错误。su切换成root用户以后，pwd一下，发现工作目录仍然是普通用户的工作目录；而用su -命令切换以后，工作目录变成root的工作目录了。用echo $PATH命令看一下su和su -以后的环境变量有何不同。以此类推，要从当前用户切换到其它用户也一样，应该使用su -命令。

比如： 
   su admin 会重新加载 ~/.bashrc ，但是不会切换到admin 的home目录。
   但是 su - admin 不会重新加载 ~/.bashrc ，但是会切换admin的home目录。


The su command is used to become another user during a login session. Invoked without a username, su defaults to becoming the superuser. The optional argument - may be used to provide an environment similar to what the user would expect had the user logged in directly.

### 后台任务执行

将任务放到后台，断开ssh后还能运行：
"ctrl-Z"将当前任务挂起（实际是发送 SIGTSTP 信号），父进程ssh退出时会给所有子进程发送 SIGHUP；
"disown -h"让该任务忽略SIGHUP信号（不会因为掉线而终止执行）；
"bg"让该任务在后台恢复运行。

## shell 调试与参数

为了方便 Debug，有时在启动 Bash 的时候，可以加上启动参数。

- `-n`：不运行脚本，只检查是否有语法错误。
- `-v`：输出每一行语句运行结果前，会先输出该行语句。
- `-x`：每一个命令处理完以后，先输出该命令，再进行下一个命令的处理。

```
$ bash -n scriptname
$ bash -v scriptname
$ bash -x scriptname
```

## shell 数值运算

bash中数值运算要这样 $(( $a+$b )) // declare -i 才是定义一个整型变量

- 在中括号 [] 内的每个组件都需要有空白键来分隔；
- 在中括号内的变量，最好都以双引号括号起来；
- 在中括号内的常数，最好都以单或双引号括号起来。

在bash中为变量赋值的语法是`foo=bar`，访问变量中存储的数值，其语法为 `$foo`。 需要注意的是，`foo = bar` （使用空格隔开）是不能正确工作的，因为解释器会调用程序`foo` 并将 `=` 和 `bar`作为参数。 总的来说，在shell脚本中使用空格会起到分割参数的作用，有时候可能会造成混淆，请务必多加检查。

## 其它

在bash中进行比较时，尽量使用双方括号 `[[ ]]` 而不是单方括号 `[ ]`，[这样会降低犯错的几率](http://mywiki.wooledge.org/BashFAQ/031)，尽管这样并不能兼容 `sh`



[tldr 可以用来查询命令的常用语法](https://tldr.sh/)，比man简短些，偏case型

## 参考文章：

[关于ansible远程执行的环境变量问题](https://blog.csdn.net/u010871982/article/details/78525367)

[Bash和Sh的区别](http://bbs.chinaunix.net/thread-1068678-1-1.html)

[什么是交互式登录 Shell what-is-interactive-and-login-shell](http://kodango.com/what-is-interactive-and-login-shell)

[Shell 默认选项 himBH 的解释](http://kodango.com/explain-shell-default-options)

[useful-documents-about-shell](http://kodango.com/useful-documents-about-shell)

[linux cp实现强制覆盖](http://coolnull.com/4432.html)

https://wangdoc.com/bash/startup.html

[编写一个最小的 64 位 Hello World](https://cjting.me/2020/12/10/tiny-x64-helloworld/)

[计算机教育中缺失的一课](https://missing-semester-cn.github.io/)
