---
title: Pod 中断与 PDB
---

PDB（Pod 中断预算）
Pod 不会消失，直到有人（人类或控制器）将其销毁，或者当出现不可避免的硬件或系统软件错误。我们把这些不可避免的情况称为应用的**非自愿性中断**。例如：

- 后端节点物理机的硬件故障
- 集群管理员错误地删除虚拟机（实例）
- 云提供商或管理程序故障使虚拟机消失
- 内核恐慌（kernel panic）
- 节点由于集群网络分区而从集群中消失
- 由于节点资源不足而将容器逐出

下面这些情况为**自愿中断**，包括由应用程序所有者发起的操作和由集群管理员发起的操作。应用程序所有者操作包括：

- 删除管理该 pod 的 Deployment 或其他控制器
- 更新了 Deployment 的 pod 模板导致 pod 重启
- 直接删除 pod（意外删除）

集群管理员操作包括：

- [排空（drain）节点](https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/)进行修复或升级。
- 从集群中排空节点以缩小集群（了解集群自动调节）。
- 从节点中移除一个 pod，以允许其他 pod 使用该节点。

## 处理中断

一些减轻非自愿性中断的方法：

- 确保 pod 请求所需的资源。
- 为了更高的可用性，复制你的应用程序。
- 为了在运行复制应用程序时获得更高的可用性，请跨机架
（使用[反亲和性](https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#inter-pod-affinity-and-anti-affinity-beta-feature)）或
跨区域（如果使用[多区域集群](https://kubernetes.io/docs/setup/best-practices/multiple-zones/)）分布应用程序。

## 中断预算的工作原理

应用程序所有者可以为每个应用程序创建一个 PodDisruptionBudget 对象（PDB）。 PDB 将限制在同一时间自愿中断的宕机的 Pod 的数量。

集群管理器和托管提供商应使用遵循 Pod Disruption Budgets 的工具，方法是调
用 [Eviction API](https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/#the-eviction-api) 而不是直接删除 Pod。
例如 `kubectl drain` 命令和 `Kubernetes-on-GCE` 集群升级脚本（`cluster/gce/upgrade.sh`）。

当集群管理员想要排空节点时，可以使用 `kubectl drain` 命令。该命令会试图驱逐机器上的所有 pod。驱逐请求可能会暂时被拒绝，并且该工具会定期重试所有失败的请求，直
到所有的 pod 都被终止，或者直到达到配置的超时时间。

## PDB 示例

假设集群有 3 个节点，`node-1` 到 `node-3`。集群中运行了一些应用，其中一个应用有 3 个副本，分别是 `pod-a`、`pod-b` 和 `pod-c`。另外，还有一个与它相关的不
具有 PDB 的 pod，我们称为之为 `pod-x`。最初，所有 Pod 的分布如下：

| node-1 | node-2 | node-3 |
| --- | --- | --- |
| pod-a available | pod-b available | pod-c available |
| pod-x available |  |  |

所有的3个 pod 都是 Deployment 中的一部分，并且它们共同拥有一个 PDB，要求至少有3个 pod 中的2个始终处于可用状态。

例如，假设集群管理员想要重启系统，升级内核版本来修复内核中的错误。集群管理员首先使用 `kubectl drain` 命令尝试排除 `node-1`。该工具试图驱逐 `pod-a` 和 `pod-x`。这立即成功。
两个 Pod 同时进入终止状态。这时的集群处于这种状态：

| node-1 | node-2 | node-3 |
| --- | --- | --- |
| pod-a terminating | pod-b available | pod-c available |
| pod-x terminating |  |  |

Deployment 注意到其中有一个 pod 处于正在终止，因此会创建了一个 `pod-d` 来替换。由于 `node-1` 被封锁（cordon），它落在另一个节点上。同时其它控制器也创建了 `pod-y` 作为 `pod-x` 的替代品。

当前集群的状态如下：

| node-1 | node-2 | node-3 |
| --- | --- | --- |
| pod-a terminating | pod-b available | pod-c available |
| pod-x terminating | pod-d starting | pod-y |

在某一时刻，pod 被终止，集群看起来像下面这样子：

| node-1 drained | node-2 | node-3 |
| --- | --- | --- |
|  | pod-b available | pod-c available |
|  | pod-d starting | pod-y |

此时，如果一个急躁的集群管理员试图排空（drain）`node-2` 或 `node-3`，drain 命令将被阻塞，因为对于 Deployment 只有2个可用的 pod，并且其 PDB 至少需要2个。
经过一段时间，`pod-d` 变得可用。

| node-1 drained | node-2 | node-3 |
| --- | --- | --- |
|  | pod-b available | pod-c available |
|  | pod-d available | pod-y |

现在，集群管理员尝试排空 `node-2`。drain 命令将尝试按照某种顺序驱逐两个 pod，假设先是 `pod-b`，然后再 `pod-d`。它将成功驱逐 `pod-b`。但是，当它试图驱逐 `pod-d` 时，
将被拒绝，因为这样对 Deployment 来说将只剩下一个可用的 pod。

Deployment 将创建一个名为 `pod-e` 的 `pod-b` 的替代品。但是，集群中没有足够的资源来安排 `pod-e`。那么，`drain` 命令就会被阻塞。集群最终可能是这种状态：

| node-1 drained | node-2 | node-3 | no node |
| --- | --- | --- | --- |
|  | pod-b available | pod-c available | pod-e pending |
|  | pod-d available | pod-y |  |

此时，集群管理员需要向集群中添加回一个节点以继续升级操作。

可以看到 Kubernetes 如何改变中断发生的速率，根据：

- 应用程序需要多少副本
- 正常关闭实例需要多长时间
- 启动新实例需要多长时间
- 控制器的类型
- 集群的资源能力

## 如何在集群上执行中断操作

如果是集群管理员，要对集群的所有节点执行中断操作，例如节点或系统软件升级，则可以使用以下选择：

- 在升级期间接受停机时间。
- 故障转移到另一个完整的副本集群。
  - 没有停机时间，但是对于重复的节点和人工协调成本可能是昂贵的。
- 编写可容忍中断的应用程序和使用 PDB。
  - 没有停机时间。
  - 最小的资源重复。
  - 允许更多的集群管理自动化。
  - 编写可容忍中断的应用程序是很棘手的，但对于可容忍自愿中断，和支持自动调整以容忍非自愿中断，两者在工作上有大量的重叠。
