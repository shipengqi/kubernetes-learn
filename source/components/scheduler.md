---
title: kube-scheduler
---

# kube-scheduler
`kube-scheduler` 负责分配调度 Pod 到集群内的节点上，它监听 `kube-apiserver`，查询还未分配 Node 的 Pod，然后根据调度策略为这些 Pod 分配节点（更新 Pod 的 NodeName 字段）。