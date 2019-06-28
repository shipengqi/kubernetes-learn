# PodPreset
PodPreset 用来给指定 Label 的 Pod 注入额外的信息，如环境变量、存储卷等。这样，Pod 模板就不需要为每个 Pod 都显式设置重复的信息。

## 开启 PodPreset
- 开启 API `settings.k8s.io/v1alpha1/podpreset`
- 开启准入控制 `PodPreset`

