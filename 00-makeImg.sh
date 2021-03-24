#!/bin/bash
# author: quinn
# Updated Date:2021-03-22
# auto create kvm virtual machine
# corp: www.diangoumall.com
set -e
# 1. 要把iso镜像文件放在/data/vmdisk目录下面
# 2. 设置kvm主机的网段头比如: 192.168
# 3. 第一次要做好xml配置文件template.xml和基础的镜像C7-base.qcow2

# 根据自己的网段设置, 前两位比如: 192.168
NET_PREFIX='10.10' 
# 获取当前kvm主机的网卡名: ens33 IP NETMASK HW GATEWAY
LOCAL_INTERFACE=`ls /etc/sysconfig/network-scripts/ |grep ifcfg-e |head -1  |sed s/ifcfg-//g`
NETWORK=(
    IPADDR=`ifconfig $LOCAL_INTERFACE|grep -Po '[\d.]+(?=  netmask)'`
    HWADDR=`ifconfig $LOCAL_INTERFACE|grep -Po 'inet6 \K[\w:]+'`
    NETMASK=`ifconfig $LOCAL_INTERFACE|grep -Po 'netmask \K[\d.]+'`
    GATEWAY=`route -n|grep "UG"|awk '{print $2}'`
)

# 设置aliyun源
if ! grep -q aliyun /etc/yum.repos.d/CentOS-Base.repo
then
curl -sq -o  /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo && yum clean all && yum makecache fast
fi


# 判断系统是否支持kvm, 是否有kvm相关模块.
lsmod | grep kvm &>/dev/null && lsmod |grep -E '(kvm_intel|kvm_amd)' &>/dev/null
if [ $? -ne 0 ];then
    exit 2 && echo 'KVM mode is not loaded!'
fi

# 判断 cpu 是否支持 kvm 虚拟化.
grep -E "(vmx|svm)" /proc/cpuinfo &>/dev/null
if [ $? -ne 0 ];then
    exit 3 && echo 'You computer is not SUPPORT Virtual Tech OR the VT is NOT OPEN!'
fi


# 安装相关镜像管理工具, 网络管理工具, 虚拟机管理工具
function INSTALL_KVM_PACKAGES(){
    yum -y install qemu-kvm qemu-kvm-tools && ln -sv /usr/libexec/qemu-kvm /usr/bin/qemu-kvm
    yum -y install libvirt libvirt-client virt-install virt-manager virt-viewer
    yum -y install libguest* libvirt* wget  bridge-utils nmap wget lrzsz&& systemctl enable --now libvirtd
}


# 设置网络为桥接模式
function SET_BRIDGE() {
cd  /etc/sysconfig/network-scripts/
# 备份
cp ifcfg-${LOCAL_INTERFACE} ifcfg-${LOCAL_INTERFACE}.bak
cat >"ifcfg-${LOCAL_INTERFACE}"<<EOF
TYPE="Ethernet"
BRIDGE=br0
BOOTPROTO="static"
DEFROUTE="yes"
NAME="${LOCAL_INTERFACE}"
DEVICE="${LOCAL_INTERFACE}"
ONBOOT="yes"
EOF

cat >ifcfg-br0<<EOF
TYPE=Bridge
BOOTPROTO=static
DEVICE=br0
ONBOOT=yes
${NETWORK[0]}
${NETWORK[2]}
${NETWORK[3]}
DNS1=114.114.114.114
DNS2=8.8.8.8
EOF

echo '---------------------------------------------------------'
echo 'Restart Network Service: systemctl restart network ...'
if systemctl restart network
then
  echo 'Restart Network Service: systemctl restart network sucess ...'
else
  echo 'Restart Network Service: systemctl restart network failure ...'
fi
echo '---------------------------------------------------------'
}

# 是否安装kvm
if [ -d "/etc/libvirt/qemu" ]
then
  echo '---------------------------------------------------------'
  echo "KVM Installed ..."
  systemctl start libvirtd
else 
  INSTALL_KVM_PACKAGES
  SET_BRIDGE
fi

VMDISK_DIR="/data/vmdisk"
[ ! -d "${VMDISK_DIR}" ] && mkdir -pv "${VMDISK_DIR}"

