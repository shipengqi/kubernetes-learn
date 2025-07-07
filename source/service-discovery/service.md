---
title: Service
---

Pod 是有生命周期的，它们可以被创建，也可以被销毁，并且创建 Pod 时， pod 会动态获取 IP 地址。也就是说 pod 的 ip 是变化的。所以当集群内的 pod 要访问另一个 pod 时，通过 ip 是不可靠的。

因为，Kubernetes 定义了 `Service` 对象。 **Service 是对一组提供相同功能的 Pods 的抽象，并为它们提供一个统一的入口**。

借助 Service，应用可以方便的实现服务发现与负载均衡，并实现应用的零宕机升级。Service 通过 [Label Selector](../cluster/label.html) 来选取服务后端，一般配合 Replication Controller 或者 Deployment 来保证后端容器的正常运行。这些匹配标签的 Pod IP 和端口列表组成 endpoints，由 `kube-proxy` 负责将服务 IP 负载均衡到这些 endpoints 上。

比如，一个 backend pod 要访问 mysql pod，mysql 有三个副本， backend 不需要关心 mysql pod 可能会发生的变化，Service 定义的抽象能够解耦这种关联。

```yml
kind: Service
apiVersion: v1
metadata:
  name: my-service
spec:
  selector:
    app: MyApp
  ports:
    - protocol: TCP
      port: 80
      targetPort: 9376
```

上述配置将创建一个名称为 `my-service` 的 Service 对象，它会将请求代理到使用 TCP 端口 9376，并且具有标签 `app=MyApp` 的 Pod 上。这个 Service 将被指派一个 IP 地址（通常称为 “Cluster IP”），它会被服务的代理使用。

Service 能够将一个接收端口映射到任意的 `targetPort`。 默认情况下，`targetPort` 将被设置为与 `port` 字段相同的值。`targetPort` 可以是一个字符串，引用了 backend Pod 的一个端口的名称。但是，实际指派给该端口名称的端口号，在每个 backend Pod 中可能并不相同。

## 类型

Service 有四种类型， `spec.type` 的取值以及行为如下：

- ClusterIP：默认类型，自动分配一个仅 cluster 内部可以访问的虚拟 IP
- NodePort：在 ClusterIP 基础上为 Service 在每台机器上绑定一个端口，这样就可以通过 `<NodeIP>:NodePort` 来访问该服务，简单的说就是暴露一个节点的端口。
如果 `kube-proxy` 设置了 `--nodeport-addresses=10.240.0.0/16`（v1.10 支持），那么该 NodePort 仅对设置在范围内的 IP 有效。
- LoadBalancer：在 NodePort 的基础上，借助 cloud provider 创建一个外部的负载均衡器，并将请求转发到 `<NodeIP>:NodePort`
- ExternalName：将服务通过 DNS CNAME 记录方式转发到指定的域名（通过 `spec.externlName` 设定）。需要 kube-dns 版本在 1.7 以上。

### NodePort

设置 `type` 的值为 "NodePort"，Kubernetes master 将从给定的配置范围内（默认：`30000-32767`）分配端口。
每个 Node 将从该端口（每个 Node 上的同一端口）代理到 Service。该端口将通过 Service 的 `spec.ports[*].nodePort` 字段被指定。

```yml
apiVersion: v1
kind: Service
metadata:
  name: mattermost-svc
  namespace: core
spec:
  type: NodePort
  ports:
  - name: mm-server
    port: 8065
    targetPort: 8065
    nodePort: 8065
  selector:
    app: mattermost
```

### LoadBalancer

使用支持外部负载均衡器的云提供商的服务，设置 `type` 的值为 "LoadBalancer"，将为 Service 提供负载均衡器。
负载均衡器是异步创建的，关于被提供的负载均衡器的信息将会通过 Service 的 `status.loadBalancer` 字段被发布出去。

```yml
kind: Service
apiVersion: v1
metadata:
  name: ingress-frontend-svc
  namespace: core
  labels:
    app: ingress-frontend
spec:
  type: LoadBalancer
  ports:
  - name: "https"
    port: 3000
    targetPort: 8443
  loadBalancerIP: 78.11.24.19
  selector:
    app: ingress-frontend
status:
  loadBalancer:
    ingress:
      - ip: 146.148.47.155
```

