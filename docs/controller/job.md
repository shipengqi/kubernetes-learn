# Job

Job 负责批量处理短暂的一次性任务 (short lived one-off tasks)，即仅执行一次的任务，它保证批处理任务的一个或多个 Pod 成功结束。

```yml
apiVersion: batch/v1
kind: Job
metadata:
  name: deployer
  namespace: {KUBE_SYSTEM_NAMESPACE}
  labels:
    app: deployer-app
spec:
  backoffLimit: 5
  template:
    metadata:
      labels:
        app: deployer-app
    spec:
      hostname: deployer
      serviceAccountName: cdf-deployer
      imagePullSecrets:
        - name: myregistrykey
      containers:
      - image: {REGISTRY_URL}/{REGISTRY_ORGNAME}/{IMAGE_ITOM_CDF_DEPLOYER}
        imagePullPolicy: IfNotPresent
        name: deployer
        env:
        - name: K8S_INSTALL_MODE
          value: "{K8S_INSTALL_MODE}"
        volumeMounts:
        - mountPath: /ssl
          name: core-volume
          subPath: baseinfra-1.0/ssl
        - mountPath: /phase2_yaml
          name: core-volume
          subPath: yaml
      restartPolicy: Never
      securityContext:
        supplementalGroups: [{SYSTEM_GROUP_ID}]
      volumes:
      - name: core-volume
        persistentVolumeClaim:
          claimName: itom-vol-claim
```

## Bare Pods
所谓 Bare Pods 是指直接用PodSpec来创建的Pod（即不在ReplicaSets或者ReplicationController的管理之下的Pods）。这些Pod在Node重启后不会自动重启，但Job则会创建新的Pod继续任务。所以，推荐使用Job来替代Bare Pods，即便是应用只需要一个Pod。