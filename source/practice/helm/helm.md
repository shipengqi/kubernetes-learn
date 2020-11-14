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

## Charts

Helm 使用的包格式称为 chart。一个 chart 是一个描述一组相关 Kubernetes 资源的文件集合。一个单独的 chart 可能用于被部署简单的东西，比如 memcached pod，或者一些复杂的东西，比如一个完整的具有 HTTP 服务，数据库，缓存等的 Web 应用。

chart 是以文件的形式创建的，按特定的目录树排列。它们可以被打包到版本化的压缩包，然后进行部署。

如果你想下载并查看一个已经发布的 chart 的文件，但是不安装这个 chart，你可以使用 `helm pull chartrepo/chartname`。

本文档解释了 chart 格式，并且提供使用 Helm 构建 chart 的基本指导。

### Chart 文件结构

chart 被组织为一个目录内的文件集合。目录名称是 chart 的名称（没有版本信息）。那么，一个描述 WordPress 的 chart 会被存储在 `wordpress/` 目录中。

在这个目录中，Helm 期望的目录结构是下面这样的：

```bash
wordpress/
  Chart.yaml          # A YAML file containing information about the chart
  LICENSE             # OPTIONAL: A plain text file containing the license for the chart
  README.md           # OPTIONAL: A human-readable README file
  values.yaml         # The default configuration values for this chart
  values.schema.json  # OPTIONAL: A JSON Schema for imposing a structure on the values.yaml file
  charts/             # A directory containing any charts upon which this chart depends.
  crds/               # Custom Resource Definitions
  templates/          # A directory of templates that, when combined with values,
                      # will generate valid Kubernetes manifest files.
  templates/NOTES.txt # OPTIONAL: A plain text file containing short usage notes
```

Helm 保留使用 `charts/`，`crds` 和 `templates/` 目录以及上面列出的文件名称。其他文件将被忽略。

### Chart.yaml

`Chart.yaml` 文件是一个 chart 必须的。包含了以下字段：

```yml
apiVersion: The chart API version (required)
name: The name of the chart (required)
version: A SemVer 2 version (required)
kubeVersion: A SemVer range of compatible Kubernetes versions (optional)
description: A single-sentence description of this project (optional)
type: The type of the chart (optional)
keywords:
  - A list of keywords about this project (optional)
home: The URL of this projects home page (optional)
sources:
  - A list of URLs to source code for this project (optional)
dependencies: # A list of the chart requirements (optional)
  - name: The name of the chart (nginx)
    version: The version of the chart ("1.2.3")
    repository: The repository URL ("https://example.com/charts") or alias ("@repo-name")
    condition: (optional) A yaml path that resolves to a boolean, used for enabling/disabling charts (e.g. subchart1.enabled )
    tags: # (optional)
      - Tags can be used to group charts for enabling/disabling together
    enabled: (optional) Enabled bool determines if chart should be loaded
    import-values: # (optional)
      - ImportValues holds the mapping of source values to parent key to be imported. Each item can be a string or pair of child/parent sublist items.
    alias: (optional) Alias to be used for the chart. Useful when you have to add the same chart multiple times
maintainers: # (optional)
  - name: The maintainers name (required for each maintainer)
    email: The maintainers email (optional for each maintainer)
    url: A URL for the maintainer (optional for each maintainer)
icon: A URL to an SVG or PNG image to be used as an icon (optional).
appVersion: The version of the app that this contains (optional). This needn't be SemVer.
deprecated: Whether this chart is deprecated (optional, boolean)
annotations:
  example: A list of annotations keyed by name (optional).
```

其他字段将被忽略。

#### Charts 和版本控制

