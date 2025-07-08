---
title: 容器镜像
weight: 3
---

容器里的进程看到的文件系统又是什么样子的？

这一定是一个关于 Mount Namespace 的问题：容器里的应用进程，理应看到一份完全独立的文件系统。

但其实**即使开启了 Mount Namespace，容器进程看到的文件系统也跟宿主机完全一样**。

运行下面的代码来验证：

```c
#define _GNU_SOURCE
#include <sys/mount.h> 
#include <sys/types.h>
#include <sys/wait.h>
#include <stdio.h>
#include <sched.h>
#include <signal.h>
#include <unistd.h>
#define STACK_SIZE (1024 * 1024)
static char container_stack[STACK_SIZE];
char* const container_args[] = {
  "/bin/bash",
  NULL
};
 
int container_main(void* arg)
{  
  printf("Container - inside the container!\n");
  execv(container_args[0], container_args);
  printf("Something's wrong!\n");
  return 1;
}
 
int main()
{
  printf("Parent - start a container!\n");
  int container_pid = clone(container_main, container_stack+STACK_SIZE, CLONE_NEWNS | SIGCHLD , NULL);
  waitpid(container_pid, NULL, 0);
  printf("Parent - container stopped!\n");
  return 0;
}
```

编译一下这个程序：

```bash
$ gcc -o ns ns.c
$ ./ns
Parent - start a container!
Container - inside the container!
```

进入了这个“容器”当中。可是，如果在“容器”里执行一下 `ls` 指令的话，我们就会发现一个有趣的现象：`/tmp` 目录下的内容跟宿主机的内容是一样的。

为什么？

**Mount Namespace 修改的，是容器进程对文件系统“挂载点”的认知**。这也就意味着，**只有在“挂载”这个操作发生之后，进程的视图才会被改变**。

除了声明要启用 Mount Namespace 之外，还要告诉容器进程，有哪些目录需要重新挂载。就比如这个 `/tmp` 目录。添加一步重新挂载 `/tmp` 目录的操作：

```c
int container_main(void* arg)
{
  printf("Container - inside the container!\n");
  // 如果你的机器的根目录的挂载类型是 shared，那必须先重新挂载根目录
  // mount("", "/", NULL, MS_PRIVATE, "");
  mount("none", "/tmp", "tmpfs", 0, "");
  execv(container_args[0], container_args);
  printf("Something's wrong!\n");
  return 1;
}
```

`mount(“none”, “/tmp”, “tmpfs”, 0, “”)` 告诉了容器以 tmpfs（内存盘）格式，重新挂载了 `/tmp` 目录。再次编译运行，执行 `ls` ，这次 `/tmp` 变成了一个空目录。


这就是 **Mount Namespace 跟其他 Namespace 的使用略有不同的地方：它对容器进程视图的改变，一定是伴随着挂载操作（mount）才能生效**。

Docker 容器进程启动之前重新挂载它的整个根目录 “/”。而由于 Mount Namespace 的存在，这个挂载对宿主机不可见。

在 Linux 操作系统里，有一个名为 chroot 的命令可以帮助你在 shell 中方便地完成这个工作。顾名思义，它的作用就是帮你“change root file system”，即改变进程的根目录到你指定的位置。它的用法也非常简单。


假设，现在有一个 `$HOME/test` 目录，想要把它作为一个 `/bin/bash` 进程的根目录。

首先，创建一个 test 目录和几个 lib 文件夹：

```bash
$ mkdir -p $HOME/test
$ mkdir -p $HOME/test/{bin,lib64,lib}
$ cd $T
```

然后，把 bash 命令拷贝到 test 目录对应的 bin 路径下：

```bash
$ cp -v /bin/{bash,ls} $HOME/test/bin
```

接下来，把 bash 命令需要的所有 so 文件，也拷贝到 test 目录对应的 lib 路径下。找到 so 文件可以用 ldd 命令：

```bash
$ T=$HOME/test
$ list="$(ldd /bin/ls | egrep -o '/lib.*\.[0-9]')"
$ for i in $list; do cp -v "$i" "${T}${i}"; done
```

