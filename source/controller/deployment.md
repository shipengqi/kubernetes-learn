---
title: Deployment
---

Deployment 为 Pod 和 ReplicaSet 提供了一个声明式定义 (declarative) 方法，用来替代以前的 ReplicationController 来方便的管理应用。

**Deployment 控制器实际操纵的，是 ReplicaSet 对象，而不是 Pod 对象**。

**一个 ReplicaSet 对象，其实就是由副本数目的定义和一个 Pod 模板组成的**。

Deployment，与 ReplicaSet，以及 Pod 的关系：

![deploy-repalicas-pod](../imgs/deploy-repalicas-pod.png)

Deployment，与它的 ReplicaSet，以及 Pod 的关系，实际上是一种“层层控制”的关系。

ReplicaSet 负责通过“控制器模式”，保证系统中 Pod 的个数永远等于指定的个数。这也正是 **Deployment 只允许容器的 restartPolicy=Always** 的主要原因：只有在
容器能保证自己始终是 Running 状态的前提下，ReplicaSet 调整 Pod 的个数才有意义。

Deployment 同样通过“控制器模式”，来操作 ReplicaSet 的个数和属性，进而实现“水平扩展/收缩”和“滚动更新”。“水平扩展/收缩” 只需要修改它所控制的 ReplicaSet 的 Pod 副本个数就可以了。将一个集群中正在运行的多个 Pod 版本，交替地逐一升级的过程，就是“滚动更新”。

## 创建 Deployment

`nginx-deployment.yaml`：

```yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.7.9
        ports:
        - containerPort: 80
```

```sh
kubectl create -f ./nginx-deployment.yaml --record
```

**`--record` 设置为 `true` 可以在 `annotation` 中记录当前命令创建或者升级了该资源**。这在未来会很有用，例如，查看在每个 Deployment revision 中执行了哪些命令。

执行 `get` 将获得如下结果：

```sh
$ kubectl get deployments
NAME               READY     UP-TO-DATE   AVAILABLE   AGE
nginx-deployment    0/3          0            0       1s
```

输出结果表明我们希望的 repalica 数是 3（根据 deployment 中的 `.spec.replicas` 配置）当前 replica 数（ .status.replicas）是 0,
最新的 replica 数（`.status.updatedReplicas`）是 0，可用的 replica 数（`.status.availableReplicas`）是 0。

过几秒后再执行 `get` 命令，将获得如下输出：

```sh
$ kubectl get deployments
NAME               READY     UP-TO-DATE   AVAILABLE   AGE
nginx-deployment    3/3          0            0       1s
```

可用的（根据 Deployment 中的 `.spec.minReadySeconds` 声明，处于已就绪状态的 pod 的最少个数）。执行 `kubectl get rs` 和 `kubectl get pods` 会
显示 Replica Set（RS）和 Pod 已创建。

```sh
$ kubectl get rs
NAME                          DESIRED   CURRENT   READY   AGE
nginx-deployment-2035384211   3         3         0       18s
```

Replica Set 的名字总是 `<Deployment name>-<pod template 的 hash 值 >`。

## 更新 Deployment

**Deployment 的 rollout 当且仅当 Deployment 的 pod template（例如 `.spec.template`）中的 label 更新或者镜像更改时被触发**。
其他更新，例如扩容 Deployment 不会触发 rollout。

假如我们现在想要让 nginx pod 使用 `nginx:1.9.1` 的镜像来代替原来的 `nginx:1.7.9` 的镜像。

```sh
$ kubectl set image deployment/nginx-deployment nginx=nginx:1.9.1
deployment "nginx-deployment" image updated
```

也可以使用 `edit` 命令来编辑 Deployment，修改 `.spec.template.spec.containers[0].image` ，将 `nginx:1.7.9` 改写成 `nginx:1.9.1`。

```sh
$ kubectl edit deployment/nginx-deployment
deployment "nginx-deployment" edited
```

查看 rollout 的状态，只要执行：

```sh
$ kubectl rollout status deployment/nginx-deployment
Waiting for rollout to finish: 2 out of 3 new replicas have been updated...
deployment "nginx-deployment" successfully rolled out
```

