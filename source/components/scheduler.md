---
title: kube-scheduler
---

`kube-scheduler` 负责分配**调度 Pod 到集群内的节点上**，它监听 `kube-apiserver`，查询还未分配 Node 的 Pod，然后根据调度策略为这些 Pod 分配节点（更新 Pod 的 `NodeName` 字段）。

影响调度的因素：

- 公平调度
- 资源高效利用
- QoS
- affinity（亲和性） 和 anti-affinity（非亲和性）
- 数据本地化（data locality）
- 内部负载干扰（inter-workload interference）
- deadlines

## 调度到指定 Node 节点

有三种方式调度 Pod 到指定的 Node 节点上：

- **nodeSelector**：只调度到匹配指定 label 的 Node 上
- **nodeAffinity**：功能更丰富的 Node 选择器，比如支持集合操作
- **podAffinity**：调度到满足条件的 Pod 所在的 Node 上

### nodeSelector

首先给 Node 打上标签

```sh
kubectl label nodes node-01 disktype=ssd
```

然后在 `daemonset` 或者 `deployment` 中指定 `nodeSelector` 为 `disktype=ssd`：

```yml
spec:
  nodeSelector:
    disktype: ssd
```

### nodeAffinity

`nodeAffinity` 目前支持两种：`requiredDuringSchedulingIgnoredDuringExecution` 和 `preferredDuringSchedulingIgnoredDuringExecution`，
分别代表**必须满足条件**和**优选条件**。

```yml
pods/pod-with-node-affinity.yaml

apiVersion: v1
kind: Pod
metadata:
  name: with-node-affinity
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: kubernetes.io/e2e-az-name
            operator: In
            values:
            - e2e-az1
            - e2e-az2
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 1
        preference:
          matchExpressions:
          - key: another-node-label-key
            operator: In
            values:
            - another-node-label-value
  containers:
  - name: with-node-affinity
    image: k8s.gcr.io/pause:2.0
```

上面的例子表示调度到包含标签 `kubernetes.io/e2e-az-name` 并且值为 `e2e-az1` 或 `e2e-az2` 的 Node 上，
并且优选还带有标签 `another-node-label-key=another-node-label-value` 的 Node。

### podAffinity

`podAffinity` 根据已在节点上运行的 pod 上的标签来限制 pod 可以调度到哪些节点，而不是基于节点上的标签。支持：

- `podAffinity`：用于调度 pod 可以和哪些 pod 部署在同一 Zone 中。
- `podAntiAffinity`：用于规定 pod 不可以和哪些 pod 部署在同一 Zone 中。

```yml
apiVersion: v1
kind: Pod
metadata:
  name: with-pod-affinity
spec:
  affinity:
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: security
            operator: In
            values:
            - S1
        topologyKey: failure-domain.beta.kubernetes.io/zone
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: security
              operator: In
              values:
              - S2
          topologyKey: kubernetes.io/hostname
  containers:
  - name: with-pod-affinity
    image: gcr.io/google_containers/pause:2.0
```

上面的例子，如果 node 所在的 zone 中包含了一个或多个带有标签 `security=S1` 的 pod，那么可以调度到该 node 节点。
如果 node 所在的 zone 中包含了一个或多个带有标签 `security=S2` 的 pod，那么不能到该 node 节点。

## Taints 和 tolerations

参考[Taints 和 tolerations](../cluster/taint.html)

## 优先级调度

`v1.8` 开始，`kube-scheduler` 支持定义 Pod 的优先级，从而保证高优先级的 Pod 优先调度。并从 `v1.11` 开始默认开启。

> 在 `v1.8-v1.10` 版本中的开启方法 apiserver 配置 `--feature-gates=PodPriority=true` 和 `--runtime-config=scheduling.k8s.io/v1alpha1=true`。
`kube-scheduler` 配置 `--feature-gates=PodPriority=true`

在指定 Pod 的优先级之前需要先定义一个 `PriorityClass`（非 namespace 资源）：

```yml
apiVersion: v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000000
globalDefault: false
description: "This priority class should be used for XYZ service pods only."
```

