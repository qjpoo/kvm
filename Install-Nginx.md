# 安装 Nginx

[官方资料](http://nginx.org/en/linux_packages.html)

```shell
yum install yum-utils

vi /etc/yum.repos.d/nginx.repo
```

```conf
[nginx-stable]
name=nginx stable repo
baseurl=http://nginx.org/packages/centos/$releasever/$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true

[nginx-mainline]
name=nginx mainline repo
baseurl=http://nginx.org/packages/mainline/centos/$releasever/$basearch/
gpgcheck=1
enabled=0
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true

```

```shell
yum-config-manager --enable nginx-mainline

yum install nginx

vi /etc/nginx/conf.d/head.conf
```

```conf
proxy_redirect off;
proxy_set_header        Host $host;
proxy_set_header        HTTP_X_FORWARDED_FOR $remote_addr;
proxy_redirect default;
```

```shell
systemctl start nginx.service
#systemctl stop nginx.service
#systemctl reload nginx.service
#systemctl status nginx.service

#开机启动
systemctl enable nginx.service
```
