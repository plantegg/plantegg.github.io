
# 跨 Die 热迁移迁移

## 场景

在 ARM 上，本来业务跑在 Die0 上，如果通过taskset 将 CPU 绑到 Die1，经过一段时间运行，内存也会慢慢随着释放/新分配慢慢都迁移到 Die1， 但是这之后仍然发现性能比在 Die0 上要差很多。而在 Intel X86 上没碰到过这个问题

## 分析

下图是内存带宽使用率监控数据，可以看到跨 Die 绑定后原来的 Die0 带宽急剧增加（7.5% -> 13%）这是因为内存都需要跨 Die 访问了，随着跨 Die 访问并慢慢将内存迁移到 Die1 后内存带宽使用率回落到 5%：

![img](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io@_md2zhihu_blog_04540fc6/跨Die热迁移迁移/d3d87757f35b327e-893058e1-0f19-4fc1-a76c-49b48f49317a.png)

同时可以看到 CPU 使用率也从 35% 飙升到 76%，随着内存的迁移完毕，CPU  使用率回落到 48%，但仍然比最开始的 35% 高不少：

![img](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io@_md2zhihu_blog_04540fc6/跨Die热迁移迁移/74e238bc429ba161-6b396de3-36cb-42d9-b14b-56be896509f8.png)

### Intel X86 下跨 Die 迁移

Intel 基本都是一路就是一个 Die，所以你可以理解这里的跨 Die 就是跨路/Socket 迁移：

![img](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io@_md2zhihu_blog_04540fc6/跨Die热迁移迁移/b76351d2680624ae-22e39654-d8d3-4d5d-ae88-d2c137be71a0.png)

![img](https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io@_md2zhihu_blog_04540fc6/跨Die热迁移迁移/0131213e5ac4a9a5-5b4477a5-a8d9-45b2-84e4-fb01cf8cc0b7.png)

## 结论

ARM 比 X86 差这么多的原因是内存页表跨 Die 访问导致的，业务同学测试了开启 THP 负载的影响，从结果看，THP on 可有效降低cpu水位，但是依然存在跨die迁移cpu水位上升的问题。

alios 对应的 patch：https://gitee.com/anolis/cloud-kernel/pulls/2254/commits  不区分 x86 和 arm

页表是进程创建时在内核空间分配好的，所以迁移内存时并不会迁移页表。通过测试页表跨die迁移的poc，验证了跨die页表访问是导致本文所述问题的根本原因

课后作业：

去了解下内存页表/THP(透明大页)

学习 CPU 访问内存延时是怎么回事，然后学习 CPU 和内存速度的差异，最后再去看看大学的计算机组成原理

学习下 taskset/perf 等命令



Reference:

