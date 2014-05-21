---
title: '当流浪者(Vagrant)遇见码头工人(Docker): 实战'
summary: "流浪者与码头工人突破重重阻碍，终于结合在了一起，但当他们踏上一个名为“瓷器国”的地方时，却一下子撞上了一堵无形无象的高墙..."
tags: Vagrant Docker DevOps
category: 开发工具
series: 当流浪者(Vagrant)遇见码头工人(Docker)
layout: post
---
{% assign align='right' %}
{% assign src='/docker/docker-top-logo.png' %}
{% include image.html %}
{% assign align='left' %}
{% assign src='/vagrant/logo_vagrant.png' %}
{% include image.html %}

要使用Vagrant与Docker共同创建一个开发环境，并不是一件容易的事情。特别是在国内这种网络环境中，更是平添了一层难度。官方的演示与文档中，也基本是将Docker provider作为测试或Stage环境来使用，对于创建开发环境时会遇到的问题几乎没有涉及。在本文中，笔者将详细讲述使用Docker provider创建一个完整的Rails开发环境的全过程。对于其它框架或语言的开发者，此过程也基本相似。

{% series_list %}

##一、前提
----
在阅读本文之前，您需要有一定的Vagrant和Docker的使用经验。在涉及到这两个软件本身的知识时，文中不会作详细解释。

在您的物理机器上，必须已经安装了下列的软件，并能正常使用：

* Vagrant >= 1.6.2
* VirtualBox >= 4.10.0
* vagrant-vbguest插件 (建议，可选)
* Docker >= 0.9.0 (仅当Docker原生支持时需要, Mac OS X与Windows用户不可安装)

##二、创建 HOST VM
----
*注：理论上Linux用户可以跳过此节，但由于团队中很可能有成员使用其它的操作系统，所以还是看一下吧。*

对于Docker不能原生支持的平台，如Mac OS X或Windows，Vagrant会自动在后台启动一个host VM来运行Docker。这个host VM，说到底就是一个VirtualBox的虚拟机，Dokcer将安装在这个虚拟机上，所有Vagrant的命令，也会自动转发到这个虚拟机的Docker中。对用户而言，这个过程是透明的，Vagrant将这个VM隐藏在了幕后，使所有平台的用户能获得一致操作界面。

Vagrant自带了一个基于boot2docker的host VM。它具有体积小，速度快，无需配置等优点。但不幸的是，有两个致命的缺点使它在我们的开发环境中完全无法使用：

1. 在这个host VM中启动Docker容器时，会自动连接到<index.docker.io>来获取相应的镜像。但由于一堵墙的存在，这是不可能成功的。虽然最终我们可以通过进入这个虚拟机并配置代理来fq，但是这个操作不能自动化，且技术门槛较高，对于一个开箱即用的统一开发环境来说，这是无法接受的。
2. 这个host VM与物理主机使用的文件夹同步方式是rsync。这意味着这个同步是单向，只能是在物理机上修改的内容同步至虚拟机中。对于测试或模拟生产环境来说，这种同步方式完全可行。但对于开发环境，必须要有双向同步的能力。

为了解决这两个问题，我们需要自己创建一个host VM给Docker provider使用。创建host VM的过程其实很简单。就是用Vagrant创建一个正常的基于VirtualBox的虚拟机，然后在里面安装好Docker软件。为了对付国内的网络情况，我们可以在这个虚拟机fq后，下载好所需的常用Docker镜像。然后重新打包成一个Box即可。其过程不再赘述。

为了节省大家的时间和精力，笔者已经创建好一个host VM: [docker-host-01.box](http://yun.baidu.com/share/link?shareid=566951005&uk=289275890)，您可以直接下载使用。

这个VM的近1G大小，具有如下特性：

* 操作系统为 ubuntu 14.04
* 时区为 Asia/Shanghai
* 已安装 Docker 0.11.1
* 已包含下列Docker Image:
  * ubuntu:12.04
  * ubuntu:14.04
  * phusion/baseimage:0.9.10
  * busybox
  * svendowideit/ambassador
  * dockerfile/redis

##三、创建开发环境
----
在准备好上述的host VM之后，我们就可以正式开始创建Rails开发环境了。我们将创建一系列的目录和文件来配置Vagrant，告诉它应该如何启动Docker容器。我们也将创建一个Dockerfile来自动构建我们的Rails开发容器。

该示例项目的完整内容可以从我的[GitHub项目](https://github.com/hlj/vagrant-docker)中获取。

###1. 目录结构
首先我们来看一下基本的目录结构：

```
vagrant-docker/
|-- Vagrantfile            # 主要的Vagrant配置文件，定义了Docker容器
|-- docker_host/           # 包含host VM的配置
|   |-- Vagrantfile        # host VM配置文件
|-- dockerfiles/           # 包含所有Dockerfile的定义
|   |-- rails/             # 包含rails容器配置
|       |-- Dockefile      # rails容器的构建文件
|       |-- ...
|-- demo_app/              # rails项目的主目录
|   |-- ...
|-- ...
```

目录结构比较简单。其中`demo_app`中包含了一个正常的rails项目，与其它普通的rails项目没有区别。`docker_host`则定义了host VM的配置。`dockerfiles`则应该包含所有该项目中用到的Docker容器的构建文件。

###2. docker_host/Vagrantfile
这个文件中定义了host VM。它是基于我们上面所说的docker-host-01.box创建的，文件内容为：

```ruby
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.box = "docker-host-01"
  config.vm.hostname = "dh01"

  # Forward port for rails app
  config.vm.network "forwarded_port", guest: 3000, host: 3000
  # Forward port for container's ssh
  config.vm.network "forwarded_port", guest: 2244, host: 2244

  # Fixed the mapping of the app's folder
  config.vm.synced_folder "../", "/var/lib/docker_root"

end
```
虽然只有短短几行，但里面的后面三行配置却需要好好解释一下。

前面说过，在使用host VM时，Docker容器实际上是运行在这个虚拟机里面的。相当于是盗梦空间里的第二层梦境。在容器中映射至外部的网络端口，

##小结
----
在本篇中，笔者简要的介绍了Vagrant对Docker的支持情况。下一篇将以搭建一个Rails开发环境为例，介绍Docker provider的使用与技巧。



###参考
* [Feature Preview: Docker-Based Development Environments](https://www.vagrantup.com/blog/feature-preview-vagrant-1-6-docker-dev-environments.html)
* [Vagrant官方网站](http://www.vagrantup.com/)
* [Docker官方网站](https://www.docker.io/)
