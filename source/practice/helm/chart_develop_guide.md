# Chart 模版开发者指南

该指南提供 Helm Chart 模板的介绍，重点强调模板语言。

模板会生成 manifest 文件，使用 Kubernetes 可以识别的 YAML 格式描述。我们会看到模板是如何结构化的， 它们如何被使用，如何编写 Go 模板，以及如何调试。

该指南聚焦于以下概念：

- Helm 模板语言
- 使用 values
- 使用模板工作的技术点

该指南面向学习 Helm 模板语言的来龙去脉。其他指南提供介绍性资料，示例和最佳实践。

## 入门

在本节指南中，我们将创建一个 chart，然后添加第一个模板。我们在这里创建的 chart将在本指南的其余部分使用。

我们来简单看一下 Helm chart。

### Charts

Charts 指南中描述一个 Helm chart 的结构想这样：

```bash
mychart/
  Chart.yaml
  values.yaml
  charts/
  templates/
  ...
```

`templates/` 目录用于放置模板文件。当 Helm 渲染 charts 时，它会通过模版引擎传递目录中的每一个文件。然后它收集这些模板的结果，并将它们发送到 Kubernetes。

`values.yaml` 文件对模板也很重要。该文件包含了 chart 的默认值。这些值可以在用户在 `helm install` 或 `helm upgrade` 期间被覆盖。

`Chart.yaml` 文件包含 chart 的描述。可以从模板中访问它。`charts/` 目录可能包含其他 chart（称之为子 chart）。在本指南的后面，我们将看到它们在模板渲染方面如何起作用。

### 初始 chart

对于本指南，我们将创建一个名为 `mychart` 的简单的 chart，然后我们将在 chart 内部创建一些模板。

```bash
$ helm create mychart
Creating mychart
```

#### 快速看一下目录 `mychart/templates/`

查看 `mychart/templates/` 目录，你会发现已经存在一些文件。

