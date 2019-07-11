---
title: ETCD
---

# ETCD

Etcd 是 CoreOS 基于 Raft 开发的分布式 `key-value` 存储，可用于服务发现、共享配置以及一致性保障（如数据库选主、分布式锁等）。

Etcd 是 Kubernetes 集群中的一个十分重要的组件，用于保存集群所有的网络配置和对象的状态信息。

整个 kubernetes 系统中一共有两个服务需要用到 Etcd 用来协同和存储配置，分别是：

- 网络插件 flannel、对于其它网络插件也需要用到 etcd 存储网络的配置信息
- kubernetes 本身，包括各种对象的状态和元信息配置

> 注意：**flannel 操作 etcd 使用的是 v2 的 API，而 kubernetes 操作 etcd 使用的 v3 的 API**，所以在下面我们执行 `etcdctl` 的时候需要设置 `ETCDCTL_API` 环境变量，
该变量默认值为 2。

## 原理
[理解 Raft 一致性算法 动画演示](http://thesecretlivesofdata.com/raft/)
[Raft 一致性算法论文的中文翻译](https://github.com/maemual/raft-zh_cn)

## Etcd 存储 Flannel 网络信息
我们在安装 Flannel 的时候配置了 `ETCD_PREFIX="/coreos.com/network"`参数，这是 Flannel 查询 etcd 的目录地址。

查看 Etcd 中存储的 flannel 网络信息：
```sh
$ etcdctl --ca-file=/etc/kubernetes/ssl/ca.pem \
--cert-file=/etc/kubernetes/ssl/kubernetes.pem \
--key-file=/etc/kubernetes/ssl/kubernetes-key.pem \
ls /coreos.com/network -r
2018-01-19 18:38:22.768145 I | warning: ignoring ServerName for user-provided CA for backwards compatibility is deprecated
/coreos.com/network/config
/coreos.com/network/subnets
/coreos.com/network/subnets/172.30.31.0-24
/coreos.com/network/subnets/172.30.20.0-24
/coreos.com/network/subnets/172.30.23.0-24
```
查看 flannel 的配置：
```sh
$ etcdctl --ca-file=/etc/kubernetes/ssl/ca.pem \
--cert-file=/etc/kubernetes/ssl/kubernetes.pem \
--key-file=/etc/kubernetes/ssl/kubernetes-key.pem \
get /coreos.com/network/config
2018-01-19 18:38:22.768145 I | warning: ignoring ServerName for user-provided CA for backwards compatibility is deprecated
{ "Network": "172.30.0.0/16", "SubnetLen": 24, "Backend": { "Type": "host-gw" } }
```

## Etcd 存储 Kubernetes 对象信息
Kubernetes 所有的资源对象都保存在 `/registry` 路径下：
```
ThirdPartyResourceData
apiextensions.k8s.io
apiregistration.k8s.io
certificatesigningrequests
clusterrolebindings
clusterroles
configmaps
controllerrevisions
controllers
daemonsets
deployments
events
horizontalpodautoscalers
ingress
limitranges
minions
monitoring.coreos.com
namespaces
persistentvolumeclaims
persistentvolumes
poddisruptionbudgets
pods
ranges
replicasets
resourcequotas
rolebindings
roles
secrets
serviceaccounts
services
statefulsets
storageclasses
thirdpartyresources
```
如果还创建了 CRD（自定义资源定义），则在此会出现 CRD 的 API。

### 查看集群中所有的 Pod 信息
直接从 etcd 中查看 kubernetes 集群中所有的 pod 的信息，可以使用下面的命令：
```sh
ETCDCTL_API=3 etcdctl get /registry/pods --prefix -w json|python -m json.tool
```

## 示例
```yml
apiVersion: v1
kind: Pod
metadata:
  name: etcd
  namespace: kube-system
  annotations:
    scheduler.alpha.kubernetes.io/critical-pod: ""
spec:
  containers:
  - command:
    - "sh"
    - "-c"
    - >
      umask 066;
      etcd
      --listen-peer-urls=https://0.0.0.0:2380
      --listen-client-urls=https://0.0.0.0:4001
      --advertise-client-urls=https://{THIS_NODE}:4001
      --initial-advertise-peer-urls=https://{THIS_NODE}:2380
      --cert-file=/etc/etcd/ssl/server.crt
      --key-file=/etc/etcd/ssl/server.key
      --trusted-ca-file=/etc/etcd/ssl/ca.crt
      --client-cert-auth
      --peer-cert-file=/etc/etcd/ssl/server.crt
      --peer-key-file=/etc/etcd/ssl/server.key
      --peer-trusted-ca-file=/etc/etcd/ssl/ca.crt
      --peer-client-cert-auth
      --name={THIS_NODE}
      --initial-cluster={initial_cluster}
      --initial-cluster-state={initial_cluster_state}
      --initial-cluster-token=etcd-cluster-1
      --data-dir=/var/etcd/data
      --auto-compaction-retention=168
      --snapshot-count=100000
      --heartbeat-interval=100
      --election-timeout=1000
      --max-snapshots=5
      --max-wals=5
      --force-new-cluster=false
    image: gcr.io/google_containers/{IMAGE_ETCD}
    imagePullPolicy: IfNotPresent
    name: etcd
    securityContext:
      runAsUser: {SYSTEM_USER_ID}
    resources: {}
    volumeMounts:
    - mountPath: /var/etcd
      name: etcd-data
    - mountPath: /etc/etcd/ssl
      name: etcd-certs
  hostNetwork: true
  priorityClassName: system-node-critical
  volumes:
  - hostPath:
      path: {K8S_HOME}/ssl
    name: etcd-certs
  - hostPath:
      path: {RUNTIME_CDFDATA_HOME}/etcd
      type: DirectoryOrCreate
    name: etcd-data
```
