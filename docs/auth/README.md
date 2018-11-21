# 身份与权限认证
Kubernetes 中提供了良好的多租户认证管理机制，如RBAC、ServiceAccount还有各种Policy等。

## Service Account
Service account 是为了方便 Pod 里面的进程调用 Kubernetes API 或其他外部服务而设计的。为 Pod 中的进程提供身份信息。Service account 与
User account 的区别：
- User account 是为人设计的，而 service account 则是为 Pod 中的进程调用 Kubernetes API 而设计
- User account 是跨 namespace 的，而 service account 则是仅局限它所在的 namespace；
- **每个 namespace 都会自动创建一个 default service account**
- Token controller 检测 service account 的创建，并为它们创建 [Secret​]()
- 开启 ServiceAccount Admission Controller 后
  - 每个 Pod 在创建后都会自动设置`spec.serviceAccountName`为`default`（除非指定了其他 ServiceAccout）
  - 验证 Pod 引用的 service account 已经存在，否则拒绝创建
  - 如果 Pod 没有指定 ImagePullSecrets，则把 service account 的 ImagePullSecrets 加到 Pod 中
  - **每个 container 启动后都会挂载该 service account 的`token`和`ca.crt`到`/var/run/secrets/kubernetes.io/serviceaccount/`**

当创建 pod 的时候，如果没有指定一个 service account，系统会自动得在与该 pod 相同的 namespace 下为其指派一个`default` service account，
并会自动挂载到容器的`/var/run/secrets/kubernetes.io/serviceaccount`目录中。

在 1.6 以上版本中，可以选择取消为 service account 自动挂载 API 凭证，只需在 service account 中设置`automountServiceAccountToken: false`：
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: build-robot
automountServiceAccountToken: false
```
也可以选择只取消单个 pod 的 API 凭证自动挂载：
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  serviceAccountName: build-robot
  automountServiceAccountToken: false
```
pod 设置中的优先级更高。

在认证时，ServiceAccount 的用户名格式为`system:serviceaccount:(NAMESPACE):(SERVICEACCOUNT)`，并从属于两个`group：system:serviceaccounts`
和`system:serviceaccounts:(NAMESPACE)`。

### 创建 Service Account
```bash
# 创建 Service Account  jenkins
$ kubectl create serviceaccount jenkins
serviceaccount "jenkins" created

# 查看 Service Account  jenkins
$ kubectl get serviceaccounts jenkins -o yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  creationTimestamp: 2017-05-27T14:32:25Z
  name: jenkins
  namespace: default
  resourceVersion: "45559"
  selfLink: /api/v1/namespaces/default/serviceaccounts/jenkins
  uid: 4d66eb4c-42e9-11e7-9860-ee7d8982865f
secrets:
- name: jenkins-token-l9v7v
```

上面的输出中，看到有一个 token 已经被自动创建，并被 service account 引用：
```bash
kubectl get secret jenkins-token-l9v7v -o yaml
apiVersion: v1
data:
  ca.crt: (APISERVER CA BASE64 ENCODED)
  namespace: ZGVmYXVsdA==
  token: (BEARER TOKEN BASE64 ENCODED)
kind: Secret
metadata:
  annotations:
    kubernetes.io/service-account.name: jenkins
    kubernetes.io/service-account.uid: 4d66eb4c-42e9-11e7-9860-ee7d8982865f
  creationTimestamp: 2017-05-27T14:32:25Z
  name: jenkins-token-l9v7v
  namespace: default
  resourceVersion: "45558"
  selfLink: /api/v1/namespaces/default/secrets/jenkins-token-l9v7v
  uid: 4d697992-42e9-11e7-9860-ee7d8982865f
type: kubernetes.io/service-account-token
```

设置非默认的 service account，只需要在 pod 的`spec.serviceAccountName` 字段中将`name`设置为想要用的 service account 名字即可。

在 pod 创建之初 service account 就必须已经存在，否则创建将被拒绝。