- `NOTES.txt`: chart 的帮助文本。这会在用户运行 `helm install` 时展示给用户。
- `deployment.yaml`: 创建 deployment 的基本 manifest。
- `service.yaml`: 为 deployment 创建 [service endpoint](https://kubernetes.io/docs/user-guide/services/) 的基本 manifest。
- `_helpers.tpl`: 放置模板助手的地方，可以在整个 chart 中重复使用。

而我们要做的就是 ... 全部删除它们！这样我们就可以从头开始学习我们的教程。实际上，我们将创建自己的 `NOTES.tx`t 和 `_helpers.tpl`。

```bash
rm -rf mychart/templates/*
```

在编写生产级 chart 时，这些 chart 的基本版本是非常有用的。所以在你的日常 chart 制作中，可以不删除它们。

### 第一个模版

我们的第一个模版会创建一个 `ConfigMap`。在 Kubernetes 中 `ConfigMap` 只是一个存储配置数据的地方。其他像 pod 可以访问 ConfigMap 中的数据。

因为 ConfigMap 是基础资源，它们为我们提供了一个很好的起点。

从创建 `mychart/templates/configmap.yaml` 这个文件开始：

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mychart-configmap
data:
  myvalue: "Hello World"
```

提示：模板的命名不需要遵循严格的命名模式。但是，我们建议 `.yaml` 为 YAML 文件后缀，`.tpl` 为模板助手后缀。

上面的 YAML 文件是一个基本的 ConfigMap，只有最少的必要的字段。由于该文件位于 `mychart/templates/` 目录中，因此将通过模板引擎发送。

在 `templates/` 目录中放置一个像这样的普通 YAML 文件就可以了。当 Helm 读取这个模板时，它会直接发送给 Kubernetes。

有了这个简单的模板，我们现在有一个可安装的 chart。我们可以像这样安装它：

```bash
$ helm install full-coral ./mychart
NAME: full-coral
LAST DEPLOYED: Tue Nov  1 17:36:01 2016
NAMESPACE: default
STATUS: DEPLOYED
REVISION: 1
TEST SUITE: None
```

使用 Helm，我们可以检索版本并查看加载的实际模板。

```bash
$ helm get manifest full-coral

---
# Source: mychart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mychart-configmap
data:
  myvalue: "Hello World"
```

`helm get manifest` 命令获取 release 名称（full-coral），并且打印了所有上传到服务器的 Kubernetes 资源。每个文件以 `---` 开头表示一个 YAML 文档的开始。然后是一个自动生成的注释行，告诉我们该模板文件生成的这个 YAML 文档。

从那里开始，我们可以看到 YAML 数据正是我们放在 `configmap.yaml` 文件中的。

现在我们可以卸载我们的 release：`helm uninstall full-coral`。

#### 添加一个简单的模版调用

硬编码 `name:` 在一个资源中通常被认为是不好的做法。Names 对于一个 release 应该是唯一的。所以我们可能希望通过插入 release 名称来生成一个 name 字段。

提示：`name:` 由于 DNS 系统的限制，该字段限制为 63 个字符。因此，release 名称限制为 53 个字符。Kubernetes 1.3 及更早版本仅限于 24 个字符（即 14 个字符 name）。

相应的修改 `configmap.yaml`：

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{.Release.Name}}-configmap
data:
  myvalue: "Hello World"
```

`name:` 这个字段值变成了 `{{.Release.Name}}-configmap`。

> 模板指令包含在 `{{` 和 `}}` 块中。

模版指令 `{{ .Release.Name }}` 将 release name 注入到了模版中。传递给模板的值可以认为是 namespace 对象，其中 `.` 分隔每个 namespace 元素。

Release 前面的前一个 `.` 表示我们从这个范围的最上面的 namespace 开始。所以我们可以这样理解 `.Release.Name` 是 "从顶层命名空间开始，找到 `Release` 对象，然后在里面查找名为 `Name` 的对象"。

`Release` 对象是 Helm 的内置对象之一，稍后我们将更深入地讨论它。但现在，只需说这会显示 library 分配给我们的 release 的 release name 即可。

现在当我们安装 release 时，我们会立即看到使用模版指令的结果：

```bash
$ helm install clunky-serval ./mychart
NAME: clunky-serval
LAST DEPLOYED: Tue Nov  1 17:45:37 2016
NAMESPACE: default
STATUS: DEPLOYED
REVISION: 1
TEST SUITE: None
```

可以运行 `helm get manifest clunky-serval` 来查看生成的完整的 YAML。

注意 ConfigMap 在 Kubernetes 中名字从之前 `mychart-configmap` 变成了 `clunky-serval-configmap`。

至此，我们已经看到了模板最基本的部分: 在 YAML 文件中嵌入了 `{{` 和 `}}` 中的模板指令。在下一部分中，我们将深入研究模板。但在继续之前，有一个小技巧可以使构建模板更快：当您想测试模板渲染，但实际上不想安装任何东西时，可以使用 `helm install --debug --dry-run ./mychart`。它将渲染模板。但不是安装 chart，它会将渲染模板返回，以便可以看到输出：

```bash
$ helm install --debug --dry-run goodly-guppy ./mychart
install.go:149: [debug] Original chart version: ""
install.go:166: [debug] CHART PATH: /Users/ninja/mychart

NAME: goodly-guppy
LAST DEPLOYED: Thu Dec 26 17:24:13 2019
NAMESPACE: default
STATUS: pending-install
REVISION: 1
TEST SUITE: None
USER-SUPPLIED VALUES:
{}

COMPUTED VALUES:
affinity: {}
fullnameOverride: ""
image:
  pullPolicy: IfNotPresent
  repository: nginx
imagePullSecrets: []
ingress:
  annotations: {}
  enabled: false
  hosts:
  - host: chart-example.local
    paths: []
  tls: []
nameOverride: ""
nodeSelector: {}
podSecurityContext: {}
replicaCount: 1
resources: {}
securityContext: {}
service:
  port: 80
  type: ClusterIP
serviceAccount:
  create: true
  name: null
tolerations: []

HOOKS:
MANIFEST:
---
# Source: mychart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: goodly-guppy-configmap
data:
  myvalue: "Hello World"
```

使用 `--dry-run` 可以更容易地测试你的代码，但不能确保 Kubernetes 本身会接受生成的模板。不要因为 `--dry-run` 成功就假定你的 chart 可以安装。