最后，执行 chroot 命令，告诉操作系统，将使用 `$HOME/test` 目录作为 `/bin/bash` 进程的根目录：

```bash
$ chroot $HOME/test /bin/bash
```

这时，你如果执行 "ls /"，就会看到，它返回的都是 `$HOME/test` 目录下面的内容。

**实际上，Mount Namespace 正是基于对 chroot 的不断改良才被发明出来的，它也是 Linux 操作系统里的第一个 Namespace**。

为了能够让容器的这个根目录看起来更“真实”，我们一般会在这个容器的根目录下挂载一个完整操作系统的文件系统，比如 Ubuntu16.04 的 ISO。

**而这个挂载在容器根目录上、用来为容器进程提供隔离后执行环境的文件系统，就是所谓的“容器镜像”。它还有一个更为专业的名字，叫作：rootfs（根文件系统）**。

## rootfs 根文件系统

一个最常见的 rootfs，或者说容器镜像，会包括如下所示的一些目录和文件，比如 `/bin`，`/etc`，`/proc` 等等：

```bash
$ ls /
bin dev etc home lib lib64 mnt opt proc root run sbin sys tmp usr var
```

而你进入容器之后执行的 `/bin/bash`，就是 `/bin` 目录下的可执行文件，与宿主机的 `/bin/bash` 完全不同。

对 Docker 项目来说，它最核心的原理实际上就是为待创建的用户进程：

- 启用 Linux Namespace 配置；
- 设置指定的 Cgroups 参数；
- 切换进程的根目录（Change Root）。

这样，一个完整的容器就诞生了。不过，Docker 项目在最后一步的切换上会优先使用 `pivot_root` 系统调用，如果系统不支持，才会使用 chroot。

需要明确的是，**rootfs 只是一个操作系统所包含的文件、配置和目录，并不包括操作系统内核**。在 **Linux 操作系统中，这两部分是分开存放的，操作系统只有在开机启动时才会加载指定版本的内核镜像**。

rootfs 只包括了操作系统的“躯壳”，并没有包括操作系统的“灵魂”。

这就意味着，如果你的应用程序需要配置内核参数、加载额外的内核模块，以及跟内核进行直接的交互，你就需要注意了：这些操作和依赖的对象，都是宿主机操作系统的内核，它对于该机器上的所有容器来说是一个“全局变量”，牵一发而动全身。

这也是容器相比于虚拟机的主要缺陷之一：毕竟后者不仅有模拟出来的硬件机器充当沙盒，而且每个沙盒里还运行着一个完整的 Guest OS 给应用随便折腾。

**正是由于 rootfs 的存在，容器才有了一个被反复宣传至今的重要特性：一致性**。

**由于 rootfs 里打包的不只是应用，而是整个操作系统的文件和目录，也就意味着，应用以及它运行所需要的所有依赖，都被封装在了一起**。

有了容器镜像“打包操作系统”的能力，这个最基础的依赖环境也终于变成了应用沙盒的一部分。这就赋予了容器所谓的一致性：无论在本地、云端，还是在一台任何地方的机器上，用户只需要解压打包好的容器镜像，那么这个应用运行所需要的完整的执行环境就被重现出来了。

**这种深入到操作系统级别的运行环境一致性，打通了应用在本地开发和远端执行环境之间难以逾越的鸿沟**。

### UFS 联合文件系统

每开发一个应用，或者升级一下现有的应用，都要重复制作一次 rootfs 吗？

比如，我现在用 Ubuntu 操作系统的 ISO 做了一个 rootfs，然后又在里面安装了 Java 环境，用来部署我的 Java 应用。那么，我的另一个同事在发布他的 Java 应用时，显然希望能够直接使用我安装过 Java 环境的 rootfs，而不是重复这个流程。

一种比较直观的解决办法是，我在制作 rootfs 的时候，每做一步“有意义”的操作，就保存一个 rootfs 出来，这样其他同事就可以按需求去用他需要的 rootfs 了。

