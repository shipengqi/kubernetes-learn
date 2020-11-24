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

当求值时，该模板将产生如下结果：

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

当有像这样管道参数时，第一个求值（`.Values.favorite.drink`）的结果将作为函数的最后一个参数发送。我们可以修改上面的 drink 示例来说明一个带有两个参数的函数 `repeat COUNT STRING`：

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

## 流程控制

控制结构（模板中称为 “actions”）为模板作者提供了控制模板生成流程的能力。Helm 的模版语言提供了以下控制结构：

- `if/else` 创建条件块
- `with` 指定域
- `range`, 它提供了一个 `for each` 风格的循环

除了这些之外，还提供了一些用于声明和使用命名模版的 actions：

- `define` 在你的模版中声明一个新的命名模版
- `template` 导入一个命名模版
- `block` 声明一种可填充模板区域的特殊类型

在本节中，将谈论 `if`，`with` 和 `range`。其他内容在后面的 “命名模板” 一节中介绍。

### if/else

我们要看的第一个控制结构是用于在模板中有条件地包含文本块。这就是 `if/else` 块。

基本的条件结构：

```yml
{{ if PIPELINE }}
  # Do something
{{ else if OTHER PIPELINE }}
  # Do something else
{{ else }}
  # Default case
{{ end }}
```

注意，我们现在讨论的是管道而不是 values。其原因是要明确控制结构可以执行整个管道，而不仅仅是计算一个值。

如果值为如下情况，则管道求值为 `false`：

- 一个布尔值 `false`
- 一个数值 0
- 一个空字符串
- `nil`
- 一个空集合 (`map`, `slice`, `tuple`, `dict`, `array`)

在其他情况下, 条件为 `true`。

我们添加一个简单的条件在我们的 ConfigMap 中。我们添加一个其他配置当 drink 是 coffe 时。

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
  myvalue: "Hello World"
  drink: {{ .Values.favorite.drink | default "tea" | quote }}
  food: {{ .Values.favorite.food | upper | quote }}
  {{ if eq .Values.favorite.drink "coffee" }}mug: true{{ end }}
```

由于我们在上一个示例中注释掉了`drink: coffee`，所以输出不应该包括 `mug: true`。但是如果我们把它添加回到 `values.yaml` 文件中，输出会像下面这样：

```yml
# Source: mychart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: eyewitness-elk-configmap
data:
  myvalue: "Hello World"
  drink: "coffee"
  food: "PIZZA"
  mug: true
```

在查看条件时，我们应该快速查看模板中的空格控制方式。我们采取前面的例子和格式化使它更容易阅读:

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
  myvalue: "Hello World"
  drink: {{ .Values.favorite.drink | default "tea" | quote }}
  food: {{ .Values.favorite.food | upper | quote }}
  {{ if eq .Values.favorite.drink "coffee" }}
    mug: true
  {{ end }}
```

最初，这看起来不错。但是如果我们通过模板引擎运行它，我们会得到一个错误的结果：

```bash
$ helm install --dry-run --debug ./mychart
SERVER: "localhost:44134"
CHART PATH: /Users/mattbutcher/Code/Go/src/helm.sh/helm/_scratch/mychart
Error: YAML parse error on mychart/templates/configmap.yaml: error converting YAML to JSON: yaml: line 9: did not find expected key
```

发生了什么？我们生成了一个错误的 YAML 因为上面的空格。

```yml
# Source: mychart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: eyewitness-elk-configmap
data:
  myvalue: "Hello World"
  drink: "coffee"
  food: "PIZZA"
    mug: true
```

`mug` 是的缩进是错误的。简单地将那行减少缩进，然后重新运行：

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
  myvalue: "Hello World"
  drink: {{ .Values.favorite.drink | default "tea" | quote }}
  food: {{ .Values.favorite.food | upper | quote }}
  {{ if eq .Values.favorite.drink "coffee" }}
  mug: true
  {{ end }}
