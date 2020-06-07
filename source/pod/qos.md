---
title: QoS
---

QoS（Quality of Service），是作用在 Pod 上的一个配置，当 Kubernetes 创建一个 Pod 时，它就会给这个 Pod 分配一个 QoS 等级，可以是以下等级之一：

- **Guaranteed**：Pod 里的每个容器都必须有内存/CPU 限制和请求，而且值必须相等。
- **Burstable**：Pod 里至少有一个容器有内存或者 CPU 请求且不满足 Guarantee 等级的要求，即内存/CPU 的值设置的不同。
- **BestEffort**：容器必须没有任何内存或者 CPU 的限制或请求。

**通过配置 CPU/内存 的 `limits` （上线） 与 `requests` （请求，调度器保证调度到资源充足的 Node 上，如果无法满足会调度失败） 值的大小来确认服务质量等级**。

`Guarantee` 示例：

```yml
spec:
  containers:
    ...
    resources:
      limits:
        cpu: 100m
        memory: 128Mi
      requests:
        cpu: 100m
        memory: 128Mi
```

`Burstable` 示例：

```yml
spec:
  containers:
    ...
    resources:
      limits:
        memory: "180Mi"
      requests:
        memory: "100Mi"
```

Kubernetes 通过 `cgroups` 限制容器的 CPU 和内存等计算资源:

- `spec.containers[].resources.limits.cpu`：CPU 上限，可以短暂超过，容器也不会被停止
- `spec.containers[].resources.limits.memory`：内存上限，不可以超过；如果超过，容器可能会被终止或调度到其他资源充足的机器上
- `spec.containers[].resources.limits.ephemeral-storage`：临时存储（容器可写层、日志以及 `EmptyDir` 等）的上限，超过后 Pod 会被驱逐
- `spec.containers[].resources.requests.cpu`：CPU 请求，也是调度 CPU 资源的依据，可以超过
- `spec.containers[].resources.requests.memory`：内存请求，也是调度内存资源的依据，可以超过；但如果超过，容器可能会在 Node 内存不足时清理
- `spec.containers[].resources.requests.ephemeral-storage`：临时存储（容器可写层、日志以及 `EmptyDir` 等）的请求，调度容器存储的依据

## 示例

比如 nginx 容器请求 30% 的 CPU 和 56MB 的内存，但限制最多只用 50% 的 CPU 和 128MB 的内存：

```yml
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: nginx
  name: nginx
spec:
  containers:
    - image: nginx
      name: nginx
      resources:
        requests:
          cpu: "300m"
          memory: "56Mi"
        limits:
          cpu: "1"
          memory: "128Mi"
```

- **CPU 的单位是 CPU 个数，可以用 `millicpu` (m) （`milli` 千分之一）表示少于 1 个 CPU 的情况，如 `500m = 500millicpu = 0.5cpu`，而一个 CPU 相当于
  - AWS 上的一个 vCPU
  - GCP 上的一个 Core
  - Azure 上的一个 vCore
  - 物理机上开启超线程时的一个超线程
- 内存的单位则包括 `E, P, T, G, M, K, Ei, Pi, Ti, Gi, Mi, Ki` 等。
- 从 v1.10 开始，可以设置 `kubelet ----cpu-manager-policy=static` 为 `Guaranteed`（即 `requests.cpu` 与 `limits.cpu` 相等）Pod 绑定 CPU。
