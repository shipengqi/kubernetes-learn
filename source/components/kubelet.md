---
title: kubelet
---

# kubelet
每个节点上都运行一个 `kubelet` 服务进程，默认监听 `10250` 端口，接收并执行 master 发来的指令，管理 Pod 及 Pod 中的容器。每个 `kubelet` 进程会在 API Server 上注册节点
自身信息，定期向 master 节点汇报节点的资源使用情况，并通过 cAdvisor 监控节点和容器的资源。