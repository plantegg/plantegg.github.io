---
title: kubernetes volume and storage
date: 2020-01-13 17:30:03
categories:
    - docker
tags:
    - docker
    - kubernetes
    - volume
---

# kubernetes volume and storage

通常部署应用需要一些永久存储，kubernetes提供了PersistentVolume （PV，实际存储）、PersistentVolumeClaim （PVC，Pod访问PV的接口）、StorageClass来支持。

它为 PersistentVolume 定义了 [StorageClass 名称](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#class) 为 `manual`，StorageClass 名称用来将 PersistentVolumeClaim 请求绑定到该 PersistentVolume。

PVC是用来描述希望使用什么样的或者说是满足什么条件的存储，它的全称是Persistent Volume Claim，也就是持久化存储声明。开发人员使用这个来描述该容器需要一个什么存储。

PVC就相当于是容器和PV之间的一个接口，使用人员只需要和PVC打交道即可。另外你可能也会想到如果当前环境中没有合适的PV和我的PVC绑定，那么我创建的POD不就失败了么？的确是这样的，不过如果发现这个问题，那么就赶快创建一个合适的PV，那么这时候持久化存储循环控制器会不断的检查PVC和PV，当发现有合适的可以绑定之后它会自动给你绑定上然后被挂起的POD就会自动启动，而不需要你重建POD。

创建 PersistentVolumeClaim 之后，Kubernetes 控制平面将查找满足申领要求的 PersistentVolume。 如果控制平面找到具有相同 StorageClass 的适当的 PersistentVolume，则将 PersistentVolumeClaim 绑定到该 PersistentVolume 上。**PVC的大小可以小于PV的大小**。

一旦 PV 和 PVC 绑定后，`PersistentVolumeClaim` 绑定是排他性的，不管它们是如何绑定的。 PVC 跟 PV 绑定是一对一的映射。

**注意**：PV必须先于POD创建，而且只能是网络存储不能属于任何Node，虽然它支持HostPath类型但由于你不知道POD会被调度到哪个Node上，所以你要定义HostPath类型的PV就要保证所有节点都要有HostPath中指定的路径。

## PV 和PVC的关系

PVC就会和PV进行绑定，绑定的一些原则：

1. PV和PVC中的spec关键字段要匹配，比如存储（storage）大小。
2. PV和PVC中的storageClassName字段必须一致，这个后面再说。
3. 上面的labels中的标签只是增加一些描述，对于PVC和PV的绑定没有关系

PV的accessModes：支持三种类型

- ReadWriteMany 多路读写，卷能被集群多个节点挂载并读写
- ReadWriteOnce 单路读写，卷只能被单一集群节点挂载读写
- ReadOnlyMany 多路只读，卷能被多个集群节点挂载且只能读

PV状态：

-  Available – 资源尚未被claim使用
-  Bound – 卷已经被绑定到claim了
-  Released – claim被删除，卷处于释放状态，但未被集群回收。
-  Failed – 卷自动回收失败

 PV**回收Recycling**---pv可以设置三种回收策略：保留（Retain），回收（Recycle）和删除（Delete）。

-  保留（Retain）： 当删除与之绑定的PVC时候，这个PV被标记为released（PVC与PV解绑但还没有执行回收策略）且之前的数据依然保存在该PV上，但是该PV不可用，需要手动来处理这些数据并删除该PV。
-  删除（Delete）：当删除与之绑定的PVC时候
-  回收（Recycle）：这个在1.14版本中以及被废弃，取而代之的是推荐使用动态存储供给策略，它的功能是当删除与该PV关联的PVC时，自动删除该PV中的所有数据

### 更改 PersistentVolume 的回收策略

```
#kubectl patch pv wordpress-data -p '{"spec":{"persistentVolumeReclaimPolicy":"Delete"}}'
persistentvolume/wordpress-data patched
```

本地卷（hostPath）也就是LPV不支持动态供给的方式，延迟绑定，就是为了综合考虑所有因素再进行POD调度。其根本原因是动态供给是先调度POD到节点，然后动态创建PV以及绑定PVC最后运行POD；而LPV是先创建与某一节点关联的PV，然后在调度的时候综合考虑各种因素而且要包括PV在哪个节点，然后再进行调度，到达该节点后在进行PVC的绑定。也就说动态供给不考虑节点，LPV必须考虑节点。所以这两种机制有冲突导致无法在动态供给策略下使用LPV。换句话说动态供给是PV跟着POD走，而LPV是POD跟着PV走。

## PV 和 PVC

创建 pv controller 和pvc

```
#cat mysql-pv.yaml 
apiVersion: v1
kind: PersistentVolume
metadata:
  name: simple-pv-volume
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 20Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/simple"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pv-claim
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
```

### StorageClass

PV是运维人员来创建的，开发操作PVC，可是大规模集群中可能会有很多PV，如果这些PV都需要运维手动来处理这也是一件很繁琐的事情，所以就有了动态供给概念，也就是Dynamic Provisioning。而我们上面的创建的PV都是静态供给方式，也就是Static Provisioning。而动态供给的关键就是StorageClass，它的作用就是创建PV模板。

创建StorageClass里面需要定义PV属性比如存储类型、大小等；另外创建这种PV需要用到存储插件。最终效果是，用户提交PVC，里面指定存储类型，如果符合我们定义的StorageClass，则会为其自动创建PV并进行绑定。

**简单可以把storageClass理解为名字，只是这个名字可以重复，然后pvc和pv之间通过storageClass来绑定。**

如下case中两个pv和两个pvc的绑定就是通过storageClass(一致)来实现的（当然pvc要求的大小也必须和pv一致）：

```
#kubectl get pv
NAME             CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                              STORAGECLASS   REASON   AGE
mariadb-pv       8Gi        RWO            Retain           Bound    default/data-wordpress-mariadb-0   db                      3m54s
wordpress-data   10Gi       RWO            Retain           Bound    default/wordpress                  wordpress               3m54s

[root@az3-k8s-11 15:35 /root/charts/bitnami/wordpress]
#kubectl get pvc
NAME                       STATUS   VOLUME           CAPACITY   ACCESS MODES   STORAGECLASS   AGE
data-wordpress-mariadb-0   Bound    mariadb-pv       8Gi        RWO            db             4m21s
wordpress                  Bound    wordpress-data   10Gi       RWO            wordpress      4m21s

#cat create-pv.yaml 
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mariadb-pv
spec:
  capacity:
    storage: 8Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: db
  hostPath:
    path: /mnt/mariadb-pv

---

apiVersion: v1
kind: PersistentVolume
metadata:
  name: wordpress-data
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: wordpress
  hostPath:
    path: /mnt/wordpress-pv

----对应 pvc的定义参数：
persistence:
  enabled: true
  storageClass: "wordpress"
  accessMode: ReadWriteOnce
  size: 10Gi
  
  persistence:
    enabled: true
    mountPath: /bitnami/mariadb
    storageClass: "db"
    annotations: {}
    accessModes:
      - ReadWriteOnce
    size: 8Gi
  
```

#### 定义StorageClass

```
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
```

#### 定义PVC

```
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: local-claim
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: local-storage
```

## delete pv 卡住

```
#kubectl describe pv wordpress-pv
Name:            wordpress-pv
Labels:          <none>
Annotations:     pv.kubernetes.io/bound-by-controller: yes
Finalizers:      [kubernetes.io/pv-protection]  --- 问题在finalizers
StorageClass:    
Status:          Terminating (lasts 18h)
Claim:           default/wordpress
Reclaim Policy:  Retain
Access Modes:    RWO
VolumeMode:      Filesystem
Capacity:        10Gi
Node Affinity:   <none>
Message:         
Source:
    Type:      NFS (an NFS mount that lasts the lifetime of a pod)
    Server:    192.168.0.111
    Path:      /mnt/wordpress-pv
    ReadOnly:  false
Events:        <none>

先执行后就能自动删除了：
kubectl patch pv wordpress-pv -p '{"metadata":{"finalizers": []}}' --type=merge
```

