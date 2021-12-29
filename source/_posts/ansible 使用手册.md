---
title: ansible 手册
date: 2016-03-24 17:30:03
categories: Ansible
tags:
	- Ansible
    - Linux
---

# ansible 手册

## 获取模块信息 ##
-
获取所有模块信息，100多个

*  ansible-doc -l

获取每个模块的具体信息 
*  ansible-doc   
   example：ansible-doc ping
   
      PING

      A trivial test module, this module always returns `pong' on
      successful contact. It does not make sense in playbooks, but it is
      useful from `/usr/bin/udp'

    EXAMPLES:
    Test 'webservers' status

    udp webservers -m ping

## 嵌套执行命令roles ##
    - name: create jdk home
      file: path={{ remote_jdk_home }} state=directory mode=0755
    
    - name: xxxxxxxxx
      include: ../../init/tasks/main.yml

## defaults 中变量定义 ##
     1：加双引号；2：变量名和变量之间，有空格；
     diamond_db_key: "{{ diamond_db_ip }}_{{ diamond_db_name }}_dbkey"
     manager_user1: "{{ manager_user_name }}"

# tags #
相同的tasks在不同的环境下面执行，通过tag来进行表面，如下图：

      useage: 
        udp-playbook setup.yml -v -kK -i hosts.ini --tags "ta"
    
    - name: 1
      authorized_key: user={{ ansible_ssh_user }}  key="{{ lookup('file', '~/.ssh/id_rsa.pub') }}"  state=present
      tags: ta
    
    - name: 2
      group: name={{ remote_user }}
      tags: always
    
    - name: 3
      file: path={{ remote_home }} owner={{ remote_user }} group={{ remote_user }} state=directory recurse=yes mode=0755
      tags: tb

## 常见错误

ansible 中 scp scp: ambiguous target 错误还是因为ssh 增加了 -t 参数, scp不支持 -t 参数



## [disable python warning](https://docs.ansible.com/ansible/latest/reference_appendices/interpreter_discovery.html)

To control the discovery behavior:

- for individual hosts and groups, use the `ansible_python_interpreter` inventory variable
- globally, use the `interpreter_python` key in the `[defaults]` section of `ansible.cfg`

```shell
[defaults]
interpreter_python=auto_silent  
```

