---
title: hyperkube
---

# hyperkube
hyperkube 是 Kubernetes 的 **allinone** binary，可以用来启动多种 kubernetes 服务，常用在 Docker 镜像中。每个 Kubernetes 发布都会同时发布一
个包含 hyperkube 的 docker 镜像，如 `gcr.io/google_containers/hyperkube:v1.6.4`。
hyperkube 支持的子命令包括：
- kubelet
- apiserver
- controller-manager
- federation-apiserver
- federation-controller-manager
- kubectl
- proxy
- scheduler