# 安装基础的镜像, 先要上传iso到指定的目录中去
function MAKE_BASE_IMG() {
  [ ! -d "${VMDISK_DIR}/base" ] && mkdir -pv ${VMDISK_DIR}/base
  qemu-img create -f qcow2 ${VMDISK_DIR}/base/C7-base.qcow2 8G

  virt-install --virt-type kvm --name C7-base --ram 4096 --vcpus 2 -l ${VMDISK_DIR}/CentOS-7-x86_64-Minimal-2009.iso  --disk path=${VMDISK_DIR}/base/C7-base.qcow2,size=8,bus=virtio,format=qcow2 --bridge=br0 --graphics vnc,listen=0.0.0.0 --noautoconsole --os-type=linux --os-variant=rhel7

# 虚拟机基础的tempalate配置文件
cat >${VMDISK_DIR}/base/template.xml<<EOF
<!--
WARNING: THIS IS AN AUTO-GENERATED FILE. CHANGES TO IT ARE LIKELY TO BE
OVERWRITTEN AND LOST. Changes to this xml configuration should be made using:
  virsh edit tmp
or other application using the libvirt API.
-->

<domain type='kvm'>
  <name>%VM_NAME%</name>
  <uuid>%VM_UUID%</uuid>
  <memory unit='KiB'>4194304</memory>
  <currentMemory unit='KiB'>%VM_MEM_NOW%</currentMemory>
  <vcpu placement='static' current='%VM_VCPU%'>22</vcpu>
  <resource>
    <partition>/machine</partition>
  </resource>
  <os>
    <type arch='x86_64' machine='%VM_MACHINE%'>hvm</type>
    <boot dev='hd'/>
  </os>
  <features>
    <acpi/>
    <apic/>
  </features>
  <cpu mode='custom' match='exact' check='full'>
    <model fallback='forbid'>Broadwell-IBRS</model>
    <feature policy='require' name='ssbd'/>
    <feature policy='disable' name='hle'/>
    <feature policy='disable' name='rtm'/>
    <feature policy='require' name='spec-ctrl'/>
    <feature policy='require' name='hypervisor'/>
    <feature policy='disable' name='erms'/>
    <feature policy='require' name='xsaveopt'/>
  </cpu>
  <clock offset='utc'>
    <timer name='rtc' tickpolicy='catchup'/>
    <timer name='pit' tickpolicy='delay'/>
    <timer name='hpet' present='no'/>
  </clock>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <pm>
    <suspend-to-mem enabled='no'/>
    <suspend-to-disk enabled='no'/>
  </pm>
  <devices>
    <emulator>/usr/libexec/qemu-kvm</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='%VM_DISK_PATH%'/>
      <target dev='vda' bus='virtio'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x0'/>
    </disk>

    <controller type='usb' index='0' model='ich9-ehci1'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x04' function='0x7'/>
    </controller>

    <controller type='usb' index='0' model='ich9-uhci1'>
      <master startport='0'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x04' function='0x0' multifunction='on'/>
    </controller>
    <controller type='usb' index='0' model='ich9-uhci2'>
      <master startport='2'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x04' function='0x1'/>
    </controller>
    <controller type='usb' index='0' model='ich9-uhci3'>
      <master startport='4'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x04' function='0x2'/>
    </controller>
    <controller type='pci' index='0' model='pci-root'/>
    <controller type='ide' index='0'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x01' function='0x1'/>
    </controller>

    <interface type='bridge'>
      <mac address='%VM_NET_MAC%'/>
      <source bridge='br0'/>
      <model type='rtl8139'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x03' function='0x0'/>
    </interface>

    <interface type='bridge'>
      <mac address='%VM_NET_MAC2%'/>
      <source bridge='br0'/>
      <model type='virtio'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x07' function='0x0'/>
    </interface>

    <serial type='pty'>
      <target type='isa-serial' port='0'>
        <model name='isa-serial'/>
      </target>
    </serial>

    <console type='pty'>
      <target type='serial' port='0'/>
    </console>

    <input type='mouse' bus='ps2'/>
    <input type='keyboard' bus='ps2'/>

    <graphics type='vnc' port='-1' autoport='yes' listen='0.0.0.0'>
      <listen type='address' address='0.0.0.0'/>
    </graphics>

    <video>
      <model type='cirrus' vram='16384' heads='1' primary='yes'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x0'/>
    </video>

    <memballoon model='virtio'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x06' function='0x0'/>
    </memballoon>
  </devices>
</domain>
EOF
}

MAKE_BASE_IMG

if [ ! -f "$VMDISK_DIR/base/C7-base.qcow2" -o  ! -f "$VMDISK_DIR/base/template.xml" ]
then
  echo "$VMDISK_DIR/base/C7-base.qcow2 or $VMDISK_DIR/base/template.xml dosnot exist ..."
  exit -1
fi
