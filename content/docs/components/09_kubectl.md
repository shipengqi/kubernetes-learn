---
title: kubectl
---

kubectl 是 Kubernetes 的命令行工具（CLI）。提供了大量的子命令，方便管理 Kubernetes 集群中的各种功能。

## 配置

使用 kubectl 的第一步是配置 Kubernetes 集群以及认证方式，包括

- cluster 信息：Kubernetes server 地址
- 用户信息：用户名、密码或密钥
- Context：cluster、用户信息以及 Namespace 的组合

```sh
kubectl config set-cluster kubernetes \
--server=https://${K8S_APISERVER_IP}:${MASTER_API_SSL_PORT} \
--certificate-authority=${K8S_HOME}/ssl/ca.crt

kubectl config set-context kubelet-to-kubernetes \
--cluster=kubernetes  --user=kubelet

kubectl config set-credentials kubelet \
--client-certificate=${K8S_HOME}/ssl/${prefix}.crt \
--client-key=${K8S_HOME}/ssl/${prefix}.key

kubectl config use-context kubelet-to-kubernetes
```

## 常用命令格式

- 创建：`kubectl run <name> --image=<image>` 或者 `kubectl create -f manifest.yaml`
- 查询：`kubectl get <resource>`
- 更新 `kubectl set` 或者 `kubectl patch`
- 删除：`kubectl delete <resource> <name>` 或者 `kubectl delete -f manifest.yaml`
- 查询 Pod IP：`kubectl get pod <pod-name> -o jsonpath='{.status.podIP}'`
- 容器内执行命令：`kubectl exec -it <pod-name> bash`
- 容器日志：`kubectl logs [-f] <pod-name>`
- 导出服务：`kubectl expose deploy <name> --port=80`
- Base64 解码：

```sh
kubectl get secret SECRET -o go-template='{{ .data.KEY | base64decode }}'
```

> `kubectl run` 仅支持 Pod、Replication Controller、Deployment、Job 和 CronJob 等几种资源。

## 命令概览

