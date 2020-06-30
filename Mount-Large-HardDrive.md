# 硬盘分区格式化和挂载

```shell
#查看目前挂载情况
df -h

文件系统                 容量  已用  可用 已用% 挂载点
devtmpfs                 7.7G     0  7.7G    0% /dev
tmpfs                    7.7G     0  7.7G    0% /dev/shm
tmpfs                    7.7G  9.1M  7.7G    1% /run
tmpfs                    7.7G     0  7.7G    0% /sys/fs/cgroup
/dev/mapper/centos-root  215G  2.0G  213G    1% /
/dev/sda1               1014M  184M  831M   19% /boot
tmpfs                    1.6G     0  1.6G    0% /run/user/0
```

```shell
#查看目前存储设备情况
fdisk -l

磁盘 /dev/sda：240.1 GB, 240057409536 字节，468862128 个扇区
Units = 扇区 of 1 * 512 = 512 bytes
扇区大小(逻辑/物理)：512 字节 / 4096 字节
I/O 大小(最小/最佳)：4096 字节 / 4096 字节
磁盘标签类型：dos
磁盘标识符：0x0007076a

   设备 Boot      Start         End      Blocks   Id  System
/dev/sda1   *        2048     2099199     1048576   83  Linux
/dev/sda2         2099200   468860927   233380864   8e  Linux LVM

磁盘 /dev/sdb：1000.2 GB, 1000204886016 字节，1953525168 个扇区
Units = 扇区 of 1 * 512 = 512 bytes
扇区大小(逻辑/物理)：512 字节 / 4096 字节
I/O 大小(最小/最佳)：4096 字节 / 4096 字节
磁盘标签类型：dos
磁盘标识符：0x8d35379b

   设备 Boot      Start         End      Blocks   Id  System
/dev/sdb1            2048   614402047   307200000    7  HPFS/NTFS/exFAT
/dev/sdb2       614402048  1953519615   669558784    7  HPFS/NTFS/exFAT

磁盘 /dev/mapper/centos-root：230.4 GB, 230388924416 字节，449978368 个扇区
Units = 扇区 of 1 * 512 = 512 bytes
扇区大小(逻辑/物理)：512 字节 / 4096 字节
I/O 大小(最小/最佳)：4096 字节 / 4096 字节


磁盘 /dev/mapper/centos-swap：8589 MB, 8589934592 字节，16777216 个扇区
Units = 扇区 of 1 * 512 = 512 bytes
扇区大小(逻辑/物理)：512 字节 / 4096 字节
I/O 大小(最小/最佳)：4096 字节 / 4096 字节
```

对/dev/sd重新分区

```shell
#进入分区程序（2T以下使用）
fdisk /dev/sdb

#删除原有分区
命令(输入 m 获取帮助)：d
分区号 (1,2，默认 2)：2
分区 2 已删除

命令(输入 m 获取帮助)：d
已选择分区 1
分区 1 已删除

命令(输入 m 获取帮助)：w
The partition table has been altered!

#查看一下
fdisk -l

磁盘 /dev/sda：240.1 GB, 240057409536 字节，468862128 个扇区
Units = 扇区 of 1 * 512 = 512 bytes
扇区大小(逻辑/物理)：512 字节 / 4096 字节
I/O 大小(最小/最佳)：4096 字节 / 4096 字节
磁盘标签类型：dos
磁盘标识符：0x0007076a

   设备 Boot      Start         End      Blocks   Id  System
/dev/sda1   *        2048     2099199     1048576   83  Linux
/dev/sda2         2099200   468860927   233380864   8e  Linux LVM

磁盘 /dev/sdb：1000.2 GB, 1000204886016 字节，1953525168 个扇区
Units = 扇区 of 1 * 512 = 512 bytes
扇区大小(逻辑/物理)：512 字节 / 4096 字节
I/O 大小(最小/最佳)：4096 字节 / 4096 字节
磁盘标签类型：dos
磁盘标识符：0x8d35379b

   设备 Boot      Start         End      Blocks   Id  System

磁盘 /dev/mapper/centos-root：230.4 GB, 230388924416 字节，449978368 个扇区
Units = 扇区 of 1 * 512 = 512 bytes
扇区大小(逻辑/物理)：512 字节 / 4096 字节
I/O 大小(最小/最佳)：4096 字节 / 4096 字节


磁盘 /dev/mapper/centos-swap：8589 MB, 8589934592 字节，16777216 个扇区
Units = 扇区 of 1 * 512 = 512 bytes
扇区大小(逻辑/物理)：512 字节 / 4096 字节
I/O 大小(最小/最佳)：4096 字节 / 4096 字节
```

