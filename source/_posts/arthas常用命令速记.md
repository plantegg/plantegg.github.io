---
title: arthas常用命令速记
date: 2019-09-27 13:30:03
categories: Java
tags:
    - java
    - arthas
---

# arthas常用命令速记

https://github.com/alibaba/arthas

## thread

thread -n 3
thread 16

## jad 反编译

	jad org.slf4j.Logger
	jad org.slf4j.Logger -c 61bbe9ba
	
	jad com.taobao.tddl.common.IdGenerator
	jad --source-only com.taobao.tddl.common.IdGenerator
	jad --source-only com.taobao.tddl.common.IdGenerator > /tmp/IdGenerator.java

反编译生成java代码

## mc 编译生成新的class

将修改后的java代码编译成class（因为依赖的关系可能失败）

	mc /tmp/IdGenerator.java -d /tmp


## redefine 加载新的class

将修改后的class代码热加载

	redefine /tmp/IdGenerator.class
	redefine -c 1e80bfe8 /tmp/com/alibaba/middleware/drds/worker/task/RegisterTask.class

可以再次jad 反编译确认class中是修改后的代码：

	jad --source-only com.alibaba.cobar.server.ServerConnection > /tmp/SC.java

有时候 redefine 看到成功，可是实际并不一定，最好再次 jad 确认一下。

线上环境快速修改代码验证三部曲：jad反编译得到源代码、修改后mc编译成class、redefine替换新的class。

## classload 

	classloader -l
	classloader -c 1e80bfe8 -r com/alibaba/middleware/drds/worker/task/RegisterTask.class
	classload -t
	classload -c 6e0be858
	classloader ch.qos.logback.core.AppenderBase

## sc

	sc -d com.taobao.tddl.common.IdGenerator
	sc -df ch.qos.logback.core.AppenderBase

## sm

列出class的方法

	sm ch.qos.logback.core.AppenderBase -d


## getstatic 查看静态成员

通过getstatic查看静态成员，来追踪一个logger没有设置level的话他的输出级别到底是什么？

先 sc 获取classloader的hash

	sc -df io.netty.channel.nio.NioEventLoop

	getstatic -c 1e80bfe8 io.netty.channel.nio.NioEventLoop logger 'getClass().getName()'
	field: logger
	@String[io.netty.util.internal.logging.Slf4JLogger]
	Affect(row-cnt:1) cost in 5 ms.

然后查看 logger的具体内容，可以看到level等，level为null的话会从父logger继承：

	getstatic -c 1e80bfe8 io.netty.channel.nio.NioEventLoop logger 'logger'
	field: logger
	@Logger[
	    serialVersionUID=@Long[5454405123156820674],
	    FQCN=@String[ch.qos.logback.classic.Logger],
	    name=@String[io.netty.channel.nio.NioEventLoop],
	    level=null,
	    effectiveLevelInt=@Integer[20000],
	    parent=@Logger[Logger[io.netty.channel.nio]],
	    childrenList=null,
	    aai=null,
	    additive=@Boolean[true],
	    loggerContext=@LoggerContext[ch.qos.logback.classic.LoggerContext[default]],
	]

再次用getstatic命令来确定jar包的location：

	getstatic -c 1e80bfe8 io.netty.channel.nio.NioEventLoop logger 'logger.getClass().getProtectionDomain().getCodeSource().getLocation()'
	field: logger
	@URL[
	    BUILTIN_HANDLERS_PREFIX=@String[sun.net.www.protocol],
	    serialVersionUID=@Long[-7627629688361524110],
	    protocolPathProp=@String[java.protocol.handler.pkgs],
	    protocol=@String[file],
	    host=@String[],
	    port=@Integer[-1],
	    file=@String[/home/admin/drds-worker/lib/logback-classic-1.1.8.jar],
	    query=null,
	    authority=@String[],
	    path=@String[/home/admin/drds-worker/lib/logback-classic-1.1.8.jar],
	    userInfo=null,
	    ref=null,
	    hostAddress=null,
	    handler=@Handler[sun.net.www.protocol.file.Handler@5a98007],
	    hashCode=@Integer[-1217964899],
	    tempState=null,
	    factory=null,
	    handlers=@Hashtable[isEmpty=false;size=3],
	    streamHandlerLock=@Object[java.lang.Object@3bf379e9],
	    serialPersistentFields=@ObjectStreamField[][isEmpty=false;size=7],
	]

