# 安装Java1.8

## 下载安装包

[Oracle Java下载地址](https://www.oracle.com/technetwork/java/javase/downloads/index.html)

```shell
#上传到服务器
scp jdk-8u211-linux-x64.tar  root@192.168.0.5:/opt/

#解压文件
sudo tar -xvf jdk-8u211-linux-x64.tar （如果是GZ压缩文件用：tar -xzvf jdk-8u211-linux-x64.tar.gz）

#如果发现权限不对请改变所有者权限
chown -R root:root jdk1.8.0_211/

#为了便于升级版本维护创建软链接
ln -s /opt/jdk1.8.0_211/ /usr/local/java

#配置环境变量
vi /etc/profile
```

```conf
JAVA_HOME=/usr/local/java
JRE_HOME=/usr/local/java/jre
PATH=$PATH:$JAVA_HOME/bin:$JRE_HOME/bin
CLASSPATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar:$JRE_HOME/lib
export JAVA_HOME JRE_HOME PATH CLASSPATH
```

```shell
#重新加载
source /etc/profile

#检查结果
java -version
```

## Mac系统

Java安装后目录是：

/Library/Java/JavaVirtualMachines/jdk1.8.0_211.jdk/Contents/Home
