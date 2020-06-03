---
title: Pod 简介
---

# Pod

Pod 是 Kubernetes 中调度的最基本单位。`kube-controller-manager` 就是用来控制 Pod 的状态和生命周期的。

Pod 中封装着应用的容器（有的情况下是好几个容器），存储、独立的网络 IP，管理容器如何运行的策略选项。Pod 代表着部署的一个单位：kubernetes 中应用的一个实例，
可能由一个或者多个容器组合在一起共享资源。

```yml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 80
```

Pod 的两种使用方式：
- 一个 Pod 中运行一个容器。
- 一个 Pod 中也可以同时封装几个需要紧密耦合互相协作的容器，它们之间共享资源。这些在同一个 Pod 中的容器可以互相协作成为一个 service 单位——一个容器共享文件，
另一个 "sidecar" 容器来更新这些文件。Pod 将这些容器的存储资源作为一个实体来管理。

每个 Pod 都是一个应用实例。如果要运行多个 Pod 实例，在 Kubernetes 中，这通常被称为 `replication`。

## 为什么需要 pod
操作系统里，很多进程并不是独自运行的，而是以进程组的方式组织在一起。
对于操作系统来说，进程组更方便管理。

例如，Linux 操作系统只需要将信号，比如，SIGKILL 信号，发送给一个进程组，那么该进程组中的所有进程就都会收到这个信号而终止运行。

Kubernetes 项目所做的，其实就是将“进程组”的概念映射到了容器技术中，并使其成为了这个云计算“操作系统”里的“一等公民”。


关于 **Pod 最重要的一个事实是：它只是一个逻辑概念**。Kubernetes 真正处理的，还是宿主机操作系统上 Linux 容器的 Namespace 和 Cgroups，而
**并不存在一个所谓的 Pod 的边界或者隔离环境**。

**Pod，其实是一组共享了某些资源的容器。Pod 里的所有容器，共享的是同一个 Network Namespace，并且可以声明共享同一个 Volume**。

这好像通过 docker run --net --volumes-from 这样的命令就能实现嘛，比如：
```sh
$ docker run --net=B --volumes-from=B --name=A image-A ...
```
但是，如果这样做的话，容器 B 就必须比容器 A 先启动，这样一个 Pod 里的多个容器就不是对等关系，而是拓扑关系了。

### Infra 容器
在 Kubernetes 项目里，Pod 的实现需要使用一个中间容器，这个容器叫作 **Infra 容器**。

Pod 中，Infra 容器永远都是第一个被创建的容器，而其他用户定义的容器，则通过 Join Network Namespace 的方式，与 Infra 容器关联在一起。

Infra 容器占用极少的资源，它使用的是一个非常特殊的镜像，叫作：`k8s.gcr.io/pause`。这个镜像是一个用汇编语言编写的、永远处于“暂停”状态的
容器，解压后的大小也只有 100~200 KB 左右。
 
在 Infra 容器“Hold 住”Network Namespace 后，用户容器就可以加入到 Infra 容器的 Network Namespace 当中了。
查看这些容器在宿主机上的 Namespace 文件，它们指向的值一定是完全一样的。

这就意味着，对于 Pod 里的容器 A 和容器 B 来说：

- 它们可以直接使用 localhost 进行通信；
- 它们看到的网络设备跟 Infra 容器看到的完全一样；
- 一个 Pod 只有一个 IP 地址，也就是这个 Pod 的 Network Namespace 对应的 IP 地址；
- 当然，其他的所有网络资源，都是一个 Pod 一份，并且被该 Pod 中的所有容器共享；
- Pod 的生命周期只跟 Infra 容器一致，而与容器 A 和 B 无关。

对于同一个 Pod 里面的所有用户容器来说，它们的进出流量，也可以认为都是通过 Infra 容器完成的。

有了这个设计之后，共享 Volume 就简单多了：Kubernetes 项目只要把所有 Volume 的定义都设计在 Pod 层级即可。

这样，一个 Volume 对应的宿主机目录对于 Pod 来说就只有一个，Pod 里的容器只要声明挂载这个 Volume，就一定可以共享这个 Volume 对应的宿主机目录。

## NodeName 
一旦 Pod 的这个字段被赋值，Kubernetes 项目就会被认为这个 Pod 已经经过了调度，调度的结果就是赋值的节点名字。
一般由调度器负责设置，但用户也可以设置它来“骗过”调度器，当然这个做法一般是在测试或者调试的时候才会用到。

## RestartPolicy
Pod 支持三种 RestartPolicy：
- `Always`：只要退出就重启
- `OnFailure`：失败退出（exit code 不等于 0）时重启
- `Never`：只要退出就不再重启