执行 `kubectl get rs` 可以看到 Deployment 更新了 Pod，通过创建一个新的 Replica Set 并扩容了 3 个 replica，同时将原来的 Replica Set 缩容到了 0 个 replica。

```sh
$ kubectl get rs
NAME                          DESIRED   CURRENT   READY   AGE
nginx-deployment-1564180365   3         3         0       6s
nginx-deployment-2035384211   0         0         0       36s
```

### Rollover（多个 rollout 并行）

每当 Deployment controller 观测到有新的 deployment 被创建时，如果没有已存在的 Replica Set 来创建期望个数的 Pod 的话，就会创建出一个新的 Replica Set 来做这件事。
已存在的 Replica Set 控制 label 匹配 `.spec.selector` 但是 template 跟 `.spec.template` 不匹配的 Pod 缩容。最终，新的 Replica Set 将会扩容出 `.spec.replicas` 指定
数目的 Pod，旧的 Replica Set 会缩容到 0。

如果你更新了一个的已存在并正在进行中的 Deployment，每次更新 Deployment 都会创建一个新的 Replica Set 并扩容它，同时回滚之前扩容的 Replica Set——将它添加
到旧的 Replica Set 列表，开始缩容。

例如，假如你创建了一个有 5 个 `niginx:1.7.9` replica 的 Deployment，但是当还只有 3 个 `nginx:1.7.9` 的 replica 创建出来的时候你就开始更新含有 5 个 `nginx:1.9.1` replica
的 Deployment。在这种情况下，Deployment 会立即杀掉已创建的 3 个 `nginx:1.7.9` 的 Pod，并开始创建 `nginx:1.9.1` 的 Pod。它不会等到所有的 5 个 `nginx:1.7.9` 的 Pod 都
创建完成后才开始执行滚动更新。

## 回退 Deployment

有时候你可能想回退一个 Deployment，例如，当 Deployment 不稳定时，比如一直 crash looping。

默认情况下，kubernetes 会在系统中保存所有的 Deployment 的 rollout 历史记录，以便你可以随时回退（你可以修改 revision history limit 来更改保存的 revision 数）。
只要 Deployment 的 rollout 被触发就会创建一个 revision。

假设我们在更新 Deployment 的时候犯了一个拼写错误，将镜像的名字写成了 `nginx:1.91`，而正确的名字应该是 `nginx:1.9.1`，Rollout 将会卡住。：

```sh
$ kubectl rollout status deployments nginx-deployment
Waiting for rollout to finish: 2 out of 3 new replicas have been updated...
```

你会看到旧的 replicas（`nginx-deployment-1564180365` 和 `nginx-deployment-2035384211`）和新的 replicas （`nginx-deployment-3066724191`）数目都是 2 个。

```sh
$ kubectl get rs
NAME                          DESIRED   CURRENT   READY   AGE
nginx-deployment-1564180365   2         2         0       25s
nginx-deployment-2035384211   0         0         0       36s
nginx-deployment-3066724191   2         2         2       6s
```

看下创建 Pod，你会看到有两个新的 Replica Set 创建的 Pod 处于 `ImagePullBackOff` 状态，循环拉取镜像。

```sh
$ kubectl get pods
NAME                                READY     STATUS             RESTARTS   AGE
nginx-deployment-1564180365-70iae   1/1       Running            0          25s
nginx-deployment-1564180365-jbqqo   1/1       Running            0          25s
nginx-deployment-3066724191-08mng   0/1       ImagePullBackOff   0          6s
nginx-deployment-3066724191-eocby   0/1       ImagePullBackOff   0          6s
```

Deployment controller 会自动停止坏的 rollout，并停止扩容新的 Replica Set。为了修复这个问题，我们需要回退到稳定的 Deployment revision。

### 检查 Deployment 升级的历史记录

```sh
$ kubectl rollout history deployment/nginx-deployment
deployments "nginx-deployment":
REVISION    CHANGE-CAUSE
1           kubectl create -f docs/user-guide/nginx-deployment.yaml --record
2           kubectl set image deployment/nginx-deployment nginx=nginx:1.9.1
3           kubectl set image deployment/nginx-deployment nginx=nginx:1.91
```

因为我们创建 Deployment 的时候使用了 `--record` 参数可以记录命令，我们可以很方便的查看每次 revison 的变化。

