---
title: Taints 和 tolerations
---

# Taints 和 tolerations

Taints 和 tolerations 用于保证 Pod 不被调度到不合适的 Node 上，其中 Taint 应用于 Node 上，而 toleration 则应用于 Pod 上。

taint 类型：
- NoSchedule：新的 Pod 不调度到该 Node 上，不影响正在运行的 Pod
- PreferNoSchedule：soft 版的 NoSchedule，尽量不调度到该 Node 上
- NoExecute：新的 Pod 不调度到该 Node 上，并且删除（evict）已在运行的 Pod。Pod 可以增加一个时间（tolerationSeconds）

每个节点上都可以应用一个或多个 taint ，这表示对于那些不能容忍这些 taint 的 pod，是不会被该节点接受的。如果将 toleration 应用于 pod 上，
则表示这些 pod 可以（但不要求）被调度到具有相应 taint 的节点上。


## 设置 taint
```sh
# 为 node1 设置 taint
kubectl taint nodes node1 key1=value1:NoSchedule
kubectl taint nodes node1 key1=value1:NoExecute
kubectl taint nodes node1 key2=value2:NoSchedule

# 删除上面的 taint
kubectl taint nodes node1 key1:NoSchedule-
kubectl taint nodes node1 key1:NoExecute-
kubectl taint nodes node1 key2:NoSchedule-

# 查看 node1 上的 taint
kubectl describe nodes node1
```

## 为 pod 设置 toleration
在 pod 的 spec 中设置 tolerations 字段即可：
```yml
tolerations:
- key: "key1"
  operator: "Equal"
  value: "value1"
  effect: "NoSchedule"
- key: "key1"
  operator: "Equal"
  value: "value1"
  effect: "NoExecute"
- key: "node.alpha.kubernetes.io/unreachable"
  operator: "Exists"
  effect: "NoExecute"
  tolerationSeconds: 6000
```

- `value` 的值可以为 `NoSchedule`、`PreferNoSchedule` 或 `NoExecute`。
- `tolerationSeconds` 是当 pod 需要被驱逐时，可以继续在 node 上运行的时间。

## 示例

比如，假设 node1 上应用以下几个 taint
```sh
kubectl taint nodes node1 key1=value1:NoSchedule
kubectl taint nodes node1 key1=value1:NoExecute
kubectl taint nodes node1 key2=value2:NoSchedule
```

下面的这个 Pod 由于没有 tolerate `key2=value2:NoSchedule` 无法调度到 node1 上
```yml
tolerations:
- key: "key1"
  operator: "Equal"
  value: "value1"
  effect: "NoSchedule"
- key: "key1"
  operator: "Equal"
  value: "value1"
  effect: "NoExecute"
```