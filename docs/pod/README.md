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

## 一个 Pod 管理多个容器
同一个 Pod 中的容器会自动的分配到同一个 node 上。同一个 Pod 中的容器共享资源、网络环境和依赖，它们总是被同时调度。
Pod中可以共享两种资源：网络和存储。如：

```yml
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
也可以通过 `{{ .spec.spec.terminationGracePeriodSeconds }}` 来修改此值。

### 强制删除 Pod
Pod的 强制删除是通过在集群和 etcd 中将其定义为删除状态。当执行**强制删除命令时，API server不会等待该 pod 所运行在节点上的 kubelet 确认**，就会立即将该 pod 从 API server 中移除，
这时就可以创建跟原 pod 同名的 pod 了。这时，在节点上的 pod 会被立即设置为 `terminating` 状态，不过在被强制删除之前依然有一小段优雅删除周期。

## 使用
通常很少会直接在集群中创建单个 Pod。因为 Pod 不会自愈，上面已经提到。所以**通常是使用 Controller 来管理 Pod 的**。

### Controller
Controller 可以创建和管理多个 Pod，提供副本管理、滚动升级和集群级别的自愈能力。

示例：
- [Deployment](../controller/deployment.md)
- [StatefulSet](../controller/stateful-set.md)
- [DaemonSet](../controller/daemon-set.md)