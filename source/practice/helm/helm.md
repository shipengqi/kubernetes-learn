---
title: Helm
---

[Helm](https://helm.sh/) 是构建于 K8S 之上的包管理器，可与我们平时接触到的 `Yum`，`APT`，`Homebrew` 或者 `Pip` 等包管理器相类比。
使用 Helm 可简化包分发，安装，版本管理等操作流程。

## 使用 Helm

### 三大概念

一个 **Chart** 就是一个 Helm 包。它包含了 Kubernetes 集群内运行的应用程序，工具和服务所有必要的资源定义。可以当做是一个自制软件，一个 Apt dpkg 或者一个 Yum RPM 文件的 Kubernetes 环境里面的等价物。

一个 **Repository** 是一个收集和共享 **Charts** 的地方. 就像 Perl 的 [CPAN archive](https://www.cpan.org/) 或者 Fedora 的 [Package Database](https://pagure.io/pkgdb2/), 只不过是针对 Kubernetes 包的。

一个 **Release** 就是在 Kubernetes 集群中运行的一个 **Chart** 实例。通常一个 chart 在同一个集群中可以安装多次。并且每次安装后会创建一个新的 **Release**。例如一个 MySQL chart，如果你想在集群中运行两个数据库，就可以安装两次这个 chart。每个都会有自己的 release，每个 release 都会有自己的 release name。

了解了这些概念, 我们可以解释 Helm:

Helm 将 chart 安装到 Kubernetes 中，每个安装创建一个新的 release。要找到新的 chart，可以搜索 Helm charts repositories。

### 'helm search': Finding Charts

Helm 提供了强大的搜索命令。可以用来搜索两种不同类型的来源：

- `helm search hub` 搜索 [Artifact Hub](https://artifacthub.io/)，可以列出来自多个仓库的 charts。
- `helm search repo` 搜索已经在本地客户端添加的仓库（通过 `helm repo add`）。 这个搜索是在本地数据上完成的，不需要链接公共网络。

运行 `helm search hub`，你可以找到可用的公共的 chart：

```bash
$ helm search hub wordpress
URL                                                 CHART VERSION APP VERSION DESCRIPTION
https://hub.helm.sh/charts/bitnami/wordpress        7.6.7         5.2.4       Web publishing platform for building blogs and ...
https://hub.helm.sh/charts/presslabs/wordpress-...  v0.6.3        v0.6.3      Presslabs WordPress Operator Helm Chart
https://hub.helm.sh/charts/presslabs/wordpress-...  v0.7.1        v0.7.1      A Helm chart for deploying a WordPress site on ...
```

上面的搜索找的在 Artifact Hub 上的所有 wordpress charts。

没有过滤条件的话，`helm search hub` 展示所有可用的 charts。

使用 `helm search repo` 可以找到已经添加到仓库的 charts 名称：

```bash
$ helm repo add brigade https://brigadecore.github.io/charts
"brigade" has been added to your repositories
$ helm search repo brigade
NAME                          CHART VERSION APP VERSION DESCRIPTION
brigade/brigade               1.3.2         v1.2.1      Brigade provides event-driven scripting of Kube...
brigade/brigade-github-app    0.4.1         v0.2.1      The Brigade GitHub App, an advanced gateway for...
brigade/brigade-github-oauth  0.2.0         v0.20.0     The legacy OAuth GitHub Gateway for Brigade
brigade/brigade-k8s-gateway   0.1.0                     A Helm chart for Kubernetes
brigade/brigade-project       1.0.0         v1.0.0      Create a Brigade project
brigade/kashti                0.4.0         v0.4.0      A Helm chart for Kubernetes
```

Helm 搜索使用了一个模糊字符串匹配算法，所以可以输入单词或短语的部分：

```bash
$ helm search repo kash
NAME            CHART VERSION APP VERSION DESCRIPTION
brigade/kashti  0.4.0         v0.4.0      A Helm chart for Kubernetes
```

搜索是找到可用包的好方法。一旦你找到了你想要安装的软件包，你可以使用 `helm install` 来安装它。

### 'helm install': Installing a Package