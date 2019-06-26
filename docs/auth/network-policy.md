# Network Policy
网络策略说明一组`Pod`之间是如何被允许互相通信，以及如何与其它网络`Endpoint`进行通信。 `NetworkPolicy`资源使用标签来选择`Pod`，并定义了一些规则，
这些规则指明允许什么流量进入到选中的`Pod`上。

`Pod`默认是未隔离的，它们可以从任何的源接收请求。 具有一个可以选择`Pod`的网络策略后，`Pod`就会变成隔离的。
一旦 Namespace 中配置的网络策略能够选择一个特定的 Pod，这个 Pod 将拒绝任何该网络策略不允许的连接。

### NetworkPolicy 资源
查看[API参考](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.12/#networkpolicy-v1-networking-k8s-io)可以获取该资源的完整定义。
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: test-network-policy
  namespace: default
spec:
  podSelector:
    matchLabels:
      role: db
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          project: myproject
    - podSelector:
        matchLabels:
          role: frontend
    ports:
    - protocol: TCP
      port: 6379
```

`podSelector`：每个`NetworkPolicy`包含一个`podSelector`，它可以选择一组应用了网络策略的`Pod`。由于`NetworkPolicy`当前只支持定义`ingress`规则，这` podSelector`实际上为该策略
定义了一组 “目标Pod”。示例中的策略选择了标签为 “role=db” 的 Pod。一个空的`podSelector`代表选择了该 Namespace 中的所有 Pod。

`ingress`：每个`NetworkPolicy`包含了一个白名单`ingress`规则列表。每个规则只允许能够匹配上`from`和`ports`配置段的流量。示例策略包含了单个规则，它从这两个源中匹配在单个
端口上的流量，第一个是通过`namespaceSelector`指定的，第二个是通过`podSelector`指定的。

因此，上面示例的 NetworkPolicy：

- 在`default` Namespace中 隔离了标签 “role=db” 的 Pod（如果他们还没有被隔离）
- 在`default` Namespace中，允许任何具有 “role=frontend” 的 Pod，连接到标签为 “role=db” 的 Pod 的 TCP 端口 6379
- 允许在 Namespace 中任何具有标签 “project=myproject” 的 Pod，连接到 “default” Namespace 中标签为 “role=db” 的 Pod 的 TCP 端口 6379

### 默认策略
通过创建一个可以选择所有 Pod 但不允许任何流量的 NetworkPolicy，你可以为一个 Namespace 创建一个 “默认的” 隔离策略，如下所示：
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
spec:
  podSelector:
```

可选地，在 Namespace 中，如果你想允许所有的流量进入到所有的 Pod（即使已经添加了某些策略，使一些 Pod 被处理为 “隔离的”），你可以通过创建一个策略来显式地指定允许所有流量：
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-all
spec:
  podSelector:
  ingress:
  - {}
```