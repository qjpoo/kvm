# 创建Bridge网络虚拟机环境

## 准备工作

* 准备一台安装CentOS-7操作系统的电脑。(PS:安装系统时硬盘分区不要自动否则/home会分一半的硬盘空间)
* 准备一份CentOS-7的iso安装文件。
* [安装VNC Viewer](https://www.realvnc.com/en/)

## 更新系统并校对时间

```shell
#安装EPEL源
yum install epel-release -y

#升级系统
yum update -y

```

如果有私有的YUM仓库请参照[搭建Nexus Repository包管理系统](Nexus-Repository.md)进行客户端设置。

```shell
#安装常用软件
yum -y install htop wget yum-utils telnet net-tools acpid device-mapper-persistent-data lvm2

#校时
yum install ntpdate

vi /etc/sysconfig/clock
#添加或修改时区
ZONE=“Asia/Shanghai”

ntpdate us.pool.ntp.org

#//同步系统时间和硬件时间
hwclock  -w

date
```

## 关闭防火墙和selinux

```shell
#关闭防火墙
systemctl stop firewalld.service
systemctl disable firewalld.service

#关闭selinux
vi /etc/sysconfig/selinux

SELINUX=disabled
```

## 创建虚拟机文件目录

因为虚拟机文件会很大，所以建议单独准备一块硬盘来存储，以下示例的虚拟机文件都存储在/data中，可参考[硬盘分区格式化和挂载](Mount-Large-HardDrive.md)。

## 安装KVM

```shell
yum install -y libvirt qemu-kvm virt-install

#启动libvirt并设置开机自启动
systemctl start libvirtd
systemctl enable libvirtd

#重启
reboot
```

## 桥接

我的网卡标示是ifcfg-enp2s0

```shell
#创建网桥
vi /etc/sysconfig/network-scripts/ifcfg-br0
```

```conf
TYPE=Bridge
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=static
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME="Bridge br0"
UUID=927a7fb4-c711-4993-8888-1f5bb7d551f4
DEVICE=br0
ONBOOT=yes
IPADDR0=192.168.0.10
NETMASK=255.255.255.0
PREFIXO0=24
GATEWAY0=192.168.0.1
DNS1=192.168.0.1
#设置STP协议防止二层网络的广播风暴
STP=yes
```

```shell
vi /etc/sysconfig/network-scripts/ifcfg-enp2s0
```

```conf
TYPE=Ethernet
BRIDGE=br0
NAME=enp2s0
UUID=927a7fb4-c711-4993-8309-1f5bb7d551f4
DEVICE=enp2s0
ONBOOT=yes
```

```shell
#重启网络服务
systemctl restart network.service

#查看网桥信息
brctl show

#virbr0是KVM的NAT网络192.168.122.0网段，br0是我们刚刚创建的192.168.0.0网段
bridge name	bridge id		STP enabled	interfaces
br0		8000.107b44818ece	yes		enp2s0
virbr0		8000.5254006ba1ef	yes		virbr0-nic
```

## 安装第一台虚拟机

```shell
#创建虚拟机
virt-install --name centos7-k8s-master --memory 2048 --vcpus 4 --disk device=cdrom,path=/data/iso/CentOS-7-x86_64-Minimal-2003.iso --disk path=/data/kvm/centos7-k8s-master.qcow,size=200,bus=virtio --network bridge=br0,model=virtio --noautoconsole --accelerate --os-variant  centos7.0 --hvm --graphics vnc,listen=0.0.0.0,port=50000 --cpu host-passthrough --video cirrus --check path_in_use=off --boot cdrom  --autostart
```

主要参数说明：

* --name：虚拟机名称
* --memory：内存大小（M）
* --vcpus：CPU核心数量
* --disk device：存储设备
* --network bridge=br0：br0是刚刚创建的网桥
* --graphics：远程可视化设置
* --boot：引导设备
* --autostart：开机自动启动

启动VNC连接远程桌面 192.168.0.10:50000 (宿主机IP是192.168.0.10)
![Alt text](http://static.bluersw.com/images/Kvm/Create-Bridge-Cluster-01.png)

安装系统时不要忘了手动分区否则home目录会分走一半的磁盘容量
![Alt text](http://static.bluersw.com/images/Kvm/Create-Bridge-Cluster-02.png)

激活网卡后，因为默认是DHCP所以自动获得192.168.0.0网段的IP
![Alt text](http://static.bluersw.com/images/Kvm/Create-Bridge-Cluster-03.png)

```shell
#安装完成之后先关机
virsh destroy centos7-k8s-master

#修改虚拟机配置
virsh edit centos7-k8s-master
```

```xml
<boot dev='cdrom'/> <!--改为--><boot dev='hd'/>
```

```shell
virsh start centos7-k8s-master
```

用VNC重新连接虚拟机之后进行登录修改网络配置

```shell
cd  /etc/sysconfig/network-scripts/

vi ifcfg-eth0
```

```conf
TYPE="Ethernet"
PROXY_METHOD="none"
BROWSER_ONLY="no"
BOOTPROTO="static"
DEFROUTE="yes"
IPV4_FAILURE_FATAL="no"
IPV6INIT="yes"
IPV6_AUTOCONF="yes"
IPV6_DEFROUTE="yes"
IPV6_FAILURE_FATAL="no"
IPV6_ADDR_GEN_MODE="stable-privacy"
NAME="eth0"
UUID="f9930914-2f6f-4bbe-bb36-5bf9dacb9de5"
DEVICE="eth0"
ONBOOT="yes"
IPADDR0=192.168.0.50
PREFIXO0=24
GATEWAY0=192.168.0.1
DNS1=192.168.0.1
```

```shell
#重启网络服务
service network restart

#查看结果
ip a
```

用SSH登录虚拟机，如果有私有的YUM仓库请参照[搭建Nexus Repository包管理系统](Nexus-Repository.md)进行客户端设置。

```shell
#免密登录
ssh-copy-id root@192.168.0.50
ssh root@192.168.0.50

#安装EPEL源
yum install epel-release -y

#升级系统
yum update -y

#安装常用软件
yum -y install htop wget yum-utils telnet net-tools acpid

#校时
yum install ntpdate

vi /etc/sysconfig/clock
#添加或修改时区
ZONE=“Asia/Shanghai”

ntpdate us.pool.ntp.org
```

## 收缩虚拟机文件后复制出其他虚拟机硬盘

```shell
#优雅的关闭虚拟机（virsh --list查看）
virsh shutdown centos7-k8s-master

#查看大小(200G ls -l)
qemu-img info centos7-k8s-master.qcow

#制作操作系统基础盘
qemu-img convert -O qcow2 centos7-k8s-master.qcow centos7-system.qcow

#查看大小(1.8G)
qemu-img info centos7-system.qcow

#删除原有文件
rm centos7-k8s-master.qcow

#从基础盘复制一份
cp centos7-system.qcow centos7-k8s-master.qcow

#复制其他虚拟机硬盘
cp centos7-system.qcow centos7-k8s-node1.qcow
cp centos7-system.qcow centos7-k8s-node2.qcow
```

## 创建其他虚拟机

```shell
virt-install --name centos7-k8s-node1 --memory 4096 --vcpus 4  --disk path=/data/kvm/centos7-k8s-node1.qcow,bus=virtio --network bridge=br0,model=virtio --noautoconsole --accelerate --os-variant  centos7.0 --hvm  --cpu host-passthrough --video cirrus --check path_in_use=off --graphics vnc,listen=0.0.0.0,port=50001 --boot hd --autostart

#修改IP为192.168.0.51
vi /etc/sysconfig/network-scripts/ifcfg-eth0

virt-install --name centos7-k8s-node2 --memory 4096 --vcpus 4  --disk path=/data/kvm/centos7-k8s-node2.qcow,bus=virtio --network bridge=br0,model=virtio --noautoconsole --accelerate --os-variant  centos7.0 --hvm  --cpu host-passthrough --video cirrus --check path_in_use=off --graphics vnc,listen=0.0.0.0,port=50002 --boot hd --autostart

#修改IP为192.168.0.52
vi /etc/sysconfig/network-scripts/ifcfg-eth0
```

## 创建虚拟机快照备份

```shell
#关闭所有虚拟机（创建快照前必须关闭虚拟机否则文件会损害）
virsh shutdown centos7-k8s-master
virsh shutdown centos7-k8s-node1
virsh shutdown centos7-k8s-node2

#创建快照备份
cd /data/kvm/
qemu-img snapshot -c back20200606 centos7-k8s-master.qcow
qemu-img snapshot -c back20200606 centos7-k8s-node1.qcow
qemu-img snapshot -c back20200606 centos7-k8s-node2.qcow

#查看快照信息
qemu-img info centos7-k8s-master.qcow

#备份虚拟机设置
virsh dumpxml centos7-k8s-master > /data/backup/centos7-k8s-master.xml
virsh dumpxml centos7-k8s-node1 > /data/backup/centos7-k8s-node1.xml
virsh dumpxml centos7-k8s-node2 > /data/backup/centos7-k8s-node2.xml

#备份虚拟机硬盘
cd /data/backup
cp /data/kvm/*.* .

#启动虚拟机
virsh start centos7-k8s-master
virsh start centos7-k8s-node1
virsh start centos7-k8s-node2

#查看网桥的连接情况vnet0-2是虚拟机的虚拟网卡
brctl show

bridge name	bridge id		STP enabled	interfaces
br0		8000.107b44818ece	yes		enp2s0
							vnet0
							vnet1
							vnet2
virbr0		8000.5254006ba1ef	yes		virbr0-nic

```
