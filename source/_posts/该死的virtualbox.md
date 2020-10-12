---
title: 该死的错误
date: 2019-11-05 12:30:03
categories: Linux
tags:
    - virtualbox
    - ubuntu
    - dd
---

# 该死的错误

virtualbox+ubuntu用了快10年了，各种莫名其妙的问题，一直没有换掉，也怪自己 virtualbox+ubuntu组合也许确实奇葩吧，每次碰到问题都没法google到真正的答案了。

## 问题

用的过程中突然发现挂载的数据盘找不到了（主要存放工作文件）， 看历史记录发现自己执行了：

	sudo dd if=/dev/urandom of=/dev/sdb1 bs=1M count=512

/dev/sdb1 对应的正是我的大磁盘，哭死去，怪自己不认识 /dev/sdb1！！ 从来不知道自己挂载的磁盘的真正名字，df -lh 也没仔细看过，导致了这次故障

出问题的history:

	29214  01/11/19 10:29:05 vi /tmp/tmp.txt
	29215  01/11/19 10:29:18 cat /tmp/tmp.txt |grep "^172.16"
	29216  01/11/19 10:29:27 cat /tmp/tmp.txt |grep "^172.16" >cainiao.txt
	29217  01/11/19 10:29:31 wc -l cainiao.txt
	29218  01/11/19 10:33:13 cat cainiao.txt 
	29219  01/11/19 13:36:55 sudo dd if=/dev/urandom of=/dev/sdb1 bs=1M count=512 //故障发生
	29220  01/11/19 13:37:08 cd ..
	29221  01/11/19 13:37:46 cd / //尝试解决
	29222  01/11/19 19:13:45 ls -lh
	29223  01/11/19 19:13:49 cd ali 
	29224  03/11/19 10:24:56 dmesg
	29225  03/11/19 10:27:28 dmesg |grep -i sda
	29226  03/11/19 10:27:59 dmesg |grep -i sata
	29227  04/11/19 10:19:46 dmesg
	29228  04/11/19 10:20:20 dmesg |grep -i sda
	29229  04/11/19 10:25:21 dmesg 
	29230  04/11/19 10:25:25 dmesg 
	29231  04/11/19 10:25:34 dmesg |grep -i sda


## 尝试

各种重启还是无效，重新删掉数据盘再次挂载启动后依然看不见

## mount

virtualbox的启动参数里明确能看到这快盘，和挂载配置

启动后通过fdisk可以看见这块大硬盘

	$sudo fdisk -l

	Disk /dev/sda: 20 GiB, 21474836480 bytes, 41943040 sectors
	Units: sectors of 1 * 512 = 512 bytes
	Sector size (logical/physical): 512 bytes / 512 bytes
	I/O size (minimum/optimal): 512 bytes / 512 bytes
	Disklabel type: dos
	Disk identifier: 0x01012f4d
	
	Device     Boot    Start      End  Sectors Size Id Type
	/dev/sda1  *        2048 33554431 33552384  16G 83 Linux
	/dev/sda2       33556478 41940991  8384514   4G  5 Extended
	/dev/sda5       33556480 41940991  8384512   4G 82 Linux swap / Solaris
	
	Disk /dev/sdb: 50 GiB, 53687091200 bytes, 104857600 sectors
	Units: sectors of 1 * 512 = 512 bytes
	Sector size (logical/physical): 512 bytes / 512 bytes
	I/O size (minimum/optimal): 512 bytes / 512 bytes
	Disklabel type: dos
	Disk identifier: 0x000e88f6
	
	Device     Boot    Start       End  Sectors Size Id Type
	/dev/sdb1  *        2048  96471039 96468992  46G 83 Linux
	/dev/sdb2       96473086 104855551  8382466   4G  5 Extended
	/dev/sdb5       96473088 104855551  8382464   4G 82 Linux swap / Solaris
	
	Disk /dev/sdc: 50 GiB, 53687091200 bytes, 104857600 sectors
	Units: sectors of 1 * 512 = 512 bytes
	Sector size (logical/physical): 512 bytes / 512 bytes
	I/O size (minimum/optimal): 512 bytes / 512 bytes
	Disklabel type: dos
	Disk identifier: 0x000e88f6
	
	Device     Boot    Start       End  Sectors Size Id Type
	/dev/sdc1  *        2048  96471039 96468992  46G 83 Linux
	/dev/sdc2       96473086 104855551  8382466   4G  5 Extended
	/dev/sdc5       96473088 104855551  8382464   4G 82 Linux swap / Solaris


尝试手工mount （这时看到的才是root cause）

	write-protected, mounting read-only 和 bad superblock 错误

