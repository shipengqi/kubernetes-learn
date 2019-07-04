# 垃圾收集
Kubernetes 垃圾收集器的角色是删除指定的对象，这些对象曾经有但以后不再拥有 Owner 了。在 1.4 及以上版本默认启用。

## Owner 和 Dependent

一些 Kubernetes 对象是其它一些的 **Owner**。例如，一个 ReplicaSet 是一组 Pod 的 Owner。具有 Owner 的对象被称为是 Owner 的 **Dependent**。每个 Dependent 对象具
有一个指向其所属对象的 `metadata.ownerReferences` 字段。

有时，Kubernetes 会自动设置 ownerReference 的值。例如，当创建一个 ReplicaSet 时，Kubernetes 自动设置 ReplicaSet 中每个 Pod 的 ownerReference 字段值。
在 1.6 版本，Kubernetes 会自动为一些对象设置 ownerReference 的值，这些对象是由 ReplicationController、ReplicaSet、StatefulSet、DaemonSet 和 Deployment 所创建或管理。

也可以通过手动设置 ownerReference 的值，来指定 Owner 和 Dependent 之间的关系。

这有一个配置文件，表示一个具有 3 个 Pod 的 ReplicaSet：
```yml
apiVersion: extensions/v1beta1
kind: ReplicaSet
metadata:
  name: my-repset
spec:
  replicas: 3
  selector:
    matchLabels:
      pod-is-for: garbage-collection-example
  template:
    metadata:
      labels:
        pod-is-for: garbage-collection-example
    spec:
      containers:
      - name: nginx
        image: nginx
```

创建该 ReplicaSet，然后查看 Pod 的 `metadata` 字段，能够看到 `OwnerReferences` 字段：
```sh
kubectl create -f https://k8s.io/docs/concepts/abstractions/controllers/my-repset.yaml
kubectl get pods --output=yaml

apiVersion: v1
kind: Pod
metadata:
  ...
  ownerReferences:
  - apiVersion: extensions/v1beta1
    controller: true
    blockOwnerDeletion: true
    kind: ReplicaSet
    name: my-repset
    uid: d9607e19-f88f-11e6-a518-42010a800195
  ...
```

## 控制垃圾收集器删除 Dependent
当删除对象时，可以指定是否该对象的 Dependent 也自动删除掉。 自动删除 Dependent 也称为**级联删除**。 Kubernetes 中有两种级联删除的模式：`background` 模式和 `foreground` 模式。

如果删除对象时，不自动删除它的 Dependent，这些 Dependent 被称作是原对象的**孤儿**。

### Background 级联删除
在 background 级联删除 模式下，Kubernetes 会立即删除 Owner 对象，然后垃圾收集器会在后台删除这些 Dependent。

### Foreground 级联删除
在 foreground 级联删除 模式下，**根**对象首先进入 “删除中” 状态。在 “删除中” 状态会有如下的情况：

- 对象仍然可以通过 REST API 可见。
- 会设置对象的 `deletionTimestamp` 字段。
- 对象的 `metadata.finalizers` 字段包含了值 `foregroundDeletion`。

一旦对象被设置为 “删除中” 状态，垃圾收集器会删除对象的所有 Dependent。 垃圾收集器在删除了所有 “Blocking” 状态
的 Dependent（对象的 `ownerReference.blockOwnerDeletion=true`）之后，它会删除 Owner 对象。


## 设置级联删除策略
通过为 Owner 对象设置 `deleteOptions.propagationPolicy` 字段，可以控制级联删除策略。 可能的取值包括：`orphan`（孤儿）、`Foreground` 或 `Background`。

对很多 Controller 资源，包括 ReplicationController、ReplicaSet、StatefulSet、DaemonSet 和 Deployment，默认的垃圾收集策略是 `orphan`。 因此，
除非指定其它的垃圾收集策略，否则所有 Dependent 对象使用的都是 `orphan` 策略。

> **本段所指的默认值是指 REST API 的默认值，并非 kubectl 命令的默认值，kubectl 默认为级联删除**。

```sh
# Background 模式下 删除 Dependent 对象
kubectl proxy --port=8080
curl -X DELETE localhost:8080/apis/extensions/v1beta1/namespaces/default/replicasets/my-repset \
-d '{"kind":"DeleteOptions","apiVersion":"v1","propagationPolicy":"Background"}' \
-H "Content-Type: application/json"

# Foreground 模式下 删除 Dependent 对象
kubectl proxy --port=8080
curl -X DELETE localhost:8080/apis/extensions/v1beta1/namespaces/default/replicasets/my-repset \
-d '{"kind":"DeleteOptions","apiVersion":"v1","propagationPolicy":"Foreground"}' \
-H "Content-Type: application/json"

# orphan 模式
kubectl proxy --port=8080
curl -X DELETE localhost:8080/apis/extensions/v1beta1/namespaces/default/replicasets/my-repset \
-d '{"kind":"DeleteOptions","apiVersion":"v1","propagationPolicy":"Orphan"}' \
-H "Content-Type: application/json"
```

kubectl 也支持级联删除。 通过设置 `--cascade` 为 `true`，可以使用 kubectl 自动删除 Dependent 对象。设置 `--cascade` 为 `false`，会使 Dependent 对象成为
孤儿 Dependent 对象。`--cascade` 的默认值是 `true`。

下面是一个例子，使一个 ReplicaSet 的 Dependent 对象成为孤儿 Dependent：
```sh
kubectl delete replicaset my-repset --cascade=false
```

