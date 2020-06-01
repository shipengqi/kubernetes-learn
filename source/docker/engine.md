# Docker 引擎

Docker引擎主要构成：
- Docker客户端（Docker Client）
- Docker守护进程（Docker daemon）
- containerd
- runc

它们共同负责容器的创建和运行。

docker 首次发布时，核心组件只有 LXC 和 docker daemon。
daemon 包含了 client 和 API，容器 runtime，image 构建。
LXC 提供了命名空间（Namespace）和控制组（CGroup）等容器虚拟化技术。

LXC 是基于 Linux 的，所以 docker 要实现跨平台就必须摆脱 LXC。

docker 公司开发了 Libcontainer 替代 LXC。

docker daemon 由于包含了太多功能，变的难以维护，运行越来越慢。docker 公司拆分了
docker daemon，将其模块化。

## runc
runc 只负责容器的创建。

## containerd
包含所有的容器执行逻辑。负责容器的生命周期管理：start，stop，pause，rm

也包含镜像管理

containerd 位于 daemon 和 runc 之间


创建容器的过程：
1. docker client 将 `docker run` 命令转为 API 发送到 daemon
2. daemon 通过 gRPC 与 containerd 通信
3. containerd 将 docker image 转为 OCI bundle，调用 runc 创建容器
4. runc 调用操作系统内核创建容器

容器管理与 docker daemon 解耦以后，daemon 的升级不会再影响运行中的容器

## shim
containerd 每次调用 runc 创建容器时，都会 fock 一个新的 runc 实例。一旦容器创建完毕，fork 的 runc 进程就会
退出。

runc 退出以后，相关联的 containerd-shim 进程就会成为容器的父进程。shim 的职责：
- 保持所有的 stdin 和 stdout 流时开启的，从而在 daemon 重启的时候，容器不会因为管道关闭而中止
- 将容器退出状态返回给 daemon


## Linux 中的实现
组件所对应的二进制文件：
daemon - dockerd ，daemon 的主要功能包括镜像管理、镜像构建、REST API、身份验证、安全、核心网络以及编排。
containerd - containerd
containerd-shim - shim
runc - runc


 