查看单个 revision 的详细信息：

```sh
$ kubectl rollout history deployment/nginx-deployment --revision=2
deployments "nginx-deployment" revision 2
  Labels:       app=nginx
          pod-template-hash=1159050644
  Annotations:  kubernetes.io/change-cause=kubectl set image deployment/nginx-deployment nginx=nginx:1.9.1
  Containers:
   nginx:
    Image:      nginx:1.9.1
    Port:       80/TCP
     QoS Tier:
        cpu:      BestEffort
        memory:   BestEffort
    Environment Variables:      <none>
  No volumes.
```

### 回退到历史版本

我们可以决定回退当前的 rollout 到之前的版本：

```sh
$ kubectl rollout undo deployment/nginx-deployment
deployment "nginx-deployment" rolled back
```

也可以使用 `--to-revision` 参数指定某个历史版本：

```sh
$ kubectl rollout undo deployment/nginx-deployment --to-revision=2
deployment "nginx-deployment" rolled back
```

回退以后，Deployment controller 会产生了一个回退到 revison 2 的 DeploymentRollback 的 event。

```sh
$ kubectl get deployment
NAME               DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
nginx-deployment   3         3         3            3           30m

$ kubectl describe deployment
Name:           nginx-deployment
Namespace:      default
...
Events:
  FirstSeen LastSeen    Count   From                    SubobjectPath   Type        Reason              Message
  --------- --------    -----   ----                    -------------   --------    ------              -------
  30m       30m         1       {deployment-controller}                Normal      ScalingReplicaSet   Scaled up replica set nginx-deployment-2035384211 to 3
  ...
  2m        2m          1       {deployment-controller}                Normal      DeploymentRollback  Rolled back deployment "nginx-deployment" to revision 2
```

### 清理 Policy

你可以通过**设置 `.spec.revisionHistoryLimit` 项来指定 deployment 最多保留多少 revison 历史记录。默认的会保留所有的 revision；如果将该项设置为 `0`，
将导致该 Deployment 的所有历史记录都被清除，Deployment 就不允许回退了**。

## Deployment 扩容

```sh
$ kubectl scale deployment nginx-deployment --replicas 10
deployment "nginx-deployment" scaled
```

如果集群中启用了 [horizontal pod autoscaling (HPA)](./hpa.html)，你可以给 Deployment 设置一个 `autoscaler`，基于当前 Pod 的 CPU 利用率选择最
少和最多的 Pod 数。

```sh
$ kubectl autoscale deployment nginx-deployment --min=10 --max=15 --cpu-percent=80
deployment "nginx-deployment" autoscaled
```

### 比例扩容

为了保证服务的连续性，Deployment Controller 会确保，在任何时间窗口内，只有指定比例的 Pod 处于离线状态。同时，它也会确保，在任何时间窗口内，
只有指定比例的新 Pod 被创建出来。这两个比例的值都是可以配置的，默认都是 DESIRED 值的 25%。这被称为比例扩容。

例如，一个 Deployment 有 3 个 Pod 副本，那么控制器在“滚动更新”的过程中永远都会确保至少有 2 个 Pod 处于可用状态，至多只有 4 个 Pod 同时存在于集群中。

这个策略，是 Deployment 对象的一个字段，叫 RollingUpdateStrategy。

```yml
strategy:
type: RollingUpdate
rollingUpdate:
  maxSurge: 1
  maxUnavailable: 1
```

`maxSurge` 指定的是除了 DESIRED 数量之外，在一次“滚动”中，Deployment 控制器还可以创建多少个新 Pod。
`maxUnavailable` 指的是，在一次“滚动”中，Deployment 控制器可以删除多少个旧 Pod。

这两个配置还可以用百分比形式来表示，比如：`maxUnavailable=50%`，指的是最多可以一次删除“50%*DESIRED 数量”个 Pod。

## 暂停和恢复 Deployment

你可以在触发一次或多次更新前暂停一个 Deployment，然后再恢复它。这样你就能多次暂停和恢复 Deployment，在此期间进行一些修复工作，
而不会触发不必要的 rollout。

例如使用刚刚创建 Deployment：

