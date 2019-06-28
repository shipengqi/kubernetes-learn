# Init 容器

Init 容器是一种专用的容器，**在应用程序容器启动之前运行一些应用镜像中不存在的实用工具或安装脚本**。

Pod 能够具有一个或多个先于应用容器启动的 Init 容器。

Init 容器支持应用容器的全部字段和特性，包括资源限制、数据卷和安全设置。有以下区别：
- Init 容器不支持 `Readiness Probe`，因为它们必须在 Pod 就绪之前运行完成。
- 如果为 Pod 指定了多个 Init 容器，那些容器会按顺序一次运行一个。
- Init 容器总是运行到成功完成为止。
- 每个 Init 容器都必须在下一个 Init 容器启动之前成功完成。

当所有的 Init 容器运行完成后，Kubernetes 才初始化 Pod 和运行应用容器。

如果 **Pod 的 Init 容器失败，Kubernetes 会不断地重启该 Pod，直到 Init 容器成功为止**。如果 `restartPolicy` 为 `Never`，则不会重新启动。

示例:
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
```

## 用途