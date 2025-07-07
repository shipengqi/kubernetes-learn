---
title: docker exec 原理
weight: 4
---

docker exec 是怎么做到进入容器里的？

Linux Namespace 创建的隔离空间虽然看不见摸不着，但一个进程的 Namespace 信息在宿主机上是确确实实存在的，并且是以一个文件的方式存在。

通过如下指令，你可以看到当前正在运行的 Docker 容器的进程号（PID）是 25686：

```bash
$ docker inspect --format '{{ .State.Pid }}'  4ddf4638572d
25686
```

这时，你可以通过查看宿主机的 proc 文件，看到这个 25686 进程的所有 Namespace 对应的文件：

```bash
$ ls -l  /proc/25686/ns
total 0
lrwxrwxrwx 1 root root 0 Aug 13 14:05 cgroup -> cgroup:[4026531835]
lrwxrwxrwx 1 root root 0 Aug 13 14:05 ipc -> ipc:[4026532278]
lrwxrwxrwx 1 root root 0 Aug 13 14:05 mnt -> mnt:[4026532276]
lrwxrwxrwx 1 root root 0 Aug 13 14:05 net -> net:[4026532281]
lrwxrwxrwx 1 root root 0 Aug 13 14:05 pid -> pid:[4026532279]
lrwxrwxrwx 1 root root 0 Aug 13 14:05 pid_for_children -> pid:[4026532279]
lrwxrwxrwx 1 root root 0 Aug 13 14:05 user -> user:[4026531837]
lrwxrwxrwx 1 root root 0 Aug 13 14:05 uts -> uts:[4026532277]
```

可以看到，一个进程的每种 Linux Namespace，都在它对应的 `/proc/[进程号]/ns` 下有一个对应的虚拟文件，并且链接到一个真实的 Namespace 文件上。

有了这样一个 Linux Namespace 的文件，就可以对 Namespace 做一些很有意义事情了，比如：加入到一个已经存在的 Namespace 当中。

**这也就意味着：一个进程，可以选择加入到某个进程已有的 Namespace 当中，从而达到“进入”这个进程所在容器的目的，这正是 docker exec 的实现原理**。

而这个操作所依赖的，乃是一个名叫 `setns()` 的 Linux 系统调用。


```bash
#define _GNU_SOURCE
#include <fcntl.h>
#include <sched.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
 
#define errExit(msg) do { perror(msg); exit(EXIT_FAILURE);} while (0)
 
int main(int argc, char *argv[]) {
    int fd;
    
    fd = open(argv[1], O_RDONLY);
    if (setns(fd, 0) == -1) {
        errExit("setns");
    }
    execvp(argv[2], &argv[2]); 
    errExit("execvp");
}
```

它一共接收两个参数，**第一个参数是 `argv[1]`，即当前进程要加入的 Namespace 文件的路径**，比如 `/proc/25686/ns/net`；而**第二个参数，则是你要在这个 Namespace 里运行的进程**，比如 `/bin/bash`。

通过 `open()` 系统调用打开了指定的 Namespace 文件，并把这个文件的描述符 fd 交给 `setns()` 使用。在 `setns()` 执行后，当前进程就加入了这个文件对应的 Linux Namespace 当中了。


你可以编译执行一下这个程序，加入到容器进程（`PID=25686`）的 Network Namespace 中：

```bash
$ gcc -o set_ns set_ns.c 
$ ./set_ns /proc/25686/ns/net /bin/bash 
$ ifconfig
eth0      Link encap:Ethernet  HWaddr 02:42:ac:11:00:02  
          inet addr:172.17.0.2  Bcast:0.0.0.0  Mask:255.255.0.0
          inet6 addr: fe80::42:acff:fe11:2/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:12 errors:0 dropped:0 overruns:0 frame:0
          TX packets:10 errors:0 dropped:0 overruns:0 carrier:0
	   collisions:0 txqueuelen:0 
          RX bytes:976 (976.0 B)  TX bytes:796 (796.0 B)
 
lo        Link encap:Local Loopback  
          inet addr:127.0.0.1  Mask:255.0.0.0
          inet6 addr: ::1/128 Scope:Host
          UP LOOPBACK RUNNING  MTU:65536  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
	  collisions:0 txqueuelen:1000 
          RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B)
```

执行 `ifconfig` 命令查看网络设备时，我会发现能看到的网卡“变少”了：只有两个。在 `setns()` 之后我看到的这两个网卡，正是我在前面启动的 Docker 容器里的网卡。

**一旦一个进程加入到了另一个 Namespace 当中，在宿主机的 Namespace 文件上，也会有所体现**。这个进程和 Docker 容器进程指向的 Network Namespace 文件完全一样。

Docker 还专门提供了一个参数，可以让你启动一个容器并“加入”到另一个容器的 Network Namespace 里，这个参数就是 `-net`，比如:

```bash
$ docker run -it --net container:4ddf4638572d busybox ifconfig
```

### setns

**`setns()` 不能一次性设置多个 namespace，但可通过多次调用实现**。

```bash
# 1. 打开目标容器的 namespace 文件
int mntns_fd = open("/proc/12345/ns/mnt", O_RDONLY);
int pidns_fd = open("/proc/12345/ns/pid", O_RDONLY);

# 2. 加入非 PID namespace
setns(netns_fd, CLONE_NEWNET);
setns(mntns_fd, CLONE_NEWNS);

# 3. 创建子进程
# 加入 PID namespace 会立即改变进程的 PID 视图，可能导致父进程无法正确管理子进程。因此需要在 fork() 后的子进程中单独加入。
pid_t child_pid = fork();
if (child_pid == 0) {
    # 子进程中加入 PID namespace
    setns(pidns_fd, CLONE_NEWPID);
    
    # 执行用户命令
    execve("/bin/bash", NULL, NULL);
}
```