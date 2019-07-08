---
title: StorageClass
---

# StorageClass

StorageClass 来动态创建 PV，不仅节省了管理员的时间，还可以封装不同类型的存储供 PVC 选用。

StorageClass 中包含以下四个字段，当 class 需要动态分配 PersistentVolume 时会使用到。
- `provisioner`：存储分配器，用来决定使用哪个卷插件分配 PV。该字段必须指定。
- `parameters`：描述属于 storage class 卷的参数。取决于分配器，可以接受不同的参数。
- `mountOptions`：挂载选项，如果卷插件不支持挂载选项，却指定了该选项，则分配操作失败。
- `reclaimPolicy`：回收策略，默认为 `Delete`。可以是 `Delete` 或者 `Retain`。

StorageClass 对象的名称很重要，用户使用该类来请求一个特定的方法。 当创建 StorageClass 对象时，管理员设置名称和其他参数，一旦创建了对象就不能再对其更新。

```yml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: standard
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp2
reclaimPolicy: Retain
mountOptions:
  - debug
```

关于内置的 StorageClass 的配置参考 [Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)。