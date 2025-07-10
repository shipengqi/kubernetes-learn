## NodeAffinity

NodeAffinity 允许你根据节点标签来调度 Pod，类似于 nodeSelector，但提供了更丰富的表达语法。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: node-affinity-pod
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:  # 硬性要求
        nodeSelectorTerms:
        - matchExpressions:
          - key: disktype
            operator: In
            values:
            - ssd
      preferredDuringSchedulingIgnoredDuringExecution:  # 软性偏好
      - weight: 1
        preference:
          matchExpressions:
          - key: zone
            operator: In
            values:
            - east
  containers:
  - name: nginx
    image: nginx
```

关键参数说明
operator 支持的值:

In: 标签值在列表中

NotIn: 标签值不在列表中

Exists: 标签存在

DoesNotExist: 标签不存在

Gt: 大于 (用于数值)

Lt: 小于 (用于数值)

调度类型:

requiredDuringSchedulingIgnoredDuringExecution: 必须满足 (硬性要求)

preferredDuringSchedulingIgnoredDuringExecution: 优先满足 (软性偏好)

### 应用场景

指定节点类型:

```yaml
nodeAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    nodeSelectorTerms:
    - matchExpressions:
      - key: node-role.kubernetes.io/gpu
        operator: Exists
```


避免特定节点:

```yaml
nodeAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    nodeSelectorTerms:
    - matchExpressions:
      - key: kubernetes.io/arch
        operator: NotIn
        values:
        - arm64
```

## PodAffinity 


PodAffinity 允许你根据其他 Pod 的分布来调度当前 Pod，可以是亲和性 (一起调度) 或反亲和性 (分开调度)。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-affinity-example
spec:
  affinity:
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:  # 必须与这些 Pod 在同一节点
      - labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - cache
        topologyKey: kubernetes.io/hostname
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:  # 尽量避免与这些 Pod 在同一节点
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app
              operator: In
              values:
              - database
          topologyKey: kubernetes.io/hostname
  containers:
  - name: nginx
    image: nginx
```

关键参数说明
topologyKey: 定义拓扑域 (如 hostname, zone, region)

labelSelector: 选择目标 Pod 的标签

weight: 对于 preferred 规则，权重 1-100

### 应用场景

将服务与缓存共置:

```yaml
podAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
  - labelSelector:
      matchExpressions:
      - key: app
        operator: In
        values:
        - redis-cache
    topologyKey: kubernetes.io/hostname
```

实现高可用 (分散部署):

```yaml
podAntiAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
  - labelSelector:
      matchExpressions:
      - key: app
        operator: In
        values:
        - my-web-app
    topologyKey: kubernetes.io/hostname
```

多层级反亲和性:

```yaml
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
  - weight: 100
    podAffinityTerm:
      labelSelector:
        matchExpressions:
        - key: app
          operator: In
          values:
          - my-app
      topologyKey: kubernetes.io/hostname
  - weight: 80
    podAffinityTerm:
      labelSelector:
        matchExpressions:
        - key: app
          operator: In
          values:
          - my-app
      topologyKey: topology.kubernetes.io/zone
```

综合使用示例:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-server
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 1
            preference:
              matchExpressions:
              - key: node-type
                operator: In
                values:
                - web-optimized
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - web
            topologyKey: kubernetes.io/hostname
        podAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 80
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - cache
              topologyKey: kubernetes.io/hostname
      containers:
      - name: nginx
        image: nginx:latest
```