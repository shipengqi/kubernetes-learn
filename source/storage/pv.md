---
title: Persistent Volume
---

# Persistent Volume

PersistentVolume（PV）是由管理员设置的存储，它是群集的一部分。就像节点是集群中的资源一样，PV 也是集群中的资源。PV 是 Volume 之类的卷插件，但具有独立的生命周期。
也就是说及时使用该 pv 的 pod 被删除，pv 也仍然存在。

PersistentVolumeClaim（PVC）是用户存储的请求。它与 Pod 相似。Pod 消耗节点资源，PVC 消耗 PV 资源。Pod 可以请求特定级别的资源（CPU 和内存）
。声明可以请求特定的大小和访问模式（例如，可以以读/写一次或 只读多次模式挂载）。

## PersistentVolume 生命周期

6 个阶段：
1. Provisioning，即 PV 的创建，可以直接创建 PV（静态方式），也可以使用 StorageClass 动态创建
2. Binding，将 PV 分配给 PVC
3. Using，Pod 通过 PVC 使用该 PV，并可以**通过准入控制 `--admission-control=StorageObjectInUseProtection`（1.9 及以前版本为 PVCProtection）阻止删除正在使用的 PVC**。
开启准入控制时，删除使用中的 PV 和 PVC 后，它们会等待使用者删除后才删除（而不是之前的立即删除）。而在使用者删除之前，它们会一直处于 Terminating 状态。
4. Releasing，Pod 释放 PV 并删除 PVC
5. Reclaiming，回收 PV，可以保留 PV 以便下次使用，也可以直接从云存储中删除
6. Deleting，删除 PV 并从云存储中删除后段存储

PV 的状态有以下 4 种：
- Available：可用
- Bound：已经分配给 PVC
- Released：PVC 解绑但还未执行回收策略
- Failed：发生错误


## 配置
有两种方式来配置 PV：静态或动态。
### 静态
集群管理员创建一些 PV。它们带有可供群集用户使用的实际存储的细节。

### 动态
当管理员创建的静态 PV 都不匹配用户的 PVC 时，集群可能会尝试动态地为 PVC 创建卷。此配置基于 `StorageClasses`：PVC 必须
请求[存储类](./storageclass.html)，并且管理员必须创建并配置该类才能进行动态创建。不仅节省了管理员的时间，还可以封装不同类型的存储供 PVC 选用。

## 绑定
在动态配置的情况下，用户创建或已经创建了具有特定存储量的 PVC 以及某些访问模式。master 中的控制环路监视新的 PVC，寻找匹配的 PV（如果可能），并将它们绑定在一起。
如果为新的 PVC 动态调配 PV，则该环路将始终将该 PV 绑定到 PVC。否则，用户总会得到他们所请求的存储，但是容量可能超出要求的数量。一旦 PV 和 PVC 绑定后，
PVC 绑定是排他性的，不管它们是如何绑定的。 PVC 跟 PV 绑定是一对一的映射。

如果没有匹配的卷，声明将无限期地保持未绑定状态。随着匹配卷的可用，声明将被绑定。例如，配置了许多 50Gi PV 的集群将不会匹配请求 100Gi 的 PVC。将 100Gi PV 添加到群集时，
可以绑定 PVC。

## 使用
每个 PV 配置中都包含一个 sepc 规格字段和一个 status 卷状态字段。

定义一个 NFS 的 PV ：
```yml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv0003
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Recycle
  nfs:
    path: /tmp
    server: 172.17.0.2
```

访问模式（accessModes）有三种：
- ReadWriteOnce（RWO）：是最基本的方式，可读可写，但只支持被单个节点挂载。
- ReadOnlyMany（ROX）：可以以只读的方式被多个节点挂载。
- ReadWriteMany（RWX）：这种存储可以以读写的方式被多个节点共享。不是每一种存储都支持这三种方式，像共享方式，目前支持的还比较少，比较常用的是 NFS。
在 PVC 绑定 PV 时通常根据两个条件来绑定，一个是存储的大小，另一个就是访问模式。

一个卷一次只能使用一种访问模式挂载，即使它支持很多访问模式。

