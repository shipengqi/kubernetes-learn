# How-to 指南

## chart 开发提示和技巧

本指南涵盖了 Helm chart 开发人员在构建 production-quality chart 时所学到的一些技巧和技巧。

### 了解你的模板功能

Helm 使用了 [Go 模板](https://godoc.org/text/template) 将你的源文件构建成模板。 虽然 Go 提供了一些内置方法，但我们也增加了一些其他功能。

首先，我们添加的所有功能都在 [Sprig library](https://masterminds.github.io/sprig/).。

我们也添加了两个特殊的模版方法：`include` 和 `required`。`include` 方法允许你引入另一个模版，并将结果传递给其他模版。

例如，这个模版片段包含了一个叫做 `mytpl` 的模版，然后将结果转为小写，并用双引号括起来：

```yml
value: {{ include "mytpl" . | lower | quote }}
```

`required` 方法可以让你声明模板渲染所必需的特定值。如果这个值时空的，模板渲染会出错并打印用户提交的错误信息。

下面的 `required` 方法的示例声明了一个 `.Values.who` 必需的条目，并且当这个条目不存在时会打印错误信息：

```yml
value: {{ required "A valid .Values.who entry required!" .Values.who }}
```

### 字符串用引号括起来，整数类型不用

使用字符串数据时，更安全地方式将字符串括起来而不是露在外面：

```yml
name: {{ .Values.MyName | quote }}
```

但是使用整型时不要把值括起来。在很多场景中那样会导致 Kubernetes 内解析失败。

```yml
port: {{ .Values.Port }}
```

这个说明不适用于环境变量是字符串的情况，即使表现为整型：

```yml
env:
  - name: HOST
    value: "http://host"
  - name: PORT
    value: "1234"
```

### 使用 'include' 方法

Go 提供了一种使用内置模板将一个模板包含在另一个模板中的方法。然而内置方法不能用于 Go 模板 pipeline。

为了可以包含模板，然后对该模板的输出执行操作，Helm 有一个特殊的 `include` 方法：

```yml
{{ include "toYaml" $value | indent 2 }}
```

上面这个包含的模板称为 `toYaml`，传值给 `$value`，然后将这个模板的输出传给 `indent` 方法。

因为 YAML 对缩进级别和空白都很重视，所以这是一个很好的方法来包含代码片段，但在相关的上下文中要处理缩进。

### 使用 'required' 方法

Go 提供了一种设置模板选项的方法，以控制 map 中没有键的索引时的行为。通常设置为 `template.Options("missingkey=option")`， `option` 是 `default`，`zero`，或 `error`。 将此项设置为`error` 时会停止执行并出现错误，这会应用到 map 中的每一个缺失的 key 中。 某些情况下 chart 的开发人员希望在 `values.yaml` 中选择值强制执行此操作。

`required` 方法可以让开发者声明模板渲染所必需的特定值。如果在 `values.yaml` 中这个值是空的，模板就不会渲染并返回开发者提供的错误信息。

```yml
{{ required "A valid foo is required!" .Values.foo }}
```

上述示例表示当 `.Values.foo` 被定义时模板会被渲染，但是未定义时渲染会失败并退出。

### 使用 'tpl' 方法

tpl 方法允许开发者在模板中使用字符串作为模板。将模板字符串作为一个值传递给 chart 或渲染外部配置文件非常有用。语法： `{{ tpl TEMPLATE_STRING VALUES }}`。

示例：

```yml
# values
template: "{{ .Values.name }}"
name: "Tom"

# template
{{ tpl .Values.template . }}

# output
Tom
```

渲染额外的配置文件：

```yml
# external configuration file conf/app.conf
firstName={{ .Values.firstName }}
lastName={{ .Values.lastName }}

# values
firstName: Peter
lastName: Parker

# template
{{ tpl (.Files.Get "conf/app.conf") . }}

# output
firstName=Peter
lastName=Parker
```

### 创建 Image pull secrets

Image pull secrets 本质上是 repo，username 和 password 的组合。你在部署应用时需要它，但是创建它需要运行几次 `base64`。我们可以写一个辅助模板来编写 Docker 的配置文件，用来承载密钥。示例如下：

首先，假定 `values.yaml` 文件中定义了认证信息：

```yml
imageCredentials:
  registry: quay.io
  username: someone
  password: sillyness
  email: someone@host.com
```

然后定义辅助模板：

```yml
{{- define "imagePullSecret" }}
{{- with .Values.imageCredentials }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"email\":\"%s\",\"auth\":\"%s\"}}}" .registry .username .password .email (printf "%s:%s" .username .password | b64enc) | b64enc }}
{{- end }}
{{- end }}
```

最后，使用辅助模版在更大的模版中创建了 secret manifest：

```yml
apiVersion: v1
kind: Secret
metadata:
  name: myregistrykey
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: {{ template "imagePullSecret" . }}
```

### 自动滚动部署

通常 `ConfigMaps` 和 `Secrets` 会作为配置文件注入到容器，以及其他外部依赖更新导致需要滚动部署 pods。

根据不同的应用，如果在随后的 `helm upgrade` 中进行更新，可能需要重新启动。但是，如果 deployment spec 本身没有更改，应用程序将继续使用旧的配置运行，从而导致 deployment 不一致。

`sha256sum` 方法保证在另一个文件发生更改时更新 deployment 的 `annotation`：

```yml
kind: Deployment
spec:
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
[...]
```

这个场景下你通常想滚动更新你的 deployment，可以使用上面类似的 annotation 步骤，而不是使用随机字符串替换，因而经常更改并导致 deployment 滚动更新：

```yml
kind: Deployment
spec:
  template:
    metadata:
      annotations:
        rollme: {{ randAlphaNum 5 | quote }}
[...]
```

每次调用模板方法会生成一个唯一的随机字符串。这意味着如果需要同步随机字符串给多种资源使用，所有相关的资源都要在同一个模板文件中。

这两种方法都允许你的 deployment 利用内置的更新策略逻辑来避免停机。

注意：过去我们推荐使用 `--recreate-pods` 参数作为另一个选项。这个参数在 Helm 3 中弃用了，而支持上面更具声明性的方法。

### 告诉 Helm 不要卸载资源

有时在执行 `helm uninstall` 时有些资源不应该被卸载。Chart 的开发者可以在资源中添加 annotation 避免被卸载。

```yml
kind: Secret
metadata:
  annotations:
    "helm.sh/resource-policy": keep
[...]
```

（需要引号）

annotation `"helm.sh/resource-policy": keep` 指示 Helm 执行一些操作要删除时（比如 `helm uninstall`，`helm upgrade` 或 `helm rollback`）跳过删除这个资源。然而，这个资源会变成孤立的。**Helm 不再以任何方式管理它**。如果在已经卸载的但保留资源的 release 上使用 `helm install --replace` 会出问题。

### 使用 "Partials" 和模板引用

有时你想在 chart中 创建可以重复利用的部分，不管是块还是局部模板。通常将这些文件保存在自己的文件中会更干净。

在 `templates/` 目录中，任何以下划线(`_`)开始的文件不希望输出到 Kubernetes 清单文件中。因此按照惯例，辅助模板和局部模板会被放在 `_helpers.tpl` 文件中。

### 使用很多依赖的复杂 Chart

在 [official charts repository](https://github.com/helm/charts) 中的许多 charts 是创建更先进应用的 “组成部分”。但是 chart 可能被用于创建大规模应用实例。在这种场景中，一个总的 chart 会有很多子 chart，每一个是整体功能的一部分。

当前从离散组件组成一个复杂应用的最佳实践是创建一个顶层总 chart 构建全局配置，然后使用 `charts/` 子目录嵌入每个组件。

### YAML 是 JSON 的超集

根据 YAML 规范，YAML 是 JSON 的超集。这意味着任意的合法 JSON 结构在 YAML 中应该是合法的。

这有个优势：有时候模板开发者会发现使用类JSON语法更容易表达数据结构而不是处理 YAML 的空白敏感度。

作为最佳实践，模板应遵循类 YAML 语法 除非 JSON语法大大降低了格式问题的风险。

### 关注生成的随机值

Helm 中有的方法允许你生成随机数据，加密密钥等等。这些很好用，但是在升级，模板重新执行时要注意，当模板运行与最后一次运行生成不一样的数据时，会触发资源升级。

### 用一条命令安装或升级 release

Helm 提供了一种简单命令执行安装或升级的方法。使用 `helm upgrade` 和 `--install` 命令，这会使Helm 查看是否已经安装版本，如果没有，会执行安装；如果版本存在，会进行升级。

```bash
helm upgrade --install <release name> --values <values file> <chart directory>
```

## 同步 chart 仓库
