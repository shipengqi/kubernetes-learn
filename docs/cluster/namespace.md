# Namespace

在一个 Kubernetes 集群中可以使用 `namespace` 创建多个“虚拟集群”，这些 `namespace` 之间可以完全隔离，也可以通过某种方式，
让一个 `namespace` 中的 service 可以访问到其他的 `namespace` 中的服务。比如 Kubernetes 自带的服务一般运行在 `kube-system` namespace 中，并且为整个集群提供服务。

当你的项目和人员众多的时候可以考虑根据项目属性，例如生产、测试、开发划分不同的 namespace。

> node, persistent volume，namespace 等资源则不属于任何 namespace。

## 使用
```sh
# 获取集群中的 namespace

$ kubectl get namespaces
NAME          STATUS    AGE
default       Active    11d
kube-system   Active    11d

# 或者
$ kubectl get ns

# 获取指定 namespace kube-system
kubectl get namespace kube-system
```
namespace 包含两种状态 "Active" 和 "Terminating"。在 namespace 删除过程中，namespace 状态被设置成 "Terminating"。

> kubectl 可以**通过 `--namespace` 或者 `-n` 选项指定 namespace。如果不指定，默认为 `default`。查看操作下,
也可以通过设置 `--all-namespace=true` 或者 --all-namespace` 来查看所有 namespace 下的资源**。

### 创建
```sh
# 命令行直接创建
$ kubectl create namespace new-namespace

# 通过文件创建
$ cat my-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: new-namespace

$ kubectl create -f ./my-namespace.yaml
```

### 删除
```sh
$ kubectl delete namespaces new-namespace
```

- 删除一个 namespace 会自动删除所有属于该 namespace 的资源。
- `default` 和 `kube-system` 命名空间不可删除。
- `PersistentVolume` 是不属于任何 namespace 的，但 `PersistentVolumeClaim` 是属于某个特定 namespace 的。
- v1.7 版本增加了 `kube-public` 命名空间，该命名空间用来存放公共的信息，一般以 `ConfigMap` 的形式存放。