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

要安装一个新的包，使用 `helm install` 命令。最简单的方法，需要两个参数：选择一个 release name，想要安装的 chart 的 name。

```bash
$ helm install happy-panda stable/mariadb
WARNING: This chart is deprecated
NAME: happy-panda
LAST DEPLOYED: Fri May  8 17:46:49 2020
NAMESPACE: default
STATUS: deployed
REVISION: 1
NOTES:
This Helm chart is deprecated

...

Services:

  echo Master: happy-panda-mariadb.default.svc.cluster.local:3306
  echo Slave:  happy-panda-mariadb-slave.default.svc.cluster.local:3306

Administrator credentials:

  Username: root
  Password : $(kubectl get secret --namespace default happy-panda-mariadb -o jsonpath="{.data.mariadb-root-password}" | base64 --decode)

To connect to your database:

  1. Run a pod that you can use as a client:

      kubectl run happy-panda-mariadb-client --rm --tty -i --restart='Never' --image  docker.io/bitnami/mariadb:10.3.22-debian-10-r27 --namespace default --command -- bash

  2. To connect to master service (read/write):

      mysql -h happy-panda-mariadb.default.svc.cluster.local -uroot -p my_database

  3. To connect to slave service (read-only):

      mysql -h happy-panda-mariadb-slave.default.svc.cluster.local -uroot -p my_database

To upgrade this helm chart:

  1. Obtain the password as described on the 'Administrator credentials' section and set the 'rootUser.password' parameter as shown below:

      ROOT_PASSWORD=$(kubectl get secret --namespace default happy-panda-mariadb -o jsonpath="{.data.mariadb-root-password}" | base64 --decode)
      helm upgrade happy-panda stable/mariadb --set rootUser.password=$ROOT_PASSWORD
```

现在 mariadb chart 已经安装好了。注意安装 chart 会创建一个新的 release 对象。上面的 release 被命名为 `happy-panda`（如果你想要 Helm 为你生成一个名称，去掉 release name，使用 `--generate-name`）。

在安装时，Helm 客户端会打印出有关创建哪些资源的有用信息，release 的状态，以及是否可以或应该采取其他的配置步骤。

Helm 不会等到所有资源运行才退出。许多 charts 需要大小超过 600M 的 Docker 镜像，因此可能需要很长时间才能安装到集群中。

跟踪 release 的状态，或者重新读取配置信息，可以使用 `helm status`：

```bash
$ helm status happy-panda
NAME: happy-panda
LAST DEPLOYED: Fri May  8 17:46:49 2020
NAMESPACE: default
STATUS: deployed
REVISION: 1
NOTES:
This Helm chart is deprecated

...

Services:

  echo Master: happy-panda-mariadb.default.svc.cluster.local:3306
  echo Slave:  happy-panda-mariadb-slave.default.svc.cluster.local:3306

Administrator credentials:

  Username: root
  Password : $(kubectl get secret --namespace default happy-panda-mariadb -o jsonpath="{.data.mariadb-root-password}" | base64 --decode)

To connect to your database:

 1. Run a pod that you can use as a client:

      kubectl run happy-panda-mariadb-client --rm --tty -i --restart='Never' --image  docker.io/bitnami/mariadb:10.3.22-debian-10-r27 --namespace default --command -- bash

  2. To connect to master service (read/write):

      mysql -h happy-panda-mariadb.default.svc.cluster.local -uroot -p my_database

  3. To connect to slave service (read-only):

      mysql -h happy-panda-mariadb-slave.default.svc.cluster.local -uroot -p my_database

To upgrade this helm chart:

  1. Obtain the password as described on the 'Administrator credentials' section and set the 'rootUser.password' parameter as shown below:

      ROOT_PASSWORD=$(kubectl get secret --namespace default happy-panda-mariadb -o jsonpath="{.data.mariadb-root-password}" | base64 --decode)
      helm upgrade happy-panda stable/mariadb --set rootUser.password=$ROOT_PASSWORD
```

上面的输出展示了当前 release 的状态。

### 在安装前自定义 chart

上面的安装方式使用的是 chart 的默认配置选项。很多时候，我们需要自定义 chart 以使用自定义配置。

要查看一个 chart 的可配置选项，使用 `helm show values`：

```bash
$ helm show values stable/mariadb
Fetched stable/mariadb-0.3.0.tgz to /Users/mattbutcher/Code/Go/src/helm.sh/helm/mariadb-0.3.0.tgz
## Bitnami MariaDB image version
## ref: https://hub.docker.com/r/bitnami/mariadb/tags/
##
## Default: none
imageTag: 10.1.14-r3

## Specify a imagePullPolicy
## Default to 'Always' if imageTag is 'latest', else set to 'IfNotPresent'
## ref: https://kubernetes.io/docs/user-guide/images/#pre-pulling-images
##
# imagePullPolicy:

## Specify password for root user
## ref: https://github.com/bitnami/bitnami-docker-mariadb/blob/master/README.md#setting-the-root-password-on-first-run
##
# mariadbRootPassword:

## Create a database user
## ref: https://github.com/bitnami/bitnami-docker-mariadb/blob/master/README.md#creating-a-database-user-on-first-run
##
# mariadbUser:
# mariadbPassword:

## Create a database
## ref: https://github.com/bitnami/bitnami-docker-mariadb/blob/master/README.md#creating-a-database-on-first-run
##
# mariadbDatabase:
# ...
```

