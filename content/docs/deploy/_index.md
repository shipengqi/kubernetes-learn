# 部署 Kubernetes

## kubeadm 原理

为什么不用容器部署 Kubernetes 呢？

在 Kubernetes 早期的部署脚本里，确实有一个脚本就是用 Docker 部署 Kubernetes 项目的，这个脚本相比于 SaltStack 等的部署方式，也的确简单了不少。

但是，这样做会带来一个很麻烦的问题，即：**如何容器化 kubelet**。

 kubelet 本身就运行在一个容器里，那么直接操作宿主机就会变得很麻烦。
 
 1. 对于网络配置来说还好，kubelet 容器可以通过不开启 Network Namespace（即 Docker 的 host network 模式）的方式，直接共享宿主机的网络栈。
 2. 要让 kubelet 隔着容器的 Mount Namespace 和文件系统，操作宿主机的文件系统，就有点儿困难了。

比如，如果用户想要使用 NFS 做容器的持久化数据卷，那么 kubelet 就需要在容器进行绑定挂载前，在宿主机的指定目录上，先挂载 NFS 的远程目录。

可是，这时候问题来了。由于现在 kubelet 是运行在容器里的，这就意味着它要做的这个“mount -F nfs”命令，被隔离在了一个单独的 Mount Namespace 中。即，kubelet 做的挂载操作，不能被“传播”到宿主机上。

对于这个问题，有人说，可以使用 `setns() `系统调用，在宿主机的 Mount Namespace 中执行这些挂载操作；也有人说，应该让 Docker 支持一个 `–mnt=host` 的参数。

到目前为止，在容器里运行 kubelet，依然没有很好的解决办法，我也不推荐你用容器去部署 Kubernetes 项目。

kubeadm 选择了一种妥协方案：

**把 kubelet 直接运行在宿主机上，然后使用容器部署其他的 Kubernetes 组件**。

所以，*8使用 kubeadm 的第一步，是在机器上手动安装 kubeadm、kubelet 和 kubectl 这三个二进制文件**。当然，kubeadm 的作者已经为各个发行版的 Linux 准备好了安装包，所以你只需要执行：

```bash
$ apt-get install kubeadm
```

接下来，就可以使用“kubeadm init”部署 Master 节点了。

### kubeadm init 的工作流程

#### 检查 Preflight Checks

执行 `kubeadm init` 指令后，kubeadm 首先要做的，是一系列的检查工作（“Preflight Checks”），以确定这台机器可以用来部署 Kubernetes。

Preflight Checks 包括了很多方面，比如：

- Linux 内核的版本必须是否是 3.10 以上？
- Linux Cgroups 模块是否可用？
- 机器的 hostname 是否标准？在 Kubernetes 项目里，机器的名字以及一切存储在 Etcd 中的 API 对象，都必须使用标准的 DNS 命名（RFC 1123）。
- 用户安装的 kubeadm 和 kubelet 的版本是否匹配？
- 机器上是不是已经安装了 Kubernetes 的二进制文件？
- Kubernetes 的工作端口 10250/10251/10252 端口是不是已经被占用？
- ip、mount 等 Linux 指令是否存在？
- Docker 是否已经安装？

#### 生成证书

通过了 Preflight Checks 之后，kubeadm 要为你做的，是生成 Kubernetes 对外提供服务所需的各种证书和对应的目录。

Kubernetes 对外提供服务时，**除非专门开启“不安全模式”，否则都要通过 HTTPS 才能访问 `kube-apiserver`。这就需要为 Kubernetes 集群配置好证书文件**。

kubeadm 为 Kubernetes 项目生成的证书文件都放在 Master 节点的 `/etc/kubernetes/pki` 目录下。在这个目录下，最主要的证书文件是 `ca.crt` 和对应的私钥 `ca.key`。

