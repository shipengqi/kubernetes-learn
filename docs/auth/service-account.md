# Service Account
ServiceAccount 是为了方便 Pod 里面的进程调用 Kubernetes API 或其他外部服务而设计的。为 Pod 中的进程提供身份信息。ServiceAccount 与
User account 的区别：
- User account 是为人设计的，而 ServiceAccount 则是为 Pod 中的进程调用 Kubernetes API 而设计
- User account 是跨 namespace 的，而 ServiceAccount 则是仅局限它所在的 namespace；
- **每个 namespace 都会自动创建一个 `default` ServiceAccount**
- Token controller 检测 ServiceAccount 的创建，并为它们创建 [Secret​](../storage/secret.md)
- 开启 ServiceAccount Admission Controller 后
  - **每个 Pod 在创建后都会自动设置 `spec.serviceAccountName` 为 `default`**（除非指定了其他 ServiceAccount）
  - 验证 Pod 引用的 ServiceAccount 已经存在，否则拒绝创建
  - 如果 Pod 没有指定 ImagePullSecrets，则把 ServiceAccount 的 ImagePullSecrets 加到 Pod 中
  - **每个 container 启动后都会挂载该 ServiceAccount 的` token` 和 `ca.crt` 到 `/var/run/secrets/kubernetes.io/serviceaccount/`**

在 1.6 以上版本中，可以选择取消为 ServiceAccount 自动挂载 API 凭证，只需在 ServiceAccount 中设置 `automountServiceAccountToken: false`：
```yml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: build-robot
automountServiceAccountToken: false
```
也可以选择只取消单个 pod 的 API 凭证自动挂载：
```yml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  serviceAccountName: build-robot
  automountServiceAccountToken: false
```

pod 设置中的**优先级更高**。

在认证时，ServiceAccount 的用户名格式为 `system:serviceaccount:(NAMESPACE):(SERVICEACCOUNT)`，并从属于两个 `group：system:serviceaccounts`
和 `system:serviceaccounts:(NAMESPACE)`。

## 创建 ServiceAccount
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
创建 ServiceAccount，会自动创建 [secret](../storage/secret.md)。上面的输出中，看到有一个 secret `jenkins-token-l9v7v` token 已经被自动创建，并被 ServiceAccount 引用：

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

设置非默认的 ServiceAccount，只需要在 pod 的 `spec.serviceAccountName` 字段中将 `name` 设置为想要用的 ServiceAccount 名字即可。

**在 pod 创建之初 ServiceAccount 就必须已经存在，否则创建将被拒绝**。

### 手动创建 ServiceAccount 的 API token
假设我们已经有了一个如上文提到的名为 `jenkins` 的 ServiceAccount，我们手动创建一个新的 secret。
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

新创建的 secret 取代了 `jenkins` 这个 ServiceAccount 原来的 API token。
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

## 添加 ImagePullSecrets
首先，创建一个 imagePullSecret，详见[这里](../storage/secret.md)。
然后，确认已创建。

修改 namespace 中的默认 ServiceAccount 使用该 secret 作为 imagePullSecret。
输出 `default` ServiceAccount 到 `default.yaml`:
```bash
$ kubectl get serviceaccounts default -o yaml > ./default.yaml
```
修改 `default.yaml`,添加 `{"imagePullSecrets": [{"name": "myregistrykey"}]}`：
```yml
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

现在，所有当前 namespace 中新创建的 pod 的 `spec` 中都会增加如下内容，不需要手动在每个 pod 的 yaml 文件中添加 imagePullSecrets：
```yml
spec:
  imagePullSecrets:
  - name: myregistrykey
```