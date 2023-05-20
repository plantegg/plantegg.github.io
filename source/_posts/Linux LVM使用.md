---
title: Linux LVM使用
date: 2018-02-25 17:30:03
categories:
    - Linux
tags:
    - Linux
    - LVM
---

# Linux LVM使用

LVM是 Logical Volume Manager（逻辑[卷管理](https://baike.baidu.com/item/卷管理)）的简写, 用来解决磁盘分区大小动态分配。LVM不是软RAID（Redundant Array of Independent Disks）。

**从一块硬盘到能使用LV文件系统的步骤：**

​     **硬盘----分区(fdisk)----PV(pvcreate)----VG(vgcreate)----LV(lvcreate)----格式化(mkfs.ext4 LV为ext文件系统)----挂载**

![img](/images/951413iMgBlog/949069-20200416104045527-1858978940.png)

LVM磁盘管理方式

![image-20220725100705140](/images/951413iMgBlog/image-20220725100705140.png)

**lvreduce 缩小LV**

**先卸载--->然后减小逻辑边界---->最后减小物理边界--->在检测文件系统  ==谨慎用==**

```
[aliyun@uos15 15:07 /dev/disk/by-label]
$sudo e2label /dev/nvme0n1p1 polaru01  //给磁盘打标签

[aliyun@uos15 15:07 /dev/disk/by-label]
$lsblk  -f
NAME        FSTYPE LABEL     UUID                                 FSAVAIL FSUSE% MOUNTPOINT
sda                                                                              
├─sda1      vfat   EFI       D0E3-79A8                               299M     0% /boot/efi
├─sda2      ext4   Boot      f204c992-fb20-40e1-bf58-b11c994ee698    1.3G     6% /boot
├─sda3      ext4   Roota     dbc68010-8c36-40bf-b794-271e59ff5727   14.8G    61% /
├─sda4      ext4   Rootb     73fe0ac6-ff6b-46cc-a609-c574be026e8f                
├─sda5      ext4   _dde_data 798fce56-fc82-4f59-bcaa-d2ed5c48da8d   42.1G    54% /data
├─sda6      ext4   Backup    267dc7a8-1659-4ccc-b7dc-5f2cd80f4e4e    3.7G    57% /recovery
└─sda7      swap   SWAP      7a5632dc-bc7b-410e-9a50-07140f20cd13                [SWAP]
nvme0n1                                                                          
└─nvme0n1p1 ext4   polaru01  762a5700-8cf1-454a-b385-536b9f63c25d  413.4G    54% /u01
nvme1n1     xfs    u02       8ddf19c4-fe71-4428-b2aa-e45acf08050c                
nvme2n1     xfs    u03       2b8625b4-c67d-4f1e-bed6-88814adfd6cc                
nvme3n1     ext4   u01       cda85750-c4f7-402e-a874-79cb5244d4e1 
```

## LVM 创建、扩容

```
sudo vgcreate vg1 /dev/nvme0n1 /dev/nvme1n1 //两块物理磁盘上创建vg1
如果报错：
  Can't open /dev/nvme1n1 exclusively.  Mounted filesystem?
  Can't open /dev/nvme0n1 exclusively.  Mounted filesystem?
是说/dev/nvme0n1已经mounted了，需要先umount

vgdisplay 
sudo lvcreate -L 5T -n u03 vg1  //在虚拟volume-group vg1上创建一个5T大小的分区or: sudo lvcreate -l 100%free -n u03 vg1
sudo mkfs.ext4 /dev/vg1/u03   
sudo mkdir /lvm
sudo fdisk -l
sudo umount /lvm
sudo lvresize -L 5.8T /dev/vg1/u03 //lv 扩容
sudo e2fsck -f /dev/vg1/u03 
sudo resize2fs /dev/vg1/u03
sudo mount /dev/vg1/u03 /lvm
cd /lvm/
lvdisplay 
sudo vgdisplay vg1
lsblk -l
lsblk 
sudo vgextend vg1 /dev/nvme3n1  //vg 扩容, 增加一块磁盘到vg1
ls /u01
sudo vgdisplay 
sudo fdisk  -l
sudo pvdisplay 
sudo lvcreate -L 1T -n lv2 vg1  //从vg1中再分配一块1T大小的磁盘
sudo lvdisplay 
sudo mkfs.ext4 /dev/vg1/lv2 
mkdir /lv2
ls /
sudo mkdir /lv2
sudo mount /dev/vg1/lv2 /lv2
df -lh

//手工创建lvm
 1281  18/05/22 11:04:22 ls -l /dev/|grep -v ^l|awk '{print $NF}'|grep -E "^nvme[7-9]{1,2}n1$|^df[a-z]$|^os[a-z]$"
 1282  18/05/22 11:05:06 vgcreate -s 32 vgbig /dev/nvme7n1 /dev/nvme8n1 /dev/nvme9n1
 1283  18/05/22 11:05:50 vgcreate -s 32 vgbig /dev/nvme7n1 /dev/nvme8n1 /dev/nvme9n1
 1287  18/05/22 11:07:59 lvcreate -A y -I 128K -l 100%FREE  -i 3 -n big vgbig
 1288  18/05/22 11:08:02 df -h
 1289  18/05/22 11:08:21 lvdisplay
 1290  18/05/22 11:08:34 df -lh
 1291  18/05/22 11:08:42 df -h
 1292  18/05/22 11:09:05 mkfs.ext4 /dev/vgbig/big -m 0 -O extent,uninit_bg -E lazy_itable_init=1 -q -L big -J size=4000
 1298  18/05/22 11:10:28 mkdir -p /big
 1301  18/05/22 11:12:11 mount /dev/vgbig/big /big
```

## 创建LVM

```shell
function create_polarx_lvm_V62(){
    vgremove vgpolarx

    #sed -i "97 a\    types = ['nvme', 252]" /etc/lvm/lvm.conf
    parted -s /dev/nvme0n1 rm 1
    parted -s /dev/nvme1n1 rm 1
    parted -s /dev/nvme2n1 rm 1
    parted -s /dev/nvme3n1 rm 1
    dd if=/dev/zero of=/dev/nvme0n1  count=10000 bs=512
    dd if=/dev/zero of=/dev/nvme1n1  count=10000 bs=512
    dd if=/dev/zero of=/dev/nvme2n1  count=10000 bs=512
    dd if=/dev/zero of=/dev/nvme3n1  count=10000 bs=512

    #lvmdiskscan
    vgcreate -s 32 vgpolarx /dev/nvme0n1 /dev/nvme1n1 /dev/nvme2n1 /dev/nvme3n1
    lvcreate -A y -I 16K -l 100%FREE  -i 4 -n polarx vgpolarx
    mkfs.ext4 /dev/vgpolarx/polarx -m 0 -O extent,uninit_bg -E lazy_itable_init=1 -q -L polarx -J size=4000
    sed  -i  "/polarx/d" /etc/fstab
    mkdir -p /polarx
    echo "LABEL=polarx /polarx     ext4        defaults,noatime,data=writeback,nodiratime,nodelalloc,barrier=0    0 0" >> /etc/fstab
    mount -a
}

create_polarx_lvm_V62
```

-I 64K 值条带粒度，默认64K，mysql pagesize 16K，所以最好16K

## 复杂版创建LVM

```shell
function disk_part(){
    set -e
    if [ $# -le 1 ]
    then
        echo "disk_part argument error"
        exit -1
    fi
    action=$1
    disk_device_list=(`echo $*`)

    echo $disk_device_list
    unset disk_device_list[0]

    echo $action
    echo ${disk_device_list[*]}
    len=`echo ${#disk_device_list[@]}`
    echo "start remove origin partition  "
    for dev in  ${disk_device_list[@]}
    do
        #echo ${dev}
        `parted -s ${dev} rm 1` || true
        dd if=/dev/zero of=${dev}  count=100000 bs=512
    done
#替换98行，插入的话r改成a
    sed -i "98 r\    types = ['aliflash' , 252 , 'nvme' ,252 , 'venice', 252 , 'aocblk', 252]" /etc/lvm/lvm.conf
    sed  -i  "/flash/d" /etc/fstab

    if [ x${1} == x"split" ]
    then
        echo "split disk "
        #lvmdiskscan
    echo ${disk_device_list}
        vgcreate -s 32 vgpolarx ${disk_device_list[*]}
    lvcreate -A y -I 16K -l 100%FREE  -i 4 -n polarx vgpolarx
        #lvcreate -A y -I 128K -l 75%VG  -i ${len} -n volume1 vgpolarx
        #lvcreate -A y -I 128K -l 100%FREE  -i ${len} -n volume2 vgpolarx
        mkfs.ext4 /dev/vgpolarx/polarx -m 0 -O extent,uninit_bg -E lazy_itable_init=1 -q -L polarx -J size=4000
        sed  -i  "/polarx/d" /etc/fstab
        mkdir -p /polarx
    opt="defaults,noatime,data=writeback,nodiratime,nodelalloc,barrier=0"
        echo "LABEL=polarx /polarx     ext4        ${opt}    0 0" >> /etc/fstab
        mount -a
    else
        echo "unkonw action "
    fi

}

function format_nvme_mysql(){

    if [ `df |grep flash|wc -l` -eq $1  ]
    then
        echo "check success"
        echo "start umount partition "
        parttion_list=`df |grep flash|awk -F ' ' '{print $1}'`
        for partition in ${parttion_list[@]}
        do
            echo $partition
            umount $partition
        done

    else
        echo "check host fail"
        exit -1
    fi

  disk_device_list=(`ls -l /dev/|grep -v ^l|awk '{print $NF}'|grep -E "^nvme[0-9]{1,2}n1$|^df[a-z]$|^os[a-z]$"`)
  full_disk_device_list=()
    for i in ${!disk_device_list[@]}
  do
        echo ${i}
    full_disk_device_list[${i}]=/dev/${disk_device_list[${i}]}
  done
    echo ${full_disk_device_list[@]}
    disk_part split ${full_disk_device_list[@]}
}

if [ ! -d "/polarx" ]; then
    umount /dev/vgpolarx/polarx
    vgremove -f vgpolarx
    dmsetup --force --retry --deferred remove vgpolarx-polarx
    format_nvme_mysql $1
else
   echo "the lvm exists."
fi
```

LVM性能还没有做到多盘并行，也就是性能和单盘差不多，盘数多读写性能也一样

## 安装LVM

```
sudo yum install lvm2 -y
```



## dmsetup查看LVM

管理工具dmsetup是 Device mapper in the kernel 中的一个

```
dmsetup ls
dmsetup info /dev/dm-0
```



## reboot 失败

在麒麟下OS reboot的时候可能因为`mount: /polarx: 找不到 LABEL=/polarx.` 导致OS无法启动，可以进入紧急模式，然后注释掉 /etc/fstab 中的polarx 行，再reboot

这是因为LVM的label、uuid丢失了，导致挂载失败。

查看设备的label

```
sudo lsblk -o name,mountpoint,label,size,uuid  or lsblk -f
```

修复：

紧急模式下修改 /etc/fstab 去掉有问题的挂载; 修改标签

```
#blkid   //查询uuid、label
/dev/mapper/klas-root: UUID="c4793d67-867e-4f14-be87-f6713aa7fa36" BLOCK_SIZE="512" TYPE="xfs"
/dev/sda2: UUID="8DCEc5-b4P7-fW0y-mYwR-5YTH-Yf81-rH1CO8" TYPE="LVM2_member" PARTUUID="4ffd9bfa-02"
/dev/nvme0n1: UUID="nJAHxP-d15V-Fvmq-rxa3-GKJg-TCqe-gD1A2Z" TYPE="LVM2_member"
/dev/sda1: UUID="29f59517-91c6-4b3c-bd22-0a47c800d7f4" BLOCK_SIZE="512" TYPE="xfs" PARTUUID="4ffd9bfa-01"
/dev/mapper/vgpolarx-polarx: LABEL="polarx" UUID="025a3ac5-d38a-42f1-80b6-563a55cba12a" BLOCK_SIZE="4096" TYPE="ext4"

e2label /dev/mapper/vgpolarx-polarx polarx
```

比如，下图右边的是启动失败的

![image-20211228185144635](/images/951413iMgBlog/image-20211228185144635.png)

## [软RAID](https://xiaoz.co/2020/04/28/array-with-mdadm/)

> mdadm(multiple devices admin)是一个非常有用的管理软raid的工具，可以用它来创建、管理、监控raid设备，当用mdadm来创建磁盘阵列时，可以使用整块独立的磁盘(如/dev/sdb,/dev/sdc)，也可以使用特定的分区(/dev/sdb1,/dev/sdc1)

mdadm使用手册

> mdadm --create device --level=Y --raid-devices=Z devices
> 	-C | --create /dev/mdn
> 	-l | --level  0|1|4|5
> 	-n | --raid-devices device [..]
> 	-x | --spare-devices device [..]



[创建](https://www.cxyzjd.com/article/weixin_51486343/113114906) -l 0表示raid0， -l 10表示raid10

```shell
mdadm -C /dev/md0 -a yes -l 0 -n2 /dev/nvme{6,7}n1  //raid0
mdadm -D /dev/md0
mkfs.ext4 /dev/md0
mkdir /md0
mount /dev/md0 /md0

//条带
mdadm --create --verbose /dev/md0 --level=linear --raid-devices=2 /dev/sdb /dev/sdc
检查
mdadm -E /dev/nvme[0-5]n1
```

删除

```
umount /md0 
mdadm -S /dev/md0
```

监控raid

```
#cat /proc/mdstat
Personalities : [raid0] [raid6] [raid5] [raid4]
md6 : active raid6 nvme3n1[3] nvme2n1[2] nvme1n1[1] nvme0n1[0]
      7501211648 blocks super 1.2 level 6, 512k chunk, algorithm 2 [4/4] [UUUU]
      [=>...................]  resync =  7.4% (280712064/3750605824) finish=388.4min speed=148887K/sec
      bitmap: 28/28 pages [112KB], 65536KB chunk //raid6一直在异步刷数据

md0 : active raid0 nvme7n1[3] nvme6n1[2] nvme4n1[0] nvme5n1[1]
      15002423296 blocks super 1.2 512k chunks
```

控制刷盘速度

```
#sysctl -a |grep raid
dev.raid.speed_limit_max = 0
dev.raid.speed_limit_min = 0
```

## nvme-cli

```
nvme id-ns /dev/nvme1n1 -H
for i in `seq 0 1 2`; do nvme format --lbaf=3 /dev/nvme${i}n1 ; done  //格式化，选择不同的扇区大小，默认512，可选4K

fuser -km /data/
```



## raid硬件卡

[raid卡外观](http://aijishu.com/a/1060000000225602)

![image.png](/images/951413iMgBlog/bV6Ra.png)

## 参考资料

https://www.tecmint.com/manage-and-create-lvm-parition-using-vgcreate-lvcreate-and-lvextend/

[pvcreate error : Can’t open /dev/sdx exclusively. Mounted filesystem?](https://www.thegeekdiary.com/lvm-error-cant-open-devsdx-exclusively-mounted-filesystem/)

软RAID配置方法[参考这里](https://halysl.github.io/2020/06/09/%E8%BD%AFraid%E9%85%8D%E7%BD%AE/)