然后你可以在 YAML 文件中覆盖这些配置，然后在安装过程中使用这个文件：

```bash
echo '{mariadbUser: user0, mariadbDatabase: user0db}' > config.yaml
helm install -f config.yaml stable/mariadb --generate-name
```

以上将创建一个名称为 MariaDB 的默认用户 `user0`，并授予这个用户访问新创建的数据库 `user0db` 的权限，其他使用这个 chart 的默认值。

在安装过程中有两种方式传递自定义配置数据：

- `--values` (或者 `-f`): 指定一个 overrides 的 YAML 文件。可以指定多次，最右边的文件将优先使用。
- `--set`: 在命令行上指定 overrides。

如果两者都使用，则将 `--set` 值合并到 `--values` 并具有更高的优先级。`--set` 指定的 override 将保存在 configmap 中。`helm get values <release-name>` 可以查看指定 release `--set` 的值，`--set` 设置的值可以通过运行 `helm upgrade` 带有 `--reset-values` 参数来清除。

#### --set 格式和限制

`--set` 选项使用零个或多个 `name/value` 对。最简单的用法：`--set name=value`。YAML 的对应的表示是：

```yml
name: value
```

多个值由 `,` 分隔。因此 `--set a=b,c=d` 可以写成：

```yml
a: b
c: d
```

支持更复杂的表达式。例如，`--set outer.inner=value` 写成这样：

```yml
outer:
  inner: value
```

列表可以通过在 `{` 和 `}` 中包含值来表示。例如， `--set name={a, b, c}` 转化为：

```yml
name:
  - a
  - b
  - c
```

从 Helm 2.5.0 开始，可以使用数组索引语法访问列表项。例如，`--set servers[0].port=80` 变成：

```yml
servers:
  - port: 80
```

可以通过这种方式设置多个值。该行 `--set servers[0].port=80,servers[0].host=example` 变成：

```yml
servers:
  - port: 80
    host: example
```

有时候你需要在 `--set` 行中使用特殊字符。可以使用反斜杠来转义字符; `--set name="value1\,value2"` 会变成：

```yml
name: "value1,value2"
```

同样，你也可以转义点序列，这可能在 chart 中使用 toYaml 函数解析 annotations, labels 和 node selectors 。`--set nodeSelector."kubernetes\.io/role"=master` 的语法变为：

```yml
nodeSelector:
  kubernetes.io/role: master
```

使用深层嵌套的数据结构可能很难用 `--set` 表示。鼓励 chart 设计师在设计 `values.yaml` 文件格式时考虑 `--set` 使用情况。

#### 更多安装方式

`helm install` 命令可以从多个来源安装：

一个 chart repository (像上面看到的)
一个本地 chart 压缩包 (`helm install foo foo-0.1.1.tgz`)
一个解压后的 chart 目录 (`helm install foo path/to/foo`)
一个完整 URL (`helm install foo https://example.com/charts/foo-1.2.3.tgz`)

### 'helm upgrade' and 'helm rollback'：升级 release 和失败时恢复

当新版本的 chart 发布时，或者当你想要更改 release 配置时，可以使用 `helm upgrade` 命令。

升级需要已有的 release 并根据你提供的信息进行升级。由于 Kubernetes chart 可能很大而且很复杂，因此 Helm 会尝试执行最小侵入式升级。它只会更新自上次发布以来发生更改的内容。

```bash
$ helm upgrade -f panda.yaml happy-panda stable/mariadb
Fetched stable/mariadb-0.3.0.tgz to /Users/mattbutcher/Code/Go/src/helm.sh/helm/mariadb-0.3.0.tgz
happy-panda has been upgraded. Happy Helming!
Last Deployed: Wed Sep 28 12:47:54 2016
Namespace: default
Status: DEPLOYED
...
```

上面的示例中，`happy-panda` release 被使用同样的 chart 进行升级，但是使用新的 YAML 文件：

```yml
mariadbUser: user1
```

你可以使用 `helm get values` 来查看新设置是否生效。

```bash
$ helm get values happy-panda
mariadbUser: user1
```

`helm get` 命令是查看集群中的 release 的一个很有用工具。正如我们上面看到的，它展示了 `panda.yaml` 被部署到群集中的新值。

