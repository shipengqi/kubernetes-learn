# kubernetes
Kubernetes learning.

多集群管理

多集群是指在多个独立的 Kubernetes 集群上部署和管理应用程序的策略。

配置多集群访问

使用 kubectl 管理多集群

Kubernetes 提供了内置的多集群访问配置功能：

```bash
# 查看当前配置的集群
kubectl config get-clusters

# 切换集群上下文
kubectl config use-context <context-name>

# 查看当前上下文
kubectl config current-context
```


现代多集群管理方案
集群联邦（已弃用）


现代多集群解决方案


服务网格方案

Istio：提供跨集群的服务发现和流量管理
Linkerd：轻量级服务网格，支持多集群通信
Consul Connect：提供跨集群服务连接

专用多集群平台

Admiral：Istio 的多集群管理扩展
Submariner：专注于跨集群网络连接
Liqo：动态跨集群资源共享