# 安装 Gitlab

## 环境

* 操作系统：CentOS 7
* Gitlab版本：13.0.3-ce.0.el7

## 安装

执行官方脚本：https://packages.gitlab.com/gitlab/gitlab-ce/install#bash-rpm

```shell
curl -s https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh | sudo bash
```

Yum源安装成功后执行安装命令：

```shell
yum install gitlab-ce
```

## 修改配置

安装成功后修改配置：

```shell
vi /etc/gitlab/gitlab.rb
```

主要是修改external_url内容：

```conf
external_url 'http://git.bluersw.com'
```

注意：external_url可以是IP:Port，我使用的是域名默认是80端口，但无论使用什么端口，8080都将被使用，所以不要让其他程序使用8080端口，这里也不要设置为8080端口。

```shell
#配置Gitlab系统
gitlab-ctl reconfigure
```

注意：如果在ruby_block[wait for redis service socket] action run 被卡住，请打开另一个SSH执行：

systemctl restart gitlab-runsvdir

完成后执行：

```shell
gitlab-ctl restart
```

注意：完成安装和启动服务后Jenkins和gitlab启动将占用2.91G内存。

## 使用说明

* 访问：http://git.bluersw.com
* 创建root密码
* 使用root账号和root密码登录系统
* 创建分组 New group （例如：Dev）
* 创建项目 New project （例如：gitlab）
* 创建用户 New user并设置新用户密码
* 将新用户分配到Group 再设置为Developer角色
* 将项目配置内的分支保护关闭 Settings - Repository - Protected Branches
* 使用新用户登录设置新密码
* 新用户给自己添加一个SSH Keys
* 克隆项目git clone git@git.bluersw.com:dev/gitlab.git
* 开始工作
