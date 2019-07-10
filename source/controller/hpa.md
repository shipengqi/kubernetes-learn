---
title: Horizontal Pod Autoscaling
---

# Horizontal Pod Autoscaling
应用的资源使用率通常都有高峰和低谷的时候，如何削峰填谷，提高集群的整体资源利用率，让 service 中的 Pod 个数自动调整？这就有赖于 Horizontal Pod Autoscaling（HPA） 了，顾名思义，
Pod 水平自动缩放。

利用 Horizontal Pod Autoscaling，kubernetes 能够根据监测到的 CPU 利用率周期性地自动扩缩容 replication controller，deployment 和 replica set
中 pod 的数量。

## HPA 如何工作
Horizontal Pod Autoscaler 由一个控制循环实现，循环周期由 controller manager 中的 `--horizontal-pod-autoscaler-sync-period` 标志指定（默认是 30 秒）。
在每个周期内，controller manager 会查询 HorizontalPodAutoscaler 中定义的 metric 的资源利用率。
Controller manager 从 resource metric API（每个 pod 的 resource metric）或者自定义 metric API（所有的metric）中获取 metric。

- 每个 Pod 的 resource metric（例如 CPU），controller 通过 resource metric API 获取 HorizontalPodAutoscaler 中定义的每个 Pod 中的 metric。然后，
如果设置了目标利用率，controller 计算利用的值与每个 Pod 的容器里的 resource request 值的百分比。如果设置了目标原始值，将直接使用该原始 metric 值。然后 controller 计
算所有目标 Pod 的利用率或原始值（取决于所指定的目标类型）的平均值，产生一个用于缩放所需 replica 数量的比率。 请注意，如果某些 Pod 的容器没有设置相关的 resource request ，
则不会定义 Pod 的 CPU 利用率，并且 Autoscaler 也不会对该 metric 采取任何操作。
- 对于每个 Pod 自定义的 metric，controller 功能类似于每个 Pod 的 resource metric，只是它使用原始值而不是利用率值。
- 对于 object metric，获取单个度量（该问题描述中 object的 metric），并与目标值进行比较，以产生如上所述的比率。

HorizontalPodAutoscaler 控制器可以以两种不同的方式获取 metric ：**直接的 Heapster 访问**和 **REST 客户端访问**。

当使用直接的 Heapster 访问时，HorizontalPodAutoscaler 直接通过 API 服务器的服务代理子资源查询 Heapster。需要在集群上部署 Heapster 并在 `kube-system` namespace 中运行。

Autoscaler 访问相应的 replication controller，deployment 或 replica set 来缩放子资源。

Scale 是一个允许动态设置副本数并检查其当前状态的接口。

注意：
- HPA 是关于 Pod 的自动扩展，而 Node 的自动扩展参考 [Cluster AutoScaler](../addons/cluster-autoscaler.html)。
- 在使用 HPA 之前需要 确保已部署好 [metrics-server](../addons/metrics.html)。

## 支持多个 metric
Kubernetes 1.6 中增加了支持基于多个 metric 的扩缩容。可以使用 `autoscaling/v2alpha1` API 版本来为 Horizontal Pod Autoscaler 指定多个 metric。
然后 Horizontal Pod Autoscaler controller 将权衡每一个 metric，并根据该 metric 提议一个新的 scale。在所有提议里最大的那个 scale 将作为最终的 scale。

## 示例
```sh
# 创建 pod 和 service
$ kubectl run php-apache --image=k8s.gcr.io/hpa-example --requests=cpu=200m --expose --port=80
service "php-apache" created
deployment "php-apache" created

# 创建 autoscaler
$ kubectl autoscale deployment php-apache --cpu-percent=50 --min=1 --max=10
deployment "php-apache" autoscaled

$ kubectl get hpa
NAME         REFERENCE                     TARGET    MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache/scale   0% / 50%  1         10        1          18s

# 增加负载
$ kubectl run -i --tty load-generator --image=busybox /bin/sh
Hit enter for command prompt
$ while true; do wget -q -O- http://php-apache.default.svc.cluster.local; done

# 过一会就可以看到负载升高了
$ kubectl get hpa
NAME         REFERENCE                     TARGET      CURRENT   MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache/scale   305% / 50%  305%      1         10        1          3m

# autoscaler 将这个 deployment 扩展为 7 个 pod
$ kubectl get deployment php-apache
NAME         DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
php-apache   7         7         7            7           19m

# 删除刚才创建的负载增加 pod 后会发现负载降低，并且 pod 数量也自动降回 1 个
$ kubectl get hpa
NAME         REFERENCE                     TARGET       MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache/scale   0% / 50%     1         10        1          11m

$ kubectl get deployment php-apache
NAME         DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
php-apache   1         1         1            1           27m
```

## 自定义 metrics
```yml
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: php-apache
  namespace: default
spec:
  scaleTargetRef:
    apiVersion: apps/v1beta1
    kind: Deployment
    name: php-apache
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      targetAverageUtilization: 50
  - type: Pods
    pods:
      metricName: packets-per-second
      targetAverageValue: 1k
  - type: Object
    object:
      metricName: requests-per-second
      target:
        apiVersion: extensions/v1beta1
        kind: Ingress
        name: main-route
      targetValue: 10k
status:
  observedGeneration: 1
  lastScaleTime: <some-time>
  currentReplicas: 1
  desiredReplicas: 1
  currentMetrics:
  - type: Resource
    resource:
      name: cpu
      currentAverageUtilization: 0
      currentAverageValue: 0
```

上面的例子，HPA 保证每个 Pod 占用 50% CPU、1000pps 以及 10000 请求 `/s`：
## 状态条件
v1.7+ 可以在客户端中看到 Kubernetes 为 HorizontalPodAutoscaler 设置的状态条件 `status.conditions`，用
来判断 HorizontalPodAutoscaler 是否可以扩展（AbleToScale）、是否开启扩展（ScalingActive）以及是否受到限制（ScalingLimitted）。

```sh
$ kubectl describe hpa cm-test
Name:                           cm-test
Namespace:                      prom
Labels:                         <none>
Annotations:                    <none>
CreationTimestamp:              Fri, 16 Jun 2017 18:09:22 +0000
Reference:                      ReplicationController/cm-test
Metrics:                        (current / target)
  "http_requests" on pods:      66m / 500m
Min replicas:                   1
Max replicas:                   4
ReplicationController pods:     1 current / 1 desired
Conditions:
  Type                  Status  Reason                  Message
  ----                  ------  ------                  -------
  AbleToScale           True    ReadyForNewScale        the last scale time was sufficiently old as to warrant a new scale
  ScalingActive         True    ValidMetricFound        the HPA was able to successfully calculate a replica count from pods metric http_requests
  ScalingLimited        False   DesiredWithinRange      the desired replica count is within the acceptable range
Events:
```

## HPA 最佳实践
- 为容器配置 CPU Requests
- HPA 目标设置恰当，如设置 70% 给容器和应用预留 30% 的余量
- 保持 Pods 和 Nodes 健康（避免 Pod 频繁重建）
- 保证用户请求的负载均衡
- 使用 `kubectl top node` 和 `kubectl top pod` 查看资源使用情况