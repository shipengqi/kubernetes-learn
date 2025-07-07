---
title: Pod
weight: 1
---

为什么 Kubernetes 项目又搞出一个 Pod？

首先：容器的本质是进程。容器，就是未来云计算系统中的进程。那么 Kubernetes 就是云计算操作系统。

一台 Linux 机器里执行 pstree：

```bash
$ pstree -g
systemd(1)-+-accounts-daemon(1984)-+-{gdbus}(1984)
           | `-{gmain}(1984)
           |-acpid(2044)
          ...      
           |-lxcfs(1936)-+-{lxcfs}(1936)
           | `-{lxcfs}(1936)
           |-mdadm(2135)
           |-ntpd(2358)
           |-polkitd(2128)-+-{gdbus}(2128)
           | `-{gmain}(2128)
           |-rsyslogd(1632)-+-{in:imklog}(1632)
           |  |-{in:imuxsock) S 1(1632)
           | `-{rs:main Q:Reg}(1632)
           |-snapd(1942)-+-{snapd}(1942)
           |  |-{snapd}(1942)
           |  |-{snapd}(1942)
           |  |-{snapd}(1942)
           |  |-{snapd}(1942)
```

在一个真正的操作系统里，**进程并不是独自运行的，而是以进程组的方式，“有原则地”组织在一起**。进程组内的进程相互协作，共同完成任务。


而 Kubernetes 项目所做的，其实就是将“进程组”的概念映射到了容器技术中，并使其成为了这个云计算“操作系统”里的“一等公民”。

在 Borg 项目的开发和实践过程中，Google 公司的工程师们发现，他们部署的应用，往往都存在着类似于“进程和进程组”的关系。更具体地说，就是这些应用之间有着密切的协作关系，使得它们必须部署在同一台机器上。

而如果事先没有“组”的概念，像这样的运维关系就会非常难以处理。


**Pod 最重要的一个事实是：它只是一个逻辑概念**。Kubernetes 真正处理的，还是宿主机操作系统上 Linux 容器的 Namespace 和 Cgroups，而**并不存在一个所谓的 Pod 的边界或者隔离环境**。

**Pod，其实是一组共享了某些资源的容器**。

具体的说：**Pod 里的所有容器，共享的是同一个 Network Namespace，并且可以声明共享同一个 Volume**。

那这么来看的话，一个有 A、B 两个容器的 Pod，不就是等同于一个容器（容器 A）共享另外一个容器（容器 B）的网络和 Volume 的玩儿法么？

好像通过 `docker run --net --volumes-from` 这样的命令就能实现嘛，比如：

```bash
$ docker run --net=B --volumes-from=B --name=A image-A ...
```

但是，如果真这样做的话，容器 B 就必须比容器 A 先启动，这样一个 Pod 里的多个容器就不是对等关系，而是拓扑关系了。

## Pod 实现原理

### Pod 中的容器如何共享网络

在 Kubernetes 项目里，Pod 的实现需要使用一个中间容器，这个容器叫作 **Infra 容器**。在这个 **Pod 中，Infra 容器永远都是第一个被创建的容器，而其他用户定义的容器，则通过 Join Network Namespace 的方式，与 Infra 容器关联在一起**。


在 Kubernetes 项目里，**Infra 容器一定要占用极少的资源，所以它使用的是一个非常特殊的镜像，叫作：`k8s.gcr.io/pause`。这个镜像是一个用汇编语言编写的、永远处于“暂停”状态的容器，解压后的大小也只有 100~200 KB 左右**。

Infra 容器创建之后，用户容器就可以加入到 Infra 容器的 Network Namespace 当中了。

这也就意味着，对于 Pod 里的容器 A 和容器 B 来说：

- 它们可以直接使用 localhost 进行通信；
- 它们看到的网络设备跟 Infra 容器看到的完全一样；
- **一个 Pod 只有一个 IP 地址**，也就是这个 Pod 的 Network Namespace 对应的 IP 地址；
- 当然，其他的**所有网络资源，都是一个 Pod 一份，并且被该 Pod 中的所有容器共享**；
- Pod 的生命周期只跟 Infra 容器一致，而与容器 A 和 B 无关。

对于同一个 Pod 里面的所有用户容器来说，它们的进出流量，也可以认为都是通过 Infra 容器完成的。这一点很重要，**因为将来如果要为 Kubernetes 开发一个网络插件时，应该重点考虑的是如何配置这个 Pod 的 Network Namespace，而不是每一个用户容器如何使用你的网络配置，这是没有意义的**。

### Pod 中的容器如何共享 Volume

共享 Volume 就简单多了：Kubernetes 项目只要把所有 Volume 的定义都设计在 Pod 层级即可。

