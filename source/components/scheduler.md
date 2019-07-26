---
title: kube-scheduler
---

# kube-scheduler
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

## 工作原理
`kube-scheduler` 调度分为两个阶段，`predicate` 和 `priority`
- predicate：过滤不符合条件的节点
- priority：优先级排序，选择优先级最高的节点