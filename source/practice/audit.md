---
title: 审计日志
---

# 审计日志
Kubernetes 审计（Audit）提供了安全相关的时序操作记录，可以记录所有对 apiserver 接口的调用，让我们能够非常清晰的知道集群到底发生了什么事情，通过记录的日志可以查到所发生的事件、操作的用户和时间。

支持**日志**和 **webhook** 两种格式，并可以通过审计策略自定义事件类型。

## 审计日志的策略
### 日志记录阶段
kube-apiserver 是负责接收及响应用户请求的一个组件，每一个请求都会有几个阶段，每个阶段都有对应的日志，当前支持的阶段有：
- RequestReceived - apiserver 在接收到请求后且在将该请求下发之前会生成对应的审计日志。
- ResponseStarted - 在响应 header 发送后并在响应 body 发送前生成日志。这个阶段仅为长时间运行的请求生成（例如 watch）。
- ResponseComplete - 当响应 body 发送完并且不再发送数据。
- Panic - 当有 panic 发生时生成。

也就是说 apiserver 的每一个请求理论上会有三个阶段的审计日志生成。

### 日志记录级别
当前支持的日志记录级别有：

- None - 不记录日志。
- Metadata - 只记录 Request 的一些 metadata (例如 `user`, `timestamp`, `resource`, `verb` 等)，但不记录 Request 或 Response 的 body。
- Request - 记录 Request 的 metadata 和 body。
- RequestResponse - 最全记录方式，会记录所有的 metadata、Request 和 Response 的 body。

### 日志记录策略
启用审计日志会增加 apiserver 对内存的使用量。记录日志的时尽量只记录所需要的信息，避免造成系统资源的浪费。

- 一个请求不要重复记录，每个请求有三个阶段，只记录其中需要的阶段
- 不要记录所有的资源，不要记录一个资源的所有子资源
- 系统的请求不需要记录 `kubelet`、`kube-proxy`、`kube-scheduler`、`kube-controller-manager` 等对 `kube-apiserver` 的请求
- 对一些认证信息（`secerts`、`configmaps`、`token` 等）的 body 不记录

可以使用 `--audit-policy-file` 标志将包含策略的文件传递给 kube-apiserver。如果不设置该标志，则不记录事件。 注意 **`rules` 字段必须在审计策略文件中提供**。

审计策略文件的示例：
```yml
apiVersion: audit.k8s.io/v1beta1 # This is required.
kind: Policy
# Don't generate audit events for all requests in RequestReceived stage.
omitStages:
  - "RequestReceived"
rules:
  # Log pod changes at RequestResponse level
  - level: RequestResponse
    resources:
    - group: ""
      # Resource "pods" doesn't match requests to any subresource of pods,
      # which is consistent with the RBAC policy.
      resources: ["pods"]
  # Log "pods/log", "pods/status" at Metadata level
  - level: Metadata
    resources:
    - group: ""
      resources: ["pods/log", "pods/status"]

  # Don't log requests to a configmap called "controller-leader"
  - level: None
    resources:
    - group: ""
      resources: ["configmaps"]
      resourceNames: ["controller-leader"]

  # Don't log watch requests by the "system:kube-proxy" on endpoints or services
  - level: None
    users: ["system:kube-proxy"]
    verbs: ["watch"]
    resources:
    - group: "" # core API group
      resources: ["endpoints", "services"]

  # Don't log authenticated requests to certain non-resource URL paths.
  - level: None
    userGroups: ["system:authenticated"]
    nonResourceURLs:
    - "/api*" # Wildcard matching.
    - "/version"

  # Log the request body of configmap changes in kube-system.
  - level: Request
    resources:
    - group: "" # core API group
      resources: ["configmaps"]
    # This rule only applies to resources in the "kube-system" namespace.
    # The empty string "" can be used to select non-namespaced resources.
    namespaces: ["kube-system"]

  # Log configmap and secret changes in all other namespaces at the Metadata level.
  - level: Metadata
    resources:
    - group: "" # core API group
      resources: ["secrets", "configmaps"]

  # Log all other resources in core and extensions at the Request level.
  - level: Request
    resources:
    - group: "" # core API group
    - group: "extensions" # Version of group should NOT be included.

  # A catch-all rule to log all other requests at the Metadata level.
  - level: Metadata
    # Long-running requests like watches that fall under this rule will not
    # generate an audit event in RequestReceived.
    omitStages:
      - "RequestReceived"
---
apiVersion: audit.k8s.io/v1beta1
kind: Policy
rules:
  # The following requests were manually identified as high-volume and low-risk,
  # so drop them.
  - level: None
    resources:
      - group: ""
        resources:
          - endpoints
          - services
          - services/status
    users:
      - 'system:kube-proxy'
    verbs:
      - watch

  - level: None
    resources:
      - group: ""
        resources:
          - nodes
          - nodes/status
    userGroups:
      - 'system:nodes'
    verbs:
      - get

  - level: None
    namespaces:
      - kube-system
    resources:
      - group: ""
        resources:
          - endpoints
    users:
      - 'system:kube-controller-manager'
      - 'system:kube-scheduler'
      - 'system:serviceaccount:kube-system:endpoint-controller'
    verbs:
      - get
      - update

  - level: None
    resources:
      - group: ""
        resources:
          - namespaces
          - namespaces/status
          - namespaces/finalize
    users:
      - 'system:apiserver'
    verbs:
      - get

  # Don't log HPA fetching metrics.
  - level: None
    resources:
      - group: metrics.k8s.io
    users:
      - 'system:kube-controller-manager'
    verbs:
      - get
      - list

  # Don't log these read-only URLs.
  - level: None
    nonResourceURLs:
      - '/healthz*'
      - /version
      - '/swagger*'

  # Don't log events requests.
  - level: None
    resources:
      - group: ""
        resources:
          - events

  # node and pod status calls from nodes are high-volume and can be large, don't log responses for expected updates from nodes
  - level: Request
    omitStages:
      - RequestReceived
    resources:
      - group: ""
        resources:
          - nodes/status
          - pods/status
    users:
      - kubelet
      - 'system:node-problem-detector'
      - 'system:serviceaccount:kube-system:node-problem-detector'
    verbs:
      - update
      - patch

  - level: Request
    omitStages:
      - RequestReceived
    resources:
      - group: ""
        resources:
          - nodes/status
          - pods/status
    userGroups:
      - 'system:nodes'
    verbs:
      - update
      - patch

  # deletecollection calls can be large, don't log responses for expected namespace deletions
  - level: Request
    omitStages:
      - RequestReceived
    users:
      - 'system:serviceaccount:kube-system:namespace-controller'
    verbs:
      - deletecollection

  # Secrets, ConfigMaps, and TokenReviews can contain sensitive & binary data,
  # so only log at the Metadata level.
  - level: Metadata
    omitStages:
      - RequestReceived
    resources:
      - group: ""
        resources:
          - secrets
          - configmaps
      - group: authentication.k8s.io
        resources:
          - tokenreviews
  # Get repsonses can be large; skip them.
  - level: Request
    omitStages:
      - RequestReceived
    resources:
      - group: ""
      - group: admissionregistration.k8s.io
      - group: apiextensions.k8s.io
      - group: apiregistration.k8s.io
      - group: apps
      - group: authentication.k8s.io
      - group: authorization.k8s.io
      - group: autoscaling
      - group: batch
      - group: certificates.k8s.io
      - group: extensions
      - group: metrics.k8s.io
      - group: networking.k8s.io
      - group: policy
      - group: rbac.authorization.k8s.io
      - group: scheduling.k8s.io
      - group: settings.k8s.io
      - group: storage.k8s.io
    verbs:
      - get
      - list
      - watch

  # Default level for known APIs
  - level: RequestResponse
    omitStages:
      - RequestReceived
    resources:
      - group: ""
      - group: admissionregistration.k8s.io
      - group: apiextensions.k8s.io
      - group: apiregistration.k8s.io
      - group: apps
      - group: authentication.k8s.io
      - group: authorization.k8s.io
      - group: autoscaling
      - group: batch
      - group: certificates.k8s.io
      - group: extensions
      - group: metrics.k8s.io
      - group: networking.k8s.io
      - group: policy
      - group: rbac.authorization.k8s.io
      - group: scheduling.k8s.io
      - group: settings.k8s.io
      - group: storage.k8s.io

  # Default level for all other requests.
  - level: Metadata
    omitStages:
      - RequestReceived
```

可以使用最低限度的审计策略文件在 Metadata 级别记录所有请求：
```yml
# Log all requests at the Metadata level.
apiVersion: audit.k8s.io/v1beta1
kind: Policy
rules:
- level: Metadata
```

## 审计后端
审计存储后端支持两种方式
- Log 后端
- Webhook 后端

### Log 后端
Log 后端将审计事件写入 JSON 格式的文件。使用以下 kube-apiserver 标志配置 Log 审计后端：

- `--audit-log-path` 指定用来写入审计事件的日志文件路径。**不指定此标志会禁用日志后端**。`-` 意味着标准化
- `--audit-log-maxage` 定义了保留旧审计日志文件的最大天数
- `--audit-log-maxbackup` 定义了要保留的审计日志文件的最大数量
- `--audit-log-maxsize` 定义审计日志文件的最大大小（兆字节）

Log 配置文件示例：
```yml
apiVersion: v1
kind: Pod
metadata:
  name: apiserver
  namespace: kube-system
  annotations:
    scheduler.alpha.kubernetes.io/critical-pod: ""
spec:
  containers:
  - command:
    - /hyperkube
    - apiserver
    ...
    - --audit-policy-file=/etc/kubernetes/cfg/audit-policy.yaml
    - --audit-log-path=/var/log/kube-audit/audit.log # 这里必须是文件路径
    ...
    image: k8s.gcr.io/hyperkube:v1.13.5
    imagePullPolicy: IfNotPresent
    securityContext:
      runAsUser: 1999
    ...
    volumeMounts:
    - mountPath: /var/log/kube-audit
      name: kube-audit
    - mountPath: /etc/kubernetes/cfg/audit-policy.yaml
      name: audit-policy
      readOnly: true
  ...
  volumes:
  - hostPath:
      path: /var/log/kube-audit
    name: kube-audit
  - hostPath:
      path: /opt/kubernetes/cfg/audit-policy.yaml
    name: audit-policy
```

上面的示例中由于 pod 的 user 是 `1999`，所以 `/var/log/kube-audit` 的 owner 也必须是 `1999`，否则会报 `permission denied`，像下面的错误：
```sh
kube-apiserver[1574]: E1105 18:43:54.090393 1574 metrics.go:86] Error in audit plugin 'log' affecting 1 audit
 events: can't open new logfile: open /var/lib/audit.log: permission denied
```
可以使用 `chown` 命令。

### Webhook 后端
Webhook 配置文件实际上是一个 `kubeconfig` 文件，apiserver 会将审计日志发送到指定的 webhook 后，webhook 接收到日志后可以再分发到 kafka 或其他组件进行收集。
使用如下 `kube-apiserver` 标志来配置 webhook 审计后端：
- `--audit-webhook-config-file` webhook 配置文件的路径。
- `--audit-webhook-initial-backoff` 指定在第一次失败后重发请求等待的时间。随后的请求将以指数退避重试。

Webhook 配置文件示例：
```yml
# clusters refers to the remote service.
clusters:
  - name: name-of-remote-audit-service
    cluster:
      certificate-authority: /path/to/ca.pem  # CA for verifying the remote service.
      server: https://audit.example.com/audit # URL of remote service to query. Must use 'https'.

# users refers to the API server's webhook configuration.
users:
  - name: name-of-api-server
    user:
      client-certificate: /path/to/cert.pem # cert for the webhook plugin to use
      client-key: /path/to/key.pem          # key matching the cert

# kubeconfig files require a context. Provide one for the API server.
current-context: webhook
contexts:
- context:
    cluster: name-of-remote-audit-service
    user: name-of-api-sever
  name: webhook
---
# another example
apiVersion: v1
clusters:
- cluster:
    server: http://127.0.0.1:8081/audit/webhook
  name: metric
contexts:
- context:
    cluster: metric
    user: ""
  name: default-context
current-context: default-context
kind: Config
preferences: {}
users: []
```

所有的事件以 JSON 格式 POST 给 webhook server，如
```js
{
  "kind": "EventList",
  "apiVersion": "audit.k8s.io/v1alpha1",
  "items": [
    {
      "metadata": {
        "creationTimestamp": null
      },
      "level": "Metadata",
      "timestamp": "2017-06-15T23:07:40Z",
      "auditID": "4faf711a-9094-400f-a876-d9188ceda548",
      "stage": "ResponseComplete",
      "requestURI": "/apis/rbac.authorization.k8s.io/v1beta1/namespaces/kube-public/rolebindings/system:controller:bootstrap-signer",
      "verb": "get",
      "user": {
        "username": "system:apiserver",
        "uid": "97a62906-e4d7-4048-8eda-4f0fb6ff8f1e",
        "groups": [
          "system:masters"
        ]
      },
      "sourceIPs": [
        "127.0.0.1"
      ],
      "objectRef": {
        "resource": "rolebindings",
        "namespace": "kube-public",
        "name": "system:controller:bootstrap-signer",
        "apiVersion": "rbac.authorization.k8s.io/v1beta1"
      },
      "responseStatus": {
        "metadata": {},
        "code": 200
      }
    }
  ]
}
```

#### webhook 的一个简单示例
```go
package main

import (
    "encoding/json"
    "io/ioutil"
    "log"
    "net/http"

    "github.com/emicklei/go-restful"
    "github.com/gosoon/glog"
    "k8s.io/apiserver/pkg/apis/audit"
)

func main() {
    // NewContainer creates a new Container using a new ServeMux and default router (CurlyRouter)
    container := restful.NewContainer()
    ws := new(restful.WebService)
    ws.Path("/audit").
        Consumes(restful.MIME_JSON).
        Produces(restful.MIME_JSON)
    ws.Route(ws.POST("/webhook").To(AuditWebhook))

    //WebService ws2被添加到container2中
    container.Add(ws)
    server := &http.Server{
        Addr:    ":8081",
        Handler: container,
    }
    //go consumer()
    log.Fatal(server.ListenAndServe())
}

func AuditWebhook(req *restful.Request, resp *restful.Response) {
    body, err := ioutil.ReadAll(req.Request.Body)
    if err != nil {
        glog.Errorf("read body err is: %v", err)
    }
    var eventList audit.EventList
    err = json.Unmarshal(body, &eventList)
    if err != nil {
        glog.Errorf("unmarshal failed with:%v,body is :\n", err, string(body))
        return
    }
    for _, event := range eventList.Items {
        jsonBytes, err := json.Marshal(event)
        if err != nil {
            glog.Infof("marshal failed with:%v,event is \n %+v", err, event)
        }
        // 消费日志
        asyncProducer(string(jsonBytes))
    }
    resp.AddHeader("Content-Type", "application/json")
    resp.WriteEntity("success")
}
```

### Batching
log 和 webhook 后端都支持 batch。 默认情况下，在 webhook 中启用 batch，在 log 中禁用 batch。同样，默认情况下，在 webhook 中启用限制，在 log 中禁用限制。
以 webhook 为例，以下是可用参数列表。要**获取 log 后端的同样参数，在参数名称中将 `webhook` 替换为 `log`**：
- `--audit-webhook-mode` 定义缓存策略，可选值如下：
  - `batch` - 以批处理缓存事件和异步的过程。这是默认值。
  - `blocking` - 阻止 API server 处理每个单独事件的响应。

以下参数仅用于 batch 模式：
- `--audit-webhook-batch-buffer-size` 定义 batch 之前要缓存的事件数。 如果传入事件的速率溢出缓存区，则会丢弃事件。
- `--audit-webhook-batch-max-size` 定义一个 batch 中的最大事件数。
- `--audit-webhook-batch-max-wait` 无条件 batch 队列中的事件前等待的最大事件。
- `--audit-webhook-batch-throttle-qps` 每秒生成的最大 batch 平均值。
- `--audit-webhook-batch-throttle-burst` 在达到允许的 QPS 前，同一时刻允许存在的最大 batch 生成数