---
title: Kubernetes learning
---

Kubernetes 项目的本质，是为用户提供一个具有普遍意义的容器编排工具。

不过，更重要的是，Kubernetes 项目为用户提供的不仅限于一个工具。它真正的价值，乃在于提供了**一套基于容器构建分布式系统的基础依赖**。

## 运行一个应用

Kubernetes 跟 Docker 等很多项目最大的不同，就在于它不推荐你使用命令行的方式直接运行容器（虽然 Kubernetes 项目也支持这种方式，比如：`kubectl run`），而是希望你用 YAML 文件的方式，即：把容器的定义、参数、配置，统统记录在一个 YAML 文件中，然后用这样一句指令把它运行起来：

```bash
$ kubectl create -f 配置文件
```

这么做最直接的好处是，会有一个文件能记录下 Kubernetes 到底“run”了什么。比如下面这个例子：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 2
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.7.9
        ports:
        - containerPort: 80
```

- `kind` 字段，指定了这个 API 对象的类型（Type），是一个 Deployment。所谓 Deployment，是一个定义多副本应用（即多个副本 Pod）的对象，还负责在 Pod 定义发生变化时，对每个副本进行滚动更新（Rolling Update）。
- 这个文件定义的 Pod 副本个数 (`spec.replicas`) 是：2。
- Pod 里只有一个容器，这个容器的镜像（`spec.containers.image`）是 `nginx:1.7.9`，这个容器监听端口（`containerPort`）是 80。

**Pod 就是 Kubernetes 世界里的“应用”；而一个应用，可以由多个容器组成**。

**像这样使用一种 API 对象（Deployment）管理另一种 API 对象（Pod）的方法，在 Kubernetes 中，叫作“控制器”模式**（controller pattern）。Deployment 扮演的正是 Pod 的控制器的角色。

每一个 API 对象都有一个叫作 Metadata 的字段，这个字段就是 API 对象的“标识”，即**元数据**，它也是从 Kubernetes 里找到这个对象的主要依据。这其中最主要使用到的字段是 Labels。

Labels 就是一组 key-value 格式的标签。而像 Deployment 这样的控制器对象，就可以**通过这个 Labels 字段从 Kubernetes 中过滤出它所关心的被控制对象**。

这个 YAML 文件中，Deployment 会把所有正在运行的、携带 “app: nginx” 标签的 Pod 识别为被管理的对象，并确保这些 Pod 的总数严格等于两个。

Deployment 的“spec.selector.matchLabels”字段。一般称之为：Label Selector。

另外，在 Metadata 中，还有一个与 Labels 格式、层级完全相同的字段叫 Annotations，它专门用来携带 `key-value `格式的内部信息。所谓内部信息，指的是对这些信息感兴趣的，是 Kubernetes 组件本身，而不是用户。所以大多数 Annotations，都是在 Kubernetes 运行过程中，被自动加在这个 API 对象上。

一个 Kubernetes 的 **API 对象的定义，大多可以分为 Metadata 和 Spec 两个部分**。前者存放的是这个对象的元数据，对所有 API 对象来说，这一部分的字段和格式基本上是一样的；而后者存放的，则是属于这个对象独有的定义，用来描述它所要表达的功能。

```bash
$ kubectl get pods -l app=nginx
NAME                                READY     STATUS    RESTARTS   AGE
nginx-deployment-67594d6bf6-9gdvr   1/1       Running   0          10m
nginx-deployment-67594d6bf6-v6j7w   1/1       Running   0          10m
```

**在命令行中，所有 `key-value` 格式的参数，都使用“=”而非“:”表示**。

还可以使用 `kubectl describe` 命令，查看一个 API 对象的细节，比如：

```bash
$ kubectl describe pod nginx-deployment-67594d6bf6-9gdvr
Name:               nginx-deployment-67594d6bf6-9gdvr
Namespace:          default
Priority:           0
PriorityClassName:  <none>
Node:               node-1/10.168.0.3
Start Time:         Thu, 16 Aug 2018 08:48:42 +0000
Labels:             app=nginx
                    pod-template-hash=2315082692
Annotations:        <none>
Status:             Running
IP:                 10.32.0.23
Controlled By:      ReplicaSet/nginx-deployment-67594d6bf6
...
Events:
 
  Type     Reason                  Age                From               Message
 
  ----     ------                  ----               ----               -------
  
  Normal   Scheduled               1m                 default-scheduler  Successfully assigned default/nginx-deployment-67594d6bf6-9gdvr to node-1
  Normal   Pulling                 25s                kubelet, node-1    pulling image "nginx:1.7.9"
  Normal   Pulled                  17s                kubelet, node-1    Successfully pulled image "nginx:1.7.9"
  Normal   Created                 17s                kubelet, node-1    Created container
  Normal   Started                 17s                kubelet, node-1    Started container