此外，用户使用 kubectl 获取容器日志等 streaming 操作时，需要通过 `kube-apiserver` 向 kubelet 发起请求，这个连接也必须是安全的。kubeadm 为这一步生成的是 `apiserver-kubelet-client.crt` 文件，对应的私钥是 `apiserver-kubelet-client.key`。

除此之外，Kubernetes 集群中还有 Aggregate APIServer 等特性，也需要用到专门的证书。也可以选择不让 kubeadm 为你生成这些证书，而是拷贝现有的证书到如下证书的目录里：

```bash
/etc/kubernetes/pki/ca.{crt,key}
```

这时，kubeadm 就会跳过证书生成的步骤，把它完全交给用户处理。

#### 生成配置文件

1. 证书生成后，kubeadm 接下来会**为其他组件生成访问 `kube-apiserver` 所需的配置文件**。这些文件的路径是：`/etc/kubernetes/xxx.conf`：

```bash
ls /etc/kubernetes/
admin.conf  controller-manager.conf  kubelet.conf  scheduler.conf
```

这些文件里面记录的是，当前这个 Master 节点的服务器地址、监听端口、证书目录等信息。这样，对应的客户端（比如 scheduler，kubelet 等），可以直接加载相应的文件，使用里面的信息与 `kube-apiserver` 建立安全连接。

2. 接下来，kubeadm 会**为 Master 组件生成 Pod 配置文件**。

`kube-apiserver`、`kube-controller-manager`、`kube-scheduler`，而它们都会被使用 Pod 的方式部署起来。

**这个时候，Kubernetes 集群尚不存在，难道 kubeadm 会直接执行 `docker run` 来启动这些容器吗？**

不是。

**在 Kubernetes 中，有一种特殊的容器启动方法叫做“Static Pod” （Static Pod 仅在定义它的当前节点上运行）**。它允许你把要部署的 Pod 的 YAML 文件放在一个指定的目录里。这样，当这台机器上的 **kubelet 启动时，它会自动检查这个目录，加载所有的 Pod YAML 文件，然后在这台机器上启动它们**。

**kubelet 在 Kubernetes 项目中的地位非常高，在设计上它就是一个完全独立的组件，而其他 Master 组件，则更像是辅助性的系统容器**。

3. **kubeadm 还会再生成一个 Etcd 的 Pod YAML 文件，用来通过同样的 Static Pod 的方式启动 Etcd**。

所以，最后 Master 组件的 Pod YAML 文件如下所示：

```bash
$ ls /etc/kubernetes/manifests/
etcd.yaml  kube-apiserver.yaml  kube-controller-manager.yaml  kube-scheduler.yaml
```

一旦这些 YAML 文件出现在被 kubelet 监视的 `/etc/kubernetes/manifests` 目录下，kubelet 就会自动创建这些 YAML 文件中定义的 Pod，即 Master 组件的容器。

kubeadm 会通过检查 `localhost:6443/healthz` 这个 Master 组件的健康检查 URL，等待 Master 组件完全运行起来。

4. 然后，kubeadm 就会**为集群生成一个 bootstrap token**。

在后面，只要持有这个 token，任何一个安装了 kubelet 和 kubadm 的节点，都可以通过 `kubeadm join` 加入到这个集群当中。

这个 token 的值和使用方法会，会在 `kubeadm init` 结束后被打印出来。

**在 token 生成之后，kubeadm 会将 `ca.crt` 等 Master 节点的重要信息，通过 ConfigMap 的方式保存在 Etcd 当中，供后续部署 Node 节点使用**。

5. **安装默认插件**

Kubernetes **默认 `kube-proxy` 和 DNS 这两个插件是必须安装的**。它们分别用来提供整个集群的服务发现和 DNS 功能。其实，这两个插件也只是两个容器镜像而已，所以 kubeadm 只要用 Kubernetes 客户端创建两个 Pod 就可以了。

### kubeadm join 的工作流程

