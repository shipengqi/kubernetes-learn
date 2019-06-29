# Pod 生命周期

Pod 的 `status` 字段是一个 `PodStatus` 对象，`PodStatus` 中有一个 `phase` 字段。`phase` 可能的状态：

- Pending: Pod 已经在 apiserver 中创建，但有一个或者多个容器镜像尚未创建。等待时间包括调度 Pod 的时间和通过网络下载镜像的时间，这可能需要花点时间。
- Running: Pod 已经调度到 Node 上面，所有容器都已经创建，并且至少有一个容器还在运行或者正在启动。
- Succeeded: Pod 中的所有容器都被成功终止，并且不会再重启。
- Failed: Pod 中的所有容器都已终止了，并且至少有一个容器运行失败（即退出码不为 0 或者被系统终止）。
- Unknonwn: 状态未知，通常是由于 apiserver 无法与 kubelet 通信导致。

## 探针

探针是由 [kubelet]() 对容器执行的定期诊断。要执行诊断，kubelet 调用由容器实现的 [Handler](https://godoc.org/k8s.io/kubernetes/pkg/api/v1#Handler)。
有三种类型的处理程序：

ExecAction：在容器内执行指定命令。如果命令退出时返回码为 0 则认为诊断成功。
TCPSocketAction：对指定端口上的容器的 IP 地址进行 TCP 检查。如果端口打开，则诊断被认为是成功的。
HTTPGetAction：对指定的端口和路径上的容器的 IP 地址执行 HTTP Get 请求。如果响应的状态码大于等于200 且小于 400，则诊断被认为是成功的。