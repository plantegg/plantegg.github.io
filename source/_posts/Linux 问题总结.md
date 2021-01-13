---
title: Linux 问题总结
date: 2020-01-02 17:30:03
categories: Linux
tags:
    - Linux
    - crond
    - pam
---

# Linux 问题总结

## 文件权限的坑

crond第一次加载的时候（刚启动）会去检查文件属性，不是644的话以后都不会执行了，即使后面chmod改成了644. 

手工随便修改一下该文件的内容就能触发自动执行了，或者重启crond, 或者 sudo service crond reload， 或者 /etc/cron.d/下有任何修改都会触发crond reload配置(包含 touch )。

总之 crond会每分钟去检查job有没有change，有的话才触发reload，这个change看的时候change time有没有变化，不看权限的变化，仅仅是权限的变化不会触发crond reload。

 crond会每分钟去检查一下job有没有修改，有修改的话会reload，但是这个**修改不包含权限的修改**。可以简单地理解这个修改是指文件的change time。

## 容器中ulimit限制了crond的执行

容器启动的时候默认nofile为65535（可以通过 docker run --ulimit nofile=655360 来设置），如果容器中的 /etc/security/limits.conf 中设置的nofile大于 65535就会报错，因为容器的1号进程就是65535了，比如在容器中用root用户执行sudo ls报错：

```
#sudo ls
sudo: pam_open_session: Permission denied
sudo: policy plugin failed session initialization
```

可以修改容器中的 ulimit 不要超过默认的65535或者修改容器的启动参数来解决。

子进程都会继承父进程的一些环境变量，比如 limits.conf, sudo/su/crond/passwd等都会触发重新加载limits, 

```
grep -rin pam_limit /etc/pam.d //可以看到触发重新加载的场景
```

## debug crond

先停掉 crond service，然后开启debug参数

```
 systemctl stop crond
 crond -x proc //不想真正执行的话：test
```

或者增加更多的debug信息， debug sudo/sudoers , 在 /etc/sudo.conf 中增加了：

```
Debug sudo /var/log/sudo_debug all@warn
Debug sudoers.so /var/log/sudoers_debug all@debug
```

## systemd limits


/etc/security/limits.conf 的配置，只适用于通过PAM 认证登录用户的资源限制，它对systemd 的service 的资源限制不生效。

因此登录用户的限制，通过/etc/security/limits.conf 与/etc/security/limits.d 下的文件设置即可。

对于systemd service 的资源设置，则需修改全局配置，全局配置文件放在/etc/systemd/system.conf 和/etc/systemd/user.conf，同时也会加载两个对应目录中的所有.conf 文件/etc/systemd/system.conf.d/.conf
和/etc/systemd/user.conf.d/.conf。

### 关于ulimit的一些知识点

参考 [Ulimit](https://feichashao.com/ulimit_demo/) http://blog.yufeng.info/archives/2568

- limit的设定值是 per-process 的
- 在 Linux 中，每个普通进程可以调用 getrlimit() 来查看自己的 limits，也可以调用 setrlimit() 来改变自身的 soft limits
- 要改变 hard limit, 则需要进程有 CAP_SYS_RESOURCE 权限
- 进程 fork() 出来的子进程，会继承父进程的 limits 设定
- `ulimit` 是 shell 的内置命令。在执行`ulimit`命令时，其实是 shell 自身调用 getrlimit()/setrlimit() 来获取/改变自身的 limits. 当我们在 shell 中执行应用程序时，相应的进程就会继承当前 shell 的 limits 设定
- shell 的初始 limits 是谁设定的: 通常是 pam_limits 设定的。顾名思义，pam_limits 是一个 PAM 模块，用户登录后，pam_limits 会给用户的 shell 设定在 limits.conf 定义的值

ulimit, limits.conf 和 pam_limits 的关系，大致是这样的：

1. 用户进行登录，触发 pam_limits;
2. pam_limits 读取 limits.conf，相应地设定用户所获得的 shell 的 limits；
3. 用户在 shell 中，可以通过 ulimit 命令，查看或者修改当前 shell 的 limits;
4. 当用户在 shell 中执行程序时，该程序进程会继承 shell 的 limits 值。于是，limits 在进程中生效了

## deleted 文件

`lsof +L1` 或者` lsof | grep delete` 发现有被删除的文件，且占用大量磁盘空间

## pam 权限报错

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/b646979272e71e015de4a47c62b89747.png)

