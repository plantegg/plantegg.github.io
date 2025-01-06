# wireshark 插件

尝试从最简单的角度来实现一个自定义的 Wireshark 插件，并对自定义的协议进行解析

## Wireshark 插件编写

### 插件编写步骤

1.  定义Proto。
1.  定义Proto中每一个ProtoField并定要到Proto的fields结构。
1.  实现Proto的dissector方法。
1.  将自定义的Proto通过DissectorTable添加到协议列表中。

基本都看不懂，接着往下看上面步骤里涉及到的概念，也可以直接跳到后面的 vtoa 插件代码，先去试着跑一下这个插件代码然后再考虑回来看插件的编写步骤和概念

### 基本概念

Proto：定义一个新的协议。

ProtoField：Proto中的每一个域的定义。

Proto的dissector方法: 解析Proto的方法。

![image-20241220110145871](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io@_md2zhihu_blog_04540fc6/wireshark插件/7261e759f2f47e85-image-20241220110145871.png)

ProtoField 有两大类：

-   **整型**:

​	ProtoField.{type} (abbr, [name], [desc],[base], [valuestring], [mask])

​	type包括：uint8, uint16, uint24, uint32, uint64, framenum

-   **其他类型**

​	ProtoField.{type} (abbr, [name], [desc])

​	type包括：float, double, string, stringz, bytes, bool, ipv4, ipv6, ether,oid, guid