`kubeadm init` 生成 bootstrap token 之后，你就可以在任意一台安装了 kubelet 和 kubeadm 的机器上执行 `kubeadm join` 了。

为什么执行 `kubeadm join` 需要这样一个 token 呢？

因为，任何一台机器想要成为 Kubernetes 集群中的一个节点，就必须在集群的 `kube-apiserver` 上注册。可是，**要想跟 apiserver 打交道，这台机器就必须要获取到相应的证书文件（CA 文件）**。可是，**为了能够一键安装，我们就不能让用户去 Master 节点上手动拷贝这些文件**。

kubeadm 至少需要发起一次“不安全模式”的访问到 `kube-apiserver`，从而拿到保存在 ConfigMap 中的 `cluster-info`（它保存了 APIServer 的授权信息）。而 **bootstrap token，扮演的就是这个过程中的安全验证的角色**。

只要有了 `cluster-info` 里的 `kube-apiserver` 的地址、端口、证书，kubelet 就可以以“安全模式”连接到 apiserver 上，这样一个新的节点就部署完成了。


### 配置 kubeadm 的部署参数

kubeadm 确实简单易用，可是又该如何定制我的集群组件参数呢？

比如，要指定 `kube-apiserver` 的启动参数，该怎么办？

推荐在使用 `kubeadm init` 部署 Master 节点时，使用下面这条指令：

```bash
$ kubeadm init --config kubeadm.yaml
```

这时，你就可以给 kubeadm 提供一个 YAML 文件（比如，`kubeadm.yaml`），它的内容如下所示（主要部分）：

```yaml
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

通过制定这样一个部署参数配置文件，就可以很方便地在这个文件里填写各种自定义的部署参数了。

比如，现在要指定 `kube-apiserver` 的参数：

```yaml
...
apiServerExtraArgs:
  advertise-address: 192.168.0.103
  anonymous-auth: false
  enable-admission-plugins: AlwaysPullImages,DefaultStorageClass
  audit-log-path: /home/johndoe/audit.log
```

kubeadm 就会使用上面这些信息替换 `/etc/kubernetes/manifests/kube-apiserver.yaml` 里的 command 字段里的参数了。

### 配置 kubeconfig

`kubeadm init` 之后，还会提示第一次使用 Kubernetes 集群所需要的配置命令：

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

需要这些配置命令的原因是：Kubernetes 集群默认需要加密方式访问。所以，这几条命令，就是将刚刚部署生成的 Kubernetes 集群的安全配置文件，保存到当前用户的 **`.kube` 目录下，kubectl 默认会使用这个目录下的授权信息访问 Kubernetes 集群**。

如果不这么做的话，每次都需要通过 `export KUBECONFIG` 环境变量告诉 kubectl 这个安全配置文件的位置。

### 配置网络插件

使用 `kubectl get` 命令来查看当前唯一一个节点的状态了：

```bash
$ kubectl get nodes
 
NAME      STATUS     ROLES     AGE       VERSION
master    NotReady   master    1d        v1.11.1
```

Master 节点的状态是 NotReady，这是为什么呢？

```bash
$ kubectl describe node master
 
...
Conditions:
...
 
Ready   False ... KubeletNotReady  runtime network not ready: NetworkReady=false reason:NetworkPluginNotReady message:docker: network plugin is not ready: cni config uninitialized
```

看到 NodeNotReady 的原因在于，我们尚未部署任何网络插件。

通过 kubectl 检查这个节点上各个系统 Pod 的状态，其中，**`kube-system `是 Kubernetes 项目预留的系统 Pod 的工作空间**：

```bash
$ kubectl get pods -n kube-system
 