### 手动创建 service account 的 API token
假设我们已经有了一个如上文提到的名为`jenkins`的 service account，我们手动创建一个新的 secret。
```bash
$ cat > /tmp/jenkins-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: jenkins-secret
  annotations:
    kubernetes.io/service-account.name: jenkins
type: kubernetes.io/service-account-token
EOF
$ kubectl create -f /tmp/jenkins-secret.yaml
secret "jenkins-secret" created
```

新创建的 secret 取代了 “jenkins” 这个 service account 原来的 API token。
```bash
$ kubectl describe secrets/jenkins-secret
Name:   jenkins-secret
Namespace:  default
Labels:   <none>
Annotations:  kubernetes.io/service-account.name=jenkins,kubernetes.io/service-account.uid=870ef2a5-35cf-11e5-8d06-005056b45392

Type: kubernetes.io/service-account-token

Data
====
ca.crt: 1220 bytes
token: ...
namespace: 7 bytes
```

### 添加 ImagePullSecrets
首先，创建一个 imagePullSecret，详见[这里](https://kubernetes.io/docs/concepts/containers/images/#specifying-imagepullsecrets-on-a-pod)。
修改 namespace 中的默认 service account 使用该 secret 作为 imagePullSecret。
输出default service account 到`default.yaml`:
```bash
$ kubectl get serviceaccounts default -o yaml > ./default.yaml
```
修改`default.yaml`,添加`{"imagePullSecrets": [{"name": "myregistrykey"}]}`：
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  creationTimestamp: 2015-08-07T22:02:39Z
  name: default
  namespace: default
  selfLink: /api/v1/namespaces/default/serviceaccounts/default
  uid: 052fb0f4-3d50-11e5-b066-42010af0d7b6
secrets:
- name: default-token-uudge
imagePullSecrets:
- name: myregistrykey
```
替换：
```bash
$ kubectl replace serviceaccount default -f ./default.yaml
serviceaccounts/default
```

### 使用 Service Account 作为用户权限管理配置 kubeconfig
#### 创建服务账号
```bash
kubectl create serviceaccount sample-sc

# 查看 Service Account  sample-sc
kubectl get serviceaccounts sample-sc -o yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  creationTimestamp: 2017-05-27T14:32:25Z
  name: sample-sc
  namespace: default
  resourceVersion: "45559"
  selfLink: /api/v1/namespaces/default/serviceaccounts/jenkins
  uid: 4d66eb4c-42e9-11e7-9860-ee7d8982865f
secrets:
- name: sample-sc-token-l9v7v

# 查看secret
kubectl get secret sample-sc-token-l9v7v
apiVersion: v1
data:
  ca.crt: ...
  namespace: ZGVmYXAsdA==
  token: ...
kind: Secret
metadata:
  annotations:
    kubernetes.io/service-account.name: sample-sc
    kubernetes.io/service-account.uid: 26e129dc-af1d-11e8-9453-00163e0efab0
  creationTimestamp: 2018-09-03T02:00:37Z
  name: mofang-viewer-sc-token-9x7nk
  namespace: default
  resourceVersion: "18914310"
  selfLink: /api/v1/namespaces/default/secrets/sample-sc-token-9x7nk
  uid: 26e58b7c-af1d-11e8-9453-00163e0efab0
type: kubernetes.io/service-account-token
```

`{data.token}`就会是我们的用户 token 的 base64 编码
#### 创建角色
比如我们想创建一个只可以查看集群deployments，services，pods 相关的角色，应该使用如下配置：
```yaml
apiVersion: rbac.authorization.k8s.io/v1
## 这里也可以使用 Role
kind: ClusterRole
metadata:
  name: mofang-viewer-role
  labels:
    from: mofang
rules:
- apiGroups:
  - ""
  resources:
  - pods
  - pods/status
  - pods/log
  - services
  - services/status
  - endpoints
  - endpoints/status
  - deployments
  verbs:
  - get
  - list
  - watch
```
#### 角色绑定
```yaml
apiVersion: rbac.authorization.k8s.io/v1
## 这里也可以使用 RoleBinding
kind: ClusterRoleBinding
metadata:
  name: sample-role-binding
  labels:
    from: mofang
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: mofang-viewer-role
subjects:
- kind: ServiceAccount
  name: sample-sc
  namespace: default
```
#### 配置 kubeconfig
经过以上的步骤，我们最开始创建的 serviceaccount 就可以用来访问我们的集群了， 同时我们可以动态更改 ClusterRole 的授权来及时控制某个账号的权限(这也是使用 serviceaccount 的好处)；
```yaml
apiVersion: v1
clusters:
- cluster:
    ## 这个是集群的 TLS 证书，与授权无关，使用同一的就可以
    certificate-authority-data: ...
    server: https://47.95.24.167:6443
  name: beta
contexts:
- context:
    cluster: beta
    user: beta-viewer
  name: beta-viewer
current-context: beta-viewer
kind: Config
preferences: {}
users:
- name: beta-viewer
  user:
    ## 这个使我们在创建 serviceaccount 生成相关 secret 之后的 data.token 的 base64 解码字符，它本质是一个 jwt token
    token: ...
```

使用授权插件来[设置 service account 的权限](https://kubernetes.io/docs/reference/access-authn-authz/authorization/#a-quick-note-on-service-accounts) 。

## RBAC
基于角色的访问控制机制（Role-Based Access，RBAC），集群管理员可以对用户或服务账号的角色进行更精确的资源访问控制。
**使用 RBAC 可以很方便的更新访问授权策略而不用重启集群。**

在使用 RBAC 时，只需要在启动 kube-apiserver 时配置`--authorization-mode=RBAC`即可。

RBAC API所定义的四种顶级类型。用户可以像使用其他Kubernetes API资源一样 （例如通过`kubectl`、API调用等）与这些资源进行交互。

### Role与ClusterRole
`Role`（角色）是一系列权限的集合，例如一个角色可以包含读取 Pod 的权限和列出 Pod 的权限。`Role`只能用来给某个特定`namespace`中的资源作鉴权，对多`namespace`和集群级的资源或者
是非资源类的 API（如`/healthz`）使用`ClusterRole`。

`ClusterRole`对象可以授予与`Role`对象相同的权限，但由于它们属于集群范围对象， 也可以使用它们授予对以下几种资源的访问权限：

- 集群范围资源（例如节点，即`node`）
- 非资源类型`endpoint`（例如`/healthz`）
- 跨所有命名空间的命名空间范围资源（例如`pod`，需要运行命令`kubectl get pods --all-namespaces`来查询集群中所有的`pod`）

```yaml
kind: Role
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  namespace: default
  name: pod-reader
rules:
- apiGroups: [""] # 空字符串""表明使用core API group
  resources: ["pods"]
  verbs: ["get", "watch", "list"]
```
上面的例子描述了”default”命名空间中的一个`Role`对象的定义，用于授予对pod的读访问权限。
```yaml
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  # 鉴于ClusterRole是集群范围对象，所以这里不需要定义"namespace"字段
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "watch", "list"]
```
上面例子中的`ClusterRole`定义可用于授予用户对某一特定命名空间，或者所有命名空间中的`secret`（取决于其绑定方式）的读访问权限

#### ClusterRole 聚合
从 v1.9 开始，在`ClusterRole`中可以通过`aggregationRule`来与其他`ClusterRole`聚合使用：
```yaml
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: monitoring
aggregationRule:
  clusterRoleSelectors:
  - matchLabels:
      rbac.example.com/aggregate-to-monitoring: "true"
