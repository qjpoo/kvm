# 搭建Nexus Repository包管理系统

## 下载安装程序

[下载Nexus Repository最新版本](https://www.sonatype.com/download-oss-sonatype)

[配置说明](https://help.sonatype.com/repomanager3)

将下载后的文件传输到服务器上

```shell
#修改配置文件
vi  /etc/security/limits.conf

#添加
* soft nofile 65536

#修改服务配置
vi /etc/systemd/system.conf

#修改
DefaultLimitNOFILE=65536

#重启
reboot

#查看结果
ulimit -n

#将当前目标下的文件上传到目标服务器的指定路径
scp nexus-3.23.0-03-unix.tar root@192.168.0.5:/opt/

#解压
tar -xvf nexus-3.23.0-03-unix.tar

#做一个软链接方便访问和更新
ln -s /opt/nexus-3.23.0-03/ /nexus

#修改运行用户
vi /nexus/bin/nexus.rc

#修改运行用户，除非自己个人使用否则不要用root用户
run_as_user="root"

ln -s /nexus/bin/nexus /etc/init.d/nexus

#init.d设置
cd /etc/init.d
chkconfig --add nexus
chkconfig --levels 345 nexus on
service nexus start

#创建Nexus服务
vi /etc/systemd/system/nexus.service
```

```conf
[Unit]
Description=nexus service
After=network.target
  
[Service]
Type=forking
LimitNOFILE=65536
ExecStart=/nexus/bin/nexus start
ExecStop=/nexus/bin/nexus stop
User=root
Restart=on-abort
TimeoutSec=600
  
[Install]
WantedBy=multi-user.target
```

如果没有安装JAVA，请看：
[安装Java1.8](Install-Java-18.md)

```shell
#重新加载服务
systemctl daemon-reload

#开机启动
systemctl enable nexus.service

#运行服务
systemctl start nexus.service

#查看日志
tail -f /opt/sonatype-work/nexus3/log/nexus.log
```

访问http://192.168.0.5:8081 进入管理界面。

## 创建YUM仓库

[创建YUM代理仓库官方说明](https://help.sonatype.com/repomanager3/formats/yum-repositories)

Nexus服务器域名和端口：repo.bluersw.com：8081

Proxy仓库：

- 仓库名称：aliyun-yum-proxy（属于repo-bluersw分组）
- 仓库类型：proxy
- 远程仓库地址：http://mirrors.aliyun.com/centos/

Group仓库：

- 仓库名称：repo-bluersw（含多个proxy仓库）
- 仓库类型：group
- 对外地址：http://repo.bluersw.com:8081/repository/repo-bluersw/

客户端配置：

```shell
#备份
cd /etc/yum.repos.d/
mkdir bak
cp *.repo bak/

vi /etc/yum.repos.d/CentOS-Base.repo
```

修改CentOS-Base文件内容：

```conf
[base]
name=CentOS-$releasever - Base
#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=os&infra=$infra
#baseurl=http://mirror.centos.org/centos/$releasever/os/$basearch/
baseurl=http://repo.bluersw.com:8081/repository/repo-bluersw/$releasever/os/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#released updates
[updates]
name=CentOS-$releasever - Updates
#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=updates&infra=$infra
#baseurl=http://mirror.centos.org/centos/$releasever/updates/$basearch/
baseurl=http://repo.bluersw.com:8081/repository/repo-bluersw/$releasever/updates/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#additional packages that may be useful
[extras]
name=CentOS-$releasever - Extras
#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=extras&infra=$infra
#baseurl=http://mirror.centos.org/centos/$releasever/extras/$basearch/
baseurl=http://repo.bluersw.com:8081/repository/repo-bluersw/$releasever/extras/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#additional packages that extend functionality of existing packages
[centosplus]
name=CentOS-$releasever - Plus
#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=centosplus&infra=$infra
#baseurl=http://mirror.centos.org/centos/$releasever/centosplus/$basearch/
baseurl=http://repo.bluersw.com:8081/repository/repo-bluersw/$releasever/centosplus/$basearch/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
```

```shell
yum clean all
yum makecache

#更新系统第一次会比较慢
yum update -y
```

下载的RPM包都存储在Nexus服务器上，以后其他服务器照此配置就不用从外网下载了。

## 创建Docker仓库

[创建Docker仓库官方说明](https://help.sonatype.com/repomanager3/formats/docker-registry)

Proxy仓库：

- 仓库名称：hub-docker-proxy
- 仓库类型：proxy
- 远程仓库地址：https://registry-1.docker.io
- Repository Connectors：不创建（由Group仓库负责）
- Allow anonymous docker pull ( Docker Bearer Token Realm required )：true（勾选）
- Enable Docker V1 API：勾选
- Docker Index：Use Docker Hub

Hosted仓库：

- 仓库名称：my-docker-host
- 仓库类型：hosted
- Repository Connectors：HTTP 8082端口（负责Push Image）
- Allow anonymous docker pull ( Docker Bearer Token Realm required )：true（勾选）
- Enable Docker V1 API：勾选
- 对外地址：http://repo.bluersw.com:8082

Group仓库：

- 仓库名称：docker-bluersw（含hub-docker-proxy和my-docker-host）
- 仓库类型：group
- Repository Connectors：HTTP 8083端口（负责Pull Image）
- - Allow anonymous docker pull ( Docker Bearer Token Realm required )：true（勾选）
- 对外地址：http://repo.bluersw.com:8083

group类型的Docker仓库只能pull不能push。

在Security中打开Realms界面，激活Docker Bearer Token Realm 选项。

客户端配置：

```shell
vi /etc/docker/daemon.json
```

修改Docker的daemon配置文件，添加上述两个Docker私服地址。

```json
{
"insecure-registries": ["http://repo.bluersw.com:8082","http://repo.bluersw.com:8083"]
}
```

```shell
#重启服务
systemctl restart docker

#登录
docker login http://repo.bluersw.com:8082
docker login http://repo.bluersw.com:8083

#使用代理服务器下载镜像，镜像会存在代理服务器上供其他人下载
docker pull repo.bluersw.com:8083/hello-world

[root@ops docker]# docker images
REPOSITORY                           TAG                 IMAGE ID            CREATED             SIZE
repo.bluersw.com:8083/hello-world   latest              bf756fb1ae65        4 months ago        13.3kB

#改名
docker tag repo.bluersw.com:8083/hello-world repo.bluersw.com:8082/hello-world

#上传到Docker私有仓库
docker push repo.bluersw.com:8082/hello-world
```
