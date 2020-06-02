docker 有两个组件：client 和 daemon。

client 和 daemon 之间的通信是通过本地 IPC/UNIX Socket 完成的（`/var/run/docker.sock`）