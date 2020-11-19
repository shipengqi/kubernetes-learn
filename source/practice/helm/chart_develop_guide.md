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

## 内置对象

对象从模板引擎传递到模板中。你的代码可以传递对象（我们将在说明 `with` 和 `range` 语句时看到示例）。有几种方法在模板中创建新对象，就像我们稍后会看的 `tuple` 函数一样。

对象可以是简单的，只有一个值。或者它们可以包含其他对象或函数。例如 `Release` 对象包含多个对象（如 `Release.Name`）和 `File` 对象包含了一些函数。

在上一节中，我们使用 `{{.Release.Name}}` 将 release 的名称插入到模板中。`Release` 是可以在你的模板中访问的顶级对象之一。

- `Release`: 这个对象描述了 release 本身。它里面有几个对象：
  - `Release.Name`: release 名称
  - `Release.Namespace`: release 所在的 namespace (如果没有被覆盖)
  - `Release.IsUpgrade`: 如果当前操作是 upgrade 或者 rollback，则为 `true`。
  - `Release.IsInstall`: 如果当前操作是 install，则为 `true`。
  - `Release.Revision`: 此 release 的修订版本号。它从 1 开始，每次 upgrade 或者 rollback 则增加 1。
  - `Release.Service`: 正在渲染当前模板的服务。在 Helm 上，这总是 `Helm`。
