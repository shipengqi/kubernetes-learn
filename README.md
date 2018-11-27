# Kubernetes 学习笔记

## Docker
我们知道 Docker 是基于 Cgroups 和 Namespace 机制创建一个叫做“沙盒”的隔离环境。这个用来运行应用的隔离环境就是所谓的“容器”。

但是在Docker 之前就已经有成熟的 PaaS 项目，比如 Cloud Foundry。Docker 与 Cloud Foundry 的容器都是基于 Cgroups 和 Namespace ，大部分功能
和实现原理基本上都是一样的饿。Docker 为什么可以迅速崛起？

原因就是 Docker 独有的功能 **Docker 镜像**。

PaaS 项目可以帮助用户大规模部署应用到集群，但是它的打包功能是一个饱受诟病的“软肋”。使用 PaaS 用户必须为每种语言，每种框架甚至每个版本打包，而且应用在本地环境
运行的好好的在 PaaS 里就运行不了，需要不断试错，修改配置。

**Docker 镜像**解决的就是这个打包问题。**Docker 镜像**。本质上就是一个压缩包，但是这个压缩包包含了一个完整的操作系统的文件和目录，所以这个压缩包的内容和本地环境
是完全一样的。在云端环境，不再需要多余的修改和配置，可以使用某种技术创建一个沙盒，解压这个压缩包，就可以运行应用了。本地环境和云端环境高度一致，这就是Docker 镜像的
精髓。

## 容器基础
容器其实就是一种沙盒技术。沙盒就像一个集装箱，把你的应用装起来，这样应用和应用之间互不干扰，并且这个集装箱应用可以很方便的搬来搬去。

容器技术的核心iushi通过约束和修改进程的动态表现，从而为其创造出一个“边界”。对于Docker 容器，**Cgroups 技术（控制组 Control groups）**是用来制造约束的主要手段，
**Namespace 技术**是用来修改进程视图的主要方法。

### Namespace
```bash
docker run -it busybox /bin/sh
```
这里运行了一个容器，并且分配了一个命令行终端来和容器交互。执行`ps`命令，会输出：
```bash
PID USER TIME COMMAND
1   root  0:00  /bin/sh
10  root  0:00  ps
```

`/bin/sh`是容器内部的 1 号进程，这就意味着`/bin/sh`和`ps`已经被docker 与宿主机隔离。

怎么隔离？

本来，每当我们在宿主机上运行了一个`/bin/sh`程序，操作系统都会给它分配一个进程编号，比如`PID=100`。这个编号是进程的唯一标识，就像员工的工牌一样。所以`PID=100`，
可以粗略地理解为这个`/bin/sh`是我们公司里的第 100 号员工，而第 1 号员工就自然是老板。而现在，我们要通过Docker 把这个`/bin/sh`程序运行在一个容器当中。
这时候，Docker 就会在这个第 100 号员工入职时给他施一个“障眼法”，让他永远看不到前面的其他 99 个员工，更看不到老板。这样，他就会错误地以为自己就是公司里的第 1 号员工。
这种机制，其实就是对被隔离应用的进程空间做了手脚，使得这些进程只能看到重新计算过的进程编号，比如`PID=1`。可实际上，他们在宿主机的操作系统里，还是原来的第100 号进程。

**这种技术，就是Linux 里面的Namespace 机制。**

每个 PID Namespace 里的应用进程，都会认为自己是当前容器里的第 1 号进程，它们既看不到宿主机里真正的进程空间，也看不到其他PID Namespace 里的具体情况。

除了 PID Namespace，Linux 操作系统还提供了Mount、UTS、IPC、Network 和 User 这些Namespace，用来对各种不同的进程上下文进行“障眼法”操作。
比如，Mount Namespace，用于让被隔离进程只看到当前Namespace 里的挂载点信息；Network Namespace，用于让被隔离进程看到当前Namespace 里的网络设备和配置。

这就是Linux 容器最基本的实现原理了。所以说，**容器，其实是一种特殊的进程**。

### Cgroups

基于Linux Namespace 的隔离机制相比于虚拟化技术也有很多不足之处，其中最主要的问题就是：隔离得不彻底。

首先，既然容器只是运行在宿主机上的一种特殊的进程，那么多个容器之间使用的就还是同一个宿主机的操作系统内核。
这意味着，如果你要在 Windows 宿主机上运行Linux 容器，或者在低版本的Linux 宿主机上运行高版本的Linux 容器，都是行不通的。