NAME               READY   STATUS   RESTARTS  AGE
coredns-78fcdf6894-j9s52     0/1    Pending  0     1h
coredns-78fcdf6894-jm4wf     0/1    Pending  0     1h
etcd-master           1/1    Running  0     2s
kube-apiserver-master      1/1    Running  0     1s
kube-controller-manager-master  0/1    Pending  0     1s
kube-proxy-xbd47         1/1    NodeLost  0     1h
kube-scheduler-master      1/1    Running  0     1s
```

CoreDNS、`kube-controller-manager` 等依赖于网络的 Pod 都处于 Pending 状态，即调度失败。这当然是符合预期的：因为这个 Master 节点的网络尚未就绪。

署网络插件非常简单，只需要执行一句 `kubectl apply` 指令，以 Weave 为例：

```bash
$ kubectl apply -f https://git.io/weave-kube-1.6
```

部署完成后，我们可以通过 `kubectl get` 重新检查 Pod 的状态：

```bash
$ kubectl get pods -n kube-system
 
NAME                             READY     STATUS    RESTARTS   AGE
coredns-78fcdf6894-j9s52         1/1       Running   0          1d
coredns-78fcdf6894-jm4wf         1/1       Running   0          1d
etcd-master                      1/1       Running   0          9s
kube-apiserver-master            1/1       Running   0          9s
kube-controller-manager-master   1/1       Running   0          9s
kube-proxy-xbd47                 1/1       Running   0          1d
kube-scheduler-master            1/1       Running   0          9s
weave-net-cmk27                  2/2       Running   0          19s
```

所有的系统 Pod 都成功启动了，而刚刚部署的 Weave 网络插件则在 kube-system 下面新建了一个名叫 `weave-net-cmk27` 的 Pod，一般来说，这些 Pod 就是容器网络插件在每个节点上的控制组件。

Kubernetes 支持容器网络插件，使用的是一个名叫 CNI 的通用接口。，市面上的所有容器网络开源项目都可以通过 CNI 接入 Kubernetes，比如 Flannel、Calico、Canal、Romana 等等。

### 配置 Taint/Toleration

在**默认情况下，Kubernetes 的 Master 节点是不能运行用户 Pod 的，所以还需要额外做一个小操作**。 Kubernetes 做到这一点，依靠的是 Kubernetes 的 `Taint/Toleration` 机制。

它的原理非常简单：

1. **一旦某个节点被加上了一个 `Taint`，即被“打上了污点”，那么所有 Pod 就都不能在这个节点上运行，因为 Kubernetes 的 Pod 都有“洁癖”**。
2. **除非，有个别的 Pod 声明自己能“容忍”这个“污点”，即声明了 `Toleration`，它才可以在这个节点上运行**。


为节点打上“污点”（Taint）的命令是：

```bash
$ kubectl taint nodes node1 foo=bar:NoSchedule
```

**NoSchedule，意味着这个 Taint 只会在调度新 Pod 时产生作用，而不会影响已经在 node1 上运行的 Pod，哪怕它们没有 Toleration**。

Pod 又如何声明 Toleration 呢？

```yaml
apiVersion: v1
kind: Pod
...
spec:
  tolerations:
  - key: "foo"
    operator: "Equal"
    value: "bar"
    effect: "NoSchedule"
```

这个 Pod 能“容忍”所有键值对为 `foo=bar` 的 `Taint`（ `operator: “Equal”`，“等于”操作）。

通过 `kubectl describe` 检查一下 Master 节点的 `Taint` 字段：

```bash
$ kubectl describe node master
 
Name:               master
Roles:              master
Taints:             node-role.kubernetes.io/master:NoSchedule
```

Master 节点默认被加上了 `node-role.kubernetes.io/master:NoSchedule` 这样一个“污点”，其中“键”是 `node-role.kubernetes.io/master`，而没有提供“值”。

此时，就需要像下面这样用 “Exists” 操作符（`operator: “Exists”`，“存在”即可）来说明，该 Pod 能够容忍所有以 foo 为键的 Taint，才能让这个 Pod 运行在该 Master 节点上：

```yaml
apiVersion: v1
kind: Pod
...
spec:
  tolerations:
  - key: "foo"
    operator: "Exists"
    effect: "NoSchedule"
