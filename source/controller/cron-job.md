---
title: CronJob
---

# CronJob
CronJob 即定时任务，管理基于时间的 [Job](./job.html)，类似于 Linux 系统的 crontab，在指定的时间周期运行指定的任务。

## 开启 CronJob

对于小于 1.8 的版本，需要在启动 API Server 时，通过传递选项 `--runtime-config=batch/v2alpha1=true` 可以开启 `batch/v2alpha1` API。
大于 1.8 的版本可以直接使用。

## 使用场景
- 在给定的时间点调度 Job 运行
- 创建周期性运行的 Job，例如：数据库备份、发送邮件。

## CronJob Spec
- `.spec.jobTemplate` 指定需要运行的任务，格式同 [Job](./job.html)
- `.spec.schedule` 指定任务运行周期，格式同 [Cron](https://en.wikipedia.org/wiki/Cron)
- `.spec.startingDeadlineSeconds` 指定任务启动的期限
- `.spec.concurrencyPolicy` 指定任务的并发策略，支持 Allow、Forbid 和 Replace 三个选项

`cronjob.yaml`：
```yml
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: hello
spec:
  schedule: "*/1 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: hello
            image: busybox
            args:
            - /bin/sh
            - -c
            - date; echo Hello from the Kubernetes cluster
          restartPolicy: OnFailure
```

```sh
# 创建
$ kubectl create -f cronjob.yaml
cronjob "hello" created

# 用 kubectl run 来创建 CronJob
kubectl run hello --schedule="*/1 * * * *" --restart=OnFailure --image=busybox -- /bin/sh -c "date; echo Hello from the Kubernetes cluster"

# 查看
$ kubectl get cronjob
NAME      SCHEDULE      SUSPEND   ACTIVE    LAST-SCHEDULE
hello     */1 * * * *   False     0         <none>
$ kubectl get jobs
NAME               DESIRED   SUCCESSFUL   AGE
hello-1202039034   1         1            49s
$ pods=$(kubectl get pods --selector=job-name=hello-1202039034 --output=jsonpath={.items..metadata.name} -a)
$ kubectl logs $pods
Mon Aug 29 21:34:09 UTC 2016
Hello from the Kubernetes cluster

# 注意，删除 cronjob 的时候不会自动删除 job，这些 job 可以用 kubectl delete job 来删除
$ kubectl delete cronjob hello
cronjob "hello" deleted
```

## Cron Job 限制

### 启动 Job 的期限（秒级别）
`.spec.startingDeadlineSeconds` 字段是可选的。它表示启动 Job 的期限（秒级别），如果因为任何原因而错过了被调度的时间，那么错过执行时间的 Job 将被认为是失败的。如果没有指定，则没有期限。

### 并发策略
`.spec.concurrencyPolicy` 字段也是可选的。它指定了如何处理被 Cron Job 创建的 Job 的并发执行。只允许指定下面策略中的一种：

- Allow（默认）：允许并发运行 Job
- Forbid：禁止并发运行，如果前一个还没有完成，则直接跳过下一个
- Replace：取消当前正在运行的 Job，用一个新的来替换

注意，当前策略只能应用于同一个 Cron Job 创建的 Job。如果存在多个 Cron Job，它们创建的 Job 之间总是允许并发运行。

### 挂起
`.spec.suspend` 字段也是可选的。如果设置为 `true`，后续所有执行都将被挂起。它对已经开始执行的 Job 不起作用。默认值为 `false`。

### Job 历史限制

`.spec.successfulJobsHistoryLimit` 和 `.spec.failedJobsHistoryLimit` 这两个字段是可选的。它们指定了可以保留完成和失败 Job 数量的限制。

默认没有限制，所有成功和失败的 Job 都会被保留。然而，当运行一个 Cron Job 时，很快就会堆积很多 Job，推荐设置这两个字段的值。
设置限制值为 0，相关类型的 Job 完成后将不会被保留。
