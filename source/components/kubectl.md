---
title: kubectl
---

# kubectl

kubectl 是 Kubernetes 的命令行工具（CLI）。提供了大量的子命令，方便管理 Kubernetes 集群中的各种功能。

## 配置
使用 kubectl 的第一步是配置 Kubernetes 集群以及认证方式，包括
- cluster 信息：Kubernetes server 地址
- 用户信息：用户名、密码或密钥
- Context：cluster、用户信息以及 Namespace 的组合

```sh
kubectl config set-cluster kubernetes \
--server=https://${K8S_APISERVER_IP}:${MASTER_API_SSL_PORT} \
--certificate-authority=${K8S_HOME}/ssl/ca.crt

kubectl config set-context kubelet-to-kubernetes \
--cluster=kubernetes  --user=kubelet

kubectl config set-credentials kubelet \
--client-certificate=${K8S_HOME}/ssl/${prefix}.crt \
--client-key=${K8S_HOME}/ssl/${prefix}.key

kubectl config use-context kubelet-to-kubernetes
```

## 常用命令格式
- 创建：`kubectl run <name> --image=<image>` 或者 `kubectl create -f manifest.yaml`
- 查询：`kubectl get <resource>`
- 更新 `kubectl set` 或者 `kubectl patch`
- 删除：`kubectl delete <resource> <name>` 或者 `kubectl delete -f manifest.yaml`
- 查询 Pod IP：`kubectl get pod <pod-name> -o jsonpath='{.status.podIP}'`
- 容器内执行命令：`kubectl exec -it <pod-name> bash`
- 容器日志：`kubectl logs [-f] <pod-name>`
- 导出服务：`kubectl expose deploy <name> --port=80`
- Base64 解码：
```sh
kubectl get secret SECRET -o go-template='{{ .data.KEY | base64decode }}'
```


> `kubectl run` 仅支持 Pod、Replication Controller、Deployment、Job 和 CronJob 等几种资源。

## 命令概览
Kubectl 的子命令主要分为8个类别：

- 基础命令（初级）
- 基础命令（中级）
- 部署命令
- 集群管理命令
- 故障排查和调试命令
- 高级命令
- 设置命令
- 其他命令