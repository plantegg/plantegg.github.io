---
title: Docker 常见问题
date: 2018-02-25 17:30:03
categories:
    - docker
tags:
    - Linux
    - docker
---

# Docker 常见问题

## 启动

docker daemon启动的时候如果报 socket错误，是因为daemon启动参数配置了： -H fd://  ，但是 docker.socket是disable状态，启动daemon依赖socket，但是systemctl又拉不起来docker.socket，因为被disable了，先  sudo systemctl enable docker.socket 就可以了。

如果docker.socket service被mask后比disable更粗暴，mask后手工都不能拉起来了，但是disable后还可以手工拉起，然后再拉起docker service。 这是需要先 systemctl unmask 

```
$sudo systemctl restart docker.socket
Failed to restart docker.socket: Unit docker.socket is masked.
```

另外 docker.socket 启动依赖环境的要有 docker group这个组，可以添加： groupadd docker

## failed to start docker.service unit not found. rhel 7.7

systemctl list-unit-files |grep docker.service 可以看到docker.service 是存在并enable了

实际是redhat 7.7的yum仓库所带的docker启动参数变了， 如果手工启动的话也会报找不到docker-runc 手工:

> ```
> ln -s /usr/libexec/docker/docker-runc-current /usr/bin/docker-runc
> ```

https://access.redhat.com/solutions/2876431  https://stackoverflow.com/questions/42754779/docker-runc-not-installed-on-system

yum安装docker会在 /etc/sysconfig 下放一些配置参数(docker.service 环境变量)

### [Docker 启动报错： Error starting daemon： Error initializing network controller： list bridge addresses failed： no available network](http://blog.joylau.cn/2019/04/08/Docker-Start-Error/)

这是因为daemon启动的时候缺少docker0网桥，导致启动失败，手工添加：  

```
ip link add docker0 type bridge
ip addr add dev docker0 172.30.0.0/24
```

启动成功后即使手工删除docker0，然后再次启动也会成功，这次会自动创建docker0 172.30.0.0/16 。

```
#systemctl status docker -l
● docker.service - Docker Application Container Engine
   Loaded: loaded (/etc/systemd/system/docker.service; enabled; vendor preset: disabled)
   Active: failed (Result: exit-code) since Fri 2021-01-22 17:21:45 CST; 2min 12s ago
     Docs: http://docs.docker.io
  Process: 68318 ExecStartPost=/sbin/iptables -I FORWARD -s 0.0.0.0/0 -j ACCEPT (code=exited, status=0/SUCCESS)
  Process: 68317 ExecStart=/opt/kube/bin/dockerd (code=exited, status=1/FAILURE)
 Main PID: 68317 (code=exited, status=1/FAILURE)

Jan 22 17:21:43 l57f12112.sqa.nu8 dockerd[68317]: time="2021-01-22T17:21:43.991179104+08:00" level=warning msg="failed to load plugin io.containerd.snapshotter.v1.aufs" error="modprobe aufs failed: "modprobe: FATAL: Module aufs not found.\n": exit status 1"
Jan 22 17:21:43 l57f12112.sqa.nu8 dockerd[68317]: time="2021-01-22T17:21:43.991371956+08:00" level=warning msg="could not use snapshotter btrfs in metadata plugin" error="path /var/lib/docker/containerd/daemon/io.containerd.snapshotter.v1.btrfs must be a btrfs filesystem to be used with the btrfs snapshotter"
Jan 22 17:21:43 l57f12112.sqa.nu8 dockerd[68317]: time="2021-01-22T17:21:43.991381620+08:00" level=warning msg="could not use snapshotter aufs in metadata plugin" error="modprobe aufs failed: "modprobe: FATAL: Module aufs not found.\n": exit status 1"
Jan 22 17:21:43 l57f12112.sqa.nu8 dockerd[68317]: time="2021-01-22T17:21:43.991388991+08:00" level=warning msg="could not use snapshotter zfs in metadata plugin" error="path /var/lib/docker/containerd/daemon/io.containerd.snapshotter.v1.zfs must be a zfs filesystem to be used with the zfs snapshotter: skip plugin"
Jan 22 17:21:44 l57f12112.sqa.nu8 systemd[1]: Stopping Docker Application Container Engine...
Jan 22 17:21:45 l57f12112.sqa.nu8 dockerd[68317]: failed to start daemon: Error initializing network controller: list bridge addresses failed: PredefinedLocalScopeDefaultNetworks List: [172.17.0.0/16 172.18.0.0/16 172.19.0.0/16 172.20.0.0/16 172.21.0.0/16 172.22.0.0/16 172.23.0.0/16 172.24.0.0/16 172.25.0.0/16 172.26.0.0/16 172.27.0.0/16 172.28.0.0/16 172.29.0.0/16 172.30.0.0/16 172.31.0.0/16 192.168.0.0/20 192.168.16.0/20 192.168.32.0/20 192.168.48.0/20 192.168.64.0/20 192.168.80.0/20 192.168.96.0/20 192.168.112.0/20 192.168.128.0/20 192.168.144.0/20 192.168.160.0/20 192.168.176.0/20 192.168.192.0/20 192.168.208.0/20 192.168.224.0/20 192.168.240.0/20]: no available network
Jan 22 17:21:45 l57f12112.sqa.nu8 systemd[1]: docker.service: main process exited, code=exited, status=1/FAILURE
Jan 22 17:21:45 l57f12112.sqa.nu8 systemd[1]: Stopped Docker Application Container Engine.
Jan 22 17:21:45 l57f12112.sqa.nu8 systemd[1]: Unit docker.service entered failed state.
Jan 22 17:21:45 l57f12112.sqa.nu8 systemd[1]: docker.service failed.
```