来自外部负载均衡器的流量将直接打到 backend Pod 上，不过实际它们是如何工作的，这要依赖于云提供商。 在这些情况下，将根据用户设置的 `loadBalancerIP` 来创建
负载均衡器。 某些云提供商允许设置 `loadBalancerIP`。如果没有设置 `loadBalancerIP`，将会给负载均衡器指派一个临时 IP。 如果设置了 `loadBalancerIP`，但云提供
商并不支持这种特性，那么设置的 `loadBalancerIP` 值将会被忽略掉。

## 外部 IP

如果外部的 IP 路由到集群中一个或多个 Node 上，Kubernetes Service 会被暴露给这些 `externalIPs`。 通过外部 IP（作为目的 IP 地址）进入
到集群，打到 Service 的端口上的流量，将会被路由到 Service 的 Endpoint 上。 `externalIPs` 不会被 Kubernetes 管理。

```yml
kind: Service
apiVersion: v1
metadata:
  name: my-service
spec:
  selector:
    app: MyApp
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 9376
  externalIPs:
    - 80.11.12.10
```

`externalIPs` 可以同任意的 ServiceType 来一起指定。 在下面的例子中，`my-service` 可以在 `80.11.12.10:80`（外部 IP:端口）上被客户端访问。

`externalIPs` 字段填入 IP 地址之后，`kube-proxy` 会增加对应的 `iptables` 规则， 当有以对应 IP 为目标的流量发送到 Node 节点时，iptables 将进行 NAT，将
流量转发到对应的服务上。一般情况下，很少会遇到服务器接受非自身绑定 IP 流量的情况，所以 `externalIPs` 不常被使用，但配合网络层的其他工具，
它可以实现给 Service 绑定外部 IP 的效果。

`externalIP` 是指能够被路由到 kubernetes 节点的 IP 地址，在公有云上，也就是我们所说的公网IP。

## 服务发现

Kubernetes 支持2种基本的服务发现模式 —— 环境变量和 DNS。

### 环境变量