- [kubectl annotate](#annotate) – 更新资源的注解。
- [kubectl api-versions](#api-versions) – 以“组/版本”的格式输出服务端支持的API版本。
- [kubectl apply](#apply) – 通过文件名或控制台输入，对资源进行配置。
- [kubectl attach](#attach) – 连接到一个正在运行的容器。
- [kubectl autoscale](#autoscale) – 对 replication controller 进行自动伸缩。
- [kubectl cluster-info](#cluster-info) – 输出集群信息。
- [kubectl config](#config) – 修改 kubeconfig 配置文件。
- [kubectl convert](#convert) – 转换配置文件为不同的 API 版本。
- [kubectl cordon](#cordon) – 将节点标记为不可调度。
- [kubectl cp](#cp) – 从容器中复制文件和目录。
- [kubectl create](#create) – 通过文件名或控制台输入，创建资源。
- [kubectl delete](#delete) – 通过文件名、控制台输入、资源名或者 label selector 删除资源。
- [kubectl describe](#describe) – 输出指定的一个/多个资源的详细信息。
- [kubectl drain](#drain) – 排空节点。
- [kubectl edit](#edit) – 编辑服务端的资源。
- [kubectl exec](#exec) – 在容器内部执行命令。
- [kubectl explain](#explain) – 资源文档。
- [kubectl expose](#expose) – 输入 replication controller，service 或者 pod，并将其暴露为新的 kubernetes service。
- [kubectl get](#get) – 输出一个/多个资源。
- [kubectl label](#label) – 更新资源的 label。
- [kubectl logs](#logs) – 输出 pod 中一个容器的日志。
- [kubectl patch](#patch) – 通过控制台输入更新资源中的字段。
- [kubectl port-forward](#port-forward) – 将本地端口转发到 Pod。
- [kubectl proxy](#proxy) – 为 Kubernetes API server 启动代理服务器。
- [kubectl replace](#replace) – 通过文件名或控制台输入替换资源。
- [kubectl rolling-update](#rolling-update) – 对指定的 replication controller 执行滚动升级。
- [kubectl rollout](#rollout) – 对资源进行管理。
- [kubectl run](#run) – 在集群中使用指定镜像启动容器。
- [kubectl scale](#scale) – 为 replication controller 设置新的副本数。
- [kubectl uncordon](#uncordon) – 将节点标记为可调度。
- [kubectl version](#version) – 输出服务端和客户端的版本信息。

### annotate

更新一个或多个资源的 [Annotations](../cluster/annotation.html) 信息。

- Annotations 由 `key/value` 组成。
- Annotations 的目的是存储辅助数据，特别是通过工具和系统扩展操作的数据。
- **如果 `--overwrite` 为 `true`，现有的 annotations 可以被覆盖，否则试图覆盖 annotations 将会报错**。
- 如果设置了 `--resource-version`，则更新将使用此 resource version，否则将使用原有的 resource version。

```sh
kubectl annotate [--overwrite] (-f FILENAME | TYPE NAME) KEY_1=VAL_1 ... KEY_N=VAL_N [--resource-version=version]

# 选项
--all[=false]: 选择 namespace 中所有指定类型的资源。
-f, --filename=[]: 用来指定待升级资源的文件名，目录名或者 URL。
--overwrite[=false]: 如果设置为 true，允许覆盖更新注解，否则拒绝更新已存在的注解。
--resource-version="": 如果不为空，仅当资源当前版本和指定版本相同时才能更新注解。仅当更新单个资源时有效。
```

示例：

```sh
# 更新名为 "foo" 的 pod，设置其注解 description 的值为 "my frontend"。
# 如果同一个注解被赋值了多次，只保存最后一次设置的值。
$ kubectl annotate pods foo description='my frontend'

# 更新 pod.json 文件中 type 和 name 字段指定的 pod 的注解。
$ kubectl annotate -f pod.json description='my frontend'

# 更新名为 "foo" 的 pod，设置其注解 description 的值为 my frontend running nginx，已有的值将被覆盖。
$ kubectl annotate --overwrite pods foo description='my frontend running nginx'

# 更新同一 namespace 下所有的 pod。
$ kubectl annotate pods --all description='my frontend running nginx'

# 仅当名为 "foo" 的 pod 当前版本为 1 时，更新其注解
$ kubectl annotate pods foo description='my frontend running nginx' --resource-version=1

# 更新名为 "foo" 的 pod，删除其注解 description。
# 不需要 --override 选项。
$ kubectl annotate pods foo description-
```

### api-versions

以 “组/版本” 的格式输出服务端支持的 API 版本。

```sh
kubectl api-versions
```

### apply

通过文件名或控制台输入，对资源进行配置。接受 JSON 和 YAML 格式的描述文件。

```sh
kubectl apply -f FILENAME

# 选项
-f, --filename=[]: 包含配置信息的文件名，目录名或者URL。
-o, --output="": 输出格式，使用 "-o name" 来输出简短格式（资源类型/资源名）。
--schema-cache-dir="/tmp/kubectl.schema": 如果不为空，将 API schema 缓存为指定文件，默认缓存到 "/tmp/kubectl.schema"。
--validate[=true]: 如果为 true，在发送到服务端前先使用 schema 来验证输入。
```

#### 示例

```sh
# 将 pod.json 中的配置应用到 pod
$ kubectl apply -f ./pod.json

# 将控制台输入的 JSON 配置应用到 Pod
$ cat pod.json | kubectl apply -f -
```

### attach

连接到现有容器中一个正在运行的进程。

```sh
kubectl attach POD -c CONTAINER

# 选项
-c, --container="": 容器名。
-i, --stdin[=false]: 将控制台输入发送到容器。
-t, --tty[=false]: 将标准输入控制台作为容器的控制台输入。
```

#### 示例

```sh
# 获取正在运行中的pod 123456-7890的输出，默认连接到第一个容器
$ kubectl attach 123456-7890

# 获取pod 123456-7890中ruby-container的输出
$ kubectl attach 123456-7890 -c ruby-container date

# 切换到终端模式，将控制台输入发送到pod 123456-7890的ruby-container的“bash”命令，并将其输出到控制台/
# 错误控制台的信息发送回客户端。
$ kubectl attach 123456-7890 -c ruby-container -i -t
```

### autoscale

使用 autoscaler 自动设置在 kubernetes 集群中运行的 pod 数量（水平自动伸缩）。

指定 Deployment、ReplicaSet 或 ReplicationController，并创建已经定义好资源的自动伸缩器。使用自动伸缩器可以根据需要自动增加或减少系统中部署的 pod 数量。

```sh
autoscale (-f FILENAME | TYPE NAME | TYPE/NAME) [--min=MINPODS] --max=MAXPODS [--cpu-percent=CPU] [flags]
```

#### 示例

```sh
# 使用 Deployment "foo" 设定，使用默认的自动伸缩策略，指定目标 CPU 使用率，使其 Pod 数量在 2 到 10 之间。
$ kubectl autoscale deployment foo --min=2 --max=10

# 使用 RC "foo" 设定，使其 Pod 的数量介于 1 和 5 之间，CPU 使用率维持在 80%。
$ kubectl autoscale rc foo --max=5 --cpu-percent=80
```

### cluster-info

显示 master 节点的地址和包含 `kubernetes.io/cluster-service=true` 的 service（系统 service）。

```sh
kubectl cluster-info
```

### config

修改 kubeconfig 配置文件。如 `kubectl config set current-context my-context`。

配置文件的读取遵循如下规则：

- 如果指定了 **`--kubeconfig`** 选项，那么只有指定的文件被加载。此选项只能被设置一次，并且不会合并其他文件。
- 如果设置了 **`$KUBECONFIG`** 环境变量，将同时使用此环境变量指定的所有文件列表（使用操作系统默认的顺序），所有文件将被合并。当修改一个值时，
将修改设置了该值的文件。当创建一个值时，将在列表的首个文件创建该值。若列表中所有的文件都不存在，将创建列表中的最后一个文件。
- 如果前两项都没有设置,将使用 **`${HOME}/.kube/config`**，并且不会合并其他文件。

```sh
kubectl config SUBCOMMAND

# 选项
--kubeconfig="": 使用特定的配置文件。
```

#### 示例

```sh
${K8S_HOME}/bin/kubectl config set-cluster kubernetes \
--server=https://${K8S_APISERVER_IP}:${MASTER_API_SSL_PORT} \
--certificate-authority=${K8S_HOME}/ssl/ca.crt

${K8S_HOME}/bin/kubectl config set-context kubelet-to-kubernetes \
--cluster=kubernetes  \
--user=kubelet

${K8S_HOME}/bin/kubectl config set-credentials kubelet \
--client-certificate=${K8S_HOME}/ssl/${prefix}.crt \
--client-key=${K8S_HOME}/ssl/${prefix}.key

${K8S_HOME}/bin/kubectl config use-context kubelet-to-kubernetes
```

#### kubectl config set-cluster

在 `kubeconfig` 配置文件中设置一个集群项。 如果指定了一个已存在的名字，将合并新字段并覆盖旧字段。

```sh
kubectl config set-cluster NAME \
[--server=server] \
[--certificate-authority=path/to/certficate/authority] \
[--api-version=apiversion] \
[--insecure-skip-tls-verify=true]

# 选项
--api-version="": 设置 kuebconfig 配置文件中集群选项中的 api-version。
--certificate-authority="": 设置 kuebconfig 配置文件中集群选项中的 certificate-authority 路径。
--embed-certs=false: 设置 kuebconfig 配置文件中集群选项中的 embed-certs 开关。
--insecure-skip-tls-verify=false: 设置 kuebconfig 配置文件中集群选项中的 insecure-skip-tls-verify 开关。
--server="": 设置 kuebconfig 配置文件中集群选项中的 server。
```

#### 示例

```sh
# 仅设置 e2e 集群项中的 server 字段，不影响其他字段
$ kubectl config set-cluster e2e --server=https://1.2.3.4

# 向 e2e 集群项中添加认证鉴权数据
$ kubectl config set-cluster e2e --certificate-authority=~/.kube/e2e/kubernetes.ca.crt

# 取消 dev 集群项中的证书检查
$ kubectl config set-cluster e2e --insecure-skip-tls-verify=true
```

#### kubectl config set-context

在 `kubeconfig` 配置文件中设置一个环境项。 如果指定了一个已存在的名字，将合并新字段并覆盖旧字段。

```sh
kubectl config set-context NAME \
[--cluster=cluster_nickname] \
[--user=user_nickname] \
[--namespace=namespace]

# 选项
--cluster="": 设置 kuebconfig 配置文件中环境选项中的集群。
--namespace="": 设置 kuebconfig 配置文件中环境选项中的命名空间。
--user="": 设置 kuebconfig 配置文件中环境选项中的用户。
```

#### 示例

```sh
# 设置 gce 环境项中的 user 字段，不影响其他字段。
$ kubectl config set-context gce --user=cluster-admin
```

#### kubectl config set-credentials

在 `kubeconfig` 配置文件中设置一个用户项。 如果指定了一个已存在的名字，将合并新字段并覆盖旧字段。

```sh
kubectl config set-credentials NAME \
[--client-certificate=path/to/certfile] \
[--client-key=path/to/keyfile] \
[--token=bearer_token] \
[--username=basic_user] \
[--password=basic_password]

# 选项
--client-certificate="": 设置 kuebconfig 配置文件中用户选项中的证书文件路径。
--client-key="": 设置 kuebconfig 配置文件中用户选项中的证书密钥路径。
--embed-certs=false: 设置 kuebconfig 配置文件中用户选项中的 embed-certs 开关。
--password="": 设置 kuebconfig 配置文件中用户选项中的密码。
--token="": 设置 kuebconfig 配置文件中用户选项中的令牌。
--username="": 设置 kuebconfig 配置文件中用户选项中的用户名。
```

#### 示例

```sh
# 仅设置 cluster-admin 用户项下的 client-key 字段，不影响其他值
$ kubectl config set-credentials cluster-admin --client-key=~/.kube/admin.key

# 为 cluster-admin 用户项设置基础认证选项
$ kubectl config set-credentials cluster-admin --username=admin --password=uXFGweU9l35qcif

# 为 cluster-admin 用户项开启证书验证并设置证书文件路径
$ kubectl config set-credentials cluster-admin --client-certificate=~/.kube/admin.crt --embed-certs=true
```

#### kubectl config set

在 `kubeconfig` 配置文件中设置一个单独的值。

`PROPERTY_NAME` 使用 `.` 进行分隔，每段代表一个属性名或者 map 的键，map 的键不能包含 `.`。 `PROPERTY_VALUE` 需要设置的新值。

```sh
kubectl config set PROPERTY_NAME PROPERTY_VALUE
```

#### kubectl config unset

在 `kubeconfig` 配置文件中清除一个单独的值。

`PROPERTY_NAME` 使用 `.` 进行分隔，每段代表一个属性名或者 map 的键，map 的键不能包含 `.`。

```sh
kubectl config unset PROPERTY_NAME
```

#### kubectl config use-context

使用 `kubeconfig` 中的一个环境项作为当前配置。

```sh
kubectl config use-context CONTEXT_NAME
```

#### kubectl config view

显示合并后的 `kubeconfig` 设置，或者一个指定的 `kubeconfig` 配置文件。

```sh
kubectl config view

# 选项
  --flatten[=false]: 将读取的 kubeconfig 配置文件扁平输出为自包含的结构（对创建可迁移的 kubeconfig 配置文件有帮助）
  --merge=true: 按照继承关系合并所有的 kubeconfig 配置文件。
  --minify[=false]: 如果为 true，不显示目前环境未使用到的任何信息。
  --no-headers[=false]: 当使用默认输出格式时不打印标题栏。
-o, --output="": 输出格式，只能使用 json|yaml|wide|name|go-template=...|go-template-file=...|jsonpath=...|jsonpath-file=...中的一种。
  --output-version="": 输出资源使用的 API 版本（默认使用 api-version）。
  --raw[=false]: 显示未经格式化的字节信息。
-a, --show-all[=false]: 打印输出时，显示所有的资源（默认隐藏状态为 terminated 的 pod）。
  --sort-by="": 如果不为空，对输出的多个结果根据指定字段进行排序。该字段使用 jsonpath 表达式（如 "ObjectMeta.Name"）描述，并且该字段只能为字符串或者整数类型。
  --template="": 当指定了 -o=go-template 或 -o=go-template-file 时使用的模板字符串或者模板文件。模板的格式为 golang 模板
```

[jsonpath 模板](http://releases.k8s.io/release-1.1/docs/user-guide/jsonpath.md)。
[golang 模板](http://golang.org/pkg/text/template/#pkg-overview)。

#### 示例

```sh
# 显示合并后的 kubeconfig 设置
$ kubectl config view

# 获取 e2e 用户的密码
$ kubectl config view -o template --template='{{range .users}}{{ if eq .name "e2e" }}{{ index .user.password }}{{end}}{{end}}'
```

### convert

转换配置文件为不同的 API 版本，支持 YAML 和 JSON 格式。

该命令将配置文件名，目录或 URL 作为输入，并将其转换为指定的版本格式，如果目标版本未指定或不支持，则转换为最新版本。

默认输出将以 YAML 格式打印出来，可以使用 `-o` 选项改变输出格式。

```sh
kubectl convert -f FILENAME

# 选项
-f, --filename=[]: 需要转换的配置文件名，目录或 URL。
  --include-extended-apis[=true]: 如果为 true, 通过调用 API server 来包含新 API 的定义。 [默认值 true]
  --local[=true]: 如果为 true, convert 不会尝试 connect api server，而是在本地运行。
  --no-headers[=false]: 当使用默认输出格式时不打印标题栏。
-o, --output="": 输出格式，只能使用 json|yaml|wide|name|go-template=...|go-template-file=...|jsonpath=...|jsonpath-file=...中的一种。
  --output-version="": 输出 group version（例如 'extensions/v1beta1'）。
-R, --recursive[=false]: 递归处理 -f 或 --filename 指定的目录。当你希望管理在同一目录中组织的相关清单时，此功能非常有用。
  --schema-cache-dir="~/.kube/schema": 如果不为空，加载/存储 这个目录中的 API schemas。默认是 '$HOME/.kube/schema'。
-a, --show-all[=false]: 打印时，显示所有资源 (默认情况下隐藏 terminated 的 pods)。
  --show-labels[=false]: 打印时，将所有标签显示为最后一列 (默认隐藏标签列)
  --sort-by="": 如果不为空，使用此字段规范对列表类型排序。字段规范表示为 JSONPath 表达式 (e.g. '{.metadata.name}')。这个 JSONPath 表达式指定的 API 资源中的字段必须是整数或字符串。
  --template="": 当指定了 -o=go-template 或 -o=go-template-file 时使用的模板字符串或者模板文件。模板的格式为 golang 模板。
  --validate[=true]: 如果为 true, 在发送输入之前，使用 schema 验证输入。
```

#### 示例

```sh
# 将 pod.yaml 转换为最新版本
$ kubectl convert -f pod.yaml

# 将 pod.yaml 指定的资源的实时状态转换为最新版本，并以 json 格式打印到 stdout。
$ kubectl convert -f pod.yaml --local -o json

# 将当前目录下的所有文件转换为最新版本，并将其全部创建。
$ kubectl convert -f . | kubectl create -f -
```

### cordon

将节点标记为不可调度。

```sh
kubectl cordon NODE
```

#### 示例

```sh
# 将节点 foo 标记为不可调度.
kubectl cordon foo
```

### cp

```sh
kubectl cp <file-spec-src> <file-spec-dest>

# 选项
-c, --container=""：容器的名字。如果省略，将选择 pod 中的第一个容器。
--no-preserve[=true]：默认为 false。复制的文件/目录的所有权和权限将不会保留在容器中
```

#### 示例

```sh
# 将本地目录 /tmp/foo_dir 复制到默认名称空间中的 pod 中的 /tmp/bar_dir
kubectl cp /tmp/foo_dir <some-pod>:/tmp/bar_dir

# 复制本地文件 /tmp/foo 到 pod 的特定的容器中的 /tmp/bar
kubectl cp /tmp/foo <some-pod>:/tmp/bar -c <specific-container>

# 将本地文件 /tmp/foo 复制到指定名称空间中的 pod 中的 /tmp/bar
kubectl cp /tmp/foo <some-namespace>/<some-pod>:/tmp/bar

# 从 pod 中的 /tmp/foo 复制到本地的 /tmp/bar
kubectl cp <some-namespace>/<some-pod>:/tmp/foo /tmp/bar
```

### create

通过文件名或控制台输入，创建资源。接受 JSON 和 YAML 格式的描述文件。

```sh
kubectl create -f FILENAME

# 选项
-f, --filename=[]: 用以创建资源的文件名，目录名或者 URL。
-o, --output="": 输出格式，使用 "-o name" 来输出简短格式（资源类型/资源名）。
  --schema-cache-dir="/tmp/kubectl.schema": 如果不为空，将 API schema 缓存为指定文件，默认缓存到 "/tmp/kubectl.schema"。
  --validate[=true]: 如果为 true，在发送到服务端前先使用 schema 来验证输入。
```

#### 示例

```sh
# 使用 pod.json 文件创建一个 pod
$ kubectl create -f ./pod.json

# 通过控制台输入的 JSON 创建一个 pod
$ cat pod.json | kubectl create -f -
```

#### kubectl create namespace

创建一个具有指定名称的 namespace。

```sh
kubectl create namespace NAME [--dry-run]

# 选项
--dry-run[=false]: 如果为 true，则只打印将要发送的对象，而不发送它。
```

#### 示例

```sh
# 创建一个名叫 my-namespace 的 namespace
$ kubectl create namespace my-namespace
```

#### kubectl create deployment

创建具有指定名称的 deployment。

```sh
kubectl create deployment NAME --image=image [--dry-run]
```

#### 示例

```sh
# 创建一个名为 my-dep 的 deployment，运行 busybox 镜像。
$ kubectl create deployment my-dep --image=busybox
```

#### kubectl create configmap

根据配置文件、目录或指定的 literal-value 创建 configmap 。

当基于配置文件创建 configmap 时，key 将默认为文件的基础名称，value 默认为文件文本内容。如果基本名称的 key 无效，则可以指定另一个 key。

当基于目录创建 configmap 时，key 还是文件的基础名称，目录中每个配置文件名都被设置为 key，文件内容设置为 value。

```sh
kubectl create configmap NAME [--from-file=[key=]source] [--from-literal=key1=value1] [--dry-run]

# 选项
--dry-run[=false]: 如果为 true，则只打印将要发送的对象，而不发送它。
--from-file=[]: 指定的目录下的所有文件都会被用在 `ConfigMap` 里面创建一个 `key/value` 键值对，`key` 的名字就是文件名，`value` 就是文件的内容，参数可以使用多次。
- `key`，当 `--from-file` 指定的是一个文件目录时，可以为每个文件设置 `key`，而不使用文件名来作为 `key`， 如 `--from-file=config1=example/a`。
--from-literal=[]: 指定要插入 configmap 的 key 和 value (i.e. mykey=somevalue)
```

更多参考 [ConfigMap](../storage/configmap.html)。

#### kubectl create secret tls

从给定的（public/private）公钥/私钥对创建 TLS secret 。

公共密钥证书必须是 `.PEM` 编码并匹配指定的私钥。

```sh
kubectl create secret tls NAME --cert=path/to/cert/file --key=path/to/key/file [--dry-run]

# 选项
--cert="": PEM 编码的公钥证书的路径。
--key="": 与给定证书关联的私钥的路径。
```

#### 示例

```sh
# 使用指定的 key 创建名为 tls-secre t的 TLS secret：
$ kubectl create secret tls tls-secret --cert=path/to/tls.cert --key=path/to/tls.key
```

更多参考 [Secret](../storage/secret.html)。

#### kubectl create secret generic

根据配置文件、目录或指定的 `literal-value` 创建 secret。

secret 可以保存为一个或多个 `key/value` 信息。

当基于配置文件创建 secret 时，key 将默认为文件的基础名称，value 默认为文件内容。如果基本名称的 key 无效，则可以指定另一个 key。

当基于目录创建 secret 时，key 还是文件的基础名称，目录中有效的 key 的每个文件都被打包到 secret 中，除了常规文件之外的任何目录条目都被忽略
(例如 subdirectories, symlinks, devices, pipes, etc)。

```sh
kubectl create generic NAME [--type=string] [--from-file=[key=]source] [--from-literal=key1=value1] [--dry-run]

# 选项
--type="": 创建的 secret 类型
--from-file=[]: 指定的目录下的所有文件都会被用在 `ConfigMap` 里面创建一个 `key/value` 键值对，`key` 的名字就是文件名，`value` 就是文件的内容，参数可以使用多次。
  - `key`，当 `--from-file` 指定的是一个文件目录时，可以为每个文件设置 `key`，而不使用文件名来作为 `key`， 如 `--from-file=config1=example/a`。
--from-literal=[]: 指定要插入 configmap 的 key 和 value (i.e. mykey=somevalue)
```

更多参考 [Secret](../storage/secret.html)。

#### kubectl create secret docker-registry

创建与 Docker registries 一起使用的s ecret。

Dockercfg secrets 用于对 Docker registries 进行安全认证。

当使用 Docker 命令 push 镜像时，可以进行 Docker registries 认证。

```sh
docker login DOCKER_REGISTRY_SERVER --username=DOCKER_USER --password=DOCKER_PASSWORD --email=DOCKER_EMAIL
```

这时会产生一个 `~/.dockercf`g 文件，在 `docker push` 和 `docker pull` 命令时，此文件用于 registries 进行认证。

在创建应用时，当 Node 节点从私有仓库 Pull 镜像时，需要有相应凭证，才能使用私有 Docker 仓库。我们可以通过创建 `dockercfg secret` 并
添加到 service account 来实现。

更多参考 [Secret](../storage/secret.html)。

#### 其他

```sh
kubectl create serviceaccount NAME [--dry-run]

kubectl create role NAME --verb=verb --resource=resource.group/subresource [--resource-name=resourcename] [--dry-run]

kubectl create rolebinding NAME --clusterrole=NAME|--role=NAME \
[--user=username] \
[--group=groupname] \
[--serviceaccount=namespace:serviceaccountname] \
[--dry-run]
```

### delete

通过配置文件名、stdin、资源名称或 label 选择器来删除资源。

支持 JSON 和 YAML 格式文件。可以只指定一种类型的参数：文件名、资源名称或 label 选择器。

有些资源，如 pod，支持优雅的（graceful）删除，因为这些资源一般是集群中的实体，所以删除不可能会立即生效，这些资源在强制终止之前默认定义了一个周期（宽限期），
但是你可以使用 `--grace-period` 来覆盖该值。

如果托管 Pod 的 Node 节点已经停止或者无法连接 API Server，使用 `delete` 命令删除 Pod 需等待时间更长。要强制删除资源，需指定 `--force`，且设置周期（宽限期）为 0。

如果执行强制删除 Pod，则调度程序会在节点释放这些 Pod 之前将新的 Pod 放在这些节点上，并使之前 Pod 立即被逐出。

> 执行 `delete` 命令时不会检查资源版本，如果在执行 `delete` 操作时有人进行了更新操作，那么更新操作将连同资源一起被删除

```sh
kubectl delete ([-f FILENAME] | TYPE [(NAME | -l label | --all)])

# 选项
  --all[=false]: 使用 [-all] 选择所有指定的资源。
  --cascade[=true]: 如果为 true，级联删除指定资源所管理的其他资源（例如：被 replication controller 管理的所有 pod）。默认为 true。
-f, --filename=[]: 用以指定待删除资源的文件名，目录名或者 URL。
  --grace-period=-1: 安全删除资源前等待的秒数。如果为负值则忽略该选项。
  --ignore-not-found[=false]: 当待删除资源未找到时，也认为删除成功。如果设置了--all 选项，则默认为 true。
  --now[=false]: 如果为 true，资源被强制终止，而没有优雅地删除 (和 --grace-period=0 效果一样).
-o, --output="": 输出格式，使用 "-o name" 来输出简短格式（资源类型/资源名）。
-l, --selector="": 用于过滤资源的 Label。
  --timeout=0: 删除资源的超时设置，0 表示根据待删除资源的大小由系统决定。
```

#### 示例

```sh
# 通过 pod.json 文件中指定的资源类型和名称删除一个 pod
$ kubectl delete -f ./pod.json

# 通过控制台输入的 JSON 所指定的资源类型和名称删除一个 pod
$ cat pod.json | kubectl delete -f -

# 删除所有名为 "baz" 和 "foo" 的 pod 和 service
$ kubectl delete pod,service baz foo

# 删除所有带有 lable name=myLabel 的 pod 和 service
$ kubectl delete pods,services -l name=myLabel

# 删除 UID 为 1234-56-7890-234234-456456 的 pod
$ kubectl delete pod 1234-56-7890-234234-456456

# 删除所有的 pod
$ kubectl delete pods --all
```

### describe

输出指定的一个或多个资源的详细信息。

```sh
$ kubectl describe TYPE NAME_PREFIX

# 选项
-f, --filename=[]: 用来指定待描述资源的文件名，目录名或者 URL。
-l, --selector="": 用于过滤资源的 Label。
```

#### 示例

```sh
# 描述一个 node
$ kubectl describe nodes kubernetes-minion-emt8.c.myproject.internal

# 描述一个 pod
$ kubectl describe pods/nginx

# 描述 pod.json 中的资源类型和名称指定的 pod
$ kubectl describe -f pod.json

# 描述所有的 pod
$ kubectl describe pods

# 描述所有包含 label name=myLabel 的 pod
$ kubectl describe po -l name=myLabel

# 描述所有被 replication controller “frontend” 管理的 pod（rc创建的pod都以rc的名字作为前缀）
$ kubectl describe pods frontend
```

### drain

排空节点，准备维护。

给定节点将被标记为不可调度，以防止新的 pod 调度到该节点。然后 `drain` 会删除除了 `mirror pod` （mirror pod 不能通过 API 删除）之外的所有 pods。

- 如果存在 DaemonSet 管理的 pods，`drain` 必须指定 `--ignore-daemonsets` 才会继续运行，而且无论如何，它都不会删除任何 DaemonSet 管理的 pods，
因为这些 pod 将立即被 DaemonSet controller 替换，忽略不可调度的标记。
- 如果有任何 pod 既不是 `mirror pod`，也不是由 ReplicationController、ReplicaSet、DaemonSet 或 Job 管理的，那么 drain 不会删除任何 pod，除非使用 `-force`。

当准备将节点重新投入服务时，使用 `kubectl uncordon`，这将使节点再次可调度。

```sh
kubectl drain NODE
```

#### 示例

```sh
# 排空节点 "foo", 即使有些 pod 不是由 ReplicationController、ReplicaSet、Job 或 DaemonSet 管理的.
$ kubectl drain foo --force

# 排空节点 "foo"，但是如果存在不是由 ReplicationController、ReplicaSet、Job 或 DaemonSet 管理的 pod，则终止，并使用 15 分钟的宽限期。
$ kubectl drain foo --grace-period=900
```

### edit

使用系统默认编辑器编辑服务端的资源。

`edit` 命令允许你直接编辑使用命令行工具获取的任何资源。此命令将打开你通过 `KUBE_EDITOR`，`GIT_EDITOR` 或者 `EDITOR` 环境变量定义的编辑器，或者直接使用 `vi`。

可以同时编辑多个资源，但所有的变更都只会一次性提交。`edit` 除命令参数外还接受文件名形式。

文件默认输出格式为 YAML。要以 JSON 格式编辑，请指定 `-o json` 选项。

如果当更新资源的时候出现错误，将会在磁盘上创建一个临时文件，记录未成功的更新。**更新资源时最常见的错误 是其他人也在更新服务端的资源**。

当这种情况发生时，你需要将你所作的更改应用到最新版本的资源上，或者编辑 保存的临时文件，使用最新的资源版本。

```sh
kubectl edit (RESOURCE/NAME | -f FILENAME)

# 选项
-f, --filename=[]: 用来指定待编辑资源的文件名，目录名或者 URL。
-o, --output="yaml": 输出格式，可选 yaml 或者 json 中的一种。
    --output-version="": 输出资源使用的 API 版本（默认使用 api-version）。
```

#### 示例

```sh
# 编辑名为 docker-registry 的 service
$ kubectl edit svc/docker-registry

# 使用一个不同的编辑器
$ KUBE_EDITOR="nano" kubectl edit svc/docker-registry

# 编辑名为 docker-registry 的 service，使用 JSON 格式、v1 API版本
$ kubectl edit svc/docker-registry --output-version=v1 -o json
```

### exec

在容器内部执行命令。

```sh
kubectl exec POD [-c CONTAINER] -- COMMAND [args...]

# 选项
-c, --container="": 容器名。如果未指定，使用 pod 中的一个容器。
-p, --pod="": Pod 名。
-i, --stdin[=false]: 将控制台输入发送到容器。
-t, --tty[=false]: 将标准输入控制台作为容器的控制台输入。
```

#### 示例

```sh
# 默认在 pod 123456-7890 的第一个容器中运行 date 并获取输出
$ kubectl exec 123456-7890 date

# 在 pod 123456-7890 的容器 ruby-container 中运行 date 并获取输出
$ kubectl exec 123456-7890 -c ruby-container date

# 切换到终端模式，将控制台输入发送到 pod 123456-7890 的 ruby-container 的 bash 命令，并将其输出到控制台
# 错误控制台的信息发送回客户端。
$ kubectl exec 123456-7890 -c ruby-container -it -- bash -il

$ kubectl exec -it kubernetes-vault-bcg9x -n core -- sh -c 'more /kube*/kubernetes-vault.yml|grep token'
```

### explain

资源文档。

```sh
kubectl explain RESOURCE
```

#### 示例

```sh
# 获取资源及其字段的文档
kubectl explain pods

# 获取资源及其指定字段的文档
kubectl explain pods.spec.containers
```

### expose

将 replication controller, service, deployment 或 pod 作为新的 Kubernetes service 开放出去。

指定 deployment、service、replica set、replication controller 或 pod ，并使用该资源的选择器作为指定端口上新服务的选择器。
deployment 或 replica set 只有当其选择器可转换为 service 支持的选择器时，即当选择器仅包含 matchLabels 组件时才会作为暴露新的 Service。

```sh
kubectl expose (-f FILENAME | TYPE NAME) \
[--port=port] \
[--protocol=TCP|UDP] \
[--target-port=number-or-name] \
[--name=name] \
[--external-ip=external-ip-of-service] \
[--type=type]
```

#### 示例

```sh
# 为 RC 的 nginx 创建 service，并通过 Service 的 80 端口转发至容器的 8000 端口上。。
kubectl expose rc nginx --port=80 --target-port=8000

#  使用 "nginx-controller.yaml" 中指定的类型和名称标识为 replication controller 创建一个服务。并通过 Service 的 80 端口转发至容器的 8000端口上。
kubectl expose -f nginx-controller.yaml --port=80 --target-port=8000
```

### get

获取列出一个或多个资源的信息。

可以使用的资源包括：

- all
- certificatesigningrequests (aka 'csr')
- clusterrolebindings
- clusterroles
- clusters (valid only for federation apiservers)
- componentstatuses (aka 'cs')
- configmaps (aka 'cm')
- controllerrevisions
- cronjobs
- daemonsets (aka 'ds')
- deployments (aka 'deploy')
- endpoints (aka 'ep')
- events (aka 'ev')
- horizontalpodautoscalers (aka 'hpa')
- ingresses (aka 'ing')
- jobs
- limitranges (aka 'limits')
- namespaces (aka 'ns')
- networkpolicies (aka 'netpol')
- nodes (aka 'no')
- persistentvolumeclaims (aka 'pvc')
- persistentvolumes (aka 'pv')
- poddisruptionbudgets (aka 'pdb')
- podpreset
- pods (aka 'po')
- podsecuritypolicies (aka 'psp')
- podtemplates
- replicasets (aka 'rs')
- replicationcontrollers (aka 'rc')
- resourcequotas (aka 'quota')
- rolebindings
- roles
- secrets
- serviceaccounts (aka 'sa')
- services (aka 'svc')
- statefulsets
- storageclasses
- thirdpartyresources

```sh
kubectl get \
[(-o|--output=)json|yaml|wide|custom-columns=...|custom-columns-file=...|go-template=...|go-template-file=...|jsonpath=...|jsonpath-file=...] \
(TYPE [NAME | -l label] | TYPE/NAME ...) [flags]
```

#### 示例

```sh
# 列出 Pod 及运行 Pod 节点信息
kubectl get pods -o wide

# 以 JSON 格式输出一个 pod 信息
kubectl get -o json pod web-pod-13je7

# 以 pod.yaml 配置文件中指定资源对象和名称输出 JSON 格式的 Pod 信息
kubectl get -f pod.yaml -o json

# 返回指定 pod 的相位值
kubectl get -o template pod/web-pod-13je7 --template={{.status.phase}}

# 列出所有 replication controllers 和 service 信息
kubectl get rc,services

# 按其资源和名称列出相应信息
kubectl get rc/web service/frontend pods/web-pod-13je7

# 列出所有不同的资源对象
kubectl get all
```

### label

更新（增加、修改或删除）资源上的 label（标签）。

- label 必须以字母或数字开头，可以使用字母、数字、连字符、点和下划线，最长 63 个字符。
- 如果 `--overwrite` 为 `true`，则可以覆盖已有的 label，否则尝试覆盖 label 将会报错。
- 如果指定了 `--resource-version`，则更新将使用此资源版本，否则将使用现有的资源版本。

```sh
kubectl label [--overwrite] (-f FILENAME | TYPE NAME) KEY_1=VAL_1 ... KEY_N=VAL_N [--resource-version=version]
```

#### 示例

```sh
# 给名为 foo 的 Pod 添加 label unhealthy=true ，且覆盖现有的 value
kubectl label  --overwrite pods foo unhealthy=true

# 给 namespace 中的所有 pod 添加 label
kubectl label pods --all unhealthy=true

# 仅当 resource-version=1 时才更新 名为 foo 的 Pod 上的 label。
kubectl label pods foo status=unhealthy --resource-version=1

# 删除名为 bar 的 label （使用 "-" 减号相连）
kubectl label pods foo bar-
```

### logs

输出 pod 中一个容器的日志。果 pod 只包含一个容器则可以省略容器名。

```sh
kubectl logs [-f] [-p] POD [-c CONTAINER]

# 选项
-c, --container="": 容器名。
-f, --follow[=false]: 指定是否持续输出日志。
  --interactive[=true]: 如果为 true，当需要时提示用户进行输入。默认为 true。
  --limit-bytes=0: 输出日志的最大字节数。默认无限制。
-p, --previous[=false]: 如果为 true，输出 pod 中曾经运行过，但目前已终止的容器的日志。
  --since=0: 仅返回相对时间范围，如 5s、2m 或 3h，之内的日志。默认返回所有日志。只能同时使用 since 和 since-time 中的一种。
  --since-time="": 仅返回指定时间（RFC3339格式）之后的日志。默认返回所有日志。只能同时使用 since 和 since-time 中的一种。
  --tail=-1: 要显示的最新的日志条数。默认为 -1，显示所有的日志。
  --timestamps[=false]: 在日志中包含时间戳。
```

#### 示例

```sh
# 返回仅包含一个容器的 pod nginx 的日志快照
$ kubectl logs nginx

# 返回 pod ruby 中已经停止的容器 web-1 的日志快照
$ kubectl logs -p -c ruby web-1

# 持续输出 pod ruby 中的容器 web-1 的日志
$ kubectl logs -f -c ruby web-1

# 仅输出 pod nginx 中最近的 20 条日志
$ kubectl logs --tail=20 nginx

# 输出 pod nginx 中最近一小时内产生的所有日志
$ kubectl logs --since=1h nginx
```

### patch

使用（patch）补丁修改、更新资源的字段。支持 JSON 和 YAML 格式。

```sh
kubectl patch (-f FILENAME | TYPE NAME) -p PATCH
```

#### 示例

```sh
# 使用 patch 更新 Node 节点
kubectl patch node k8s-node-1 -p '{"spec":{"unschedulable":true}}'

# 使用 patch 更新由 node.json 文件中指定的类型和名称标识的节点
kubectl patch -f node.json -p '{"spec":{"unschedulable":true}}'

# 更新容器的镜像
kubectl patch pod valid-pod -p '{"spec":{"containers":[{"name":"kubernetes-serve-hostname","image":"new image"}]}}'

kubectl patch pod valid-pod --type='json' -p='[{"op": "replace", "path": "/spec/containers/0/image", "value":"new image"}]'
```

### port-forward

将一个或多个本地端口转发到一个 pod。

```sh
kubectl port-forward POD [LOCAL_PORT:]REMOTE_PORT [...[LOCAL_PORT_N:]REMOTE_PORT_N]
```

#### 示例

```sh
# 将本地的 5000，6000 端口转发到 pod mypod 中的 5000，6000
kubectl port-forward mypod 5000 6000

# 将本地的 8888 端口转发到 pod mypod 中的 5000
kubectl port-forward mypod 8888:5000

# 将本地的一个随机端口转发到 pod mypod 中的 5000
kubectl port-forward mypod :5000

# 将本地的一个随机端口转发到 pod mypod 中的 5000
kubectl port-forward  mypod 0:5000
```

### proxy

为 Kubernetes API server 启动代理服务器。

```sh
kubectl proxy [--port=PORT] [--www=static-dir] [--www-prefix=prefix] [--api-prefix=prefix]
```

#### 示例

```sh
# 在8011端口上运行到 kubernetes apiserver 的代理, 代理 ./local/www/ 目录下的静态文件
kubectl proxy --port=8011 --www=./local/www/

# 在任意本地端口上运行到 kubernetes apiserver 的代理，服务器选择的端口将输出到 stdout。
kubectl proxy --port=0

# 要代理所有 kubernetes api
kubectl proxy –api-prefix=/

# 只代理部分 kubernetes api 和一些静态文件
kubectl proxy –www=/my/files –www-prefix=/static/ –api-prefix=/api/

# 在不同的根上代理整个 kubernetes api，改变 api 前缀为 /custom/，使用 "curl localhost:8001/custom/api/v1/pods"
kubectl proxy –api-prefix=/custom/
```

### replace

使用配置文件或 stdin 来替换资源。

支持 JSON 和 YAML 格式。如果替换当前资源，则必须提供完整的资源规范。可以通过命令 `kubectl get TYPE NAME -o yaml` 获取。

```sh
kubectl replace -f FILENAME
```

#### 示例

```sh
# 使用 pod.json 中的数据替换 pod
kubectl replace -f ./pod.json

# 根据传入的 JSON 替换 pod
cat pod.json | kubectl replace -f -

# 更新镜像版本(tag) 到 v4
kubectl get pod mypod -o yaml | sed 's/\(image: myimage\):.*$/\1:v4/' | kubectl replace -f -

# 强制替换，删除原有资源，然后重新创建资源
kubectl replace --force -f ./pod.json
```

### rolling-update

执行指定 ReplicationController 的滚动更新。

该命令创建了一个新的 RC， 然后一次更新一个 pod 方式逐步使用新的 `PodTemplate`，最终实现 Pod 滚动更新，`new-controller.json` 需要
与之前 RC 在相同的 namespace 下。

```sh
kubectl rolling-update OLD_CONTROLLER_NAME ([NEW_CONTROLLER_NAME] --image=NEW_CONTAINER_IMAGE | -f NEW_CONTROLLER_SPEC)
```

#### 示例

```sh
# 使用 frontend-v2.json 中的新 RC 数据更新 frontend-v1 的 pod
kubectl rolling-update frontend-v1 -f frontend-v2.json

# 使用 JSON 数据更新 frontend-v1 的 pod
cat frontend-v2.json | kubectl rolling-update frontend-v1 -f -

kubectl rolling-update frontend-v1 frontend-v2 --image=image:v2

kubectl rolling-update frontend --image=image:v2

kubectl rolling-update frontend-v1 frontend-v2 --rollback
```

### rollout

对资源进行管理

可用资源包括：

- deployments
- daemonsets

```sh
kubectl rollout SUBCOMMAND
```

#### kubectl rollout history

查看之前推出的版本（历史版本）。

```sh
kubectl rollout history (TYPE NAME | TYPE/NAME) [flags]
```

##### 示例

```sh
# 查看 deployment 的历史记录
kubectl rollout history deployment/abc

# 查看 daemonset 修订版 3 的详细信息
kubectl rollout history daemonset/abc --revision=3
```

#### kubectl rollout pause

将提供的资源标记为暂停。

被 `pause` 命令暂停的资源不会被控制器协调使用，可以是 `kubectl rollout resume` 命令恢复已暂停资源。

目前仅支持的资源：deployments。

```sh
kubectl rollout pause RESOURCE
```

##### 示例

```sh
# 将 deployment 标记为暂停。只要 deployment 在暂停中，使用 deployment 更新将不会生效
kubectl rollout pause deployment/nginx
```

#### kubectl rollout resume

恢复已暂停的资源

被 `pause` 命令暂停的资源将不会被控制器协调使用。可以通过 `resume` 来恢复资源。目前仅支持恢复 deployment 资源。

```sh
kubectl rollout resume RESOURCE
```

##### 示例

```sh
# 恢复已暂停的 deployment
kubectl rollout resume deployment/nginx
```

#### kubectl rollout status

查看资源的状态。

使用 `--watch=false` 来查看当前状态，需要查看特定修订版本状态，使用 `--revision=N` 来指定。

```sh
kubectl rollout status (TYPE NAME | TYPE/NAME) [flags]
```

##### 示例

```sh
# 查看 deployment 的状态
kubectl rollout status deployment/nginx
```

#### kubectl rollout undo

回滚到之前的版本。

```sh
kubectl rollout undo (TYPE NAME | TYPE/NAME) [flags]
```

##### 示例

```sh
# 回滚到之前的 deployment 版本
kubectl rollout undo deployment/abc

kubectl rollout undo --dry-run=true deployment/abc

# 回滚到 daemonset 修订 3 版本
kubectl rollout undo daemonset/abc --to-revision=3
```

### run

创建并运行一个指定的可复制的镜像。创建一个 deployment 或者 job 来管理创建的容器。

```sh
kubectl run NAME --image=image \
[--env="key=value"] \
[--port=port] \
[--replicas=replicas] \
[--dry-run=bool] \
[--overrides=inline-json] \
[--command] -- [COMMAND] [args...]

# 选项
--image="": 用来运行的容器镜像。
--attach[=false]: 如果为 true, 那么等 pod 开始运行之后，链接到这个 pod 和运行 'kubectl attach ...'一样。默认是 false，除非设置了 '-i/--interactive' 默认才会是 true。
--command[=false]: 如果为 true 并且有其他参数，那么在容器中运行这个 'command'，而不是默认的 'args'。
--dry-run[=false]: 如果为 true，则仅仅打印这个对象，而不会执行命令。
--env=[]: 设置容器的环境变量。
--expose[=false]: 如果为 true， 会为这个运行的容器创建一个公开的 service。
--hostport=-1: 容器端口的主机端口映射。演示一个单机容器
-l, --labels="": pod 的标签。
--port=-1: 容器开放的端口。如果 `--expose` 为 true，则创建的服务也使用这个端口。
-r, --replicas=1: 为该容器创建的副本数量。默认值为 1。
--restart="Always": pod 的重启策略。有效的值包括  [Always, OnFailure, Never]。默认值是 "Always"。
--rm[=false]: 如果为 true, 删除在此命令中为附加容器创建的资源.
-i, --stdin[=false]: 将控制台输入发送到容器。
-t, --tty[=false]: 将标准输入控制台作为容器的控制台输入。
```

#### 示例

```sh
# 启动一个 Nginx 实例。
kubectl run nginx --image=nginx

# 启动一个 hazelcast 单个实例，并开放容器的5701端口。
kubectl run hazelcast --image=hazelcast --port=5701

# 运行一个 hazelcast 单个实例，并设置容器的环境变量 "DNS_DOMAIN=cluster" 和 "POD_NAMESPACE=default"。
kubectl run hazelcast --image=hazelcast --env="DNS_DOMAIN=cluster" --env="POD_NAMESPACE=default"

# 启动一个 replicated 实例去复制 nginx。
kubectl run nginx --image=nginx --replicas=5

# 试运行。不创建他们的情况下，打印出所有相关的 API 对象。
kubectl run nginx --image=nginx --dry-run

# 用可解析的 JSON 来覆盖加载 `deployment` 的 `spec`，来运行一个 nginx 单个实例。
kubectl run nginx --image=nginx --overrides='{ "apiVersion": "v1", "spec": { ... } }'

# 运行一个在前台运行的 busybox 单个实例，如果退出不会重启。
kubectl run -i --tty busybox --image=busybox --restart=Never

# 使用默认命令来启动 nginx 容器，并且传递自定义参数(arg1 .. argN)给 nginx。
kubectl run nginx --image=nginx -- <arg1> <arg2> ... <argN>

# 使用不同命令或者自定义参数来启动 nginx 容器。
kubectl run nginx --image=nginx --command -- <cmd> <arg1> ... <argN>

# 启动 perl 容器来计算 bpi(2000) 并打印出结果。
kubectl run pi --image=perl --restart=OnFailure -- perl -Mbignum=bpi -wle 'print bpi(2000)'
```

### scale

扩容或缩容 Deployment、ReplicaSet、Replication Controller 或 Job 中 Pod 数量。

`scale` 也可以指定多个前提条件，如：当前副本数量或 `--resource-version`，进行伸缩比例设置前，系统会先验证前提条件是否成立。

```sh
kubectl scale [--resource-version=version] [--current-replicas=count] --replicas=COUNT (-f FILENAME | TYPE NAME)
```

#### 示例

```sh
# 将名为 foo 的 pod 副本数设置为 3
kubectl scale --replicas=3 rs/foo

# 将由 foo.yaml 配置文件中指定的资源对象和名称标识的 Pod 资源副本设为 3
kubectl scale --replicas=3 -f foo.yaml

# 如果当前副本数为 2，则将其扩展至 3
kubectl scale --current-replicas=2 --replicas=3 deployment/mysql

# 设置多个 RC 中 Pod 副本数量
kubectl scale --replicas=5 rc/foo rc/bar rc/baz
```

### uncordon

将节点标记为可调度。

```sh
kubectl uncordon NODE
```

### version

输出服务端和客户端的版本信息。

```sh
kubectl version

# 选项
-c, --client[=false]: 仅输出客户端版本（无需连接服务器）。
```
