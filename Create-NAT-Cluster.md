# 创建NAT网络虚拟机环境

## 准备工作

* 准备一台安装CentOS-7操作系统的电脑。(PS:安装系统时硬盘分区不要自动否则/home会分一半的硬盘空间)
* 准备一份CentOS-7的iso安装文件。
* [安装VNC Viewer](https://www.realvnc.com/en/)

## 虚拟机配置及规划

![Alt text](http://static.bluersw.com/images/Kvm/Create-NAT-Cluster-1.png)  

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

## 配置防火墙

```shell
#打开防火墙
systemctl start  firewalld

#打开端口
firewall-cmd --add-port=22/tcp --permanent
firewall-cmd --add-port=80/tcp --permanent
firewall-cmd --add-port=443/tcp --permanent

#设置开机启动
systemctl enable firewalld

#重新加载
firewall-cmd --reload

#查看开放端口
firewall-cmd --zone=public --list-ports
```

## 创建虚拟机文件目录

因为虚拟机文件会很大，所以建议单独准备一块硬盘来存储，以下示例的虚拟机文件都存储在/data中，可参考[硬盘分区格式化和挂载](Mount-Large-HardDrive.md)。

## 安装KVM

```shell
yum install -y libvirt qemu-kvm virt-install

#重启
reboot
```

## 安装第一台虚拟机

```shell
#打开VNC远程端口
firewall-cmd --add-port=50001/tcp --permanent
firewall-cmd --reload

#安装
virt-install --name centos7-mysql --memory 2048 --vcpus 2 --disk device=cdrom,path=/data/iso/CentOS-7-x86_64-Minimal-2003.iso --disk path=/data/kvm/centos7-mysql.qcow,size=200,bus=virtio --network bridge=virbr0,model=virtio --noautoconsole --accelerate --os-variant  centos7.0 --hvm --graphics vnc,listen=0.0.0.0,port=50001 --cpu host-passthrough --video cirrus --check path_in_use=off --boot cdrom

# 关闭VNC远程端口
firewall-cmd --remove-port=50001/tcp --permanent
firewall-cmd --reload
```

主要参数说明：

* --name：虚拟机名称
* --memory：内存大小（M）
* --vcpus：CPU核心数量
* --disk device：存储设备
* --network bridge=virbr0：NAT网络，网段是192.168.122.0/24
* --graphics：远程可视化设置
* --boot：引导设备

启动VNC连接远程桌面 192.168.0.5:50001
![Alt text](http://static.bluersw.com/images/Kvm/Create-NAT-Cluster-2.png)

安装完成之后用virsh list命令浏览虚拟机列表，并关闭虚拟机

```shell
#显示正在运行中的虚拟机
virsh list

#暴力关闭虚拟机（shutdown是优雅的关闭需要acpid支持）
virsh destroy centos7-mysql

#显示所有虚拟机列表
virsh list --all

#关闭端口
firewall-cmd --remove-port=50001/tcp --permanent
firewall-cmd --reload
firewall-cmd --zone=public --list-ports
```

## 编辑虚拟机信息

```shell
virsh edit centos7-mysql
```

```xml
<boot dev='cdrom'/> <!--改为--><boot dev='hd'/>
<!--删除以下配置-->
<graphics type='vnc' port='50001' autoport='no' listen='0.0.0.0'>
      <listen type='address' address='0.0.0.0'/>
</graphics>
<!--找到MAC地址-->
<mac address='52:54:00:98:4e:c5'/>
```

## 修改KVM的DHCP设置

```shell
virsh net-edit default
```

修改配置将起始IP从2改为100，增加根据MAC地址分配IP和主机名称的规则。

```xml
<network>
  <name>default</name>
  <uuid>378b7f4b-bbdb-452d-a380-0ae353e2d0b8</uuid>
  <forward mode='nat'/>
  <bridge name='virbr0' stp='on' delay='0'/>
  <mac address='52:54:00:29:9f:49'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.100' end='192.168.122.254'/>
      <host mac='52:54:00:98:4e:c5' name='centos7-mysql' ip='192.168.122.2'/>
    </dhcp>
  </ip>
</network>
```

重新加载并启动虚拟机

```shell
#这个方法有个问题就是——执行下面命令之后，所有在运行中的虚拟机都需要关机再开机才能重新连接网络
virsh net-destroy default

virsh net-start default

virsh start centos7-mysql
```

## 登录虚拟机更新系统和安装常用软件

```shell
#免密登录
ssh-keygen -t rsa
ssh-copy-id root@192.168.122.2
ssh root@192.168.122.2

#安装EPEL源
yum install epel-release -y

#升级系统
yum update -y

```

如果有私有的YUM仓库请参照[搭建Nexus Repository包管理系统](Nexus-Repository.md)进行客户端设置。

```shell

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
virsh shutdown centos7-mysql

#查看大小(200G ls -l)
qemu-img info centos7-mysql.qcow

#制作操作系统基础盘
qemu-img convert -O qcow2 centos7-mysql.qcow centos7-system.qcow

#查看大小(1.8G)
qemu-img info centos7-system.qcow

#删除原有文件
rm centos7-mysql.qcow

#从基础盘复制一份
cp centos7-system.qcow centos7-mysql.qcow

#复制其他虚拟机硬盘
cp centos7-system.qcow centos7-k8s-master.qcow
cp centos7-system.qcow centos7-k8s-node1.qcow
cp centos7-system.qcow centos7-k8s-node2.qcow
```

## 创建K8S-Master虚拟机

``` shell
#创建虚拟机
virt-install --name centos7-k8s-master --memory 1024 --vcpus 2  --disk path=/data/kvm/centos7-k8s-master.qcow,bus=virtio --network bridge=virbr0,model=virtio --noautoconsole --accelerate --os-variant  centos7.0 --hvm  --cpu host-passthrough --video cirrus --check path_in_use=off --boot hd

#优雅的关闭虚拟机
virsh shutdown centos7-k8s-master

#寻找MAC地址 52:54:00:7e:00:be
virsh edit centos7-k8s-master

#修改DHCP
virsh net-edit default

virsh net-destroy default
virsh net-start default

#启动虚拟机
virsh start centos7-k8s-master

#登录虚拟机
ssh root@192.168.122.3
```

## 按照上述步骤创建其他虚拟机

```shell
virt-install --name centos7-k8s-node1 --memory 1536 --vcpus 2  --disk path=/data/kvm/centos7-k8s-node1.qcow,bus=virtio --network bridge=virbr0,model=virtio --noautoconsole --accelerate --os-variant  centos7.0 --hvm  --cpu host-passthrough --video cirrus --check path_in_use=off --boot hd

virt-install --name centos7-k8s-node2 --memory 1536 --vcpus 2  --disk path=/data/kvm/centos7-k8s-node2.qcow,bus=virtio --network bridge=virbr0,model=virtio --noautoconsole --accelerate --os-variant  centos7.0 --hvm  --cpu host-passthrough --video cirrus --check path_in_use=off --boot hd

.....

52:54:00:28:22:66
52:54:00:dc:3a:93

<host mac='52:54:00:28:22:66' name='centos7-k8s-node1' ip='192.168.122.4'/>
<host mac='52:54:00:dc:3a:93' name='centos7-k8s-node2' ip='192.168.122.5'/>

virsh start centos7-mysql
virsh start centos7-k8s-node1
virsh start centos7-k8s-node2
```

## 创建虚拟机快照备份

```shell
#关闭所有虚拟机（创建快照前必须关闭虚拟机否则文件会损害）
virsh shutdown centos7-mysql
virsh shutdown centos7-k8s-master
virsh shutdown centos7-k8s-node1
virsh shutdown centos7-k8s-node2

#创建快照备份
cd /data/kvm/
qemu-img snapshot -c back20200517 centos7-mysql.qcow
qemu-img snapshot -c back20200517 centos7-k8s-master.qcow
qemu-img snapshot -c back20200517 centos7-k8s-node1.qcow
qemu-img snapshot -c back20200517 centos7-k8s-node2.qcow

#查看快照信息
qemu-img info centos7-mysql.qcow

#备份虚拟机设置
virsh dumpxml centos7-k8s-master > /backup/domains/centos7-k8s-master.xml
virsh dumpxml centos7-k8s-node1 > /backup/domains/centos7-k8s-node1.xml
virsh dumpxml centos7-k8s-node2 > /backup/domains/centos7-k8s-node2.xml
virsh dumpxml centos7-mysql > /backup/domains/centos7-mysql.xml

#备份虚拟机硬盘
cd /backup
cp /data/kvm/*.* .

#启动虚拟机
virsh start centos7-mysql
virsh start centos7-k8s-master
virsh start centos7-k8s-node1
virsh start centos7-k8s-node2
```
