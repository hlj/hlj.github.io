---
title: 'Gitolite on Docker'
summary: "使用Docker将Gitolite打包为一个开箱即用的服务。"
tags: Docker Git
category: 服务器 开发工具
layout: post
---

在公司内部我们有十多个项目用Git作为源代码版本控制工具。因为是内部项目，所以简单在一台内网Linux服务器上创建一个名为git的用户，所有项目成员都通过此用户，使用ssh协议来读写中心代码库。同时，又用nginx架设了一个HTTP服务器，在部署环境提供Git仓库的只读访问。

但是这样做的弊端也很明显，尤其在以下几点方面让人比较头疼：

* 项目成员有变化时，需要管理员登录到服务器上去手工增加或删除ssh公钥。
* 因为所有成员都通过git用户来访问，一旦为某个成员在服务器上增加了公钥，就意味着同时开放了这台服务器所有其它项目的代码。
* 只能通过HTTP或SSH协议来提供只读/读写两类权限控制，无法对项目内容进行细粒度的权限控制。
* 为一个项目开放HTTP访问需要管理员手工去修改hook。

总之，这种SSH方式虽然简单易行，但在安全性和便利性上却不尽如人意。

Gitolite作为更强大但也更复杂的Git服务器，以前也看到很多人在推荐。但因为需求没那么迫切，一直没有好好研究过。不过最近在做应用的Docker化时，产生了把Git服务器也打包成一个Docker容器的想法。既然要动手，那就干脆直接迁移到Gitolite上吧。

##构建容器
----
此容器的构建代码可以从我的[Github项目](https://github.com/hlj/gitolite-docker)上下载。

项目中包括4个文件，其中唯一需要修改就是`admin.pub`文件。这个文件的内容应该是您自己使用ssh-keygen产生的公钥文件。您可以直接替换这个文件的内容，也可以完全删除这个文件并用自己的文件代替。如果您不想使用`admin.pub`这个名称，也可以改成任意名称，但一定要同步修改`Dockerfile`里的相关内容。

在修改好这个文件后，就可以直接运行构建命令了：

```sh
$ docker build -t gitolite .
```

##使用
----
*注意：这里仅介绍容器本身的使用，Gitolite的使用请自行参考[相关手册](https://github.com/sitaramc/gitolite#readme)*

###准备
在使用这个容器之前，首先要在主机准备一个空目录，用以存储Git仓库的内容。在脚本中默认是使用`/opt/git`。

```sh
$ sudo mkdir -p /opt/git
$ sudo chown $USER:$USER /opt/git
```

记住一定要把这个目录的读写权限赋给运行容器的用户。

您也可以选择别的目录，但需要同步修改`gitolite`这个脚本中的相关部分。

###运行
运行这个容器也很简单,直接用项目中自带的`gitolite`这个脚本就可以了：

```sh
./gitolite start
```
这个脚本是基于我写的[Docker应用管理脚本模板](http://betacz.com/2014/05/29/docker-app-script-template/)制作的，如有需要，也可自行修改。

###测试
现在，Gitolite服务已经顺利跑起来了，可以测试一下:

```sh
git clone ssh://git@localhost:22222/testing
```
如果在这一步发生错误，那可能是您改动了`gitolite`脚本的相关配置，请仔细检查一下。

###额外配置rc文件
这个Gitolite服务器使用的是默认配置。如果您想自定义一此选项，只需要修改`/opt/git/gitolite.rc`这个配置文件即可。 这个文件是在首次启动服务器时，从容器内的`~/.gitolite.rc`文件复制出来的（见`start.sh`）。

在修改这个文件后，需要重启一下容器才能生效:

```sh
$ ./gitolite stop && ./gitolite start
```

###容器被删除了?
如果容器被删除了（使用`docker rm`或`./gitolite remove`)，那么可以用`./gitolite start`重新启动。但启动完成后，必须要重新推送一下`gitolite-admin`这个仓库。如下所示：

```sh
~/gitolite-admin$ git push -f
``` 
在您把Gitolite迁移到其它主机上时，也需要如此操作。
