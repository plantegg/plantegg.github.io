---
title: 如何手动为docker daemon添加label
date: 2017-03-24 17:30:03
categories: docker
tags:
    - Linux
    - docker
---

# 如何手动为docker daemon添加label

1. 编辑或创建/etc/docker/daemon.json

2. 将一个或多个lable以json格式写入文件，示例如下

  ```json
  # 为docker分配两个label，分别是nodetype和red
  {"labels":["nodetype=dbpaas", "color=red"]}
  ```

3. 重启docker daemon
  ```shell
  service docker restart
  ```

4 /etc/docker/daemon.json 参考

```
{
    "api-cors-header": "",
    "authorization-plugins": [],
    "bip": "",
    "bridge": "",
    "cgroup-parent": "",
    "cluster-store": "",
    "cluster-store-opts": {},
    "cluster-advertise": "",
    "debug": true,
    "default-gateway": "",
    "default-gateway-v6": "",
    "default-runtime": "runc",
    "default-ulimits": {},
    "disable-legacy-registry": false,
    "dns": [],
    "dns-opts": [],
    "dns-search": [],
    "exec-opts": [],
    "exec-root": "",
    "fixed-cidr": "",
    "fixed-cidr-v6": "",
    "graph": "",
    "group": "",
    "hosts": [],
    "icc": false,
    "insecure-registries": [],
    "ip": "0.0.0.0",
    "iptables": false,
    "ipv6": false,
    "ip-forward": false,
    "ip-masq": false,
    "labels": ["nodetype=drds-server", "ark.ip=11.239.155.83"],
    "live-restore": true,
    "log-driver": "",
    "log-level": "",
    "log-opts": {},
    "max-concurrent-downloads": 3,
    "max-concurrent-uploads": 5,
    "mtu": 0,
    "oom-score-adjust": -500,
    "pidfile": "",
    "raw-logs": false,
    "registry-mirrors": [],
    "runtimes": {
        "runc": {
            "path": "runc"
        },
        "custom": {
            "path": "/usr/local/bin/my-runc-replacement",
            "runtimeArgs": [
                "--debug"
            ]
        }
    },
    "selinux-enabled": false,
    "storage-driver": "",
    "storage-opts": [],
    "swarm-default-advertise-addr": "",
    "tls": true,
    "tlscacert": "",
    "tlscert": "",
    "tlskey": "",
    "tlsverify": true,
    "userland-proxy": false,
    "userns-remap": ""
}

```