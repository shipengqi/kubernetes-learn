---
title: ConfigMap
---


`ConfigMap` 是 `Kubernetes` 中的一种用来**存储配置**的资源对象。

<!-- more -->

`ConfigMap` 可以**将配置信息与 `image` 解耦合，当配置改变时，我们只需要修改 `ConfigMap` 保存的数据，而不需要重新 `build` 新的 `image`**。
`ConfigMap` 可以用来存储配置文件，也可以存储 `JSON` 对象。如果有敏感信息要存储，使用 [Secret](./secret.html)。

## 创建 ConfigMap

### 使用 yaml 创建

`example.yml` 文件：

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: example-config
  namespace: default
data:
  example.how: hello
  example.type: kube
```

```bash
kubectl create -f example.yaml
```

### 使用 `create configmap` 命令创建

```bash
kubectl create configmap NAME [--from-literal=key1=value1] [--from-env-file=source] [--from-file=[key=]source] [--dry-run]
```

参数：

- `--from-literal`，配置信息，该参数可以使用多次。
- `--from-env-file`，
- `--from-file`，指定的目录下的所有文件都会被用在 `ConfigMap` 里面创建一个 `key/value` 键值对，`key` 的名字就是文件名，`value` 就是文件的内容，参数可以使用多次。
  - `key`，当 `--from-file` 指定的是一个文件目录时，可以为每个文件设置 `key`，而不使用文件名来作为 `key`， 如 `--from-file=config1=example/a`。

```bash
# 使用 key/value 字符串创建
kubectl create configmap example-config --from-literal=example.how=hello
configmap "example-config" created
kubectl get configmap example-config -o go-template='{{.data}}'
map[example.how:hello]

# 使用 env 文件创建
echo -e "a=b\nc=d" | tee example.env
a=b
c=d

kubectl create configmap example-config --from-env-file=example.env
configmap "example-config" created

kubectl get configmap example-config -o go-template='{{.data}}'
map[a:b c:d]

# 使用目录创建
mkdir example
echo avalue > example/a
echo bvalue > example/b
# --from-file=example/ 这里的 example/ 也可以不带 /
kubectl create configmap example-config --from-file=example/
configmap "example-config" created
kubectl get configmap example-config -o go-template='{{.data}}'
map[a:avalue
 b:bvalue
]

# 设置 key
kubectl create configmap my-config --from-file=config1=example/a --from-file=config2=example/b

kubectl get configmap example-config -o yaml
apiVersion: v1
data:
  config1: |
    a
  config2: |
    b
kind: ConfigMap
metadata:
  creationTimestamp: 2018-08-13T06:01:59Z
  name: my-config
  namespace: default
  resourceVersion: "5318721"
  selfLink: /api/v1/namespaces/default/configmaps/my-config
  uid: 6425e0ce-9ebe-11e8-93fa-005056b02a1c
```

## ConfigMap 使用

`Pod` 中使用 `ConfigMap` 的方式有三种：

- 设置环境变量
- 设置容器命令行参数
- 在 Volume 中挂载

使用 `ConfigMap` 要注意下面几点：

- `ConfigMap` 必须在 `Pod` 使用它之前创建
- 使用 `envFrom`，会自动忽略无效的键
- `Pod` 只能使用和它在同一个命名空间内的 `ConfigMap`

### 设置环境变量

创建两个 `ConfigMap`：
`example-config.yml`：

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: example-config
  namespace: default
data:
  example.how: hello
  example.type: kube
```

`env-config.yml`：

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: env-config
  namespace: default
data:
  log_level: INFO
```

使用 `example-pod.yml`：

```yml
apiVersion: v1
kind: Pod
metadata:
  name: dapi-test-pod
spec:
  containers:
    - name: example-container
      image: gcr.io/google_containers/busybox
      command: [ "/bin/sh", "-c", "env" ]
      env:
        - name: SPECIAL_LEVEL_KEY
          valueFrom:
            configMapKeyRef:
              name: example-config
              key: example.how
        - name: SPECIAL_TYPE_KEY
          valueFrom:
            configMapKeyRef:
              name: example-config
              key: example.type
      envFrom:
        - configMapRef:
            name: env-config
  restartPolicy: Never
```

Pod 结束后会输出：

```bash
SPECIAL_LEVEL_KEY=hello
SPECIAL_TYPE_KEY=kube
log_level=INFO
```

### 设置容器命令行参数

修改 `example-pod.yml`，先把 `ConfigMap` 的数据保存到环境变量中，然后通过 `$(VAR_NAME)` 的方式引用环境变量：

```yml
apiVersion: v1
kind: Pod
metadata:
  name: dapi-test-pod