```

当我们发送该信息时，我们会得到有效的 YAML，但仍然看起来有点意思：

```yml
# Source: mychart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: telling-chimp-configmap
data:
  myvalue: "Hello World"
  drink: "coffee"
  food: "PIZZA"

  mug: true

```

注意我们收到的 YAML 中有一些空行。为什么？当模版引擎删除 `{{` 和 `}}` 中的内容时，但是按原样保留剩余的空白。

YAML 中的缩进空格是严格的，因此管理空格变得非常重要。幸运的是，Helm 模板有一些工具可以帮助我们。

首先，可以用特殊字符修改模板声明的花括号语法，以告诉模板引擎删除空白。`{{-` 表示删除左空格，`-}}` 意味着应该删除右空格。注意！换行符也是空格！

> 确保 `-` 和其他指令之间有空格。`{{ -3 }}` 意思是 “删除左空格并打印 3”，而 `{{-3 }}` 意思是 “打印 `-3`”。

使用这个语法，我们可以修改我们的模板来摆脱这些新行：

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
  myvalue: "Hello World"
  drink: {{ .Values.favorite.drink | default "tea" | quote }}
  food: {{ .Values.favorite.food | upper | quote }}
  {{- if eq .Values.favorite.drink "coffee" }}
  mug: true
  {{- end }}
```

为了清楚说明这一点，让我们调整上面的内容，将空格替换为 `*`, 按照此规则将每个空格将被删除。一个在该行的末尾的 `*` 指示换行符将被移除

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
  myvalue: "Hello World"
  drink: {{ .Values.favorite.drink | default "tea" | quote }}
  food: {{ .Values.favorite.food | upper | quote }}*
**{{- if eq .Values.favorite.drink "coffee" }}
  mug: true*
**{{- end }}
```

通过 Helm 运行我们的模板并查看结果：

```yml
# Source: mychart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: clunky-cat-configmap
data:
  myvalue: "Hello World"
  drink: "coffee"
  food: "PIZZA"
  mug: true
```

小心使用 chomping 修饰符。这样很容易引起意外：

```yml
  food: {{ .Values.favorite.food | upper | quote }}
  {{- if eq .Values.favorite.drink "coffee" -}}
  mug: true
  {{- end -}}
```

这会产生 `food: "PIZZA"mug:true`，因为删除了双方的换行符。

最后，有时候告诉模板系统如何缩进更容易，而不是试图掌握模板指令的间距。因此，有时可能会发现使用 `indent` 函数（`{{indent 2 "mug:true"}}`）会很有用。

### 使用 with 修改域

`with` 控制着变量作用域。`.` 是对当前范围的引用。因此，`.Values` 告诉模板在当前范围中查找 `Values` 对象。

`with` 语法类似一个简单的 `if` 片段：

```yml
{{ with PIPELINE }}
  # restricted scope
{{ end }}
```

scope 可以改变。`with` 可以允许将当前范围（`.`）设置为特定的对象。如，我们一直在使用的 `.Values.favorites`。让我们重写我们的 ConfigMap 来改变 `.` scope 来指向 `.Values.favorites`：

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
  myvalue: "Hello World"
  {{- with .Values.favorite }}
  drink: {{ .drink | default "tea" | quote }}
  food: {{ .food | upper | quote }}
  {{- end }}
```

注意，现在我们可以引用 `.drink` 和 `.food` 无需对其进行限定。这是因为该 `with` 声明设置 `.` 为指向 `.Values.favorite`。在 `{{- end }}` 后会重置 `.` 为先前的 scope。

但是请注意！在受限范围内，此时将无法从父作用域访问其他对象。例如，下面会报错：

```yml
  {{- with .Values.favorite}}
  drink: {{.drink | default "tea" | quote}}
  food: {{.food | upper | quote}}
  release: {{.Release.Name}}
  {{- end}}
```

它会产生一个错误，因为 `Release.Name` 它不在 `.` 限制范围内。但是，如果我们交换最后两行，所有将按预期工作，因为范围在 `{{ end }}` 之后被重置。

或者，我们可以使用 `$` 访问父作用域的 `Release.Name` 对象。`$` 被映射到根作用域，并且在模板执行过程中不会改变。以下也是可行的：

