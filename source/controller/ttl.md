---
title: TTL Controller for Finished Resources
---

# TTL Controller for Finished Resources
TTL 控制器提供了一种 TTL 机制来限制已经执行完成的资源对象的生存期。TTL 控制器目前只可以处理 [Job](./job.html)。
可以通过扩展它来处理其他将完成执行的资源，比如 Pod 或其他自定义的资源。

此功能目前是 Alpha 版本，可以通过 `kube-apiserver` 和 `kube-controller-manager` 的 
[Feature Gates](https://kubernetes.io/docs/reference/command-line-tools-reference/feature-gates/) `TTLAfterFinished` 启用。
要求 Kubernetes v1.12 以上。

## TTL Controller
TTL 控制器目前只可以处理 Job。可以通过指定 `.spec.ttlSecondsAfterFinished` 字段来使用该特性，自动清理已完成的 Job(`Completed` 
或 `Failed`)。

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pi-with-ttl
spec:
  ttlSecondsAfterFinished: 100
  template:
    spec:
      containers:
      - name: pi
        image: perl
        command: ["perl",  "-Mbignum=bpi", "-wle", "print bpi(2000)"]
      restartPolicy: Never
```

TTL 控制器假定在资源完成后的几秒内(换句话说，当 TTL 过期时)，资源可以被清除。TTL 控制器清理一个资源会级联地删除它，也就是说，删除它
的依赖对象。

TTL 可以在任何时间设置。下面是一些 Job 设置 `.spec.ttlSecondsAfterFinished` 的示例:
- 在资源的 manifest 中指定此字段，以便 Job 完成后可以自动清理。
- 也可以为已经存在或完成的资源设置此字段，使该资源采用新特性。
- 使用 [mutating admission webhook](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#admission-webhooks) 
在资源创建时动态的设置此字段，集群管理员可以使用它对完成的资源执行 TTL 策略。
- 使用 [mutating admission webhook](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#admission-webhooks) 
在资源完成后动态的设置此字段，并根据资源状态、label 等选择不同的 TTL 值。

## Updating TTL Seconds
注意 TTL 周期，例如 Job 的 `.spec.ttlSecondsAfterFinished` 字段，可以在资源创建或完成后进行修改。但是，一旦 Job 符合删除条件
(当 TTL 过期时)，系统将不能保证保留 Job，即使扩展 TTL 的返回一个成功的 API 响应。

## Time Skew
由于 TTL 控制器使用存储在 Kubernetes 资源中的时间戳来确定 TTL 是否已经过期，所以这个特性对集群中的时间倾斜很敏感，这可能会
导致 TTL 控制器在错误的时间清理资源对象。

在 Kubernetes 中，需要在所有节点上运行 NTP
(参见 [#6159](https://github.com/kubernetes/kubernetes/issues/6159#issuecomment-93844058))，以避免时间倾斜。时钟并不总
是正确的，但两者之间的差别应该很小。在设置非零 TTL 时，请注意这种风险。