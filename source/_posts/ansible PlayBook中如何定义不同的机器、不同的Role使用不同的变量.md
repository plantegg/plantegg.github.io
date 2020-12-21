---
title: 在ansible PlayBook中如何定义不同的机器、不同的Role使用不同的变量
date: 2016-03-22 17:30:03
categories: Ansible
tags:
	- ansible
    - Linux
---



# 在ansible PlayBook中如何定义不同的机器、不同的Role使用不同的变量


## 问题场景1
>  在安装Edas Agent脚本的时候发现在不同的机房[深圳、杭州、北京]有不同的网络定义[VPC、Normal],希望不同机房的机器在不同网络下使用不同的下载地址

## 问题场景2
>  在同一台机器上安装MySQL和Diamond，需要定义一个Project_Name, 如果定义在Hosts.ini中必然会覆盖，一台机器相当于一个作用域【同一个函数中也不允许你定义两个一样的名字吧！】

## 问题场景1的解决

### 在hosts.ini文件中定义不同的机器和变量


	[sz_vpc]
	10.125.0.169 
	10.125.192.40
	
	[sz_normal]
	10.125.12.174 
	
	[sz:children]
	sz_vpc
	sz_normal
	
	[hz_vpc]
	10.125.3.33  
	[hz_normal]
	10.125.14.238
	
	[hz:children]
	hz_vpc
	hz_normal
	
	############variables
	[sz_vpc:vars]
	script_url="sz_vpc"
	
	[sz_normal:vars]
	script_url="sz_normal"
	
	[hz_vpc:vars]
	script_url="hz_vpc"
	
	[hz_normal:vars]
	script_url="hz_normal"

### 执行代码

	- name: test variables
	  debug: msg={{ script_url }}  #对所有机器输出他们的url来验证一下我们的定义生效没有
	  tags: test

### 执行结果
	$udp-playbook -i udp-hosts.ini site.yml -b -u admin -t test    
	
	UDP-PLAY-START: [apply common configuration to all nodes] ********************* 
	
	UDP-TASK: [test variables] **************************************************** 
	ok => 10.125.3.33 => {
	    "msg": "hz_vpc"
	}
	ok => 10.125.0.169 => {
	    "msg": "sz_vpc"
	}
	ok => 10.125.192.40 => {
	    "msg": "sz_vpc"
	}
	ok => 10.125.14.238 => {
	    "msg": "hz_normal"
	}
	ok => 10.125.12.174 => {
	    "msg": "sz_normal"
	}

## 问题场景2的解决

> 在这里变量不要放在hosts.ini中，到MySQL、Diamond的roles中新建两个yml文件,在 里面分别写上 MySQL和Diamond的 Project_Name 这样就不会覆盖了

### 目录结构
	```
	$ find roles
	roles/
	roles/mysql
	roles/mysql/tasks
	roles/mysql/tasks/main.yml
	roles/mysql/defaults
	roles/mysql/defaults/main.yml
	roles/diamond
	roles/diamond/tasks
	roles/diamond/tasks/main.yml
	roles/diamond/defaults
	roles/diamond/defaults/main.yml
	
	```

### 变量定义
```
$ cat roles/mysql/defaults/main.yml

project: {
        "project_name": mysql,
		"version": 5.6.0
        }

$ cat roles/daimond/defaults/main.yml

project: {
        "project_name": daimond,
		"version": 3.5.0
        }
```

### 变量使用

```
- name: print the tar file name
  debug: msg="{{ project.project_name }}"
  tags: test
```

## role 和 playbook 用法

role中文件夹含义

- tasks目录：存放task列表。若role要生效，此目录必须要有一个主task文件main.yml，在main.yml中可以使用include包含同目录(即tasks)中的其他文件。
- handlers目录：存放handlers的目录，若要生效，则文件必须名为main.yml文件。
- files目录：在task中执行copy或script模块时，如果使用的是相对路径，则会到此目录中寻找对应的文件。
- templates目录：在task中执行template模块时，如果使用的是相对路径，则会到此目录中寻找对应的模块文件。
- vars目录：定义**专属**于该role的变量，如果要有var文件，则必须为main.yml文件。
- defaults目录：**定义角色默认变量，角色默认变量的优先级最低**，会被任意其他层次的同名变量覆盖。如果要有var文件，则必须为main.yml文件。



```
ansible-playbook 11.harbor.yml --list-tasks
```

