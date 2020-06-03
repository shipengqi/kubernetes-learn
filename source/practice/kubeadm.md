# kubeadm

[kubeadm](https://github.com/kubernetes/kubeadm)
[安装 kubeadm](https://kubernetes.io/zh/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)

kubeadm 可以让用户只用简单的几条指令就可以安装 k8s 集群：
```sh
# 创建一个 Master 节点
$ kubeadm init

# 将一个 Node 节点加入到当前集群中
$ kubeadm join <Master 节点的 IP 和端口 >
```

> 注意 kubeadm 不能够用于生产环境，目前 kubeadm 已经可以[部署高可用的 k8s 集群](https://kubernetes.io/zh/docs/setup/production-environment/tools/kubeadm/high-availability/) 了。

## kubeadm 原理

k8s 有很多组件，部署时，所有组件的二进制文件都需要在指定的节点运行起来。

**kubeadm 就是用容器部署了大部分组件**。

但是有一个问题就是 **kubelet 很难容器化**。

kubelet 是操作 docker 或其他容器 ruantime 的核心组件，除了**操作容器 runtime，还需要配置容器网络，管理容器数据卷。
这些都需要直接操作宿主机**。

kubelet 如果以容器的方式运行，这些操作就会很麻烦。
- 网络配置可以不开启 Network Namespace，使用 docker 的 host network，共享宿主机网络栈。
- 隔着 Mount Namespace 和文件系统，操作宿主机文件系统，就很困难。

如果用户想要使用 NFS 做容器的持久化数据卷，那么 kubelet 就需要在容器进行绑定挂载前，在宿主机的指定目录上，先挂载 NFS 的远程目录。

可是，这时候问题来了。由于现在 kubelet 是运行在容器里的，这就意味着它要做的这个“mount -F nfs”命令，被隔离在了一个单独的 Mount Namespace 中。
即，kubelet 做的挂载操作，不能被“传播”到宿主机上。

有人说，可以使用 setns() 系统调用，在宿主机的 Mount Namespace 中执行这些挂载操作；也有人说，应该让 Docker 支持一个–mnt=host 的参数。

到目前为止，在容器里运行 kubelet，依然没有很好的解决办法。

### 安装
1. 安装容器 runtime
2. 安装 kubeadm、kubelet 和 kubectl 这三个二进制文件。

kubeadm 的作者已经为各个发行版的 Linux 准备好了安装包，所以只需要执行：
```sh
$ apt-get install kubeadm
```
### init 的工作流程
1. **kubeadm 首先要做一系列检查工作，以确定这台机器可以用来部署 Kubernetes**。叫做 "Preflight Checks"。

比如：
- Linux 内核的版本必须是否是 3.10 以上
- Linux Cgroups 模块是否可用
- 机器的 hostname 是否标准？在 Kubernetes 项目里，机器的名字以及一切存储在 Etcd 中的 API 对象，都必须使用标准的 DNS 命名（RFC 1123）。
- 用户安装的 kubeadm 和 kubelet 的版本是否匹配
- 机器上是不是已经安装了 Kubernetes 的二进制文件
- Kubernetes 的工作端口 10250/10251/10252 端口是不是已经被占用
- ip、mount 等 Linux 指令是否存在
- Docker 是否已经安装
。。。

在通过了 **Preflight Checks 之后，kubeadm 要生成 Kubernetes 对外提供服务所需的各种证书和对应的目录**。
Kubernetes 对外提供服务时，除非专门开启“不安全模式”，否则都要通过 HTTPS 才能访问 kube-apiserver。
kubeadm 为 Kubernetes 项目生成的证书文件都放在 Master 节点的 `/etc/kubernetes/pki` 目录下。

2. **证书生成后，kubeadm 接下来会为其他组件生成访问 kube-apiserver 所需的配置文件**。

这些文件的路径是：`/etc/kubernetes/xxx.conf`：
```sh
ls /etc/kubernetes/
admin.conf  controller-manager.conf  kubelet.conf  scheduler.conf
```

3. **接下来，kubeadm 会为 Master 组件生成 Pod 配置文件**。

包括 kube-apiserver、kube-controller-manager、kube-scheduler。
它们是以 static pod 的模式运行的。kubelet 启动时，它会自动检查这个目录，加载所有的 Pod YAML 文件，然后在这台机器上启动它们。 
Master 组件的 YAML 文件会被生成在 `/etc/kubernetes/manifests` 路径下。


4. **然后，kubeadm 就会为集群生成一个 bootstrap token**。
只要持有这个 token，任何一个安装了 kubelet 和 kubadm 的节点，都可以通过 kubeadm join 加入到这个集群当中。

token 的值和使用方法会，会在 kubeadm init 结束后被打印出来。

5. **在 token 生成之后，kubeadm 会将 ca.crt 等 Master 节点的重要信息，通过 ConfigMap 的方式保存在 Etcd 当中，供后续部署 Node 节点使用**。

这个 ConfigMap 的名字是 cluster-info。

6. **安装默认插件**。
Kubernetes 默认 kube-proxy 和 DNS 这两个插件是必须安装的。

这两个插件也只是两个容器镜像而已，所以 kubeadm 只要用 Kubernetes 客户端创建两个 Pod 就可以了。

### join 的工作流程
kubeadm init 生成 bootstrap token 之后，你就可以在任意一台安装了 kubelet 和 kubeadm 的机器上执行 kubeadm join 了。

为什么执行 kubeadm join 需要这样一个 token ？

因为，任何一台机器想要成为 Kubernetes 集群中的一个节点，就必须在集群的 kube-apiserver 上注册。可是，要想跟 apiserver 打交道，这台机器就必须要获
取到相应的证书文件（CA 文件）。可是，为了能够一键安装，我们就不能让用户去 Master 节点上手动拷贝这些文件。

所以，kubeadm 至少需要发起一次“不安全模式”的访问到 kube-apiserver，从而拿到保存在 ConfigMap 中的 cluster-info（它保存了 APIServer 的授权
信息）。而 bootstrap token，扮演的就是这个过程中的安全验证的角色。

只要有了 cluster-info 里的 kube-apiserver 的地址、端口、证书，kubelet 就可以以“安全模式”连接到 apiserver 上，这样一个新的节点就部署完成了。

### 配置 kubeadm 的部署参数
如何定制我的集群组件参数？如何定制我的集群组件参数呢？

推荐在使用 kubeadm init 部署 Master 节点时，使用下面这条指令：
```sh
$ kubeadm init --config kubeadm.yaml
```

`kubeadm.yaml` ，是 kubeadm 的配置文件，示例：
```yml
apiVersion: kubeadm.k8s.io/v1alpha2
kind: MasterConfiguration
kubernetesVersion: v1.11.0
api:
advertiseAddress: 192.168.0.102
bindPort: 6443
...
etcd:
local:
dataDir: /var/lib/etcd
image: ""
imageRepository: k8s.gcr.io
kubeProxy:
config:
bindAddress: 0.0.0.0
...
kubeletConfiguration:
baseConfig:
address: 0.0.0.0
...
networking:
dnsDomain: cluster.local
podSubnet: ""
serviceSubnet: 10.96.0.0/12
nodeRegistration:
criSocket: /var/run/dockershim.sock
...
```

通过这个文件就可以自定义部署参数了。比如，指定 kube-apiserver 的参数：
```yml
apiServerExtraArgs:
advertise-address: 192.168.0.103
anonymous-auth: false
enable-admission-plugins: AlwaysPullImages,DefaultStorageClass
audit-log-path: /home/johndoe/audit.log
```

kubeadm 就会使用上面这些信息替换 `/etc/kubernetes/manifests/kube-apiserver.yaml` 里的 command 字段里的参数了。