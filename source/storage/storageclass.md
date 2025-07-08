---
title: StorageClass
---

Kubernetes 为我们提供了一套可以自动创建 PV 的机制，即：Dynamic Provisioning。

相比之下，前面人工管理 PV 的方式就叫作 Static Provisioning。

Dynamic Provisioning 机制工作的核心，在于一个名叫 StorageClass 的 API 对象。
StorageClass 对象会定义如下两个部分内容：

第一，PV 的属性。比如，存储类型、Volume 的大小等等。
第二，创建这种 PV 需要用到的存储插件。比如，Ceph 等等。

有了这样两个信息之后，Kubernetes 就能够根据用户提交的 PVC，找到一个对应的 StorageClass 了。然后，Kubernetes 就会调用该 StorageClass 声明的存储插件，创建出需要的 PV。

举个例子，假如我们的 Volume 的类型是 GCE 的 Persistent Disk 的话，运维人员就需要定义一个如下所示的 StorageClass：

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: block-service
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-ssd
```

定义了一个名叫 block-service 的 StorageClass。

这个 StorageClass 的 provisioner 字段的值是：kubernetes.io/gce-pd，这正是 Kubernetes 内置的 GCE PD 存储插件的名字。

而这个 StorageClass 的 parameters 字段，就是 PV 的参数。比如：上面例子里的 type=pd-ssd，指的是这个 PV 的类型是“SSD 格式的 GCE 远程磁盘”。

```bash
$ kubectl create -f sc.yaml
```

只需要在 PVC 里指定要使用的 StorageClass 名字即可，如下所示：

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: claim1
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: block-service
  resources:
    requests:
      storage: 30Gi
```

这个 PVC 里添加了一个叫作 storageClassName 的字段，用于指定该 PVC 所要使用的 StorageClass 的名字是：block-service。

当我们通过 kubectl create 创建上述 PVC 对象之后，Kubernetes 就会调用 Google Cloud 的 API，创建出一块 SSD 格式的 Persistent Disk。然后，再使用这个 Persistent Disk 的信息，自动创建出一个对应的 PV 对象。

**Kubernetes 只会将 StorageClass 相同的 PVC 和 PV 绑定起来**。

StorageClass 对象的作用，其实就是创建 PV 的模板。

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