- `Values`: 从 `values.yaml` 文件和用户提供的文件传入模板的值。`Values` 默认是空的。
- `Chart`: `Chart.yaml` 的内容。 `Chart.yaml` 中的所有数据都是可访问的。例如 `{{ .Chart.Name }}-{{ .Chart.Version }}` 会打印出 `mychart-0.1.0`。[Charts Guide](https://helm.sh/docs/topics/charts/#the-chartyaml-file) 列出了所有可用的字段。
- `Files`: 提供对 chart 中所有非特殊文件的访问。虽然无法使用它来访问模板，但可以使用它来访问 chart 中的其他文件。参考 "访问文件" 部分。
  - `Files.Get` 是一个按名称获取文件的函数 (`.Files.Get config.ini`)
  - `Files.GetBytes` 是将文件内容作为字节数组而不是字符串获取的函数。
  - `Files.Glob` 是一个返回与 shell glob 模式匹配的文件列表的函数。
  - `Files.Lines` 是一个逐行读取文件的函数。这对于迭代文件中的每一行非常有用。
  - `Files.AsSecrets` 是一个以 Base 64 编码字符串返回文件体的函数。
  - `Files.AsConfig` 是一个以 YAML 映射形式返回文件体的函数。
- `Capabilities`: 这提供了关于 Kubernetes 集群支持的功能的信息。
  - `Capabilities.APIVersions` 是一组版本信息。
  - `Capabilities.APIVersions.Has $version` 表示一个版本 (如 `batch/v1`) 或者资源（如 `apps/v1/Deployment`）在集群中是否可用。
  - `Capabilities.KubeVersion` 和 `Capabilities.KubeVersion.Version` 是 Kubernetes 的版本。
  - `Capabilities.KubeVersion.Major` 是 Kubernetes 的主版本号。
  - `Capabilities.KubeVersion.Minor` 是 Kubernetes 的次版本号。
- `Template`: 包含有关当前正在执行的模板信息
  - `Template.Name`: 当前模板的命名空间文件路径（如 `mychart/templates/mytemplate.yaml`）。
  - `Template.BasePath`: 当前 chart 的模板目录的命名空间路径（如 `mychart/templates`）。

内建的 values 总是以大写字母开头。这延续了 Go 的命名约定。当你创建自己的名字时，你可以自由地使用适合你的团队的惯例。一些团队，如 Kubernetes chart 团队，选择仅使用首字母小写字母来区分本地名称与内置名称。在本指南中，我们遵循该约定。

## Values 文件

上一节中，了解了 Helm 模版的内置对象。`Values` 是四个内置对象之一。这个对象可以访问传入到 chart 的值。内容的多个来源：

- chart 中的 `values.yaml` 文件
- 如果是一个子 chart， 父 chart 的 `values.yaml` 文件
- 通过 `helm install` 或者 `helm upgrade` 命令参数 `-f` 传入 balues 文件。(`helm install -f myvals.yaml ./mychart`)
- 通过 `--set` 参数指定的值 (如 `helm install --set foo=bar ./mychart`)

上面的列表的按照指定的顺序：`values.yaml` 是默认的，可以被父 chart 的 `values.yaml` 覆盖，它们又可以被用户提供的 values 文件覆盖，而这些又可以被 `--set` 参数指定的值覆盖。

Values 文件是普通的 YAML 文件。编辑 `mychart/values.yaml`，然后来编辑我们的 ConfigMap 模板。

删除默认的 `values.yaml`，我们只设置一个参数：

```yml
favoriteDrink: coffee
```

现在我们可以在模板中使用这个：

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
  myvalue: "Hello World"
  drink: {{ .Values.favoriteDrink }}
```

注意我们在最后一行通过 `{{ .Values.favoriteDrink}}` 获取 `favoriteDrink` 字段的值。

看看这是如何渲染的：

```bash
$ helm install geared-marsupi ./mychart --dry-run --debug
install.go:158: [debug] Original chart version: ""
install.go:175: [debug] CHART PATH: /home/bagratte/src/playground/mychart

NAME: geared-marsupi
LAST DEPLOYED: Wed Feb 19 23:21:13 2020
NAMESPACE: default
STATUS: pending-install
REVISION: 1
TEST SUITE: None
USER-SUPPLIED VALUES:
{}

COMPUTED VALUES:
favoriteDrink: coffee

HOOKS:
MANIFEST:
---
# Source: mychart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: good-puppy-configmap
data:
  myvalue: "Hello World"
  drink: coffee
```

由于 `favoriteDrink` 在默认 `values.yaml` 文件中设置为 `coffee`，这就是模板中显示的值。我们可以轻松地在 `helm install` 命令中通过加一个 `--set` 添标志来覆盖：

```bash
$ helm install solid-vulture ./mychart --dry-run --debug --set favoriteDrink=slurm
install.go:158: [debug] Original chart version: ""
install.go:175: [debug] CHART PATH: /home/bagratte/src/playground/mychart

NAME: solid-vulture
LAST DEPLOYED: Wed Feb 19 23:25:54 2020
NAMESPACE: default
STATUS: pending-install
REVISION: 1
TEST SUITE: None
USER-SUPPLIED VALUES:
favoriteDrink: slurm

COMPUTED VALUES:
favoriteDrink: slurm

HOOKS:
MANIFEST:
---
# Source: mychart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: good-puppy-configmap
data:
  myvalue: "Hello World"
  drink: slurm
```

由于 `--set` 的优先级比默认 `values.yaml` 文件更高，所以模板生成 `drink: slurm`。

values 文件也可以包含更多结构化内容。例如，我们在 `values.yaml` 文件中创建 `favorite` 部分，然后在其中添加几个键：

```yml
favorite:
  drink: coffee
  food: pizza
```

现在我们稍微修改模板：

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
  myvalue: "Hello World"
  drink: {{ .Values.favorite.drink }}
  food: {{ .Values.favorite.food }}
```

虽然以这种方式构建数据是可以的，但建议保持 value 树浅一些，平一些。当我们看看为子 chart 分配值时，我们将看到如何使用树结构来命名值。

### 删除一个默认的 key

如果需要从默认值中删除一个键，可以覆盖该键的值为 `null`，在这种情况下，Helm 将在覆盖合并中删除该键。

例如，stable 版本的 Drupal chart 允许配置 liveness probe，如果配置了自定义的 image。以下是默认值：

```yml
livenessProbe:
  httpGet:
    path: /user/login
    port: http
  initialDelaySeconds: 120
```

如果你尝试使用 `--set livenessProbe.exec.command=[cat,docroot/CHANGELOG.txt]` 覆盖 liveness Probe 处理程序用 `exec` 替代 `httpGet`，Helm 会将默认和重写的键合并在一起，产生以下 YAML：

```yml
livenessProbe:
  httpGet:
    path: /user/login
    port: http
  exec:
    command:
    - cat
    - docroot/CHANGELOG.txt
  initialDelaySeconds: 120
```

然而，Kubernetes 会失败，因为不能声明多于一个的 livenessProbe 处理程序。为了解决这个问题，可以指示 Helm 过将 `livenessProbe.httpGe`t 通设置为 `null` 来删除它：

```bash
helm install stable/drupal --set image=my-registry/drupal:0.1.0 --set livenessProbe.exec.command=[cat,docroot/CHANGELOG.txt] --set livenessProbe.httpGet=null
```

## 函数和管道

目前为止，我们已经知道如何将信息放入模板中。但是这些信息未经修改就被放入模板中。有时我们想要转换这些数据，使得他们对我们来说更有用。

从一个最佳实践开始：当从 `.Values` 对象注入字符串到模板中时，我们引用这些字符串。我们可以通过调用 `quote` 模板指令中的函数来实现：

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
  myvalue: "Hello World"
  drink: {{ quote .Values.favorite.drink }}
  food: {{ quote .Values.favorite.food }}
```

模板函数遵循语法 `functionName arg1 arg2...` 。在上面的代码片段中，`quote .Values.favorite.drink` 调用 `quote` 函数并将一个参数传递给它。

Helm 拥有超过 60 种可用函数。其中一些是由 [Go template language](https://godoc.org/text/template) 本身定义的。其他大多数都是 [Sprig template library](https://godoc.org/github.com/Masterminds/sprig) 的一部分。在我们讲解例子进行的过程中，我们会看到很多。

### 管道

模板语言的强大功能之一是其管道概念。利用 UNIX 的一个概念，管道是一个链接在一起的一系列模板命令的工具，以紧凑地表达一系列转换。换句话说，管道是按顺序完成几件事情的有效方式。我们用管道重写上面的例子。

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
  myvalue: "Hello World"
  drink: {{ .Values.favorite.drink | quote }}
  food: {{ .Values.favorite.food | quote }}
```

在这个例子中，没有调用 `quote ARGUMENT`，我们调换了顺序。我们使用管道 `|` 将 “参数” 发送给函数：`.Values.favorite.drink | quote`。使用管道，我们可以将几个功能链接在一起：

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
  myvalue: "Hello World"
  drink: {{ .Values.favorite.drink | quote }}
  food: {{ .Values.favorite.food | upper | quote }}
```

当评估时，该模板将产生如下结果：

```yml
# Source: mychart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: trendsetting-p-configmap
data:
  myvalue: "Hello World"
  drink: "coffee"
  food: "PIZZA"
```

注意，原来的 `pizza` 已经转换为 `PIZZA`。

当有像这样管道参数时，第一个评估（`.Values.favorite.drink`）的结果将作为函数的最后一个参数发送。我们可以修改上面的 drink 示例来说明一个带有两个参数的函数 `repeat COUNT STRING`：

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
  myvalue: "Hello World"
  drink: {{ .Values.favorite.drink | repeat 5 | quote }}
  food: {{ .Values.favorite.food | upper | quote }}
```

`repeat` 函数将给定的字符串进行给定的次数 echo，所以我们将得到这个输出：

```yml
# Source: mychart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: melting-porcup-configmap
data:
  myvalue: "Hello World"
  drink: "coffeecoffeecoffeecoffeecoffee"
  food: "PIZZA"
```

### 使用 default 函数

模版中经常使用的一个函数是 `default`：`default DEFAULT_VALUE GIVEN_VALUE`。该功能允许在模板内部指定默认值，以防该值被省略。让我们用它来修改上面的 drink 示例：

```yml
drink: {{ .Values.favorite.drink | default "tea" | quote }}
```

如果我们像往常一样运行，我们会得到 `coffee`：

```yml
# Source: mychart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: virtuous-mink-configmap
data:
  myvalue: "Hello World"
  drink: "coffee"
  food: "PIZZA"
```

现在，我们在 `values.yaml` 中删除 `favorite.drink`：

```yml
favorite:
  #drink: coffee
  food: pizza
```

现在重新运行 `helm install --dry-run --debug fair-worm ./mychart` 会产生 YAML：

```yml
# Source: mychart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fair-worm-configmap
data:
  myvalue: "Hello World"
  drink: "tea"
  food: "PIZZA"
```

在实际的 chart 中，所有静态默认值应该存在于 `values.yaml` 中，不应该使用该 `default` 命令重复（否则它们将是重复多余的）。但是，`default` 命令对于计算的值是合适的，因为计算值不能在 `values.yaml` 中声明。例如：

```yml
drink: {{ .Values.favorite.drink | default (printf "%s-tea" (include "fullname" .)) }}
```

在一些地方，一个 `if` 条件可能比这 `default` 更适合。我们将在下一节中看到这些。

### 使用 lookup 函数

lookup 函数可以用来查找正在运行的集群中的资源。lookup 函数概要是 `lookup apiVersion, kind, namespace, name -> resource or resource list`。

```bash
parameter     type
-------------------
apiVersion   string
kind         string
namespace    string
name         string
```

`name` 和 `namespace` 都是可选的，可以传递一个空字符串 (`""`)。

可采用以下参数组合：

```bash
Behavior                                             Lookup function
--------------------------------------------------------------------------------------
kubectl get pod mypod -n mynamespace           lookup "v1" "Pod" "mynamespace" "mypod"
kubectl get pods -n mynamespace                lookup "v1" "Pod" "mynamespace" ""
kubectl get pods --all-namespaces              lookup "v1" "Pod" "" ""
kubectl get namespace mynamespace              lookup "v1" "Namespace" "" "mynamespace"
kubectl get namespaces                         lookup "v1" "Namespace" "" ""
```

当 `lookup` 返回一个对象时，它将返回一个字典。这个字典可以被进一步浏览以提取特定的值。

下面的例子将返回 `mynamespace` 对象的 annotations。

```yml
(lookup "v1" "Namespace" "" "mynamespace").metadata.annotations
```

当 `lookup` 返回一个对象列表时，可以通过 `item` 字段访问列表对象：

```yml
{{ range $index, $service := (lookup "v1" "Service" "mynamespace" "").items }}
    {{/* do something with each service */}}
{{ end }}
```

没有找到对象时，返回一个空值。这可以用来检测对象是否存在。

`lookup` 函数使用当前 Helm 现有的 Kubernetes 连接配置来查询 Kubernetes。如果在与调用 API 服务器交互时返回任何错误（例如由于缺乏访问资源的权限）， helm 的模板处理将失败。

请记住，在 `helm template` 或 `helm install|update|delete|rollback --dry-run` 期间，Helm 不会连接 Kubernetes API Server，所以在这种情况下，查找函数将返回一个空列表（即 `dict`）。

### 运算符函数

对于模板，操作符 (`eq`、`ne`、`lt`、`gt`、`and`、`or`等等) 都被作为函数实现。在管道中，运算符可以用圆括号（`(` 和 `)`）分组。
