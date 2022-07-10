---
title: 定制Linux Kernel
date: 2019-01-24 17:30:03
categories: Linux
tags:
    - Linux
    - kernel
---

# 定制Linux Kernel

## 修改启动参数

```shell
$cat change_kernel_parameter.sh 
#cat /sys/devices/system/cpu/vulnerabilities/*
#grep '' /sys/devices/system/cpu/vulnerabilities/*
#https://help.aliyun.com/document_detail/102087.html?spm=a2c4g.11186623.6.721.4a732223pEfyNC

#cat /sys/kernel/mm/transparent_hugepage/enabled
#transparent_hugepage=always
#noibrs noibpb nopti nospectre_v2 nospectre_v1 l1tf=off nospec_store_bypass_disable no_stf_barrier mds=off mitigations=off
#追加nopti nospectre_v2到内核启动参数中
sudo sed -i 's/\(GRUB_CMDLINE_LINUX=".*\)"/\1 nopti nospectre_v2 nospectre_v1 l1tf=off nospec_store_bypass_disable no_stf_barrier mds=off mitigations=off transparent_hugepage=always"/' /etc/default/grub

//从修改的 /etc/default/grub 生成 /boot/grub2/grub.cfg 配置
sudo grub2-mkconfig -o /boot/grub2/grub.cfg

#limit the journald log to 500M
sed -i 's/^#SystemMaxUse=$/SystemMaxUse=500M/g' /etc/systemd/journald.conf
#重启系统
#sudo reboot

## 选择不同的kernel启动
#sudo grep "menuentry " /boot/grub2/grub.cfg | grep -n menu
##grub认的index从0开始数的
#sudo grub2-reboot 0; sudo reboot
or
#grub2-set-default "CentOS Linux (3.10.0-1160.66.1.el7.x86_64) 7 (Core)" ; sudo reboot
```

## 修改是否启用透明大页

```
$cat /sys/kernel/mm/transparent_hugepage/enabled
always [madvise] never
```

## 制作启动盘

Windows 上用 UltraISO 烧制，Mac 上就比较简单了，直接用 dd 就可以搞

```
$ diskutil list
/dev/disk6 (external, physical):
   #:                       TYPE NAME                    SIZE       IDENTIFIER
   0:                                                   *31.5 GB    disk6
                        
# 找到 U 盘的那个设备，umount
$ diskutil unmountDisk /dev/disk3

# 用 dd 把 ISO 文件写进设备，注意这里是 rdisk3 而不是 disk3，在 BSD 中 r(IDENTIFIER)
# 代表了 raw device，会快很多
$ sudo dd if=/path/image.iso of=/dev/rdisk3 bs=1m

# 弹出 U 盘
$ sudo diskutil eject /dev/disk3
```

[Linux 下制作步骤](https://linuxiac.com/how-to-create-bootable-usb-drive-using-dd-command/)

```
umount /dev/sdn1
sudo mkfs.vfat /dev/sdn1
dd if=/data/uniontechos-server-20-1040d-amd64.iso of=/dev/sdn1 status=progress
```

## 定制内存

物理内存700多G，要求OS只能用512G：

```
24条32G的内存条，总内存768G
# dmidecode -t memory |grep "Size: 32 GB"
  Size: 32 GB
…………
  Size: 32 GB
  Size: 32 GB
root@uos15:/etc# dmidecode -t memory |grep "Size: 32 GB" | wc -l
24

# cat /boot/grub/grub.cfg  |grep 512
  linux /vmlinuz-4.19.0-arm64-server root=UUID=dbc68010-8c36-40bf-b794-271e59ff5727 ro  splash quiet console=tty video=VGA-1:1280x1024@60 mem=512G DEEPIN_GFXMODE=$DEEPIN_GFXMODE
    linux /vmlinuz-4.19.0-arm64-server root=UUID=dbc68010-8c36-40bf-b794-271e59ff5727 ro  splash quiet console=tty video=VGA-1:1280x1024@60 mem=512G DEEPIN_GFXMODE=$DEEPIN_GFXMODE
```

### 高级版 [按numa限制内存](https://www.kernel.org/doc/html/v4.14/admin-guide/kernel-parameters.html)

每个numa 128G内存，总共1024G（32条*32G），8个numa node，需要将每个numa node内存限制在64G

在grub中cmdline中加入如下配置，每个node只用64G内存：

```
memmap=64G\$64G memmap=64G\$192G memmap=64G\$320G memmap=64G\$448G memmap=64G\$576G memmap=64G\$704G memmap=64G\$832G memmap=64G\$960G
```

或者：

```
#cat /etc/default/grub
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="$(sed 's, release .*$,,g' /etc/system-release)"
GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU=true
GRUB_TERMINAL_OUTPUT="console"
GRUB_CMDLINE_LINUX="crashkernel=1024M,high resume=/dev/mapper/klas-swap rd.lvm.lv=klas/root rd.lvm.lv=klas/swap video=efifb:on rhgb quiet quiet noibrs noibpb nopti nospectre_v2 nospectre_v1 l1tf=off nospec_store_bypass_disable no_stf_barrier mds=off tsx=on tsx_async_abort=off mitigations=off iommu.passthrough=1 memmap=64G\\\$64G memmap=64G\\\$192G memmap=64G\\\$320G memmap=64G\\\$448G memmap=64G\\\$576G memmap=64G\\\$704G memmap=64G\\\$832G memmap=64G\\\$960G"
GRUB_DISABLE_RECOVERY="true"

然后执行生成最终grub启动参数
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
```

比如在一个4node的机器上，总共768G内存（32G*24），每个node使用64G内存

```
linux16 /vmlinuz-0-rescue-e91413f0be2c4c239b4aa0451489ae01 root=/dev/mapper/centos-root ro crashkernel=auto rd.lvm.lv=centos/root rd.lvm.lv=centos/swap rhgb quiet memmap=128G\$64G memmap=128G\$256G memmap=128G\$448G memmap=128G\$640G
```

128G表示相对地址，$64G是绝对地址，128G\\$64G 的意思是屏蔽64G到（64+128）G的地址对应的内存

## 内存信息

```
#dmidecode -t memory
# dmidecode 3.2
Getting SMBIOS data from sysfs.
SMBIOS 3.2.1 present.
# SMBIOS implementations newer than version 3.2.0 are not
# fully supported by this version of dmidecode.

Handle 0x0033, DMI type 16, 23 bytes 
Physical Memory Array
	Location: System Board Or Motherboard
	Use: System Memory
	Error Correction Type: Multi-bit ECC
	Maximum Capacity: 2 TB  //最大支持2T
	Error Information Handle: 0x0032
	Number Of Devices: 32   //32个插槽
	
	Handle 0x0041, DMI type 17, 84 bytes
Memory Device
	Array Handle: 0x0033
	Error Information Handle: 0x0040
	Total Width: 72 bits
	Data Width: 64 bits
	Size: 32 GB
	Form Factor: DIMM
	Set: None
	Locator: CPU0_DIMMA0
	Bank Locator: P0 CHANNEL A
	Type: DDR4
	Type Detail: Synchronous Registered (Buffered)
	Speed: 2933 MT/s                    //内存最大频率
	Manufacturer: SK Hynix
	Serial Number: 220F9EC0
	Asset Tag: Not Specified
	Part Number: HMAA4GR7AJR8N-WM
	Rank: 2
	Configured Memory Speed: 2400 MT/s  //内存实际运行速度--比如海光CPU内存太多会给内存降频
	Minimum Voltage: 1.2 V
	Maximum Voltage: 1.2 V
	Configured Voltage: 1.2 V
	Memory Technology: DRAM
	Memory Operating Mode Capability: Volatile memory
	Module Manufacturer ID: Bank 1, Hex 0xAD
	Non-Volatile Size: None
	Volatile Size: 32 GB
	
	#lshw
	*-bank:19  
             description: DIMM DDR4 Synchronous Registered (Buffered) 2933 MHz (0.3 ns) //内存最大频率
             product: HMAA4GR7AJR8N-WM
             vendor: SK Hynix
             physical id: 13
             serial: 220F9F63
             slot: CPU1_DIMMB0
             size: 32GiB  //实际所插内存大小
             width: 64 bits
             clock: 2933MHz (0.3ns)
```

### 内存速度对延迟的影响

左边两列是同一种机型和CPU、内存，只是最左边的开了numa，他们的内存Speed: 2400 MT/s，但是实际运行速度是2133；最右边的是另外一种CPU，内存速度更快，用mlc测试他们的延时、带宽。可以看到V52机型带宽能力提升特别大，时延变化不大

![image-20220123094155595](/images/951413iMgBlog/image-20220123094155595.png)

![image-20220123094928794](/images/951413iMgBlog/image-20220123094928794.png)

![image-20220123100052242](/images/951413iMgBlog/image-20220123100052242.png)

对比一下V62，intel8269 机型

```
./Linux/mlc
Intel(R) Memory Latency Checker - v3.9
Measuring idle latencies (in ns)...
    Numa node
Numa node      0       1
       0    77.9   143.2
       1   144.4    78.4

Measuring Peak Injection Memory Bandwidths for the system
Bandwidths are in MB/sec (1 MB/sec = 1,000,000 Bytes/sec)
Using all the threads from each core if Hyper-threading is enabled
Using traffic with the following read-write ratios
ALL Reads        :  225097.1
3:1 Reads-Writes :  212457.8
2:1 Reads-Writes :  210628.1
1:1 Reads-Writes :  199315.4
Stream-triad like:  190341.4

Measuring Memory Bandwidths between nodes within system
Bandwidths are in MB/sec (1 MB/sec = 1,000,000 Bytes/sec)
Using all the threads from each core if Hyper-threading is enabled
Using Read-only traffic type
    Numa node
Numa node      0       1
       0  113139.4  50923.4
       1  50916.6 113249.2

Measuring Loaded Latencies for the system
Using all the threads from each core if Hyper-threading is enabled
Using Read-only traffic type
Inject  Latency Bandwidth
Delay (ns)  MB/sec
==========================
 00000  261.50   225452.5
 00002  263.79   225291.6
 00008  269.02   225184.1
 00015  261.96   225757.6
 00050  260.56   226013.2
 00100  264.27   225660.1
 00200  130.61   195882.4
 00300  102.65   133820.1
 00400   95.04   101353.2
 00500   91.56    81585.9
 00700   87.94    58819.1
 01000   85.54    41551.3
 01300   84.70    32213.6
 01700   83.14    24872.5
 02500   81.74    17194.3
 03500   81.14    12524.2
 05000   80.74     9013.2
 09000   80.09     5370.0
 20000   78.92     2867.2

Measuring cache-to-cache transfer latency (in ns)...
Local Socket L2->L2 HIT  latency  51.6
Local Socket L2->L2 HITM latency  51.7
Remote Socket L2->L2 HITM latency (data address homed in writer socket)
      Reader Numa Node
Writer Numa Node     0       1
            0      -   111.3
            1  111.1       -
Remote Socket L2->L2 HITM latency (data address homed in reader socket)
      Reader Numa Node
Writer Numa Node     0       1
            0      -   175.8
            1  176.7       -

[root@numaopen.cloud.et93 /home/xijun.rxj]
#lscpu
Architecture:          x86_64
CPU op-mode(s):        32-bit, 64-bit
Byte Order:            Little Endian
CPU(s):                104
On-line CPU(s) list:   0-103
Thread(s) per core:    2
Core(s) per socket:    26
Socket(s):             2
NUMA node(s):          2
Vendor ID:             GenuineIntel
CPU family:            6
Model:                 85
Model name:            Intel(R) Xeon(R) Platinum 8269CY CPU @ 2.50GHz
Stepping:              7
CPU MHz:               3199.902
CPU max MHz:           3800.0000
CPU min MHz:           1200.0000
BogoMIPS:              4998.89
Virtualization:        VT-x
L1d cache:             32K
L1i cache:             32K
L2 cache:              1024K
L3 cache:              36608K
NUMA node0 CPU(s):     0-25,52-77
NUMA node1 CPU(s):     26-51,78-103

#dmidecode -t memory
Handle 0x003C, DMI type 17, 40 bytes
Memory Device
  Array Handle: 0x0026
  Error Information Handle: Not Provided
  Total Width: 72 bits
  Data Width: 64 bits
  Size: 32 GB
  Form Factor: DIMM
  Set: None
  Locator: CPU1_DIMM_E1
  Bank Locator: NODE 2
  Type: DDR4
  Type Detail: Synchronous
  Speed: 2666 MHz
  Manufacturer: Samsung
  Serial Number: 14998029
  Asset Tag: CPU1_DIMM_E1_AssetTag
  Part Number: M393A4K40BB2-CTD
  Rank: 2
  Configured Clock Speed: 2666 MHz
  Minimum Voltage:  1.2 V
  Maximum Voltage:  1.2 V
  Configured Voltage:  1.2 V
```

