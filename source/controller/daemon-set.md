---
title: DaemonSet
---


**DaemonSet 保证在每个 Node 上都运行一个 Pod 副本**，常用来部署一些集群的日志、监控或者其他系统管理应用。典型的应用包括：

- 日志收集，比如 fluentd，logstash 等
- 系统监控，比如 Prometheus Node Exporter，collectd，New Relic agent，Ganglia gmond 等
- 系统程序，比如 kube-proxy, kube-dns, glusterd, ceph 等

**需要 Pod 副本总是运行在全部或特定主机上，并需要先于其他 Pod 启动，当这被认为非常重要时，应该使用 Daemon Controller**。

## 示例

`coredns`：

```yml
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: coredns
  namespace: kube-system
  labels:
    k8s-app: kube-dns
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
spec:
  updateStrategy:
    type: RollingUpdate
  selector:
    matchLabels:
      k8s-app: kube-dns
  template:
    metadata:
      labels:
        k8s-app: kube-dns
      annotations:
        scheduler.alpha.kubernetes.io/critical-pod: ''
    spec:
      {HOST_ALIASES}
      nodeSelector:
        {NODESELECT}
      serviceAccountName: keel-view
      priorityClassName: system-cluster-critical
      volumes:
      - name: config-volume
        configMap:
          name: coredns
          items:
          - key: Corefile
            path: Corefile
      - name: dns-hosts-cm
        configMap:
          name: dns-hosts-configmap
          items:
            - key: dns-hosts-key
              path: dns-hosts.conf
      containers:
      - name: coredns
        image: k8s.gcr.io/{IMAGE_COREDNS}
        imagePullPolicy: IfNotPresent
        resources:
          limits:
            memory: 170Mi
          requests:
            cpu: 100m
            memory: 70Mi
        args: [ "-conf", "/etc/coredns/Corefile" ]
        volumeMounts:
        - name: config-volume
          mountPath: /etc/coredns
        - name: dns-hosts-cm
          mountPath: /etc/k8s/dns/hosts
        ports:
        - containerPort: 53
          name: dns
          protocol: UDP
        - containerPort: 53
          name: dns-tcp
          protocol: TCP
        - containerPort: 9153
          name: metrics
          protocol: TCP
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            add:
            - NET_BIND_SERVICE
            drop:
            - all
          readOnlyRootFilesystem: true
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 60
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 5
      dnsPolicy: Default
```

## 编写 DaemonSet Spec

DaemonSet 需要 `apiVersion`、`kind`、`metadata` 和 `spec` 字段。

### Pod 模板

`.spec` 唯一必需的字段是 `.spec.template`。`.spec.template` 是一个 Pod 模板。 它与 Pod 具有相同的 schema。
不具有 `apiVersion` 或 `kind` 字段。

Pod 除了必须字段外，在 DaemonSet 中的 Pod 模板必须指定合理的标签。

**在 DaemonSet 中的 Pod 模板必需具有一个值为 `Always` 的 `RestartPolicy`，或者未指定它的值，默认是 `Always`**。

如果指定了 `.spec.selector`，那么必须与 `.spec.template.metadata.labels` 相匹配。如果没有指定，它们默认是等价的。
如果与它们配置的不匹配，则会被 API 拒绝。

## Daemon Pod 调度

如果指定了 `.spec.template.spec.nodeSelector`，DaemonSet Controller 将在能够匹配上 Node Selector 的 Node 上创建 Pod。
类似这种情况，可以指定 `.spec.template.spec.affinity`。

正常情况下，Pod 运行在哪个机器上是由 Kubernetes 调度器进行选择的。然而，由 Daemon Controller 创建的 Pod 已经确定
了在哪个机器上（Pod 创建时指定了 `.spec.nodeName`），因为 Daemon Controller 要保证全部或特定主机上总是有一个 pod 副本，因此：

- DaemonSet Controller 并不关心一个 Node 的 `unschedulable` 字段。
- DaemonSet Controller 可以创建 Pod，即使调度器还没有被启动，这对集群启动是非常有帮助的。

Daemon Pod 关心 [Taint 和 Toleration](../cluster/taint.html)。