从debug信息看如果是pam权限报错的话，需要将 required 改成 sufficientS

```
$cat /etc/pam.d/crond 
#
# The PAM configuration file for the cron daemon
#
#
# No PAM authentication called, auth modules not needed
account    required   pam_access.so
account    include    system-auth
session    required   pam_loginuid.so //required 改成 sufficient
session    include    system-auth
auth       include    system-auth

```

PAM 提供四个安全领域的特性，但是应用程序不太可能同时需要所有这些方面。例如，`passwd` 命令只需要下面列表中的第三组：

- `account` 处理账户限制。对于有效的用户，允许他做什么？
- `auth` 处理用户识别 — 例如，通过输入用户名和密码。
- `password` 只处理与密码相关的问题，比如设置新密码。
- `session` 处理连接管理，包括日志记录。

在 /etc/pam.d 目录中为将使用 PAM 的每个应用程序创建一个配置文件，文件名与应用程序名相同。例如，`login` 命令的配置文件是 /etc/pam.d/login。

必须定义将应用哪些模块，创建一个动作 “堆”。PAM 运行堆中的所有模块，根据它们的结果允许或拒绝用户的请求。还必须定义检查是否是必需的。最后，*other* 文件为没有特殊规则的所有应用程序提供默认规则。

- `optional` 模块可以成功，也可以失败；PAM 根据模块是否最终成功返回 `success` 或 `failure`。
- `required` 模块必须成功。如果失败，PAM 返回 `failure`，但是会在运行堆中的其他模块之后返回。
- `requisite` 模块也必须成功。但是，如果失败，PAM 立即返回 `failure`，不再运行其他模块。
- `sufficient` 模块在成功时导致 PAM 立即返回 `success`，不再运行其他模块。

当pam安装之后有两大部分：在/lib64/security目录下的各种pam模块以及/etc/pam.d和/etc/pam.d目录下的针对各种服务和应用已经定义好的pam配置文件。当某一个有认证需求的应用程序需要验证的时候，一般在应用程序中就会定义负责对其认证的PAM配置文件。以vsftpd为例，在它的配置文件/etc/vsftpd/vsftpd.conf中就有这样一行定义：

> pam_service_name=vsftpd

表示登录FTP服务器的时候进行认证是根据/etc/pam.d/vsftpd文件定义的内容进行。

### PAM 认证过程

当程序需要认证的时候已经找到相关的pam配置文件，认证过程是如何进行的？下面我们将通过解读/etc/pam.d/system-auth文件予以说明。

首先要声明一点的是：system-auth是一个非常重要的pam配置文件，主要负责用户登录系统的认证工作。而且该文件不仅仅只是负责用户登录系统认证，其它的程序和服务通过include接口也可以调用到它，从而节省了很多重新自定义配置的工作。所以应该说该文件是系统安全的总开关和核心的pam配置文件。

下面是/etc/pam.d/system-auth文件的全部内容：

```
$cat /etc/pam.d/system-auth
#%PAM-1.0
# This file is auto-generated.
# User changes will be destroyed the next time authconfig is run.
auth        required      pam_env.so
auth        required      pam_faildelay.so delay=2000000
auth        sufficient    pam_unix.so nullok try_first_pass
auth        requisite     pam_succeed_if.so uid >= 1000 quiet_success
auth        required      pam_deny.so

account     required      pam_unix.so
account     sufficient    pam_localuser.so
account     sufficient    pam_succeed_if.so uid < 1000 quiet
account     required      pam_permit.so

password    requisite     pam_pwquality.so try_first_pass local_users_only retry=3 authtok_type=
password    sufficient    pam_unix.so sha512 shadow nullok try_first_pass use_authtok
password    required      pam_deny.so

session     optional      pam_keyinit.so revoke
session     required      pam_limits.so
-session     optional      pam_systemd.so
session     [success=1 default=ignore] pam_succeed_if.so service in crond quiet use_uid
session     required      pam_unix.so
```