现在，如果在发布过程中某些事情没有按计划进行，那么回滚到以前的版本很容易，使用 `helm rollback [RELEASE] [REVISION]`。

```bash
helm rollback happy-panda 1
```

上述回滚我们的 `happy-panda` 到它的第一个 release 版本。release 版本是增量修订。每次安装，升级或回滚发生时，修订版本号都会增加 1. 第一个修订版本号始终为 1. 我们可以使用 `helm history [RELEASE]` 查看特定版本的修订版号。

### 安装 / 升级 / 回滚的帮助选项

在安装 / 升级 / 回滚期间，可以指定几个其他有用的选项来定制 Helm 的行为。请注意，这不是 cli 参数的完整列表。要查看所有参数的说明，运行 `helm --help`。

- `--timeout`：等待 Kubernetes 命令完成的超时时间值（秒），默认值为 `5m0s`（5 分钟）
- `--wait`：等待所有 Pod 都处于就绪状态，PVC 绑定完，将 release 标记为成功之前，Deployments 有最小（Desired-maxUnavailable）Pod 处于就绪状态，并且服务具有 IP 地址（如果是 LoadBalancer，则为 Ingress ）。它会等待 `--timeout` 的值。如果达到超时，release 将被标记为 FAILED。注意：在部署 replicas 设置为 1 maxUnavailable 且未设置为 0，作为滚动更新策略的一部分的情况下， `--wait` 它将返回就绪状态，因为它已满足就绪状态下的最小 Pod。
- `--no-hooks`：这会跳过命令的运行钩子
- `--recreate-pods`（仅适用于 `upgrade` 和 `rollback`）：此参数将导致重新创建所有 pod（属于 deployment 的 pod 除外）。（Helm 3 中**弃用**）

### 'helm uninstall': 卸载一个 release

在要从群集中卸载或删除一个 release 时，使用 `helm delete` 命令：

```bash
helm uninstall happy-panda
```

这将从集群中删除该 release。可以使用以下 `helm list` 命令查看当前部署的所有 release：

```bash
$ helm list
NAME            VERSION UPDATED                         STATUS          CHART
inky-cat        1       Wed Sep 28 12:59:46 2016        DEPLOYED        alpine-0.1.0
```

从上面的输出可以看出来，`happy-panda` release 已经被卸载了。

在之前版本的 Helm 中，当一个 release 被删除时，会保留一个已删除的 release 的记录。在 Helm 3 中，不会保留这个记录。如果你想保留一个已删除 release 的记录，使用 `helm uninstall --keep-history`。使用 `helm list --uninstalled` 可以查看使用了 `--keep-history` 选项删除的 release。

`helm list --all` 显示所有 release（已删除和当前部署的，以及失败的版本）：

```bash
$  helm list --all
NAME            VERSION UPDATED                         STATUS          CHART
happy-panda     2       Wed Sep 28 12:47:54 2016        UNINSTALLED     mariadb-0.3.0
inky-cat        1       Wed Sep 28 12:59:46 2016        DEPLOYED        alpine-0.1.0
kindred-angelf  2       Tue Sep 27 16:16:10 2016        UNINSTALLED     alpine-0.1.0
```

注意，由于 release 在默认情况下会被删除，因此不可能回滚已卸载的资源。

### 'helm repo'：使用 Repositories

Helm 3 不再提供默认的 chart 仓库。 `helm repo` 命令提供了一组命令用于 添加，列出和删除仓库。

使用 `helm repo list` 可以查看已经配置的仓库：

```bash
$ helm repo list
NAME            URL
stable          https://charts.helm.sh/stable
mumoshu         https://mumoshu.github.io/charts
```

`helm repo add` 添加一个新的仓库：

```bash
helm repo add dev https://example.com/dev-charts
```

由于 chart 仓库经常变化，所以可以通过 `helm repo update` 来确保 Helm 客户端是最新的。

`helm repo remove` 删除仓库。

### 创建你的 chart

你可以使用 `helm create` 命令迅速开始：

```bash
$ helm create deis-workflow
Creating deis-workflow
```

现在在 `./deis-workflow` 目录下有一个 chart。你可以编辑它，创建自己的模版。

当你编辑 chart 时，可以使用 `helm lint` 校验格式是否正确。

当要将 chart 打包分发时，可以使用 `helm package`：

```bash
$ helm package deis-workflow
deis-workflow-0.1.0.tgz
```

现在可以通过 `helm install` 轻松安装该 chart：

```bash
$ helm install deis-workflow ./deis-workflow-0.1.0.tgz
...
```

可以将已归档的 chart 加载到 chart repo 中。请参阅 chart repo 服务器的文档以了解如何上传。

注意：stable repo 在 [Kubernetes Charts GitHub repository](https://github.com/helm/charts) 上进行管理。该项目接受 chart 源代码，并且（在审计后）自动打包。
