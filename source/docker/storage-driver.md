# docker 存储驱动

每个 docker 容器都有一个本地存储空间，用于保存 image layer 以及挂载的文件系统。

默认情况下，容器的所有读写操作都发生在其镜像层上或者挂载的文件系统中。

本地存储通常是存储驱动（storage dirver 或 graph driver）管理的。

docker 支持几种不同的存储驱动，这几种方式都实现了镜像层和写时复制（copy on write）：
- AUFS
- Overlay2
- Device Mapper
- Btrfs
- ZFS

Windows 只支持一种：Filter

存储驱动的选择是节点级别的。意味着每个 docker 主机只能选择一种存储驱动。

可以修改 `/etc/docker/daemon.json` 文件来修改存储引擎：

```json
{
  "storage-driver": "overlay2"
}
```

如果修改了存储引擎，那么现有的容器和镜像在 docker 重启之后将不可用，因为 image layer 的存储目录已经改变了。
无法找到原有的 image layer。切换回去就可以正常使用。

`docker system info` 查看当前存储驱动。

## Device Mapper

默认情况下，Device Mapper 采用 loopback mounted sparse file 作为底层实现来为 Docker 提供存储支持。
但是默认方式的性能很差，并不支持生产环境。

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

- `dm.directlvm_device` ：设置了块设备的位置。为了存储的最佳性能以及可用性，块设备应当位于高性能存储设备（如本地SSD）
或者外部 RAID 存储阵列之上。
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