#### 第一部分

当用户登录的时候，首先会通过auth类接口对用户身份进行识别和密码认证。所以在该过程中验证会经过几个带auth的配置项。

其中的第一步是通过pam_env.so模块来定义用户登录之后的环境变量， pam_env.so允许设置和更改用户登录时候的环境变量，默认情况下，若没有特别指定配置文件，将依据/etc/security/pam_env.conf进行用户登录之后环境变量的设置。

然后通过pam_unix.so模块来提示用户输入密码，并将用户密码与/etc/shadow中记录的密码信息进行对比，如果密码比对结果正确则允许用户登录，而且**该配置项的使用的是“sufficient”控制位，即表示只要该配置项的验证通过，用户即可完全通过认证而不用再去走下面的认证项**。不过在特殊情况下，用户允许使用空密码登录系统，例如当将某个用户在/etc/shadow中的密码字段删除之后，该用户可以只输入用户名直接登录系统。

下面的配置项中，通过pam_succeed_if.so对用户的登录条件做一些限制，表示允许uid大于500的用户在通过密码验证的情况下登录，在Linux系统中，一般系统用户的uid都在500之内，所以该项即表示允许使用useradd命令以及默认选项建立的普通用户直接由本地控制台登录系统。

最后通过pam_deny.so模块对所有不满足上述任意条件的登录请求直接拒绝，pam_deny.so是一个特殊的模块，该模块返回值永远为否，类似于大多数安全机制的配置准则，在所有认证规则走完之后，对不匹配任何规则的请求直接拒绝。

#### 第二部分

三个配置项主要表示通过account账户类接口来识别账户的合法性以及登录权限。

第一行仍然使用pam_unix.so模块来声明用户需要通过密码认证。第二行承认了系统中uid小于500的系统用户的合法性。之后对所有类型的用户登录请求都开放控制台。

#### 第三部分

会通过password口令类接口来确认用户使用的密码或者口令的合法性。第一行配置项表示需要的情况下将调用pam_cracklib来验证用户密码复杂度。如果用户输入密码不满足复杂度要求或者密码错，最多将在三次这种错误之后直接返回密码错误的提示，否则期间任何一次正确的密码验证都允许登录。需要指出的是，pam_cracklib.so是一个常用的控制密码复杂度的pam模块，关于其用法举例我们会在之后详细介绍。之后带pam_unix.so和pam_deny.so的两行配置项的意思与之前类似。都表示需要通过密码认证并对不符合上述任何配置项要求的登录请求直接予以拒绝。不过用户如果执行的操作是单纯的登录，则这部分配置是不起作用的。

#### 第四部分

主要将通过session会话类接口为用户初始化会话连接。其中几个比较重要的地方包括，使用pam_keyinit.so表示当用户登录的时候为其建立相应的密钥环，并在用户登出的时候予以撤销。不过该行配置的控制位使用的是optional，表示这并非必要条件。之后通过pam_limits.so限制用户登录时的会话连接资源，相关pam_limit.so配置文件是/etc/security/limits.conf，默认情况下对每个登录用户都没有限制。关于该模块的配置方法在后面也会详细介绍。

### 常用的PAM模块介绍