```shell
#创建新的分区
fdisk /dev/sdb

命令(输入 m 获取帮助)：n
Partition type:
   p   primary (0 primary, 0 extended, 4 free)
   e   extended
Select (default p): p
分区号 (1-4，默认 1)：1
起始 扇区 (2048-1953525167，默认为 2048)：
将使用默认值 2048
Last 扇区, +扇区 or +size{K,M,G} (2048-1953525167，默认为 1953525167)：
将使用默认值 1953525167
分区 1 已设置为 Linux 类型，大小设为 931.5 GiB

命令(输入 m 获取帮助)：w
The partition table has been altered!

Calling ioctl() to re-read partition table.
正在同步磁盘。
```

格式化分区

```shell
fdisk -l

磁盘 /dev/sda：240.1 GB, 240057409536 字节，468862128 个扇区
Units = 扇区 of 1 * 512 = 512 bytes
扇区大小(逻辑/物理)：512 字节 / 4096 字节
I/O 大小(最小/最佳)：4096 字节 / 4096 字节
磁盘标签类型：dos
磁盘标识符：0x0007076a

   设备 Boot      Start         End      Blocks   Id  System
/dev/sda1   *        2048     2099199     1048576   83  Linux
/dev/sda2         2099200   468860927   233380864   8e  Linux LVM

磁盘 /dev/sdb：1000.2 GB, 1000204886016 字节，1953525168 个扇区
Units = 扇区 of 1 * 512 = 512 bytes
扇区大小(逻辑/物理)：512 字节 / 4096 字节
I/O 大小(最小/最佳)：4096 字节 / 4096 字节
磁盘标签类型：dos
磁盘标识符：0x8d35379b

   设备 Boot      Start         End      Blocks   Id  System
/dev/sdb1            2048  1953525167   976761560   83  Linux

磁盘 /dev/mapper/centos-root：230.4 GB, 230388924416 字节，449978368 个扇区
Units = 扇区 of 1 * 512 = 512 bytes
扇区大小(逻辑/物理)：512 字节 / 4096 字节
I/O 大小(最小/最佳)：4096 字节 / 4096 字节


磁盘 /dev/mapper/centos-swap：8589 MB, 8589934592 字节，16777216 个扇区
Units = 扇区 of 1 * 512 = 512 bytes
扇区大小(逻辑/物理)：512 字节 / 4096 字节
I/O 大小(最小/最佳)：4096 字节 / 4096 字节

#用XFS格式进行格式化
mkfs.xfs -f /dev/sdb1
```

创建挂载点并挂载分区

```shell
#创建挂载点
mkdir /data

#挂载
mount /dev/sdb1 /data

#存储挂载点
vi /etc/fstab

#添加内容
/dev/sdb1 /data xfs     defaults        0 0

#重启
reboot

#查看结果
df -h

文件系统                 容量  已用  可用 已用% 挂载点
devtmpfs                 7.7G     0  7.7G    0% /dev
tmpfs                    7.7G     0  7.7G    0% /dev/shm
tmpfs                    7.7G  9.1M  7.7G    1% /run
tmpfs                    7.7G     0  7.7G    0% /sys/fs/cgroup
/dev/mapper/centos-root  215G  2.0G  213G    1% /
/dev/sda1               1014M  197M  818M   20% /boot
/dev/sdb1                932G   33M  932G    1% /data
tmpfs                    1.6G     0  1.6G    0% /run/user/0
```
