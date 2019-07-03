# Label
Label 是附着到 object 上（例如 Pod）的键值对。可以在创建 object 的时候指定，也可以在 object 创建后随时指定。**Labels 的值对系统本身并没有什么含义，只是对用户才有意义**。

```yml
metadata:
  name: kube-flannel-cfg
  namespace: kube-system
  labels:
    tier: node
    app: flannel
```

Label 能够将组织架构映射到系统架构上，这样能够更便于微服务的管理，你可以给 object 打上如下类型的 label：

- `"release" : "stable"`, `"release" : "canary"`
- `"environment" : "dev"`, `"environment" : "qa"`, `"environment" : "production"`
- `"tier" : "frontend"`, `"tier" : "backend"`, `"tier" : "cache"`
- `"partition" : "customerA"`, `"partition" : "customerB"`
- `"track" : "daily"`, `"track" : "weekly"`
- `"team" : "teamA"`,"`team:" : "teamB"`

## Label selector
标签不需要有唯一性。一般来说，我们期望许多对象具有相同的标签。

通过标签选择器（Labels Selectors），客户端/用户 能方便辨识出一组对象。标签选择器是 kubernetes 中核心的组成部分。

Label selector 有两种类型：
- `equality-based` ：可以使用 `=`、`==`、`!=` 操作符，可以使用 `,` 分隔多个表达式
- `set-based` ：可以使用 `in`、`notin`、`!` 操作符，另外还可以没有操作符，直接写出某个 label 的 key，表示过滤有某个 key 的 object 而不管该 key 的 value 是何值，
`!` 表示没有该 label 的 object。

```sh
# 过滤所有处于 production 但不是 frontend 的资源
$ kubectl get pods -l environment=production,tier!=frontend

#选择所有 key 等于 environment ，且 value 等于 production 或者 qa 的资源
$ kubectl get pods -l 'environment in (production),tier in (frontend)'

# 选择所有 key 等于 tier 且值是除了 frontend 和 backend 之外的资源，和那些没有标签的 key 是 tier 的资源
$ kubectl get pods -l 'environment in (production, qa)'

# 选择所有有一个标签的 key 为 environment，并且 value 不是 frontend 的资源
$ kubectl get pods -l 'environment,environment notin (frontend)'
```

### 设置 label selector
在 service、replicationcontroller 等 object 中有对 pod 的 label selector，使用方法只能使用"等于"操作，例如：
```yml
apiVersion: v1
kind: Service
metadata:
  name: chatbot-svc
  namespace: {NAMESPACE}
spec:
  ports:
  - name: cr
    port: 3000
    targetPort: 3000
  # label keys and values that must match in order to receive traffic for this service
  selector:
    app: chatops-chatbot
```

在 Job、Deployment、ReplicaSet 和 DaemonSet 这些 object 中，支持 `set-based` 的过滤，例如：
```yml
selector:
  matchLabels:
    app: chatbot
  matchExpressions:
    - {key: tier, operator: In, values: [cache]}
    - {key: environment, operator: NotIn, values: [dev]}
```