| PAM模块          | 结合管理类型                     | 说明                                                         |
| ---------------- | -------------------------------- | ------------------------------------------------------------ |
| pam_unix.so      | auth                             | 提示用户输入密码,并与/etc/shadow文件相比对.匹配返回0         |
| pam_unix.so      | account                          | 检查用户的账号信息(包括是否过期等).帐号可用时,返回0.         |
| pam_unix.so      | password                         | 修改用户的密码. 将用户输入的密码,作为用户的新密码更新shadow文件 |
| pam_shells.so    | auth、account                    | 如果用户想登录系统，那么它的shell必须是在/etc/shells文件中之一的shell |
| pam_deny.so      | account、auth、password、session | 该模块可用于拒绝访问                                         |
| pam_permit.so    | account、auth、password、session | 模块任何时候都返回成功.                                      |
| pam_securetty.so | auth                             | 如果用户要以root登录时,则登录的tty必须在/etc/securetty之中.  |
| pam_listfile.so  | account、auth、password、session | 访问应用程的控制开关                                         |
| pam_cracklib.so  | password                         | 这个模块可以插入到一个程序的密码栈中,用于检查密码的强度.     |
| pam_limits.so    | session                          | 定义使用系统资源的上限，root用户也会受此限制，可以通过/etc/security/limits.conf或/etc/security/limits.d/*.conf来设定 |



## 强制重启系统

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/ee2e438907fa72c70d5393a651dc9113.png)

## hostname

hostname -i 是根据机器的hostname去解析ip，如果 /etc/hosts里面没有指定hostname对应的ip就会走dns 流程libnss_myhostname 返回所有ip

## tsar Floating point execption

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/72197d600425656ec9a8ed18bcc5853b.png)

因为 /etc/localtime 是deleted状态

## yum 源问题处理

[Yum commands error "pycurl.so: undefined symbol”](https://access.redhat.com/solutions/641093)

```
# yum check update
There was a problem importing one of the Python modules
required to run yum. The error leading to this problem was:

/usr/lib64/python2.6/site-packages/pycurl.so: undefined symbol: CRYPTO_set_locking_callback

Please install a package which provides this module, or
verify that the module is installed correctly.

It's possible that the above module doesn't match the
current version of Python, which is:
2.6.6 (r266:84292, Sep  4 2013, 07:46:00)
[GCC 4.4.7 20120313 (Red Hat 4.4.7-3)]

If you cannot solve this problem yourself, please go to
the yum faq at:
http://yum.baseurl.org/wiki/Faq
```

## 软中断、系统调用和上下文切换

“你可以把内核看做是不断对请求进行响应的服务器，这些请求可能来自在CPU上执行的进程，也可能来自发出中断的外部设备。老板的请求相当于中断，而顾客的请求相当于用户态进程发出的系统调用”。

软中断和系统调用一样，都是CPU停止掉当前用户态上下文，保存工作现场，然后陷入到内核态继续工作。二者的唯一区别是系统调用是切换到同进程的内核态上下文，而软中断是则是切换到了另外一个内核进程ksoftirqd上。

> 系统调用开销是200ns起步
>
> 从实验数据来看，一次软中断CPU开销大约3.4us左右
>
> 实验结果显示进程上下文切换平均耗时 3.5us，lmbench工具显示的进程上下文切换耗时从2.7us到5.48之间
>
> 大约每次线程切换开销大约是3.8us左右。**从上下文切换的耗时上来看，Linux线程（轻量级进程）其实和进程差别不太大**。

软中断和进程上下文切换比较起来，进程上下文切换是从用户进程A切换到了用户进程B。而软中断切换是从用户进程A切换到了内核线程ksoftirqd上。而ksoftirqd作为一个内核控制路径，其处理程序比一个用户进程要轻量，所以上下文切换开销相对比进程切换要少一些（实际数据基本差不多）。

系统调用只是在进程内将用户态切换到内核态，然后再切回来，而上下文切换可是直接从进程A切换到了进程B。显然这个上下文切换需要完成的工作量更大。

### [软中断开销计算](https://mp.weixin.qq.com/s?__biz=MjM5Njg5NDgwNA==&mid=2247483827&idx=3&sn=8b897c8d6d3038ea79bd156a0e88db10&scene=21#wechat_redirect)

- **查看软中断总耗时**， 首先用top命令可以看出每个核上软中断的开销占比，是在si列（1.2%--1秒[1000ms]中的1.2%）
- **查看软中断次数**，再用vmstat命令可以看到软中断的次数（in列 56000）
- **计算每次软中断的耗时**，该机器是16核的物理实机，故可以得出每个软中断需要的CPU时间是=12ms/(56000/16)次=3.428us。从实验数据来看，一次软中断CPU开销大约3.4us左右

## 参考文章

https://www.cnblogs.com/kevingrace/p/8671964.html

https://www.jianshu.com/p/ac3e7009a764

B 站哈工大操作系统视频地址：https://www.bilibili.com/video/BV1d4411v7u7?from=search&seid=2361361014547524697

B 站清华大学操作系统视频地址：https://www.bilibili.com/video/BV1js411b7vg?from=search&seid=2361361014547524697