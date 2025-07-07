---
title: Namespace 机制
weight: 1
---

**容器技术的核心功能，为进程创造出一个“边界”**。

对于 Docker 等大多数 Linux 容器来说，**Cgroups 技术是用来制造约束的主要手段**，而 **Namespace 技术则是用来修改进程视图的主要方法**。

先创建一个容器：

```bash
docker run -it busybox /bin/sh
```

- `-it` 参数告诉了 Docker 项目在启动容器后，需要分配一个文本输入/输出环境，也就是 TTY
- `/bin/sh` 就是要在 Docker 容器里运行的程序。

这样，一个运行着 `/bin/sh` 的容器，就跑在了宿主机里面。

容器里执行 `ps`：

```bash
/ # ps
PID  USER   TIME COMMAND
  1 root   0:00 /bin/sh
  10 root   0:00 ps
```

- `/bin/sh`，就是这个容器内部的第 1 号进程（`PID=1`），而这个容器里一共只有两个进程在运行。
-  `/bin/sh` 和 `ps`，已经被 Docker 隔离在了一个跟宿主机完全不同的世界当中。

这就是利用了 **Linux 里面的 Namespace 机制**。像一种障眼法，让容器里 `/bin/sh` 看不到容器以外的其他进程。

## Namespace 原理

Namespace 的使用方式非常简单：它其实**只是 Linux 创建新进程的一个可选参数**。在 Linux 系统中创建线程的系统调用是 `clone()`，比如：

```bash
# 创建一个新的进程，并且返回进程号 pid。
int pid = clone(main_function, stack_size, SIGCHLD, NULL); 
```

当用 `clone()` 系统调用创建一个新进程时，就可以在参数中指定 `CLONE_NEWPID` 参数：

```bash
int pid = clone(main_function, stack_size, CLONE_NEWPID | SIGCHLD, NULL); 
```

`CLONE_NEWPID` 会让创建的新进程“看到”一个全新的进程空间，在这个进程空间里，它的 PID 是 1。在宿主机真实的进程空间里，这个进程的 PID 还是真实的数值，比如 100。

多次执行上面的 `clone()` 调用，这样就会创建多个 PID Namespace，而每个 Namespace 里的应用进程，都会认为自己是当前容器里的第 1 号进程，它们既看不到宿主机里真正的进程空间，也看不到其他 PID Namespace 里的具体情况。

**Linux 操作系统还提供了 Mount、UTS、IPC、Network 和 User 这些 Namespace，用来对各种不同的进程上下文进行“障眼法”操作**。

比如，Mount Namespace，用于让被隔离进程只看到当前 Namespace 里的挂载点信息；Network Namespace，用于让被隔离进程看到当前 Namespace 里的网络设备和配置。

Docker 容器这个听起来玄而又玄的概念，实际上是在创建容器进程时，指定了这个进程所需要启用的一组 Namespace 参数。这样，容器就只能“看”到当前 Namespace 所限定的资源、文件、设备、状态，或者配置。而对于宿主机以及其他不相关的程序，它就完全看不到了。

**容器，其实是一种特殊的进程而已**。

### 不同类型的 Namespace

Linux 一共实现了 6 种不同类型的 Namespace：
```bash
[root@SGDLITVM0905 ~]# ls -l /proc/self/ns
total 0
lrwxrwxrwx. 1 root root 0 Aug 17 09:48 ipc -> ipc:[4026531839]
lrwxrwxrwx. 1 root root 0 Aug 17 09:48 mnt -> mnt:[4026531840]
lrwxrwxrwx. 1 root root 0 Aug 17 09:48 net -> net:[4026531956]
lrwxrwxrwx. 1 root root 0 Aug 17 09:48 pid -> pid:[4026531836]
lrwxrwxrwx. 1 root root 0 Aug 17 09:48 user -> user:[4026531837]
lrwxrwxrwx. 1 root root 0 Aug 17 09:48 uts -> uts:[4026531838]
```

| Namespace 类型| 系统调用参数 | 内核版本 |
| ---- | ---- | ---- |
| Mount Namespace | CLONE_NEWNS | 2.4.19 |
| UTS Namespace | CLONE_NEWUTS | 2.6.19 |
| IPC Namespace | CLONE_NEWIPC | 2.6.19 |
| PID Namespace | CLONE_NEWPID | 2.6.24 |
| Network Namespace | CLONE_NEWNET | 2.6.29 |
| User Namespace | CLONE_NEWUSER | 3.8 |

Namespace 的 API 主要使用如下3 个系统调用。
- `clone` 创建新进程。根据系统调用参数来判断哪些类型的 Namespace 被创建，而且它们 的子进程也会被包含到这些 Namespace 中。
- `unshare` 将进程移出某个 Namespace
- `setns` 将进程加入到 Namespace 中。

- UTS Namespace 主要用来隔离 nodename 和 domainname 两个系统标识。在 UTS Namespace 里面， 每个 Namespace 允许有自己的 hostname 。
- IPC  Namespace 用来隔离 System V IPC 和 POSIX message queues。
- PID Namespace 是用来隔离进程 ID 的。
- Mount Namespace 用来隔离各个进程看到的挂载点视图。在不同 Namespace 的进程中，看到的文件系统层次是不一样的。在 Mount Namespace 中调用 mount 和 umount 仅仅只会影响当前 Namespace 内的文件系统，而对全局的文件系统是没有影响的。**`chroot` 也是将某一个子目录变成根节点**。但是， Mount Namespace 不仅能实现这个功能，而且能以更加灵活和安全的方式实现。**Mount Namespace 是 Linux 第一个实现的 Namespace 类型，因此，它的系统调用参数是 `NEWNS`** （New Namespace 的缩写）。当时人们貌似没有意识到，以后还会有很多类型的 Namespace 加入。
- User Namespace 主要是隔离用户的用户组 ID。
- Network Namespace 是用来隔离网络设备、IP 地址端口等网络栈的 Namespace。

### setns

`setns` 是一个系统调用，可以根据提供的 PID 再次进入到指定的 Namespace 中。它需要先打开 `/proc/[pid]/ns/` 文件夹下对应的文件，然后使当前进程进入到指定的 Namespace 中。

## 虚拟机和 Docker 的区别

虚拟机的工作原理是利用 Hypervisor，通过硬件虚拟化功能，模拟出了运行一个操作系统需要的各种硬件，比如 CPU、内存、I/O 设备等等。然后，它在这些虚拟的硬件上安装了一个新的操作系统，即 Guest OS。

这样，用户的应用进程就可以运行在这个虚拟的机器中，它能看到的自然也只有 Guest OS 的文件和目录，以及这个机器里的虚拟设备。这就是为什么虚拟机也能起到将不同的应用进程相互隔离的作用。

**和虚拟机不同的是，Docker 不会创建任何实体的“容器”**，Docker 帮助用户启动的，还是原来的应用进程，只不过在创建这些进程时，Docker 为它们加上了各种各样的 Namespace 参数。这些进程就会觉得自己是各自 PID Namespace 里的第 1 号进程，只能看到各自 Mount Namespace 里挂载的目录和文件，只能访问到各自 Network Namespace 里的网络设备，就仿佛运行在一个个“容器”里面，与世隔绝。