- `value`：32 位整数的优先级，该值越大，优先级越高
- `globalDefault`：表示 `PriorityClass` 的值应该给那些没有设置 `PriorityClassName` 的 Pod 使用。**整个系统只能存在一个 `globalDefault` 设
置为 `true` 的 `PriorityClass`**。如果没有任何 `globalDefault` 为 `true` 的 `PriorityClass` 存在，那么，那些没有设置 `PriorityClassName` 的 Pod 的
优先级将为 `0`。此外，将一个 `PriorityClass` 的 `globalDefault` 设置为 `true`，不会改变系统中已经存在的 Pod 的优先级。也就是说，`PriorityClass` 的值
只能用于在 `PriorityClass` 添加之后创建的那些 Pod 当中。

> 如果删除一个 `PriorityClass`，那些使用了该 `PriorityClass` 的 Pod 将会保持不变，但是，该 `PriorityClass` 的名称不能在新创建的 Pod 里面使用。

在 `PodSpec` 中通过 `PriorityClassName` 设置 Pod 的优先级：

```yml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  labels:
    env: test
spec:
  containers:
  - name: nginx
    image: nginx
    imagePullPolicy: IfNotPresent
  priorityClassName: high-priority
```

## 示例

```yml
apiVersion: v1
kind: Pod
metadata:
  name: scheduler
  namespace: kube-system
  annotations:
    scheduler.alpha.kubernetes.io/critical-pod: ""
spec:
  containers:
  - command:
    - /hyperkube
    - scheduler
    - --address=127.0.0.1
    - --bind-address=127.0.0.1
    - --master=https://{THIS_NODE}:{MASTER_API_SSL_PORT}
    - --leader-elect=true
    - --v=1
    - --logtostderr=true
    - --kubeconfig=/etc/kubernetes/ssl/kubeconfig
    - --authentication-kubeconfig=/etc/kubernetes/ssl/kubeconfig
    - --authorization-kubeconfig=/etc/kubernetes/ssl/kubeconfig
    image: k8s.gcr.io/{IMAGE_HYPERKUBE}
    imagePullPolicy: IfNotPresent
    securityContext:
      runAsUser: {SYSTEM_USER_ID}
    livenessProbe:
      httpGet:
        host: 127.0.0.1
        path: /healthz
        port: 10251
        scheme: HTTP
      initialDelaySeconds: 15
      timeoutSeconds: 15
    name: scheduler
    volumeMounts:
    - mountPath: /etc/kubernetes/ssl
      name: ssl-certs-path
      readOnly: true
  dnsPolicy: ClusterFirst
  hostNetwork: true
  restartPolicy: Always
  terminationGracePeriodSeconds: 30
  priorityClassName: system-cluster-critical
  volumes:
  - hostPath:
      path: {K8S_HOME}/ssl
    name: ssl-certs-path
```

当 Pod 拥有了优先级之后，高优先级的 Pod 就可能会比低优先级的 Pod 提前出队，从而尽早完成调度过程。

而当一个高优先级的 Pod 调度失败的时候，调度器的抢占能力就会被触发。这时，调度器就会试图从当前集群里寻找一个节点，使得当这个节点上的一个或者多个低优先级 Pod 被删除后，待调度的高优先级 Pod 就可以被调度到这个节点上。这个过程，就是**抢占**这个概念在 Kubernetes 里的主要体现。

当上述抢占过程发生时，抢占者并不会立刻被调度到被抢占的 Node 上。事实上，调度器只会将抢占者的 spec.nominatedNodeName 字段，设置为被抢占的 Node 的名字。然后，抢占者会重新进入下一个调度周期，然后在新的调度周期里来决定是不是要运行在被抢占的节点上。这当然也就意味着，即使在下一个调度周期，调度器也不会保证抢占者一定会运行在被抢占的节点上。

原因是，调度器只会通过标准的 DELETE API 来删除被抢占的 Pod，所以，这些 Pod 必然是有一定的“优雅退出”时间（默认是 30s）的。而在这段时间里，其他的节点也是有可能变成可调度的，或者直接有新的节点被添加到这个集群中来。所以，鉴于优雅退出期间，集群的可调度性可能会发生的变化，把抢占者交给下一个调度周期再处理，是一个非常合理的选择。