```sh
$ kubectl get deploy
NAME      DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
nginx     3         3         3            3           1m
[mkargaki@dhcp129-211 kubernetes]$ kubectl get rs
NAME               DESIRED   CURRENT   READY     AGE
nginx-2142116321   3         3         3         1m
```

使用以下命令暂停 Deployment：

```sh
$ kubectl rollout pause deployment/nginx-deployment
deployment "nginx-deployment" paused
```

然后更新 Deplyment 中的镜像：

```sh
$ kubectl set image deploy/nginx nginx=nginx:1.9.1
deployment "nginx-deployment" image updated
```

注意没有启动新的 rollout：

```sh
$ kubectl rollout history deploy/nginx
deployments "nginx"
REVISION  CHANGE-CAUSE
1   <none>

$ kubectl get rs
NAME               DESIRED   CURRENT   READY     AGE
nginx-2142116321   3         3         3         2m
```

可以进行任意多次更新，例如更新使用的资源：

```sh
$ kubectl set resources deployment nginx -c=nginx --limits=cpu=200m,memory=512Mi
deployment "nginx" resource requirements updated
```

Deployment 暂停前的初始状态将继续它的功能，而不会对 Deployment 的更新产生任何影响，只要 Deployment 是暂停的。

最后，恢复这个 Deployment，观察完成更新的 ReplicaSet 已经创建出来了：

```sh
$ kubectl rollout resume deploy nginx
deployment "nginx" resumed
$ KUBECTL get rs -w
NAME               DESIRED   CURRENT   READY     AGE
nginx-2142116321   2         2         2         2m
nginx-3926361531   2         2         0         6s
nginx-3926361531   2         2         1         18s
nginx-2142116321   1         2         2         2m
nginx-2142116321   1         2         2         2m
nginx-3926361531   3         2         1         18s
nginx-3926361531   3         2         1         18s
nginx-2142116321   1         1         1         2m
nginx-3926361531   3         3         1         18s
nginx-3926361531   3         3         2         19s
nginx-2142116321   0         1         1         2m
nginx-2142116321   0         1         1         2m
nginx-2142116321   0         0         0         2m
nginx-3926361531   3         3         3         20s
^C
$ KUBECTL get rs
NAME               DESIRED   CURRENT   READY     AGE
nginx-2142116321   0         0         0         2m
nginx-3926361531   3         3         3         28s
```

**在恢复 Deployment 之前你无法回退一个暂停了的 Deployment**。

## Deployment 状态

Deployment 在生命周期中有多种状态。在创建一个新的 ReplicaSet 的时候它可以是 `progressing` 状态， `complete` 状态，或者 `fail to progress` 状态。

### Progressing Deployment

Kubernetes 将执行过下列任务之一的 Deployment 标记为 `progressing` 状态：

- Deployment 正在创建新的 ReplicaSet 过程中。
- Deployment 正在扩容一个已有的 ReplicaSet。
- Deployment 正在缩容一个已有的 ReplicaSet。
- 有新的可用的 pod 出现。

你可以使用 `kubectl rollout status` 命令监控 Deployment 的进度。

### Complete Deployment

Kubernetes 将包括以下特性的 Deployment 标记为 `complete` 状态：

- Deployment 最小可用。最小可用意味着 Deployment 的可用 replica 个数等于或者超过 Deployment 策略中的期望个数。
所有与该 Deployment 相关的 replica 都被更新到了你指定版本，也就说更新完成。
- 该 Deployment 中没有旧的 Pod 存在。

你可以用 `kubectl rollout status` 命令查看 Deployment 是否完成。如果 rollout 成功完成，`kubectl rollout status` 将返回一个 0 值的 Exit Code。

### Failed Deployment

你的 Deployment 在尝试部署新的 ReplicaSet 的时候可能卡住，永远也不会完成。这可能是因为以下几个因素引起的：

- 无效的引用
- 不可读的 probe failure
- 镜像拉取错误
- 权限不够
- 范围限制
- 程序运行时配置错误

探测这种情况的一种方式是，在你的 Deployment spec 中指定 `spec.progressDeadlineSeconds`。`spec.progressDeadlineSeconds` 表示 Deployment controller 等待
多少秒才能确定（通过 Deployment status）Deployment 进程是卡住的。

