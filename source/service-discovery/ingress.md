---
title: Ingress
---
# Ingress
Ingress 是从 Kubernetes 集群外部访问集群内部服务的入口。

需要一个 Ingress Controller 来实现 Ingress，单纯的创建一个 Ingress 没有任何意义。

通常情况下，service 和 pod 的 IP 仅可在集群内部访问。集群外部的请求需要通过负载均衡转发到 service 在 Node 上暴露的 NodePort 上，然后再由 `kube-proxy` 通过边缘
路由器 (edge router) 将其转发给相关的 Pod 或者丢弃。而 Ingress 就是为进入集群的请求提供路由规则的集合。

如果你的集群使用的是 [ingress-nginx](https://github.com/kubernetes/ingress-nginx)，那么可以把 Ingress 资源对象理解为 nginx 的配置文件（如 conf/<your config>.conf），
Ingress controller 监听 Ingress 和 service 的变化，并根据规则配置负载均衡并提供访问入口。

## Ingress 格式
```yml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: chatbot-ingress-tls
  namespace: {NAMESPACE}
  annotations:
    ingress.kubernetes.io/secure-backends: "true" # 如果后端服务启用了 tls
    ingress.kubernetes.io/proxy-body-size: 60m    # http body 的 size limit
    kubernetes.io/ingress.class: "nginx"
spec:
  rules:
  - host: {EXTERNAL_ACCESS_HOST}
    http:
      paths:
      - backend:
          serviceName: chatbot-svc
          servicePort: 3000
        path: /chatbot/urest/v1
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: chatbot-ingress
  namespace: {NAMESPACE}
spec:
  rules:
  - host: bar.foo.com
    http:
      paths:
      # msteams used
      - backend:
          serviceName: chatbot-svc
          servicePort: 8080
        path: /chatbot/v1/msteams/msteamsbot
```
每个 Ingress 都需要配置 `rules`，目前 Kubernetes 仅支持 `http` 规则。上面的示例表示分别将请求 `/chatbot/urest/v1` 和 `/chatbot/v1/msteams/msteamsbot`
转发到服务 `chatbot-svc` 的 3000 端口和 8080 端口。 `http.paths` 可以配置多个服务。`rules.host` 是可选的，如果配置了 `host`，如果请求 `header` 中的 `host`
不能跟 `ingress` 中的 `host` 匹配，或请求的 URL 不能与任何一个 `path` 匹配，则流量将路由到你的默认 backend。

更多配置查看[这里](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/)。

### 默认 backend
默认 backend 是一个没有 `rules` 的 ingress：
```yml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: test-ingress
spec:
  backend:
    serviceName: testsvc
    servicePort: 80
```

## TLS
可以通过指定包含 TLS 私钥和证书的 secret 来加密 Ingress。TLS secret 中必须包含名为 `tls.crt` 和 `tls.key` 的密钥，这里面包含了用于 TLS 的证书和私钥，例如：
```yml
apiVersion: v1
data:
  tls.crt: base64 encoded cert
  tls.key: base64 encoded key
kind: Secret
metadata:
  name: testsecret
  namespace: default
type: Opaque
```

在 Ingress 中引用这个 secret 将通知 Ingress controller 使用 TLS 加密从将客户端到 loadbalancer 的 channel：
```yml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: no-rules-map
spec:
  tls:
    - secretName: testsecret
  backend:
    serviceName: s1
    servicePort: 80
```

## 更新 Ingress
假如想要向已有的 ingress 中增加一个新的 `host`，你可以编辑和更新该 ingress：
```sh
$ kubectl get ing
NAME      RULE          BACKEND   ADDRESS
test      -                       178.91.123.132
          foo.bar.com
          /foo          s1:80
$ kubectl edit ing test
```
然后修改并保存。保存会更新 API server 中的资源，这会触发 ingress controller 重新配置 loadbalancer。

在一个修改过的 ingress yml 文件上调用 `kubectl replace -f` 命令一样可以达到同样的效果。

## Ingress Controller
Ingress Controller 与其他作为 `kube-controller-manage`r 中的在集群创建时自动启动的 controller 成员不同，需要用户选择最适合自己
集群的 Ingress Controller，或者自己实现一个。

Ingress Controller 以 Kubernetes Pod 的方式部署，以 daemon 方式运行，保持 watch Apiserver 的 `/ingress` 接口以更新 Ingress 资源，
以满足 Ingress 的请求。比如可以使用 [Nginx Ingress Controller](https://github.com/kubernetes/ingress-nginx)：
```sh
helm install stable/nginx-ingress --name nginx-ingress --set rbac.create=true
```