```

如果就是**想要一个单节点的 Kubernetes，删除这个 Taint 才是正确的选择**：

```bash
kubectl taint nodes --all node-role.kubernetes.io/master-
```

在 “node-role.kubernetes.io/master” 这个键后面加上了一个短横线 “-”，这个格式就意味着移除所有以 “node-role.kubernetes.io/master” 为键的 Taint。

到了这一步，一个基本完整的 Kubernetes 集群就部署完毕了。

### 部署容器存储插件

**容器最典型的特征之一：无状态**。

而容器的持久化存储，就是用来保存容器存储状态的重要手段：**存储插件会在容器里挂载一个基于网络或者其他机制的远程数据卷，使得在容器里创建的文件，实际上是保存在远程存储服务器上，或者以分布式的方式保存在多个节点上，而与当前宿主机没有任何绑定关系**。

这样，无论你在其他哪个宿主机上启动新的容器，都可以请求挂载指定的持久化存储卷，从而访问到数据卷里保存的内容。这就是“**持久化**”的含义。

绝大多数存储项目，比如 Ceph、GlusterFS、NFS 等，都可以为 Kubernetes 提供持久化存储能力。

Rook 项目是一个基于 Ceph 的 Kubernetes 存储插件（它后期也在加入对更多存储实现的支持）。不过，不同于对 Ceph 的简单封装，Rook 在自己的实现中加入了水平扩展、迁移、灾难备份、监控等大量的企业级功能，使得这个项目变成了一个完整的、生产级别可用的容器存储插件。

用两条指令，Rook 就可以把复杂的 Ceph 存储后端部署起来：

```bash
$ kubectl apply -f https://raw.githubusercontent.com/rook/rook/master/cluster/examples/kubernetes/ceph/operator.yaml
 
$ kubectl apply -f https://raw.githubusercontent.com/rook/rook/master/cluster/examples/kubernetes/ceph/cluster.yaml
```

在部署完成后，你就可以看到 Rook 项目会将自己的 Pod 放置在由它自己管理的两个 Namespace 当中：

```bash
$ kubectl get pods -n rook-ceph-system
NAME                                  READY     STATUS    RESTARTS   AGE
rook-ceph-agent-7cv62                 1/1       Running   0          15s
rook-ceph-operator-78d498c68c-7fj72   1/1       Running   0          44s
rook-discover-2ctcv                   1/1       Running   0          15s
 
$ kubectl get pods -n rook-ceph
NAME                   READY     STATUS    RESTARTS   AGE
rook-ceph-mon0-kxnzh   1/1       Running   0          13s
rook-ceph-mon1-7dn2t   1/1       Running   0          2s
```

一个基于 Rook 持久化存储集群就以容器的方式运行起来了，而接下来在 Kubernetes 项目上创建的所有 Pod 就能够通过 Persistent Volume（PV）和 Persistent Volume Claim（PVC）的方式，在容器里挂载由 Ceph 提供的数据卷了。

Rook 项目，则会负责这些数据卷的生命周期管理、灾难备份等运维工作。

### 高可用 Kubernetes 集群

使用 kubeadm 部署 高可用（HA）Kubernetes 集群 主要涉及 **`控制平面（Control Plane）的高可用`**，通常采用 **`多 Master 节点 + 负载均衡`** 的架构。

Kubeadm 支持两种高可用模式：

1. 堆叠式（Stacked）HA：
   - 每个 Master 节点同时运行 kube-apiserver、kube-controller-manager、kube-scheduler 和 etcd。
   - etcd 集群在 Master 节点之间形成高可用。
   - 需要 负载均衡器（如 HAProxy、Nginx）暴露 API Server。
   - 优点：部署简单，适合中小规模集群。
   - 缺点：etcd 和 Master 组件耦合，故障域集中。
2. 外部 etcd（External etcd）HA：
   - etcd 集群独立于 Master 节点部署（至少 3 节点）。
   - Master 节点仅运行控制平面组件，通过负载均衡访问 etcd。
   - 优点：解耦 etcd 和 Master，扩展性更好。
   - 缺点：部署复杂度高，适合大规模生产环境。   

####  配置负载均衡器

LB 需代理所有 Master 节点的 6443（API Server）端口，例如 HAProxy 配置：

```ini
frontend kubernetes-apiserver
    bind *:6443
    mode tcp
    default_backend kube-apiservers

