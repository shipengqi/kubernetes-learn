# Pod 生命周期

Pod 的 `status` 字段是一个 `PodStatus` 对象，`PodStatus` 中有一个 `phase` 字段。`phase` 可能的状态：

- Pending: Pod 已经在 apiserver 中创建，但有一个或者多个容器镜像尚未创建。等待时间包括调度 Pod 的时间和通过网络下载镜像的时间，这可能需要花点时间。
- Running: Pod 已经调度到 Node 上面，所有容器都已经创建，并且至少有一个容器还在运行或者正在启动。
- Succeeded: Pod 中的所有容器都被成功终止，并且不会再重启。
- Failed: Pod 中的所有容器都已终止了，并且至少有一个容器运行失败（即退出码不为 0 或者被系统终止）。
- Unknonwn: 状态未知，通常是由于 apiserver 无法与 kubelet 通信导致。

## 探针

探针是由 [kubelet](../components/kubelet.md) 对容器执行的定期诊断。要执行诊断，kubelet 调用由容器实现的 [Handler](https://godoc.org/k8s.io/kubernetes/pkg/api/v1#Handler)。
三种执行探针的方式：

- exec：在容器内执行指定命令。如果命令退出时返回码为 0 则认为诊断成功。
- tcpSocket：对指定端口上的容器的 IP 地址进行 TCP 检查。如果端口打开，则诊断被认为是成功的。
- httpGet：对指定的端口和路径上的容器的 IP 地址执行 HTTP Get 请求。如果响应的状态码大于等于 200 且小于 400，则诊断被认为是成功的。

每次探测都将获得以下三种结果之一：

- 成功：容器通过了诊断。
- 失败：容器未通过诊断。
- 未知：诊断失败，因此不会采取任何行动。

Kubernetes 提供了两种探针（Probe）来探测容器的状态：
- `livenessProbe`：探测应用是否处于健康状态，如果不健康则删除并重新创建容器。如果容器不提供存活探针，则默认状态为 `Success`。
- `readinessProbe`：探测应用是否启动完成并且处于正常服务状态，如果不正常则不会接收来自 Kubernetes Service 的流量。如果容器不提供就绪探针，则默认状态为 `Success`。

### 示例
```yml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: chatbot-deployment
  namespace: {NAMESPACE}
  labels:
    app: chatbot
spec:
  replicas: 1
  selector:
    matchLabels:
      app: chatbot
  template:
    metadata:
      labels:
        app: chatbot
    spec:
      containers:
      - name: itom-chatops-chatbot
        image: {IMAGE_REPOSITORY}
        args:
        - "chatbot"
        imagePullPolicy: IfNotPresent
        livenessProbe:
          httpGet:
            path: /healthz
            port: 3000
            scheme: HTTPS
          initialDelaySeconds: 360
          periodSeconds: 30
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 5
        readinessProbe:
          httpGet:
            path: /healthz
            port: 3000
            scheme: HTTPS
          initialDelaySeconds: 45
          periodSeconds: 5
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 3
```

上面的例子中：
- `initialDelaySeconds` 指定 kubelet 在该执行第一次探测之前需要等待 45 秒钟。也就是容器启动后第一次执行探测是需要等待多少秒。
- `periodSeconds` 指定 kubelet 需要每隔 5 秒执行一次 probe。也就是执行探测的频率。默认是10秒，最小1秒。
- `timeoutSeconds` 探测超时时间。默认1秒，最小1秒。
- `successThreshold` 探测失败后，最少连续探测成功多少次才被认定为成功。默认是1。对于 liveness 必须是 1。最小值是 1。
- `failureThreshold` 探测成功后，最少连续探测失败多少次才被认定为失败。默认是3。最小值是1。

`httpGet` 的其他配置项：
- `host`：连接的主机名，默认连接到 pod 的 IP。你可能想在 http header 中设置 "Host" 而不是使用 IP。
- `scheme`：连接使用的 schema，默认 `HTTP`。
- `path`: 访问的 HTTP server 的 `path`。
- `httpHeaders`：自定义请求的 header。
- `port`：访问的容器的端口名字或者端口号。端口号必须介于 1 和 65535 之间。

## Hook
容器生命周期钩子（Container Lifecycle Hooks）监听容器生命周期的特定事件，并在事件发生时执行已注册的回调函数。支持两种钩子：
- `postStart`：**容器创建后立即执行**，注意由于是异步执行，它无法保证一定在 `ENTRYPOINT` 之前运行。如果失败，容器会被杀死，并根据 `RestartPolicy` 决定是否重启。
在 `postStart` 操作执行完成之前，kubelet 会锁住容器，不让应用程序的进程启动，只有在 `postStart` 操作完成之后容器的状态才会被设置成为 `RUNNING`。
- `preStop`：**容器终止前执行**，常用于资源清理。如果失败，容器同样也会被杀死。

钩子的回调函数支持两种方式：
- `exec`：在容器内执行命令，如果命令的退出状态码是 0 表示执行成功，否则表示失败
- `httpGet`：向指定 URL 发起 GET 请求，如果返回的 HTTP 状态码在 [200, 400] 之间表示请求成功，否则表示失败

```yml
apiVersion: v1
kind: Pod
metadata:
  name: lifecycle-demo
spec:
  containers:
  - name: lifecycle-demo-container
    image: nginx
    lifecycle:
      postStart:
        httpGet:
          path: /
          port: 80
      preStop:
        exec:
          command: ["/usr/sbin/nginx", "-s", "quit"]
```

### 调试 Hook
Hook 调用的日志没有暴露个给 Pod 的 event，所以只能通过 `describe` 命令来获取，如果有错误将可以看到 `FailedPostStartHook` 或 `FailedPreStopHook` 这样的 event。