但是，这个解决办法并不具备推广性。原因在于，一旦你的同事们修改了这个 rootfs，新旧两个 rootfs 之间就没有任何关系了。这样做的结果就是极度的碎片化。

那么，既然这些修改都基于一个旧的 rootfs，我们能不能以增量的方式去做这些修改呢？这样做的好处是，所有人都只需要维护相对于 base rootfs 修改的增量内容，而不是每次修改都制造一个“fork”。


这也正是为何，Docker 公司在实现 Docker 镜像时并没有沿用以前制作 rootfs 的标准流程，而是做了一个小小的创新：

**Docker 在镜像的设计中，引入了层（layer）的概念。也就是说，用户制作镜像的每一步操作，都会生成一个层，也就是一个增量 rootfs**。

用到了一种叫作**联合文件系统**（Union File System）的能力。

Union File System 也叫 UnionFS，最主要的功能是将多个不同位置的目录联合挂载（union mount）到同一个目录下。比如，我现在有两个目录 A 和 B，它们分别有两个文件：

```bash
$ tree
.
├── A
│  ├── a
│  └── x
└── B
  ├── b
  └── x
```

然后，我使用联合挂载的方式，将这两个目录挂载到一个公共的目录 C 上：

```bash
$ mkdir C
$ mount -t aufs -o dirs=./A:./B none ./C
```

这时，我再查看目录 C 的内容，就能看到目录 A 和 B 下的文件被合并到了一起：

```bash
$ tree ./C
./C
├── a
├── b
└── x
```

可以看到，在这个合并后的目录 C 里，有 a、b、x 三个文件，并且 x 文件只有一份。这，就是“合并”的含义。此外，如果你在目录 C 里对 a、b、x 文件做修改，这些修改也会在对应的目录 A、B 中生效。

### Advance UnionFS

Docker 项目中，又是如何使用这种 Union File System 的呢？

Ubuntu 16.04 和 Docker CE 18.05，这对组合默认使用的是 AuFS 这个联合文件系统的实现。你可以通过 docker info 命令，查看到这个信息。

**AuFS 的全称是 Another UnionFS**，后改名为 Alternative UnionFS，再后来干脆改名叫作 Advance UnionFS，从这些名字中你应该能看出这样两个事实：

1. 它是对 Linux 原生 UnionFS 的重写和改进；
2. 它的作者怨气好像很大。我猜是 Linus Torvalds（Linux 之父）一直不让 AuFS 进入 Linux 内核主干的缘故，所以我们只能在 Ubuntu 和 Debian 这些发行版上使用它。

对于 AuFS 来说，它最关键的目录结构在 `/var/lib/docker` 路径下的 `diff` 目录：

```bash
/var/lib/docker/aufs/diff/<layer_id>
```

而这个目录的作用，通过一个具体例子来看一下。

现在，启动一个容器，比如：

```bash
$ docker run -d ubuntu:latest sleep 3600
```

这时候，Docker 就会从 Docker Hub 上拉取一个 Ubuntu 镜像到本地。


这个所谓的“镜像”，实际上就是一个 Ubuntu 操作系统的 rootfs，它的内容是 Ubuntu 操作系统的所有文件和目录。不过，与之前我们讲述的 rootfs 稍微不同的是，Docker 镜像使用的 rootfs，往往由多个“层”组成：

```bash
$ docker image inspect ubuntu:latest
...
     "RootFS": {
      "Type": "layers",
      "Layers": [
        "sha256:f49017d4d5ce9c0f544c...",
        "sha256:8f2b771487e9d6354080...",
        "sha256:ccd4d61916aaa2159429...",
        "sha256:c01d74f99de40e097c73...",
        "sha256:268a067217b5fe78e000..."
      ]
    }
```

可以看到，这个 Ubuntu 镜像，实际上由五个层组成。这**五个层就是五个增量 rootfs，每一层都是 Ubuntu 操作系统文件与目录的一部分**；而在**使用镜像时，Docker 会把这些增量联合挂载在一个统一的挂载点上**（等价于前面例子里的“/C”目录）。

