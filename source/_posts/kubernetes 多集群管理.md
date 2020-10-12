---

title: kubernetes 多集群管理
date: 2020-01-21 17:30:03
categories:
    - docker
tags:
    - docker
    - kubernetes
    - context
---

# kubernetes 多集群管理



## kubectl 管理多集群

指定config配置文件的方式访问不同的集群

```
kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes
```

一个kubectl可以管理多个集群，主要是 ~/.kube/config 里面的配置，比如：

```
clusters:
- cluster:
    certificate-authority: /root/k8s-cluster.ca
    server: https://192.168.0.80:6443
  name: context-az1
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCQl0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K
    server: https://192.168.0.97:6443
  name: context-az3

- context:
    cluster: context-az1
    namespace: default
    user: az1-admin
  name: az1
- context:
    cluster: context-az3
    namespace: default
    user: az3-read
  name: az3
current-context: az3  //当前使用的集群

kind: Config
preferences: {}
users:
- name: az1-admin
  user:
    client-certificate: /root/k8s.crt  //key放在配置文件中
    client-key: /root/k8s.key
- name: az3-read
  user:
    client-certificate-data: LS0tLS1CRUQ0FURS0tLS0tCg==
    client-key-data: LS0tLS1CRUdJThuL2VPM0YxSWpEcXBQdmRNbUdiU2c9PQotLS0tLUVORCBSU0EgUFJJVkFURSBLRVktLS0tLQo=
```

多个集群中切换的话 ： kubectl config use-context az3

### 快速合并两个cluster

简单来讲就是把两个集群的 .kube/config 文件合并，注意context、cluster name别重复了。

```
# 必须提前保证两个config文件中的cluster、context名字不能重复
export KUBECONFIG=~/.kube/config:~/someotherconfig 
kubectl config view --flatten

#激活这个上下文
kubectl config use-context az1 

#查看所有context
kubectl config get-contexts 
CURRENT   NAME   CLUSTER       AUTHINFO           NAMESPACE
          az1    context-az1   az1-admin          default
*         az2    kubernetes    kubernetes-admin   
          az3    context-az3   az3-read           default

```

背后的原理类似于这个流程：

```
# 添加集群 集群地址上一步有获取 ，需要指定ca文件，上一步有获取 
kubectl config set-cluster cluster-az1 --server https://192.168.146.150:6444  --certificate-authority=/usr/program/k8s-certs/k8s-cluster.ca

# 添加用户 需要指定crt，key文件，上一步有获取
kubectl config set-credentials az1-admin --client-certificate=/usr/program/k8s-certs/k8s.crt --client-key=/usr/program/k8s-certs/k8s.key

# 指定一个上下文的名字，我这里叫做 az1，随便你叫啥 关联刚才的用户
kubectl config set-context az1 --cluster=context-az1  --namespace=default --user=az1-admin 

```

## 参考资料

http://coreos.com/blog/kubectl-tips-and-tricks

https://stackoverflow.com/questions/46184125/how-to-merge-kubectl-config-file-with-kube-config