backend kube-apiservers
    mode tcp
    balance roundrobin
    server master1 <Master1-IP>:6443 check
    server master2 <Master2-IP>:6443 check
    server master3 <Master3-IP>:6443 check
```

```bash
sudo haproxy -c -f /etc/haproxy/haproxy.cfg  # 验证配置
sudo systemctl restart haproxy
```

LB 的 IP/DNS 将作为集群的 `control-plane-endpoint`。

为了保证 HaProxy 的高可用，可以再使用 Keepalived 配置 VIP，实现高可用。

部署方案：

- 至少 2 个节点 运行 HAProxy + Keepalived（主备模式）。
- VIP 默认绑定在 主节点（Master），故障时自动切换到 备节点（Backup）。

配置 Keepalived 节点，`/etc/keepalived/keepalived.conf`：

```ini
# 主节点
vrrp_script chk_haproxy {
    script "pidof haproxy"  # 检查 HAProxy 是否运行
    interval 2
    weight 2
}

vrrp_instance VI_1 {
    state MASTER           # 主节点
    interface eth0         # 替换为实际网卡名（如 ens160）
    virtual_router_id 51   # 集群唯一 ID（1-255）
    priority 101           # 主节点优先级更高（101 > 100）
    advert_int 1

    authentication {
        auth_type PASS
        auth_pass 1111     # 节点间认证密码
    }

    virtual_ipaddress {
        <VIP>              # 替换为虚拟 IP（如 192.168.1.100）
    }

    track_script {
        chk_haproxy        # 绑定健康检查
    }
}

# 备节点
vrrp_instance VI_1 {
    state BACKUP           # 备节点
    interface eth0         # 替换为实际网卡名
    virtual_router_id 51   # 必须与主节点一致
    priority 100           # 优先级低于主节点
    advert_int 1

    authentication {
        auth_type PASS
        auth_pass 1111     # 密码与主节点一致
    }

    virtual_ipaddress {
        <VIP>              # 相同的虚拟 IP
    }

    track_script {
        chk_haproxy
    }
}
```

#### Keepalived 原理

Keepalived 的 VIP（Virtual IP，虚拟 IP） 实现原理基于 VRRP（Virtual Router Redundancy Protocol，虚拟路由冗余协议），通过多台服务器协商主备角色，确保 VIP 的高可用性。

**VIP 绑定与释放**

Master 节点：
- 通过 ip addr add 将 VIP 绑定到指定网卡（如 eth0）。
- 对外宣告 VIP 的 MAC 地址为虚拟 MAC（格式 00:00:5E:00:01:XX，XX 是 vrid）。

Backup 节点：
- 监听 Master 的通告，不绑定 VIP。
- 若超时未收到通告（默认 3 × advert_int），触发选举新 Master。

Keepalived 可结合自定义脚本检查服务状态（如 HAProxy、Nginx），决定是否降级：

```ini
vrrp_script chk_haproxy {
    script "pidof haproxy"  # 检查进程是否存在
    interval 2              # 检查间隔（秒）
    weight 2                # 权重变化（优先级 +/- weight）
    fall 2                  # 连续失败次数触发降级
    rise 2                  # 连续成功次数恢复
}

vrrp_instance VI_1 {
    track_script {
        chk_haproxy  # 绑定健康检查
    }
}
```

若脚本检测失败，节点优先级降低，触发主备切换。