这样，一个 Volume 对应的宿主机目录对于 Pod 来说就只有一个，Pod 里的容器只要声明挂载这个 Volume，就一定可以共享这个 Volume 对应的宿主机目录。比如下面这个例子：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: two-containers
spec:
  restartPolicy: Never
  volumes:
  - name: shared-data
    hostPath:      
      path: /data
  containers:
  - name: nginx-container
    image: nginx
    volumeMounts:
    - name: shared-data
      mountPath: /usr/share/nginx/html
  - name: debian-container
    image: debian
    volumeMounts:
    - name: shared-data
      mountPath: /pod-data
    command: ["/bin/sh"]
    args: ["-c", "echo Hello from the debian container > /pod-data/index.html"]
```

`debian-container` 和 `nginx-container` 都声明挂载了 `shared-data` 这个 Volume。而 `shared-data `是 `hostPath` 类型。所以，它对应在宿主机上的目录就是：`/data`。而这个目录，其实就被同时绑定挂载进了上述两个容器当中。

这就是为什么，`nginx-container` 可以从它的 `/usr/share/nginx/html` 目录中，读取到 `debian-container` 生成的 `index.html` 文件的原因。

Pod 中的容器不在一个 Mount Namespace 里，但是通过挂载同一个 Volume，就可以实现共享挂载卷的目的。

## Pod 对象

**Pod 扮演的是传统部署环境里“虚拟机”的角色。把 Pod 看成传统环境里的“机器”、把容器看作是运行在这个“机器”里的“用户程序”**，那么很多关于 Pod 对象的设计就非常容易理解了。

Pod 是调度的最小单元。

**凡是调度、网络、存储，以及安全相关的属性，基本上是 Pod 级别的**。

这些属性的共同特征是，它们描述的是“机器”这个整体，而不是里面运行的“程序”。比如，配置这个“机器”的网卡（即：Pod 的网络定义），配置这个“机器”的磁盘（即：Pod 的存储定义），配置这个“机器”的防火墙（即：Pod 的安全定义）。更不用说，这台“机器”运行在哪个服务器之上（即：Pod 的调度）。

### NodeSelector

**是一个供用户将 Pod 与 Node 进行绑定的字段**：

```yaml
apiVersion: v1
kind: Pod
...
spec:
 nodeSelector:
   disktype: ssd
```

意味着这个 Pod 永远只能运行在携带了 “disktype: ssd” 标签（Label）的节点上；否则，它将调度失败。

### NodeName

一旦 Pod 的这个字段被赋值，Kubernetes 项目就会被认为这个 Pod 已经经过了调度，**调度的结果就是赋值的节点名字**。

所以，这个字段一般由调度器负责设置，但**用户也可以设置它来“骗过”调度器，当然这个做法一般是在测试或者调试的时候才会用到**。

### HostAliases

定义了 Pod 的 hosts 文件（比如 `/etc/hosts`）里的内容：

```yaml
apiVersion: v1
kind: Pod
...
spec:
  hostAliases:
  - ip: "10.1.2.3"
    hostnames:
    - "foo.remote"
    - "bar.remote"
...
```

这个 Pod 启动后，`/etc/hosts` 文件的内容将如下所示：

```bash
cat /etc/hosts
# Kubernetes-managed hosts file.
127.0.0.1 localhost
...
10.244.135.10 hostaliases-pod
10.1.2.3 foo.remote
10.1.2.3 bar.remote
```

下面两行记录，就是通过 `HostAliases` 字段为 Pod 设置的。

{{< callout type="info" >}}
**在 Kubernetes 项目中，如果要设置 hosts 文件里的内容，一定要通过这种方法**。否则，如果直接修改了 hosts 文件的话，在 Pod 被删除重建之后，kubelet 会自动覆盖掉被修改的内容。
{{< /callout >}}

### Pod 中的 Linux Namespace

**凡是跟容器的 Linux Namespace 相关的属性，也一定是 Pod 级别的**。这个原因也很容易理解：Pod 的设计，就是要让它里面的容器尽可能多地共享 Linux Namespace，仅保留必要的隔离和限制能力。这样，Pod 模拟出的效果，就跟虚拟机里程序间的关系非常类似了。

举个例子，在下面这个 Pod 的 YAML 文件中，定义了 `shareProcessNamespace=true`：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  shareProcessNamespace: true
  containers:
  - name: nginx
    image: nginx
  - name: shell
    image: busybox
    stdin: true
    tty: true
```

这就意味着这个 Pod 里的容器要共享 PID Namespace。

使用 `kubectl attach` 命令，连接到 shell 容器的 tty 上：

```bash
$ kubectl attach -it nginx -c shell
/ # ps ax
PID   USER     TIME  COMMAND
    1 root      0:00 /pause
    8 root      0:00 nginx: master process nginx -g daemon off;
   14 101       0:00 nginx: worker process
   15 root      0:00 sh
   21 root      0:00 ps ax
```

