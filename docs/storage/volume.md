# Volume
如果了解 Docker volume，那么 kubernetes 的 volume 会很容易理解。Volume 解决了什么问题？

1. 容器是无状态的，容器磁盘上的文件的生命周期是短暂的。当容器挂掉或退出时，容器中的一切文件，状态都会丢失。容器重启之后，
回到初始的状态。
2. Pod 是 kubernetes 的最小单位，一个 Pod 可以包含多个容器，当 pod 中的容器需要共享某个文件时（比如 token），就需要 volume。

Kubernetes 中的 volume 有明确的生命周期 —— 与封装它的 Pod 相同。支持多种类型的卷，Pod 可以同时使用任意数量的卷。

要使用卷，需要为 pod 指定为卷（`spec.volumes` 字段）以及将它挂载到容器的位置（`spec.containers.volumeMounts` 字段）。
**Pod 中的每个容器都必须独立指定每个卷的挂载位置**。


Kubernetes 支持多种类型的卷，常用的有：
- `emptyDir`
- `hostPath`
- `nfs`
- `persistentVolumeClaim`

## emptyDir
当 Pod 被分配给节点时，首先创建 `emptyDir` volume，生命周期与 pod 相同。正如卷的名字所述，它最初是空的。Pod 中的容器可以读取和写入 emptyDir 卷中的相同文件。
注意，容器崩溃不会从节点中移除 pod，因此 `emptyDir` volume 中的数据在容器崩溃时是安全的。

`emptyDir` 的用法有：

- 暂存空间，例如用于基于磁盘的合并排序
- 用作长时间计算崩溃恢复时的检查点
- Web 服务器容器提供数据时，保存内容管理器容器提取的文件

```yml
spec:
  initContainers:
  - name: install
    image: localhost:5000/kubernetes-vault-init:0.5.0
    securityContext:
      runAsUser: 1999
    env:
    - name: VAULT_ROLE_ID
      value: {VAULT_ROLE_ID}
    - name: CERT_COMMON_NAME
      value: {EXTERNAL_ACCESS_HOST}
    volumeMounts:
    - name: vault-token
      mountPath: /var/run/secrets/boostport.com
  containers:
  - name: chatbot
    image: {IMAGE_REPOSITORY}
    args:
    - "chatbot"
    imagePullPolicy: IfNotPresent
    volumeMounts:
    - name: vault-token
      mountPath: /var/run/secrets/boostport.com
  - name: kubernetes-vault-renew
    image: localhost:5000/kubernetes-vault-renew:0.5.0
    imagePullPolicy: IfNotPresent
    volumeMounts:
    - name: vault-token
      mountPath: /var/run/secrets/boostport.com
  volumes:
  - name: vault-token
    emptyDir: {}
```

上面的例子中：init 容器 `install`，容器 `chatbot` 和 `kubernetes-vault-renew` 都将 volume `vault-token` 挂载到了路径 `/var/run/secrets/boostport.com` 上，
`install` 容器在初始化 pod 时，调用 vault API 生成 vault token，并保存到 `/var/run/secrets/boostport.com`。`chatbot` 容器运行时，会使用 `install` 容器生成的
vault token 访问 vault。而 `kubernetes-vault-renew` 容器的作用就是定时检查 vault token 是否过期，并及时刷新 vault token。这就实现了 token 容器间的共享。

## hostPath
`hostPath` 卷将主机节点的文件系统中的文件或目录挂载到集群中。前面已经知道 `emptyDir` 在 pod 被删除时，保存的数据也会被永久删除。如果想要保留 `emptyDir` 中的数据，
就可以使用 `hostPath` volume。

`hostPath` 的用途如下：

- 运行需要访问 Docker 内部的容器；使用 `/var/lib/docker` 的 `hostPath`
- 在容器中运行 `cAdvisor`；使用 `/dev/cgroups` 的 `hostPath`
- 允许 pod 指定给定的 `hostPath` 是否应该在 pod 运行之前存在，是否应该创建，以及它应该以什么形式存在

除了所需的 `path` 属性之外，用户还可以为 `hostPath` 卷指定 `type`。

`type` 字段的值：
- 空：空字符串（默认）用于向后兼容，这意味着在挂载 hostPath 卷之前不会执行任何检查。
- `DirectoryOrCreate`：如果在给定的路径上没有任何东西存在，那么将根据需要在那里创建一个空目录，权限设置为 0755，与 Kubelet 具有相同的组和所有权。
- `Directory`：给定的路径下必须存在目录
- `FileOrCreate`：如果在给定的路径上没有任何东西存在，那么会根据需要创建一个空文件，权限设置为 0644，与 Kubelet 具有相同的组和所有权。
- `File`：给定的路径下必须存在文件
- `Socket`：给定的路径下必须存在 UNIX 套接字
- `CharDevice`：给定的路径下必须存在字符设备
- `BlockDevice`：给定的路径下必须存在块设备