每个 chart 必须有一个版本号。版本号必须按照 [SemVer 2](https://semver.org/spec/v2.0.0.html) 标准.与 Helm Classic 格式不同，Helm V2 及更高版本使用版本号作为发布标记。仓库中的包以 name 和 versoion 为唯一识别。

例如，一个 nginx chart 的版本设置为 `version: 1.2.3`，将被命名为：`nginx-1.2.3.tgz`。

很多复杂的 SemVer2 命名也是支持的，如 `version: 1.2.3-alpha.1+ef365`。但是非 SemVer 命名是明确禁止的。

注意：虽然 Helm Classic 和 Deployment Manager 在 chart 方面都非常适合 GitHub，但 Helm V2 或更高的版本并不依赖或需要 GitHub 甚至 Git。因此，它不使用 Git SHA 进行版本控制。

Helm 中的许多工具会用到 `Chart.yaml` 中的 `version` 字段，包括 CLI。在生成包时，`helm package` 命令将使用 `Chart.yaml` 中的版本名作为包名的 token。系统假定 chart 包名称中的版本号与 `Chart.yaml` 中的版本号相匹配。不符合这个情况会导致错误。

#### apiVersion 字段

对于至少需要 Helm 3 的 chart 来说，`apiVersion` 字段应该是 `v2`。支持以前的 Helm 版本的 chart `apiVersion` 设置为 `v1`，仍然可以被 Helm 3 安装。

从 `v1` 改成 `v2`

- `dependencies` 字段定义 chart 的依赖，在 v1 chart 中这些依赖的定义在一个单独的文件中 `requirements.yaml`。
- `type` 字段，区分应用程序和 library charts。

#### appVersion 字段

注意 `appVersion` 字段和 `version` 字段没有关系。它是指定应用程序版本的一种方法。例如，drupal chart 可能有一个 `appVersion: 8.2.1`，表示 chart 中包含的 drupal 的版本（默认）是 `8.2.1`。这个字段是信息行的，不影响 chart 版本的计算。

#### kubeVersion 字段

可选的 `kubeVersion` 字段可以定义支持的 Kubernetes 版本的 semver 约束。当 Helm 安装 chart 时，会校验版本约束，如果是不支持的 Kubernetes 版本，则会失败。

版本约束可以包含空格分隔的 AND 比较符，如 `>= 1.13.0 < 1.15.0`。

它们本身可以与 `||` 操作符组合在一起，如 `>= 1.13.0 < 1.14.0 || >= 1.14.1 < 1.15.0`

在这个例子中，`1.14.0` 版本被排除在外，如果某些已知版本的 bug 会阻止 chart 的正常运行，这是有意义的。

除了使用运算符 `=` `!=` `>` `<` `>=` `<=` 的版本约束外，还支持以下速记符号：

- `1.1 - 2.3.4` 相当于 `>= 1.1 <= 2.3.4`。
- 通配符 `x`、`X` 和 `*`，其中 `1.2.x` 相当于 `>= 1.2.0 < 1.3.0`。
- 波浪符范围（允许修改补丁版本），其中 `~1.2.3` 相当于 `>= 1.2.3 < 1.3.0`。
- Caret 范围（允许轻微的版本变化），其中 `^1.2.3`相当于 `>= 1.2.3 < 2.0.0`。

关于支持的 semver 约束的详细解释，参考 [Masterminds/semver](https://github.com/Masterminds/semver)。

#### 弃用的 charts

当在 chart 仓库管理 chart 时，有时可能需要弃用一个 chart。`Chart.yaml` 文字中的可选字段 `deprecated` 可以用来标记一个 chart 已被弃用。如果一个 chart 的最新版本在仓库中被标记为废弃，那么整个 chart 被认为是废弃的。chart 的名称可以在以后发布一个没有被标记废弃的新版本来重复使用。

弃用 chart 的流程，如下 [kubernetes/charts](https://github.com/helm/charts) 项目所示：

1. 更新 chart 的 `Chart.yaml`，将 chart 标记为废弃的，并且更新版本。
2. 在 chart Repository 中发布新的 chart 版本。
3. 从源代码库中删除 chart（例如 git）。

#### chart 类型

`type` 字段定义了 chart 的类型。有两个可选的类型：`application` 和 `library`。`application` 是默认类型，是可以完全操作的标准 chart。`library` chart 为 chart builder 提供了使用工具和功能。一个 library chart 与 application chart 不同之处在于，它是不可安装的，通常不包含任何资源对象。

注意，一个 application chart 可以被当做 library chart 使用，只需要设置 `type` 为 `library`。chart 会被当做 library chart 渲染，其中的所有工具和函数都可以被利用。chart 的所有资源不会被渲染。

### Chart LICENSE, README 和 NOTES

charts 可以包含描述 chart 的安装，配置，使用和 lisense 的文件。

### chart 依赖

在 Helm 中，一个 chart 可能依赖多个其他 charts。这些依赖关系可以通过 `Chart.yaml` 中的 `dependencies` 字段动态链接，也可以放入 `charts/` 目录进行手动管理。

#### 通过 dependencies 字段管理依赖

当前 chart 依赖的 chart 以列表形式定义在 `dependencies` 字段：

```yml
dependencies:
  - name: apache
    version: 1.2.3
    repository: https://example.com/charts
  - name: mysql
    version: 3.2.1
    repository: https://another.example.com/charts
```

- `name` chart 的 name
- `version` chart 的版本
- `repository` chart 仓库的完整 URL。注意必须使用 `helm repo add`  在本地添加 repo。
- 你可以使用 repo 的名称而不是 URL。

```bash
helm repo add fantastic-charts https://fantastic-charts.storage.googleapis.com
```

```yml
dependencies:
  - name: awesomeness
    version: 1.0.0
    repository: "@fantastic-charts"
```

一旦你定义了依赖关系，就可以运行 `helm dependency update`，它会将指定的依赖下载到 `charts` 目录。

```bash
$ helm dep up foochart
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "local" chart repository
...Successfully got an update from the "stable" chart repository
...Successfully got an update from the "example" chart repository
...Successfully got an update from the "another" chart repository
Update Complete. Happy Helming!
Saving 2 charts
Downloading apache from repo https://example.com/charts
Downloading mysql from repo https://another.example.com/charts
```

当 `helm dependency update` 检索 charts 时，它将以 chart 存档的形式存储在 `charts/` 目录下。因此，对于上面的例子，希望在 `charts/` 目录下看到以下文件：

```bash
charts/
  apache-1.2.3.tgz
  mysql-3.2.1.tgz
```

#### alias 字段

除上述其他字段外，每个依赖条目还可包含可选字段 `alias`。

为依赖的 chart 添加别名会将 chart 放入依赖关系中，并使用别名作为新的依赖关系名称。

如果需要使用其他名称访问 chart，可以使用 `alias`。

```yml
# parentchart/Chart.yaml

dependencies:
  - name: subchart
    repository: http://localhost:10191
    version: 0.1.0
    alias: new-subchart-1
  - name: subchart
    repository: http://localhost:10191
    version: 0.1.0
    alias: new-subchart-2
  - name: subchart
    repository: http://localhost:10191
    version: 0.1.0
```

上面的例子中，可以得到 `parentchart` 的 3 个依赖：

```bash
subchart
new-subchart-1
new-subchart-2
```

也可以通过手动方法实现，在 `charts/` 中用不同名称多次复制/粘贴目录中的同一个 chart 。

#### tags 和 condition 字段

除上述其他字段外，每个依赖条目还可包含可选字段 `tags` 和 `condition`。

所有 charts 默认会被加载。如果存在 `tags` 和 `condition` 字段，将对它们进行评估并用于控制所应用的 chart 的加载。

**Condition** - `condition` 字段包含一个或多个 YAML 路径（用逗号分隔）。如果此路径存在于顶级父级的值中并且解析为布尔值，则将根据该布尔值启用或禁用 chart。只有在列表中找到的第一个有效路径才被评估，如果没有路径存在，那么该条件不起作用。

**Tags** - `tags` 字段是与 chart 相关联的 YAML 标签列表。在顶级父级的值中，可以通过指定标签和布尔值来启用或禁用所有带有标签的 chart。

```yml
# parentchart/Chart.yaml

dependencies:
  - name: subchart1
    repository: http://localhost:10191
    version: 0.1.0
    condition: subchart1.enabled, global.subchart1.enabled
    tags:
      - front-end
      - subchart1
  - name: subchart2
    repository: http://localhost:10191
    version: 0.1.0
    condition: subchart2.enabled,global.subchart2.enabled
    tags:
      - back-end
      - subchart2
```

```yml
# parentchart/values.yaml

subchart1:
  enabled: true
tags:
  front-end: false
  back-end: true
```

上面的示例中，所有的带有标签 `front-end` 的 chart 会被禁用，但是由于父级 `subchart1.enabled` 的值为 `true`，所以此条件将覆盖该 `front-end` 标签，`subchart1` 会启用。

由于 `subchart2` 被标记 `back-end` 和标签为 `true`，`subchart2` 将被启用。要注意的是，虽然 `subchart2` 指定了一个条件，但父值中没有对应的路径和值，因此条件无效。

在命令行中使用 Tags 和 Conditiions，`--set` 参数可用来更改 tag 和 conditions 值。

```bash
helm install --set tags.front-end=true --set subchart2.enabled=false
```

Tags 和 Conditiion 解析：

- **Conditions (设置 values) 总会覆盖 tags 配置**。第一个 chart 条件路径存在时会忽略后面的路径。
- 如果 chart 的某 tag 中的任一 tag 的值为 `true`，那么该 tag 的值为 `true`，并启用这个 chart。
- Tags 和 conditions 值必须在顶级父级的值中进行设置。
- key `tags:` 的值中的关键字必须是顶级的关键字。目前不支持全局和嵌套 `tags:` 表格。

#### 导入子值

在某些情况下，允许子 chart 的值传到父 chart 并作为通用默认值共享。使用 `exports` 格式的另一个好处是，它可以使未来的工具能够考虑用户可设置的值。

要导入的 value 的 key 可以在父 chart 的 `dependencies` 中的 `import-values` 字段使用 YAML list 指定。list 列表中的每一个项目都是一个键，它是从子 chart 的 `exports` 字段中导入的。

要导入不包含在 `exports` key 中的值，使用 `child-parent` 格式。下面描述了两种格式的例子。

##### 使用 exports 格式

如果子 chart 的 `values.yaml` 文件中在根节点包含了 `exports` 字段，则可以通过指定要导入的 key 将其内容直接导入到父级的值中， 如下所示：

```yml
# parent's Chart.yaml file

dependencies:
  - name: subchart
    repository: http://localhost:10191
    version: 0.1.0
    import-values:
      - data
```

```yml
# child's values.yaml file

exports:
  data:
    myint: 99
```

只要在导入列表中指定了 `data` key，Helm 就会在子 chart 的 `exports` 字段中查找 `data` key 并导入它的内容。

最终的父级 value 会包含我们导出字段：

```yml
# parent's values

myint: 99
```

注意 key `data` 没有包含在父级最终的 value 中，如果想指定这个父级键，要使用 `child-parent` 格式。

##### 使用 child-parent 格式

要访问子 chart 中未包含在 `exports` 键中的值，需要指定要导入的值的源 key （child）和父 chart （parent）中值的目标路径。

下面的例子中的 `import-values` 告诉 Helm 去拿在 `child:` 路径发现的任何值，并将其复制到父值 `parent:` 指定的路径：

```yml
# parent's Chart.yaml file

dependencies:
  - name: subchart1
    repository: http://localhost:10191
    version: 0.1.0
    ...
    import-values:
      - child: default.data
        parent: myimports
```

上面的例子中，在 `subchart1` 里面找到的 `default.data` 的值会被导入到父 chart 的 `myimports` 键中，如下：

```yml
# parent's values.yaml file

myimports:
  myint: 0
  mybool: false
  mystring: "helm rocks!"
```

```yml
# subchart1's values.yaml file

default:
  data:
    myint: 999
    mybool: true
```

父 chart 的结果值将会是这样：

```yml
# parent's final values

myimports:
  myint: 999
  mybool: true
  mystring: "helm rocks!"
```

父 chart 中的最终值包含了从 `subchart1` 中导入的 `myint` 和 `mybool` 字段。

### 通过 charts/ 目录手动管理依赖

如果对依赖进行更多控制，可以将有依赖关系的 chart 复制到 `charts/` 目录中来显式表达这些依赖关系。

依赖可以是 chart 包（`foo-1.2.3.tgz`）或者一个解压的 chart 目录。但是名字不能以 `_` 或 `.` 开头，否则会被 chart 加载器忽略。

比如，WordPress chart 依赖于 Apache chart，那么 Apache chart （正确版本的）需要放在 WordPress chart 的 `charts/` 目录中：

```bash
wordpress:
  Chart.yaml
  # ...
  charts/
    apache/
      Chart.yaml
      # ...
    mysql/
      Chart.yaml
      # ...
```

上面的例子展示了 WordPress chart 如何通过将这些 chart 包含在 `charts/` 目录中来表示它对 Apache 和 MySQL 的依赖。

注意，使用 `helm pull` 命令，将依赖放入 `charts/` 目录。

假设一个命名为 A 的 chert 创建了一下 Kubernetes 对象：

- namespace "A-Namespace"
- statefulset "A-StatefulSet"
- service "A-Service"

另外，A 以来于 chart B 从创建的对象：

- namespace "B-Namespace"
- replicaset "B-ReplicaSet"
- service "B-Service"

安装/升级 chart A 后，会创建/修改一个单独的 Helm release。这个版本会按照下面的顺序创建/升级以下所有的 Kubernetes 对象：

- A-Namespace
- B-Namespace
- A-Service
- B-Service
- B-ReplicaSet
- A-StatefulSet

这是因为 Helm 安装/升级 cherts 时，chart 中所有的 Kubernetes 对象以及依赖会：

- 聚合成一个单一的集合；然后
- 按类型排序，然后按名称排序；然后
- 按这个顺序 创建/升级。

至此会为 chart 及其依赖创建一个包含所有对象的 release 版本。

Kubernetes 类型的安装顺序，按照 [kind_sorter.go](https://github.com/helm/helm/blob/484d43913f97292648c867b56768775a55e4bba6/pkg/releaseutil/kind_sorter.go) 中给出的枚举 `InstallOrder` 排序。

#### 使用依赖的操作部分

上面的部分解释了如何指定 chart 的但是，但是对使用 `helm install` 和 `helm upgrade` 安装 chart 有什么影响？

### Templates 和 Values

Helm 的 templates 是用 [Go template](https://golang.org/pkg/text/template/) 写的，增加了 50 多个来自 [Sprig 库](https://github.com/Masterminds/sprig)的附加模板函数和其他一些专业函数。

所有的模版文件存放在 `templates/` 目录下。当 Helm 渲染 charts 时，它会通过模版引擎传递目录中的每一个文件。

给模版提供 Values 有两种方式：

- chart 的开发者可以提供一个 `values.yaml` 文件，这个文件包含默认值。
- chart 的使用者可以提供一个包含值 YAML 文件。它可以提供给命令行 `helm install`。

当一个使用者提供了自定义的值时，这些值会负载 chart 中 `values.yaml` 文件中的值。

#### 模版文件

模板文件遵循编写 Go 模板的标准约定。一个模版示例：

```yml
apiVersion: v1
kind: ReplicationController
metadata:
  name: deis-database
  namespace: deis
  labels:
    app.kubernetes.io/managed-by: deis
spec:
  replicas: 1
  selector:
    app.kubernetes.io/name: deis-database
  template:
    metadata:
      labels:
        app.kubernetes.io/name: deis-database
    spec:
      serviceAccount: deis-database
      containers:
        - name: deis-database
          image: {{ .Values.imageRegistry }}/postgres:{{ .Values.dockerTag }}
          imagePullPolicy: {{ .Values.pullPolicy }}
          ports:
            - containerPort: 5432
          env:
            - name: DATABASE_STORAGE
              value: {{ default "minio" .Values.storage }}
```

上面的例子，基于 <https://github.com/deis/charts>， 是一个 Kubernetes ReplicationController 的模板。可以使用下面四种模板值（一般被定义在 `values.yaml` 文件）：

- `imageRegistry`: Docker image 的 repo
- `dockerTag`: Docker image 的 tag
- `pullPolicy`: image 的拉取策略
- `storage`: 后台存储，默认设置为 "minio"

所有的值都是模板作者定义的。Helm 不需要或指定参数。

#### 预定义的 Values

Values 可以通过模板中 `.Values` 对象访问的 `values.yaml` 文件（或者通过 `--set` 参数）提供。但是可以在模板中访问其他预定义的数据片段。

以下值是预定义的，可用于每个模板，并且不能被覆盖。与所有 Values 一样，名称时大小写敏感的。

- `Release.Name`: Release 名称(不是 chart 的)
- `Release.Namespace`: chart 所发布到的 namespace
- `Release.Service`: 处理 release 的服务
- `Release.IsUpgrade`: 如果当前操作是升级或回滚，则为 `true`
- `Release.IsInstall`: 如果当前操作是安装，则为 `true`
- `Chart`: `Chart.yaml` 的内容。因此，chart 的版本可以通过 `Chart.Version` 获得， 并且维护者在 `Chart.Maintainers` 里。
- `Files`: chart 中的包含了非特殊文件的 map-like 对象。不允许访问模板， 但是可以访问现有的其他文件（除非被 `.helmignore` 排除在外）。使用 `{{ index .Files "file.name" }}` 可以访问文件或者使用 `{{.Files.Get name }}` 功能。 也可以使用 `{{ .Files.GetBytes }}` 作为 `[]byte` 访问文件内容。
- `Capabilities`: 包含了 Kubernetes 版本信息的 map-like 对象。(`{{ .Capabilities.KubeVersion }}` 和支持的 Kubernetes API 版本(`{{ .Capabilities.APIVersions.Has "batch/v1" }}`)

注意：任何未知的 `Chart.yaml` 字段会被抛弃。它们无法在 `Chart` 对象中访问。因此， `Chart.yaml` 不能用于将任意结构的数据传递到模板中。不过 values 文件可以用于传递。

#### Values 文件

考虑到前面部分的模板，`values.yaml` 文件必须要提供的值如下：

```yml
imageRegistry: "quay.io/deis"
dockerTag: "latest"
pullPolicy: "Always"
storage: "s3"
```

values 文件为 YAML 格式。chart 会包含一个默认的 `values.yaml` 文件。 Helm 安装命令允许用户提供附加的 YAML values 来覆盖这个 values：

```bash
helm install --generate-name --values=myvals.yaml wordpress
```

`-f` 是 `--values` 的简写。

以这种方式传递值时，它们会合并到默认的 values 文件中。比如，`myvals.yaml` 文件如下：

```yml
storage: "gcs"
```

当在 chart 中这个值被合并到 `values.yaml` 文件中时，生成的内容是这样：

```yml
imageRegistry: "quay.io/deis"
dockerTag: "latest"
pullPolicy: "Always"
storage: "gcs"
```

注意只有最后一个字段会覆盖。

注意：chart 包含的默认 values 文件必须被命名为 `values.yaml`。不过在命令行指定的文件可以是其他名称。

注意：如果 `helm install` 或 `helm upgrade` 使用了 `--set` 参数，这些值在客户端会被简单地转换为 YAML。

注意：如果 values 文件存在任何必需的条目，可以在 chart 模板中使用 `'required' 函数` 声明为必需的。

然后使用模板中的 `.Values` 对象就可以任意访问这些值了：

```yml
apiVersion: v1
kind: ReplicationController
metadata:
  name: deis-database
  namespace: deis
  labels:
    app.kubernetes.io/managed-by: deis
spec:
  replicas: 1
  selector:
    app.kubernetes.io/name: deis-database
  template:
    metadata:
      labels:
        app.kubernetes.io/name: deis-database
    spec:
      serviceAccount: deis-database
      containers:
        - name: deis-database
          image: {{ .Values.imageRegistry }}/postgres:{{ .Values.dockerTag }}
          imagePullPolicy: {{ .Values.pullPolicy }}
          ports:
            - containerPort: 5432
          env:
            - name: DATABASE_STORAGE
              value: {{ default "minio" .Values.storage }}
```

#### Scope, Dependencies 和 Values

Values 文件可以声明顶级 chart 的值，也可以为 `charts/` 目录中包含的其他任意 chart 声明值。 或者换个说法，values 文件可以为 chart 及其任何依赖项提供值。比如，上面示例的 WordPress chart 同时有 mysql 和 apache 作为依赖。values 文件可以为以下所有这些组件提供值：

```yml
title: "My WordPress Site" # Sent to the WordPress template

mysql:
  max_connections: 100 # Sent to MySQL
  password: "secret"

apache:
  port: 8080 # Passed to Apache
```

更高级别的 chart 可以访问下面定义的所有变量。所以 WordPress chart 可以通过 `.Values.mysql.password` 访问 mysql 密码。但较低级别的 chart 无法访问父 chart 中的内容，因此 mysql 将无法访问该 `title` 属性。同样的，也不能访问 `apache.port`。

值是命名空间限制的，但命名空间被删减了。因此对于 WordPress chart 来说，它可以访问 `.Values.mysql.password`。但是对于 MySQL chart 来说，这些值的范围已经减小了，并且删除了名 namespace 前缀，将密码字段简单地视为 `.Values.password`。

#### 全局 Values

从 2.0.0-Alpha.2 开始，Helm 支持特殊的 "global" 值。设想一下前面的示例中的修改版本：

```yml
title: "My WordPress Site" # Sent to the WordPress template

global:
  app: MyWordPress

mysql:
  max_connections: 100 # Sent to MySQL
  password: "secret"

apache:
  port: 8080 # Passed to Apache
```

上面添加了 `global` 部分和一个值 `app: MyWordPress`。这个值以 `.Values.global.app` 在所有 chart 中有效。

比如，mysql 模板可以以 `{{.Values.global.app}}` 访问 app，同样 apache chart 也可以访问。 实际上，上面的 values 文件会重新生成为这样：

```yml
title: "My WordPress Site" # Sent to the WordPress template

global:
  app: MyWordPress

mysql:
  global:
    app: MyWordPress
  max_connections: 100 # Sent to MySQL
  password: "secret"

apache:
  global:
    app: MyWordPress
  port: 8080 # Passed to Apache
```

这提供了一种和所有的子 chart 共享顶级变量的方式，这在类似 label 设置 metadata 属性时会很有用。

如果子 chart 声明了一个全局变量，那这个变量会**向下传递**（到子 chart 的子 chart），但不会向上传递到父级 chart。 子 chart 无法影响父 chart 的值。

并且，**父 chart 的全局变量优先于子 chart 中的全局变量**。

#### 架构文件

有时候，chart 的维护者可能想要给 values 定义一个结构体。 这可以通过在 `values.schema.json` 文件中定义一个  schema 来实现。一个 shcema 可以使用 [JSON schema](https://json-schema.org/) 来表示。看起来像这样：

```yml
{
  "$schema": "https://json-schema.org/draft-07/schema#",
  "properties": {
    "image": {
      "description": "Container Image",
      "properties": {
        "repo": {
          "type": "string"
        },
        "tag": {
          "type": "string"
        }
      },
      "type": "object"
    },
    "name": {
      "description": "Service name",
      "type": "string"
    },
    "port": {
      "description": "Port",
      "minimum": 0,
      "type": "integer"
    },
    "protocol": {
      "type": "string"
    }
  },
  "required": [
    "protocol",
    "port"
  ],
  "title": "Values",
  "type": "object"
}
```

这个 schema 将被应用到 values 并验证它。当执行以下任意命令时会进行验证：

- `helm install`
- `helm upgrade`
- `helm lint`
- `helm template`

一个符合此 schema 要求的 `values.yaml` 文件示例如下所示：

```yml
name: frontend
protocol: https
port: 443
```

注意这个 schema 被应用到了最终的 `.Values` 对象，而不仅仅是这个 `values.yaml` 文件。这意味着下面的 `yaml` 文件是有效的，因为 chart 是用下面带 `--set` 选项安装的：

```yml
name: frontend
protocol: https
```

```bash
helm install --set port=443
```

此外，最终的 `.Values` 对象是根据所有的子 chart  schema 检查。 这意味着父 chart 无法规避子 chart 的限制。这也是逆向的 - 如果子 chart 的 `values.yaml` 文件无法满足需求，父 chart 必须 满足这些限制才能有效。

#### 参考

在编写 templates， values 和 schema 文件时，有几个标准的参考可以帮助你：

- [Go templates](https://godoc.org/text/template)
- [Extra template functions](https://godoc.org/github.com/Masterminds/sprig)
- [The YAML format](https://yaml.org/spec/)
- [JSON Schema](https://json-schema.org/)

### 用户自定义资源（CRD）

Kubernetes 提供了一种声明 Kubernetes 新类型对象的机制。使用 CustomResourceDefinition（CRD）， Kubernetes 开发者可以声明自定义资源类型。

Helm 3 中,CRD 被视为一种特殊的对象。它们被安装在 chart 的其他部分之前，并受到一些限制。

CRD YAML 文件应被放置在 chart 的 `crds/` 目录中。多个 CRD（用 YAML 的开始和结束符分隔）可以被放在同一个文件中。Helm 会尝试加载 CRD 目录中所有文件到 Kubernetes 中。

**CRD 文件无法模板化**，必须是普通的 YAML 文档。

当 Helm 安装新 chart 时，会上传 CRD，暂停安装直到 CRD 可以被 API 服务使用，然后启动模板引擎， 渲染 chart 其他部分，并上传到 Kubernetes。因为这个顺序，CRD 信息会在 Helm 模板中的 `.Capabilities` 对象中生效，并且 Helm 模板会创建在 CRD 中声明的新的实例对象。

例如，如果你的 chart 在 `crds/` 目录中有针对于 `CronTab` 的 CRD，你可以在 `templates/` 目录中创建 `CronTab` 类型实例：

```yml
crontabs/
  Chart.yaml
  crds/
    crontab.yaml
  templates/
    mycrontab.yaml
```

`crontab.yaml` 文件不能包含模板指令：

```yml
kind: CustomResourceDefinition
metadata:
  name: crontabs.stable.example.com
spec:
  group: stable.example.com
  versions:
    - name: v1
      served: true
      storage: true
  scope: Namespaced
  names:
    plural: crontabs
    singular: crontab
    kind: CronTab
```

然后模板 `mycrontab.yaml` 可以创建一个新的 `CronTab`（照例使用模板）：

```yml
apiVersion: stable.example.com
kind: CronTab
metadata:
  name: {{ .Values.name }}
spec:
   # ...
```

Helm 在安装 `templates/` 目录下的内容之前会保证 `CronTab` 类型安装成功并对 Kubernetes API 可用。

#### CRD 的限制

不像大部分的 Kubernetes 对象，CRD 是全局安装的。因此 Helm 管理 CRD 时会采取非常谨慎的方式。 CRD 受到以下限制：

- CRD 永远不会被重新安装。如果 Helm 确定 `crds/` 目录中的 CRD 已经存在（忽略版本），Helm 将不会安装或升级。
- CRD 永远不会在升级或回滚时安装。Helm 只会在安装操作时创建 CRD。
- CRD 永远不会被删除。自动删除 CRD 会删除集群中所有命名空间中的所有 CRD 内容。因此 Helm 不会删除 CRD。

想要升级或删除 CRD 的操作者应该谨慎地手动执行此操作。

### 使用 Helm 管理 Chart

helm 工具有一系列命令用来处理 chart。

它可以为你创建一个新 chart：

```bash
$ helm create mychart
Created mychart/
```

编辑了 chart 之后，helm 能把它打包成一个 chart 存档：

```bash
$ helm package mychart
Archived mychart-0.1.-.tgz
```

也可以使用 helm 找到 chart 的格式或信息的问题：

```bash
$ helm lint mychart
No issues found
```

### Chart 仓库

chart 仓库是一个 HTTP 服务器，包含了一个或多个打包的 chart。helm 可以用来管理本地 chart 目录，当需要共享 chart 时，首选的机制就是使用 chart 仓库。

任何可以服务于 YAML 文件和 tar 文件并可以响应 GET 请求的 HTTP 服务器都可以用做仓库服务器。 Helm 团队已经测试了一些服务器，包括 Google Cloud Storage，以及使用 website 的 S3。

仓库的主要特征存在一个名为 `index.yaml` 的特殊文件，这个文件中包含仓库提供的包的完整列表， 以及允许检索和验证这些包的元数据。

在客户端，仓库使用 `helm repo` 命令管理。然而，Helm 不提供上传 chart 到远程仓库的工具。 这是因为这样做会给执行服务器增加大量的必要条件，也就增加了设置仓库的障碍。

### Chart Starter 包

`helm create` 命令可以附带一个可选的 `--starter` 选项让你指定一个 "starter chart"。

Starter 就只是普通 chart，但是被放在 `$XDG_DATA_HOME/helm/starters`。作为一个 chart 开发者，你可以编写被特别设计用来作为启动的 chart。设计此类 chart 应注意以下考虑因素：

- `Chart.yaml` 将被生成器覆盖。
- 用户可能想要修改此类 chart 的内容，所以文档应该说明用户如何做到这一点。
- 所有出现的 `<CHARTNAME>` 都会被替换为指定为 chart 名称，以便 chart 可以作为模板使用。

当前在 `$XDG_DATA_HOME/helm/starters` 目录中增加一个 chart 的唯一方式就是手动拷贝一个 chart 到这个目录。在 chart 文档中，可能需要解释这个过程。