当 Pod 运行在 Node 上，kubelet 会为每个活跃的 Service 添加一组环境变量。 它同时支持 [Docker links兼容](https://docs.docker.com/network/links/) 变量
（查看 `makeLinkVariables`）、简单的 `{SVCNAME}_SERVICE_HOST` 和 `{SVCNAME}_SERVICE_PORT` 变量，这里 Service 的名称需要大写，横线被转换成下划线。

举个例子，一个名称为 "redis-master" 的 Service 暴露了 TCP 端口 `6379`，同时给它分配了 Cluster IP 地址 `10.0.0.11`，这个 Service 生成了如下环境变量：

```sh
REDIS_MASTER_SERVICE_HOST=10.0.0.11
REDIS_MASTER_SERVICE_PORT=6379
REDIS_MASTER_PORT=tcp://10.0.0.11:6379
REDIS_MASTER_PORT_6379_TCP=tcp://10.0.0.11:6379
REDIS_MASTER_PORT_6379_TCP_PROTO=tcp
REDIS_MASTER_PORT_6379_TCP_PORT=6379
REDIS_MASTER_PORT_6379_TCP_ADDR=10.0.0.11
```

**这意味着一个 Pod 想要访问的一个 Service， 那么这个 Service 必须在 Pod 自己之前被创建，否则这些环境变量就不会被赋值。DNS 没有这个限制**。

### DNS

一个可选（强烈推荐）[集群插件](https://github.com/kubernetes/kubernetes/tree/master/cluster/addons) 是 DNS 服务器。
DNS 服务器监视着创建新 Service 的 Kubernetes API，从而为每一个 Service 创建一组 DNS 记录。如果整个集群的 DNS 一直被启用，那么所有的 Pod 应该能够自动对 Service 进行名称解析。

例如，有一个名称为 `chatbot-svc` 的 Service，它在 Kubernetes 集群中名为 `core` 的 Namespace 中，为 `chatbot-svc.core` 创建了一条 DNS 记录。
在名称为 `core` 的 Namespace 中的 Pod 可以直接通过 Service 的名称 `chatbot-svc` 访问该 service。 但是如果在另一个 Namespace 中的 Pod 必须
以全名 `chatbot-svc.core` 访问该 service。

Kubernetes 也支持对端口名称的 DNS SRV（Service）记录。 如果名称为 `chatbot-svc.core` 的 Service 有一个名为 "http" 的 TCP 端口，
可以对 "_http._tcp.chatbot-svc.core" 执行 DNS SRV 查询，得到 "http" 的端口号。

Kubernetes DNS 服务器是唯一的一种能够访问 `ExternalName` 类型的 Service 的方式。

## Service 定义

```yml
apiVersion: v1
kind: Service
metadata:
  name: chatbot-svc
  namespace: core
spec:
  ports:
  - name: slack-auth
    protocol: TCP
    port: 4000
    targetPort: 4000
  - name: msteams-auth
    port: 8080
    targetPort: 8080
  selector:
    app: chatbot
```

上面的例子定义了一个 `chatbot-svc` 的 service 对象，它会将请求代理到 pods 的 TCP 端口 4000 和 8080，并且 pod 的 label 要具有 `app: chatbot`。
**当服务需要多个端口时，每个端口都必须设置一个 `name` 字段**。

### 协议

Service、Endpoints 和 Pod 支持三种类型的协议：

- TCP
- UDP
- SCTP（Stream Control Transmission Protocol，流控制传输协议），用于通过IP网传输

如果 `protocol` 字段未定义，默认是 TCP。

## 不指定 selector 的 Service

在创建 Service 的时候，也可以不指定 Selectors，用来将 service 转发到 kubernetes 集群外部的服务（而不是 Pod）。例如：

- 希望在生产环境中使用外部的数据库集群，但测试环境使用自己的数据库。
- 希望服务指向另一个 Namespace 中或其它集群中的服务。
- 正在将工作负载转移到 Kubernetes 集群，和运行在 Kubernetes 集群之外的 backend。

两种方法定义没有 `selector` 的 Service。

### 自定义 endpoint

```yml
kind: Service
apiVersion: v1
metadata:
  name: my-service
spec:
  ports:
    - protocol: TCP
      port: 80
      targetPort: 9376
---
kind: Endpoints
apiVersion: v1
metadata:
  name: my-service
subsets:
  - addresses:
      - ip: 1.2.3.4
    ports:
      - port: 9376
```

> **Endpoints 的 IP 地址不能是 loopback `127.0.0.0/8`、link-local `169.254.0.0/16` 和 link-local 多播 `224.0.0.0/24`，也不能是 Kubernetes 中其他服务的 clusterIP**。

### DNS 转发

```yml
kind: Service
apiVersion: v1
metadata:
  name: my-service
  namespace: default
spec:
  type: ExternalName
  externalName: my.database.example.com
```

在 service 定义中指定 `externalName`。此时 DNS 服务会给 `<service-name>.<namespace>.svc.cluster.local` 创建一个 CNAME 记录，
其值为 `my.database.example.com`。并且，该服务不会自动分配 Cluster IP，需要通过 service 的 DNS 来访问。

## Headless Service

Headless Service 即不需要 Cluster IP 的服务。有时不需要或不想要负载均衡，以及单独的 Service IP。 遇到这种情况，
可以通过指定 Cluster IP（`spec.clusterIP`）的值为 `None` 来创建 Headless Service。

这个选项允许开发人员自由寻找他们自己的方式，从而降低与 Kubernetes 系统的耦合性。 应用仍然可以使用一种自注册的模式和适配器，对其它需要发现机制的系统能够很容易地基于这个 API 来构建。

对这类 Service 并不会分配 Cluster IP，`kube-proxy` 不会处理它们，而且平台也不会为它们进行负载均衡和路由。 DNS 如何实现自动配置，依赖于 Service 是否定义了 `selector`。

- 定义了 Selectors 的 Headless Service，Endpoint 控制器在 API 中创建了 `Endpoints` 记录，并且修改 DNS 配置返回 A 记录（地址），通过这个
地址直接到达 Service 的后端 Pod 上。
- 不定义 Selectors 的 Headless Service，但设置 `externalName`，即上面的 **DNS 转发**，通过 CNAME 记录处理。

```yml
apiVersion: v1
kind: Service
metadata:
  labels:
    app: nginx
  name: nginx
spec:
  clusterIP: None
  ports:
  - name: tcp-80-80-3b6tl
    port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: nginx
  sessionAffinity: None
  type: ClusterIP
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  labels:
    app: nginx
  name: nginx
  namespace: default
spec:
  replicas: 2
  revisionHistoryLimit: 5
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - image: nginx:latest
        imagePullPolicy: Always
        name: nginx
        resources:
          limits:
            memory: 128Mi
          requests:
            cpu: 200m
            memory: 128Mi
      dnsPolicy: ClusterFirst
      restartPolicy: Always
```

```sh
# 查询创建的 nginx 服务
$ kubectl get service --all-namespaces=true
NAMESPACE     NAME         CLUSTER-IP      EXTERNAL-IP      PORT(S)         AGE
default       nginx        None            <none>           80/TCP          5m
kube-system   kube-dns     172.26.255.70   <none>           53/UDP,53/TCP   1d
```

### Headless Service 原理

**Service 是 Kubernetes 项目中用来将一组 Pod 暴露给外界访问的一种机制**。比如，一个 Deployment 有 3 个 Pod，那么我就可以定义一个 Service。然后，用户只要能访问到这个 Service，它就能访问到某个具体的 Pod。

那么，这个 Service 又是如何被访问的呢？

**第一种方式，是以 Service 的 VIP（Virtual IP，即：虚拟 IP）方式**。比如：当我访问 10.0.23.1 这个 Service 的 IP 地址时，10.0.23.1 其实就是一个 VIP，它会把请求转发到该 Service 所代理的某一个 Pod 上。这里的具体原理，我会在后续的 Service 章节中进行详细介绍。

**第二种方式，就是以 Service 的 DNS 方式**。比如：这时候，只要我访问 “my-svc.my-namespace.svc.cluster.local”这条 DNS 记录，就可以访问到名叫 my-svc 的 Service 所代理的某一个 Pod。

而在第二种 Service DNS 的方式下，具体还可以分为两种处理方法：

1. 是 Normal Service。这种情况下，你访问“my-svc.my-namespace.svc.cluster.local”解析到的，正是 my-svc 这个 Service 的 VIP，后面的流程就跟 VIP 方式一致了。

2. 正是 **Headless Service。这种情况下，你访问 “my-svc.my-namespace.svc.cluster.local” 解析到的，直接就是 my-svc 代理的某一个 Pod 的 IP 地址**。可以看到，这里的区别在于，Headless Service 不需要分配一个 VIP，而是可以直接以 DNS 记录的方式解析出被代理 Pod 的 IP 地址。

这样的设计又有什么作用呢？

下面是一个标准的 Headless Service 对应的 YAML 文件：

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  ports:
  - port: 80
    name: web
  clusterIP: None
  selector:
    app: nginx
```

所谓的 Headless Service，其实仍是一个标准 Service 的 YAML 文件。只不过，它的 **clusterIP 字段的值是：None，即：这个 Service，没有一个 VIP 作为“头”**。这也就是 Headless 的含义。所以，这个 Service 被创建后并不会被分配一个 VIP，而是会以 DNS 记录的方式暴露出它所代理的 Pod。

所有携带了 `app=nginx` 标签的 Pod，都会被这个 Service 代理起来。

然后关键来了。

按照这样的方式创建了一个 Headless Service 之后，它所代理的所有 Pod 的 IP 地址，都会被绑定一个这样格式的 DNS 记录，如下所示：

```
<pod-name>.<svc-name>.<namespace>.svc.cluster.local
```

**这个 DNS 记录，正是 Kubernetes 项目为 Pod 分配的唯一的“可解析身份”**（Resolvable Identity）。

有了这个“可解析身份”，**只要知道了一个 Pod 的名字，以及它对应的 Service 的名字，你就可以非常确定地通过这条 DNS 记录访问到 Pod 的 IP 地址**。

StatefulSet 又是如何使用这个 DNS 记录来维持 Pod 的拓扑状态的？

编写一个 StatefulSet 的 YAML 文件，如下所示：

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: "nginx"
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.9.1
        ports:
        - containerPort: 80
          name: web
```

这个 YAML 文件，多了一个 `serviceName=nginx` 字段。

这个字段的作用，就是告诉 StatefulSet 控制器，在执行控制循环（Control Loop）的时候，请使用 `nginx` 这个 Headless Service 来保证 Pod 的“可解析身份”。

所以，当你通过 kubectl create 创建了上面这个 Service 和 StatefulSet 之后，就会看到如下两个对象：

```bash
$ kubectl create -f svc.yaml
$ kubectl get service nginx
NAME      TYPE         CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
nginx     ClusterIP    None         <none>        80/TCP    10s
 
$ kubectl create -f statefulset.yaml
$ kubectl get statefulset web
NAME      DESIRED   CURRENT   AGE
web       2         1         19s
```

如果你手比较快的话（如果手不够快的话，Pod 很快就创建完了。不过，你依然可以通过这个 StatefulSet 的 Events 看到这些信息），还可以通过 kubectl 的 `-w` 参数，即：Watch 功能，实时查看 StatefulSet 创建两个有状态实例的过程：

```bash
$ kubectl get pods -w -l app=nginx
NAME      READY     STATUS    RESTARTS   AGE
web-0     0/1       Pending   0          0s
web-0     0/1       Pending   0         0s
web-0     0/1       ContainerCreating   0         0s
web-0     1/1       Running   0         19s
web-1     0/1       Pending   0         0s
web-1     0/1       Pending   0         0s
web-1     0/1       ContainerCreating   0         0s
web-1     1/1       Running   0         20s
```

这个 Pod 的创建过程，不难看到，StatefulSet 给它所管理的所有 Pod 的名字，进行了编号，编号规则是：`-`。

而且这些编号都是从 0 开始累加，与 StatefulSet 的每个 Pod 实例一一对应，绝不重复。

**更重要的是，这些 Pod 的创建，也是严格按照编号顺序进行的**。比如，在 web-0 进入到 Running 状态、并且细分状态（Conditions）成为 Ready 之前，web-1 会一直处于 Pending 状态。

当这两个 Pod 都进入了 Running 状态之后，你就可以查看到它们各自唯一的“网络身份”了。

使用 `kubectl exec` 命令进入到容器中查看它们的 hostname：

```bash
$ kubectl exec web-0 -- sh -c 'hostname'
web-0
$ kubectl exec web-1 -- sh -c 'hostname'
web-1
```

这两个 Pod 的 hostname 与 Pod 名字是一致的，都被分配了对应的编号。接下来，我们再试着以 DNS 的方式，访问一下这个 Headless Service：

```bash
$ kubectl run -i --tty --image busybox dns-test --restart=Never --rm /bin/sh 
```


通过这条命令，启动了一个一次性的 Pod，因为–rm 意味着 Pod 退出后就会被删除掉。然后，在这个 Pod 的容器里面，我们尝试用 nslookup 命令，解析一下 Pod 对应的 Headless Service：

```bash
$ kubectl run -i --tty --image busybox dns-test --restart=Never --rm /bin/sh
$ nslookup web-0.nginx
Server:    10.0.0.10
Address 1: 10.0.0.10 kube-dns.kube-system.svc.cluster.local
 
Name:      web-0.nginx
Address 1: 10.244.1.7
 
$ nslookup web-1.nginx
Server:    10.0.0.10
Address 1: 10.0.0.10 kube-dns.kube-system.svc.cluster.local
 
Name:      web-1.nginx
Address 1: 10.244.2.7
```


在另外一个 Terminal 里把这两个“有状态应用”的 Pod 删掉：

```bash
$ kubectl delete pod -l app=nginx
pod "web-0" deleted
pod "web-1" deleted
```

然后，再在当前 Terminal 里 Watch 一下这两个 Pod 的状态变化，就会发现一个有趣的现象：

```bash
$ kubectl get pod -w -l app=nginx
NAME      READY     STATUS              RESTARTS   AGE
web-0     0/1       ContainerCreating   0          0s
NAME      READY     STATUS    RESTARTS   AGE
web-0     1/1       Running   0          2s
web-1     0/1       Pending   0         0s
web-1     0/1       ContainerCreating   0         0s
web-1     1/1       Running   0         32s
```

可以看到，当我们把这两个 Pod 删除之后，Kubernetes 会按照原先编号的顺序，创建出了两个新的 Pod。并且，Kubernetes 依然为它们分配了与原来相同的“网络身份”：`web-0.nginx` 和 `web-1.nginx`。

通过这种严格的对应规则，**StatefulSet 就保证了 Pod 网络标识的稳定性**。

再用 nslookup 命令，查看一下这个新 Pod 对应的 Headless Service 的话：

```bash
$ kubectl run -i --tty --image busybox dns-test --restart=Never --rm /bin/sh 
$ nslookup web-0.nginx
Server:    10.0.0.10
Address 1: 10.0.0.10 kube-dns.kube-system.svc.cluster.local
 
Name:      web-0.nginx
Address 1: 10.244.1.8
 
$ nslookup web-1.nginx
Server:    10.0.0.10
Address 1: 10.0.0.10 kube-dns.kube-system.svc.cluster.local
 
Name:      web-1.nginx
Address 1: 10.244.2.8
```

在这个 StatefulSet 中，这两个新 Pod 的“网络标识”（比如：`web-0.nginx` 和 `web-1.nginx`），再次解析到了正确的 IP 地址。


**Kubernetes 就成功地将 Pod 的拓扑状态（比如：哪个节点先启动，哪个节点后启动），按照 Pod 的“名字 + 编号”的方式固定了下来**。此外，Kubernetes 还为每一个 Pod 提供了一个固定并且唯一的访问入口，即：这个 Pod 对应的 DNS 记录。