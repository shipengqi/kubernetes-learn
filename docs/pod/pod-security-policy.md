# Pod 安全策略
## 什么是 Pod 安全策略
Pod 安全策略 是集群级别的资源，它能够控制 Pod 运行的行为，以及它具有访问什么的能力。`PodSecurityPolicy` 对象定义了一组条件，指示 Pod 必须按系统所能接受的顺序运行。
它们允许管理员控制如下方面：

| 控制面 | 字段 |
| --- | --- |
| Running of privileged containers	| privileged |
| Usage of host namespaces	| hostPID, hostIPC |
| Usage of host networking and ports | hostNetwork, hostPorts |
| Usage of volume types	 | volumes |
| Usage of the host filesystem	| allowedHostPaths |
| White list of Flexvolume drivers	| allowedFlexVolumes |
| Allocating an FSGroup that owns the pod’s volumes | fsGroup |
| Requiring the use of a read only root file system | readOnlyRootFilesystem |
| The user and group IDs of the container | runAsUser, runAsGroup, supplementalGroups |
| Restricting escalation to root privileges | allowPrivilegeEscalation, defaultAllowPrivilegeEscalation |
| Linux capabilities | defaultAddCapabilities, requiredDropCapabilities, allowedCapabilities |
| The SELinux context of the container | seLinux |
| The Allowed Proc Mount types for the container | allowedProcMountTypes |
| The AppArmor profile used by containers | annotations |
| The seccomp profile used by containers | annotations |
| The sysctl profile used by containers | forbiddenSysctls,allowedUnsafeSysctls |