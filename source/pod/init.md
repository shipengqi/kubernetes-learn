---
title: Init 容器
---

Init 容器是一种专用的容器，**在应用程序容器启动之前运行一些应用镜像中不存在的实用工具或安装脚本**。

Pod 能够具有一个或多个先于应用容器启动的 Init 容器。

Init 容器支持应用容器的全部字段和特性，包括资源限制、数据卷和安全设置。有以下区别：

- Init 容器**不支持 `Readiness Probe`，因为它们必须在 Pod 就绪之前运行完成**。
- 如果为 Pod 指定了**多个 Init 容器，那么 Init 容器会按顺序一次运行一个**。
- Init 容器总是运行到成功完成为止。
- 每个 Init 容器都必须在下一个 Init 容器启动之前成功完成。

当所有的 Init 容器运行完成后，Kubernetes 才初始化 Pod 和运行应用容器。

如果 **Pod 的 Init 容器失败，Kubernetes 会不断地重启该 Pod，直到 Init 容器成功为止，如果 Pod 重启，所有 Init 容器必须重新执行。**。如果 `restartPolicy` 为 `Never`，则不会重新启动。

在 Pod 上使用 `activeDeadlineSeconds`，在容器上使用 `livenessProbe`，这样能够避免 Init 容器一直失败。 这就**为 Init 容器活跃设置了一个期限**。

在 Pod 中的每个 app 和 Init 容器的名称必须唯一；与任何其它容器共享同一个名称，会在验证时抛出错误。

## 用途

- 它们可以包含并运行实用工具，出于安全考虑，不建议在应用程序容器镜像中包含这些实用工具的。
- 它们可以包含使用工具和定制化代码来安装，但是不能出现在应用程序镜像中。例如，创建镜像没必要 `FROM` 另一个镜像，只需要在安装过
程中使用类似 `sed`、 `awk`、 `python` 或 `dig` 这样的工具。
- 应用程序镜像可以分离出创建和部署的角色，而没有必要联合它们构建一个单独的镜像。
- Init 容器使用 Linux Namespace，所以相对应用程序容器来说具有不同的文件系统视图。因此，**它们能够具有访问 Secret 的权限，而应用程序容器则不能**。
- 它们必须在应用程序容器启动之前运行完成，而应用程序容器是并行运行的，所以 Init 容器能够提供了一种简单的阻塞或延迟应用容器的启动的方法，直到满足了一组先决条件。

## 使用

示例:

```yml
apiVersion: v1
kind: Pod
metadata:
  name: myapp-pod
  labels:
    app: myapp
spec:
  containers:
  - name: myapp-container
    image: busybox
    command: ['sh', '-c', 'echo The app is running! && sleep 3600']
  initContainers:
  - name: init-myservice
    image: busybox
    command: ['sh', '-c', 'until nslookup myservice; do echo waiting for myservice; sleep 2; done;']
  - name: init-mydb
    image: busybox
    command: ['sh', '-c', 'until nslookup mydb; do echo waiting for mydb; sleep 2; done;']
```