下面的 kubectl 命令设置 `progressDeadlineSeconds` 使 controller 在 Deployment 在进度卡住 10 分钟后报告：

```sh
$ kubectl patch deployment/nginx-deployment -p '{"spec":{"progressDeadlineSeconds":600}}'
"nginx-deployment" patched
```

当超过截止时间后，Deployment controller 会在 Deployment 的 `status.conditions` 中增加一条 DeploymentCondition，它包括如下属性：

- `Type=Progressing`
- `Status=False`
- `Reason=ProgressDeadlineExceeded`

> **注意**: kubernetes 除了报告 `Reason=ProgressDeadlineExceeded` 状态信息外不会对卡住的 Deployment 做任何操作。更高层次的协调器可以利用它并采取
相应行动，例如，回滚 Deployment 到之前的版本。
> **注意**： 如果你暂停了一个 Deployment，在暂停的这段时间内 kubernetnes 不会检查你指定的 deadline。你可以在 Deployment 的 rollout 途中安全的暂停
它，然后再恢复它，这不会触发超过 deadline 的状态。

你可能在使用 Deployment 的时候遇到一些短暂的错误，这些可能是由于你设置了太短的 timeout，也有可能是因为各种其他错误导致的短暂错误。例如，假设你使用了
无效的引用。当你 Describe Deployment 的时候可能会注意到如下信息：

```sh
$ kubectl describe deployment nginx-deployment
<...>
Conditions:
  Type            Status  Reason
  ----            ------  ------
  Available       True    MinimumReplicasAvailable
  Progressing     True    ReplicaSetUpdated
  ReplicaFailure  True    FailedCreate
<...>
```

执行 `kubectl get deployment nginx-deployment -o yaml，Deployement` 的状态可能看起来像这个样子：

```sh
status:
  availableReplicas: 2
  conditions:
  - lastTransitionTime: 2016-10-04T12:25:39Z
    lastUpdateTime: 2016-10-04T12:25:39Z
    message: Replica set "nginx-deployment-4262182780" is progressing.
    reason: ReplicaSetUpdated
    status: "True"
    type: Progressing
  - lastTransitionTime: 2016-10-04T12:25:42Z
    lastUpdateTime: 2016-10-04T12:25:42Z
    message: Deployment has minimum availability.
    reason: MinimumReplicasAvailable
    status: "True"
    type: Available
  - lastTransitionTime: 2016-10-04T12:25:39Z
    lastUpdateTime: 2016-10-04T12:25:39Z
    message: 'Error creating: pods"nginx-deployment-4262182780-" is forbidden: exceeded quota:
      object-counts, requested: pods=1, used: pods=3, limited: pods=2'
    reason: FailedCreate
    status: "True"
    type: ReplicaFailure
  observedGeneration: 3
  replicas: 2
  unavailableReplicas: 2
```

最终，一旦超过 Deployment 进程的 deadline，kuberentes 会更新状态和导致 Progressing 状态的原因：

```sh
Conditions:
  Type            Status  Reason
  ----            ------  ------
  Available       True    MinimumReplicasAvailable
  Progressing     False   ProgressDeadlineExceeded
  ReplicaFailure  True    FailedCreate
```

## 编写 Deployment Spec

Deployment 也需要 `apiVersion`、`kind`、`metadata` 和 `spec` 这些配置项。

### template

`.spec.template` 是 `.spec` 中唯一要求的字段。
`.spec.template` 是 pod template. 它跟 Pod 有一模一样的 schema，并且不需要 `apiVersion` 和 `kind` 字段。

`.spec.template.spec.restartPolicy` 可以设置为 `Always` , 如果不指定的话这就是默认配置。

### Replicas

`.spec.replicas` 是可以选字段，指定期望的 pod 数量，默认是 1。

### Selector

`.spec.selector` 是可选字段，用来指定 label selector ，圈定 Deployment 管理的 pod 范围。

如果被指定， `.spec.selector` 必须匹配 `.spec.template.metadata.labels`，否则它将被 API 拒绝。如果 `.spec.selector` 没有被
指定， `.spec.selector.matchLabels` 默认是 `.spec.template.metadata.labels`。

### 策略