﻿[DissectorTable](https://documentation.help/Wireshark/lua_module_Proto.html#lua_class_DissectorTable)：集合一系列相关协议的表，比如http, smtp, sip 被添加到 "tcp.port"，自定义的协议最终也会被添加到这样一个table才能被识别。

﻿[Dissector](https://documentation.help/Wireshark/lua_module_Proto.html#lua_class_DissectorTable)：解析器，我们也可以调用一些已有的解析器，比如：

展示数据的解析器

```
Dissector.get("data"):call(buffer(index):tvb(), pinfo, tree)
```

再比如解析ip报文的解析器

```
Dissector.get("ip"):call(buffer(index+4, payloadLen):tvb(), pinfo, tree)
```

### 解析器（Dissector）和post-dissectors

1）解析器（Dissector）是用来被wireshark调用解析数据包或部分数据包的
2）解析器注册分为很多种，可以使用函数register_postdissector(trivial_proto)注册为postdissectors，即在所有解析器执行完后执行；也可以在DissectorTable上注册，这样就可以使用wireshark自带的上一层协议解析后的结果。

### 插件路径

macOS 上init.lua 默认在：

```
/Applications/WireShark.app/Contents/Resources/share/wireshark/init.lua
```

Global Lua Plugins 默认在：

```
/Applications/Wireshark.app/Contents/PlugIns/wireshark/3-0
```

当然最好的方式是通过如下图所示来查看插件具体存放在哪里：

![image-20241223173901942](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io@_md2zhihu_blog_04540fc6/wireshark插件/f79c294fff65e7e4-image-20241223173901942.png)

### 插件调试

加载插件：重启 Wireshark 或 点击 Analyze->Reload Lua Plugins(mac上快捷键 command+shift+L)即可加载插件。

调试信息的输出：

1.  插件脚本中添加print() 输出指定的信息

1.  wireshark中依次点击Tools->Lua-Console，重新加载插件后会在窗口出现打印结果。

我个人在 MacOS 下喜欢这样调试：

```
//写个脚本 /usr/local/bin/wsopen，来打开 Wireshark 内容如下：
cat /usr/local/bin/wsopen
#! /bin/sh
/Applications/Wireshark.app/Contents/MacOS/Wireshark "$@"&
```

主要是方便快捷，比如我想用 wireshark 打开 ~/Downloads/vtoa.pcap 只需在命令行里要执行：

```
# wsopen ~/Downloads/vtoa.pcap
//以下是输出的 Debug 信息
 (wireshark:76420) 17:13:31.609917 [GUI WARNING] -- Populating font family aliases took 71 ms. Replace uses of missing font family ".AppleSystemUIFont" with one that exists to avoid this cost.
vtoa info:	252	20	TVB(18) : a85e0a0a05384fa82c000a0a08d00cea0101
debug/252 client:	a85e	0a0a0538	0a0a08d0	0cea
vtoa info:	2	4	TVB(2) : 05b4
vtoa info:	3	3	TVB(1) : 09
vtoa info:	2	4	TVB(2) : 05b4
vtoa info:	3	3	TVB(1) : 07
vtoa info:	252	20	TVB(18) : a85e0a0a05384fa82c000a0a08d00cea0101
debug/252 client:	a85e	0a0a0538	0a0a08d0	0cea
vtoa info:	252	20	TVB(18) : a85e0a0a05384fa82c000a0a08d00cea0101
debug/252 client:	a85e	0a0a0538	0a0a08d0	0cea
vtoa info:	2	4	TVB(2) : 05b4
vtoa info:	3	3	TVB(1) : 09
vtoa info:	2	4	TVB(2) : 05b4
vtoa info:	3	3	TVB(1) : 07
vtoa info:	252	20	TVB(18) : a85e0a0a05384fa82c000a0a08d00cea0101
debug/252 client:	a85e	0a0a0538	0a0a08d0	0cea
vtoa info:	252	20	TVB(18) : a85e0a0a05384fa82c000a0a08d00cea0101
debug/252 client:	a85e	0a0a0538	0a0a08d0	0cea
vtoa info:	2	4	TVB(2) : 05b4
vtoa info:	3	3	TVB(1) : 09
vtoa info:	252	20	TVB(18) : a85e0a0a05384fa82c000a0a08d00cea0101
debug/252 client:	a85e	0a0a0538	0a0a08d0	0cea
vtoa info:	2	4	TVB(2) : 05b4
vtoa info:	3	3	TVB(1) : 09
vtoa info:	2	4	TVB(2) : 05b4
vtoa info:	3	3	TVB(1) : 07
vtoa info:	252	20	TVB(18) : a85e0a0a05384fa82c000a0a08d00cea0101
debug/252 client:	a85e	0a0a0538	0a0a08d0	0cea
vtoa info:	252	20	TVB(18) : a85e0a0a05384fa82c000a0a08d00cea0101
debug/252 client:	a85e	0a0a0538	0a0a08d0	0cea
vtoa info:	2	4	TVB(2) : 05b4
vtoa info:	3	3	TVB(1) : 09
vtoa info:	2	4	TVB(2) : 05b4
vtoa info:	3	3	TVB(1) : 07
vtoa info:	252	20	TVB(18) : a85e0a0a05384fa82c000a0a08d00cea0101
debug/252 client:	a85e	0a0a0538	0a0a08d0	0cea
2024-12-23 17:13:38.208 Wireshark[76420:1456272] WARNING: Secure coding is not enabled for restorable state! Enable secure coding by implementing NSApplicationDelegate.applicationSupportsSecureRestorableState: and returning YES.
```

这部分请结合文章最后的插件代码来验证

最后通过一个具体实例，来完成在 Wireshark 中通过插件来解析 tcp options 中的内容

如果到这里完全看不懂也是正常的，毕竟丢出来一大堆流程和概念，可以直接跳到插件代码部分，把代码保存后直接 Debug 看效果，然后再回头看前面的步骤和概念

## 解析 tcp options 的 vtoa 信息

### vtoa 格式说明

客户端经过 LVS 访问 RS（Real Server 代表真正提供服务的节点） 时一般 RS 看到的时 LVS 节点的 IP，但是在很多业务中需要知道真正的 client ip（比如记日志，希望记录真正的 IP 这样可以和客户端联动排查问题）

于是很多 LVS 服务提供将 client ip 传递给 RS，怎么传？一般是通过在 tcp options 中添加进去，然后在 RS 机器上安装组件将 tcp options 中的内容解析并还原成 client ip。

![image-20241227095746990](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io@_md2zhihu_blog_04540fc6/wireshark插件/d221fd145ea5558b-image-20241227095746990.png)

那我们通过 tcpdump 抓包还是看不到 client ip，为了排查问题方便需要在 Wireshark 中通过插件将 tcp options 解析出来，所以本节就是完成这样一个插件。在完成插件之前我们要了解 tcp options 塞进去的 client ip 的格式。

进一步了解这些概念的话，可以看看描述：

> 1.  toa模块主要用在Classic网络SLB/ALB的FNAT场景下后端RS（NC）获取实际Client端的真实地址和端口（FNAT模式下SLB/ALB发送给后端RS的报文中源IP已经被替换为SLB/ALB的localIP，将ClientIP[后续简写为cip]通过tcp option携带到RS），用户通过特定getpeername接口获取cip。toa模块已经内置到ali内核版本中，无需再单独安装（见/lib/modules/`uname -r`/kernel/net/toa/toa.ko）。
> 1.  vtoa(全称是Vpc Tcp Option Address)模块属于增强版toa，同时支持VPC网络和Classic网络SLB/ALB的FNAT场景下后端RS获取实际客户端的真实地址和端口（FNAT模式下SLB/ALB发送给后端RS的报文中源IP已经被替换为SLB/ALB的localIP，将cip通过tcp option携带到RS），用户通过特定getsockopt接口获取vid:vip:vport和cip:cport，兼容toa接口
> 1.  ctk: 包括ALB_ctk_debugfs.ko，ALB_ctk_session.ko，ALB_ctk_proxy.ko模块。ctk是一个NAT模块，对于ENAT场景，从ALB过来的带tcp option的tcp流量（cip:cport<->rip:rport带vip:vport opt）做了DNAT和反向DNAT转换，使得到上层应用层时看到的流被恢复为原始形态（cip:cport<->vip:vport）
> 1.  vctk:VPC NGLB模式下，只有建立TCP连接的首包（SYN包）经过ALB转发,后端vctk做Local的SNAT（避免VPC间地址冲突）和DNAT, 返回包做反向SNAT和DNAT转换，再做VXLAN封装，直接返回Source NC。


TCP 协议包头，注意从 20 开始的地方：TCP Options

![](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io@_md2zhihu_blog_04540fc6/wireshark插件/3717b29d0be60da6-c2ee1795-5e48-4e82-b896-4e3a24d6d9ee.png)

（图片来源：[https://nmap.org/book/tcpip-ref.html](https://nmap.org/book/tcpip-ref.html)）

在不同的场景下LVS 需要传递的信息不一样，根据传递的信息内容目前 vtoa option 有5种：TCPOPT_TOA，TCPOPT_TOA_VIP，TCPOPT_VTOA，TCPOPT_V6VTOA，TCPOPT_TOA_V6

<table>
<tr>
<th>名称</th>
<th>opcode</th>
<th>客户端地址类型</th>
<th>后端server支持</th>
<th>备注</th>
</tr>
<tr>
<td>TCPOPT_TOA</td>
<td>254</td>
<td>ipv4</td>
<td>ipv4/ipv6</td>
<td>携带cip/cport信息，地址为ipv4格式，<strong>可以嵌套 TCPOPT_TOA_VIP</strong></td>
</tr>
<tr>
<td>TCPOPT_TOA_VIP</td>
<td>250</td>
<td>ipv4</td>
<td>ipv4/ipv6</td>
<td>携带vip/vport信息，地址为ipv4格式</td>
</tr>
<tr>
<td>TCPOPT_VTOA</td>
<td>252</td>
<td>ipv4</td>
<td>ipv4</td>
<td>携带cip/cport/vip/vport信息，地址为ipv4格式</td>
</tr>
<tr>
<td>TCPOPT_V6VTOA</td>
<td>249</td>
<td>ipv6</td>
<td>ipv4/ipv6</td>
<td>携带cip/cport/vip/vport信息，地址为ipv6格式</td>
</tr>
<tr>
<td>TCPOPT_TOA_V6</td>
<td>253</td>
<td>ipv6</td>
<td>ipv6</td>
<td>携带cip/cport信息，地址为ipv6格式</td>
</tr>
</table>

**我们这次只关注 252，也就是 TCPOPT_VTOA**

vtoa 252 格式说明(LVS  fullnat 时 LVS 就会传递 252 的内容)：

vtoa 252 说明(16 进制)：fc：252 (下图红框) 14：长度(对应 10 进制的 20)   b3a2: cport 45986  0a 0a 03 d0 : caddr 10.10.3.208  0a0a08d0: vaddr 10.0.8.208（LVS 对外 ip）  0cea: vport 3306（LVS 对外端口）

![image-20241219135417002](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io@_md2zhihu_blog_04540fc6/wireshark插件/764a4ababbe7ee0b-image-20241219135417002.png)

TCPOLEN_VTOA 20         /* |opcode|size|cport+cip+vid+vip+vport+pad[2]| = 1 + 1 + 16 + 2 */

![img](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io@_md2zhihu_blog_04540fc6/wireshark插件/94929890b921ba67-1605077931817-63e21d90-33cb-44df-9442-906daf66ae32.png)

[254 定义](https://github.com/alibaba/LVS/blob/master/kernel/net/toa/toa.h#L39)如下(可忽略)：

```
#define TCPOPT_TOA  254
/* MUST be 4n !!!! */
#define TCPOLEN_TOA 8		/* |opcode|size|ip+port| = 1 + 1 + 6 */
/* MUST be 4 bytes alignment */
struct toa_data {
    __u8 opcode;
    __u8 opsize;
    __u16 port;
    __u32 ip;
};
```

### 解析效果

最终插件运行解析效果如下：

![image-20241220110145871](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io@_md2zhihu_blog_04540fc6/wireshark插件/7261e759f2f47e85-image-20241220110145871.png)

其中：b3a2 0a0a03d8 4fa82c00 0a0a08d0 0cea 0101 是主要内容， b3a2 是 client port 对应十进制：45986 ；0a0a03d8 是客户端 ip 10.10.3.216

### 插件代码

搞清楚了以上 254/252的格式以及 wireshark 插件的基本步骤和概念后，就可以写如下解析代码了：

```lua
--- Proto：定义一个新的协议
local vtoa_protocol = Proto("vtoa","Parse VTOA Protocol")
local tcp_opts = Field.new("tcp.options")

--- ProtoField：Proto中的每一个域的定义
local vtoa_client_ip = ProtoField.ipv4("vtoa.client_ip", "Client IP Address")
local vtoa_client_port = ProtoField.uint16("vtoa.cport", "Client port")
local vtoa_vip = ProtoField.ipv4("vtoa.vip", "LVS Address")
local vtoa_vport = ProtoField.uint16("vtoa.vport", "LVS port")
local vtoa_client_ipv6 = ProtoField.ipv6("vtoa.client_ipv6", "Client IPv6 Address")
local vtoa_vipv6 = ProtoField.ipv6("vtoa.vipv6", "VIPv6 Address")

vtoa_protocol.fields = {
        vtoa_client_ip,
        vtoa_client_port,
        vtoa_vip,
        vtoa_vport,
        vtoa_client_ipv6,
        vtoa_vipv6
}

--- 以下几个 parse 函数针对不同的 vtoa 类型(252/254/250/249)进行解析
--- vtoa 252 TCPOLEN_VTOA 20  |opcode|size|cport+cip+vid+vip+vport+pad[2]|=1+1+ 2+4+4+4+2 +2
function parse_252(v, subtree)
        local cport = v:range(0,2)
        local client_ip = v:range(2, 4)
        local vaddr_ip= v:range(10,4)
        local vport = v:range(14,2)
        print("debug/252 client:", cport, client_ip, vaddr_ip, vport)
    			
    		---将取到的 client ip 展示到 Wireshark 窗口里
        subtree:add(vtoa_client_ip, client_ip)
        subtree:add(vtoa_client_port, cport)
        subtree:add(vtoa_vip, vaddr_ip)
        subtree:add(vtoa_vport, vport)
end

function parse_254(v, subtree)
        local magic = v:range(0, 2):uint()
        local client_ip = v:range(2, 4)
        print("debug/254 client:", magic, client_ip)
        subtree:add(vtoa_client_ip, client_ip)
end

function parse_250(v, subtree)
        local magic = v:range(0, 2):uint()
        local vip = v:range(2, 4)
        print("debug/250 client:", magic, vip)
        subtree:add(vtoa_vip, vip)
end

function parse_249(v, subtree)
        local vip = v:range(0, 16)
        print("debug/249 client ipv6:", vip)
        subtree:add(vtoa_vipv6, vip)
        local client_ip = v:range(16, 16)
        print("debug/249 client ipv6:", client_ip)
        subtree:add(vtoa_client_ipv6, client_ip)
end

--- Proto的dissector方法: 解析Proto的方法
--[[参数：
buffer是 A Tvbobject，是报文序列化后的一个buf信息。
pinfo是 A Pinfoobject，是数据包信息，比如pinfo.cols.protocol可以添加显示protocol列信息, 对于udp这样的数据报该结构用的还不多，但是tcp这样流式的报文，为了在多个错乱的流中切分出完整的私有报文就要和pinfo打交道了。
tree是A TreeItemobject，是详情面板中的相关。
]]
function vtoa_protocol.dissector(buffer, pinfo, tree)
        local subtree = nil
        local opts = tcp_opts()
        if (opts) then
                local len = opts.len
                local off = 0
                while (off < len)
                do
                        local t = opts.range(off, 1):uint()
                        if (t == 1 or t == 0) then
                                off = off + 1
                        else
                                local l = opts.range(off + 1, 1):uint()
                                if (l ~= 2) then
                                        local v = opts.range(off + 2, l - 2):tvb()

                                        print("vtoa info:", t, l, v)
                                        if (subtree == nil and t >248 and t<255) then
                                                subtree = tree:add(vtoa_protocol, string.format("VTOA Protocol: %d", t))
                                                -- 单独再次添加 vtoa_type 是希望可以在过滤器中搜索匹配，但不展示
                                                local vtoa_type_item = subtree:add(vtoa_type, t)
                                                -- 只隐藏 vtoa_type,因为已经在 head 部分显示了，不再单独展示
                                                vtoa_type_item:set_hidden(true)
                                                -- 这行隐藏单独的整个 subtree，但仍然可以在过滤器中搜索匹配
                                                --subtree:set_hidden(true)  
                                        end
                                        if (t == 254 and l == 8) then
                                                parse_254(v, subtree)
                                        end
                                        if (t == 252 and l == 20) then
                                                parse_252(v, subtree)
                                        end
                                        if (t == 250 and l == 8) then
                                                parse_250(v, subtree)
                                        end
                                        if (false and t == 249 and l >= 40) then
                                                parse_249(v, subtree)
                                        end
                                end
                                off = off + l
                        end
                end
        end
end

register_postdissector(vtoa_protocol)
```

将以上代码保存为：~/.local/lib/wireshark/plugins/toa.lua 就可以调试这个 Wireshark 插件了：

![image-20241223171811426](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io@_md2zhihu_blog_04540fc6/wireshark插件/128fc8de3eb43d0c-image-20241223171811426.png)

然后用上一节中插件调试的命令就可以看到 Debug 信息，在 Wireshark 中也能看到解析后的 IP 了

```
wsopen ~/Downloads/vtoa.pcap
```

[Tvb（Testy Virtual Buffer）表示报文缓存](https://www.cnblogs.com/zzqcn/p/4827337.html)，也就是实际的报文数据

接下来可以找下网络上实现的 Dubbo 等插件，代码都不长，按照最前面的插件编写步骤还是比较好理解，剩下的就是理解协议内容每一个 byte 都表示什么意思了

![image-20241231100749378](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io@_md2zhihu_blog_04540fc6/wireshark插件/dc8aaee1e457037d-image-20241231100749378.png)

## 最简洁的学习方式

直接将这个带 vtoa 网络包下载下来，然后将上面的 lua 插件代码保存到本地 lua 插件目录下，再用 Wireshark 打开网络包，就可以看到插件的工作工程了，并不断修改插件，按照调试部分给出的方式不断验证

另外没有人天天需要写 Wireshark 插件，所以这个不需要特别去学习和记忆，但是需要你在自己的工具箱里备一份(案例)，需要的时候可以随时基于这个案例修改修改就能解析你自己的协议就 OK 了

## 参考文档

[实战编写 wireshark 插件解析私有协议](https://cloud.tencent.com/developer/article/1696433)

﻿[官方wiki中的几个插件示例](https://wiki.wireshark.org/Lua/Examples)

[Creating a Wireshark dissector in Lua - part 1 (the basics)](https://mika-s.github.io/wireshark/lua/dissector/2017/11/04/creating-a-wireshark-dissector-in-lua-1.html) 官方示范，解析 MongoDB 协议

[[Wireshark] 11.6.新协议与解析器的方法（Functions For New Protocols And Dissectors）](https://juejin.cn/post/7004036232720154660)



Reference:

