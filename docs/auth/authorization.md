# 授权

## ABAC
使用 ABAC（Attribute Based Access Control）授权需要在启动 API Server 时配置 `--authorization-policy-file=SOME_FILENAME` 和 `--authorization-mode=ABAC`，
文件格式为每行一个 `policy` 对象，比如
```js
{
    "apiVersion": "abac.authorization.kubernetes.io/v1beta1",
    "kind": "Policy",
    "spec": {
        "group": "system:authenticated",
        "nonResourcePath": "*",
        "readonly": true
    }
}
{
    "apiVersion": "abac.authorization.kubernetes.io/v1beta1",
    "kind": "Policy",
    "spec": {
        "group": "system:unauthenticated",
        "nonResourcePath": "*",
        "readonly": true
    }
}
{
    "apiVersion": "abac.authorization.kubernetes.io/v1beta1",
    "kind": "Policy",
    "spec": {
        "user": "admin",
        "namespace": "*",
        "resource": "*",
        "apiGroup": "*"
    }
}
```

参考[这里](https://kubernetes.io/docs/reference/access-authn-authz/abac/)

## RBAC
参考[这里](./rbac.md)

## WebHook 授权
使用 WebHook 授权需要 API Server 配置 `--authorization-webhook-config-file=<file>` 和 `--runtime-config=authorization.k8s.io/v1beta1=true`，
配置文件格式同 `kubeconfig`，如
```yml
# clusters refers to the remote service.
clusters:
  - name: name-of-remote-authz-service
    cluster:
      # CA for verifying the remote service.
      certificate-authority: /path/to/ca.pem
      # URL of remote service to query. Must use 'https'.
      server: https://authz.example.com/authorize

# users refers to the API Server's webhook configuration.
users:
  - name: name-of-api-server
    user:
      # cert for the webhook plugin to use
      client-certificate: /path/to/cert.pem
       # key matching the cert
      client-key: /path/to/key.pem

# kubeconfig files require a context. Provide one for the API Server.
current-context: webhook
contexts:
- context:
    cluster: name-of-remote-authz-service
    user: name-of-api-server
  name: webhook
```

参考[这里](https://kubernetes.io/docs/reference/access-authn-authz/webhook/)

## Node 授权
参考[这里](https://kubernetes.io/docs/reference/access-authn-authz/node/)