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