---
title: kube-proxy
---

每台机器上都运行一个 `kube-proxy` 服务，它监听 API server 中 `service` 和 `endpoint` 的变化情况，并通过 `iptables` 等来为服务配置负载均衡（仅支持 TCP 和 UDP）。

`kube-proxy` 可以直接运行在物理机上，也可以以 static pod 或者 `daemonset` 的方式运行。

k8s 的 Service 资源对象的实现就是依赖 `kube-proxy`。`kube-proxy` 可以看作是 Service 的代理和负载均衡器。每一个 TCP 类型的 Service，`kube-proxy` 都会在
本地 Node 上创建一个 SocketServer 负责接受请求，然后均匀的转发到 Pod 的端口上。

`kube-proxy` 的几种实现：

- `userspace`：最早的负载均衡方案，它在用户空间监听一个端口，所有服务通过 iptables 转发到这个端口，然后在其内部负载均衡到实际的 Pod。该方式最主要的问题是效率低，有明显的性能瓶颈。
- `iptables`：目前推荐的方案，完全以 iptables 规则的方式来实现 service 负载均衡。该方式最主要的问题是在服务多的时候产生太多的 iptables 规则，非增量式更新会引入一定的时延，
大规模情况下有明显的性能问题
- `ipvs`：为解决 iptables 模式的性能问题，v1.11 新增了 ipvs 模式（v1.8 开始支持测试版，并在 v1.11 GA），采用增量式更新，并可以保证 service 更新期间连接保持不断开
- `winuserspace`：同 userspace，但仅工作在 windows 节点上

使用 `ipvs` 模式时，需要预先在每台 Node 上加载内核模块 `nf_conntrack_ipv4`, `ip_vs`, `ip_vs_rr`, `ip_vs_wrr`, `ip_vs_sh` 等。

```sh
# load module <module_name>
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack_ipv4

# to check loaded modules, use
lsmod | grep -e ip_vs -e nf_conntrack_ipv4
# or
cut -f1 -d " "  /proc/modules | grep -e ip_vs -e nf_conntrack_ipv4
```

Service 的 ClusterIP 和 NodePort 是 `kube-proxy` 通过 iptables 的 NAT 转换实现的。`kube-proxy` 进程会动态的创建与 Service 相关的 iptables
规则，将 ClusterIP 和 NodePort 的请求转发到代理的端口上。`kube-proxy` 的 iptables 机制只针对本地的 `kube-proxy` 端口，所以去集群的每个 Node 都需要
运行 `kube-proxy`。这样就可以在集群的任意 Node 节点上访问 Service。并且客户端不需要关心 Service 后端有几个 pod。

`kube-proxy` 通过监听 API server 中 Service 与 Endpoints 变化，为每个 Service 创建 服务代理对象，并自动同步。
`kube-proxy` 内部还实现了一个 LoadBanlancer，LoadBanlancer 上保存了 Service 对应到后端的 Enpoints 列表的动态转发路由表。

## kube-proxy systemd 文件示例

下面的示例是以 system service 的方式运行在物理机上。

```
[Unit]
Description=Kubernetes Kube Proxy service
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target

[Service]
ExecStart=/usr/bin/kube-proxy \
  --master=https://{K8S_MASTER_IP}:{MASTER_API_SSL_PORT} \
  --kubeconfig={K8S_HOME}/ssl/native.kubeconfig \
  --proxy-mode=iptables \
  --v=1 \
  --logtostderr=true \
  --cluster-cidr={POD_CIDR}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

`native.kubeconfig` 如下：

```
apiVersion: v1
kind: Config
clusters:
  - cluster:
      certificate-authority: /opt/kubernetes/ssl/ca.crt
      server: https://shccentos72vm07.hpeswlab.net:8443
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
      client-certificate: /opt/kubernetes/ssl/kubernetes.crt
      client-key: /opt/kubernetes/ssl/kubernetes.key
```
