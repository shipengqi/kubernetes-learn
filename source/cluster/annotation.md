---
title: Annotation
---

Annotation，就是注解。Annotation 可以将 Kubernetes 资源对象关联到任意的非标识性元数据。使用客户端（如工具和库）可以检索到这些元数据。

Label 和 Annotation 都可以将元数据关联到 Kubernetes 资源对象。Label 主要用于选择对象，可以挑选出满足特定条件的对象。
annotation 不能用于标识及选择对象。annotation 中的元数据可多可少，可以是结构化的或非结构化的，也可以包含 label 中不允许出现的字符。

```yml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: chatbot-ingress-ssl
  namespace: {SUITE_NAMESPACE}
  annotations:
    ingress.kubernetes.io/secure-backends: "true"
    ingress.kubernetes.io/proxy-body-size: 60m
    kubernetes.io/ingress.class: "nginx"
```

一些可以记录在 annotation 中的对象信息：

- 声明配置层管理的字段。使用 annotation 关联这类字段可以用于区分以下几种配置来源：客户端或服务器设置的默认值，
自动生成的字段或自动生成的 auto-scaling 和 auto-sizing 系统配置的字段。
- 创建信息、版本信息或镜像信息。例如时间戳、版本号、git分支、PR序号、镜像哈希值以及仓库地址。
- 记录日志、监控、分析或审计存储仓库的指针
- 可以用于 debug 的客户端（库或工具）信息，例如名称、版本和创建信息。