其次，在Linux 内核中，有很多资源和对象是不能被Namespace 化的，最典型的例子就是：时间。
这就意味着，如果你的容器中的程序使用`settimeofday(2)`系统调用修改了时间，整个宿主机的时间都会被随之修改，这显然不符合用户的预期。

#### 限制
为什么需要对容器做“限制”呢？

以PID Namespace 为例，来给你解释这个问题。

虽然容器内的第1 号进程在“障眼法”的干扰下只能看到容器里的情况，但是宿主机上，它作为第100 号进程与其他所有进程之间依然是平等的竞争关系。这就意味着，虽然第100 号进程
表面上被隔离了起来，但是它所能够使用到的资源（比如CPU、内存），却是可以随时被宿主机上的其他进程（或者其他容器）占用的。当然，这个100 号进程自己也可能把所有资源吃
光。这些情况，显然都不是一个“沙盒”应该表现出来的合理行为。

**Linux Cgroups 就是Linux 内核中用来为进程设置资源限制的一个重要功能。**Linux Cgroups 的全称是Linux Control Group。它最主要的作用，就是限制一个进程组能够
使用的资源上限，包括CPU、内存、磁盘、网络带宽等等。


一个正在运行的Docker 容器，其实就是一个启用了多个Linux Namespace 的应用进程，而这个进程能够使用的资源量，则受 Cgroups 配置的限制。

在Linux 中，Cgroups 给用户暴露出来的操作接口是文件系统，即它以文件和目录的方式组织在操作系统的`/sys/fs/cgroup`路径下。

```bash
$ mount -t cgroup
cpuset on /sys/fs/cgroup/cpuset type cgroup (rw,nosuid,nodev,noexec,relatime,cpuset)
cpu on /sys/fs/cgroup/cpu type cgroup (rw,nosuid,nodev,noexec,relatime,cpu)
cpuacct on /sys/fs/cgroup/cpuacct type cgroup (rw,nosuid,nodev,noexec,relatime,cpuacct)
blkio on /sys/fs/cgroup/blkio type cgroup (rw,nosuid,nodev,noexec,relatime,blkio)
memory on /sys/fs/cgroup/memory type cgroup (rw,nosuid,nodev,noexec,relatime,memory)
...
```

在`/sys/fs/cgroup`下面有很多诸如cpuset、cpu、memory 这样的子目录，也叫子系统。这些都是我这台机器当前可以被Cgroups 进行限制的资源种类。而在子系统对应的资
源种类下，你就可以看到该类资源具体可以被限制的方法。比如，对CPU 子系统来说，我们就可以看到如下几个配置文件：
```bash
$ ls /sys/fs/cgroup/cpu
cgroup.clone_children cpu.cfs_period_us cpu.rt_period_us cpu.shares notify_on_release
cgroup.procs cpu.cfs_quota_us cpu.rt_runtime_us cpu.stat tasks
```

注意到`cfs_period`和`cfs_quota`这样的关键词。这两个参数需要组合使用，可以用来限制进程在长度为`cfs_period`的一段时间内，只能被分配到总量为`cfs_quota`的CPU 时间。

这样的配置文件又如何使用？
你需要在对应的子系统下面创建一个目录，比如，我们现在进入/sys/fs/cgroup/cpu 目录下：
```bash
root@ubuntu:/sys/fs/cgroup/cpu$ mkdir container
root@ubuntu:/sys/fs/cgroup/cpu$ ls container/
cgroup.clone_children cpu.cfs_period_us cpu.rt_period_us cpu.shares notify_on_release
cgroup.procs cpu.cfs_quota_us cpu.rt_runtime_us cpu.stat tasks
```
**这个目录就称为一个“控制组”。你会发现，操作系统会在你新创建的`container`目录下，自动生成该子系统对应的资源限制文件。**
现在，我们在后台执行一个死循环，计算机的CPU 吃到100%：
```bash
$ while : ; do : ; done &
[1] 226
```

我们可以通过查看`container`目录下的文件，看到`container`控制组里的CPU quota还没有任何限制（即：`-1`），CPU period 则是默认的`100 ms`（`100000 us`）：
```bash
$ cat /sys/fs/cgroup/cpu/container/cpu.cfs_quota_us
-1
$ cat /sys/fs/cgroup/cpu/container/cpu.cfs_period_us
100000
```

