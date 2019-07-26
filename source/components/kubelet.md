---
title: kubelet
---

# kubelet
每个节点上都运行一个 `kubelet` 服务进程，默认监听 `10250` 端口，接收并执行 master 发来的指令，管理 Pod 及 Pod 中的容器。每个 `kubelet` 进程会在 API Server 上注册节点
自身信息，定期向 master 节点汇报节点的资源使用情况，并通过 cAdvisor 监控节点和容器的资源。

## 节点管理
## Pod 管理

**前面有几个示例如 `kube-apiserver`，`kube-controller-manager`，`kube-scheduler` 都是提供给了 pod 的 template，这是因为这几个 pods 都是交给了 kubelet 来管理。**
下面的示例中 `--pod-manifest-path={K8S_HOME}/runconf` 表示监听 `{K8S_HOME}/runconf` 目录下的文件变化，`kube-apiserver` 等几个 pod 的 yaml 文件就放在该目录下。

## kubelet systemd 文件示例
```service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Wants=docker.service

[Service]
TimeoutStartSec=300s
WorkingDirectory={KUBELET_HOME}/kubelet
ExecStart=/usr/bin/kubelet \
  --allow-privileged=true \
  --root-dir={KUBELET_HOME}/kubelet \
  --cert-dir={KUBELET_HOME}/kubelet/pki \
  --authentication-token-webhook \
  --read-only-port=0 \
  --anonymous-auth=false \
  --client-ca-file={K8S_HOME}/ssl/ca.crt \
  --cluster-dns={DNS_SVC_IP} \
  --cluster-domain=cluster.local. \
  --network-plugin=cni \
  --cni-bin-dir={K8S_HOME}/cni \
  --cni-conf-dir={K8S_HOME}/cni/conf \
  --kubeconfig={K8S_HOME}/ssl/native.kubeconfig \
  --hostname-override={THIS_NODE} \
  --pod-manifest-path={K8S_HOME}/runconf \
  --node-labels={NODE_LABELS} \
  --hairpin-mode=hairpin-veth \
  --fail-swap-on={FAIL_SWAP_ON} \
  --system-reserved=memory=1.5Gi \
  --v=1 \
  --logtostderr=true \
  --runtime-cgroups=/systemd/system.slice \
  --kubelet-cgroups=/systemd/system.slice \
  --tls-cipher-suites=TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA,TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA,TLS_RSA_WITH_AES_256_GCM_SHA384,TLS_RSA_WITH_AES_128_GCM_SHA256,TLS_RSA_WITH_AES_256_CBC_SHA,TLS_RSA_WITH_AES_128_CBC_SHA
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
```