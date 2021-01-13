---
title: 如何制作本地yum repository
date: 2020-01-24 17:30:03
categories:
    - Linux
tags:
    - Linux
    - yum
    - iso
    - createrepo
    - yum-utils
---

# 如何制作本地yum repository

某些情况下在没有外网的环境需要安装一些软件，但是软件依赖比较多，那么可以提前将所有依赖下载到本地，然后将他们制作成一个yum repo，安装的时候就会自动将依赖包都安装好。

## 收集所有rpm包

创建一个文件夹，比如 Yum，将收集到的所有rpm包放在里面，比如安装ansible和docker需要的依赖文件：

```
-rwxr-xr-x 1 root root  73K 7月  12 14:22 audit-libs-python-2.8.4-4.el7.x86_64.rpm
-rwxr-xr-x 1 root root 295K 7月  12 14:22 checkpolicy-2.5-8.el7.x86_64.rpm
-rwxr-xr-x 1 root root  23M 7月  12 14:22 containerd.io-1.2.2-3.el7.x86_64.rpm
-rwxr-xr-x 1 root root  26K 7月  12 14:22 container-selinux-2.9-4.el7.noarch.rpm
-rwxr-xr-x 1 root root  37K 7月  12 14:22 container-selinux-2.74-1.el7.noarch.rpm
-rwxr-xr-x 1 root root  14M 7月  12 14:22 docker-ce-cli-18.09.0-3.el7.x86_64.rpm
-rwxr-xr-x 1 root root  29K 7月  12 14:22 docker-ce-selinux-17.03.2.ce-1.el7.centos.noarch.rpm
-r-xr-xr-x 1 root root  22K 7月  12 14:23 sshpass-1.06-2.el7.x86_64.rpm
-r-xr-xr-x 1 root root  22K 7月  12 14:23 sshpass-1.06-1.el7.x86_64.rpm
-r-xr-xr-x 1 root root 154K 7月  12 14:23 PyYAML-3.10-11.el7.x86_64.rpm
-r-xr-xr-x 1 root root  29K 7月  12 14:23 python-six-1.9.0-2.el7.noarch.rpm
-r-xr-xr-x 1 root root 397K 7月  12 14:23 python-setuptools-0.9.8-7.el7.noarch.rpm
```

收集方法：

```
//先安装yum工具
yum install yum-utils -y
//将 ansible 依赖包都下载下来
repoquery --requires --resolve --recursive ansible | xargs -r yumdownloader --destdir=/tmp/ansible
//将ansible rpm自己下载回来
yumdownloader --destdir=/tmp/ansible --resolve ansible
//验证一下依赖关系是完整的
//repotrack ansible
```



## 创建仓库索引

需要安装工具 yum install createrepo -y：

```
# createrepo ./yum/
Spawning worker 0 with 6 pkgs
Spawning worker 1 with 6 pkgs
Spawning worker 23 with 5 pkgs
Workers Finished
Saving Primary metadata
Saving file lists metadata
Saving other metadata
Generating sqlite DBs
Sqlite DBs complete
```

会在yum文件夹下生成一个索引文件夹 repodata

```
drwxr-xr-x 2 root root 4.0K 7月  12 14:25 repodata
[root@az1-drds-79 yum]# ls repodata/
5e15c62fec1fe43c6025ecf4d370d632f4b3f607500016e045ad94b70f87bac3-filelists.xml.gz
7a314396d6e90532c5c534567f9bd34eee94c3f8945fc2191b225b2861ace2b6-other.xml.gz
ce9dce19f6b426b8856747b01d51ceaa2e744b6bbd5fbc68733aa3195f724590-primary.xml.gz
ee33b7d79e32fe6ad813af92a778a0ec8e5cc2dfdc9b16d0be8cff6a13e80d99-filelists.sqlite.bz2
f7e8177e7207a4ff94bade329a0f6b572a72e21da106dd9144f8b1cdf0489cab-primary.sqlite.bz2
ff52e1f1859790a7b573d2708b02404eb8b29aa4b0c337bda83af75b305bfb36-other.sqlite.bz2
repomd.xml
```

## 生成iso镜像文件

非必要步骤，如果需要带到客户环境可以先生成iso，不过不够灵活。

也可以不用生成iso，直接在drds.repo中指定 createrepo 的目录也可以，记得要先执行 yum clean all和yum update 

```
#mkisofs -r -o docker_ansible.iso ./yum/
I: -input-charset not specified, using utf-8 (detected in locale settings)
Using PYTHO000.RPM;1 for  /python-httplib2-0.7.7-3.el7.noarch.rpm (python-httplib2-0.9.1-3.el7.noarch.rpm)
Using MARIA006.RPM;1 for  /mariadb-5.5.56-2.el7.x86_64.rpm (mariadb-libs-5.5.56-2.el7.x86_64.rpm)
Using LIBTO001.RPM;1 for  /libtomcrypt-1.17-25.el7.x86_64.rpm (libtomcrypt-1.17-26.el7.x86_64.rpm)
  6.11% done, estimate finish Sun Jul 12 14:26:47 2020
 97.60% done, estimate finish Sun Jul 12 14:26:48 2020
Total translation table size: 0
Total rockridge attributes bytes: 14838
Total directory bytes: 2048
Path table size(bytes): 26
Max brk space used 21000
81981 extents written (160 MB)

```

## 将 生成的 iso挂载到目标机器上

```
# mkdir /mnt/iso
# mount ./docker_ansible.iso /mnt/iso
mount: /dev/loop0 is write-protected, mounting read-only
```

## 配置本地 yum 源

yum repository不是必须要求iso挂载，直接指向rpm文件夹（必须要有 createrepo 建立索引了）也可以

```
# cat /etc/yum.repos.d/drds.repo 
[drds]
name=drds Extra Packages for Enterprise Linux 7 - $basearch
enabled=1
failovermethod=priority
baseurl=file:///mnt/repo #baseurl=http://192.168.1.91:8000/ 本地内网
priority=1  #添加priority=1，数字越小优先级越高，也可以修改网络源的priority的值
gpgcheck=0
#gpgkey=file:///mnt/cdrom/RPM-GPG-KEY-CentOS-5    #注：这个你cd /mnt/cdrom/可以看到这个key，这里仅仅是个例子， 因为gpgcheck是0 ，所以gpgkey不需要了
```

到此就可以在没有网络环境的机器上直接：yum install ansible docker -y 了 

## 测试

测试的话可以指定repo 源： yum install ansible --enablerepo=drds （drds 优先级最高）

本地会cache一些rpm的版本信息，可以执行 yum clean all 得到一个干净的测试环境

```
yum clean all
yum list
yum deplist ansible
```

## yum 源问题处理

[Yum commands error "pycurl.so: undefined symbol”](https://access.redhat.com/solutions/641093)

## 安装yum源

安装7.70版本curl yum源

```
rpm -Uvh http://www.city-fan.org/ftp/contrib/yum-repo/city-fan.org-release-2-1.rhel7.noarch.rpm
```

