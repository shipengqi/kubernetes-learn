# Kubernetes 基本概念

Kubernetes 是谷歌开源的容器集群管理系统，是Google多年大规模容器管理技术 Borg 的开源版本，主要功能包括：

- 基于容器的应用部署、维护和滚动升级
- 负载均衡和服务发现
- 跨机器和跨地区的集群调度
- 自动伸缩
- 无状态服务和有状态服务
- 广泛的`Volume`支持
- 插件机制保证扩展性

## 架构
![](../images/architecture.png)

## Kubernetes 核心组件

Kubernetes 主要由以下几个核心组件组成：

- etcd 保存了整个集群的状态；
- apiserver 提供了资源操作的唯一入口，并提供认证、授权、访问控制、API 注册和发现等机制；
- controller manager 负责维护集群的状态，比如故障检测、自动扩展、滚动更新等；
- scheduler 负责资源的调度，按照预定的调度策略将 Pod 调度到相应的机器上；
- kubelet 负责维护容器的生命周期，同时也负责 Volume（CVI）和网络（CNI）的管理；
- Container runtime 负责镜像管理以及 Pod 和容器的真正运行（CRI）；
- kube-proxy 负责为 Service 提供 cluster 内部的服务发现和负载均衡


除了核心组件，还有一些推荐的 Add-ons：

- CoreDNS 负责为整个集群提供DNS服务（也可以使用 kube-dns，更推荐使用 CoreDNS）
- Ingress Controller 为服务提供外网入口
- Prometheus 提供资源监控 （Heapster 不建议使用，将被弃用）
- Dashboard 提供 GUI
- Federation 提供跨可用区的集群
- Fluentd-elasticsearch 提供集群日志采集、存储与查询


## kubernetes 中的对象
kubernetes 中的 Object，这些对象都可以在`yaml`文件中作为一种 API 类型来配置。

| 类别 | 名称 |
| ------ | ------- |
| 资源对象 | Pod、ReplicaSet、ReplicationController、Deployment、StatefulSet、DaemonSet、Job、CronJob、HorizontalPodAutoscaling、Node、Namespace、Service、Ingress、Label、CustomResourceDefinition |
| 存储对象 | Volume、PersistentVolume、Secret、ConfigMap |
| 策略对象 | SecurityContext、ResourceQuota、LimitRange |
| 身份对象 | ServiceAccount、Role、ClusterRole |

Kubernetes 对象是 “目标性记录” —— 一旦创建对象，Kubernetes 系统将持续工作以确保对象存在。通过创建对象，可以有效地告知 Kubernetes 系统，所需要的集群工作负载看起来是什么样子的，
这就是 Kubernetes 集群的**期望状态**。

### Spec 与状态
每个 Kubernetes 对象包含两个嵌套的对象字段，它们负责管理对象的配置：对象`spec`和对象`status`。`spec`必须提供，它描述了对象的**期望状态** —— 希望对象所具有的特征。
`status`描述了对象的**实际状态**，它是由 Kubernetes 系统提供和更新。在任何时刻，Kubernetes 控制平面一直处于活跃状态，管理着对象的实际状态以与我们所期望的状态相匹配。

### 创建 Kubernetes 对象
可以用 Kubernetes API 创建对象，也可以使用`kubectl`。**必须提供对象的`spec`**，常用的方式是在`.yaml`文件中为`kubectl`提供这些信息。
`kubectl`其实还是在调用 Kubernetes API 。

例如，`nginx-deployment.yaml`：
```yml
apiVersion: apps/v1beta1
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

创建：`kubectl create -f docs/user-guide/nginx-deployment.yaml`

**注意，一下的字段是必须有的**
- `apiVersion` - 创建该对象所使用的 Kubernetes API 的版本
- `kind` - 想要创建的对象的类型
- `metadata` -  帮助识别对象唯一性的数据，每个对象都至少有3个元数据：`namespace`，`name`和`uid`，除此以外还有`labels`
- `spec`