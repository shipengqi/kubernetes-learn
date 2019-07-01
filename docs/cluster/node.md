# Node
Node 是 Pod 真正运行的主机，可以是物理机也可以是虚拟机。每个 Node 节点上至少要运行 container runtime（比如 `docker` 或者 `rkt`）、`kubelet` 和 `kube-proxy` 服务。

## Node 管理
Node 本质上不是 Kubernetes 来创建的，Kubernetes 只是管理 Node 上的资源。虽然可以通过 Manifest 创建一个 Node 对象（如下 yaml 所示），但 Kubernetes 也只是去
检查是否真的是有这么一个 Node，如果检查失败，也不会往上调度 Pod。

这个检查是由 Node Controller 来完成的。Node Controller 负责
- 维护 Node 状态
- 与 Cloud Provider 同步 Node
- 给 Node 分配容器 CIDR
- 删除带有 NoExecute taint 的 Node 上的 Pods

**默认情况下，kubelet 在启动时会向 master 注册自己，并创建 Node 资源**。

```yml
kind: Node
apiVersion: v1
metadata:
  name: 10-240-79-157
  labels:
    name: my-first-k8s-node
```

禁止 pod 调度到该节点上：
```sh
kubectl cordon <node>
```

驱逐该节点上的所有 pod：
```sh
kubectl drain <node>
```

该命令会删除该节点上的所有 Pod（`DaemonSet` 除外），在其他 node 上重新启动它们，通常该节点需要维护时使用该命令。直接使用该命令会自动调用 `kubectl cordon <node>` 命令。
当该节点维护完成，启动了 kubelet 后，再使用 `kubectl uncordon <node>` 即可将该节点添加到 kubernetes 集群中。

## Node 状态
每个 Node 都包括以下状态信息：
- Addresses
  - HostName：节点内核报告的主机名，可以被 `kubelet` 中的 `--hostname-override` 参数替代。
  - ExternalIP：可以被集群外部路由到的 IP 地址。
  - InternalIP：集群内部使用的 IP，集群外部无法访问。
- Conditions， `conditions` 字段描述所有运行节点的状态。
  - OutOfDisk：如果节点上没有足够的空闲空间来添加新 pod 时为 `True`
  - Ready：Node controller 一定周期内（默认 40 秒）没有收到 node 的状态报告，则为 `Unknown`，健康为 `True`，否则为 `False`。
  - MemoryPressure：当 node 有内存压力时为 `True`，否则为 `False`。
  - PIDPressure：当 node 运行过多进程时为 `True`，否则为 `False`。
  - DiskPressure：当 node 有磁盘压力时为 `True`，否则为 `False`。
  - NetworkUnavailable：当 node 的网络配置错误时为 `True`，否则为 `False`。
- Capacity
  - CPU
  - 内存
  - 可运行的最大 Pod 个数
- Info：节点的一些版本信息，如 OS、kubernetes、docker 等