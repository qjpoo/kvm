#!/bin/bash
# author: quinn
# Updated Date:2021-03-22
# auto create kvm virtual machine
# corp: www.diangoumall.com
set -e
# 1. 要把iso镜像文件放在/data/vmdisk目录下面
# 2. 设置kvm主机的网段头比如: 192.168
# 3. 第一次要做好xml配置文件和基础的镜像C7-base.qcow2

# 自动添加虚拟机
NET_PREFIX='10.10' # 192.168
# IP地址第三位
NET_POOL=`ip addr |grep -A 3 '\<br0:' |awk -F'.'  '/inet\>/{print $3}'`
# 磁盘目录
VMDISK_DIR="/data/vmdisk"
# 脚本使用语法格式
if [ $# -ne 3 ] ;then
  echo -e "Usage : $0 VM_CPU VM_MEM(Gb) [ c6|c7 ]\nExample : $0 1 1 centos7 " && exit 5
fi 

# 获取到虚拟机的IP地址, 通过Nmap扫描
function get_vm_ip() {
  mkdir -pv ${VMDISK_DIR}/base/ip_pool/
  UNUSED_IP_LIST=${VMDISK_DIR}/base/ip_pool/unused_ip.list
  USED_IP_LIST=${VMDISK_DIR}/base/ip_pool/used_ip.list
  :> $UNUSED_IP_LIST
  :> $USED_IP_LIST

  for i in {17..250} ;do echo ${NET_PREFIX}.${NET_POOL}.${i} >>$UNUSED_IP_LIST ;done
  nmap -n -sP -PI -PT ${NET_PREFIX}.${NET_POOL}.0/24 |awk '/^Nmap/{print $5}' |grep $NET_PREFIX > $USED_IP_LIST
  for m in `cat ${USED_IP_LIST}`;do sed -i "/$m/d"  $UNUSED_IP_LIST ;done
}

get_vm_ip

VM_NET_IP=$(head -$((`echo $RANDOM`%`cat ${VMDISK_DIR}/base/ip_pool/unused_ip.list |wc -l`)) ${VMDISK_DIR}/base/ip_pool/unused_ip.list |tail -1)

# 虚拟机 CPU,MEM,OS_Version, MAC, GATEWAY 等配置.
VM_VCPU=$1
VM_MEM_NOW=$(($2*1024*1024))
VM_VERSION=`echo $3 |tr a-z A-Z`
VM_NAME=$VM_VERSION-$VM_NET_IP
VM_UUID=`uuidgen`
VM_MACHINE=`qemu-kvm -machine ? |grep default |awk '{print $1}'`
VM_DISK_PATH=$VMDISK_DIR/$VM_NET_IP/${VM_NAME}.qcow2
VM_NET_MAC=52:54:00:b0:0b:`echo $VM_NET_IP |awk -F'.' '{print $4}' |xargs printf %x`
VM_NET_MAC2=52:54:00:b1:0b:`echo $VM_NET_IP |awk -F'.' '{print $4}' |xargs printf %x`
VM_NET_GATEWAY=`route -n|grep "UG"|awk '{print $2}'`

function CONFIG_TPL() {
  #mkdir ${VMDISK_DIR}/$VM_NET_IP && cp ${VMDISK_DIR}/base/${VM_VERSION}-base.qcow2 ${VMDISK_DIR}/$VM_NET_IP/${VM_NAME}.qcow2 && cp ${VMDISK_DIR}/base/template.xml ${VMDISK_DIR}/$VM_NET_IP/${VM_NAME}.xml && chown -R qemu:qemu ${VMDISK_DIR}/$VM_NET_IP/

   mkdir ${VMDISK_DIR}/$VM_NET_IP && \
   # 这里可以不用cp, 用cp很慢
   qemu-img create -f qcow2 -b ${VMDISK_DIR}/base/${VM_VERSION}-base.qcow2  ${VMDISK_DIR}/$VM_NET_IP/${VM_NAME}.qcow2
   #cp ${VMDISK_DIR}/base/${VM_VERSION}-base.qcow2 ${VMDISK_DIR}/$VM_NET_IP/${VM_NAME}.qcow2 && \
   cp ${VMDISK_DIR}/base/template.xml ${VMDISK_DIR}/$VM_NET_IP/${VM_NAME}.xml && \
   chown -R qemu:qemu ${VMDISK_DIR}/$VM_NET_IP/
  # 完整clone
  #virt-clone -o ${VMDISK_DIR}/base/${VM_VERSION}-base.qcow2 -n $VM_NAME -f ${VMDISK_DIR}/$VM_NET_IP/${VM_NAME}.qcow2
  # 链接clone
  #qemu-img create -f qcow2 -b ${VMDISK_DIR}/base/${VM_VERSION}-base.qcow2  ${VMDISK_DIR}/$VM_NET_IP/${VM_NAME}.qcow2

  sed -i "s/%VM_NAME%/$VM_NAME/g"  ${VMDISK_DIR}/$VM_NET_IP/${VM_NAME}.xml
  sed -i "s/%VM_UUID%/$VM_UUID/g"  ${VMDISK_DIR}/$VM_NET_IP/${VM_NAME}.xml
  sed -i "s/%VM_MEM_NOW%/$VM_MEM_NOW/g"  ${VMDISK_DIR}/$VM_NET_IP/${VM_NAME}.xml
  sed -i "s/%VM_VCPU%/$VM_VCPU/g"  ${VMDISK_DIR}/$VM_NET_IP/${VM_NAME}.xml
  sed -i "s/%VM_MACHINE%/$VM_MACHINE/g"  ${VMDISK_DIR}/$VM_NET_IP/${VM_NAME}.xml
  sed -i "s@%VM_DISK_PATH%@$VM_DISK_PATH@g"  ${VMDISK_DIR}/$VM_NET_IP/${VM_NAME}.xml
  sed -i "s@%VM_NET_MAC%@$VM_NET_MAC@g"  ${VMDISK_DIR}/$VM_NET_IP/${VM_NAME}.xml
  sed -i "s@%VM_NET_MAC2%@$VM_NET_MAC2@g"  ${VMDISK_DIR}/$VM_NET_IP/${VM_NAME}.xml
}

# 修改镜像中的网络配置.
function CHANGE_IP() { 
VM_NET_CONFIG=`virt-ls -a ${VMDISK_DIR}/$VM_NET_IP/${VM_NAME}.qcow2 /etc/sysconfig/network-scripts/ |awk -F'-' '/ifcfg-e/{print $2}'`
cat >${VMDISK_DIR}/$VM_NET_IP/ifcfg-$VM_NET_CONFIG<<EOF
TYPE=Ethernet
BOOTPROTO=static
DEVICE=$VM_NET_CONFIG
ONBOOT=yes  
IPADDR=$VM_NET_IP
NETMASK=255.255.255.0
GATEWAY=$VM_NET_GATEWAY
DNS1=114.114.114.114
EOF

virt-copy-in -a $VM_DISK_PATH ${VMDISK_DIR}/$VM_NET_IP/ifcfg-$VM_NET_CONFIG  /etc/sysconfig/network-scripts/
}


# 创建虚拟机, 并展示创建结果.
function START_VM() {
  virsh define $VMDISK_DIR/$VM_NET_IP/${VM_NAME}.xml && virsh start $VM_NAME && echo -e "\nVM IPADDRESS:   $VM_NET_IP" && virsh dominfo $VM_NAME && echo -e "\n $VM_NAME vnc port: $(virsh vncdisplay $VM_NAME)" &&virsh autostart $VM_NAME
}




CONFIG_TPL
CHANGE_IP
START_VM