rules: [] # Rules are automatically filled in by the controller manager.
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: monitoring-endpoints
  labels:
    rbac.example.com/aggregate-to-monitoring: "true"
# These rules will be added to the "monitoring" role.
rules:
- apiGroups: [""]
  resources: ["services", "endpoints", "pods"]
  verbs: ["get", "list", "watch"]
```

### RoleBinding与ClusterRoleBinding
`RoleBinding`把`Role`或`ClusterRole`中定义的各种权限映射到`User`，`Service Account`或者`Group`，从而让这些用户继承角色在`namespace`中的权限。`ClusterRoleBinding`
让用户继承`ClusterRole`在整个集群中的权限。

![rbac](../images/rbac2.png)

`RoleBinding`可以引用在同一命名空间内定义的`Role`对象。
```yaml
# 以下角色绑定定义将允许用户"jane"从"default"命名空间中读取pod。
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: read-pods
  namespace: default
subjects:
- kind: User
  name: jane
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

`RoleBinding`对象也可以引用一个`ClusterRole`对象用于在`RoleBinding`所在的命名空间内授予用户对所引用的`ClusterRole`中定义的命名空间资源的访问权限。
这一点允许管理员在整个集群范围内首先定义一组通用的角色，然后再在不同的命名空间中复用这些角色。

