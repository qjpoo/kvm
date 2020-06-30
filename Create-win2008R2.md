# 创建Windows 2008 R2虚拟机

## 准备工作

下载Windows2008R2镜像：cn_windows_server_2008_r2_standard_enterprise_datacenter_web_x64_dvd_x15-50360.iso

下载KVM的virtio-win驱动：virtio-win.iso

## 创建虚拟机

```shell
#查询os-variant参数信息
osinfo-query os

#打开远程端口
firewall-cmd --add-port=50001/tcp --permanent
firewall-cmd --reload

#创建虚拟机命令
virt-install --name win-2008r2 --memory 4096 --vcpus 4 --disk device=cdrom,path=/data/iso/cn_windows_server_2008_r2_standard_enterprise_datacenter_web_x64_dvd_x15-50360.iso --disk device=cdrom,path=/data/iso/virtio-win.iso --disk path=/data/kvm/win-2008r2.qcow,size=200,bus=virtio --network bridge=virbr0,model=virtio --noautoconsole --accelerate --os-type=windows --os-variant=win2k8r2 --hvm --graphics vnc,listen=0.0.0.0,port=50001 --cpu host-passthrough --video cirrus --check path_in_use=off --boot cdrom  --force --autostart
```

打开VNC远程连接后显示安装界面，选择企业版完全安装：
![Alt text](http://static.bluersw.com/images/Kvm/Create-Win2008R2-01.png)  

需要安装SCSI控制器驱动才能识别KVM的硬盘，驱动在virtio-win.iso的\viostor\2k8R2\amd64\目录下：
![Alt text](http://static.bluersw.com/images/Kvm/Create-Win2008R2-02.png)  
![Alt text](http://static.bluersw.com/images/Kvm/Create-Win2008R2-03.png)

驱动安装后可正常显示硬盘：
![Alt text](http://static.bluersw.com/images/Kvm/Create-Win2008R2-04.png)  

下一步进行安装：
![Alt text](http://static.bluersw.com/images/Kvm/Create-Win2008R2-05.png)  

安装完成后进入系统，在设备管理器里安装网卡和其他设备的驱动，驱动都在virtio-win.iso中，选择virtio-win-0.1.1盘后全盘搜索即可。
![Alt text](http://static.bluersw.com/images/Kvm/Create-Win2008R2-06.png)  
![Alt text](http://static.bluersw.com/images/Kvm/Create-Win2008R2-07.png)  

PS 如果是安装Windows 2012 R2:

* 远程协助需要添加功能才能使用
* 远程桌面开启后防火墙里需要设置对公网打开远程桌面的端口