## 滚动更新

v1.6 + 支持 DaemonSet 的滚动更新，可以通过 `.spec.updateStrategy.type` 设置更新策略。目前支持两种策略

- `OnDelete`：默认策略，更新模板后，只有手动删除了旧的 Pod 后才会创建新的 Pod
- `RollingUpdate`：更新 DaemonSet 模版后，自动删除旧的 Pod 并创建新的 Pod

在使用 RollingUpdate 策略时，还可以设置

- `.spec.updateStrategy.rollingUpdate.maxUnavailable`, 默认 `1`
- `spec.minReadySeconds`，默认 `0`

## 回滚

v1.7 + 支持回滚

```sh
# 查询历史版本
$ kubectl rollout history daemonset <daemonset-name>

# 查询某个历史版本的详细信息
$ kubectl rollout history daemonset <daemonset-name> --revision=1

# 回滚
$ kubectl rollout undo daemonset <daemonset-name> --to-revision=<revision>
# 查询回滚状态
$ kubectl rollout status ds/<daemonset-name>
```

## 如何保证每个 Node 上有且只有一个被管理的 Pod

DaemonSet Controller，首先从 Etcd 里获取所有的 Node 列表，然后遍历所有的 Node。这时，它就可以很容易地去检查，当前这个 Node 上是不是有一个携带了 `name=fluentd-elasticsearch` 标签的 Pod 在运行。

而检查的结果，可能有这么三种情况：

1. 没有这种 Pod，那么就意味着要在这个 Node 上创建这样一个 Pod；
2. 有这种 Pod，但是数量大于 1，那就说明要把多余的 Pod 从这个 Node 上删除掉；
3. 正好只有一个这种 Pod，那说明这个节点是正常的。


## 如何在指定的 Node 上创建新 Pod 呢？

用 nodeSelector，选择 Node 的名字即可。在 Kubernetes 项目里，nodeSelector 其实已经是一个将要被废弃的字段了。

现在有了一个新的、功能更完善的字段可以代替它，即：nodeAffinity

```yaml
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
          - key: metadata.name
            operator: In
            values:
            - node-geektime
```

1. requiredDuringSchedulingIgnoredDuringExecution：它的意思是说，这个 nodeAffinity 必须在每次调度的时候予以考虑。同时，这也意味着你可以设置在某些情况下不考虑这个 nodeAffinity；
2. 这个 Pod，将来只允许运行在“metadata.name”是“node-geektime”的节点上。

其实在大多数时候，这些 Operator 语义没啥用处。所以说，在学习开源项目的时候，一定要学会抓住“主线”。不要顾此失彼。

**DaemonSet Controller 会在创建 Pod 的时候，自动在这个 Pod 的 API 对象里，加上这样一个 nodeAffinity 定义**。

**DaemonSet 还会给这个 Pod 自动加上另外一个与调度相关的字段，叫作 tolerations。这个字段意味着这个 Pod，会“容忍”（Toleration）某些 Node 的“污点”（Taint）**。

DaemonSet 自动加上的 tolerations 字段，格式如下所示：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: with-toleration
spec:
  tolerations:
  - key: node.kubernetes.io/unschedulable
    operator: Exists
    effect: NoSchedule
```

这个 Toleration 的含义是：“容忍”所有被标记为 unschedulable“污点”的 Node；“容忍”的效果是允许调度。

在正常情况下，被标记了 unschedulable“污点”的 Node，是不会有任何 Pod 被调度上去的（effect: NoSchedule）。可是，DaemonSet 自动地给被管理的 Pod 加上了这个特殊的 Toleration，就使得这些 Pod 可以忽略这个限制，继而保证每个节点上都会被调度一个 Pod。

当然，如果这个节点有故障的话，这个 Pod 可能会启动失败，而 DaemonSet 则会始终尝试下去，直到 Pod 启动成功。

**DaemonSet 的“过人之处”，其实就是依靠 Toleration 实现的**。

而通过这样一个 Toleration，调度器在调度这个 Pod 的时候，就会忽略当前节点上的“污点”，从而成功地将 pod 调度到这台机器上启动起来。