例如，尽管下面示例中的`RoleBinding`引用的是一个`ClusterRole`对象，但是用户”dave”（即角色绑定主体）还是只能读取”development” 命名空间中的secret（即RoleBinding所在的命名空间）。
```yaml
# 以下角色绑定允许用户"dave"读取"development"命名空间中的secret。
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: read-secrets
  namespace: development # 这里表明仅授权读取"development"命名空间中的资源。
subjects:
- kind: User
  name: dave
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
```

最后，可以使用`ClusterRoleBinding`在集群级别和所有命名空间中授予权限。下面示例中所定义的`ClusterRoleBinding`允许在用户组”manager”中的任何用户都可以读取集群中任何命名空间中的secret。
```yaml
# 以下`ClusterRoleBinding`对象允许在用户组"manager"中的任何用户都可以读取集群中任何命名空间中的secret。
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: read-secrets-global
subjects:
- kind: Group
  name: manager
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
```

### 对资源的引用
大多数资源由代表其名字的字符串表示，例如”pods”，就像它们出现在相关API endpoint的URL中一样。然而，有一些Kubernetes API还 包含了”子资源”，比如`pod`的`logs`。
在Kubernetes中，`pod logs endpoint`的URL格式为：
```
GET /api/v1/namespaces/{namespace}/pods/{name}/log
```
在这种情况下，”pods”是命名空间资源，而”log”是pods的子资源。为了在RBAC `Role`中表示出这一点，我们需要使用斜线来划分资源与子资源。
如果需要`Role`绑定主体读取`pods`以及`pod log`，需要定义以下`Role`：
```yaml
kind: Role
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  namespace: default
  name: pod-and-pod-logs-reader
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list"]
```

通过`resourceNames`列表，`Role`可以针对不同种类的请求根据资源名引用资源实例。当指定了`resourceNames`列表时，不同动作种类的请求的权限，
如使用”get”、”delete”、”update”以及”patch”等动词的请求，将被限定到资源列表中所包含的资源实例上。 例如，如果需要限定一个角色绑定主体
只能”get”或者”update”一个`configmap`时，可以定义以下角色：
```yaml
kind: Role
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  namespace: default
  name: configmap-updater
rules:
- apiGroups: [""]
  resources: ["configmap"]
  resourceNames: ["my-configmap"]
  verbs: ["update", "get"]
```

### 角色定义的例子
允许读取core API Group中定义的资源”pods”：
```yaml
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
```