参考：https://github.com/docker/for-linux/issues/123  

或者这样解决：https://stackoverflow.com/questions/39617387/docker-daemon-cant-initialize-network-controller

This was related to the machine having several network cards (can also happen in machines with VPN)

The solution was to start manually docker like this:

```
/usr/bin/docker daemon --debug --bip=192.168.y.x/24
```

where the 192.168.y.x is the MAIN machine IP and /24 that ip netmask. Docker will use this network range for building the bridge and firewall riles. The --debug is not really needed, but might help if something else fails.

After starting once, you can kill the docker and start as usual. AFAIK, docker have created a cache config for that --bip and should work now without it. Of course, if you clean the docker cache, you may need to do this again. 

本机网络信息默认保存在：/var/lib/docker/network/files/local-kv.db  想要清理bridge网络的话，不能直接 docker network rm bridge 因为bridge是预创建的受保护不能直接删除，可以删掉：/var/lib/docker/network/files/local-kv.db 并且同时删掉 docker0 然后重启dockerd就可以了

### alios下容器里面ping不通docker0

alios上跑docker，然后启动容器，发现容器里面ping不通docker0, 手工重新brctl addbr docker0 , 然后把虚拟网卡加进去就可以了。应该是系统哪里bug了. 

![image.png](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/2ba8bc014d93ad4b6e77c889a024772f.png)

非常神奇的是不通的时候如果在宿主机上对docker0抓包就瞬间通了，停掉抓包就不通

![docker0-tcpdump.gif](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/dbc4dac5a9a0289b58952375c5759b15.gif)

猜测是 alios 的bug

## systemctl start docker

Failed to start docker.service: Unit not found.

```
UNIT LOAD PATH
          Unit files are loaded from a set of paths determined during 
          compilation, described in the two tables below. Unit files found 
          in directories listed earlier override files with the same name 
          in directories lower in the list.

           Table 1.  Load path when running in system mode (--system).
           ┌────────────────────────┬─────────────────────────────┐
           │Path                    │ Description                 │
           ├────────────────────────┼─────────────────────────────┤
           │/etc/systemd/system     │ Local configuration         │
           ├────────────────────────┼─────────────────────────────┤
           │/run/systemd/system     │ Runtime units               │
           ├────────────────────────┼─────────────────────────────┤
           │/usr/lib/systemd/system │ Units of installed packages │
           └────────────────────────┴─────────────────────────────┘
```

[systemd 设置path环境变量，可以设置](https://askubuntu.com/questions/1014480/how-do-i-add-bin-to-path-for-a-systemd-service)：

> [Service]
> Type=notify
> Environment=PATH=/opt/kube/bin:/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/usr/X11R6/bin:/opt/satools:/root/bin

## 容器没有systemctl

**Failed to get D-Bus connection: Operation not permitted: systemd容器中默认无法启动，需要启动容器的时候** 

```
docker run -itd --privileged --name=ren drds_base:centos init //init 必须要或者systemd
```

1号进程需要是systemd(init 是systemd的link)，才可以使用systemctl，推荐用这个来解决：https://github.com/gdraheim/docker-systemctl-replacement

systemd是用来取代init的，之前init管理所有进程启动，是串行的，耗时久，也不管最终状态，systemd主要是串行并监控进程状态能反复重启。

**新版本init link向了systemd**

## busybox/Alpine/Scratch

busybox集成了常用的linux工具(nc/telnet/cat……），保持精细，方便一张软盘能装下。

Alpine一个精简版的Linux 发行版，更小更安全，用的musl libc而不是glibc

scratch一个空的框架，什么也没有

## 找不到shell

Dockerfile 中(https://www.ardanlabs.com/blog/2020/02/docker-images-part1-reducing-image-size.html)：

```
CMD ./hello OR RUN 等同于 /bin/sh -c "./hello", 需要shell，
改用：
CMD ["./hello"] 等同于 ./hello 不需要shell
```

dockerfile中：CMD 可以是命令、也可以是参数，如果是参数， 把它传递给：ENTRYPOINT

## 容器调试 -- nsenter

```
获取pid：docker inspect -f {{.State.Pid}} c8f874efea06

进入namespace：nsenter --target 17277 --net --pid –mount
```

nsenter相当于在setns的示例程序之上做了一层封装，使我们无需指定命名空间的文件描述符，而是指定进程号即可

## OS版本

**搞Docker就得上el7， 6的性能太差了** Docker 对 Linux 内核版本的最低要求是3.10，如果内核版本低于 3.10 会缺少一些运行 Docker 容器的功能。这些比较旧的内核，在一定条件下会导致数据丢失和频繁恐慌错误。



## 参考资料

https://www.ardanlabs.com/blog/2020/02/docker-images-part1-reducing-image-size.html