PV 的回收策略（persistentVolumeReclaimPolicy，即 PVC 释放卷的时候 PV 该如何操作）也有三种：
- Retain，不清理, 保留 Volume（需要手动清理）
- Recycle，删除数据，即 `rm -rf /thevolume/*`（**只有 `NFS` 和 `HostPath` 支持**）
- Delete，删除存储资源，比如删除 AWS EBS 卷（只有 AWS EBS, GCE PD, Azure Disk 和 Cinder 支持）

### PersistentVolumeClaim
每个 PVC 中都包含一个 spec 规格字段和一个 status 声明状态字段。
```yml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: myclaim
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 8Gi
  storageClassName: slow
  selector:
    matchLabels:
      release: "stable"
    matchExpressions:
      - {key: environment, operator: In, values: [dev]}
```

PVC 可以直接挂载到 Pod 中：
```yml
kind: Pod
apiVersion: v1
metadata:
  name: mypod
spec:
  containers:
    - name: myfrontend
      image: dockerfile/nginx
      volumeMounts:
      - mountPath: "/var/www/html"
        name: mypd
  volumes:
    - name: mypd
      persistentVolumeClaim:
        claimName: myclaim
```

### 类
PV 可以具有一个类，通过将 `storageClassName` 属性设置为 [StorageClass](./storageclass.html) 的名称来指定该类。
一个指定了 类 的 PV 只能绑定到请求对应 类 的 PVC。没有 storageClassName 的 PV 就没有 类，它只能绑定到不需要特定 类 的 PVC。

没有 `storageClassName` 的 PVC 根据是否打开
[ `DefaultStorageClass` 准入控制](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#defaultstorageclass)插件，集群对其进行不同处理。

- 如果打开了准入控制插件，管理员可以指定一个默认的 StorageClass。所有没有 `StorageClassName` 的 PVC 将被绑定到该默认的 PV。通过在 StorageClass 对象中
将注解 `storageclass.kubernetes.io/is-default-class` 设置为 `true` 来指定使用默认的 StorageClass。如果管理员没有指定缺省值，那么集群会响应 PVC 创建，
就好像关闭了准入控制插件一样。如果指定了多个默认值，则准入控制插件将禁止所有 PVC 创建。
- 如果准入控制插件被关闭，则没有默认 StorageClass 的概念。所有没有 `storageClassName` 的 PVC 只能绑定到没有类的 PV。在这种情况下，没
有 `storageClassName` 的 PVC 的处理方式与 `storageClassName` 设置为 `""` 的 PVC 的处理方式相同。

当 PVC 指定了 `selector`，除了请求一个 StorageClass 之外，这些需求被“与”在一起：只有被请求的 类 的 PV 具有和被请求的标签才可以被绑定到 PVC。

> 目前，具有非空 `selector` 的 PVC 不能为其动态配置 PV。

过去，使用的是 `volume.beta.kubernetes.io/storage-class` 注解而不是 `storageClassName` 属性。

### 挂载选项
挂载选项没有校验，如果挂载选项无效则挂载失败。

过去，使用 `volume.beta.kubernetes.io/mount-options` 注解而不是 `mountOptions` 属性。

### 选择器
可以声明一个[标签选择器](../cluster/label.html)来进一步过滤该组卷。只有标签与选择器匹配的卷可以绑定到声明。选择器由两个字段组成：
- `matchLabels：volume` 必须有具有该值的标签
- `matchExpressions`：这是一个要求列表，通过指定关键字，值列表以及与关键字和值相关的运算符组成。有效的运算符包括 `In`、`NotIn`、`Exists` 和 `DoesNotExist`。

所有来自 `matchLabels` 和 `matchExpressions` 的要求必须全部满足才能匹配。

## Local Volume
Local Volume 允许将 Node 本地的磁盘、分区或者目录作为持久化存储使用。**Local Volume 不支持动态创建，使用前需要预先创建好 PV**。
```yml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: example-pv
spec:
  capacity:
    storage: 100Gi
  # volumeMode field requires BlockVolume Alpha feature gate to be enabled.
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage
  local:
    path: /mnt/disks/ssd1
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - example-node
---
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
```
