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
ip addr add dev docker0 172.30.0.0/16
```

启动成功后即使手工删除docker0，然后再次启动也会成功，这次会自动创建docker0 172.30.0.0/16 。

参考：https://github.com/docker/for-linux/issues/123  

或者这样解决：https://stackoverflow.com/questions/39617387/docker-daemon-cant-initialize-network-controller

This was related to the machine having several network cards (can also happen in machines with VPN)

To me, the solution was to start manually docker like this:

```
/usr/bin/docker daemon --debug --bip=192.168.y.x/24
```

where the 192.168.y.x is the MAIN machine IP and /24 that ip netmask. Docker will use this network range for building the bridge and firewall riles. The --debug is not really needed, but might help if something else fails.

After starting once, you can kill the docker and start as usual. AFAIK, docker have created a cache config for that --bip and should work now without it. Of course, if you clean the docker cache, you may need to do this again. 

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
docker run -itd --privileged --name=ren drds_base:centos init //init 必须要
```

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

## 网络方案性能

|         | **OS** | **Host** | **Docker_Host** | **Docker_NAT_IPTABLES** | **Docker_NAT_PROXY** | **Docker_BRIDGE_VLAN** | **Docker_OVS_VLAN** | **Docker_HAVS_VLAN** |
| ------- | ------ | -------- | --------------- | ----------------------- | -------------------- | ---------------------- | ------------------- | -------------------- |
| **TPS** | 6U     | 118727.5 | 115962.5        | 83281.08                | 29104.33             | 57327.15               | 55606.37            | 54686.88             |
| **TPS** | 7U     | 117501.4 | 110010.7        | 101131.2                | 34795.39             | 108857.7               | 107554.3            | 105021               |
|         | 6U     | BASE     | -2.38%          | -42.56%                 | -307.94%             | -107.11%               | -113.51%            | -117.10%             |
|         | 7U     | BASE     | -6.81%          | -16.19%                 | -237.69%             | -7.94%                 | -9.25%              | -11.88%              |
| **RT**  | 6U(ms) | 0.330633 | 0.362042        | 0.505125                | 1.423767             | 0.799308               | 0.763842            | 0.840458             |
| **RT**  | 7U(ms) | 0.3028   | 0.321267        | 0.346325                | 1.183225             | 0.325333               | 0.335708            | 0.33535              |
|         | 6U(us) | BASE     | 31.40833        | 174.4917                | 1093.133             | 468.675                | 433.2083            | 509.825              |
|         | 7U(us) | BASE     | 18.46667        | 43.525                  | 880.425              | 22.53333               | 32.90833            | 32.55                |

-  Host：是指没有隔离的情况下，D13物理机；
- Docker_Host：是指Docker采用Host网络模式;
- Docker_NAT_IPTABLES：是指Docker采用NAT网络模式，通过IPTABLES进行网络转发。
- Docker_NAT_PROXY：是指Docker采用NAT网络模式，通过docker-proxy进行网络转发。
- Docker_BRIDGE：是指Docker采用Bridge网络模式，并且配置静态IP和VLAN701，这里使用VLAN。
- Docker_OVS_VLAN：是指Docker采用VSwitch网络模式，通过OpenVSwitch进行网络通信，使用ACS VLAN Driver。
- Docker_HAVS_VLAN：是指Docker采用VSwitch网络模式，通过HAVS进行网络通信，使用VLAN。

### 通过测试，汇总测试结论如下

1. Docker_Host网络模式在6U和7U环境下，性能比物理机方案上性能降低了2~6%左右，RT增加了18~30us左右。

2. Docker_NAT_IPTABLES网络模式在6U环境下，性能比物理机方案上性能降低了43%左右，RT增加了174us；在7U环境下，性能比物理机方案上性能降低了16%左右，RT增加了44us；此外，可以明显看出，7U环境比6U环境性能上优化了20%，RT上减少了130us左右。

3. Docker_NAT_PROXY网络模式在6U环境下，性能比物理机方案性能降低了300%，RT增加了1ms以上；在7U环境下，性能比物理机方案性能降低了237%，RT增加了880us以上；此外，可以明显看出，7U环境比6U环境性能上优化了20%，RT上减少了200us左右。

4. Docker_BRIDGE_VLAN网络模式在6U环境下，性能比物理机方案性能降低了107%，RT增加了469us；在7U环境下，性能比物理机方案性能降低了8%左右，RT增加了23us左右；此外，可以明显看出，7U环境比6U环境性能上优化了90%，RT上减少了446us。从诊断上来看，6U和7U的性能差异主要在VLAN的处理上的spin_lock，详细可以参考之前的测试验证。

