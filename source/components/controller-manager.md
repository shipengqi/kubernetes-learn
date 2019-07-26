---
title: kube-controller-manager
---

# kube-controller-manager

Controller Manager 由 `kube-controller-manager` 和 `cloud-controller-manager` 组成，是 Kubernetes 的大脑，它通过 apiserver 监控整个集群的状态，
并确保集群处于预期的工作状态。


<img src="../imgs/controller-manager.png" width="70%">


`kube-controller-manager` 由一系列的控制器组成：
- Replication Controller
- Node Controller
- CronJob Controller
- Daemon Controller
- Deployment Controller
- Endpoint Controller
- Garbage Collector
- Namespace Controller
- Job Controller
- Pod AutoScaler
- RelicaSet
- Service Controller
- ServiceAccount Controller
- StatefulSet Controller
- Volume Controller
- Resource quota Controller


## 示例
```yml
apiVersion: v1
kind: Pod
metadata:
  name: controller
  namespace: kube-system
  annotations:
    scheduler.alpha.kubernetes.io/critical-pod: ""
spec:
  containers:
  - command:
    - /hyperkube
    - controller-manager
    - --address=127.0.0.1
    - --bind-address=127.0.0.1
    - --master=https://{THIS_NODE}:{MASTER_API_SSL_PORT}
    - --leader-elect=true
    - --pod-eviction-timeout=1m0s
    - --service-account-private-key-file=/etc/kubernetes/ssl/kube-serviceaccount.key
    - --root-ca-file=/etc/kubernetes/ssl/ca.crt
    - --v=1
    - --logtostderr=true
    - --kubeconfig=/etc/kubernetes/ssl/kubeconfig
    - --authentication-kubeconfig=/etc/kubernetes/ssl/kubeconfig
    - --authorization-kubeconfig=/etc/kubernetes/ssl/kubeconfig
    - --pv-recycler-pod-template-filepath-nfs=/etc/kubernetes/cfg/recycler.yaml
    - --flex-volume-plugin-dir=/tmp/kubernetes/kubelet-plugins/volume/exec/
    # - --allocate-node-cidrs=true
    # - --cluster-cidr={POD_CIDR}
    # - --node-cidr-mask-size={POD_CIDR_SUBNETLEN}
    image: k8s.gcr.io/{IMAGE_HYPERKUBE}
    imagePullPolicy: IfNotPresent
    securityContext:
      runAsUser: {SYSTEM_USER_ID}
    livenessProbe:
      httpGet:
        host: 127.0.0.1
        path: /healthz
        port: 10252
        scheme: HTTP
      initialDelaySeconds: 15
      timeoutSeconds: 15
    name: controller
    volumeMounts:
    - mountPath: /etc/kubernetes/ssl
      name: ssl-certs-path
      readOnly: true
    - mountPath: /etc/kubernetes/cfg
      name: config
      readOnly: true

  dnsPolicy: ClusterFirst
  hostNetwork: true
  restartPolicy: Always
  terminationGracePeriodSeconds: 30
  priorityClassName: system-cluster-critical
  volumes:
  - hostPath:
      path: {K8S_HOME}/ssl
    name: ssl-certs-path
  - hostPath:
      path: {K8S_HOME}/cfg/controller-manager
    name: config
```