```yml
  {{- with .Values.favorite }}
  drink: {{ .drink | default "tea" | quote }}
  food: {{ .food | upper | quote }}
  release: {{ $.Release.Name }}
  {{- end }}
```

### 循环 range 动作

许多编程语言都支持 `for` 循环，`foreach` 循环，或者类似的简单的机制。在 Helm 的模版语言中，遍历集合的方式是使用 `range` 操作符。

首先，让我们在我们的 `values.yaml` 文件中添加一份披萨配料列表：

```yml
favorite:
  drink: coffee
  food: pizza
pizzaToppings:
  - mushrooms
  - cheese
  - peppers
  - onions
```

现在我们有了一个列表 `pizzaToppings`（在模版中叫做 `slice`）。我们可以修改我们的模板，将这个列表打印到我们的 ConfigMap 中：

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
  myvalue: "Hello World"
  {{- with .Values.favorite }}
  drink: {{ .drink | default "tea" | quote }}
  food: {{ .food | upper | quote }}
  {{- end }}
  toppings: |-
    {{- range .Values.pizzaToppings }}
    - {{ . | title | quote }}
    {{- end }}
```

我们可以使用 `$` 访问父作用域的列表 `Values.pizzaToppings`。

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
  myvalue: "Hello World"
  {{- with .Values.favorite }}
  drink: {{ .drink | default "tea" | quote }}
  food: {{ .food | upper | quote }}
  toppings: |-
    {{- range $.Values.pizzaToppings }}
    - {{ . | title | quote }}
    {{- end }}
  {{- end }}
```

让我们仔细看看 `toppings:` 列表。`range` 函数将 “range over”(遍历) `pizzaToppings` 列表。但现在发生了一些有趣的事情。就像 `with` 设置 `.` 的作用域，`range` 操作符也是一样。每次通过循环时，`.` 都设置为当前的 pizza topping。也就是第一次 `.` 为 `mushrooms`。第二个迭代它为 `cheese`，依此类推。

我们可以直接向管道发送 `.` 的值，所以当我们这样做时 `{{ . | title | quote }}`，它会发送 `.` 到 `title`（标题 case 函数），然后发送到 `quote`。如果我们运行这个模板，输出将是：

```yml
# Source: mychart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: edgy-dragonfly-configmap
data:
  myvalue: "Hello World"
  drink: "coffee"
  food: "PIZZA"
  toppings: |-
    - "Mushrooms"
    - "Cheese"
    - "Peppers"
    - "Onions"
```

现在，在这个例子中，我们碰到了一些棘手的事情。该 `toppings: |-` 行声明了一个多行字符串。所以我们的 toppings list 实际上不是 YAML 清单。这是一个很大的字符串。我们为什么要这样做？因为 ConfigMaps 中的数据 data 由键/值对组成，其中键和值都是简单的字符串。要理解这种情况，请查看 [Kubernetes ConfigMap 文档](https://kubernetes.io/docs/user-guide/configmap/)。但对我们来说，这个细节并不重要。

> YAML 中的 `|-` 标记表示一个多行字符串。这可以是一种有用的技术，用于在清单中嵌入大块数据，如此处所示。

有时这对于能快速在模板中创建一个列表，然后遍历该列表是很有用的。。Helm 模板有一个功能可以使这个变得简单：`tuple`。在计算机科学中，元组是固定大小但具有任意数据类型的类似列表的集合。这大致表达了使用元组的方式。

```yml
  sizes: |-
    {{- range tuple "small" "medium" "large" }}
    - {{ . }}
    {{- end }}
```

上面会产生：

```yml
  sizes: |-
    - small
    - medium
    - large
```

除了 list 和 tuple 之外，`range` 还可以用于遍历具有键和值的集合（如 `map` 或 `dict`）。

## 变量

了解了函数，管道，对象和控制结构，我们可以开始了解许多编程语言中较为基本的思想之一：变量。在模版中，它的使用频率比较低。但是我们会看到如何使用它们简化代码，并更好地使用 `with` 和 `range`。

在前面的例子中，我们看到这段代码会失败：

```yml
  {{- with .Values.favorite}}
  drink: {{.drink | default "tea" | quote}}
  food: {{.food | upper | quote}}
  release: {{.Release.Name}}
  {{- end}}
```  

`Release.Name` 不在该 `with` 块中限制的域内。解决作用域问题的一种方法是将对象分配给可以在不考虑当前范围的情况下访问的变量。

在 Helm 模版中。一个变量是对另一个对象的命名引用。它遵循这个形式 `$name`。变量被赋予一个特殊的赋值操作符：`:=`。我们可以使用变量重写上面的 `Release.Name`。

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{.Release.Name}}-configmap
data:
  myvalue: "Hello World"
  {{- $relname := .Release.Name -}}
  {{- with .Values.favorite}}
  drink: {{.drink | default "tea" | quote}}
  food: {{.food | upper | quote}}
  release: {{$relname}}
  {{- end}}
