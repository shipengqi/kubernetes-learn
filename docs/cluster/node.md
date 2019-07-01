# Node
Node 是 Pod 真正运行的主机，可以是物理机也可以是虚拟机。每个 Node 节点上至少要运行 container runtime（比如 `docker` 或者 `rkt`）、`kubelet` 和 `kube-proxy` 服务。

## Node 管理
Node 本质上不是 Kubernetes 来创建的，Kubernetes 只是管理 Node 上的资源。虽然可以通过 Manifest 创建一个 Node 对象（如下 yaml 所示），但 Kubernetes 也只是去
检查是否真的是有这么一个 Node，如果检查失败，也不会往上调度 Pod。