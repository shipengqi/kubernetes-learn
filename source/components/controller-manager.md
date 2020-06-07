---
title: kube-controller-manager
---

Controller Manager 由 `kube-controller-manager` 和 `cloud-controller-manager` 组成，是 Kubernetes 的大脑，它通过 apiserver 监控整个集群的状态，
，发现故障自动修复，确保集群处于预期的工作状态。

<img src="../imgs/controller-manager.png" width="70%">

`kube-controller-manager` 由一系列的控制器组成：

- Replication Controller
- Node Controller
- CronJob Controller
- Daemon Controller
- Deployment Controller
- Endpoint Controller
- Garbage Collector
- Namespace Controller
- Job Controller
- Pod AutoScaler
- RelicaSet
- Service Controller
- ServiceAccount Controller
- StatefulSet Controller
- Volume Controller
- Resource quota Controller

## 示例

```yml
apiVersion: v1
kind: Pod
metadata:
  name: controller
  namespace: kube-system
  annotations:
    scheduler.alpha.kubernetes.io/critical-pod: ""
spec:
  containers:
  - command:
    - /hyperkube
    - controller-manager
    - --address=127.0.0.1
    - --bind-address=127.0.0.1
    - --master=https://{THIS_NODE}:{MASTER_API_SSL_PORT}
    - --leader-elect=true
    - --pod-eviction-timeout=1m0s
    - --service-account-private-key-file=/etc/kubernetes/ssl/kube-serviceaccount.key
    - --root-ca-file=/etc/kubernetes/ssl/ca.crt
    - --v=1
    - --logtostderr=true
    - --kubeconfig=/etc/kubernetes/ssl/kubeconfig
    - --authentication-kubeconfig=/etc/kubernetes/ssl/kubeconfig
    - --authorization-kubeconfig=/etc/kubernetes/ssl/kubeconfig
    - --pv-recycler-pod-template-filepath-nfs=/etc/kubernetes/cfg/recycler.yaml
    - --flex-volume-plugin-dir=/tmp/kubernetes/kubelet-plugins/volume/exec/
    # - --allocate-node-cidrs=true
    # - --cluster-cidr={POD_CIDR}
    # - --node-cidr-mask-size={POD_CIDR_SUBNETLEN}
    image: k8s.gcr.io/{IMAGE_HYPERKUBE}
    imagePullPolicy: IfNotPresent
    securityContext:
      runAsUser: {SYSTEM_USER_ID}
    livenessProbe:
      httpGet:
        host: 127.0.0.1
        path: /healthz
        port: 10252
        scheme: HTTP
      initialDelaySeconds: 15
      timeoutSeconds: 15
    name: controller
    volumeMounts:
    - mountPath: /etc/kubernetes/ssl
      name: ssl-certs-path
      readOnly: true
    - mountPath: /etc/kubernetes/cfg
      name: config
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
      path: {K8S_HOME}/cfg/controller-manager
    name: config
```

## Repliaction Controller

k8s 中除了副本控制器叫做 Repliaction Controller，另外还有一个资源对象也叫 Repliaction Controller。这里将资源对象简称 RC。
Repliaction Controller 指副本控制器。

Repliaction Controller 的核心作用是确保任何一个 RC 所关联的 Pod 的副本数量保持预设值。pod 副本数量多于预设值则销毁，反之创建。

pod 的重启策略 RestartPolicy=Always 时，才会被 Repliaction Controller 管理。

注意如果 pod 长时间处于 failed 或 succeed 状态，pod 会被自动回收，Repliaction Controller 则会重新创建 pod 副本。

### 滚动更新

有一个以上的副本时，Repliaction Controller 可以逐个替换 pod 实现滚动更新。

## Node Controller

kubelet 在启动时，向 API server 注册节点信息，并定时向 API server 汇报节点状态。API server 负责将节点信息更新到 ETCD。

Node Controller 通过 API server 实时获取 Node 信息，监控和管理所有 Node 节点。
