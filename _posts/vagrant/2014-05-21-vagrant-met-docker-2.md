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

使用**Vagrant**来为项目提供统一的开发与测试环境，已成为了许多开发团队的标准流程。Vagrant能够为开发者在本机上提供与生产环境几乎一致的开发环境,也能为使用不同操作系统平台（Linux，MAC OS，Windows）的团队成员提供一致开发体验。

{% series_list %}

##背景
----
相对于Vagrant在开发中的使用，**Docker**则更关注于生产环境的虚拟化。它将应用及其依赖的其它应用，每一个都独立包装成独立自足的容器，其中包括特定的操作系统及其依赖的所有软件，解决了以前在生产部署中困扰我们的诸多难题。因此，自它发布以来，虽然还没有达到官方认为稳定的1.0版本，但还是有越来越多的人使用它来部署自己的应用。

一般来说，我们在Vagrant中会使用VirtualBox等传统的虚拟机软件来作为提供者，以创建一个与生产环境相同的开发机器。这样，我们在开发阶段就可以遇到并解决很多与生产环境相关的问题。然而，随着Docker的异军突起，这种方式开始变得尴尬，因为我们发现开发环境已经不能匹配生产环境了: 在开发时，程序使用本机的网络，与数据库直接通过本机端口连接，直接访问着主机的文件系统和其它资源并与其它程序共享这些资源；在生产中，程序则在Docker容器中运行，通过桥接网络与外界通信，与数据库通于Docker link方式进行连接，通过映射或数据容器访问主机资源且不与其它程序共享。另一方面，我们应用部署过程也与以前有了很大不同：以前我们通过FTP，HTTP或SSH、Git等方式将代码上传至服务器再进行版本切换，应用重启等工作，在此过程中可能还要在生产服务器上进行诸如库文件更新等额外工作。而现在，我们则是将应用直接打包成一个Docker镜像并推送到中心仓库，然后在服务器上下拉并直接启动最新的镜像。

##解决方案
----
Vagrant的开发者很快意识到了这个问题。

在1.4版本中，Vagrant引入了[Docker Provision](http://docs.vagrantup.com/v2/provisioning/docker.html)。帮助开发者在虚拟机中自动安装Docker软件，并自动启动Docker容器。但此时，Vagrant对Docker的支持还是比较原始的。我们无法通过Vagrant的命令行直接管理Docker容器，也无法绕过虚拟机直接与容器通信。

直到1.6版本发布，Vagrant终于引入[Docker provider](http://docs.vagrantup.com/v2/docker/index.html)。至此，Docker才获得了与VirtrualBox，VMWare等传统虚拟机软件相等的地位。我们也才有可能在开发中使用Docker容器来构建与生产环境完全一致的开发测试环境。

##优点与不足
----
使用Docker虚拟机作为开发环境至少有以下几个**好处**：

1. 节省磁盘空间： 因为Docker镜像具有共享与缓存机制，同时创建10个基于Ubuntu容器并不会比创建1个多花费多少空间。
2. 大幅减少内存与CPU占用: 传统虚拟机的明显缺点就是需要消耗大量内存与CPU，哪怕你只是启动了虚拟机，什么事情都不做，内存与CPU与照占不误。而Docker容器则轻量的多，基本上是应用使用多少内存，就占用多少内存，CPU的额外消耗也很少。
3. 性能提升： 传统虚拟机因为需要虚拟大部分硬件的关系，性能与主机有着较为明显的差距。而Docker则性能则与物理机相当接近。
4. 可以统一开发与部署环境。前提是你准备以Docker方式部署应用。

然而，现实并不完美，Vagrant与Docker的结合并不是天衣无缝，一方面是Docker或Vagrant的问题，另一方面则是因为瓷器国的特色了。问题主要表现在以下几个方面：

1. Docker目前只能运行在Linux 64bit的环境下，在其它平台上，Vagrant需要使用一个Host虚拟机来提供Docker的运行环境。因此，前面所说第2、3两个优点，对于使用Mac或Windows来开发的同学几乎不存在。
2. 以目前最新的1.6.2版本的Vagrant来说，其对于Docker provider的支持还有不少[Bug](https://github.com/mitchellh/vagrant/issues?state=open)，需要我们使用较多的"work around"。
3. 因为伟大的墙存在，Vagrant默认的Docker Host VM基本上在国内处于不可用状态。我们需要自己创建这个虚拟机。
4. 使用Docker容器作为开发环境，与传统的虚拟机相比也有一些不便之处。

##小结
----
在本篇中，笔者简要的介绍了Vagrant对Docker的支持情况。下一篇将以搭建一个Rails开发环境为例，介绍Docker provider的使用与技巧。
 
 

###参考
* [Feature Preview: Docker-Based Development Environments](https://www.vagrantup.com/blog/feature-preview-vagrant-1-6-docker-dev-environments.html)
* [Vagrant官方网站](http://www.vagrantup.com/)
* [Docker官方网站](https://www.docker.io/)
