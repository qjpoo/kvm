# MacOS下制作CentOS系统USB安装盘

```shell
#将ISO文件转化为DMG文件
hdiutil convert -format UDRW -o CentOS-7-x86_64-Minimal-2003.dmg CentOS-7-x86_64-Minimal-2003.iso

#查看存储设备列表
diskutil list

#取消U盘的挂载
diskutil unmountDisk /dev/disk2

#制作U盘安装盘
sudo dd if=CentOS-7-x86_64-Minimal-2003.dmg of=/dev/disk2
```