`.spec.strategy` 指定新的 Pod 替换旧的 Pod 的策略。 `.spec.strategy.type` 可以是 "Recreate" 或者是 "RollingUpdate"。"RollingUpdate" 是默认值。

#### Recreate Deployment

`.spec.strategy.type==Recreate` 时，在创建出新的 Pod 之前会先杀掉所有已存在的 Pod。

#### Rolling Update Deployment

`.spec.strategy.type==RollingUpdate` 时，Deployment 使用 rolling update 的方式更新 Pod 。你可以指定 `maxUnavailable` 和 `maxSurge` 来
控制 rolling update 进程。

#### Max Unavailable

`.spec.strategy.rollingUpdate.maxUnavailable` 是可选配置项，用来指定在升级过程中不可用 Pod 的最大数量。该值可以是一个绝对值（例如 5），也可以是期望 Pod 数量
的百分比（例如 10%）。通过计算百分比的绝对值向下取整。如果 `.spec.strategy.rollingUpdate.maxSurge` 为 0 时，这个值不可以为 0。默认值是 1。

例如，该值设置成 30%，启动 rolling update 后旧的 ReplicatSet 将会立即缩容到期望的 Pod 数量的 70%。新的 Pod ready 后，随着新的 ReplicaSet 的扩容，旧
的 ReplicaSet 会进一步缩容，确保在升级的所有时刻可以用的 Pod 数量至少是期望 Pod 数量的 70%。

#### Max Surge

`.spec.strategy.rollingUpdate.maxSurge` 是可选配置项，用来指定可以超过期望的 Pod 数量的最大个数。该值可以是一个绝对值（例如 5）或者是期
望的 Pod 数量的百分比（例如 10%）。当 `MaxUnavailable` 为 0 时该值不可以为 0。通过百分比计算的绝对值向上取整。默认值是 1。

例如，该值设置成 30%，启动 rolling update 后新的 ReplicatSet 将会立即扩容，新老 Pod 的总数不能超过期望的 Pod 数量的 130%。旧的 Pod 被杀掉后，新的 ReplicaSet
将继续扩容，旧的 ReplicaSet 会进一步缩容，确保在升级的所有时刻所有的 Pod 数量和不会超过期望 Pod 数量的 130%。

### Progress Deadline Seconds

`spec.progressDeadlineSeconds` 表示 Deployment controller 等待多少秒才能确定（通过 Deployment status）Deployment 进程是卡住的。
未来，在实现了自动回滚后， deployment controller 在观察到这种状态时就会自动回滚。**如果设置该参数，该值必须大于 `.spec.minReadySeconds`**。

### Min Ready Seconds

`.spec.minReadySeconds` 是一个可选配置项，用来指定没有任何容器 crash 的 Pod 并被认为是可用状态的最小秒数。默认是 0（Pod 在 ready 后就会被认为是可用状态）。
简单讲就是最小在多少秒以后会认为一个正常的 pod 是可用的。

### Rollback To

`.spec.rollbackTo` 是一个可以选配置项，用来配置 Deployment 回退的配置。设置该参数将触发回退操作，每次回退完成后，该值就会被清除。

#### Revision

`.spec.rollbackTo.revision` 是一个可选配置项，用来指定回退到的 revision。默认是 0，意味着回退到上一个 revision。

### Revision History Limit

Deployment revision history 存储在它控制的 ReplicaSets 中。

`.spec.revisionHistoryLimit` 是一个可选配置项，用来指定可以保留的旧的 ReplicaSet 数量。该理想值取决于新 Deployment 的频率和稳定性。如果该
值没有设置的话，默认所有旧的 Replicaset 或会被保留，将资源存储在 etcd 中，使用 `kubectl get rs` 查看输出。每个 Deployment 的该配置都保存
在 ReplicaSet 中，然而，**一旦你删除的旧的 RepelicaSet，你的 Deployment 就无法再回退到那个 revison 了**。

### Paused

`.spec.paused` 是可选配置项，boolean 值。用来指定暂停和恢复 Deployment。Paused 和非 paused 的 Deployment 之间的唯一区别就是，
**所有对 paused deployment 中的 PodTemplateSpec 的修改都不会触发新的 rollout**。Deployment 被创建之后默认是非 paused。
