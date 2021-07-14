---
title: PodPreset
---

`PodPreset` 用来给指定 [Label](../cluster/label.html) 的 Pod 注入额外的信息，比如有时候想要让一批容器在启动的时候就注入一些信息，如环境变量、存储卷等。
这样，Pod 模板就不需要为每个 Pod 都显式设置重复的信息。

## 工作机制

在启用了准入控制器（`PodPreset`）时，Pod Preset 会将应用创建请求传入到该控制器上。当有 Pod 创建请求发生时，系统将执行以下操作：

1. 检索所有可用的 `PodPresets`。
2. 检查 `PodPreset` 标签选择器上的标签，看看其是否能够匹配正在创建的 Pod 上的标签。
3. 尝试将由 `PodPreset` 定义的各种资源合并到正在创建的 Pod 中。
4. 出现错误时，在该 Pod 上引发记录合并错误的事件，`PodPreset` 不会注入任何资源到创建的 Pod 中。
5. 注释刚生成的修改过的 Pod spec，以表明它已被 `PodPreset` 修改过。注释的格式为
`podpreset.admission.kubernetes.io/podpreset-<pod-preset name>": "<resource version>"`。

每个 Pod 可以匹配零个或多个 Pod Prestet；并且每个 `PodPreset` 可以应用于零个或多个 Pod。

## 开启 Pod Preset

- 开启 API `settings.k8s.io/v1alpha1/podpreset`，通过 API server `--runtime-config` 包含 `settings.k8s.io/v1alpha1=true`，
如 `--runtime-config=autoscaling/v2beta1=true,settings.k8s.io/v1alpha1=true`。
- 开启准入控制 `PodPreset`，对于 1.10 及更高版本 API server `--enable-admission-plugins` 包含 `PodPreset` 选项。在以前的版本
是 `--admission-control`  包含 `PodPreset` 选项。

> `--admission-control` （顺序有关） 在 1.10 中已弃用并替换为 `--enable-admission-plugins` （顺序无关紧要）。

## 禁用特定 Pod 的 Pod Preset

在某些情况下，可能不希望 Pod 被任何 Pod Preset 所改变。在这些情况下，您可以在 Pod 的 Pod Spec 中添加注释：`podpreset.admission.kubernetes.io/exclude："true"`。

## 示例

`preset.yaml`：

```yml
apiVersion: settings.k8s.io/v1alpha1
kind: PodPreset
metadata:
  name: allow-database
spec:
  selector:
    matchLabels:
      role: frontend
  env:
    - name: DB_PORT
      value: "6379"
  volumeMounts:
    - mountPath: /cache
      name: cache-volume
  volumes:
    - name: cache-volume
      emptyDir: {}
```

上面的例子，新的 `PodPreset` 会匹配任何具有 label `role: frontend` 的 pod，并注入预设的配置。

### 创建

```sh
kubectl apply -f https://k8s.io/examples/podpreset/preset.yaml
```

### Pod Preset 使用 ConfigMap

```yml
# ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: etcd-env-config
data:
  number_of_members: "1"
  initial_cluster_state: new
  initial_cluster_token: DUMMY_ETCD_INITIAL_CLUSTER_TOKEN
  discovery_token: DUMMY_ETCD_DISCOVERY_TOKEN
  discovery_url: http://etcd_discovery:2379
  etcdctl_peers: http://etcd:2379
  duplicate_key: FROM_CONFIG_MAP
  REPLACE_ME: "a value"
---
# PodPreset
apiVersion: settings.k8s.io/v1alpha1
kind: PodPreset
metadata:
  name: allow-database
spec:
  selector:
    matchLabels:
      role: frontend
  env:
    - name: DB_PORT
      value: "6379"
    - name: duplicate_key
      value: FROM_ENV
    - name: expansion
      value: $(REPLACE_ME)
  envFrom:
    - configMapRef:
        name: etcd-env-config
  volumeMounts:
    - mountPath: /cache
      name: cache-volume
    - mountPath: /etc/app/config.json
      readOnly: true
      name: secret-volume
  volumes:
    - name: cache-volume
      emptyDir: {}
    - name: secret-volume
      secret:
        secretName: config-details
---
# 用户提交的 Pod
apiVersion: v1
kind: Pod
metadata:
  name: website
  labels:
    app: website
    role: frontend
spec:
  containers:
    - name: website
      image: ecorp/website
      ports:
        - containerPort: 80
---
# 经过准入控制 PodPreset 后，Pod 会自动增加 ConfigMap 环境变量
apiVersion: v1
kind: Pod
metadata:
  name: website
  labels:
    app: website
    role: frontend
  annotations:
    podpreset.admission.kubernetes.io/allow-database: "resource version"
spec:
  containers:
    - name: website
      image: ecorp/website
      volumeMounts:
        - mountPath: /cache
          name: cache-volume
        - mountPath: /etc/app/config.json
          readOnly: true
          name: secret-volume
      ports:
        - containerPort: 80
      env:
        - name: DB_PORT
          value: "6379"
        - name: duplicate_key
          value: FROM_ENV
        - name: expansion
          value: $(REPLACE_ME)
      envFrom:
        - configMapRef:
          name: etcd-env-config
  volumes:
    - name: cache-volume
      emptyDir: {}
    - name: secret-volume
      secretName: config-details
```

更多 [使用 PodPreset 的例子](https://kubernetes.io/docs/tasks/inject-data-application/podpreset/)
