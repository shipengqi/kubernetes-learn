---
title: 排错概览
---

# 排错概览
## 修改 pod 中的文件
1. kubectl exec
2. kubectl cp
3. docker
```sh
docker run -it --network=container:fc47d41abb44 --pid=container:fc47d41abb44 --ipc=container:fc47d41abb44 itom-docker.shcartifactory.swinfra.net/shared/opensuse-base:15.1 sh

docker ps | grep frontend


cd proc/
cd 1
cd root/
```