---
title: QoS
---

# QoS（服务质量等级）
QoS（Quality of Service），是作用在 Pod 上的一个配置，当 Kubernetes 创建一个 Pod 时，它就会给这个 Pod 分配一个 QoS 等级，可以是以下等级之一：
- **Guaranteed**：Pod 里的每个容器都必须有内存/CPU 限制和请求，而且值必须相等。
- **Burstable**：Pod 里至少有一个容器有内存或者 CPU 请求且不满足 Guarantee 等级的要求，即内存/CPU 的值设置的不同。
- **BestEffort**：容器必须没有任何内存或者 CPU 的限制或请求。