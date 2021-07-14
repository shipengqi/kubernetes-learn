---
title: kube-dns
---

DNS 是 Kubernetes 的核心功能之一，通过 `kube-dns` 或 `CoreDNS` 作为集群的必备扩展来提供命名服务。

## CoreDNS

从 v1.11 开始可以使用 [CoreDNS](https://coredns.io/) 来提供命名服务，并从 v1.13 开始成为默认 DNS 服务。CoreDNS 的特点是效率更高，资源占用率更小，
推荐使用 CoreDNS 替代 kube-dns 为集群提供 DNS 服务。

从 kube-dns 升级为 CoreDNS：

```sh
git clone https://github.com/coredns/deployment
cd deployment/kubernetes
./deploy.sh | kubectl apply -f -
kubectl delete --namespace=kube-system deployment kube-dns
```

全新部署的话，查看 [CoreDNS 扩展的配置方法](https://github.com/kubernetes/kubernetes/tree/master/cluster/addons/dns)。

## DNS 格式

- Service
  - A record：生成 `my-svc.my-namespace.svc.cluster.local`，解析 IP 分为两种情况
    - 普通 Service 解析为 Cluster IP
    - [Headless Service](../service-discovery/service.html#Headless-Service) 解析为指定的 Pod IP 列表
  - SRV record：生成 `_my-port-name._my-port-protocol.my-svc.my-namespace.svc.cluster.local`
- Pod
  - A record：`pod-ip-address.my-namespace.pod.cluster.local`
  - 指定 hostname 和 subdomain：`hostname.custom-subdomain.default.svc.cluster.local`，如下所示

```yml
apiVersion: v1
kind: Pod
metadata:
  name: busybox2
  labels:
    name: busybox
spec:
  hostname: busybox-2
  subdomain: default-subdomain
  containers:
  - image: busybox
    command:
      - sleep
      - "3600"
    name: busybox
```

## 配置私有 DNS 服务器和上游 DNS 服务器

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-dns
  namespace: kube-system
data:
  stubDomains: |
    {"acme.local": ["1.2.3.4"]}
  upstreamNameservers: |
    ["8.8.8.8", "8.8.4.4"]
```

使用上述特定配置，查询请求首先会被发送到 `kube-dns` 的 DNS 缓存层 (Dnsmasq 服务器)。Dnsmasq 服务器会先检查请求的后缀，带有集群后缀（例如：`.cluster.local`）的
请求会被发往 `kube-dns`，拥有存根域后缀的名称（例如：`.acme.local`）将会被发送到配置的私有 DNS 服务器 `["1.2.3.4"]`。最后，不满足任何这些后缀的请求将会被发送
到上游 DNS `["8.8.8.8", "8.8.4.4"]` 里。

## 示例

```yml
---
#create cdf view service account
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cdf-view
  namespace: kube-system
---
#create rolebinding for cdf view service account in kube-system namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cdf:dns
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view
subjects:
- kind: ServiceAccount
  name: cdf-view
  namespace: kube-system
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health
        template ANY AAAA . {
          rcode NXDOMAIN
        }
        kubernetes cluster.local {SERVICE_CIDR}
        prometheus :9153
        proxy . /etc/resolv.conf
        cache 30
        hosts /etc/k8s/dns/hosts/dns-hosts.conf {
          fallthrough
        }
    }
---
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: coredns
  namespace: kube-system
  labels:
    k8s-app: kube-dns
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
spec:
  updateStrategy:
    type: RollingUpdate
  selector:
    matchLabels:
      k8s-app: kube-dns
  template:
    metadata:
      labels:
        k8s-app: kube-dns
      annotations:
        scheduler.alpha.kubernetes.io/critical-pod: ''
    spec:
      {HOST_ALIASES}
      nodeSelector:
        {NODESELECT}
      serviceAccountName: cdf-view
      priorityClassName: system-cluster-critical
      volumes:
      - name: config-volume
        configMap:
          name: coredns
          items:
          - key: Corefile
            path: Corefile
      - name: dns-hosts-cm
        configMap:
          name: dns-hosts-configmap
          items:
            - key: dns-hosts-key
              path: dns-hosts.conf
      containers:
      - name: coredns
        image: k8s.gcr.io/{IMAGE_COREDNS}
        imagePullPolicy: IfNotPresent
        resources:
          limits:
            memory: 170Mi
          requests:
            cpu: 100m
            memory: 70Mi
        args: [ "-conf", "/etc/coredns/Corefile" ]
        volumeMounts:
        - name: config-volume
          mountPath: /etc/coredns
        - name: dns-hosts-cm
          mountPath: /etc/k8s/dns/hosts
        ports:
        - containerPort: 53
          name: dns
          protocol: UDP
        - containerPort: 53
          name: dns-tcp
          protocol: TCP
        - containerPort: 9153
          name: metrics
          protocol: TCP
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            add:
            - NET_BIND_SERVICE
            drop:
            - all
          readOnlyRootFilesystem: true
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 60
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 5
      dnsPolicy: Default
---
apiVersion: v1
kind: Service
metadata:
  name: kube-dns
  namespace: kube-system
  annotations:
    prometheus.io/port: "9153"
    prometheus.io/scrape: "true"
  labels:
    k8s-app: kube-dns
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
    kubernetes.io/name: "CoreDNS"
spec:
  selector:
    k8s-app: kube-dns
  clusterIP: {DNS_SVC_IP}
  ports:
  - name: dns
    port: 53
    protocol: UDP
  - name: dns-tcp
    port: 53
    protocol: TCP
```