## 环境变量
1. `HOSTNAME` 环境变量保存了该 Pod 的 hostname。
2. 容器和 Pod 的基本信息
Pod 的名字、命名空间、IP 以及容器的计算资源限制等可以以 [Downward API](../practice/inject-data-into-app.html#Downward-API)
 的方式获取并存储到环境变量中。
3. 集群中服务的信息
容器的环境变量中还可以引用容器运行前创建的所有服务的信息，比如默认的 kubernetes 服务对应以下环境变量：
```sh
KUBERNETES_PORT_443_TCP_ADDR=10.0.0.1
KUBERNETES_SERVICE_HOST=10.0.0.1
KUBERNETES_SERVICE_PORT=443
KUBERNETES_SERVICE_PORT_HTTPS=443
KUBERNETES_PORT=tcp://10.0.0.1:443
KUBERNETES_PORT_443_TCP=tcp://10.0.0.1:443
KUBERNETES_PORT_443_TCP_PROTO=tcp
KUBERNETES_PORT_443_TCP_PORT=443
```
## 镜像拉取策略
支持三种 `ImagePullPolicy`：

- `Always`：不管镜像是否存在都会进行一次拉取
- `Never`：不管镜像是否存在都不会进行拉取
- `IfNotPresent`：只有镜像不存在时，才会进行镜像拉取

注意：
默认为 `IfNotPresent`，但当镜像的标签为 `:latest` 默认为 `Always`。
拉取镜像时 docker 会进行校验，如果镜像中的 MD5 码没有变，则不会拉取镜像数据。

生产环境中应该尽量避免使用 `:latest` 标签，而开发环境中可以借助 `:latest` 标签自动拉取最新的镜像。

## 访问 DNS 的策略
通过设置 `dnsPolicy` 参数，设置 Pod 中容器访问 DNS 的策略：
- `ClusterFirst`：优先基于 cluster domain （如 `default.svc.cluster.local`） 后缀，通过 `kube-dns` 查询 (默认策略)
- `Default`：优先从 Node 中配置的 DNS 查询

## 使用主机的 IPC 命名空间
通过设置 `spec.hostIPC` 参数为 `true`，使用主机的 IPC 命名空间，默认为 `false`。
## 使用主机的网络命名空间
通过设置 `spec.hostNetwork` 参数为 `true`，使用主机的网络命名空间，默认为 `false`。
## 使用主机的 PID 空间
通过设置 `spec.hostPID` 参数为 `true`，使用主机的 PID 命名空间，默认为 `false`。
```yml
apiVersion: v1
kind: Pod
metadata:
  name: busybox1
  labels:
    name: busybox
spec:
  hostIPC: true
  hostPID: true
  hostNetwork: true
  containers:
  - image: busybox
    command:
      - sleep
      - "3600"
    name: busybox
```

## 设置 Pod 的端口映射
通过指定容器的 `hostPort` 和 `containerPort` 来创建端口映射，这样可以通过 Pod 所在 Node 的 IP:hostPort 来访问服务。比如：
```yml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
  - image: nginx
    name: nginx
    ports:
    - containerPort: 80
      hostPort: 80
```

注意  `hostPort` 不要与 Node 上的端口冲突。

## 设置 Pod 的 hostname
通过 `spec.hostname` 参数实现，如果未设置默认使用 `metadata.name` 参数的值作为 Pod 的 `hostname`。

## 设置 Pod 的子域名
比如，指定 `hostname` 为 `busybox-2` 和 `subdomain` 为 `default-subdomain`，完整域名为 `busybox-2.default-subdomain.default.svc.cluster.local`，
也可以简写为 `busybox-2.default-subdomain.default`：

```yml
apiVersion: v1
kind: Pod
metadata:
  name: busybox2
  labels:
    name: busybox
spec:
  hostname: busybox-2
  subdomain: default-subdomain
  containers:
  - image: busybox
    command:
      - sleep
      - "3600"
    name: busybox
```
注意：
- 默认情况下，DNS 为 Pod 生成的 A 记录格式为 `pod-ip-address.my-namespace.pod.cluster.local`，
如 `1-2-3-4.default.pod.cluster.local`
- 上面的示例还需要在 default namespace 中创建一个名为 `default-subdomain`（即 `subdomain`）
的 headless service，否则其他 Pod 无法通过完整域名访问到该 Pod（只能自己访问到自己）

```yml
kind: Service
apiVersion: v1
metadata:
  name: default-subdomain
spec:
  clusterIP: None
  selector:
    name: busybox
  ports:
  - name: foo # Actually, no port is needed.
    port: 1234
    targetPort: 1234
```
注意，必须为 headless service 设置至少一个服务端口（`spec.ports`，即便它看起来并不需要），
否则 Pod 与 Pod 之间依然无法通过完整域名来访问。

## 设置 Pod 的 DNS 选项
从 v1.9 开始，可以在 kubelet 和 kube-apiserver 中设置 `--feature-gates=CustomPodDNS=true` 开启设置每个 Pod DNS
地址的功能。
```yml
apiVersion: v1
kind: Pod
metadata:
  namespace: default
  name: dns-example
spec:
  containers:
    - name: test
      image: nginx
  dnsPolicy: "None"
  dnsConfig:
    nameservers:
      - 1.2.3.4
    searches:
      - ns1.svc.cluster.local
      - my.dns.search.suffix
    options:
      - name: ndots
        value: "2"
      - name: edns0
```
对于旧版本的集群，可以使用 ConfigMap 来自定义 Pod 的 `/etc/resolv.conf`，如：
```yml
kind: ConfigMap
apiVersion: v1
metadata:
  name: resolvconf
  namespace: default
data:
  resolv.conf: |
    search default.svc.cluster.local svc.cluster.local cluster.local
    nameserver 10.0.0.10

---
kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  name: dns-test
  namespace: default
spec:
  replicas: 1
  template:
    metadata:
      labels:
        name: dns-test
    spec:
      containers:
        - name: dns-test
          image: alpine
          stdin: true
          tty: true
          command: ["sh"]
          volumeMounts:
            - name: resolv-conf
              mountPath: /etc/resolv.conf
              subPath: resolv.conf
      volumes:
        - name: resolv-conf
          configMap:
            name: resolvconf
            items:
            - key: resolv.conf
              path: resolv.conf
```

## 限制网络带宽
可以通过给 Pod 增加 `kubernetes.io/ingress-bandwidth` 和 `kubernetes.io/egress-bandwidth` 这两个 `annotation` 来
限制 Pod 的网络带宽
```yml
apiVersion: v1
kind: Pod
metadata:
  name: qos
  annotations:
    kubernetes.io/ingress-bandwidth: 3M
    kubernetes.io/egress-bandwidth: 4M
spec:
  containers:
  - name: iperf3
    image: networkstatic/iperf3
    command:
    - iperf3
    - -s
```

> **目前只有 kubenet 网络插件支持限制网络带宽**，其他 CNI 网络插件暂不支持这个功能。

## 自定义 hosts
默认情况下，容器的 `/etc/hosts` 是 kubelet 自动生成的，并且仅包含 localhost 和 podName 等。不
建议在容器内直接修改 `/etc/hosts` 文件，因为在 Pod 启动或重启时会被覆盖。

从 v1.7 开始，可以通过 `pod.Spec.HostAliases` 来增加 hosts 内容，如
```yml
apiVersion: v1
kind: Pod
metadata:
  name: hostaliases-pod
spec:
  hostAliases:
  - ip: "127.0.0.1"
    hostnames:
    - "foo.local"
    - "bar.local"
  - ip: "10.1.2.3"
    hostnames:
    - "foo.remote"
    - "bar.remote"
  containers:
  - name: cat-hosts
    image: busybox
    command:
    - cat
    args:
    - "/etc/hosts"
```

HostAliases 定义了 Pod 的 hosts 文件（比如 `/etc/hosts`）里的内容：
```sh
$ kubectl logs hostaliases-pod
# Kubernetes-managed hosts file.
127.0.0.1    localhost
::1    localhost ip6-localhost ip6-loopback
fe00::0    ip6-localnet
fe00::0    ip6-mcastprefix
fe00::1    ip6-allnodes
fe00::2    ip6-allrouters
10.244.1.5    hostaliases-pod
127.0.0.1    foo.local
127.0.0.1    bar.local
10.1.2.3    foo.remote
10.1.2.3    bar.remote
```


## 一个 Pod 管理多个容器
同一个 Pod 中的容器会自动的分配到同一个 node 上。同一个 Pod 中的容器共享资源、网络环境和依赖，它们总是被同时调度。
Pod中可以共享两种资源：网络和存储。如：

```yml
apiVersion: v1
kind: Pod
metadata:
  name: chatbot-pod
  labels:
    app: chatbot
spec:
  initContainers:
  - name: install
    image: localhost:5000/kubernetes-vault-init:0.5.0
    securityContext:
      runAsUser: 1999
    env:
    - name: VAULT_ROLE_ID
      value: {VAULT_ROLE_ID}
    - name: CERT_COMMON_NAME
      value: {EXTERNAL_ACCESS_HOST}
    volumeMounts:
    - name: vault-token
      mountPath: /var/run/secrets/boostport.com
  containers:
  - name: chatbot
    image: {IMAGE_REPOSITORY}
    args:
    - "chatbot"
    imagePullPolicy: IfNotPresent
    volumeMounts:
    - name: vault-token
      mountPath: /var/run/secrets/boostport.com
  - name: kubernetes-vault-renew
    image: localhost:5000/kubernetes-vault-renew:0.5.0
    imagePullPolicy: IfNotPresent
    volumeMounts:
    - name: vault-token
      mountPath: /var/run/secrets/boostport.com
  volumes:
  - name: vault-token
    emptyDir: {}
```

上面的例子中：init 容器 `install`，容器 `chatbot` 和 `kubernetes-vault-renew` 都将 volume `vault-token` 挂载到了路径 `/var/run/secrets/boostport.com` 上，
`install` 容器在初始化 pod 时，调用 vault API 生成 vault token，并保存到 `/var/run/secrets/boostport.com`。`chatbot` 容器运行时，会使用 `install` 容器生成的
vault token 访问 vault。而 `kubernetes-vault-renew` 容器的作用就是定时检查 vault token 是否过期，并及时刷新 vault token。这就实现了 token 容器间的共享。


## Pod 的动机
### 管理
Pod 是一个服务的多个进程的聚合单位，pod 提供这种模型能够简化应用部署管理，通过提供一个更高级别的抽象的方式。Pod 作为一个独立的部署单位，支持横向扩展和复制。
共生（协同调度），命运共同体（例如被终结），协同复制，资源共享，依赖管理，Pod 都会自动的为容器处理这些问题。

### 资源共享和通信
Pod 中的应用可以共享网络空间（IP 地址和端口），因此可以通过 `localhost` 互相发现。因此，pod 中的应用必须协调端口占用。每个 pod 都有一个唯一的 IP 地址，
跟物理机和其他 pod 都处于一个扁平的网络空间中，它们之间可以直接连通。

**Pod 中应用容器的 `hostname` 被设置成 Pod 的名字**。

Pod 中的应用容器可以共享 volume。Volume 能够保证 pod 重启时使用的数据不丢失。

通常单个pod中不会同时运行一个应用的多个实例。

### Pod 的持久性
Pod 的生命周期是短暂的，在设计时就不是作为持久化实体的。在调度失败、节点故障、缺少资源或者节点维护的状态下都会死掉会被驱逐。

### Pod 的终止
用户需要能够发起一个删除 Pod 的请求，并且知道它们何时会被终止，是否被正确的删除。
删除过程：
1. 用户发送删除 pod 的命令，默认宽限期是 30 秒；
2. 在 Pod 超过该宽限期后 API server 就会更新 Pod 的状态为“dead”；
3. 在客户端命令行上显示的 Pod 状态为 `terminating`；
4. 跟第三步同时，当 kubelet 发现 pod 被标记为 `terminating` 状态时，开始停止 pod 进程：
   - 如果在 pod 中定义了 `preStop` hook，在停止 pod 前会被调用。如果在宽限期过后，`preStop` hook依然在运行，第二步会再增加 2 秒的宽限期；
   - 向 Pod 中的进程发送 `TERM` 信号；
5. 跟第三步同时，该 Pod 将从该 service 的端点列表中删除，不再是 replication controller 的一部分。关闭的慢的 pod 将继续处理 load balancer 转发的流量；
6. 过了宽限期后，将向 Pod 中依然运行的进程发送 `SIGKILL` 信号而杀掉进程。
7. Kubelet 会在 API server 中完成 Pod 的的删除，通过将优雅周期设置为 0（立即删除）。Pod 在 API 中消失，并且在客户端也不可见。


`kubectl delete` 命令支持 `--grace-period=<seconds>` 选项，允许用户设置自己的宽限期。**设置为 0 将强制删除 pod，同时使用 `--force`**。
也可以通过 `.spec.spec.terminationGracePeriodSeconds` 来修改此值。

### 强制删除 Pod
Pod的 强制删除是通过在集群和 etcd 中将其定义为删除状态。当执行**强制删除命令时，API server不会等待该 pod 所运行在节点上的 kubelet 确认**，就会立即将该 pod 从 API server 中移除，
这时就可以创建跟原 pod 同名的 pod 了。这时，在节点上的 pod 会被立即设置为 `terminating` 状态，不过在被强制删除之前依然有一小段优雅删除周期。

## 使用
通常很少会直接在集群中创建单个 Pod。因为 Pod 不会自愈，上面已经提到。所以**通常是使用 Controller 来管理 Pod 的**。

### Controller
Controller 可以创建和管理多个 Pod，提供副本管理、滚动升级和集群级别的自愈能力。

示例：
- [Deployment](../controller/deployment.html)
- [StatefulSet](../controller/stateful-set.html)
- [DaemonSet](../controller/daemon-set.html)