```

在 Kubernetes 执行的过程中，对 API 对象的**所有重要操作，都会被记录在这个对象的 Events 里**，并且显示在 `kubectl describe` 指令返回的结果中。

这个部分正是将来进行 Debug 的重要依据。**如果有异常发生，一定要第一时间查看这些 Events**，往往可以看到非常详细的错误信息。


如果要对这个 Nginx 服务进行升级，把它的镜像版本从 1.7.9 升级为 1.8，要怎么做呢？

只要修改这个 YAML 文件即可。

```yaml
...    
    spec:
      containers:
      - name: nginx
        image: nginx:1.8 # 这里被从 1.7.9 修改为 1.8
        ports:
      - containerPort: 80
```

然后使用 `kubectl replace` 指令来完成这个更新：

```bash
$ kubectl replace -f nginx-deployment.yaml
```

推荐使用 `kubectl apply` 命令，来统一进行 Kubernetes 对象的创建和更新操作，具体做法如下所示：

```bash
$ kubectl apply -f nginx-deployment.yaml
 
# 修改 nginx-deployment.yaml 的内容
 
$ kubectl apply -f nginx-deployment.yaml
```

这样的操作方法，是 Kubernetes“声明式 API”所推荐的使用方法。也就是说，作为用户，你不必关心当前的操作是创建，还是更新，你执行的命令始终是 kubectl apply，而 Kubernetes 则会根据 YAML 文件的内容变化，自动进行具体的处理。

Kubernetes 项目通过这些 YAML 文件，就保证了应用的“部署参数”在开发与部署环境中的一致性。

**而当应用本身发生变化时，开发人员和运维人员可以依靠容器镜像来进行同步；当应用部署参数发生变化时，这些 YAML 文件就是他们相互沟通和信任的媒介**。

### 定义 Volume

在 Kubernetes 中，Volume 是属于 Pod 对象的一部分。所以，我们就需要修改这个 YAML 文件里的 `template.spec` 字段，如下所示：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 2
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.8
        ports:
        - containerPort: 80
        volumeMounts:
        - mountPath: "/usr/share/nginx/html"
          name: nginx-vol
      volumes:
      - name: nginx-vol
        emptyDir: {}
```

volumes 字段定义了这个 Pod 声明的所有 Volume。它的名字叫作 `nginx-vol`，类型是 `emptyDir`。

#### emptyDir

什么是 `emptyDir` 类型呢？

它其实就等同于我们之前讲过的 Docker 的隐式 Volume 参数，即：不显式声明宿主机目录的 Volume。所以，**Kubernetes 也会在宿主机上创建一个临时目录，这个目录将来就会被绑定挂载到容器所声明的 Volume 目录上**。

{{< callout type="info" >}}
Kubernetes 的 `emptyDir` 类型，只是把 Kubernetes 创建的临时目录作为 Volume 的宿主机目录，替代了 Docker 创建的临时目录。
{{< /callout >}}

而 Pod 中的容器，使用的是 `volumeMounts` 字段来声明自己要挂载哪个 Volume，并通过` mountPath` 字段来定义容器内的 Volume 目录，比如：`/usr/share/nginx/html`。

#### hostPath

Kubernetes 也提供了显式的 Volume 定义，它叫做 hostPath。比如下面的这个 YAML 文件：

```yaml
 ...   
    volumes:
      - name: nginx-vol
        hostPath: 
          path: /var/data
```

这样，容器 Volume 挂载的宿主机目录，就变成了 `/var/data`。

执行 `kubectl apply -f nginx-deployment.yaml` 命令，就可以更新这个 Deployment 了。

新旧两个 Pod，被交替创建、删除，最后剩下的就是新版本的 Pod。这个是**滚动更新**的过程。

还可以使用 `kubectl exec` 指令，进入到这个 Pod 当中（即容器的 Namespace 中）查看这个 Volume 目录：

```bash
$ kubectl exec -it nginx-deployment-5c678cfb6d-lg9lw -- /bin/bash
# ls /usr/share/nginx/html
```

删除这个 Nginx Deployment：

```bash
$ kubectl delete -f nginx-deployment.yaml
```