修改这些文件的内容来设置限制，比如，向container 组里的cfs_quota 文件写入20 ms（20000 us）：
```bash
$ echo 20000 > /sys/fs/cgroup/cpu/container/cpu.cfs_quota_us
```

结合前面的介绍，你应该能明白这个操作的含义，它意味着在每100 ms 的时间里，被该控制组限制的进程只能使用20 ms 的CPU 时间，也就是说这个进程只能使用到20% 的CPU 带宽。

接下来，我们把被限制的进程的`PID`写入`container`组里的`tasks`文件，上面的设置就会对该进程生效了：
```bash
$ echo 226 > /sys/fs/cgroup/cpu/container/tasks

# 用top 指令查看一下
$ top
%Cpu0 : 20.3 us, 0.0 sy, 0.0 ni, 79.7 id, 0.0 wa, 0.0 hi, 0.0 si, 0.0 st
```
可以看到，计算机的CPU 使用率立刻降到了20%（%Cpu0 : 20.3 us）。

Cgroups 的每一项子系统都有其独有的资源限制能力，比如：
- `blkio`，为块设备设定`I/O`限制，一般用于磁盘等设备；
- `cpuset`，为进程分配单独的CPU 核和对应的内存节点；
- `memory`，为进程设定内存使用的限制。

Linux Cgroups 的设计还是比较易用的，**它其实就是一个子系统目录加上一组资源限制文件的组合。**

而对于Docker 等Linux 容器项目来说，**它们只需要在每个子系统下面，为每个容器创建一个控制组（即创建一个新目录），然后在启动容器进程之后，把这个进程的PID 填写
到对应控制组的tasks 文件中就可以了。**

而至于在这些控制组下面的资源文件里填上什么值，就靠用户执行`docker run`时的参数指定了，比如这样一条命令：
```bash
$ docker run -it --cpu-period=100000 --cpu-quota=20000 ubuntu /bin/bash
```

在启动这个容器后，我们可以通过查看Cgroups 文件系统下，CPU 子系统中，“docker”这个控制组里的资源限制文件的内容来确认：
```bash
$ cat /sys/fs/cgroup/cpu/docker/5d5c9f67d/cpu.cfs_period_us
100000
$ cat /sys/fs/cgroup/cpu/docker/5d5c9f67d/cpu.cfs_quota_us
20000
```
意味着这个Docker 容器，只能使用到20% 的CPU 带宽。


### Cgroups的问题
跟Namespace 的情况类似，Cgroups 对资源的限制能力也有很多不完善的地方，被提及最多的自然是`/proc`文件系统的问题。

众所周知，Linux 下的`/proc`目录存储的是记录当前内核运行状态的一系列特殊文件，用户可以通过访问这些文件，查看系统以及当前正在运行的进程的信息，比如CPU 使用情况、
内存占用率等，这些文件也是`top`指令查看系统信息的主要数据来源。但是，你如果在容器里执行`top`指令，就会发现，它显示的信息居然是宿主机的CPU 和内存数据，而不是
当前容器的数据。

造成这个问题的原因就是，`/proc`文件系统并不知道用户通过Cgroups 给这个容器做了什么样的资源限制，即：`/proc`文件系统不了解Cgroups 限制的存在。在生产环境中，
这个问题必须进行修正，否则应用程序在容器里读取到的CPU 核数、可用内存等信息都是宿主机上的数据，这会给应用的运行带来非常大的困惑和风险。这也是在企业中，容器化应用
碰到的一个常见问题，也是容器相较于虚拟机另一个不尽如人意的地方。

解决方案 **lxcfs**：
`top`是从`/prof/stats`目录下获取数据，所以道理上来讲，容器不挂载宿主机的该目录就可以了。`lxcfs`就是来实现这个功能的，做法是把宿主机的`/var/lib/lxcfs/proc/memoinfo`
文件挂载到Docker容器的`/proc/meminfo`位置后。容器中进程读取相应文件内容时，`LXCFS`的`FUSE`实现会从容器对应的Cgroup中读取正确的内存限制。从而使得应用获得正确的资源约
束设定。kubernetes 环境下，也能用，以`ds`方式运行`lxcfs`，自动给容器注入正确的`proc`信息。