然后通过getstatic来获取到这个parent属性的内容。然后通过多个parent操作，可以发现level都是INFO，最终发现ROOT level是INFO：

	getstatic -c 1e80bfe8 io.netty.channel.nio.NioEventLoop logger 'logger.parent.parent.parent.parent.parent'
	field: logger
	@Logger[
	    serialVersionUID=@Long[5454405123156820674],
	    FQCN=@String[ch.qos.logback.classic.Logger],
	    name=@String[ROOT],
	    level=@Level[INFO],
	    effectiveLevelInt=@Integer[20000],
	    parent=null,
	    childrenList=@CopyOnWriteArrayList[isEmpty=false;size=4],
	    aai=@AppenderAttachableImpl[ch.qos.logback.core.spi.AppenderAttachableImpl@3f0908e1],
	    additive=@Boolean[true],
	    loggerContext=@LoggerContext[ch.qos.logback.classic.LoggerContext[default]],
	]

## logger 查看logger配置

列出所有logger，然后修改logger的level

	classloader -l
	logger -c 27bc2616
	ognl -c 6e0be858 '@com.alibaba.cobar.server.ServerConnection@logger'
	ognl -c 6e0be858 '@org.slf4j.LoggerFactory@getLogger("root").setLevel(@ch.qos.logback.classic.Level@DEBUG)'

或者

	logger --name ROOT --level debug

## trace 耗时超过10ms的方法堆栈

查看调用耗时超过 10ms的函数堆栈

	stack ch.qos.logback.core.AppenderBase doAppend
	trace -j ch.qos.logback.core.AppenderBase doAppend '#cost > 10'

