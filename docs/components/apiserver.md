# kube-apiserver
`kube-apiserver` 是 Kubernetes 最重要的核心组件之一，主要提供以下的功能：
- 提供集群管理的 REST API 接口，包括认证授权、数据校验以及集群状态变更等
- 提供其他模块之间的数据交互和通信的枢纽（其他模块通过 API Server 查询或修改数据，只有 API Server 才直接操作 `etcd`）