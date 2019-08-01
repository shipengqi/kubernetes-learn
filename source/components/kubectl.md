---
title: kubectl
---

# kubectl

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
- [kubectl cordon](#cordon) – TODO。
- [kubectl create](#create) – 通过文件名或控制台输入，创建资源。
- [kubectl delete](#delete) – 通过文件名、控制台输入、资源名或者 label selector 删除资源。
- [kubectl describe](#describe) – 输出指定的一个/多个资源的详细信息。
- [kubectl drain](#drain) – TODO。
- [kubectl edit](#edit) – 编辑服务端的资源。
- [kubectl exec](#exec) – 在容器内部执行命令。
- [kubectl explain](#explain) – TODO。
- [kubectl expose](#expose) – 输入 replication controller，service 或者 pod，并将其暴露为新的 kubernetes service。
- [kubectl get](#get) – 输出一个/多个资源。
- [kubectl label](#label) – 更新资源的 label。
- [kubectl logs](#logs) – 输出 pod 中一个容器的日志。
- [kubectl patch](#patch) – 通过控制台输入更新资源中的字段。
- [kubectl port-forward](#port-forward) – 将本地端口转发到 Pod。
- [kubectl proxy](#proxy) – 为 Kubernetes API server 启动代理服务器。
- [kubectl replace](#replace) – 通过文件名或控制台输入替换资源。
- [kubectl rolling-update](#rolling-update) – 对指定的 replication controller 执行滚动升级。
- [kubectl rollout](#rollout) – TODO。
- [kubectl run](#run) – 在集群中使用指定镜像启动容器。
- [kubectl scale](#scale) – 为 replication controller 设置新的副本数。
- [kubectl uncordon](#uncordon) – TODO。
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

#### 示例
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
$ autoscale (-f FILENAME | TYPE NAME | TYPE/NAME) [--min=MINPODS] --max=MAXPODS [--cpu-percent=CPU] [flags]
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

示例：
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

示例：
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

示例：
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

示例：
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

示例：
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

示例：
```sh
# 将 pod.yaml 转换为最新版本
$ kubectl convert -f pod.yaml

# 将 pod.yaml 指定的资源的实时状态转换为最新版本，并以 json 格式打印到 stdout。
$ kubectl convert -f pod.yaml --local -o json

# 将当前目录下的所有文件转换为最新版本，并将其全部创建。
$ kubectl convert -f . | kubectl create -f -
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

示例：
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

示例：
```sh
# 创建一个名叫 my-namespace 的 namespace
$ kubectl create namespace my-namespace
```

#### kubectl create deployment
创建具有指定名称的 deployment。
```sh
kubectl create deployment NAME --image=image [--dry-run]
```

示例：
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

示例：
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

示例：
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

示例：
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

### edit
### exec
### expose
### get
### label
### logs
### patch
### port-forward
### proxy
### replace
### rolling-update
### run
### scale
扩容或缩容 Deployment、ReplicaSet、Replication Controller 或 Job 中 Pod 数量。

### version
输出服务端和客户端的版本信息。
```sh
kubectl version

# 选项
-c, --client[=false]: 仅输出客户端版本（无需连接服务器）。
```
