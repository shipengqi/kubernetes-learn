---
title: kubeconfig 配置文件
---

# kubeconfig 配置文件
kubeconfig 文件用于配置集群访问信息。在开启了 TLS 的集群中，每次与集群交互时都需要身份认证，生产环境一般使用证书进行认证，其认证所需要的信息会放在 kubeconfig 文件中。
此外，k8s 的组件都可以使用 kubeconfig 连接 apiserver，[client-go](https://github.com/kubernetes/client-go) 、operator、helm 等其他组件也
使用 kubeconfig 访问 apiserver。

## 示例
```yml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: xxx
    server: https://xxx:6443
  name: cluster1
- cluster:
    certificate-authority-data: xxx
    server: https://xxx:6443
  name: cluster2
contexts:
- context:
    cluster: cluster1
    user: kubelet
  name: cluster1-context
- context:
    cluster: cluster2
    user: kubelet
  name: cluster2-context
current-context: cluster1-context
kind: Config
preferences: {}
users:
- name: kubelet
  user:
    client-certificate-data: xxx
    client-key-data: xxx
---
apiVersion: v1
clusters:
- cluster:
    certificate-authority: /opt/kubernetes/ssl/ca.crt
    server: https://sgdlitvm0339.hpeswlab.net:8443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: kubelet
  name: kubelet-to-kubernetes
current-context: kubelet-to-kubernetes
kind: Config
preferences: {}
users:
- name: kubelet
  user:
    client-certificate: /opt/kubernetes/ssl/kubernetes.crt
    client-key: /opt/kubernetes/ssl/kubernetes.key
```

## clusters
`cluster` 中包含 kubernetes 集群的端点数据，包括 kubernetes apiserver 的完整 url 以及集群的证书颁发机构。

可以使用 `kubectl config set-cluster` 添加或修改 `cluster` 条目。

## users
`user` 定义用于向 kubernetes 集群进行身份验证的客户端凭据。

可用凭证：
- `client-certificate`
- `client-key`
- `token`
- `username`
- `password`

`username/password` 和 `token` 只能选择一个，但 `client-certificate` 和 `client-key` 可以分别与它们组合。

可以使用 `kubectl config set-credentials` 添加或者修改 `user` 条目。

## contexts
`context` 定义了一个命名的 `cluster`、`user`、`namespace` 元组，用于使用提供的认证信息和命名空间将请求发送到指定的集群。

三个都是可选的。

可以使用 `kubectl config set-context` 添加或修改上下文条目。

## current-context
`current-context` 是作为 `cluster`、`user`、`namespace` 元组（context）的 key。

可以在 kubectl 命令行里覆盖这些值，通过分别传入 `--context=CONTEXT`、`--cluster=CLUSTER`、`--user=USER` 和 `--namespace=NAMESPACE`。

可以使用 `kubectl config use-context` 更改 `current-context`。

## kubectl 生成 kubeconfig 的示例
kubectl 可以快速生成 kubeconfig，以下是一个示例：
```sh
$ kubectl config set-credentials myself --username=admin --password=secret
$ kubectl config set-cluster local-server --server=http://localhost:8080
$ kubectl config set-context default-context --cluster=local-server --user=myself
$ kubectl config use-context cluster-context
$ kubectl config set contexts.default-context.namespace the-right-prefix
$ kubectl config view
```

## 使用 kubeconfig 文件配置 kuebctl 跨集群认证

kubectl 作为操作 k8s 的一个客户端工具，只要为 kubectl 提供连接 apiserver 的配置(kubeconfig)，kubectl 可以在任何地方操作该集群，当然，
若 kubeconfig 文件中配置多个集群，kubectl 也可以轻松地在多个集群之间切换。

kubectl 加载配置文件的顺序：
1. kubectl 默认连接本机的 8080 端口
2. 从 `$HOME/.kube` 目录下查找文件名为 `config` 的文件
3. 通过设置环境变量 KUBECONFIG 或者通过 `--kubeconfig` 去指定的文件

```sh
# 设置 KUBECONFIG 的环境变量
export KUBECONFIG=/etc/kubernetes/kubeconfig/kubelet.kubeconfig
# 指定 kubeconfig 文件
kubectl get node --kubeconfig=/etc/kubernetes/kubeconfig/kubelet.kubeconfig
# 使用不同的 context 在多个集群之间切换
kubectl  get node --kubeconfig=./kubeconfig --context=cluster1-context
```

### 设置 KUBECONFIG 环境变量

```sh
# 保存 KUBECONFIG 环境变量当前的值，以便稍后恢复。
export  KUBECONFIG_SAVED=$KUBECONFIG

# 设置 KUBECONFIG 环境变量
export  KUBECONFIG_SAVED=$KUBECONFIG
```
`KUBECONFIG` 环境变量是配置文件路径的列表，该列表在 Linux 和 Mac 中以冒号分隔，在 Windows 中以分号分隔。
例如，在 Linux 中，临时添加两条路径到 `KUBECONFIG` 环境变量中。：
```sh
export  KUBECONFIG=$KUBECONFIG:config-demo:config-demo-2
```

### 将 `$HOME/.kube/config` 追加到 KUBECONFIG 环境变量中
如果有 `$HOME/.kube/config` 文件，并且还未列在 `KUBECONFIG` 环境变量中， 那么现在将它追加到 `KUBECONFIG` 环境变量中。 例如，在 Linux 中：
```sh
export KUBECONFIG=$KUBECONFIG:$HOME/.kube/config

# 将 KUBECONFIG 环境变量还原为原始值
export KUBECONFIG=$KUBECONFIG_SAVED
```

## kubeconfig 文件合并规则
查看配置：
```sh
$ kubectl config view
```
输出可能来自单个 kubeconfig 文件，也可能是多个 kubeconfig 文件合并的结果。

合并规则：
1. 如果设置了 `--kubeconfig`，那么只会使用指定 `--kubeconfig` 指定的文件，不会合并。否则，如果设置了 `KUBECONFIG` 环境变量，则使用它作为
应该合并的文件列表。按照以下规则合并 `KUBECONFIG`环境变量中列出的文件：
  - 文件名为空则忽略。
  - 文件内容反序列化失败报错。
  - 选取第一个文件的配置。
  - 不要更改值或映射键。示例:保存要设置 `current-context` 的第一个文件的 `context`。如果两个文件指定一个 `red-user`，则只使用
  第一个文件的 `red-user` 的值。即使第二个文件在 `red-user` 下有不冲突的字段，也要丢弃它们。

如果没有指定 `--kubeconfig`，也没有配置 `KUBECONFIG` 环境变量，则使用默认的 `$HOME/.kube/config`，不合并。

根据这个 chain 中的第一个命中确定要使用的 `context`:
1. 如果存在 `--context` 标志，则使用它。
2. 使用合并结果中的 `current-context`。

根据这个 chain 中的第一个命中确定要使用的 `user` 和 `cluster`:
1. 如果存在 `--user` 或 `--cluster` 标志，则使用它。
2. 使用 `context` 不为空，从这个 `context` 中获取 `user` 和 `cluster`。

确定要使用的实际 cluster 信息。此时，可能存在 cluster 信息，也可能不存在。基于这个 chain 构建 cluster 的每一块信息;选取第一个:
1. 如果存在 `--server`，`--certificate-authority`，`--insecure-skip-tls-verify` 标志，则使用它。
2. 使用合并结果中的 cluster 属性
3. 如果不存在 server 信息，失败

确定要使用的实际 user 信息。与 cluster 类似。