spec:
  containers:
    - name: test-container
      image: gcr.io/google_containers/busybox
      command: ["/bin/sh", "-c", "echo $(SPECIAL_LEVEL_KEY) $(SPECIAL_TYPE_KEY)" ]
      env:
        - name: SPECIAL_LEVEL_KEY
          valueFrom:
            configMapKeyRef:
              name: example-config
              key: example.how
        - name: SPECIAL_TYPE_KEY
          valueFrom:
            configMapKeyRef:
              name: example-config
              key: example.type
  restartPolicy: Never
```

运行 `Pod` 后会输出：

```bash
hello kube
```

### 在 Volume 中挂载

修改 `example-pod.yml`，将 `ConfigMap` 挂载到 `Pod` 的 `/etc/config` 目录下，其中每一个 `key/value` 键值对都会生成一个文件，`key` 为文件名，`value` 为内容：

```yml
apiVersion: v1
kind: Pod
metadata:
  name: vol-test-pod
spec:
  containers:
    - name: test-container
      image: gcr.io/google_containers/busybox
      command: ["/bin/sh", "-c", "cat /etc/config/example.how"]
      volumeMounts:
      - name: config-volume
        mountPath: /etc/config
  volumes:
    - name: config-volume
      configMap:
        name: example-config
  restartPolicy: Never
```

运行 `Pod` 后会输出：

```bash
hello
```

#### 挂载指定 `key` 到指定路径

将 `ConfigMap` 中的 key `example.how` 挂载到了 `/etc/config` 目录下的一个相对路径 `keys/example.level`，如果存在同名文件，直接覆盖。

```yml
apiVersion: v1
kind: Pod
metadata:
  name: dapi-test-pod
spec:
  containers:
    - name: test-container
      image: gcr.io/google_containers/busybox
      command: ["/bin/sh","-c","cat /etc/config/keys/example.level"]
      volumeMounts:
      - name: config-volume
        mountPath: /etc/config
  volumes:
    - name: config-volume
      configMap:
        name: example-config
        items:
        - key: example.how
          path: keys/example.level
  restartPolicy: Never
```

运行 `Pod` 后会输出：

```bash
hello
```

#### 挂载多个 key 和多个目录

将 `ConfigMap` 中的 key  `example.how` 和 `example.type` 挂载到了 `/etc/config` 目录下，`example.how` 挂载到了 `/etc/config2` 目录。

```yml
apiVersion: v1
kind: Pod
metadata:
  name: dapi-test-pod
spec:
  containers:
    - name: test-container
      image: gcr.io/google_containers/busybox
      command: ["/bin/sh","-c","sleep 36000"]
      volumeMounts:
      - name: config-volume
        mountPath: /etc/config
      - name: config-volume2
        mountPath: /etc/config2
  volumes:
    - name: config-volume
      configMap:
        name: example-config
        items:
        - key: example.how
          path: keys/example.level
        - key: special.type
          path: keys/example.type
    - name: config-volume2
      configMap:
        name: example-config
        items:
        - key: example.how
          path: keys/example.level
  restartPolicy: Never
```

```bash
# ls  /etc/config/keys/
example.level  example.type
# ls  /etc/config2/keys/
example.level
# cat  /etc/config/keys/example.level
hello
# cat  /etc/config/keys/example.type
kube
```

#### 使用 subPath

使用 `subPath` 可以将 `configmap` 中的每个 `key`，按照文件的方式挂载到目录下：

```yml
apiVersion: v1
kind: Pod
metadata:
  name: dapi-test-pod
spec:
  containers:
    - name: test-container
      image: nginx
      command: ["/bin/sh","-c","sleep 36000"]
      volumeMounts:
      - name: config-volume
        mountPath: /etc/config3/example.how
        subPath: example.how
  volumes:
    - name: config-volume
      configMap:
        name: example-config
        items:
        - key: example.how
          path: example.how
  restartPolicy: Never
```

## ConfigMap 热更新

如果 `ConfigMap` 更新了，那么：

- `Pod` 中使用该 `ConfigMap` 配置的环境变量不会同步更新，环境变量是在容器启动的时候注入的，启动之后就不会再改变环境变量的值。
- `Pod` 中使用该 `ConfigMap` 挂载的 `Volume` 中的文件在一段时间（大概10秒）会同步更新，如果使用 ConfigMap 的 `subPath` 挂载为 Container 的 Volume，Kubernetes
不会做自动热更新，[known issue](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/#mounted-configmaps-are-updated-automatically)。

`ConfigMap` 更新并不会触发相关 `Pod` 的滚动更新。可以通过修改 pod annotations 的方式强制触发滚动更新：

```sh
kubectl patch deployment my-nginx --patch '{"spec": {"template": {"metadata": {"annotations": {"version/config": "20180411" }}}}}'
```

这里我们在 `.spec.template.metadata.annotations` 中添加 `version/config`，每次通过修改 `version/config` 来触发滚动更新。
