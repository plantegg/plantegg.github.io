---
title: ansible 命令通道使用手册
date: 2016-03-24 17:30:03
categories: Ansible
tags:
	- Ansible
    - Linux
---

# ansible 命令通道使用手册

## 什么是命令通道？

> 当我们需要批量操作、查看一组机器，或者在这些机器上批量执行某个命令、修改某个文件，都可以通过命令通道在一台机器上批量并发完成对所有机器的操作

> 命令通道只是一个帮你将命令发送到多个目标机器，并将执行结果返回来给你的一个执行通道

## 使用场景

- [执行一行命令就能看到几十台机器的负载情况](http://gitlab.alibaba-inc.com/middleware-ansible/ansible-doc/wikis/UDP_Command_channel#hosts-ini-uptime)
- [批量执行远程服务器上已经写好的Shell脚本](http://gitlab.alibaba-inc.com/middleware-ansible/ansible-doc/wikis/UDP_Command_channel/#shell)
- 查看所有Web服务器最近10000行Log中有没有ERROR
- 查看所有DB服务器的内存使用情况
- 批量将所有Diamond服务器的某个端口从7000改成9000

## 开始准备

> 如果不想每次输入ssh密码的话请提前将本地公钥(~/.ssh/id_rsa.pub 没有的话 ssh-keygen生成一对)复制到目标机器的 ~/.ssh/authorized_keys 里面，否则每次执行命令都要输入密码

### 编写一个 hosts.ini 配置文件，内容如下:
```
[server]
10.125.0.169 ansible_ssh_port=9999 #如果只有这台机器ssh走的是9999端口，其它没有设置的还是默认22端口
10.125.3.33
120.26.116.193  

[worker]
10.125.12.174
10.125.14.238

[target]
10.125.192.40 
10.125.7.151
192.168.2.[101:107]
```
> server/worker/target表示将7台机器分成了三组，可以到所有7台机器执行同一个命令，也可以只在server/worker/target中的一组机器上执行某个命令.all代表所有7台机器

## 运行命令通道
### 查看 hosts.ini 里面所有服务器的 uptime

	```
	$ ansible -i hosts.ini all -m raw -a " uptime  " -u admin
	/usr/bin/ansible -i hosts.ini all -m raw -a  uptime   -u admin
	
	success => 10.125.12.174 => rc=0 =>
	 11:10:50 up 27 days, 15:40,  1 user,  load average: 0.05, 0.03, 0.05


​	
​	success => 120.26.116.193 => rc=0 =>
​	 11:10:50 up 13 days, 21:07,  1 user,  load average: 0.00, 0.00, 0.00
​	
​	```

> 命令参数说明

>    __all:__  表示对hosts.ini里面的所有服务器执行后面的命令 

>    __-i:__   指定hosts.ini文件所在的位置

>    __-m raw -a:__ 指定需要执行的命令

>    __" uptime "__ 双引号里面写上需要执行的命令

>    __-u admin__ 表示通过用户名admin 去执行命令【如果没有做好免密码，请加上 -k 参数，会出来提示输入SSH密码】


### 查看 hosts.ini 里面 server 组服务器的 home目录下的文件结构
	$ ansible -i hosts.ini server -m raw -a " ls -lh ~/  " -u admin
	
	/usr/bin/ansible -i hosts.ini server -m raw -a  ls -lh ~/   -u admin
	
	success => 10.125.0.169 => rc=0 =>
	total 12K
	drwxr-xr-x  2 root  root  4.0K Nov 13 12:34 files
	drwxr-xr-x 11 admin admin 4.0K Oct 20 10:49 tomcat
	drwxr-xr-x  3 test  games 4.0K Nov 18 15:40 ansible-engine

​	success => 10.125.3.33 => rc=0 =>
​	total 20K
​	-rw-------  1 admin admin 1.4K Nov 12 13:39 authorized_keys
​	drwxr-xr-x  2 root  root  4.0K Nov 12 16:24 engine
​	drwxr-xr-x  2 root  root  4.0K Nov 13 12:22 files
​	drwxr-xr-x 11 admin admin 4.0K Nov 18 15:43 tomcat
​	drwxr-xr-x  3 test  games 4.0K Nov 18 15:40 ansible-engine



### 查看部分机器 hostname

```
# ansible -i ccb_test.ini 192.168.2.10* -m shell -a 'hostname '
[WARNING]: Invalid characters were found in group names but not replaced, use -vvvv to see details
192.168.2.100 | CHANGED | rc=0 >>
az2-drds-100
192.168.2.106 | CHANGED | rc=0 >>
az2-manager-106
192.168.2.101 | CHANGED | rc=0 >>
az2-alisql-101
192.168.2.102 | CHANGED | rc=0 >>
az2-alisql-102
192.168.2.105 | CHANGED | rc=0 >>
az2-alisql-105
192.168.2.104 | CHANGED | rc=0 >>
az2-alisql-104
192.168.2.103 | CHANGED | rc=0 >>
az2-alisql-103
192.168.2.107 | CHANGED | rc=0 >>
az2-manager-107
```

### 使用环境变量

```
#config /etc/hosts
ansible -i $1 all -m shell -a  " sed -i '/registry/d' /etc/hosts "
ansible -i $1 all -m shell -a  " echo '{{ registry }}    registry' >/etc/hosts "
ansible -i $1 all -m shell -a " echo '{{ inventory_hostname }} `hostname`' >>/etc/hosts "
ansible -i $1 diamond -m shell -a " echo '{{ inventory_hostname  }}   jmenv.tbsite.net' >> /etc/hosts " -u root
//修改机器hostname
ansible -i $1 all -m shell -a " hostnamectl set-hostname='drds-{{ server_id }}' " -u root
//修改机器hostname -i
ansible -i $1 all -m shell -a " echo ' {{ inventory_hostname }} drds-{{ server_id }}' >> /etc/hosts  " -u root

//hostname 修改机器名
# ansible -i ccb_test.ini 192.168.2.101 -m hostname -a " name=az2-alisql-101 "
[WARNING]: Invalid characters were found in group names but not replaced, use -vvvv to see details
192.168.2.101 | CHANGED => {
    "ansible_facts": {
        "ansible_domain": "", 
        "ansible_fqdn": "iZ2ze9aj0re2ggbqa4dgxkZ", 
        "ansible_hostname": "az2-alisql-101", 
        "ansible_nodename": "az2-alisql-101", 
        "discovered_interpreter_python": "/usr/bin/python"
    }, 
    "changed": true, 
    "name": "az2-alisql-101"
}
```

### 管理系统service

设置 docker daemon服务重新启动和开机自动启动

```
# ansible -i ccb_test.ini 192.168.2.101 -m service -a " name=docker enabled=yes state=restarted "
[WARNING]: Invalid characters were found in group names but not replaced, use -vvvv to see details
192.168.2.101 | CHANGED => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    }, 
    "changed": true, 
    "enabled": true, 
    "name": "docker", 
    "state": "started", 
    "status": {
        "ActiveEnterTimestamp": "二 2020-05-12 19:03:57 CST", 
        "ActiveEnterTimestampMonotonic": "1553024093129", 
        "ActiveExitTimestamp": "二 2020-05-12 19:01:24 CST", 
        "ActiveExitTimestampMonotonic": "1552870910912", 
        "ActiveState": "active", 
        "After": "systemd-journald.socket system.slice docker.socket firewalld.service containerd.service network-online.target basic.target", 
        "AllowIsolate": "no", 
        "AmbientCapabilities": "0", 
        "AssertResult": "yes", 
        "AssertTimestamp": "二 2020-05-12 19:03:57 CST", 
        "AssertTimestampMonotonic": "1553023902297", 
        "Before": "multi-user.target shutdown.target", 
        "BindsTo": "containerd.service", 
        "BlockIOAccounting": "no", 
        "BlockIOWeight": "18446744073709551615", 
        "CPUAccounting": "no", 
        "CPUQuotaPerSecUSec": "infinity", 
        "CPUSchedulingPolicy": "0", 
        "CPUSchedulingPriority": "0", 
        "CPUSchedulingResetOnFork": "no", 
        "CPUShares": "18446744073709551615", 
        "CanIsolate": "no", 
        "CanReload": "yes", 
        "CanStart": "yes", 
        "CanStop": "yes", 
        "CapabilityBoundingSet": "18446744073709551615", 
        "ConditionResult": "yes", 
        "ConditionTimestamp": "二 2020-05-12 19:03:57 CST", 
        "ConditionTimestampMonotonic": "1553023902297", 
        "Conflicts": "shutdown.target", 
        "ConsistsOf": "docker.socket", 
        "ControlGroup": "/system.slice/docker.service", 
        "ControlPID": "0", 
        "DefaultDependencies": "yes", 
        "Delegate": "yes", 
        "Description": "Docker Application Container Engine", 
        "DevicePolicy": "auto", 
        "Documentation": "https://docs.docker.com", 
        "ExecMainCode": "0", 
        "ExecMainExitTimestampMonotonic": "0", 
        "ExecMainPID": "16213", 
        "ExecMainStartTimestamp": "二 2020-05-12 19:03:57 CST", 
        "ExecMainStartTimestampMonotonic": "1553023907468", 
        "ExecMainStatus": "0", 
        "ExecReload": "{ path=/bin/kill ; argv[]=/bin/kill -s HUP $MAINPID ; ignore_errors=no ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }", 
        "ExecStart": "{ path=/usr/bin/dockerd ; argv[]=/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:2376 --data-root=/var/lib/docker --log-opt max-size=50m --log-opt max-file=3 --registry-mirror=https://oqpc6eum.mirror.aliyuncs.com --containerd=/run/containerd/containerd.sock ; ignore_errors=no ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }", 
        "FailureAction": "none", 
        "FileDescriptorStoreMax": "0", 
        "FragmentPath": "/usr/lib/systemd/system/docker.service", 
        "GuessMainPID": "yes", 
        "IOScheduling": "0", 
        "Id": "docker.service", 
        "IgnoreOnIsolate": "no", 
        "IgnoreOnSnapshot": "no", 
        "IgnoreSIGPIPE": "yes", 
        "InactiveEnterTimestamp": "二 2020-05-12 19:03:43 CST", 
        "InactiveEnterTimestampMonotonic": "1553009791884", 
        "InactiveExitTimestamp": "二 2020-05-12 19:03:57 CST", 
        "InactiveExitTimestampMonotonic": "1553023907496", 
        "JobTimeoutAction": "none", 
        "JobTimeoutUSec": "0", 
        "KillMode": "process", 
        "KillSignal": "15", 
        "LimitAS": "18446744073709551615", 
        "LimitCORE": "18446744073709551615", 
        "LimitCPU": "18446744073709551615", 
        "LimitDATA": "18446744073709551615", 
        "LimitFSIZE": "18446744073709551615", 
        "LimitLOCKS": "18446744073709551615", 
        "LimitMEMLOCK": "65536", 
        "LimitMSGQUEUE": "819200", 
        "LimitNICE": "0", 
        "LimitNOFILE": "18446744073709551615", 
        "LimitNPROC": "18446744073709551615", 
        "LimitRSS": "18446744073709551615", 
        "LimitRTPRIO": "0", 
        "LimitRTTIME": "18446744073709551615", 
        "LimitSIGPENDING": "379870", 
        "LimitSTACK": "18446744073709551615", 
        "LoadState": "loaded", 
        "MainPID": "16213", 
        "MemoryAccounting": "no", 
        "MemoryCurrent": "58327040", 
        "MemoryLimit": "18446744073709551615", 
        "MountFlags": "0", 
        "Names": "docker.service", 
        "NeedDaemonReload": "no", 
        "Nice": "0", 
        "NoNewPrivileges": "no", 
        "NonBlocking": "no", 
        "NotifyAccess": "main", 
        "OOMScoreAdjust": "0", 
        "OnFailureJobMode": "replace", 
        "PermissionsStartOnly": "no", 
        "PrivateDevices": "no", 
        "PrivateNetwork": "no", 
        "PrivateTmp": "no", 
        "ProtectHome": "no", 
        "ProtectSystem": "no", 
        "RefuseManualStart": "no", 
        "RefuseManualStop": "no", 
        "RemainAfterExit": "no", 
        "Requires": "docker.socket basic.target", 
        "Restart": "always", 
        "RestartUSec": "2s", 
        "Result": "success", 
        "RootDirectoryStartOnly": "no", 
        "RuntimeDirectoryMode": "0755", 
        "SameProcessGroup": "no", 
        "SecureBits": "0", 
        "SendSIGHUP": "no", 
        "SendSIGKILL": "yes", 
        "Slice": "system.slice", 
        "StandardError": "inherit", 
        "StandardInput": "null", 
        "StandardOutput": "journal", 
        "StartLimitAction": "none", 
        "StartLimitBurst": "3", 
        "StartLimitInterval": "60000000", 
        "StartupBlockIOWeight": "18446744073709551615", 
        "StartupCPUShares": "18446744073709551615", 
        "StatusErrno": "0", 
        "StopWhenUnneeded": "no", 
        "SubState": "running", 
        "SyslogLevelPrefix": "yes", 
        "SyslogPriority": "30", 
        "SystemCallErrorNumber": "0", 
        "TTYReset": "no", 
        "TTYVHangup": "no", 
        "TTYVTDisallocate": "no", 
        "TasksAccounting": "no", 
        "TasksCurrent": "58", 
        "TasksMax": "18446744073709551615", 
        "TimeoutStartUSec": "0", 
        "TimeoutStopUSec": "0", 
        "TimerSlackNSec": "50000", 
        "Transient": "no", 
        "TriggeredBy": "docker.socket", 
        "Type": "notify", 
        "UMask": "0022", 
        "UnitFilePreset": "disabled", 
        "UnitFileState": "enabled", 
        "WantedBy": "multi-user.target", 
        "Wants": "network-online.target system.slice", 
        "WatchdogTimestamp": "二 2020-05-12 19:03:57 CST", 
        "WatchdogTimestampMonotonic": "1553024093096", 
        "WatchdogUSec": "0"
    }
}

```



### 一次执行多个命令

```
$ ansible -i hosts.ini server -m raw -a " which nc ; find /opt/aliUDP/logs/  " -u admin

/usr/bin/ansible -i hosts.ini server -m raw -a  which nc ; find /opt/aliUDP/logs/   -u admin

FAILED => 120.26.116.193 => rc=1 =>
which: no nc in (/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin)
find: /opt/aliUDP: No such file or directory


success => 10.125.3.33 => rc=0 =>
/usr/bin/nc
/opt/aliUDP/logs/
/opt/aliUDP/logs/ansible.log.bak
/opt/aliUDP/logs/ansible.log


success => 10.125.0.169 => rc=0 =>
/usr/bin/nc
/opt/aliUDP/logs/
/opt/aliUDP/logs/ansible.log.bak
/opt/aliUDP/logs/ansible.log

```

>结果说明

>   其中  120.26.116.193 上没有命令 nc 和 /opt/aliUDP 文件夹所有执行失败，但是其他两台机器都正常返回了结果

### Copy本地的某个文件到服务器上【前面的例子中都是单独在远程机器上执行的命令】
```
$ ansible  -i hosts.ini server  -m copy -a " src='~/.ssh/id_rsa.pub' dest='/tmp/' owner=admin " -u admin

SUCCESS => 120.26.116.193 => {
    "changed": true, 
    "checksum": "b12ccf236ab788bbaebd7159c563e97411389c9e", 
    "dest": "/tmp/id_rsa.pub", 
    "gid": 0, 
    "group": "root", 
    "md5sum": "b6ba28284ab95aaa0f47602bdab49f46", 
    "mode": "0644", 
    "owner": "root", 
    "size": 392, 
    "src": "/root/.ansible/ansible-tmp-1449109886.94-70134064194486/source", 
    "state": "file", 
    "uid": 0
}

SUCCESS => 10.125.0.169 => {
    "changed": true, 
    "checksum": "b12ccf236ab788bbaebd7159c563e97411389c9e", 
    "dest": "/tmp/id_rsa.pub", 
    "gid": 500, 
    "group": "admin", 
    "md5sum": "b6ba28284ab95aaa0f47602bdab49f46", 
    "mode": "0664", 
    "owner": "admin", 
    "size": 392, 
    "src": "/home/admin/.ansible/ansible-tmp-1449109886.78-98797505042348/source", 
    "state": "file", 
    "uid": 500
}

SUCCESS => 10.125.3.33 => {
    "changed": true, 
    "checksum": "b12ccf236ab788bbaebd7159c563e97411389c9e", 
    "dest": "/tmp/id_rsa.pub", 
    "gid": 500, 
    "group": "admin", 
    "md5sum": "b6ba28284ab95aaa0f47602bdab49f46", 
    "mode": "0664", 
    "owner": "admin", 
    "size": 392, 
    "src": "/home/admin/.ansible/ansible-tmp-1449109886.81-269249309502640/source", 
    "state": "file", 
    "uid": 500
}
```
>参数说明

>    __-m copy -a:__ 指定这是 **copy** 的命令

>    __"  src='~/.ssh/id_rsa.pub' dest='/tmp/' "__ src表示本地文件 dest表示远程目标位置

### 验证一下刚刚copy上去的文件的MD5值
```
$ ansible  -i hosts.ini server  -m command -a " md5sum /tmp/id_rsa.pub " -u admin

success => 10.125.0.169 => rc=0 =>
b6ba28284ab95aaa0f47602bdab49f46  /tmp/id_rsa.pub

success => 10.125.3.33 => rc=0 =>
b6ba28284ab95aaa0f47602bdab49f46  /tmp/id_rsa.pub

success => 120.26.116.193 => rc=0 =>
b6ba28284ab95aaa0f47602bdab49f46  /tmp/id_rsa.pub
```
结果说明

>   md5都是b6ba28284ab95aaa0f47602bdab49f46 跟本地的一致，说明成功复制到目标机器了

### 执行远程服务器上已经写好的Shell脚本
```
$ cat test.sh 
#/bin/sh

ifconfig | grep 'inet addr' 
echo "-------------"
uptime
echo "-------------"
date

df -lh
```

```
$ ansible  -i hosts.ini server  -m command -a " sh /tmp/test.sh " -u admin

/usr/bin/ansible -i hosts.ini server -m command -a  sh /tmp/test.sh  -u admin

success => 10.125.3.33 => rc=0 =>
          inet addr:10.125.3.33  Bcast:10.125.15.255  Mask:255.255.240.0
          inet addr:127.0.0.1  Mask:255.0.0.0
-------------
 10:50:51 up 28 days, 15:20,  2 users,  load average: 0.01, 0.05, 0.06
-------------
Thu Dec  3 10:50:51 CST 2015
Filesystem            Size  Used Avail Use% Mounted on
/dev/xvda1            250G  7.8G  230G   4% /
tmpfs                 2.0G  148K  2.0G   1% /dev/shm

success => 10.125.0.169 => rc=0 =>
          inet addr:10.125.0.169  Bcast:10.125.15.255  Mask:255.255.240.0
          inet addr:127.0.0.1  Mask:255.0.0.0
-------------
 10:50:51 up 29 days, 44 min,  3 users,  load average: 0.00, 0.01, 0.05
-------------
Thu Dec  3 10:50:51 CST 2015
Filesystem            Size  Used Avail Use% Mounted on
/dev/xvda1            250G  8.2G  230G   4% /
tmpfs                 2.0G   72K  2.0G   1% /dev/shm

success => 120.26.116.193 => rc=0 =>
          inet addr:10.51.38.122  Bcast:10.51.39.255  Mask:255.255.248.0
          inet addr:120.26.116.193  Bcast:120.26.119.255  Mask:255.255.252.0
          inet addr:127.0.0.1  Mask:255.0.0.0
-------------
 10:50:51 up 14 days, 20:47,  0 users,  load average: 0.00, 0.00, 0.00
-------------
2015年 12月 03日 星期四 10:50:51 CST
Filesystem            Size  Used Avail Use% Mounted on
/dev/hda1              20G  1.5G   19G   8% /
tmpfs                 249M     0  249M   0% /dev/shm

```

### copy个人笔记本的公钥到服务器上，以后从笔记本登录服务器不再需要输入密码

```
$ ansible -i ansible-hosts.ini all -m authorized_key -a " user=xijun.rxj key=\"{{ lookup('file', '/tmp/id_rsa.pub') }} \"  " -u xijun.rxj -k

```

### Copying files between different folders on the same remote machine

You can also copy files between the various locations on the remote servers. You have to set the **remote_src** parameter to yes.

The following example copies the hello6 file in the /tmp directory of the remote server and pastes it in the /etc/ directory.

```
- hosts: blocks
  tasks:
  - name: Ansible copy files remote to remote
    copy:
      src: /tmp/hello6
      dest: /etc
      remote_src: yes
```

or:

```
ansible blocks -m copy -a "src=/tmp/hello6 dest=/tmp/hello7etc remote_src=yes" -s -i inventory.ini
```



### 效率更高的 copy：synchronize

```
ansible -i xty_172.ini all -m synchronize -a " src=/home/ren/docker.service dest=/usr/lib/systemd/system/docker.socket " -u root
```



### 不使用 hosts.ini文件，从命令行中传入目标机的 ip 列表

```
$ ansible -i 10.125.0.169,10.125.192.40 all -e "ansible_ssh_port=22" -a "uptime" -u xijun.rxj

success => 10.125.192.40 => rc=0 =>
 12:31:50 up 48 days, 17:01,  0 users,  load average: 0.13, 0.06, 0.05

success => 10.125.0.169 => rc=0 =>
 12:31:50 up 49 days,  2:25,  0 users,  load average: 0.00, 0.01, 0.05
```

执行说明

>    -i 后面带入ip列表，注意每个IP后面一定要有 “,” 分割开来，all 关键字也是必须的

>    -e 中ansible_ssh_port=22表示ssh使用22端口（默认），如果ssh使用9999端口在这里将22改成9999即可

### 使用root sudo权限来执行命令
```
ansible -i 10.125.6.93, all -m  shell -a " ls -lh /home/admin/"    -u xijun.rxj --become-user=root --ask-become-pass --become-method=sudo --become -k

```

### 给admin授权登录server不需要输入密码（也不知道admin的密码）
```
通过 xijun.rxj(已知密码) 以root 权限将本机pub key复制到server上的 /home/admin, 再通过admin账号登录server就不需要密码了：
ansible -i 10.125.6.93, all -m  authorized_key -a " user=admin key=\"{{ lookup('file', '/home/ren/.ssh/id_rsa.pub') }} \"  " -u xijun.rxj --become-user=root --ask-become-pass --become-method=sudo --become -k

不需要密码就可以执行：
ansible -i 10.125.6.93, all -m shell -a " ls -lha /home/admin/  " -u admin
```

### fetch:将远程服务器上的public key 读取到本地

```
ansible -i kfc.ini hadoop -m fetch -a " src=/home/admin/.ssh/id_rsa.pub dest=./test/  "  -u admin

find test/ -type f | xargs cat > ./authorized_keys

#push all the public keys to the server
ansible -i ~/ali/ansible-edas/kfc.ini hadoop -m  copy -a " src=./authorized_keys dest=/home/admin/.ssh/authorized_keys mode=600  " -u admin
```

或者循环fetch：

```yaml
$cat fetch.yaml 
- hosts: all   
  tasks:
    - name: list the files in the folder
      #command: ls /u01/nmon/tpcc/ 
      shell: (cd /remote; find . -maxdepth 1 -type f) | cut -d'/' -f2
      register: dir_out

    - name: do the action
      fetch: src=/u01/nmon/tpcc/{{item}} dest=/home/aliyun/nmon_tpcc/ flat=no
      with_items: "{{dir_out.stdout_lines}}"

```

执行结果：

```
$ansible-playbook -i /home/aliyun/all.ini  fetch.yaml -u admin

PLAY [all] *******************************************************************************************

TASK [Gathering Facts] *******************************************************************************
ok: [10.88.88.18]
ok: [10.88.88.16]
ok: [10.88.88.15]
ok: [10.88.88.19]
ok: [10.88.88.17]
ok: [10.88.88.20]

TASK [list the files in the folder] ******************************************************************
changed: [10.88.88.15]
changed: [10.88.88.16]
changed: [10.88.88.17]
changed: [10.88.88.18]
changed: [10.88.88.19]
changed: [10.88.88.20]

TASK [do the action] *********************************************************************************
changed: [10.88.88.15] => (item=uos15_200729_1108.nmon)
changed: [10.88.88.18] => (item=uos18_200729_1107.nmon)
changed: [10.88.88.16] => (item=uos16_200729_1106.nmon)
changed: [10.88.88.19] => (item=adbpg2-PC_200729_1108.nmon)
changed: [10.88.88.17] => (item=uos17_200729_1107.nmon)
changed: [10.88.88.19] => (item=adbpg2-PC_200729_1936.nmon)
changed: [10.88.88.20] => (item=adbpg-PC_200729_1110.nmon)

PLAY RECAP *******************************************************************************************
10.88.88.15                : ok=3    changed=2    unreachable=0    failed=0   
10.88.88.16                : ok=3    changed=2    unreachable=0    failed=0   
10.88.88.17                : ok=3    changed=2    unreachable=0    failed=0   
10.88.88.18                : ok=3    changed=2    unreachable=0    failed=0   
10.88.88.19                : ok=3    changed=2    unreachable=0    failed=0   
10.88.88.20                : ok=3    changed=2    unreachable=0    failed=0   
```

### setup:获取机器配置、参数信息

```
# ansible -i 192.168.1.91, all -m setup -u admin/usr/lib/python2.7/site-
192.168.1.91 | SUCCESS => {
    "ansible_facts": {
        "ansible_all_ipv4_addresses": [
            "172.17.0.1", 
            "192.168.0.91", 
            "192.168.1.91"
        ], 
        "ansible_all_ipv6_addresses": [], 
        "ansible_apparmor": {
            "status": "disabled"
        }, 
        "ansible_architecture": "x86_64", 
        "ansible_bios_date": "04/01/2014", 
        "ansible_bios_version": "8c24b4c", 
        "ansible_cmdline": {
            "BOOT_IMAGE": "/boot/vmlinuz-3.10.0-957.21.3.el7.x86_64", 
            "LANG": "en_US.UTF-8", 
            "biosdevname": "0", 
            "console": "ttyS0,115200n8", 
            "crashkernel": "auto", 
            "idle": "halt", 
            "net.ifnames": "0", 
            "noibrs": true, 
            "quiet": true, 
            "rhgb": true, 
            "ro": true, 
            "root": "UUID=1114fe9e-2309-4580-b183-d778e6d97397"
        }, 
        "ansible_date_time": {
            "date": "2020-07-15", 
            "day": "15", 
            "epoch": "1594796084", 
            "hour": "14", 
            "iso8601": "2020-07-15T06:54:44Z", 
            "iso8601_basic": "20200715T145444643628", 
            "iso8601_basic_short": "20200715T145444", 
            "iso8601_micro": "2020-07-15T06:54:44.643725Z", 
            "minute": "54", 
            "month": "07", 
            "second": "44", 
            "time": "14:54:44", 
            "tz": "CST", 
            "tz_offset": "+0800", 
            "weekday": "星期三", 
            "weekday_number": "3", 
            "weeknumber": "28", 
            "year": "2020"
        }, 
        "ansible_default_ipv4": {
            "address": "192.168.0.91", 
            "alias": "eth0", 
            "broadcast": "192.168.0.255", 
            "gateway": "192.168.0.253", 
            "interface": "eth0", 
            "macaddress": "00:16:3e:30:d9:a4", 
            "mtu": 1500, 
            "netmask": "255.255.255.0", 
            "network": "192.168.0.0", 
            "type": "ether"
        }, 
        "ansible_default_ipv6": {}, 
        "ansible_device_links": {
            "ids": {}, 
            "labels": {
                "loop2": [
                    "CDROM"
                ]
            }, 
            "masters": {}, 
            "uuids": {
                "loop0": [
                    "2020-07-12-14-26-47-00"
                ], 
                "loop1": [
                    "2020-07-12-20-25-18-00"
                ], 
                "loop2": [
                    "2020-07-13-09-57-36-00"
                ], 
                "vda1": [
                    "1114fe9e-2309-4580-b183-d778e6d97397"
                ]
            }
        }, 
        "ansible_devices": {
            "loop0": {
                "holders": [], 
                "host": "", 
                "links": {
                    "ids": [], 
                    "labels": [], 
                    "masters": [], 
                    "uuids": [
                        "2020-07-12-14-26-47-00"
                    ]
                }, 
                "model": null, 
                "partitions": {}, 
                "removable": "0", 
                "rotational": "1", 
                "sas_address": null, 
                "sas_device_handle": null, 
                "scheduler_mode": "", 
                "sectors": "327924", 
                "sectorsize": "512", 
                "size": "160.12 MB", 
                "support_discard": "4096", 
                "vendor": null, 
                "virtual": 1
            }, 
            "loop1": {
                "holders": [], 
                "host": "", 
                "links": {
                    "ids": [], 
                    "labels": [], 
                    "masters": [], 
                    "uuids": [
                        "2020-07-12-20-25-18-00"
                    ]
                }, 
                "model": null, 
                "partitions": {}, 
                "removable": "0", 
                "rotational": "1", 
                "sas_address": null, 
                "sas_device_handle": null, 
                "scheduler_mode": "", 
                "sectors": "359172", 
                "sectorsize": "512", 
                "size": "175.38 MB", 
                "support_discard": "4096", 
                "vendor": null, 
                "virtual": 1
            }, 
            "loop2": {
                "holders": [], 
                "host": "", 
                "links": {
                    "ids": [], 
                    "labels": [
                        "CDROM"
                    ], 
                    "masters": [], 
                    "uuids": [
                        "2020-07-13-09-57-36-00"
                    ]
                }, 
                "model": null, 
                "partitions": {}, 
                "removable": "0", 
                "rotational": "1", 
                "sas_address": null, 
                "sas_device_handle": null, 
                "scheduler_mode": "", 
                "sectors": "128696", 
                "sectorsize": "512", 
                "size": "62.84 MB", 
                "support_discard": "4096", 
                "vendor": null, 
                "virtual": 1
            }, 
            "vda": {
                "holders": [], 
                "host": "SCSI storage controller: Red Hat, Inc. Virtio block device", 
                "links": {
                    "ids": [], 
                    "labels": [], 
                    "masters": [], 
                    "uuids": []
                }, 
                "model": null, 
                "partitions": {
                    "vda1": {
                        "holders": [], 
                        "links": {
                            "ids": [], 
                            "labels": [], 
                            "masters": [], 
                            "uuids": [
                                "1114fe9e-2309-4580-b183-d778e6d97397"
                            ]
                        }, 
                        "sectors": "838847992", 
                        "sectorsize": 512, 
                        "size": "399.99 GB", 
                        "start": "2048", 
                        "uuid": "1114fe9e-2309-4580-b183-d778e6d97397"
                    }
                }, 
                "removable": "0", 
                "rotational": "1", 
                "sas_address": null, 
                "sas_device_handle": null, 
                "scheduler_mode": "mq-deadline", 
                "sectors": "838860800", 
                "sectorsize": "512", 
                "size": "400.00 GB", 
                "support_discard": "0", 
                "vendor": "0x1af4", 
                "virtual": 1
            }
        }, 
        "ansible_distribution": "CentOS", 
        "ansible_distribution_file_parsed": true, 
        "ansible_distribution_file_path": "/etc/redhat-release", 
        "ansible_distribution_file_variety": "RedHat", 
        "ansible_distribution_major_version": "7", 
        "ansible_distribution_release": "Core", 
        "ansible_distribution_version": "7.8", 
        "ansible_dns": {
            "nameservers": [
                "100.100.2.136", 
                "100.100.2.138"
            ], 
            "options": {
                "attempts": "3", 
                "rotate": true, 
                "single-request-reopen": true, 
                "timeout": "2"
            }
        }, 
        "ansible_docker0": {
            "active": false, 
            "device": "docker0", 
            "features": {
                "busy_poll": "off [fixed]", 
                "fcoe_mtu": "off [fixed]", 
                "generic_receive_offload": "on", 
                "generic_segmentation_offload": "on", 
                "highdma": "on", 
                "hw_tc_offload": "off [fixed]", 
                "l2_fwd_offload": "off [fixed]", 
                "large_receive_offload": "off [fixed]", 
                "loopback": "off [fixed]", 
                "netns_local": "on [fixed]", 
                "ntuple_filters": "off [fixed]", 
                "receive_hashing": "off [fixed]", 
                "rx_all": "off [fixed]", 
                "rx_checksumming": "off [fixed]", 
                "rx_fcs": "off [fixed]", 
                "rx_gro_hw": "off [fixed]", 
                "rx_udp_tunnel_port_offload": "off [fixed]", 
                "rx_vlan_filter": "off [fixed]", 
                "rx_vlan_offload": "off [fixed]", 
                "rx_vlan_stag_filter": "off [fixed]", 
                "rx_vlan_stag_hw_parse": "off [fixed]", 
                "scatter_gather": "on", 
                "tcp_segmentation_offload": "on", 
                "tx_checksum_fcoe_crc": "off [fixed]", 
                "tx_checksum_ip_generic": "on", 
                "tx_checksum_ipv4": "off [fixed]", 
                "tx_checksum_ipv6": "off [fixed]", 
                "tx_checksum_sctp": "off [fixed]", 
                "tx_checksumming": "on", 
                "tx_fcoe_segmentation": "on", 
                "tx_gre_csum_segmentation": "on", 
                "tx_gre_segmentation": "on", 
                "tx_gso_partial": "on", 
                "tx_gso_robust": "on", 
                "tx_ipip_segmentation": "on", 
                "tx_lockless": "on [fixed]", 
                "tx_nocache_copy": "off", 
                "tx_scatter_gather": "on", 
                "tx_scatter_gather_fraglist": "on", 
                "tx_sctp_segmentation": "on", 
                "tx_sit_segmentation": "on", 
                "tx_tcp6_segmentation": "on", 
                "tx_tcp_ecn_segmentation": "on", 
                "tx_tcp_mangleid_segmentation": "on", 
                "tx_tcp_segmentation": "on", 
                "tx_udp_tnl_csum_segmentation": "on", 
                "tx_udp_tnl_segmentation": "on", 
                "tx_vlan_offload": "on", 
                "tx_vlan_stag_hw_insert": "on", 
                "udp_fragmentation_offload": "on", 
                "vlan_challenged": "off [fixed]"
            }, 
            "hw_timestamp_filters": [], 
            "id": "8000.0242e441b693", 
            "interfaces": [], 
            "ipv4": {
                "address": "172.17.0.1", 
                "broadcast": "172.17.255.255", 
                "netmask": "255.255.0.0", 
                "network": "172.17.0.0"
            }, 
            "macaddress": "02:42:e4:41:b6:93", 
            "mtu": 1500, 
            "promisc": false, 
            "stp": false, 
            "timestamping": [
                "rx_software", 
                "software"
            ], 
            "type": "bridge"
        }, 
        "ansible_domain": "", 
        "ansible_effective_group_id": 1000, 
        "ansible_effective_user_id": 1000, 
        "ansible_env": {
            "HISTCONTROL": "erasedups", 
            "HISTFILESIZE": "30000", 
            "HISTIGNORE": "pwd:ls:cd:ll:", 
            "HISTSIZE": "30000", 
            "HISTTIMEFORMAT": "%d/%m/%y %T ", 
            "HOME": "/home/admin", 
            "JAVA_HOME": "/opt/taobao/java", 
            "LANG": "C", 
            "LC_ADDRESS": "zh_CN.UTF-8", 
            "LC_ALL": "C", 
            "LC_IDENTIFICATION": "zh_CN.UTF-8", 
            "LC_MEASUREMENT": "zh_CN.UTF-8", 
            "LC_MONETARY": "zh_CN.UTF-8", 
            "LC_NAME": "zh_CN.UTF-8", 
            "LC_NUMERIC": "C", 
            "LC_PAPER": "zh_CN.UTF-8", 
            "LC_TELEPHONE": "zh_CN.UTF-8", 
            "LC_TIME": "zh_CN.UTF-8", 
            "LESSOPEN": "||/usr/bin/lesspipe.sh %s", 
            "LOGNAME": "admin", 
            "MAIL": "/var/mail/admin", 
            "PATH": "/usr/local/bin:/usr/bin:/opt/taobao/java8/bin:/home/admin/tools", 
            "PROMPT_COMMAND": "history -a", 
            "PS4": "+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }", 
            "PWD": "/home/admin", 
            "SHELL": "/bin/bash", 
            "SHLVL": "2", 
            "SSH_CLIENT": "192.168.1.79 51412 22", 
            "SSH_CONNECTION": "192.168.1.79 51412 192.168.1.91 22", 
            "USER": "admin", 
            "XDG_RUNTIME_DIR": "/run/user/1000", 
            "XDG_SESSION_ID": "40120", 
            "_": "/usr/bin/python"
        }, 
        "ansible_eth0": {
            "active": true, 
            "device": "eth0", 
            "features": {
                "busy_poll": "off [fixed]", 
                "fcoe_mtu": "off [fixed]", 
                "generic_receive_offload": "on", 
                "generic_segmentation_offload": "on", 
                "highdma": "on [fixed]", 
                "hw_tc_offload": "off [fixed]", 
                "l2_fwd_offload": "off [fixed]", 
                "large_receive_offload": "off [fixed]", 
                "loopback": "off [fixed]", 
                "netns_local": "off [fixed]", 
                "ntuple_filters": "off [fixed]", 
                "receive_hashing": "off [fixed]", 
                "rx_all": "off [fixed]", 
                "rx_checksumming": "on [fixed]", 
                "rx_fcs": "off [fixed]", 
                "rx_gro_hw": "off [fixed]", 
                "rx_udp_tunnel_port_offload": "off [fixed]", 
                "rx_vlan_filter": "off [fixed]", 
                "rx_vlan_offload": "off [fixed]", 
                "rx_vlan_stag_filter": "off [fixed]", 
                "rx_vlan_stag_hw_parse": "off [fixed]", 
                "scatter_gather": "on", 
                "tcp_segmentation_offload": "on", 
                "tx_checksum_fcoe_crc": "off [fixed]", 
                "tx_checksum_ip_generic": "on", 
                "tx_checksum_ipv4": "off [fixed]", 
                "tx_checksum_ipv6": "off [fixed]", 
                "tx_checksum_sctp": "off [fixed]", 
                "tx_checksumming": "on", 
                "tx_fcoe_segmentation": "off [fixed]", 
                "tx_gre_csum_segmentation": "off [fixed]", 
                "tx_gre_segmentation": "off [fixed]", 
                "tx_gso_partial": "off [fixed]", 
                "tx_gso_robust": "off [fixed]", 
                "tx_ipip_segmentation": "off [fixed]", 
                "tx_lockless": "off [fixed]", 
                "tx_nocache_copy": "off", 
                "tx_scatter_gather": "on", 
                "tx_scatter_gather_fraglist": "off [fixed]", 
                "tx_sctp_segmentation": "off [fixed]", 
                "tx_sit_segmentation": "off [fixed]", 
                "tx_tcp6_segmentation": "on", 
                "tx_tcp_ecn_segmentation": "on", 
                "tx_tcp_mangleid_segmentation": "off", 
                "tx_tcp_segmentation": "on", 
                "tx_udp_tnl_csum_segmentation": "off [fixed]", 
                "tx_udp_tnl_segmentation": "off [fixed]", 
                "tx_vlan_offload": "off [fixed]", 
                "tx_vlan_stag_hw_insert": "off [fixed]", 
                "udp_fragmentation_offload": "on", 
                "vlan_challenged": "off [fixed]"
            }, 
            "hw_timestamp_filters": [], 
            "ipv4": {
                "address": "192.168.0.91", 
                "broadcast": "192.168.0.255", 
                "netmask": "255.255.255.0", 
                "network": "192.168.0.0"
            }, 
            "macaddress": "00:16:3e:30:d9:a4", 
            "module": "virtio_net", 
            "mtu": 1500, 
            "pciid": "virtio2", 
            "promisc": false, 
            "timestamping": [
                "rx_software", 
                "software"
            ], 
            "type": "ether"
        }, 
        "ansible_eth1": {
            "active": true, 
            "device": "eth1", 
            "features": {
                "busy_poll": "off [fixed]", 
                "fcoe_mtu": "off [fixed]", 
                "generic_receive_offload": "on", 
                "generic_segmentation_offload": "on", 
                "highdma": "on [fixed]", 
                "hw_tc_offload": "off [fixed]", 
                "l2_fwd_offload": "off [fixed]", 
                "large_receive_offload": "off [fixed]", 
                "loopback": "off [fixed]", 
                "netns_local": "off [fixed]", 
                "ntuple_filters": "off [fixed]", 
                "receive_hashing": "off [fixed]", 
                "rx_all": "off [fixed]", 
                "rx_checksumming": "on [fixed]", 
                "rx_fcs": "off [fixed]", 
                "rx_gro_hw": "off [fixed]", 
                "rx_udp_tunnel_port_offload": "off [fixed]", 
                "rx_vlan_filter": "off [fixed]", 
                "rx_vlan_offload": "off [fixed]", 
                "rx_vlan_stag_filter": "off [fixed]", 
                "rx_vlan_stag_hw_parse": "off [fixed]", 
                "scatter_gather": "on", 
                "tcp_segmentation_offload": "on", 
                "tx_checksum_fcoe_crc": "off [fixed]", 
                "tx_checksum_ip_generic": "on", 
                "tx_checksum_ipv4": "off [fixed]", 
                "tx_checksum_ipv6": "off [fixed]", 
                "tx_checksum_sctp": "off [fixed]", 
                "tx_checksumming": "on", 
                "tx_fcoe_segmentation": "off [fixed]", 
                "tx_gre_csum_segmentation": "off [fixed]", 
                "tx_gre_segmentation": "off [fixed]", 
                "tx_gso_partial": "off [fixed]", 
                "tx_gso_robust": "off [fixed]", 
                "tx_ipip_segmentation": "off [fixed]", 
                "tx_lockless": "off [fixed]", 
                "tx_nocache_copy": "off", 
                "tx_scatter_gather": "on", 
                "tx_scatter_gather_fraglist": "off [fixed]", 
                "tx_sctp_segmentation": "off [fixed]", 
                "tx_sit_segmentation": "off [fixed]", 
                "tx_tcp6_segmentation": "on", 
                "tx_tcp_ecn_segmentation": "on", 
                "tx_tcp_mangleid_segmentation": "off", 
                "tx_tcp_segmentation": "on", 
                "tx_udp_tnl_csum_segmentation": "off [fixed]", 
                "tx_udp_tnl_segmentation": "off [fixed]", 
                "tx_vlan_offload": "off [fixed]", 
                "tx_vlan_stag_hw_insert": "off [fixed]", 
                "udp_fragmentation_offload": "on", 
                "vlan_challenged": "off [fixed]"
            }, 
            "hw_timestamp_filters": [], 
            "ipv4": {
                "address": "192.168.1.91", 
                "broadcast": "192.168.1.255", 
                "netmask": "255.255.255.0", 
                "network": "192.168.1.0"
            }, 
            "macaddress": "00:16:3e:2c:a2:c2", 
            "module": "virtio_net", 
            "mtu": 1500, 
            "pciid": "virtio4", 
            "promisc": false, 
            "timestamping": [
                "rx_software", 
                "software"
            ], 
            "type": "ether"
        }, 
        "ansible_fibre_channel_wwn": [], 
        "ansible_fips": false, 
        "ansible_form_factor": "Other", 
        "ansible_fqdn": "jtdb001", 
        "ansible_hostname": "jtdb001", 
        "ansible_hostnqn": "", 
        "ansible_interfaces": [
            "lo", 
            "docker0", 
            "eth1", 
            "eth0"
        ], 
        "ansible_is_chroot": false, 
        "ansible_iscsi_iqn": "", 
        "ansible_kernel": "3.10.0-957.21.3.el7.x86_64", 
        "ansible_kernel_version": "#1 SMP Tue Jun 18 16:35:19 UTC 2019", 
        "ansible_lo": {
            "active": true, 
            "device": "lo", 
            "features": {
                "busy_poll": "off [fixed]", 
                "fcoe_mtu": "off [fixed]", 
                "generic_receive_offload": "on", 
                "generic_segmentation_offload": "on", 
                "highdma": "on [fixed]", 
                "hw_tc_offload": "off [fixed]", 
                "l2_fwd_offload": "off [fixed]", 
                "large_receive_offload": "off [fixed]", 
                "loopback": "on [fixed]", 
                "netns_local": "on [fixed]", 
                "ntuple_filters": "off [fixed]", 
                "receive_hashing": "off [fixed]", 
                "rx_all": "off [fixed]", 
                "rx_checksumming": "on [fixed]", 
                "rx_fcs": "off [fixed]", 
                "rx_gro_hw": "off [fixed]", 
                "rx_udp_tunnel_port_offload": "off [fixed]", 
                "rx_vlan_filter": "off [fixed]", 
                "rx_vlan_offload": "off [fixed]", 
                "rx_vlan_stag_filter": "off [fixed]", 
                "rx_vlan_stag_hw_parse": "off [fixed]", 
                "scatter_gather": "on", 
                "tcp_segmentation_offload": "on", 
                "tx_checksum_fcoe_crc": "off [fixed]", 
                "tx_checksum_ip_generic": "on [fixed]", 
                "tx_checksum_ipv4": "off [fixed]", 
                "tx_checksum_ipv6": "off [fixed]", 
                "tx_checksum_sctp": "on [fixed]", 
                "tx_checksumming": "on", 
                "tx_fcoe_segmentation": "off [fixed]", 
                "tx_gre_csum_segmentation": "off [fixed]", 
                "tx_gre_segmentation": "off [fixed]", 
                "tx_gso_partial": "off [fixed]", 
                "tx_gso_robust": "off [fixed]", 
                "tx_ipip_segmentation": "off [fixed]", 
                "tx_lockless": "on [fixed]", 
                "tx_nocache_copy": "off [fixed]", 
                "tx_scatter_gather": "on [fixed]", 
                "tx_scatter_gather_fraglist": "on [fixed]", 
                "tx_sctp_segmentation": "on", 
                "tx_sit_segmentation": "off [fixed]", 
                "tx_tcp6_segmentation": "on", 
                "tx_tcp_ecn_segmentation": "on", 
                "tx_tcp_mangleid_segmentation": "on", 
                "tx_tcp_segmentation": "on", 
                "tx_udp_tnl_csum_segmentation": "off [fixed]", 
                "tx_udp_tnl_segmentation": "off [fixed]", 
                "tx_vlan_offload": "off [fixed]", 
                "tx_vlan_stag_hw_insert": "off [fixed]", 
                "udp_fragmentation_offload": "on", 
                "vlan_challenged": "on [fixed]"
            }, 
            "hw_timestamp_filters": [], 
            "ipv4": {
                "address": "127.0.0.1", 
                "broadcast": "host", 
                "netmask": "255.0.0.0", 
                "network": "127.0.0.0"
            }, 
            "mtu": 65536, 
            "promisc": false, 
            "timestamping": [
                "rx_software", 
                "software"
            ], 
            "type": "loopback"
        }, 
        "ansible_local": {}, 
        "ansible_lsb": {}, 
        "ansible_machine": "x86_64", 
        "ansible_machine_id": "20190711105006363114529432776998", 
        "ansible_memfree_mb": 33368, 
        "ansible_memory_mb": {
            "nocache": {
                "free": 41285, 
                "used": 6079
            }, 
            "real": {
                "free": 33368, 
                "total": 47364, 
                "used": 13996
            }, 
            "swap": {
                "cached": 0, 
                "free": 0, 
                "total": 0, 
                "used": 0
            }
        }, 
        "ansible_memtotal_mb": 47364, 
        "ansible_mounts": [
            {
                "block_available": 0, 
                "block_size": 2048, 
                "block_total": 32174, 
                "block_used": 32174, 
                "device": "/dev/loop2", 
                "fstype": "iso9660", 
                "inode_available": 0, 
                "inode_total": 0, 
                "inode_used": 0, 
                "mount": "/mnt/yum", 
                "options": "ro,relatime", 
                "size_available": 0, 
                "size_total": 65892352, 
                "uuid": "2020-07-13-09-57-36-00"
            }, 
            {
                "block_available": 0, 
                "block_size": 2048, 
                "block_total": 81981, 
                "block_used": 81981, 
                "device": "/dev/loop0", 
                "fstype": "iso9660", 
                "inode_available": 0, 
                "inode_total": 0, 
                "inode_used": 0, 
                "mount": "/mnt/iso", 
                "options": "ro,relatime", 
                "size_available": 0, 
                "size_total": 167897088, 
                "uuid": "2020-07-12-14-26-47-00"
            }, 
            {
                "block_available": 0, 
                "block_size": 2048, 
                "block_total": 89793, 
                "block_used": 89793, 
                "device": "/dev/loop1", 
                "fstype": "iso9660", 
                "inode_available": 0, 
                "inode_total": 0, 
                "inode_used": 0, 
                "mount": "/mnt/drds", 
                "options": "ro,relatime", 
                "size_available": 0, 
                "size_total": 183896064, 
                "uuid": "2020-07-12-20-25-18-00"
            }, 
            {
                "block_available": 96685158, 
                "block_size": 4096, 
                "block_total": 103177963, 
                "block_used": 6492805, 
                "device": "/dev/vda1", 
                "fstype": "ext4", 
                "inode_available": 26110896, 
                "inode_total": 26214400, 
                "inode_used": 103504, 
                "mount": "/", 
                "options": "rw,relatime,data=ordered", 
                "size_available": 396022407168, 
                "size_total": 422616936448, 
                "uuid": "1114fe9e-2309-4580-b183-d778e6d97397"
            }
        ], 
        "ansible_nodename": "jtdb001", 
        "ansible_os_family": "RedHat", 
        "ansible_pkg_mgr": "yum", 
        "ansible_proc_cmdline": {
            "BOOT_IMAGE": "/boot/vmlinuz-3.10.0-957.21.3.el7.x86_64", 
            "LANG": "en_US.UTF-8", 
            "biosdevname": "0", 
            "console": [
                "tty0", 
                "ttyS0,115200n8"
            ], 
            "crashkernel": "auto", 
            "idle": "halt", 
            "net.ifnames": "0", 
            "noibrs": true, 
            "quiet": true, 
            "rhgb": true, 
            "ro": true, 
            "root": "UUID=1114fe9e-2309-4580-b183-d778e6d97397"
        }, 
        "ansible_processor": [
            "0", 
            "GenuineIntel", 
            "Intel(R) Xeon(R) Platinum 8269CY CPU @ 2.50GHz", 
            "1", 
            "GenuineIntel", 
            "Intel(R) Xeon(R) Platinum 8269CY CPU @ 2.50GHz", 
            "2", 
            "GenuineIntel", 
            "Intel(R) Xeon(R) Platinum 8269CY CPU @ 2.50GHz", 
            "3", 
            "GenuineIntel", 
            "Intel(R) Xeon(R) Platinum 8269CY CPU @ 2.50GHz", 
            "4", 
            "GenuineIntel", 
            "Intel(R) Xeon(R) Platinum 8269CY CPU @ 2.50GHz", 
            "5", 
            "GenuineIntel", 
            "Intel(R) Xeon(R) Platinum 8269CY CPU @ 2.50GHz", 
            "6", 
            "GenuineIntel", 
            "Intel(R) Xeon(R) Platinum 8269CY CPU @ 2.50GHz", 
            "7", 
            "GenuineIntel", 
            "Intel(R) Xeon(R) Platinum 8269CY CPU @ 2.50GHz", 
            "8", 
            "GenuineIntel", 
            "Intel(R) Xeon(R) Platinum 8269CY CPU @ 2.50GHz", 
            "9", 
            "GenuineIntel", 
            "Intel(R) Xeon(R) Platinum 8269CY CPU @ 2.50GHz", 
            "10", 
            "GenuineIntel", 
            "Intel(R) Xeon(R) Platinum 8269CY CPU @ 2.50GHz", 
            "11", 
            "GenuineIntel", 
            "Intel(R) Xeon(R) Platinum 8269CY CPU @ 2.50GHz"
        ], 
        "ansible_processor_cores": 6, 
        "ansible_processor_count": 1, 
        "ansible_processor_threads_per_core": 2, 
        "ansible_processor_vcpus": 12, 
        "ansible_product_name": "Alibaba Cloud ECS", 
        "ansible_product_serial": "NA", 
        "ansible_product_uuid": "NA", 
        "ansible_product_version": "pc-i440fx-2.1", 
        "ansible_python": {
            "executable": "/usr/bin/python", 
            "has_sslcontext": true, 
            "type": "CPython", 
            "version": {
                "major": 2, 
                "micro": 5, 
                "minor": 7, 
                "releaselevel": "final", 
                "serial": 0
            }, 
            "version_info": [
                2, 
                7, 
                5, 
                "final", 
                0
            ]
        }, 
        "ansible_python_version": "2.7.5", 
        "ansible_real_group_id": 1000, 
        "ansible_real_user_id": 1000, 
        "ansible_selinux": {
            "status": "disabled"
        }, 
        "ansible_selinux_python_present": true, 
        "ansible_service_mgr": "systemd", 
        "ansible_ssh_host_key_dsa_public": "AAAAB3NzaC1kc3MAAACBAIjMSdXjIBwLTRwqzzLzJzw52IikcmHpmM65Idw9Q/CCH23SJdmmYzl9LIWFTEf2ZP4dHYibvgWtqfc6AHLFVgM1lz3wwdJJSyBD1TyFet+MPZEA1A9jw2Ke2K9C942dWATCpi3B0nk0KJDp49+V0QjUUjZmzt7I66wDmPLpW7mNAAAAFQDXmbLv48zsFHUgPiixhcKsk29ZPQAAAIAHHM+jfcL3V/X6EovQGj/2OytDN7k5hb4KRNTzBwh9JU5V44+S3r5ZViJDthKBolVT1CLX8jAivBu6d70ImYcZLa75AImOnlSp9D4xGP4TNfdAYrA7CkYpzn8ky15xjFDjkL0BjVmeEg6In+04tZOp/kIi/Ft9/ld63W4xopspwwAAAIAhBCIAMW37rknrsmv3sXmhgt+FeUQA/o8moZKcX+xI5sv27NEavQGGKOvZM4+nhCggRvjWaxC9N1DnO2g52trhGrUhNF0qwn/4iar/yknZWwRyZXzB3YtOdJXxCoJphuuGeqJRsLPb7OEIAF7c3lFJcfMUrwcjWrRtFMUM6mE+gQ==", 
        "ansible_ssh_host_key_ecdsa_public": "AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBMffg6EX26f+10IIgg/U7+PsCUDs8Ep0MUttUyVh3+bJ7/K7ROMhuc8BTieA4PRj3MOaKMbUuZTqPTmrK/4srqg=", 
        "ansible_ssh_host_key_ed25519_public": "AAAAC3NzaC1lZDI1NTE5AAAAINIKYkm+FKDTvx6VgENoAnXwOJQ+xZjk3rkvUqZ/4F3i", 
        "ansible_ssh_host_key_rsa_public": "AAAAB3NzaC1yc2EAAAADAQABAAABAQC1xlLrDTri/jRfph6Uqx6CoY1/+uAE34rR9sR4FtE+2OMM8kUN0+N+hWLL+8r/pzM40RJOUmELYTlibfnjkYDsmYcpxD8kOxonvlYQbpvram8Hx7X8W1thYs//Zdhltmz1ijTiEatCL/yxJnwrpxN1XOtbMtALKgykbOzF+LNevFUG05MxxQR5WVjijXwK/Auf0ce/ei3NISQZLiW+d+IVYPkAQDpbUpH5W/qGDN0W8wT2OGE0bOvrPfDPRhSxeYrcS4mgS7nGvB26sFyeAimgadnxmWaxAveargYKt33jJQhVaA/23kw+/lygQcSN1QJ2mpeHb3ugay0Gv1i/Wd7P", 
        "ansible_swapfree_mb": 0, 
        "ansible_swaptotal_mb": 0, 
        "ansible_system": "Linux", 
        "ansible_system_capabilities": [
            ""
        ], 
        "ansible_system_capabilities_enforced": "True", 
        "ansible_system_vendor": "Alibaba Cloud", 
        "ansible_uptime_seconds": 11384976, 
        "ansible_user_dir": "/home/admin", 
        "ansible_user_gecos": "", 
        "ansible_user_gid": 1000, 
        "ansible_user_id": "admin", 
        "ansible_user_shell": "/bin/bash", 
        "ansible_user_uid": 1000, 
        "ansible_userspace_architecture": "x86_64", 
        "ansible_userspace_bits": "64", 
        "ansible_virtualization_role": "guest", 
        "ansible_virtualization_type": "kvm", 
        "discovered_interpreter_python": "/usr/bin/python", 
        "gather_subset": [
            "all"
        ], 
        "module_setup": true
    }, 
    "changed": false
}
```

## ansible + xargs 占位符

```
//批量执行docker exec
ansible -i host.ini all -m shell -a "docker ps -a | grep pxd-tpcc | grep dn | cut -d ' ' -f 1 | xargs  -I{} docker exec {} bash -c \"myc -e 'shutdown'\""
```



## 指定ip执行playbook

> ansible-playbook  -i "10.168.101.179," all test.yml

或者：

> ansible -i phy.ini 11.167.60.150 -m shell -a 'docker run -it -d --net=host -e diamond_server_list="{{ diamond_server_list }}" -e diamond_db0="{{ diamond_db0 }}" -e diamond_db1="{{ diamond_db1 }}" -e diamond_db2="{{ diamond_db2 }}" -e HOST_IP="{{ inventory_hostname }}" -p 8080:8080 -p 9090:9090 --name diamond {{ images }} ' -vvv

上面这种还能重用phy.ini中所有的变量配置


## 创建用户并打通账号

```
$cat create_user.yml
# create user ren with passwd test and sudo privileges.
# ansible-playbook -i docker.ini create_user.yml
- hosts: all
  user: root
  vars:
    # created with:
    # python -c 'import crypt; print crypt.crypt("password", "$1$SomeSalt$")'
    password: $1$SomeSalt$OrX9ouxOCP0ZOpVG9SwnR/

  tasks:
    - name: create a new user
      user:
       name: '{{ user }}'
       password: '{{ password }}'
       home: /home/{{ user }}
       state: present
       shell: /bin/bash

    - name: Add user to the sudoers
      copy:
          dest: "/etc/sudoers.d/{{ user }}"
          content: "{{ user }}  ALL=(ALL)  NOPASSWD: ALL"

    - name: Deploy SSH Key
      authorized_key: user={{ user }}
           key="{{ lookup('file', '/root/.ssh/id_rsa.pub') }}"
           state=present

```

然后执行： ansible-playbook -i  all.ini create_user.yml -e "user=admin" 。

或者：

```
 ansible -i 192.168.2.101, all -m user -a "name=user02 system=yes uid=503 group=root groups=root shell=/etc/nologin home=/home/user02 password=pwd@123"
 192.168.2.101 | CHANGED => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    }, 
    "changed": true, 
    "comment": "", 
    "create_home": true, 
    "group": 0, 
    "groups": "root", 
    "home": "/home/user02", 
    "name": "user02", 
    "password": "NOT_LOGGING_PASSWORD", 
    "shell": "/etc/nologin", 
    "state": "present", 
    "system": true, 
    "uid": 503
}
```

playbook task规范：

![image.png](/images/oss/d502a11765273304abd673fb358b482a.png)

**对齐的时候不能用tab和空格混合**

## 部署docker daemon的playbook

执行 ansible-playbook site.yml -v  -i test.ini -u xijun.rxj -e "project=docker" -p

```
$cat roles/docker/tasks/main.yml 
# filename: main.yml
---
#"****************************************************************************""
- name: copy docker execute file to remote
  copy: src=docker/ dest=/usr/bin/ mode=0755 force=yes
  tags: copytar

- name: create storage dir
  file: path={{ storage_dir }} state=directory
  ignore_errors: true
  tags: docker

- name: create the dir
  file: path=/etc/systemd/system/ state=directory
  ignore_errors: true
  tags: docker

- name: template docker.service to server
  template: src=docker.service dest=/etc/systemd/system/docker.service
  tags: docker

- name: template docker.socket to server
  template: src=docker.socket dest=/usr/lib/systemd/system/docker.socket
  tags: docker

- name: create /etc/docker dir to server
  file: path=/etc/docker state=directory
  ignore_errors: true
  tags: docker

- name: copy daemon.json to server
  template: src={{ inventory_hostname }}/daemon.json dest=/etc/docker/daemon.json
  ignore_errors: true
  tags: docker

- name: copy the load ovs modules to server
  copy: src=openvswitch.modules dest=/etc/sysconfig/modules/openvswitch.modules mode=0755  force=yes
  tags: docker

- name: kill docker daemon
  shell: "kill -9 $(cat /var/run/docker.pid)"
  ignore_errors: true
  tags: test

- name: reload systemctl daemon-reload
  shell: "systemctl daemon-reload"
  tags: docker

- name: enabled the docker service
  shell: "systemctl enable docker.service"
  ignore_errors: true
  tags: docker

- name: start docker service
  shell: "systemctl start docker.service"

- name: remove all containers
  shell: sudo docker ps -a | awk '{print $1}' | xargs sudo docker rm -f -v
  ignore_errors: true

- name: template /etc/hosts to server
  template: src=hosts dest=/etc/hosts owner=root group=root mode=0644 force=yes
  tags: restorehosts

- name: mkdir /tmp/etc/
  shell: "mkdir /tmp/etc/ "
  ignore_errors: true
  tags: hosts

- name: copy remote /etc/hosts to /tmp
  shell: "cp /etc/hosts /tmp/etc/ "
  tags: hosts

- name: copy /etc/hosts to server
  template: src=etc.host dest=/tmp/etc/ owner={{ remote_user }} group={{ remote_user }} mode=0700 force=yes
  tags: hosts

- name: merge /etc/hosts
  assemble: src=/tmp/etc dest=/etc/hosts owner=root group=root mode=0644 force=yes
  tags: hosts

- name: copy docker_rc.sh to server
  template: src=docker_rc.sh dest={{ docker_rc_dir }}/docker_rc.sh owner=root group=root mode=0755 force=yes
  when: use_vxlan!="true"
  tags: docker_rc

- name: copy docker_rc.sh to server
  template: src=docker_rc_vm.sh dest={{ docker_rc_dir }}/docker_rc.sh owner=root group=root mode=0755 force=yes
  when: use_vxlan=="true"
  tags: docker_rc

- name: clean docker_rc in rc.local
  command: su - root -c " sed -i '/docker_rc.sh/d' /etc/rc.d/rc.local "
  ignore_errors: true
  sudo: yes
  tags: docker_rc

- name: start the docker when the system reboot
  command: su - root -c " echo 'su - root -c \"{{ docker_rc_dir }}/docker_rc.sh\" ' >> /etc/rc.d/rc.local "
  ignore_errors: true
  sudo: yes
  tags: docker_rc

- name: chown the /etc/rc.d/rc.local
  shell: "chmod +x /etc/rc.d/rc.local "
  ignore_errors: true
  sudo: yes
  tags: docker_rc

- name: clean previous space occupier
  file: path={{ storage_dir }}/ark.disk{{ item }}.tmp state=absent
  with_items:
    - 1
    - 2
  ignore_errors: true
  tags: docker

- name: Occupy space for docker
  shell: "dd if=/dev/zero of={{ storage_dir }}/ark.disk{{ item }}.tmp bs=1M count=1024"
  sudo: yes
  with_items:
    - 1
    - 2
  tags: docker

```

## 部署zk

```
$cat roles/zookeeper/tasks/main.yml
# filename: main.yml
---
#"****************************************************************************""
- name: extract zookeeper tgz
  unarchive: src={{ packages_dir }}/lib/{{ zk_package_name }} dest=/opt
  sudo: yes

- name: create zk data and log dir
  file: path={{ zk_data_dir }} state=directory mode=0755
  with_items:
    - "{{ zk_data_dir }}"
    - "{{ zk_logs_dir }}"

- name: set the myid
  template: src=myid dest={{ zk_myid_file }}  mode=0644

- name: template zoo.cfg
  template: src=zoo.cfg dest={{ zk_install_dir }}/conf/ mode=0644

- name: copy log4j to remote
  template: src=log4j.properties dest={{ zk_install_dir }}/conf/log4j.properties

- name: determine zk process
  command: su - root -c "ps aux | grep java | grep -v grep | grep {{ zk_install_dir }}"
  register: result
  ignore_errors: true

- name: stop zk server
  command: su - root -c "sh {{ zk_install_dir }}/bin/zkServer.sh  stop"
  ignore_errors: true
  when: "result.rc == 0"

- name: start zk server
  command: su - root -c "sh {{ zk_install_dir }}/bin/zkServer.sh start"

- name: get process info
  command: su - root -c "ps aux | grep java | grep -v grep | grep {{ zk_install_dir }}"
  register: result

- name: clean zk service when the system reboot
  command: su - root -c " sed -i '/{{ zk_dir_name }}/d' /etc/rc.d/rc.local "
  ignore_errors: true
  sudo: yes

- name: start the zk service when the system reboot
  command: su - root -c " echo 'su - root -c \"{{ zk_install_dir }}/bin/zkServer.sh start\" ' >> /etc/rc.d/rc.local "
  ignore_errors: true
  sudo: yes

- name: start the zk service when the system reboot
  shell: "chmod +x /etc/rc.d/rc.local "
  ignore_errors: true
  sudo: yes

```

## 参考资料

[How to Copy Files and Directories in Ansible Using Copy and Fetch Modules](https://www.mydailytutorials.com/how-to-copy-files-and-directories-in-ansible-using-copy-and-fetch-modules/)