这个挂载点就是 `/var/lib/docker/aufs/mnt/`，比如：

```bash
/var/lib/docker/aufs/mnt/6e3be5d2ecccae7cc0fcfa2a2f5c89dc21ee30e166be823ceaeba15dce645b3e
```

不出意外的，这个目录里面正是一个完整的 Ubuntu 操作系统：

```bash
$ ls /var/lib/docker/aufs/mnt/6e3be5d2ecccae7cc0fcfa2a2f5c89dc21ee30e166be823ceaeba15dce645b3e
bin boot dev etc home lib lib64 media mnt opt proc root run sbin srv sys tmp usr var
```

那么，前面提到的五个镜像层，又是如何被联合挂载成这样一个完整的 Ubuntu 文件系统的呢？

这个信息记录在 AuFS 的系统目录 `/sys/fs/aufs` 下面。

首先，通过查看 AuFS 的挂载信息，我们可以找到这个目录对应的 AuFS 的内部 ID（也叫：si）：

```bash
$ cat /proc/mounts| grep aufs
none /var/lib/docker/aufs/mnt/6e3be5d2ecccae7cc0fc... aufs rw,relatime,si=972c6d361e6b32ba,dio,dirperm1 0 0
```

即，`si=972c6d361e6b32ba`。

然后使用这个 ID，你就可以在 `/sys/fs/aufs` 下查看被联合挂载在一起的各个层的信息：

```bash
$ cat /sys/fs/aufs/si_972c6d361e6b32ba/br[0-9]*
/var/lib/docker/aufs/diff/6e3be5d2ecccae7cc...=rw
/var/lib/docker/aufs/diff/6e3be5d2ecccae7cc...-init=ro+wh
/var/lib/docker/aufs/diff/32e8e20064858c0f2...=ro+wh
/var/lib/docker/aufs/diff/2b8858809bce62e62...=ro+wh
/var/lib/docker/aufs/diff/20707dce8efc0d267...=ro+wh
/var/lib/docker/aufs/diff/72b0744e06247c7d0...=ro+wh
/var/lib/docker/aufs/diff/a524a729adadedb90...=ro+wh
```

可以看到，镜像的层都放置在 `/var/lib/docker/aufs/diff` 目录下，然后被联合挂载在 `/var/lib/docker/aufs/mnt` 里面。

容器的 rootfs 由如三部分组成：

![]()

#### 第一部分，只读层

它是这个容器的 rootfs 最下面的五层，对应的正是 `ubuntu:latest` 镜像的五层。可以看到，它们的挂载方式都是只读的（`ro+wh`，即 `readonly+whiteout`）。

这时，我们可以分别查看一下这些层的内容：

```bash
$ ls /var/lib/docker/aufs/diff/72b0744e06247c7d0...
etc sbin usr var
$ ls /var/lib/docker/aufs/diff/32e8e20064858c0f2...
run
$ ls /var/lib/docker/aufs/diff/a524a729adadedb900...
bin boot dev etc home lib lib64 media mnt opt proc root run sbin srv sys tmp usr var
```

这些层，都以增量的方式分别包含了 Ubuntu 操作系统的一部分。

#### 第二部分，可读写层

它是这个容器的 rootfs **最上面的一层**（6e3be5d2ecccae7cc），它的挂载方式为：`rw`，即 `read write`。在没有写入文件之前，这个目录是空的。而**一旦在容器里做了写操作，修改产生的内容就会以增量的方式出现在这个层中**。

可是，如果我现在要做的，是删除只读层里的一个文件呢？

为了实现这样的**删除操作，AuFS 会在可读写层创建一个 `whiteout` 文件，把只读层里的文件“遮挡”起来**。

比如，你要删除只读层里一个名叫 foo 的文件，那么这个删除操作实际上是在可读写层创建了一个名叫 `.wh.foo` 的文件。这样，当这两个层被联合挂载之后，foo 文件就会被 `.wh.foo` 文件“遮挡”起来，“消失”了。这个功能，就是“ro+wh”的挂载方式，即只读 `+whiteout` 的含义。

