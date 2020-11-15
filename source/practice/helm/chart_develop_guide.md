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

在编写生产级 chart 时，使用这些 chart 的基本版本可能非常有用。所以在你的日常 chart 制作中，可以不删除它们。
