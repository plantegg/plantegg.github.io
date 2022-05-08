---
title: Linux Module and make debug
date: 2019-01-24 17:30:03
categories: Linux
tags:
    - Linux
    - make
    - module
    - insmod
---

# Linux Module and make debug

## Makefile 中的 tab 键 

	$sudo make
	Makefile:4: *** missing separator.  Stop.

Makefile 中每个指令前面必须是tab(不能是4个空格）！

## pwd

	$sudo make
	make -C /lib/modules/4.19.48-002.ali4000.test.alios7.x86_64/build M= modules
	make[1]: Entering directory `/usr/src/kernels/4.19.48-002.ali4000.test.alios7.x86_64'
	make[2]: *** No rule to make target `arch/x86/entry/syscalls/syscall_32.tbl', needed by `arch/x86/include/generated/asm/syscalls_32.h'.  Stop.
	make[1]: *** [archheaders] Error 2
	make[1]: Leaving directory `/usr/src/kernels/4.19.48-002.ali4000.test.alios7.x86_64'
	make: *** [all] Error 2

Makefile中的：
	make -C /lib/modules/$(shell uname -r)/build M=$(pwd) modules

$(pwd) 需要修改成：$(shell pwd)

## makefile调试的法宝

### makefile调试的法宝1

	$ make --debug=a,m SHELL="bash -x" > make.log  2>&1                # 可以获取make过程最完整debug信息
	$ make --debug=v,m SHELL="bash -x" > make.log  2>&1                # 一个相对精简版，推荐使用这个命令
	$ make --debug=v  > make.log  2>&1                                 # 再精简一点的版本
	$ make --debug=b  > make.log  2>&1                                 # 最精简的版本

### makefile调试的法宝2

上面的法宝1更多的还是在整体工程的makefile结构、makefile读取和makefile内部的rule之间的关系方面有很好的帮助作用。但是对于makefile中rule部分之前的变量部分的引用过程则表现的不是很充分。在这里，我们有另外一个法宝，可以把变量部分的引用过程给出一个比较好的调试信息。具体命令如下。

    $ make -p 2>&1 | grep -A 1 '^# makefile' | grep -v '^--' | awk '/# makefile/&&/line/{getline n;print $0,";",n}' | LC_COLLATE=C sort -k 4 -k 6n > variable.log
    $ cat variable.log
    # makefile (from `Makefile', line 1) ; aa := 11
    # makefile (from `Makefile', line 3) ; cc := 11
    # makefile (from `Makefile', line 4) ; bb := 9999
    # makefile (from `cfg_makefile', line 1) ; MAKEFILE_LIST :=  Makefile cfg_makefile
    # makefile (from `cfg_makefile', line 1) ; xx := 4444
    # makefile (from `cfg_makefile', line 2) ; yy := 4444
    # makefile (from `cfg_makefile', line 3) ; zz := 4444
    # makefile (from `sub_makefile', line 1) ; MAKEFILE_LIST :=  sub_makefile
    # makefile (from `sub_makefile', line 1) ; aaaa := 222222
    # makefile (from `sub_makefile', line 2) ; bbbb := 222222
    # makefile (from `sub_makefile', line 3) ; cccc := 222222

### makefile调试的法宝3

法宝2可以把makefile文件中每个变量的最终值清晰的展现出来，但是对于这些变量引用过程中的中间值却没有展示。此时，我们需要依赖法宝3来帮助我们。

	$(warning $(var123))

很多人可能都知道这个warning语句。我们可以在makefile文件中的变量引用阶段的任何两行之间，添加这个语句打印关键变量的引用过程。

## make 时ld报找不到lib

make总是报找不到libc，但实际我执行 ld -lc --verbose 从debug信息看又能够正确找到libc，[debug方法](https://stackoverflow.com/questions/16710047/usr-bin-ld-cannot-find-lnameofthelibrary)

![image.png](/images/oss/f76b841375bb5ed5c5a946614fe494e1.png)

![image.png](/images/oss/19e493900f7d1ae1937d27366129e8aa.png)

实际原因是make的时候最后有一个参数 -static，这要求得装 ***-static lib库，可以去掉 -static

## 依赖错误

编译报错缺少的组件需要yum install一下(bison/flex)


## hping3

构造半连接：

	sudo hping3 -i u100 -S -p 3306 10.0.186.79

## tcp sk_state

	enum {
	    TCP_ESTABLISHED = 1,
	    TCP_SYN_SENT,
	    TCP_SYN_RECV,
	    TCP_FIN_WAIT1,
	    TCP_FIN_WAIT2,
	    TCP_TIME_WAIT,
	    TCP_CLOSE,
	    TCP_CLOSE_WAIT,
	    TCP_LAST_ACK,
	    TCP_LISTEN,
	    TCP_CLOSING,    /* Now a valid state */
	
	    TCP_MAX_STATES  /* Leave at the end! */
	};

## kdump

启动kdump(kexec-tools), 系统崩溃的时候dump 内核(/var/crash)

	sudo systemctl start kdump

## crash

	sudo yum install crash -y
	//手动触发crash
	#echo 1 > /proc/sys/kernel/sysrq
	#echo c > /proc/sysrq-trigger
	//系统crash，然后重启，重启后分析：
	sudo crash /usr/lib/debug/lib/modules/4.19.57-15.1.al7.x86_64/vmlinux /var/crash/127.0.0.1-2020-04-02-14\:40\:45/vmcore

可以触发dump但是系统没有crash, 以下两个命令都可以

```
sudo crash /usr/lib/debug/usr/lib/modules/4.19.91-19.1.al7.x86_64/vmlinux /proc/kcore
sudo crash /usr/lib/debug/usr/lib/modules/4.19.91-19.1.al7.x86_64/vmlinux  /dev/mem

写内存hack内核，那就在crash命令执行前，先执行下面的命令：
stap -g -e 'probe kernel.function("devmem_is_allowed").return { $return = 1 }'
```

## 内核函数替换

![image.png](/images/951413iMgBlog/c41363dae054baa6d7f79d03376c57cb.png)

	static int __init hotfix_init(void)
	{
	  unsigned char e8_call[POKE_LENGTH];
	  s32 offset, i;
	
	  addr = (void *)kallsyms_lookup_name("tcp_reset");
	  if (!addr) {
	    printk("一切还没有准备好！请先加载tcp_reset模块。\n");
	    return -1;
	  }
	
	  _text_poke_smp = (void *)kallsyms_lookup_name("text_poke");
	  _text_mutex = (void *)kallsyms_lookup_name("text_mutex");
	
	  stub = (void *)test_stub1;
	
	  offset = (s32)((long)stub - (long)addr - FTRACE_SIZE);
	
	  e8_call[0] = 0xe8;
	  (*(s32 *)(&e8_call[1])) = offset;
	  for (i = 5; i < POKE_LENGTH; i++) {
	    e8_call[i] = 0x90;
	  }
	  get_online_cpus();
	  mutex_lock(_text_mutex);
	  _text_poke_smp(&addr[POKE_OFFSET], e8_call, POKE_LENGTH);
	  mutex_unlock(_text_mutex);
	  put_online_cpus();
	
	  return 0;
	}
	
	void test_stub1(void)
	{
	  struct sock *sk = NULL;
	  unsigned long sk_addr = 0;
	  char buf[MAX_BUF_SIZE];
	  int size=0;
	  asm ("push %rdi");
	
	  asm ( "mov %%rdi, %0;" :"=m"(sk_addr) : :);
	  sk = (struct sock *)sk_addr;
	
	  printk("aaaaaaaa yes :%d  dest:%X  source:%X\n",
	      sk->sk_state,
	      sk->sk_rcv_saddr,
	      sk->sk_daddr);
	/*
	  size = snprintf(buf, MAX_BUF_SIZE-1, "rst %lu %d %pI4:%u->%pI4:%u \n",
	                     get_seconds(),
	                     sk->sk_state,
	                     &(inet_sk(sk)->inet_saddr),
	                     ntohs(inet_sk(sk)->inet_sport),
	                     ntohs(inet_sk(sk)->inet_dport),
	                     &(inet_sk(sk)->inet_daddr));
	*/
	//  tcp_rt_log_output(buf,size,1);
	
	  asm ("pop %rdi");
	}



## 参考文档

https://blog.sourcerer.io/writing-a-simple-linux-kernel-module-d9dc3762c234

https://stackoverflow.com/questions/16710047/usr-bin-ld-cannot-find-lnameofthelibrary

[Linux系统中如何彻底隐藏一个TCP连接](https://blog.csdn.net/dog250/article/details/105394840)