注意在集群中，不建议使用 `hostPath` volume，因为集群中的每台节点的文件目录可能都不相同，而 Kubernetes 在调度资源时，pod 会随机分配到某个节点。这时
`hostPath` volume 使用的资源是无法考虑到的。

```yml
spec:
  containers:
  - image: k8s.gcr.io/test-webserver
    name: test-container
    volumeMounts:
    - mountPath: /test-pd
      name: test-volume
  volumes:
  - name: test-volume
    hostPath:
      # directory location on host
      path: /data
      # this field is optional
      type: Directory
```

## nfs
nfs 卷允许将现有的 NFS（网络文件系统）共享挂载到您的容器中。当删除 Pod 时，nfs 卷的内容被保留，卷仅仅是被卸载。这意味着 NFS 卷可以预填充数据，
并且可以在 pod 之间“切换”数据。 NFS 可以被多个写入者同时挂载。

```yml
volumes:
- name: nfs
  nfs:
    # FIXME: use the right hostname
    server: 10.254.234.223
    path: "/"
```


## persistentVolumeClaim

`persistentVolumeClaim` 卷用于将 [PersistentVolume](./pv.md) 挂载到容器中。PersistentVolumes 是在用户不知道特定云环境的细节的情况下“声明”持久
化存储（例如 GCE PersistentDisk 或 iSCSI 卷）的一种方式。

## gitRepo
gitRepo volume 将 git 代码下拉到指定的容器路径中

```yml
  volumes:
  - name: git-volume
    gitRepo:
      repository: "git@somewhere:me/my-git-repository.git"
      revision: "22f1d8406d464b0c0874075539c1f2e96c253775"
```

## 使用 subPath
Pod 的多个容器使用同一个 Volume 时，`subPath` 非常有用，`volumeMounts.subPath` 属性可指定挂载的 volume 的根目录中的某个子路径。

```yml
spec:
  containers:
  - name: chatbot
    image: {IMAGE_REPOSITORY}
    args:
    - "chatbot"
    imagePullPolicy: IfNotPresent
    volumeMounts:
    - name: scripts
      mountPath: /opt/chatbot/scripts
      subPath: scripts
    - name: log
      mountPath: /var/opt/chatbot/log
      subPath: log
  volumes:
  - name: log
    persistentVolumeClaim:
      claimName: chatbot-pv-claim
  - name: scripts
    persistentVolumeClaim:
      claimName: chatbot-pv-claim
```

上面的例子，容器中的 `/opt/chatbot/scripts` 和 `/var/opt/chatbot/log` 两个路径分别映射到了 `chatbot-pv-claim` volume 中的 `scripts` 和 `log` 目录。

## 资源
v1.7 + 支持对基于本地存储（如 hostPath, emptyDir, gitRepo 等）的容量进行调度限额，可以通过 `--feature-gates=LocalStorageCapacityIsolation=true` 来开启这个特性。

Kubernetes 将本地存储分为两类：
- `storage.kubernetes.io/overlay`，即 `/var/lib/docker` 的大小
- `storage.kubernetes.io/scratch`，即 `/var/lib/kubelet` 的大小

Kubernetes 根据 `storage.kubernetes.io/scratch` 的大小来调度本地存储空间，而根据 `storage.kubernetes.io/overlay` 来调度容器的存储。比如
```yml
spec:
  restartPolicy: Never
  containers:
  - name: hello
    image: busybox
    command: ["df"]
    resources:
      requests:
        storage.kubernetes.io/overlay: 64Mi
```
为 `emptyDir` 请求 64MB 的存储空间
```yml
spec:
  restartPolicy: Never
  containers:
  - name: hello
    image: busybox
    command: ["df"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    emptyDir:
      sizeLimit: 64Mi
```

## 挂载传播
挂载传播（MountPropagation）是 v1.9 引入的新功能。挂载传播用来解决同一个 Volume 在不同的容器甚至是 Pod 之间挂载的问题。
通过设置 `Container.volumeMounts.mountPropagation`），可以为该存储卷设置不同的传播类型。

三种类型：
- `None`：即私有挂载（private）
- `HostToContainer`：即 Host 内在该目录中的新挂载都可以在容器中看到，等价于 Linux 内核的 `rslave`。
- `Bidirectional`：即 Host 内在该目录中的新挂载都可以在容器中看到，同样容器内在该目录中的任何新挂载也都可以在 Host 中看到，
等价于 Linux 内核的 `rshared`。仅特权容器（`privileged`）可以使用 `Bidirectional` 类型。

可以通过 `--feature-gates=MountPropagation=true` 来开启这个特性。

如未开启 MountPropagation 特性，则 v1.9 和 v1.10 中默认为私有挂载（None），而 v1.11 中默认为 `HostToContainer`
Docker 服务的 systemd 配置文件中需要设置 `MountFlags=shared`。


