---
title: 身份与权限认证
---

# 身份与权限认证
Kubernetes 中提供了良好的多租户认证管理机制，如 RBAC、ServiceAccount 还有各种 Policy 等。

Kubernetes 对 API 访问提供了三种安全访问控制措施：认证、授权和 Admission Control。认证解决用户是谁的问题，
授权解决用户能做什么的问题，Admission Control 则是资源管理方面的作用。

Kubernetes 集群的所有操作基本上都是通过 `kube-apiserver` 进行的，它提供 HTTP RESTful 形式的 API 供集群内外客户端调用。**认证授权过程只存在 HTTPS 形式的 API 中**。也就是说，
如果客户端使用 HTTP 连接到 `kube-apiserver`，那么是不会进行认证授权的。所以说，可以这么设置，在**集群内部组件间通信使用 HTTP，集群外部就使用 HTTPS**，
这样既增加了安全性，也不至于太复杂。

API 访问要经过的三个步骤：
1. 认证
2. 授权
3. Admission Control

## 认证
开启 TLS 时，所有的请求都需要首先认证。Kubernetes 支持同时开启多个认证插件（只要有一个认证通过即可）。如果认证成功，则用户的 `username` 会传入授
权模块做进一步授权验证；而对于认证失败的请求则返回 HTTP **401**。

Kubernetes 支持多种认证插件：
- X509 证书
- 静态 Token 文件
- 引导 Token
- 静态密码文件
- [Service Account](./service-account.html)
- OpenID
- Webhook
- 认证代理
- OpenStack Keystone 密码

详细使用参考[这里](./authentication.html)

## 授权
授权主要是用于对集群资源的访问控制，通过检查请求包含的相关属性值，与相对应的访问策略相比较，API 请求必须满足某些策略才能被处理。

Kubernetes 也支持同时开启多个授权插件（如 `--authorization-mode=RBAC,ABAC`，只要有一个验证通过即可）。如果授权成功，则用户的请求会发送到准入控制模块做进一步的请求验证；
对于授权失败的请求则返回 HTTP **403**。

授权处理以下的请求属性：
- user, group, extra
- API、请求方法（如 get、post、update、patch 和 delete）和请求路径（如 `/api`）
- 请求资源和子资源
- Namespace
- API Group

支持以下授权插件：
- ABAC
- [RBAC](./rbac.html)
- Webhook
- Node

详细使用参考[这里](./authorization.html)

### AlwaysDeny 和 AlwaysAllow
Kubernetes 还支持 AlwaysDeny 和 AlwaysAllow 模式，其中 AlwaysDeny 仅用来测试，而 AlwaysAllow 则 允许所有请求（会覆盖其他模式）。

## 准入控制
参考[这里](../controller/admission.html)