![image.png](https://ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/a62e3703ec9f3fef024fef4ff39441c7.png)

截图中红框的数字表示代码行号


## ongl 调用static函数并查看返回值

	ognl '#value1=@com.alibaba.middleware.drds.manager.common.utils.AddressUtil@getHostIp(), {#value1}'
	@ArrayList[
    	@String[10.0.174.135],
	]


	 ognl '#value1=@com.alibaba.middleware.drds.worker.Config@getInstance(), {#value1}'
		@ArrayList[
    @Config[Config(receivedManagerInfo=true, registeredToManager=true, workerRpcPort=8188, managerIp=10.0.171.193, managerPort=8080, drdsServerPort=3306, drdsManagerPort=3406, host=10.0.118.18, vpcId=vpc-bp1tsocjn451k7ur52vwl, urlToGetVpcId=http://100.100.100.200/latest/meta-data/vpc-id, heartBeatIntervalSeconds=180, registerInveralSeconds=2, manageDrdsIntervalSeconds=60, miniVersion=1, version=0.0.0.41, registerUrl=http://hostPlaceHolder:portPlaceHolder/v1/worker/register, heartBeatUrl=http://hostPlaceHolder:portPlaceHolder/v1/worker/heartBeat, manageDrdsServerUrl=http://hostPlaceHolder:portPlaceHolder/v1/worker/manageDrdsServer, gotVpcId=true, nodeType=drds-server, watcher=null, scheduledThreadPoolExecutor=java.util.concurrent.ScheduledThreadPoolExecutor@3aa3f85f[Running, pool size = 1, active threads = 1, queued tasks = 0, completed tasks = 0])],
	]

	#Netty的SelectorProvider.provider()创建Selector驱动的时候通过JDK create到的Selector驱动
	#如果是windows平台：WindowsSelectorProvider(); macos
	#下面是Linux平台的默认Selector驱动：
	$ options unsafe true
	$ ognl  '#value1=@sun.nio.ch.DefaultSelectorProvider@create(), {#value1}'
	@ArrayList[
	    @EPollSelectorProvider[sun.nio.ch.EPollSelectorProvider@5bf6cb51],
	]
	#或者
	$  ognl  '#value1=@java.nio.channels.spi.SelectorProvider@provider(), {#value1}'
	@ArrayList[
	    @EPollSelectorProvider[sun.nio.ch.EPollSelectorProvider@74c4ede7],
	]

## tt 观察函数调用和回放

先通过tt观察某个函数的调用，然后再用 tt -i 回放这个调用并查看返回值等

	tt -t com.alibaba.middleware.drds.manager.common.utils.AddressUtil getHostIp
	tt -t com.alibaba.middleware.drds.worker.task.RegisterTask getHostInfoIfNeeded
	tt -i 1000
	tt -i 1000 -p
	tt -n 3 -t com.alibaba.middleware.drds.worker.task.RegisterTask getHostInfoIfNeeded
	tt -n 3 -t com.alibaba.middleware.drds.manager.common.utils.AddressUtil getHostIp

	 tt -i 1010 -p
		 RE-INDEX      1010
		 GMT-REPLAY    2019-09-27 12:59:05
		 OBJECT        NULL
		 CLASS         com.alibaba.middleware.drds.manager.common.utils.AddressUtil
		 METHOD        getHostIp
		 IS-RETURN     true
		 IS-EXCEPTION  false
		 COST(ms)      0.577817
		 RETURN-OBJ    @String[10.0.118.18]

## watch 查看函数调用的参数内容和返回值

指定输出结果的属性遍历深度，默认为 1：

	watch  com.alibaba.middleware.drds.manager.common.utils.AddressUtil getHostIp "{params,returnObj}" -x 2

	watch com.alibaba.middleware.drds.worker.task.RegisterTask getHostInfoIfNeeded "{params,returnObj}" -x 2
		Press Q or Ctrl+C to abort.
		Affect(class-cnt:1 , method-cnt:1) cost in 56 ms.
		ts=2019-09-27 13:24:00; [cost=0.2698ms] result=@ArrayList[
		    @Object[][isEmpty=true;size=0],
		    @Boolean[true],
		]
		ts=2019-09-27 13:24:02; [cost=0.030039ms] result=@ArrayList[
		    @Object[][isEmpty=true;size=0],
		    @Boolean[true],
		]

可以看到处理请求的handler是 om.example.demo.arthas.user.UserController.findUserById：

	$ watch org.springframework.web.servlet.DispatcherServlet getHandler returnObj
	Press Q or Ctrl+C to abort.
	Affect(class-cnt:1 , method-cnt:1) cost in 332 ms.
	ts=2019-06-04 11:38:06; [cost=2.75218ms] result=@HandlerExecutionChain[
	    logger=@SLF4JLocationAwareLog[org.apache.commons.logging.impl.SLF4JLocationAwareLog@665c08a],
	    handler=@HandlerMethod[public com.example.demo.arthas.user.User com.example.demo.arthas.user.UserController.findUserById(java.lang.Integer)],
	    interceptors=null,
	    interceptorList=@ArrayList[isEmpty=false;size=2],
	    interceptorIndex=@Integer[-1],
	]


- watch 命令定义了4个观察事件点，即 -b 方法调用前，-e 方法异常后，-s 方法返回后，-f 方法结束后
- 4个观察事件点 -b、-e、-s 默认关闭，-f 默认打开，当指定观察点被打开后，在相应事件点会对观察表达式进行求值并输出
- 这里要注意方法入参和方法出参的区别，有可能在中间被修改导致前后不一致，除了 -b 事件点 params 代表方法入参外，其余事件都代表方法出参
- 当使用 -b 时，由于观察事件点是在方法调用前，此时返回值或异常均不存在

## 参考资料

[官方文档](https://alibaba.github.io/arthas/commands.html)

