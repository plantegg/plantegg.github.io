---
title: ipmitool 和 BIOS
date: 2020-01-01 12:30:03
categories: Linux
tags:
    - ipmi
    - BIOS
    - ipmitool
---

# ipmitool 和 BIOS

## 什么是 IPMI

IPMI（智能平台管理接口），Intelligent Platform Management Interface 的缩写。原本是一种[Intel](https://baike.baidu.com/item/Intel)架构的企业系统的周边设备所采用的一种工业标准。IPMI亦是一个开放的免费标准，用户无需支付额外的费用即可使用此标准。

IPMI 能够横跨不同的操作系统、固件和硬件平台，可以智能的监视、控制和自动回报大量服务器的运作状况，以降低服务器系统成本。



1998年Intel、DELL、HP及NEC共同提出IPMI规格，可以透过网路远端控制温度、电压。

2001年IPMI从1.0版改版至1.5版，新增 PCI Management Bus等功能。

2004年Intel发表了IPMI 2.0的规格，能够向下相容IPMI 1.0及1.5的规格。新增了Console Redirection，并可以通过Port、Modem以及Lan远端管理伺服器，并加强了安全、VLAN 和刀锋伺服器的支援性。



Intel/amd/hygon 基本都支持 ipmitool，看起来ARM 支持的接口也许不一样



BMC（Baseboard Management Controller）即我们常说的带外系统，是在机器上电时即完成自身初始化，开始运行。其系统可在standby电模式下工作。所以，通过带外监控服务器硬件故障，不受OS存活状态影响，可实现7*24小时无间断监控，甚至我们可以通过带外方式，精确感知带内存活，实现OS存活监控。

BMC在物理形态上，由一主嵌入式芯片+系列总线+末端芯片组成的一个硬件监控&控制系统，嵌入式芯片中运行嵌入式Linux操作系统，负责整个BMC系统的资源协调及用户交互，核心进程是IPMImain进程，实现了全部IPMI2.0协议的消息传递&处理工作。

## ipmitool 用法

基本步骤：

1. 查看当前值：ipmitool raw 0x3e 0x5f 0x00 0x11 （非必要，列出目前BIOS中的值）
2. 打开配置开关(让BIOS进入可配置，默认不可配置)：ipmitool raw 0x3e 0x5c 0x00 0x01 0x81
3. 修改某个值，比如将numa 设置为on：ipmitool raw 0x3e 0x5c 0x05 0x01 0x81
4. 查看修改后的值：ipmitool raw 0x3e 0x5d 0x05 0x01 (必须要)
5. 最后reboot机器新的值就会apply到BIOS中

[ipmitool使用](https://blog.csdn.net/zygblock/article/details/53367664)基本语法

```
         固定-不变 0x5c修改   要修改的项    长度(一搬都是01)    新的值(0x81 表示on、0x80表示off)
ipmitool raw 0x3e 0x5c      index       0x01                value
```

第1/2个参数raw 0x3e 固定不变

第三个参数表示操作可以是：

- 0x5c 修改
- 0x5f 查看BIOS中的当前值（海光是这样，intel不是）
- 0x5d 查询即将写入的值（修改后没有写入 0x5f 看到的是老值）  

第四个参数Index表示需要修改的配置项（具体见后表）

第五个参数 0x01 表示值的长度，一般固定不需要改

value 表示值，0x81表示enable; 0x80表示disable

### [ipmitool](https://promisechen.github.io/kbase/ipmi.html)带外设置步骤

1）设置valid flag：

ipmitool -I lan -U admin -P admin -H 192.168.1.10 raw 0x3e 0x5c 0x00 0x01 0x81

2） 设置对应的选项：

ipmitool -I lan -U admin -P admin -H 192.168.1.10 raw 0x3e 0x5c index 0x01 Data  ---- index 和Data参考下述表格；

3）重启CN：

ipmitool -I lan -U admin -P admin -H 192.168.1.10 power reset

4）读取当前值：

ipmitool -I lan -U admin -P admin -H 192.168.1.10  raw 0x3e 0x5f index 0x01 

 如moc机型，读取CN的 Numa值：

ipmitool -I lan -U admin -P admin -H 192.168.1.10 raw 0x3e 0x5f 0x05 0x01 

### 确认是否设置成功

查询要写入的新值：ipmitool 0x3e 0x5d 0x00 0x11

 返回值，如：11 **81** 81 00 00 00 00 00 00 00 00 00 00 00 00 00  00 00

​      第一个byte 表示查询数量，表示查询0x11个设置项；

 	 第二个byte 表示index=0的值，即Configuration，必须保证是0x81，才能进行重启，否则设置不生效；

​      第三个byte 表示index=1的值，即Turbo，表示要设置为0x81；

​      剩余byte依次类推..........

​      未设置新值的index对应值是00，要设置的index其对应值为Data（步骤3的设置值）；

## 海光服务器修改案例

```
//海光+alios下 第二列为：0x5c 修改、0x5f BIOS中的查询、0x5d 查询即将写入的值 
//0x5f 查询BIOS中的值

#ipmitool raw 0x3e 0x5f 0x00 0x11
 11 81 81 81 81 80 81 80 81 81 80 81 81 00 00 81
 80 81
 
//还没有写入任何新值
#ipmitool raw 0x3e 0x5d 0x00 0x11
 11 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
 00 00 

//enable numa
#ipmitool raw 0x3e 0x5c 0x00 0x01 0x81
#ipmitool raw 0x3e 0x5c 0x05 0x01 0x81

//enable boost
#ipmitool raw 0x3e 0x5c 0x01 0x01 0x81

#ipmitool raw 0x3e 0x5d 0x01 0x01
 11 81 
//关闭 SMT
#ipmitool raw 0x3e 0x5c 0x02 0x01 0x80

#ipmitool raw 0x3e 0x5d 0x02 0x01
 11 81 
```



## BIOS中选项的对应关系

### Intel服务器

| Name                                 | Index | Data Length（Bytes） | Data （不在列表中则为无效值）                                |
| ------------------------------------ | ----- | -------------------- | ------------------------------------------------------------ |
| Configuration                        | 0x00  | 1                    | 0x81 – valid Flag 0x82 – Restore Default Value (恢复为PRD定义的默认值)0x00  BIOS在读取设定后，会发送index=0x00，data=0x00的命令给BMC，BMC应清零所有参数值。 |
| Turbo                                | 0x01  | 1                    | 0x80 – disable0x81 – enable                                  |
| HT                                   | 0x02  | 1                    | 0x80 – disable0x81 – enable                                  |
| VT                                   | 0x03  | 1                    | 0x80 – disable0x81 – enable                                  |
| EIST                                 | 0x04  | 1                    | 0x80 – disable0x81 – enable                                  |
| Numa                                 | 0X05  | 1                    | 0x80 – disable 0x81 - enable                                 |
| Vendor Change                        | 0x06  | 1                    | 0x80 – disable0x81 – enable                                  |
| VT-d                                 | 0x07  | 1                    | 0x80 – disable0x81 – enable                                  |
| SRIOV                                | 0x08  | 1                    | 0x80 – disable0x81 – enable                                  |
| Active Video                         | 0x09  | 1                    | 0x80 – Onboard0x81 – PCIe                                    |
| Local HDD Boot                       | 0x0A  | 1                    | 0x80 – disable0x81 – enable                                  |
| Hotkey support                       | 0x0B  | 1                    | 0x80 – disable0x81 – enable                                  |
| Intel Speed Select                   | 0x0C  | 1                    | 0x80-Disable0x81-Config 10x82-Config 2                       |
| IMS                                  | 0x0D  | 1                    | 0x80-Disable0x81-Enable                                      |
| TPM                                  | 0x0E  | 1                    | 0x80-Disable0x81-Enabled0x83-Enable&Clear TPM                |
| Power off remove                     | 0x0F  | 1                    | 0x80 – disable – 响应命令0x81 – enable –不响应命令           |
| BIOS BOOT MODE                       | 0x10  | 1                    | 0x80 – Legacy0x81 – UEFI                                     |
| Active Cores                         | 0x11  | 1                    | 0x80 - Default Core Number0x81 - Active 1 Core0x82 - Active 2 Cores0x83 - Active 3 Cores…0xFE - Active 126 Cores |
| C   State                            | 0x12  | 1                    | 0x80-Disable0x81-Enable                                      |
| HWPM                                 | 0x13  | 1                    | 0x80-Disable0x81-Native   mode0x82-OOB   Mode0x83-Native   mode Without Legacy support |
| Intel   SgxSW Guard Extensions (SGX) | 0x14  | 1                    | 0x80-Disable0x81-Enable                                      |
| SGX PRMRR Size                       | 0x15  | 1                    | 0X80-[00]No valid PRMRR   size    0X81-[40000000]1G0X82-[80000000]2G0X83-[100000000]4G0X84-[200000000]8G0X85-[400000000]16G0X86-[800000000]32G0X87-[1000000000]64G0X88-[2000000000]128G0X89-[4000000000]256G0X8A-[8000000000]512G |
| SGX Factory Reset                    | 0x16  |                      | 0x80-Disable0x81-Enable                                      |
|                                      | 0x17  |                      | 预留                                                         |
| CPU0_IOU0 (IIO PCIe Br1)             | 0x18  | 1                    | 0x80 – x4x4x4x4   0x81 – x4x4x8   0x82 – x8x4x4   0x83 – x8x8   0x84 – x16   0x85 - Auto |
| CPU0_IOU1 (IIO PCIe Br2)             | 0x19  | 1                    | 同上                                                         |
| CPU0_IOU2 (IIO PCIe Br3)             | 0x1a  | 1                    | 同上                                                         |
| CPU0_IOU3 (IIO PCIe Br4)             | 0x1b  | 1                    | 同上                                                         |
| CPU0_IOU4 (IIO PCIe Br5)             | 0x1c  | 1                    | 同上                                                         |
| CPU1_IOU0 (IIO PCIe Br1)             | 0x1d  | 1                    | 同上                                                         |
| CPU1_IOU1 (IIO PCIe Br2)             | 0x1e  | 1                    | 同上                                                         |
| CPU1_IOU2 (IIO PCIe Br3)             | 0x1f  | 1                    | 同上                                                         |
| CPU1_IOU3 (IIO PCIe Br4)             | 0x20  | 1                    | 同上                                                         |
| CPU1_IOU4 (IIO PCIe Br5)             | 0x21  | 1                    | 同上                                                         |
| CPU2_IOU0 (IIO PCIe Br1)             | 0x22  | 1                    | 同上                                                         |
| CPU2_IOU1 (IIO PCIe Br2)             | 0x23  | 1                    | 同上                                                         |
| CPU2_IOU2 (IIO PCIe Br3)             | 0x24  | 1                    | 同上                                                         |
| CPU2_IOU3 (IIO PCIe Br4)             | 0x25  | 1                    | 同上                                                         |
| CPU2_IOU4 (IIO PCIe Br5)             | 0x26  | 1                    | 同上                                                         |
| CPU3_IOU0 (IIO PCIe Br1)             | 0x27  | 1                    | 同上                                                         |
| CPU3_IOU1 (IIO PCIe Br2)             | 0x28  | 1                    | 同上                                                         |
| CPU3_IOU2 (IIO PCIe Br3)             | 0x29  | 1                    | 同上                                                         |
| CPU3_IOU3 (IIO PCIe Br4)             | 0x2a  | 1                    | 同上                                                         |
| CPU3_IOU4 (IIO PCIe Br5)             | 0x2b  | 1                    | 同上                                                         |
| SGXLEPUBKEYHASHx Write Enable        | 0x2C  | 1                    | 0x80-Disable0x81-Enable                                      |
| SubNuma                              | 0x2D  | 1                    | 0x80-Disabled0x81-SN2                                        |
| VirtualNuma                          | 0x2E  | 1                    | 0x80-Disabled0x81-Enabled                                    |
| TPM Priority                         | 0x2F  | 1                    |                                                              |
| TDX                                  | 0x30  | 1                    | 0x80 - Disabled0x81 - Enabled                                |
| Select Owner EPOCH input type        | 0x31  | 1                    | 0x81-Change to New Random Owner EPOCHs0x82-Manual User Defined Owner EPOCHs |
| Software Guard Extensions Epoch 0    | 0x32  | 1                    |                                                              |
| Software Guard Extensions Epoch 1    | 0x33  | 1                    |                                                              |



### AMD服务器

| Name                   | Index | Data Length（Bytes） | Data （不在列表中则为无效值）                                | 支持项目  |
| ---------------------- | ----- | -------------------- | ------------------------------------------------------------ | --------- |
| Configuration          | 0x00  | 1                    | 0x81 – valid Flag 0x82 – Restore Default Value (恢复为PRD定义的默认值) | RomeMilan |
| Core Performance Boost | 0x01  | 1                    | 0x80 – disable0x81 – enable                                  | RomeMilan |
| SMT Mode               | 0x02  | 1                    | 0x80 – disable0x81 – enable                                  | RomeMilan |
| SVM Mode               | 0x03  | 1                    | 0x80 – disable0x81 – enable                                  | RomeMilan |
| EIST                   | 0x04  | 1                    | 0x80 (AMD默认支持智能调频但无此选项)                         | RomeMilan |
| NUMA nodes per socket  | 0X05  | 1                    | 0x80 – NPS0 0x81 – NPS1 0x82 – NPS2 0x83 – NPS4 （开）0x87 – Auto(Auto为NPS1) | RomeMilan |
| Vendor Change          | 0x06  | 1                    | 0x80 – disable0x81 – enable                                  | RomeMilan |
| IOMMU                  | 0x07  | 1                    | 0x80 – disable0x81 – enable0x8F – Auto                       | RomeMilan |
| SRIOV                  | 0x08  | 1                    | 0x80 – disable0x81 – enable                                  | RomeMilan |
| Active Video           | 0x09  | 1                    | 0x80 – Onboard0x81 – PCIe                                    | RomeMilan |
| Local HDD Boot         | 0x0A  | 1                    | 0x80 – disable0x81 – enable                                  | RomeMilan |
| Hotkey support         | 0x0B  | 1                    | 0x80 – disable0x81 – enable                                  | RomeMilan |
| Intel Speed Select     | 0x0C  | 1                    | 0x80 (AMD无此选项)                                           | RomeMilan |
| IMS                    | 0x0D  | 1                    | 0x80 (AMD暂未做IMS功能)                                      | RomeMilan |
| TPM                    | 0x0E  | 1                    | 0x80 – disable0x81 – enable0x83 – enable & TPM   clear       | RomeMilan |
| Power off remove       | 0x0F  | 1                    | 0x80 (AMD暂未做此功能)                                       | RomeMilan |
| BIOS BOOT MODE         | 0x10  | 1                    | 0x80 – Legacy0x81 – UEFI                                     | RomeMilan |

### 海光服务器

| Name                   | Index | Data Length（Bytes） | Data （不在列表中则为无效值）                                | 支持项目 |
| ---------------------- | ----- | -------------------- | ------------------------------------------------------------ | -------- |
| Configuration          | 0x00  | 1                    | 0x81 – valid Flag 0x82 – Restore Default Value (恢复为PRD定义的默认值) | 海光2    |
| Core Performance Boost | 0x01  | 1                    | 0x80 – disable0x81 – enable                                  | 海光2    |
| SMT                    | 0x02  | 1                    | 0x80 – disable0x81 – enable                                  | 海光2    |
| SVM                    | 0x03  | 1                    | 0x80 – disable0x81 – enable                                  | 海光2    |
| P-State Control        | 0x04  | 1                    | 0x80 – Performance0x81 – Normal                              | 海光2    |
| Memory Interleaving    | 0X05  | 1                    | 0x80 – Socket (关numa) 0x81 - channel（8 node）              | 海光2    |
| Vendor Change          | 0x06  | 1                    | 0x80 – disable0x81 – enable                                  | 海光2    |
| IOMMU                  | 0x07  | 1                    | 0x80 – disable0x81 – enable                                  | 海光2    |
| SRIOV                  | 0x08  | 1                    | 0x80 – disable0x81 – enable                                  | 海光2    |
| Onboard VGA            | 0x09  | 1                    | 0x80 – Onboard0x81 – PCIe                                    | 海光2    |
| Local HDD Boot         | 0x0A  | 1                    | 0x80 – disable0x81 – enable                                  | 海光2    |
| Hotkey support         | 0x0B  | 1                    | 0x80 – disable0x81 – enable                                  | 海光2    |
| Hygon平台没有此选项    | 0x0C  | 1                    | 0x80-Disable0x81-Config 10x82-Config 2                       | 不支持   |
| Hygon平台没有此选项    | 0x0D  | 1                    | 0x80-Disable0x81-Enable                                      | 不支持   |
| TPM                    | 0x0E  | 1                    | 0x80-Disable0x81-Enabled0x83-Enable&Clear TPM                | 海光2    |
| Power off remove       | 0x0F  | 1                    | 0x80 – disable – 响应命令0x81 – enable –不响应命令           | 海光2    |
| Boot option Filter     | 0x10  | 1                    | 0x80 – Legacy0x81 – UEFI                                     | 海光2    |