所以，**最上面这个可读写层的作用，就是专门用来存放你修改 rootfs 后产生的增量，无论是增、删、改，都发生在这里**。而当我们使用完了这个被修改过的容器之后，还可以**使用 docker commit 和 push 指令，保存这个被修改过的可读写层**，并上传到 Docker Hub 上，供其他人使用；**而与此同时，原先的只读层里的内容则不会有任何变化**。这，就是增量 rootfs 的好处。

#### 第三部分，Init 层

它是一个以“-init”结尾的层，**夹在只读层和读写层之间。Init 层是 Docker 项目单独生成的一个内部层，专门用来存放 `/etc/hosts`、`/etc/resolv.conf` 等信息**。

需要这样一层的原因是，**这些文件本来属于只读的 Ubuntu 镜像的一部分，但是用户往往需要在启动容器时写入一些指定的值比如 hostname，所以就需要在可读写层对它们进行修改**。

可是，这些修改往往只对当前的容器有效，我们并不希望执行 `docker commit` 时，把这些信息连同可读写层一起提交掉。

所以，Docker 做法是，在修改了这些文件之后，以一个单独的层挂载了出来。而用户执行 docker commit 只会提交可读写层，所以是不包含这些内容的。

最终，这 7 个层都被联合挂载到 `/var/lib/docker/aufs/mnt` 目录下，表现为一个完整的 Ubuntu 操作系统供容器使用。

### 构建镜像

示例：

```dockerfile
# 使用官方提供的 Python 开发镜像作为基础镜像
FROM python:2.7-slim
 
# 将工作目录切换为 /app
WORKDIR /app
 
# 将当前目录下的所有内容复制到 /app 下
ADD . /app
 
# 使用 pip 命令安装这个应用所需要的依赖
RUN pip install --trusted-host pypi.python.org -r requirements.txt
 
# 允许外界访问容器的 80 端口
EXPOSE 80
 
# 设置环境变量
ENV NAME World
 
# 设置容器进程为：python app.py，即：这个 Python 应用的启动命令
CMD ["python", "app.py"]
```

**Dockerfile 的设计思想，是使用一些标准的原语（即大写高亮的词语），描述我们所要构建的 Docker 镜像。并且这些原语，都是按顺序处理的**。

**Dockerfile 中的每个原语执行后，都会生成一个对应的镜像层**。即使原语本身并没有明显地修改文件的操作（比如，ENV 原语），它对应的层也会存在。只不过在外界看来，这个层是空的。

#### ENTRYPOINT

ENTRYPOINT 和 CMD 都是 Docker 容器进程启动所必需的参数，完整执行格式是：“ENTRYPOINT CMD”。

默认情况下，**Docker 会为你提供一个隐含的 ENTRYPOINT，即：`/bin/sh -c`**。所以，在不指定 ENTRYPOINT 时，比如在我们这个例子里，实际上运行在容器里的完整进程是：`/bin/sh -c “python app.py”`，即 **CMD 的内容就是 ENTRYPOINT 的参数**。

Dockerfile 里的原语并不都是指对容器内部的操作。就比如 ADD，它指的是把当前目录（即 Dockerfile 所在的目录）里的文件，复制到指定容器内的目录当中。

#### 构建镜像

```bash
$ docker build -t helloworld .
```

### 运行容器

```bash
$ docker run -p 4000:80 helloworld
```

镜像名 helloworld 后面，什么都不用写，因为在 Dockerfile 中已经指定了 CMD。

否则，就得把进程的启动命令加在后面：

```bash
$ docker run -p 4000:80 helloworld python app.py
```

使用 docker ps 命令查看：

```bash
$ docker ps
CONTAINER ID        IMAGE               COMMAND             CREATED
4ddf4638572d        helloworld       "python app.py"     10 seconds ago
```

### docker commit

`docker commit` 指令，把一个正在运行的容器，直接提交为一个镜像。一般来说，需要这么操作原因是：这个容器运行起来后，又在里面做了一些操作，并且要把操作结果保存到镜像里，比如：

