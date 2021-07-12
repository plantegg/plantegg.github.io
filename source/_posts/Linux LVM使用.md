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

LVM是 Logical Volume Manager（逻辑[卷管理](https://baike.baidu.com/item/卷管理)）的简写, 用来解决磁盘分区大小动态分配。LVM不是软RAID（Redundant Array of Independent Disks）。软RAID配置方法[参考这里](https://halysl.github.io/2020/06/09/%E8%BD%AFraid%E9%85%8D%E7%BD%AE/)

**从一块硬盘到能使用LV文件系统的步骤：**

​     **硬盘----分区(fdisk)----PV(pvcreate)----VG(vgcreate)----LV(lvcreate)----格式化(mkfs.ext4 LV为ext文件系统)----挂载**

![img](https://plantegg.oss-cn-beijing.aliyuncs.com/images/951413iMgBlog/949069-20200416104045527-1858978940.png)



**lvreduce 缩小LV**

**先卸载--->然后减小逻辑边界---->最后减小物理边界--->在检测文件系统  ====谨慎用===**

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
```

## 创建LVM

```
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
    lvcreate -A y -I 128K -l 100%FREE  -i 4 -n polarx vgpolarx
    mkfs.ext4 /dev/vgpolarx/polarx -m 0 -O extent,uninit_bg -E lazy_itable_init=1 -q -L /polarx -J size=4000
    sed  -i  "/polarx/d" /etc/fstab
    mkdir -p /polarx
    echo "LABEL=/polarx /polarx     ext4        defaults,noatime,data=writeback,nodiratime,nodelalloc,barrier=0    0 0" >> /etc/fstab
    mount -a
}

create_polarx_lvm_V62
```

## 复杂版创建LVM

```
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
    lvcreate -A y -I 128K -l 100%FREE  -i 4 -n polarx vgpolarx
        #lvcreate -A y -I 128K -l 75%VG  -i ${len} -n volume1 vgpolarx
        #lvcreate -A y -I 128K -l 100%FREE  -i ${len} -n volume2 vgpolarx
        mkfs.ext4 /dev/vgpolarx/polarx -m 0 -O extent,uninit_bg -E lazy_itable_init=1 -q -L /polarx -J size=4000
        sed  -i  "/polarx/d" /etc/fstab
        mkdir -p /polarx
    opt="defaults,noatime,data=writeback,nodiratime,nodelalloc,barrier=0"
        echo "LABEL=/polarx /polarx     ext4        ${opt}    0 0" >> /etc/fstab
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

## 参考资料

https://www.tecmint.com/manage-and-create-lvm-parition-using-vgcreate-lvcreate-and-lvextend/

[pvcreate error : Can’t open /dev/sdx exclusively. Mounted filesystem?](https://www.thegeekdiary.com/lvm-error-cant-open-devsdx-exclusively-mounted-filesystem/)

