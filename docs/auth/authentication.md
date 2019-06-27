# 认证

Kubernetes 支持多种认证机制，并支持同时开启多个认证插件。**开启 TLS 时，所有的请求都需要首先认证**。

## X509 证书
使用 X509 客户端证书只需要 API Server 启动时配置 `--client-ca-file=SOMEFILE`。在证书**认证时，其 Common Name（CN）域用作用户名，而 Organization（O）域则用作 group 名**。

创建一个客户端证书：
```sh
# Create private key
openssl genrsa -out username.key 2048
# Create CSR (certificate signing request)
openssl req -new -key username.key -out username.csr -subj "/CN=username/O=group"
# Create certificate from CSR using the cluster authority
openssl x509 -req -in username.csr -CA $CA_LOCATION/ca.crt -CAkey $CA_LOCATION/ca.key -CAcreateserial -out username.crt -days 365
```

例如，目前我们的 kubernetes 集群就是 X509 证书认证并结合 RBAC。
集群中 dashboard 组件访问 API server 就是使用的证书认证，证书的 CN 是 `k8s-dashboard-svc.core`，dashboard 的 pod 需要 `cluster-admin` 权限，所以
我们又为 dashboard 了 `ClusterRoleBinding`：
```yml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cdf:dashboard:cluster-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: User
  name: k8s-dashboard-svc.core
  apiGroup: rbac.authorization.k8s.io
```

下面是 dashboard `--kubeconfig=<kubeconfig>` 的具体配置：
```yml
apiVersion: v1
kind: Config
clusters:
  - cluster:
      certificate-authority: {HOME_DIR}/ssl/ca.crt
      server: https://{K8S_APISERVER_IP}:{MASTER_API_SSL_PORT}
    name: kubernetes
contexts:
  - context:
      cluster: kubernetes
      user: kubelet
    name: kubelet-to-kubernetes
current-context: kubelet-to-kubernetes
users:
  - name: kubelet
    user:
      client-certificate: {HOME_DIR}/ssl/{PREFIX}.crt
      client-key: {HOME_DIR}/ssl/{PREFIX}.key
```


## 静态 Token 文件
使用静态 Token 文件认证只需要 API Server 启动时配置 `--token-auth-file=SOMEFILE`。该文件为 csv 格式，每行至少包括三列 token,username,user id，后面是可选的 group 名，如：
```
token,user,uid,"group1,group2,group3"
```
## 引导 Token
## 静态密码文件
## ServiceAccount
## OpenID
## Webhook