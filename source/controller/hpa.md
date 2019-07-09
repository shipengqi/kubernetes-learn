---
title: Horizontal Pod Autoscaling
---

# Horizontal Pod Autoscaling
应用的资源使用率通常都有高峰和低谷的时候，如何削峰填谷，提高集群的整体资源利用率，让 service 中的 Pod 个数自动调整？这就有赖于 Horizontal Pod Autoscaling 了，顾名思义，
Pod 水平自动缩放。

利用 Horizontal Pod Autoscaling，kubernetes 能够根据监测到的 CPU 利用率周期性地自动扩缩容 replication controller，deployment 和 replica set
中 pod 的数量。

## Horizontal Pod Autoscaler 如何工作
Horizontal Pod Autoscaler 由一个控制循环实现，循环周期由 controller manager 中的 `--horizontal-pod-autoscaler-sync-period` 标志指定（默认是 30 秒）。
在每个周期内，controller manager 会查询 HorizontalPodAutoscaler 中定义的 metric 的资源利用率。

支持三种 metric 类型
- 预定义 metric（比如 Pod 的 CPU）以利用率的方式计算
- 自定义的 Pod metric，以原始值（raw value）的方式计算
- 自定义的 object metric

支持多种 metrics 组合。

支持两种 metric 查询方式：
- 直接访问 Heapster，需要在集群上部署 Heapster 并在 `kube-system` namespace 中运行。
- 自定义的 REST API