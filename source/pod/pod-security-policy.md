---
title: Pod 安全策略
---

# Pod 安全策略
## SecurityContext
Security Context 的目的是限制不可信容器的行为，保护系统和其他容器不受其影响。
Kubernetes 提供了三种配置 Security Context 的方法：
- Container-level Security Context：仅应用到指定的容器
- Pod-level Security Context：应用到 Pod 内所有容器以及 Volume
- Pod Security Policies（PSP）：应用到集群内部所有 Pod 以及 Volume

## Container-level Security Context
Container-level Security Context 仅应用到指定的容器上，并且不会影响 Volume。比如设置容器运行在特权模式：
```yml
apiVersion: v1
kind: Pod
metadata:
  name: hello-world
spec:
  containers:
    - name: hello-world-container
      # The container definition
      # ...
      securityContext:
        privileged: true
```

## Pod-level Security Context
Pod-level Security Context 应用到 Pod 内所有容器，并且还会影响 Volume（包括 `fsGroup` 和 `selinuxOptions`）。
```yml
apiVersion: v1
kind: Pod
metadata:
  name: hello-world
spec:
  containers:
  # specification of the pod's containers
  # ...
  securityContext:
    fsGroup: 1234
    supplementalGroups: [5678]
    seLinuxOptions:
      level: "s0:c123,c456"
```

## Pod Security Policies（PSP）
### 什么是 Pod Security Policies
Pod Security Policies 是集群级别的资源，它能够控制 Pod 运行的行为，以及它具有访问什么的能力。自动为集群内的 Pod 和 Volume 设置 Security Context。

使用 PSP 需要 API Server 开启 `extensions/v1beta1/podsecuritypolicy`，并且配置 `PodSecurityPolicy` admission 控制器。

`PodSecurityPolicy` 对象定义了一组条件，指示 Pod 必须按系统所能接受的顺序运行。它们允许管理员控制如下方面：

| 控制面 | 字段 |
| --- | --- |
| 以特权运行容器 | privileged |
| 使用宿主命名空间	 | hostPID, hostIPC |
| 使用宿主网络和端口 | hostNetwork, hostPorts |
| 使用存储卷类型 | volumes |
| 使用宿主机文件系统 | allowedHostPaths |
| flex 存储卷白名单 | allowedFlexVolumes |
| 分配拥有 Pod 数据卷的 FSGroup | fsGroup |
| 只读 root 文件系统 | readOnlyRootFilesystem |
| 容器的用户 id 和组 id | runAsUser, runAsGroup, supplementalGroups |
| 禁止提升到 root 权限 | allowPrivilegeEscalation, defaultAllowPrivilegeEscalation |
| Linux 能力 | defaultAddCapabilities, requiredDropCapabilities, allowedCapabilities |
| SELinux 上下文 | seLinux |
| 允许容器加载的 proc 类型 | allowedProcMountTypes |
| The AppArmor profile used by containers | annotations |
| The seccomp profile used by containers | annotations |
| The sysctl profile used by containers | forbiddenSysctls,allowedUnsafeSysctls |

### 示例
限制容器的 host 端口范围为 `8000-8080`：
```yml
apiVersion: extensions/v1beta1
kind: PodSecurityPolicy
metadata:
  name: permissive
spec:
  seLinux:
    rule: RunAsAny
  supplementalGroups:
    rule: RunAsAny
  runAsUser:
    rule: RunAsAny
  fsGroup:
    rule: RunAsAny
  hostPorts:
  - min: 8000
    max: 8080
  volumes:
  - '*'
```

限制只允许使用 `lvm` 和 `cifs` 等 flexVolume 插件：
```yml
apiVersion: extensions/v1beta1
kind: PodSecurityPolicy
metadata:
  name: allow-flex-volumes
spec:
  fsGroup:
    rule: RunAsAny
  runAsUser:
    rule: RunAsAny
  seLinux:
    rule: RunAsAny
  supplementalGroups:
    rule: RunAsAny
  volumes:
    - flexVolume
  allowedFlexVolumes:
    - driver: example/lvm
    - driver: example/cifs
```

## Pod 安全策略操作
### 获取 Pod 安全策略列表
```sh
$ kubectl get psp
NAME        PRIV   CAPS  SELINUX   RUNASUSER         FSGROUP   SUPGROUP  READONLYROOTFS  VOLUMES
permissive  false  []    RunAsAny  RunAsAny          RunAsAny  RunAsAny  false           [*]
privileged  true   []    RunAsAny  RunAsAny          RunAsAny  RunAsAny  false           [*]
restricted  false  []    RunAsAny  MustRunAsNonRoot  RunAsAny  RunAsAny  false           [emptyDir secret downwardAPI configMap persistentVolumeClaim projected]
```

### 修改 Pod 安全策略
```sh
$ kubectl edit psp permissive
```

该命令将打开一个默认文本编辑器，在这里能够修改策略。

### 删除 Pod 安全策略
```sh
$ kubectl delete psp permissive
podsecuritypolicy "permissive" deleted
```