---
title: ansible 常见问题
date: 2016-03-23 17:30:03
categories: Ansible
tags:
	- Linux
    - ansible
---





# ansible 常见问题

|    问题   |   解决方案   |
|-----------|-----------|
| 性能　|　ansible现在并发执行的任务好像还不够，执行批量传大文件的任务等的比较久 --- 用 synchronize  并将 fork 默认的5改大 |
| sudoers | 尝试解决ansible不能执行的问题，搜索各种英文文档，有人说版本的原因，有人反馈是脚本错误，最终无解。 继续在本地进行测试，发现使用原始的ansible命令可以执行ls，但是sudo ls时会提示 sudo need tty 之类的报错。 定位这个错误是因为在/etc/sudoers文件中设置了  Defaults requiretty，修改为 #Defaults requiretty，重试发现问题解决。 手工修改所有机器的配置文件，问题解决。{"msg": "ssh connection closed waiting for a privilege escalation password prompt"}---实际在部分机器上执行ansible命令时仍然有：sudo: no tty present and no askpass program specified  可以给ssh 增加-t/-tt参数来强制分配一个tty |
| failed to transfer file to  xxx   | 远端机器磁盘已经满,查看df -h，特别是/tmp |
| requires a json module, none found         |     问题已经通过nginx进行解决部署,安装ansible的时候，在目标机器上面安装 python-simplejson 通过如下命令：yum install python-simplejson -y  |
| openssh升级后无法登录报错         |     sshrpm 升级后会修改/etc/pam.d/sshd 文件。需要升级前备份此文件最后还原即可登录。      |
| 安装EagleEye出现的问题         |     1.hadoop name -format 这个需要输入Y/N；2.ssh-key没搞定；3.我们原来可以for循环的地方，古谦脚本只能1条1条的加      |
| 使用lineinfile方法时，内容不能包含": "(冒号+空格)，这个与ansible底层的分隔符冲突；|让用户在内容中不要包含": "|
| https 相关|SSL validation is not available in your version of python. You can use validate_certs=no, however this is unsafe and not recommended. You can also install python-ssl from EPEL|
| You need a C++ compiler for C++ support         |     yum install -y gcc gcc-c++      |
| 草谷问题  １：udp权限问题，有时候会出现权限认证失败；２：udp如何执行本地命令；　３：udp线上有什么方便的安装方法        |    问题1:方法一 去掉sudo试试（报访问文件 /opt/aliUDP/logs/udp.log 失败，备份重新建一个udp.log 文件给于 777 权限）; 方法二 指定 --private-key=PRIVATE_KEY_FILE （先试试直接ssh登录某台目标机器行不行）  问题2：udp支持直接运行目标机器上的命令，用法：udp server  -i ~/ali/udp-roles/roles/udp-install/udp-hosts.ini  -m shell -a " uptime ; df -lh " -u admin   |
|彦林问题  同一个ip部署不同的工程时，定义的变量会冲突；例如ip1同时部署mysql和diamond，都定义project_name；这样上面的会生效，下面定义的会被冲掉         |  Wiki：http://gitlab.alibaba-inc.com/middleware-udp/udp-doc/wikis/Different_Hosts_With_Different_Variables  将变量分别定义在 ./roles/mysql/defaults/main.yml 和 ./roles/diamond/defaults/main.yml中 或者使用不同的变量名 |
| 启善提供：执行udp-play-book 时会报找不到key的问题         |     在udp机器上执行 ssh-keygen 来生成key，解决   |
| ssh 的时候需要手工 yes/no | 增加参数 -o StrictHostKeyChecking no 就不需要输入了 |
|防火墙问题，本地可以访问，远程不能| 通过抓包/telnet等方式来确认这个问题， 通过iptables stop 来临时关闭防火墙； 修改iptables 的配置永久关闭或者增加所有其它节点到白名单中 |
|沈询提供|重要！ hostname -i 一定要是本机在局域网内的真实ip地址（不是127.0.0.1 ）。  要绑定etc/hosts 下面 把自己的hostname绑定到对应的真实ip上。 |
| 在UDP PlayBook中如何定义不同的机器、不同的Role使用不同的变量 | http://gitlab.alibaba-inc.com/middleware-udp/udp-doc/wikis/Different_Hosts_With_Different_Variables  |
|Dauth部署问题总结| http://gitlab.alibaba-inc.com/middleware-udp/udp-doc/wikis/Dauth-UDP-deployment-issues |
|Device or resource busy| 一般出现在Docker中修改/etc/hosts会有这个问题，ansible会rm它，实际它是-v进去的，通过脚本补丁绕过去 |

