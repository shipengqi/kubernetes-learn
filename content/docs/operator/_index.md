在K8S内部通信中，肯定要保证消息的实时性。之前以为方式有两种：

1. 客户端组件 (kubelet,scheduler,controller-manager等) 轮询 apiserver，
2. apiserver 通知客户端。

List-watch是K8S统一的异步消息处理机制，保证了消息的实时性，可靠性，顺序性，性能等等。

## List-Watch 机制

Etcd存储集群的数据信息，apiserver作为统一入口，任何对数据的操作都必须经过apiserver。

客户端(kubelet/scheduler/controller-manager)通过list-watch监听apiserver中资源(pod/rs/rc等等)的create,update和delete事件，并针对事件类型调用相应的事件处理函数。

那么list-watch具体是什么呢，顾名思义，**list-watch有两部分组成，分别是list和watch**。

- list非常好理解，就是调用资源的list API罗列资源，基于HTTP短链接实现；
- **watch则是调用资源的watch API监听资源变更事件，基于HTTP 长链接实现**。

以 pod 资源为例：

- [List API](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#list-list-or-watch-objects-of-kind-pod)，返回值为 [PodList](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#PodList) 即一组 pod。
- Watch API，往往带上 `watch=true`，表示采用 HTTP 长连接持续监听 pod 相关事件，每当有事件来临，返回一个 `WatchEvent`。

### Informer 模块

K8S 的 informer 模块封装 list-watch API，用户只需要指定资源，编写事件处理函数，`AddFunc`,`UpdateFunc` 和 `DeleteFunc` 等。如下图所示，informer 首先通过list API 罗列资源，然后调用 watch API 监听资源的变更事件，并**将结果放入到一个 FIFO 队列，队列的另一头有协程从中取出事件，并调用对应的注册函数处理事件**。**Informer 还维护了一个只读的 Map Store 缓存，主要为了提升查询的效率**，降低 apiserver 的负载。


### Watch 是如何实现的

Watch是如何通过HTTP 长链接接收apiserver发来的资源变更事件呢？

利用 HTTP 分块传输编码。

通常，持久链接需要服务器在开始发送消息体前发送Content-Length消息头字段，但是对于动态生成的内容来说，在内容创建完之前是不可知的。

使用**分块传输编码，数据分解成一系列数据块，并以一个或多个块发送，这样服务器可以发送数据而不需要预先知道发送内容的总大小**。最后一个分块的长度为0，表示传输结束。

当客户端调用watch API时，apiserver 在response的HTTP Header中设置`Transfer-Encoding`的值为`chunked`，表示采用分块传输编码，客户端收到该信息后，便和服务端该链接，并等待下一个数据块，即资源的事件信息。例如：

```bash
$ curl -i http://{kube-api-server-ip}:8080/api/v1/pods?watch=true

HTTP/1.1 200 OK
Content-Type: application/json
Transfer-Encoding: chunked
Date: Thu, 02 Jan 2019 20:22:59 GMT
Transfer-Encoding: chunked

{"type":"ADDED", "object":{"kind":"Pod","apiVersion":"v1",...}}
{"type":"ADDED", "object":{"kind":"Pod","apiVersion":"v1",...}}
{"type":"MODIFIED", "object":{"kind":"Pod","apiVersion":"v1",...}}
```

list API可以查询当前的资源及其对应的状态(即期望的状态)，客户端通过拿期望的状态和实际的状态进行对比，纠正状态不一致的资源。Watch API和apiserver保持一个长链接，接收资源的状态变更事件并做相应处理。如果仅调用watch API，若某个时间点连接中断，就有可能导致消息丢失，所以需要通过list API解决消息丢失的问题。


## Informer

Informer是Client-go中的一个核心工具包。在Kubernetes源码中，如果Kubernetes的某个组件，需要 `List/Get` Kubernetes中的Object，在绝大多 数情况下，会直接使用Informer实例中的 `Lister()` 方法（该方法包含 了 `Get` 和 `List` 方法），而很少直接请求Kubernetes API。

仅需要十行左右的代码就能实现对Pod的List和Get：




```go
clientset, err := kubernetes.NewForConfig(config)
if err != nil {
    panic(err)
}
// 增加一个stopCh，用于关闭informer
stopCh := make(chan struct{})

factory := informers.NewSharedInformerFactory(clientset, 0)
factory.Start(stopCh)

podInformer := factory.Core().V1().Pods()
podLister := podInformer.Lister()
pods, err := podLister.List(labels.Everything())
if err != nil {
    panic(err)
}

podLister.Pods("kube-system").Get("kube-dns")
podLister.Pods("kube-system").List(labels.Nothing())
```

```go
import (
	"k8s.io/client-go/informers"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
)

func main() {
	config, err := clientcmd.BuildConfigFromFlags("", clientcmd.RecommendedHomeFile)
	if err != nil {
		panic(err)
	}
	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		panic(err)
	}
    // 增加一个stopCh，用于关闭informer
	stopCh := make(chan struct{})

	factory := informers.NewSharedInformerFactory(clientset, 0)
    factory.Start(stopCh)

	podInformer := factory.Core().V1().Pods()
	podLister := podInformer.Lister()
	pods, err := podLister.List(labels.Everything())
	if err != nil {
		panic(err)
	}
	for _, pod := range pods {
		fmt.Println(pod.Name)
	}
	podInformer.Informer().AddEventHandler(cache.ResourceEventHandlerFuncs{
		AddFunc: func(obj interface{}) {
			pod := obj.(*v1.Pod)
			fmt.Printf("pod %s added\n", pod.Name)
		},
		UpdateFunc: func(oldObj, newObj interface{}) {
			oldPod := oldObj.(*v1.Pod)
			newPod := newObj.(*v1.Pod)
			fmt.Printf("pod %s updated\n", newPod.Name)
		},
		DeleteFunc: func(obj interface{}) {
			pod := obj.(*v1.Pod)
			fmt.Printf("pod %s deleted\n", pod.Name)
		},
	})
	factory.Start(stopCh)
	factory.WaitForCacheSync(stopCh)
}
```

### Informer 设计思路

为了让Client-go更快地返回List/Get请求的结果、减少对Kubenetes API的直接调用，Informer被设计实现为一个依赖Kubernetes List/Watch API、**可监听事件并触发回调函数的二级缓存工具包**。

1. 更快地返回 List/Get 请求，减少对 Kubenetes API 的直接调用

Informer实例的Lister()方法，List/Get Kubernetes中的Object时，Informer不会去请求Kubernetes API，而是直接查找缓存在本地内存中的数据(这份数据由Informer自己维护)。通过这种方式，Informer既可以更快地返回结果，又能减少对Kubernetes API的直接调用。

2. 依赖 Kubernetes List/Watch API

Informer只会调用Kubernetes List和Watch两种类型的API。Informer在初始化的时，先调用Kubernetes List API获得某种resource的全部Object，缓存在内存中; 然后，调用Watch API去watch这种resource，去维护这份缓存; 最后，Informer就不再调用Kubernetes的任何 API。

3. 可监听事件并触发回调函数

Informer通过Kubernetes Watch API监听某种resource下的所有事件。而且，Informer可以添加自定义的回调函数，这个回调函数实例(即ResourceEventHandler实例)只需实现OnAdd(obj interface{})OnUpdate(oldObj, newObj interface{}) 和OnDelete(obj interface{}) 三个方法，这三个方法分别对应informer监听到创建、更新和删除这三种事件类型。

在Controller的设计实现中，会经常用到informer的这个功能。

4. 二级缓存

二级缓存属于Informer的底层缓存机制，这两级缓存分别是 DeltaFIFO 和 LocalStore。

这两级缓存的用途各不相同。DeltaFIFO 用来存储 Watch API 返回的各种事件 ，LocalStore 只会被Lister的List/Get方法访问 。

虽然Informer和Kubernetes之间没有resync机制，但Informer内部的这两级缓存之间存在resync机制。

Informer 在初始化时，Reflector 会先 List API 获得所有的 Pod
Reflect 拿到全部 Pod 后，会将全部 Pod 放到 Store 中
如果有人调用 Lister 的 List/Get 方法获取 Pod， 那么 Lister 会直接从 Store 中拿数据
Informer 初始化完成之后，Reflector 开始 Watch Pod，监听 Pod 相关 的所有事件;如果此时 pod_1 被删除，那么 Reflector 会监听到这个事件
Reflector 将 pod_1 被删除 的这个事件发送到 DeltaFIFO
DeltaFIFO 首先会将这个事件存储在自己的数据结构中(实际上是一个 queue)，然后会直接操作 Store 中的数据，删除 Store 中的 pod_1
DeltaFIFO 再 Pop 这个事件到 Controller 中
Controller 收到这个事件，会触发 Processor 的回调函数
LocalStore 会周期性地把所有的 Pod 信息重新放到 DeltaFIFO 中