```

注意，在我们开始 `with` 块之前，我们赋值 `$relname :=.Release.Name`。现在在 `with` 块内部，`$relname` 变量仍然指向 `.Release.Name`。

运行会产生：

```yml
# Source: mychart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: viable-badger-configmap
data:
  myvalue: "Hello World"
  drink: "coffee"
  food: "PIZZA"
  release: viable-badger
```

变量在 `range` 循环中特别有用。它们可以用于类似列表的对象来捕获索引和值：

```yml
  toppings: |-
    {{- range $index, $topping := .Values.pizzaToppings}}
      {{$index}}: {{ $topping }}
    {{- end}}
```

注意，首先是 `range`，然后是变量，然后是赋值操作符，然后是列表。这会把整数索引赋值给 `$index`（从 0 开始），值赋值给 `$topping`。运行会生成：

```yml
  toppings: |-
      0: mushrooms
      1: cheese
      2: peppers
      3: onions
```

对于同时具有键值对的数据结构，可以使用 `range` 来获取两者。例如，我们可以对 `.Values.favorite` 像这样循环：

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
  myvalue: "Hello World"
  {{- range $key, $val := .Values.favorite }}
  {{ $key }}: {{ $val | quote }}
  {{- end }}
```

现在在第一次迭代中，`$key` 是 `drink`，`$val` 是 `coffee`，第二次，`$key` 是 `food`，`$val` 会 `pizza`。运行上面的代码会生成：

```yml
# Source: mychart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: eager-rabbit-configmap
data:
  myvalue: "Hello World"
  drink: "coffee"
  food: "pizza"
```

变量通常不是 “全局” 的。它们的范围是声明它们所在的块。之前，我们在模板的顶层赋值 `$relname`。该变量将在整个模板的范围内起作用。但在我们的最后一个例子中，`$key` 和 `$val` 只会在该 `{{range...}}{{end}}` 块的范围内起作用。

然后，`$` 变量永远是全局的，这个变量总是指向 root 上下文。当你在 `range` 循环需要知道 release name 时是非常有用的。

示例：

```yml
{{- range .Values.tlsSecrets }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ .name }}
  labels:
    # Many helm templates would use `.` below, but that will not work,
    # however `$` will work here
    app.kubernetes.io/name: {{ template "fullname" $ }}
    # I cannot reference .Chart.Name, but I can do $.Chart.Name
    helm.sh/chart: "{{ $.Chart.Name }}-{{ $.Chart.Version }}"
    app.kubernetes.io/instance: "{{ $.Release.Name }}"
    # Value from appVersion in Chart.yaml
    app.kubernetes.io/version: "{{ $.Chart.AppVersion }}"
    app.kubernetes.io/managed-by: "{{ $.Release.Service }}"
type: kubernetes.io/tls
data:
  tls.crt: {{ .certificate }}
  tls.key: {{ .key }}
---
{{- end }}
```

## 命名模版