而在抢占者等待被调度的过程中，如果有其他更高优先级的 Pod 也要抢占同一个节点，那么调度器就会清空原抢占者的 spec.nominatedNodeName 字段，从而允许更高优先级的抢占者执行抢占，并且，这也就是得原抢占者本身，也有机会去重新抢占其他节点。这些，都是设置 nominatedNodeName 字段的主要目的。

## 工作原理

`kube-scheduler` 调度分为两个阶段，`predicate` 和 `priority`

- predicate：过滤不符合条件的节点
- priority：优先级排序，选择优先级最高的节点

Kubernetes 调度器实现抢占算法的一个最重要的设计，就是在调度队列的实现里，使用了两个不同的队列。

第一个队列，叫作 activeQ。凡是在 activeQ 里的 Pod，都是下一个调度周期需要调度的对象。所以，当你在 Kubernetes 集群里新创建一个 Pod 的时候，调度器会将这个 Pod 入队到 activeQ 里面。

第二个队列，叫作 unschedulableQ，专门用来存放调度失败的 Pod。

关键点就在于，当一个 unschedulableQ 里的 Pod 被更新之后，调度器会自动把这个 Pod 移动到 activeQ 里，从而给这些调度失败的 Pod “重新做人”的机会。

调度失败之后，抢占者就会被放进 unschedulableQ 里面。

然后，这次失败事件就会触发调度器为抢占者寻找牺牲者(被抢占的 Pod )的流程。

第一步，调度器会检查这次失败事件的原因，来确认抢占是不是可以帮助抢占者找到一个新节点。这是因为有很多 Predicates 的失败是不能通过抢占来解决的。比如，PodFitsHost 算法（负责的是，检查 Pod 的 nodeSelector 与 Node 的名字是否匹配），这种情况下，除非 Node 的名字发生变化，否则你即使删除再多的 Pod，抢占者也不可能调度成功。

第二步，如果确定抢占可以发生，那么调度器就会把自己缓存的所有节点信息复制一份，然后使用这个副本来模拟抢占过程。

这里的抢占过程很容易理解。调度器会检查缓存副本里的每一个节点，然后从该节点上最低优先级的 Pod 开始，逐一“删除”这些 Pod。而每删除一个低优先级 Pod，调度器都会检查一下抢占者是否能够运行在该 Node 上。一旦可以运行，调度器就记录下这个 Node 的名字和被删除 Pod 的列表，这就是一次抢占过程的结果了。

当遍历完所有的节点之后，调度器会在上述模拟产生的所有抢占结果里做一个选择，找出最佳结果。就是尽量减少抢占对整个系统的影响。比如，需要抢占的 Pod 越少越好，需要抢占的 Pod 的优先级越低越好，等等。

抢占操作：
第一步，调度器会检查牺牲者列表，清理这些 Pod 所携带的 nominatedNodeName 字段。

第二步，调度器会把抢占者的 nominatedNodeName，设置为被抢占的 Node 的名字。

第三步，调度器会开启一个 Goroutine，同步地删除牺牲者。

### Pod 启动流程

<img src="../imgs/pod-start.png" width="70%">

Kubernetes 的调度器的核心，实际上就是两个相互独立的控制循环。

第一个控制循环，我们可以称之为 Informer Path。它的主要目的，是启动一系列 Informer，用来监听（Watch）Etcd 中 Pod、Node、Service 等与调度相关的 API 对象的变化。比如，当一个待调度 Pod（即：它的 nodeName 字段是空的）被创建出来之后，调度器就会通过 Pod Informer 的 Handler，将这个待调度 Pod 添加进调度队列。

第二个控制循环，是调度器负责 Pod 调度的主循环，我们可以称之为 Scheduling Path。

调度器就需要将 Pod 对象的 nodeName 字段的值，修改为上述 Node 的名字。这个步骤在 Kubernetes 里面被称作 Bind。