不仅可以看到它本身的 ps ax 指令，还可以看到 nginx 容器的进程，以及 Infra 容器的 `/pause` 进程。这就意味着，整个 Pod 里的每个容器的进程，对于所有容器来说都是可见的：它们**共享了同一个 PID Namespace**。

### Pod 共享宿主机的 Namespace


类似地，**凡是 Pod 中的容器要共享宿主机的 Namespace，也一定是 Pod 级别的定义**，比如：

```bash
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  hostNetwork: true
  hostIPC: true
  hostPID: true
  containers:
  - name: nginx
    image: nginx
  - name: shell
    image: busybox
    stdin: true
    tty: true
```

定义了共享宿主机的 Network、IPC 和 PID Namespace。这就意味着，这个 Pod 里的所有容器，会直接使用宿主机的网络、直接与宿主机进行 IPC 通信、看到宿主机里正在运行的所有进程。


### Containers

`Init Containers` 和 `Containers` 都属于 Pod 对容器的定义，内容也完全相同，只是 **Init Containers 的生命周期，会先于所有的 Containers，并且严格按照定义的顺序执行**。

#### ImagePullPolicy

定义了镜像拉取的策略。而它之所以是一个 Container 级别的属性，是因为容器镜像本来就是 Container 定义中的一部分。

ImagePullPolicy 的值默认是 **Always，即每次创建 Pod 都重新拉取一次镜像**。

如果它的值被定义为 **Never 或者 IfNotPresent，则意味着 Pod 永远不会主动拉取这个镜像，或者只在宿主机上不存在这个镜像时才拉取**。

#### Lifecycle

它定义的是 Container Lifecycle Hooks。它的作用，是在容器状态发生变化时触发一系列“钩子”：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: lifecycle-demo
spec:
  containers:
  - name: lifecycle-demo-container
    image: nginx
    lifecycle:
      postStart:
        exec:
          command: ["/bin/sh", "-c", "echo Hello from the postStart handler > /usr/share/message"]
      preStop:
        exec:
          command: ["/usr/sbin/nginx","-s","quit"]
```

- postStart，指的是，在容器启动后，立刻执行一个指定的操作。需要明确的是，postStart 定义的操作，虽然是在 Docker 容器 ENTRYPOINT 执行之后，但它并不严格保证顺序。也就是说，**在 postStart 启动时，ENTRYPOINT 有可能还没有结束**。**postStart 执行超时或者错误，会导致 Pod 也处于失败的状态**。
- preStop，是容器被杀死之前（比如，收到了 SIGKILL 信号）执行。而需要明确的是，**preStop 操作的执行，是同步的**。它会阻塞当前的容器杀死流程，**直到这个 Hook 定义操作完成之后，才允许容器被杀死**，这跟 postStart 不一样。


### 生命周期

Pod 生命周期的变化，主要体现在 Pod API 对象的Status 部分，这是它除了 Metadata 和 Spec 之外的第三个重要字段。其中，**`pod.status.phase`，就是 Pod 的当前状态**，它有如下几种可能的情况：

1. Pending。这个状态意味着，Pod 的 YAML 文件已经提交给了 Kubernetes，**API 对象已经被创建并保存在 Etcd 当中**。但是，这个 **Pod 里有些容器因为某种原因而不能被顺利创建**。比如，调度不成功。
2. Running。这个状态下，Pod 已经调度成功，跟一个具体的节点绑定。它包含的容器都已经创建成功，并且至少有一个正在运行中。
3. Succeeded。这个状态意味着，Pod 里的**所有容器都正常运行完毕，并且已经退出了**。这种情况在运行**一次性任务时最为常见**。
4. Failed。这个状态下，**Pod 里至少有一个容器以不正常的状态（非 0 的返回码）退出**。这个状态的出现，意味着你得想办法 Debug 这个容器的应用，比如查看 Pod 的 Events 和日志。
5. Unknown。这是一个异常状态，**意味着 Pod 的状态不能持续地被 kubelet 汇报给 kube-apiserver，这很有可能是主从节点（Master 和 Kubelet）间的通信出现了问题**。


Pod 对象的 Status 字段，还可以再细分出一组 **Conditions**。这些细分状态的值包括：PodScheduled、Ready、Initialized，以及 Unschedulable。它们**主要用于描述造成当前 Status 的具体原因是什么**。

Ready 这个细分状态非常值得关注：它意味着 Pod 不仅已经正常启动（Running 状态），而且已经可以对外提供服务了。这两者之间（Running 和 Ready）是有区别的，**Readiness Probe 成功后才是 Ready**。