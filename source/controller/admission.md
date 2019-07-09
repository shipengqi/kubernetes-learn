---
title: 准入控制
---

# 准入控制器
准入控制器（Admission Controller）位于 API Server 中，在对象被持久化之前，准入控制器拦截对 API Server 的请求，一般用来做身份验证和授权。
其中包含两个特殊的控制器：`MutatingAdmissionWebhook` 和 `ValidatingAdmissionWebhook`。分别作为配置的变更和验证
[准入控制 webhook](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#admission-webhooks)。

- 变更（Mutating）准入控制：修改请求的对象

- 验证（Validating）准入控制：验证请求的对象

准入控制器是在 API Server 的启动参数重配置的。一个准入控制器可能属于以上两者中的一种，也可能两者都属于。当请求到达 API Server 的时候首先执行变更准入控制，然后再执行验证准入控制。

我们在部署 Kubernetes 集群的时候都会默认开启一系列准入控制器，如果没有设置这些准入控制器的话可以说你的 Kubernetes 集群就是在裸奔，应该只有集群管理员可以修改集群的准入控制器。

## 为什么需要准入控制插件
Kubernetes 的许多高级功能都要求启用一个准入控制插件，以便正确地支持该特性。因此，一个没有正确配置准入控制插件的 Kubernetes API server 是不完整的，它不会支持所期望的所有特性。

## 准入控制器列表
准入控制支持同时开启多个插件，如果插件序列中任何一个拒绝了该请求，则整个请求将立即被拒绝并且返回一个错误给终端用户。
Kubernetes 目前提供了以下几种准入控制插件：
- AlwaysAdmit：通过所有的请求。
- AlwaysPullImages：此准入控制器修改每个 Pod 的时候都强制重新拉取镜像。
- AlwaysDeny：拒绝所有的请求。用于测试。
- DenyEscalatingExec：禁止特权容器的 `exec` 和 `attach` 操作。
- ImagePolicyWebhook：此准入控制器允许使用一个后端的 webhook 判断镜像拉取策略，例如配置镜像仓库的密钥。
- ServiceAccount：自动创建默认 ServiceAccount，并确保 Pod 引用的 ServiceAccount 已经存在。
- SecurityContextDeny：此准入控制器将拒绝任何试图设置某些升级的 SecurityContext 字段的 pod 。
- ResourceQuota：限制 Pod 的请求不会超过配额，需要在 namespace 中创建一个 ResourceQuota 对象。
- LimitRanger：此准入控制器将确保所有资源请求不会超过 namespace 的 LimitRange。
- InitialResources：此准入控制器观察 pod 创建请求。如果容器忽略了 requests 和 limits 计算资源，那么插件就会根据运行相同镜像的容器的历史使用记录来自动填充计算资源请求。
如果没有足够的数据进行决策，则请求将保持不变。
- NamespaceLifecycle：此准入控制器强制执行正在终止的命令空间中不能创建新对象，并确保 Namespace 拒绝不存在的请求。此准入控制器还防止缺失三个系统
保留的命名空间 `default`、`kube-system`、`kube-public`。
- DefaultStorageClass：此准入控制器观察创建 PersistentVolumeClaim 时不请求任何特定 StorageClass 的对象，并自动向其添加默认 StorageClass。这样，
用户就不需要关注特殊 StorageClass 而获得默认 StorageClass。
- DefaultTolerationSeconds：此准入控制器将 Pod 的容忍时间 `notready:NoExecute` 和 `unreachable:NoExecut`e 默认设置为 5 分钟。
- PodSecurityPolicy：使用 Pod Security Policies 时必须开启。
- NodeRestriction：限制 kubelet 仅可访问 node、endpoint、pod、service 以及 secret、configmap、PV 和 PVC 等相关的资源（仅适用于 v1.7+）
- EventRateLimit (alpha)：此准入控制器缓解了 API Server 被事件请求淹没的问题，限制时间速率。
- ExtendedResourceToleration：为使用扩展资源（如 GPU 和 FPGA 等）的 Pod 自动添加 `tolerations`。
- StorageProtection：自动给新创建的 PVC 增加 `kubernetes.io/pvc-protection` finalizer（v1.9 及以前版本为 `PVCProtection`，v.11 GA）
- Initializers (alpha)：Pod初始化的准入控制器，详情请参考动态准入控制。
- LimitPodHardAntiAffinityTopology：此准入控制器拒绝任何在 requiredDuringSchedulingRequiredDuringExecution 的 AntiAffinity 字段中定义除了kubernetes.io/hostname 之外的拓扑关键字的 pod 。
- PersistentVolumeClaimResize：允许设置 `allowVolumeExpansion=true` 的 StorageClass 调整 PVC 大小（v1.11 Beta）
- NamespaceAutoProvision：此准入控制器检查命名空间资源上的所有传入请求，并检查引用的命名空间是否存在。如果不存在就创建一个命名空间。
- NamespaceExists：此许可控制器检查除 Namespace 其自身之外的命名空间资源上的所有请求。如果请求引用的命名空间不存在，则拒绝该请求。
- PodNodeSelector：限制一个 Namespace 中可以使用的 Node 选择标签。
- ValidatingAdmissionWebhook：使用 Webhook 验证请求，这些 Webhook 并行调用，并且任何一个调用拒绝都会导致请求失败。
- MutatingAdmissionWebhook：使用 Webhook 修改请求，这些 Webhook 依次顺序调用。



## 动态准入控制器
标准的，插件化的 admission controller 对于大多数用户来说还不够灵活：
- 需要把它编译到 `kube-apiserver` 二进制文件中
- 只能在启动时进行配置

1.7 引入了2个alpha的功能，Initializers 和 `GenericAdmissionWebhook` 来解决这些限制。

### Initializers

### GenericAdmissionWebhook

## 推荐配置
### Kubernetes 1.10+
Kubernetes 1.10 及更高版本，建议使用 `--enable-admission-plugins` 标志运行以下一组准入控制器（**顺序无关紧要**）。
```sh
--enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,DefaultTolerationSeconds,MutatingAdmissionWebhook,ValidatingAdmissionWebhook,ResourceQuota
```

> `--admission-control` 在 `1.10` 中已弃用并替换为 `--enable-admission-plugins`。

### Kubernetes 1.9
Kubernetes 1.9 及更早版本，建议使用 `--admission-control` 标志（顺序有关）运行以下一组许可控制器。
```sh
--admission-control=NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,DefaultTolerationSeconds,MutatingAdmissionWebhook,ValidatingAdmissionWebhook,ResourceQuota
```