```bash
$ docker exec -it 4ddf4638572d /bin/sh
# 在容器内部新建了一个文件
root@4ddf4638572d:/app# touch test.txt
root@4ddf4638572d:/app# exit
 
# 将这个新建的文件提交到镜像中保存
$ docker commit 4ddf4638572d geektime/helloworld:v2
```

**docker commit，实际上就是在容器运行起来后，把最上层的“可读写层”，加上原先容器镜像的只读层，打包组成了一个新的镜像，没有 Init 层**。当然，下面这些**只读层在宿主机上是共享的，不会占用额外的空间**。

而由于使用了联合文件系统，你**在容器里对镜像 rootfs 所做的任何修改，都会被操作系统先复制到这个可读写层，然后再修改**。这就是所谓的：**Copy-on-Write**。

Init 层的存在，就是为了避免你执行 `docker commit` 时，把 Docker 自己对 `/etc/hosts` 等文件做的修改，也一起提交掉。


## 存储驱动

docker 支持几种不同的存储驱动，这几种方式都实现了镜像层和写时复制（copy on write）：

- AUFS
- Overlay2
- Device Mapper
- Btrfs
- ZFS

Windows 只支持一种：Filter。

每个 Docker 主机只能选择一种存储驱动。

可以修改 /etc/docker/daemon.json 文件来修改存储引擎：

```json
{
  "storage-driver": "overlay2"
}
```

如果修改了存储引擎，那么现有的容器和镜像在 docker 重启之后将不可用，因为 image layer 的存储目录已经改变了。 无法找到原有的 image layer。切换回去就可以正常使用。

`docker system info` 查看当前存储驱动。

### Device Mapper

默认情况下，Device Mapper 采用 loopback mounted sparse file 作为底层实现来为 Docker 提供存储支持。但是默认方式的性能很差，并不支持生产环境。

需要将底层实现修改为 direct-lvm 模式。这种模式下通过使用基于裸块设备（Raw Block Device）的 LVM 精简池（LVM thin pool）来获取更好的性能。

`/etc/docker/daemon.json` 文件中添加：

```json
  "storage-driver": "devicemapper",
  "storage-opts": [
    "dm.directlvm_device=/dev/xdf",
    "dm.thinp_percent=95",
    "dm.thinp_metapercent=1",
    "dm.thinp_autoextend_threshold=80",
    "dm.thinp_autoextend_percent=20",
    "dm.directlvm_device_force=false"
  ]
```

或者在启动 docker 时指定参数：
```sh
 -s devicemapper \
 --storage-opt dm.directlvm_device=${directLvm} \
 --storage-opt dm.directlvm_device_force=$DIRECTLVM_DEVICE_FORCE \
 --storage-opt dm.thinp_percent=95 \
 --storage-opt dm.thinp_metapercent=1 \
 --storage-opt dm.thinp_autoextend_threshold=80 \
 --storage-opt dm.thinp_autoextend_percent=20
```

- `dm.directlvm_device` ：设置了块设备的位置。为了存储的最佳性能以及可用性，块设备应当位于高性能存储设备（如本地SSD）或者外部 RAID 存储阵列之上。
- `dm.thinp_percent=95` ：设置了镜像和容器允许使用的最大存储空间占比，默认是 `95%`。
- `dm.thinp_metapercent` ：设置了元数据存储（MetaData Storage）允许使用的存储空间大小。默认是 `1%`。
- `dm.thinp_autoextend_threshold` ：设置了LVM自动扩展精简池的阈值，默认是 `80%`。
- `dm.thinp_autoextend_percent` ：表示当触发精简池（thinpool）自动扩容机制的时候，扩容的大小应当占现有空间的比例。
- `dm.directlvm_device_force` ：允许用户决定是否将块设备格式化为新的文件系统。


使用 thinpool device：

```sh
 -s devicemapper \
--storage-opt=dm.thinpooldev=${mainThinpool} \
--storage-opt=dm.use_deferred_removal=true \
--storage-opt=dm.use_deferred_deletion=true
```

重启 docker 之后使用 `docker version` 查看块设备是否被加载成功。