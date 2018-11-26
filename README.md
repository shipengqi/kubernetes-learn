# Kubernetes 学习笔记

## Docker
我们知道 Docker 是基于 Cgroups 和 NameSpace 机制创建一个叫做“沙盒”的隔离环境。这个用来运行应用的隔离环境就是所谓的“容器”。

但是在Docker 之前就已经有成熟的 PaaS 项目，比如 Cloud Foundry。Docker 与 Cloud Foundry 的容器都是基于 Cgroups 和 NameSpace ，大部分功能
和实现原理基本上都是一样的饿。Docker 为什么可以迅速崛起？

原因就是 Docker 独有的功能 **Docker 镜像**。

PaaS 项目可以帮助用户大规模部署应用到集群，但是它的打包功能是一个饱受诟病的“软肋”。使用 PaaS 用户必须为每种语言，每种框架甚至每个版本打包，而且应用在本地环境
运行的好好的在 PaaS 里就运行不了，需要不断试错，修改配置。

**Docker 镜像**解决的就是这个打包问题。**Docker 镜像**。本质上就是一个压缩包，但是这个压缩包包含了一个完整的操作系统的文件和目录，所以这个压缩包的内容和本地环境
是完全一样的。在云端环境，不再需要多余的修改和配置，可以使用某种技术创建一个沙盒，解压这个压缩包，就可以运行应用了。本地环境和云端环境高度一致，这就是Docker 镜像的
精髓。

## 容器基础
容器其实就是一种沙盒技术。沙盒就像一个集装箱，把你的应用装起来，这样应用和应用之间互不干扰，并且这个集装箱应用可以很方便的搬来搬去。

容器技术的核心就是通过约束和修改进程的动态表现，从而为其创造出一个“边界”。对于Docker 容器，**Cgroups 技术**是用来制造约束的主要手段，**NameSpace 技术**
是用来修改进程视图的主要方法。
