---
title: Debug
---

# Debug

## 修改容器中的文件
1. `kubectl cp` 或者 `docker cp`
`kubectl cp` 或者 `docker cp` 使用本地文件替换容器中的文件。如：
```sh
# 使用本地的 /root/mng-temp/app.js 替换到容器 db35085252a6 中的 /public/en/app.js
docker cp /root/mng-temp/app.js db35085252a6:/public/en/app.js
```

2. `kubectl exec` 或者 `docker exec` 使进入容器并修改文件。
3. 共享容器
如果容器内没有 vim，可有使用下面的方式：
```sh
docker run -it \
--network=container:fc47d41abb44 \
--pid=container:fc47d41abb44 \
--ipc=container:fc47d41abb44 \
itom-docker.shcartifactory.swinfra.net/shared/opensuse-base:15.1 sh

cd proc/
cd 1
cd root/
```
启动一个新的容器，并与你要修改的容器在一个网络，共享 ipc，pid。root 目录下就是你要修改的容器的 root 目录。