在本节中，将看到如何在一个文件中定义命名模板，然后在别处使用它们。命名模版（有时候叫做局部模版或子模版）只是在文件中定义，并给出名称。我们可以看到创建它们的两种方式，是一些使用它们的不同方式。

在命名模板时要注意一个重要的细节：**模板名称是全局的**。如果声明两个具有相同名称的模板，那么会使用最后加载的那个。由于子 chart 中的模板与顶级模板一起编译，因此注意小心地使用特定 chart 的名称来命名模板。

通用的命名约定是为每个定义的模板添加 chart 名称：`{{ define "mychart.labels" }}`。通过使用特定 chart 名称作为前缀，我们可以避免由于同名模板的两个不同 chart 而可能出现的任何冲突。

### partials 和 _ 文件

到目前为止，我们已经使用了一个文件，一个文件包含一个模板。但 Helm 的模板语言允许创建命名的嵌入模板，可以通过名称访问。

在我们开始编写这些模板之前，有一些文件命名约定值得一提：

- 大多数文件 `templates/` 被视为包含 Kubernetes manifests
- `NOTES.txt` 是一个例外
- 名称以下划线（`_`）开头的文件被认为内部没有 Kubernetes manifest。这些文件不会渲染 Kubernetes 对象定义，但是在其他 chart 模板中可以任意调用。

这些文件用于存储 partials 和辅助程序。事实上，当我们第一次创建时 mychart，我们看到一个叫做文件 `_helpers.tpl`。该文件是模板 partials 的默认位置。

### 用 define 和 template 声明和使用模板

define 操作允许我们在模板文件内创建一个命名模板。它的语法如下所示：

```yml
{{ define "MY.NAME" }}
  # body of template here
{{ end }}
```

例如，我们可以定义一个封装 Kubernetes labels 块的模版：

```yml
{{- define "mychart.labels" }}
  labels:
    generator: helm
    date: {{ now | htmlDate }}
{{- end }}
```

现在我们可以在现有的的 ConfigMap 中嵌入这个模版，然后将其包含在 `template` 操作中：

```yml
{{- define "mychart.labels" }}
  labels:
    generator: helm
    date: {{ now | htmlDate }}
{{- end }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
  {{- template "mychart.labels" }}
data:
  myvalue: "Hello World"
  {{- range $key, $val := .Values.favorite }}
  {{ $key }}: {{ $val | quote }}
  {{- end }}
```

当模板引擎读取该文件时，它将存储 `mychart.labels` 的引用直到 `template "mychart.labels"` 被调用。然后它将在文件内渲染该模板。所以结果如下所示：

```yml
# Source: mychart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: running-panda-configmap
  labels:
    generator: helm
    date: 2016-11-02
data:
  myvalue: "Hello World"
  drink: "coffee"
  food: "pizza"
```

通常，Helm chart 通常将这些模板放入 partials 文件中，通常是 `_helpers.tpl`。让我们移动这个函数到那里：

```yml
{{/* Generate basic labels */}}
{{- define "mychart.labels" }}
  labels:
    generator: helm
    date: {{ now | htmlDate }}
{{- end }}
```

按照惯例，`define` 函数应该有一个简单的文档块（`{{/* ... */}}`）来描述他们所做的事情。

即使这个定义在 `_helpers.tpl`，它仍然可以在 `configmap.yaml` 中访问：

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
  {{- template "mychart.labels" }}
data:
  myvalue: "Hello World"
  {{- range $key, $val := .Values.favorite }}
  {{ $key }}: {{ $val | quote }}
  {{- end }}
```

如上所述，模板名称是全局的。因此，如果两个模板被命名为相同的名称，则最后出现的模版会被使用。由于子 chart 中的模板与顶级模板一起编译，因此最好使用 chart 专用名称命名模板。流行命名约定是为每个定义的模板添加 chart 名称：`{{ define "mychart.labels" }}`。

### 设置模版的作用域

在我们上面定义的模板中，我们没有使用任何对象。我们只是使用函数。让我们修改我们定义的模板，包含 chart 名称和 chart 版本：

```yml
{{/* Generate basic labels */}}
{{- define "mychart.labels" }}
  labels:
    generator: helm
    date: {{ now | htmlDate }}
    chart: {{ .Chart.Name }}
    version: {{ .Chart.Version }}
{{- end }}
```

如果我们渲染这个，将不会得到我们期望的结果：

```yml
# Source: mychart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: moldy-jaguar-configmap
  labels:
    generator: helm
    date: 2016-11-02
    chart:
    version:
```

name 和 version 发生了什么？他们不在我们定义的模板的范围内。当一个已命名的模板（用 `define` 创建）被渲染时，它将接收由该 `template` 调用传入的作用域。在我们的例子中，我们包含了这样的模板：

```yml
{{- template "mychart.labels" }}
```

没有传入 scope，因此在模板中我们无法访问 `.` 中的任何内容。这很容易解决。我们只需将 scope 传递给模板：

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
  {{- template "mychart.labels" . }}
```

请注意，我们在调用 `template` 时末尾传递了 `.`。我们可以很容易地通过 `.Values` 或者 `.Values.favorite` 或者我们想要的任何 scope。但是我们想要的是顶级 scope。

现在，当我们用 `helm install --dry-run --debug ./mychart` 执行这个模板，我们得到这个：

```yml
# Source: mychart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: plinking-anaco-configmap
  labels:
    generator: helm
    date: 2016-11-02
    chart: mychart
    version: 0.1.0
```

现在 `{{ .Chart.Name }}` 解析为 `mychart`，`{{ .Chart.Version }}` 解析为 `0.1.0`。

### include 函数

假设我们已经定义了一个如下所示的简单模板：

```yml
{{- define "mychart.app" -}}
app_name: {{ .Chart.Name }}
app_version: "{{ .Chart.Version }}"
{{- end -}}
```

现在，假设我想把它插入到模板的 `label:` 部分和 `data:` 部分：

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
  labels:
    {{ template "mychart.app" . }}
data:
  myvalue: "Hello World"
  {{- range $key, $val := .Values.favorite }}
  {{ $key }}: {{ $val | quote }}
  {{- end }}
{{ template "mychart.app" . }}
```

输出并不是我们期望的：

```yml
# Source: mychart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: measly-whippet-configmap
  labels:
    app_name: mychart
app_version: "0.1.0+1478129847"
data:
  myvalue: "Hello World"
  drink: "coffee"
  food: "pizza"
  app_name: mychart
app_version: "0.1.0+1478129847"
```

注意，`app_version` 缩进在两个地方都是错误的。为什么？因为被替换的模板具有与右侧对齐的文本。因为 `template` 是一个动作，而不是一个函数，所以没有办法将 `template` 调用的输出传递给其他函数; 数据只是内嵌在一行。

为了解决这个问题，Helm 提供了一个替代 `template` 方案，将模板的内容导入到当前管道中，并将其传递到管道中的其函数。

这里是上面的例子，用 `indent` 纠正正确缩进 `mychart_app` 模板：

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
  labels:
{{ include "mychart.app" . | indent 4 }}
data:
  myvalue: "Hello World"
  {{- range $key, $val := .Values.favorite }}
  {{ $key }}: {{ $val | quote }}
  {{- end }}
{{ include "mychart.app" . | indent 2 }}
```

现在生成的 YAML 每个部分都正确缩进：

```yml
# Source: mychart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: edgy-mole-configmap
  labels:
    app_name: mychart
    app_version: "0.1.0+1478129987"
data:
  myvalue: "Hello World"
  drink: "coffee"
  food: "pizza"
  app_name: mychart
  app_version: "0.1.0+1478129987"
```

在 Helm 模板中使用 `include` 比 `template` 会更好，可以更好地为 YAML 处理输出格式。

## 在模版中访问 Files

在上一节中，我们介绍了几种创建和访问命名模板的方法。这可以很容易地从另一个模板中导入一个模板。但有时需要导入不是模板的文件，并注入其内容而不通过模板渲染器发送内容。

Helm 提供的 `.Files` 对象可以访问文件。
