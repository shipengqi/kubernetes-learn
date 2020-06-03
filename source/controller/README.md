# 控制器

Kubernetes 中内建了很多 controller（控制器），这些相当于一个状态机，用来控制 Pod 的具体状态和行为。

controller 的集合对应的代码在 Kubernetes 项目的 `pkg/controller` 目录下。

这些控制器都遵 循Kubernetes 项目中的一个通用编排模式，即：**控制循环**（control loop）。用伪代码来表示：

```go
for {
  // 实际状态:= 获取集群中对象 X 的实际状态（Actual State）
  // 期望状态:= 获取集群中对象 X 的期望状态（Desired State）
  if 实际状态 == 期望状态{
    // 什么都不做
  } else {
    // 执行编排动作，将实际状态调整为期望状态
  }
}
```

实际状态一般来自于 Kubernetes 集群本身。比如，kubelet 通过心跳汇报的容器状态和节点状态，或者监控系统中保存的应用监控数据，或
者控制器主动收集的它自己感兴趣的信息，这些都是常见的实际状态的来源。而期望状态，一般来自于用户提交的 YAML 文件。

```yml
# 控制器定义
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3
  # template 定义的是 被控制的对象
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