尝试 fsck(危险动作）

	sudo fsck -y /dev/sdb1

然后再次mount成功了

	sudo mount  /dev/sdb1 /media/ren/a64abcac-657d-42ee-8e7b-575eac99bce3

lsblk(修复后）

	$sudo lsblk
	NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
	sda      8:0    0   20G  0 disk 
	├─sda1   8:1    0   16G  0 part /
	├─sda2   8:2    0    1K  0 part 
	└─sda5   8:5    0    4G  0 part [SWAP]
	sdb      8:16   0   50G  0 disk 
	├─sdb1   8:17   0   46G  0 part /media/ren/a64abcac-657d-42ee-8e7b-575eac99bce3
	├─sdb2   8:18   0    1K  0 part 
	└─sdb5   8:21   0    4G  0 part 
	sr0     11:0    1 73.6M  0 rom  /media/ren/VBox_GAs_6.0.10

进到mount后的目录中，查看磁盘大小正常，但是文件看不见了

	du 发现文件都在lost+found目录下，但是文件夹名字都改成了 inode名字

根据文件夹大小找出之前的文件夹（比较大的），将其复制出来，一切正常了


## 修复记录

其中sda是系统盘，sdb是修复后的大磁盘， sdc 是修复前的大磁盘（备份过的）

	$sudo fdisk -l

	Disk /dev/sda: 20 GiB, 21474836480 bytes, 41943040 sectors
	Units: sectors of 1 * 512 = 512 bytes
	Sector size (logical/physical): 512 bytes / 512 bytes
	I/O size (minimum/optimal): 512 bytes / 512 bytes
	Disklabel type: dos
	Disk identifier: 0x01012f4d
	
	Device     Boot    Start      End  Sectors Size Id Type
	/dev/sda1  *        2048 33554431 33552384  16G 83 Linux
	/dev/sda2       33556478 41940991  8384514   4G  5 Extended
	/dev/sda5       33556480 41940991  8384512   4G 82 Linux swap / Solaris
	
	Disk /dev/sdb: 50 GiB, 53687091200 bytes, 104857600 sectors
	Units: sectors of 1 * 512 = 512 bytes
	Sector size (logical/physical): 512 bytes / 512 bytes
	I/O size (minimum/optimal): 512 bytes / 512 bytes
	Disklabel type: dos
	Disk identifier: 0x000e88f6
	
	Device     Boot    Start       End  Sectors Size Id Type
	/dev/sdb1  *        2048  96471039 96468992  46G 83 Linux
	/dev/sdb2       96473086 104855551  8382466   4G  5 Extended
	/dev/sdb5       96473088 104855551  8382464   4G 82 Linux swap / Solaris
	
	Disk /dev/sdc: 50 GiB, 53687091200 bytes, 104857600 sectors
	Units: sectors of 1 * 512 = 512 bytes
	Sector size (logical/physical): 512 bytes / 512 bytes
	I/O size (minimum/optimal): 512 bytes / 512 bytes
	Disklabel type: dos
	Disk identifier: 0x000e88f6
	
	Device     Boot    Start       End  Sectors Size Id Type
	/dev/sdc1  *        2048  96471039 96468992  46G 83 Linux
	/dev/sdc2       96473086 104855551  8382466   4G  5 Extended
	/dev/sdc5       96473088 104855551  8382464   4G 82 Linux swap / Solaris

可以看到没有修复的磁盘 uuid不太正常，类型也识别为 dos(正常应该是ext4）

	[ren@vb 18:12 /home/ren]
	$sudo blkid /dev/sdc
	/dev/sdc: PTUUID="000e88f6" PTTYPE="dos"
	
	[ren@vb 18:12 /home/ren]
	$sudo blkid /dev/sdc1
	/dev/sdc1: PARTUUID="000e88f6-01"
	
	[ren@vb 18:12 /home/ren]
	$sudo blkid /dev/sdb
	/dev/sdb: PTUUID="000e88f6" PTTYPE="dos"
	
	[ren@vb 18:12 /home/ren]
	$sudo blkid /dev/sdb1
	/dev/sdb1: UUID="a64abcac-657d-42ee-8e7b-575eac99bce3" TYPE="ext4" PARTUUID="000e88f6-01"

尝试mount失败

	[ren@vb 18:14 /home/ren]
	$sudo mkdir /media/ren/hd
	
	[ren@vb 18:15 /home/ren]
	$sudo mount /dev/sd
	sda   sda1  sda2  sda5  sdb   sdb1  sdb2  sdb5  sdc   sdc1  sdc2  sdc5  
	
	[ren@vb 18:15 /home/ren]
	$sudo mount /dev/sdc1 /media/ren/hd
	mount: /dev/sdc1 is write-protected, mounting read-only
	mount: wrong fs type, bad option, bad superblock on /dev/sdc1,
	       missing codepage or helper program, or other error
	
	       In some cases useful info is found in syslog - try
	       dmesg | tail or so.

dmesg中比较正常和不正常的磁盘日志，是看不出来差别的（还没有触发mount动作）

	[ren@vb 18:16 /home/ren]
	$dmesg |grep sdc
	[一 11月  4 18:06:47 2019] sd 4:0:0:0: [sdc] 104857600 512-byte logical blocks: (53.6 GB/50.0 GiB)
	[一 11月  4 18:06:47 2019] sd 4:0:0:0: [sdc] Write Protect is off
	[一 11月  4 18:06:47 2019] sd 4:0:0:0: [sdc] Mode Sense: 00 3a 00 00
	[一 11月  4 18:06:47 2019] sd 4:0:0:0: [sdc] Write cache: enabled, read cache: enabled, doesn't support DPO or FUA
	[一 11月  4 18:06:47 2019]  sdc: sdc1 sdc2 < sdc5 >
	[一 11月  4 18:06:47 2019] sd 4:0:0:0: [sdc] Attached SCSI disk
	
	[ren@vb 18:17 /home/ren]
	$dmesg |grep sdb
	[一 11月  4 18:06:47 2019] sd 3:0:0:0: [sdb] 104857600 512-byte logical blocks: (53.6 GB/50.0 GiB)
	[一 11月  4 18:06:47 2019] sd 3:0:0:0: [sdb] Write Protect is off
	[一 11月  4 18:06:47 2019] sd 3:0:0:0: [sdb] Mode Sense: 00 3a 00 00
	[一 11月  4 18:06:47 2019] sd 3:0:0:0: [sdb] Write cache: enabled, read cache: enabled, doesn't support DPO or FUA
	[一 11月  4 18:06:47 2019]  sdb: sdb1 sdb2 < sdb5 >
	[一 11月  4 18:06:47 2019] sd 3:0:0:0: [sdb] Attached SCSI disk
	[一 11月  4 18:07:02 2019] EXT4-fs (sdb1): mounted filesystem without journal. Opts: (null)


复盘捞到的 syslog 日志

	Nov  4 18:06:57 vb systemd[1]: Device dev-disk-by\x2duuid-5241a10b\x2d5dde\x2d4051\x2d8d8b\x2d05718dd56445.device appeared twice with different sysfs paths /sys/devices/pci0000:00/0000:00:0d.0/ata4/host3/target3:0:0/3:0:0:0/block/sdb/sdb5 and /sys/devices/pci0000:00/0000:00:0d.0/ata5/host4/target4:0:0/4:0:0:0/block/sdc/sdc5
	Nov  4 18:06:57 vb kernel: [    6.754716] sd 4:0:0:0: [sdc] 104857600 512-byte logical blocks: (53.6 GB/50.0 GiB)
	Nov  4 18:06:57 vb kernel: [    6.754744] sd 4:0:0:0: [sdc] Write Protect is off
	Nov  4 18:06:57 vb kernel: [    6.754747] sd 4:0:0:0: [sdc] Mode Sense: 00 3a 00 00
	Nov  4 18:06:57 vb kernel: [    6.754757] sd 4:0:0:0: [sdc] Write cache: enabled, read cache: enabled, doesn't support DPO or FUA
	Nov  4 18:06:57 vb kernel: [    6.767797]  sdc: sdc1 sdc2 < sdc5 >
	Nov  4 18:06:57 vb kernel: [    6.768061] sd 4:0:0:0: [sdc] Attached SCSI disk


## 奇葩问题

virtualbox 太多命名其妙的问题了，争取早日换掉

### 磁盘uuid重复后，生成新的uuid

[/drives/c/Program Files/Oracle/VirtualBox]
$./VBoxManage.exe internalcommands sethduuid "D:\vb\ubuntu-disk.vmdk"

### Windows系统突然dns不工作了

VirtualBox为啥导致了这个问题就是一个很偏的方向，我实在无能为力了，尝试找到了一个和VirtualBox的DNS相关的开关命令，只能死马当活马医了（像极了算命大师和老中医）

    ./VBoxManage.exe  modifyvm "ubuntu" --natdnshostresolver1 on

### ubuntu 鼠标中键不能复制粘贴的恢复办法 gpointing-device-settings

http://askubuntu.com/questions/302077/how-to-enable-paste-in-terminal-with-middle-mouse-button


### ubuntu无法关闭锁屏，无法修改配置：

sudo mv ~/.config/dconf ~/.config/dconf.bak //删掉dconf就好了
https://unix.stackexchange.com/questions/296231/cannot-save-changes-made-in-gnome-settings


## 感受

自己不懂 /dev/sdb 导致了这次问题

这种错误居然从virtualbox或者ubuntu的系统日志中找不到相关信息，这个应该是没有触发挂载。自己对mount、fsck不够熟悉也是主要原因，运气好在fsck 居然没丢任何数据

## 历史老问题

这种额外挂载的磁盘在ubuntu下启动后不会出现，需要在ubuntu文件系统中人肉访问一次，就触发了挂载动作，然后在bash中才可以正常使用，这个问题我折腾了N年都没解决，实际这次发现是自己对挂载、fstab不够了解。

在 /etc/fstab 中增加boot时挂载这个问题终于解决掉了

	UUID=a64abcac-657d-42ee-8e7b-575eac99bce3 /media/ren/a64abcac-657d-42ee-8e7b-575eac99bce3  ext4 defaults 1 1