5. Docker_OVS_VLAN网络模式在6U环境下，性能比物理机方案性能降低了114%，RT增加了433us；在7U环境下，性能比物理机方案性能降低了9%左右，RT增加了33us；此外，可以明显看出，7U环境比6U环境性能上优化了93%，RT上减少了400us。从诊断上来看，6U和7U的性能差异主要在VLAN的处理上的spin_lock。并且发现，OVS与Bridge网络模式性能上基本持平，无较大性能上的差异。

6. Docker_HAVS_VLAN网络模式在6U环境下，性能比物理机方案性能降低了117%，RT增加了510us；在7U环境下，性能比物理机方案性能降低了12%左右，RT增加了33us；此外，可以明显看出，7U环境比6U环境性能上优化了92%，RT上减少了477us。从诊断上来看，6U和7U的性能差异主要在VLAN的处理上的spin_lock。并且发现，HAVS与Bridge网络模式性能上基本持平，无较大性能上的差异；HAVS与OVS的性能上差异也较小，无较大性能上的差异。

7. SR-IOV网络模式由于存在OS、Docker、网卡等要求，非通用化方案，将作为进一步的优化方案进行探索。

### 网络性能结果分析（rama等同方舟vlan网络方案）

延迟数据汇总：

|       | host  | rama不开启mac nat | rama开启mac nat | calico-bgp | flannel-vxlan |
| ----- | ----- | ----------------- | --------------- | ---------- | ------------- |
| 64    | 0.041 | 0.041             | 0.041           | 0.042      | 0.041         |
| 512   | 0.041 | 0.041             | 0.043           | 0.041      | 0.043         |
| 1024  | 0.045 | 0.045             | 0.045           | 0.046      | 0.048         |
| 2048  | 0.073 | 0.072             | 0.072           | 0.073      | 0.073         |
| 4096  | 0.072 | 0.070             | 0.073           | 0.071      | 0.079         |
| 16384 | 0.148 | 0.144             | 0.149           | 0.242      | 0.200         |
| 32678 | 0.244 | 0.335             | 0.242           | 0.320      | 0.352         |
| 64512 | 0.300 | 0.481             | 0.419           | 0.437      | 0.541         |

![image.png](https://cdn.nlark.com/yuque/0/2020/png/162611/1589164443676-cc7b2394-67e1-4550-b34d-d489c34ad026.png)



吞吐量数据汇总：

|       | host | rama不开启mac nat | rama开启mac nat | calico-bgp | flannel-vxlan |
| ----- | ---- | ----------------- | --------------- | ---------- | ------------- |
| 64    | 386  | 381               | 381             | 377        | 359           |
| 512   | 2660 | 2370              | 2530            | 2580       | 1840          |
| 1024  | 5170 | 4590              | 4880            | 4510       | 2610          |
| 2048  | 7710 | 7350              | 7040            | 7420       | 3310          |
| 4096  | 9410 | 8750              | 8220            | 8440       | 3830          |
| 16384 | 9410 | 8850              | 8460            | 8580       | 5080          |
| 32678 | 9410 | 8810              | 8580            | 8550       | 4950          |
| 65507 | 9410 | 8660              | 8410            | 8540       | 4920          |

![image.png](https://cdn.nlark.com/yuque/0/2020/png/162611/1589164443610-d5bb45a6-f688-4a6b-b697-8370387f4dd8.png)

从延迟上来看，rama与calico-bgp相差不大，从数据上略低于host性能，略高于flannel-vxlan；从吞吐量上看，区别会明显一些，当报文长度大于4096 KB 时，均观察到各网络插件的吞吐量达到最大值，从最大值上来看可以初步得出以下结论：

**host > rama不开启mac nat >** **rama开启mac nat** ≈ **calico-bgp >** **flannel-vxlan**

rama不开启mac nat时性能最高，开启mac nat功能，性能与calico-bgp基本相同，并且性能大幅度高于flannel-vxlan；虽然rama开启mac nat之后的性能与每个节点上的pod数量直接相关，但由于测试 rama开启mac nat方案 的时候，取的是两个个节点上50个pod中预计性能最差的pod，基本可以反映一般情况

## 参考资料

https://www.ardanlabs.com/blog/2020/02/docker-images-part1-reducing-image-size.html