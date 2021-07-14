---
title: Federation
---

在云计算环境中，服务的作用距离范围从近到远一般可以有：同主机（Host，Node）、跨主机同可用区（Available Zone）、跨可用区同地区（Region）、跨地区同服
务商（Cloud Service Provider）、跨云平台。K8s 的设计定位是单一集群在同一个地域内，因为同一个地区的网络性能才能满足 K8s 的调度和计算存储连接要求。
而[集群联邦](https://github.com/kubernetes-retired/federation)（Federation）就是为提供跨 Region 跨服务商 K8s 集群服务而设计的。

**每个 Federation 有自己的分布式存储、API Server 和 Controller Manager**。用户可以通过 Federation 的 API Server 注册该 Federation 的成
员 K8s Cluster。当用户通过 Federation 的 API Server 创建、更改 API 对象时，Federation API Server 会在自己所有注册的子 K8s Cluster 都创建
一份对应的 API 对象。在提供业务请求服务时，K8s Federation 会先在自己的各个子 Cluster 之间做负载均衡，而对于发送到某个具体 K8s Cluster 的业务请求，
会依照这个 K8s Cluster 独立提供服务时一样的调度模式去做 K8s Cluster 内部的负载均衡。而 Cluster 之间的负载均衡是通过域名服务的负载均衡来实现的。

所有的设计都尽量不影响 K8s Cluster 现有的工作机制，这样对于每个子 K8s 集群来说，并不需要更外层的有一个 K8s Federation，也就是意
味着所有现有的 K8s 代码和机制不需要因为 Federation 功能有任何变化。

<img src="/static/images/federation-api.png" width="70%">

Federation 主要包括三个组件：

- `federation-apiserver`：类似 `kube-apiserver`，但提供的是跨集群的 REST API
- `federation-controller-manager`：类似 `kube-controller-manager`，但提供多集群状态的同步机制
- `kubefed`：Federation 管理命令行工具
