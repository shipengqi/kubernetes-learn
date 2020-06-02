---
title: kube-apiserver
---

# kube-apiserver
`kube-apiserver` 是 Kubernetes 最重要的核心组件之一，主要提供以下的功能：
- 提供集群管理的 REST API 接口，包括认证授权、数据校验以及集群状态变更等
- 提供其他模块之间的数据交互和通信的枢纽（其他模块通过 API Server 查询或修改数据，如  GET LIST WATCH 等 REST 接口，**只有 API Server 才直接操作 `etcd`**）

## REST API

kube-apiserver 支持同时提供 https（默认监听在 6443 端口）和 http API（默认监听在 `127.0.0.1` 的 8080 端口）， http 不建议生产环境启用。

[Kubernetes API Reference ](https://kubernetes.io/docs/reference/#api-reference)。

通常通过 [kubectl](./kubectl.html) 来访问 apiserver，也可以通过 Kubernetes 各个语言的 [client 库](https://github.com/kubernetes/client-go)来访问 apiserver。

在使用 kubectl 时，打开调试日志也可以看到每个 API 调用的格式，比如：
```sh
$ kubectl --v=8 get pods -n kube-system
```

## OpenAPI 和 Swagger
通过 `/swaggerapi` 可以查看 Swagger API，`/openapi/v2` 查看 OpenAPI。
开启 `--enable-swagger-ui=true` 后还可以通过 `/swagger-ui` 访问 Swagger UI。

## 访问控制
Kubernetes API 的每个请求都会经过多阶段的访问控制之后才会被接受，这包括认证、授权以及准入控制（Admission Control）等。

## 示例
```yml
apiVersion: v1
kind: Pod
metadata:
  name: apiserver
  namespace: kube-system
  annotations:
    scheduler.alpha.kubernetes.io/critical-pod: ""
spec:
  containers:
  - command:
    - /hyperkube
    - apiserver
    - --bind-address=0.0.0.0
    - --etcd-servers=https://{THIS_NODE}:4001
    - --anonymous-auth=false
    - --insecure-port=0
    - --secure-port={MASTER_API_SSL_PORT}
    - --authorization-mode=RBAC
    - --service-cluster-ip-range={SERVICE_CIDR}
    - --enable-admission-plugins=DenyEscalatingExec,PodPreset
    - --requestheader-client-ca-file=/etc/kubernetes/ssl/ca.crt
    - --proxy-client-cert-file=/etc/kubernetes/ssl/server.crt
    - --proxy-client-key-file=/etc/kubernetes/ssl/server.key
    - --requestheader-allowed-names=aggregator
    - --requestheader-extra-headers-prefix=X-Remote-Extra-
    - --requestheader-group-headers=X-Remote-Group
    - --requestheader-username-headers=X-Remote-User
    - --service-account-key-file=/etc/kubernetes/ssl/kube-serviceaccount.key
    - --tls-cert-file=/etc/kubernetes/ssl/server.crt
    - --tls-private-key-file=/etc/kubernetes/ssl/server.key
    - --client-ca-file=/etc/kubernetes/ssl/ca.crt
    - --etcd-certfile=/etc/kubernetes/ssl/server.crt
    - --etcd-keyfile=/etc/kubernetes/ssl/server.key
    - --etcd-cafile=/etc/kubernetes/ssl/ca.crt
    - --kubelet-client-certificate=/etc/kubernetes/ssl/server.crt
    - --kubelet-client-key=/etc/kubernetes/ssl/server.key
    - --storage-backend=etcd3
    - --encryption-provider-config=/etc/kubernetes/cfg/apiserver-encryption.yaml
    - --v=1
    - --service-node-port-range=60-40000
    - --allow-privileged=true
    - --logtostderr=true
    - --runtime-config=autoscaling/v2beta1=true,settings.k8s.io/v1alpha1=true
    - --tls-cipher-suites=TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA,TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA,TLS_RSA_WITH_AES_256_GCM_SHA384,TLS_RSA_WITH_AES_128_GCM_SHA256,TLS_RSA_WITH_AES_256_CBC_SHA,TLS_RSA_WITH_AES_128_CBC_SHA
    image: k8s.gcr.io/{IMAGE_HYPERKUBE}
    imagePullPolicy: IfNotPresent
    securityContext:
      runAsUser: {SYSTEM_USER_ID}
    livenessProbe:
      tcpSocket:
        port: {MASTER_API_SSL_PORT}
      initialDelaySeconds: 15
      timeoutSeconds: 15
    name: apiserver
    ports:
    - containerPort: {MASTER_API_SSL_PORT}
      hostPort: {MASTER_API_SSL_PORT}
      name: https
      protocol: TCP

    volumeMounts:
    - mountPath: /etc/kubernetes/ssl
      name: ssl-certs-path
      readOnly: true
    - mountPath: /etc/kubernetes/cfg/apiserver-encryption.yaml
      name: encryption-cfg
      readOnly: true

  dnsPolicy: ClusterFirst
  hostNetwork: true
  restartPolicy: Always
  terminationGracePeriodSeconds: 30
  priorityClassName: system-cluster-critical
  volumes:
  - hostPath:
      path: {K8S_HOME}/ssl
    name: ssl-certs-path
  - hostPath:
      path: {K8S_HOME}/cfg/apiserver-encryption.yaml
    name: encryption-cfg
```

## 工作原理
<img src="../imgs/kube-apiserver.png" width="70%">