允许读写在”extensions”和”apps” API Group中定义的”deployments”：
```yaml
rules:
- apiGroups: ["extensions", "apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

允许读取”pods”以及读写”jobs”：
```yaml
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["batch", "extensions"]
  resources: ["jobs"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

允许读取一个名为”my-config”的ConfigMap实例（需要将其通过RoleBinding绑定从而限制针对某一个命名空间中定义的一个ConfigMap实例的访问）：
```yaml
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  resourceNames: ["my-config"]
  verbs: ["get"]
```

允许读取core API Group中的”nodes”资源（由于Node是集群级别资源，所以此ClusterRole定义需要与一个ClusterRoleBinding绑定才能有效）：
```yaml
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]
```

允许对非资源endpoint “/healthz”及其所有子路径的”GET”和”POST”请求（此ClusterRole定义需要与一个ClusterRoleBinding绑定才能有效）：
```yaml
rules:
- nonResourceURLs: ["/healthz", "/healthz/*"] # 在非资源URL中，'*'代表后缀通配符
  verbs: ["get", "post"]
```

### 角色绑定主体
`RoleBinding`或者`ClusterRoleBinding`将`Role`绑定到角色绑定主体（Subject）。 角色绑定主体可以是用户组（Group）、用户（User）或者服务账户（Service Accounts）。

用户由字符串表示。可以是纯粹的用户名，例如”alice”、电子邮件风格的名字，如 “bob@example.com” 或者是用字符串表示的数字id。由Kubernetes管理员配置
[认证模块](https://k8smeetup.github.io/docs/admin/authentication/)以产生所需格式的用户名。对于用户名，RBAC授权系统不要求任何特定的格式。然而，
前缀`system:`是为Kubernetes系统使用而保留的，所以管理员应该确保用户名不会意外地包含这个前缀。

Kubernetes中的用户组信息由授权模块提供。用户组与用户一样由字符串表示。Kubernetes对用户组字符串没有格式要求，但前缀`system`:同样是被系统保留的。

**服务账户拥有包含`system:serviceaccount:`前缀的用户名，并属于拥有`system:serviceaccounts:`前缀的用户组。**

#### 角色绑定的一些例子
以下示例中，仅截取展示了`RoleBinding`的`subjects`字段。

一个名为”alice@example.com”的用户：
```yaml
subjects:
- kind: User
  name: "alice@example.com"
  apiGroup: rbac.authorization.k8s.io
```

一个名为”frontend-admins”的用户组：
```yaml
subjects:
- kind: Group
  name: "frontend-admins"
  apiGroup: rbac.authorization.k8s.io
```

`kube-system`命名空间中的默认服务账户：
```yaml
subjects:
- kind: ServiceAccount
  name: default
  namespace: kube-system
```

名为”qa”命名空间中的所有服务账户：
```yaml
subjects:
- kind: Group
  name: system:serviceaccounts:qa
  apiGroup: rbac.authorization.k8s.io
```

在集群中的所有服务账户：
```yaml
subjects:
- kind: Group
  name: system:serviceaccounts
  apiGroup: rbac.authorization.k8s.io
```

所有认证过的用户（version 1.5+）：
```yaml
subjects:
- kind: Group
  name: system:authenticated
  apiGroup: rbac.authorization.k8s.io
```

所有未认证的用户（version 1.5+）：
```yaml
subjects:
- kind: Group
  name: system:unauthenticated
  apiGroup: rbac.authorization.k8s.io
```

所有用户（version 1.5+）：
```yaml
subjects:
- kind: Group
  name: system:authenticated
  apiGroup: rbac.authorization.k8s.io
- kind: Group
  name: system:unauthenticated
  apiGroup: rbac.authorization.k8s.io
```

### 默认角色与默认角色绑定
API Server会创建一组默认的`ClusterRole`和`ClusterRoleBinding`对象。 这些默认对象中有许多包含`system:`前缀，表明这些资源由Kubernetes基础组件”拥有”。
对这些资源的修改可能导致非功能性集群（non-functional cluster）。一个例子是`system:node` `ClusterRole`对象。这个`ClusterRole`定义了`kubelets`的权限。如果这个角色被修改，
可能会导致`kubelets`无法正常工作。

所有默认的`ClusterRole`和`ClusterRoleBinding`对象都会被标记为`kubernetes.io/bootstrapping=rbac-defaults`。

## Network Policy
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