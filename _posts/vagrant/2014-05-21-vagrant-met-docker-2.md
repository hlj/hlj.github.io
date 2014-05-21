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

Vagrant自带了一个基于boot2docker的host VM。它具有体积小，速度快，无需配置等优点。但不幸的是，有两个致命的缺点使它在开发环境中完全无法使用：

1. 在这个host VM中启动Docker容器时，会自动连接到[index.docker.io](https://index.docker.io)来获取相应的镜像。但由于一堵墙的存在，这是不可能成功的。虽然最终可以通过进入这个虚拟机并配置代理来fq，但是这个操作不能自动化，且技术门槛较高，对于一个开箱即用的统一开发环境来说，这是无法接受的。
2. 这个host VM与物理主机使用的文件夹同步方式是rsync。这意味着这个同步是单向，只能是在物理机上修改的内容同步至虚拟机中。对于测试或模拟生产环境来说，这种同步方式完全可行。但对于开发环境，必须要有双向同步的能力。

为了解决这两个问题，需要自行创建一个host VM给Docker provider使用。创建host VM的过程其实很简单。就是用Vagrant创建一个正常的基于VirtualBox的虚拟机，然后在里面安装好Docker软件。为了对付国内的网络情况，可以在这个虚拟机里fq后，下载好所需的常用Docker镜像。然后重新打包成一个Box即可。其过程不再赘述。

为了节省大家的时间和精力，笔者已经创建好一个host VM: [docker-host-01.box](http://yun.baidu.com/share/link?shareid=566951005&uk=289275890)，可以直接下载使用。

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
在准备好上述的host VM之后，就可以正式开始创建Rails开发环境了。首先要创建一系列的目录和文件来配置Vagrant，告诉它应该如何启动Docker容器。

该示例项目的完整内容可以从我的[GitHub项目](https://github.com/hlj/vagrant-docker)中获取。

###1. 目录结构
首先看一下基本的目录结构：

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
这个文件中定义了host VM。它是基于上面所说的docker-host-01.box创建的，文件内容为：

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
最后三行配置的作用需要解释一下。

前面说过，在使用host VM时，Docker容器实际上是运行在这个虚拟机里面的。相当于是盗梦空间里的第二层梦境。在容器运行时使用`-p` 选项映射至主机的网络端口，实际上只是暴露给了host VM，所以需要在host VM上再进行一次转发，这样物理机上的程序才能直接访问到Docker容器的端口。

在这里，`3000`端口是Rails开发时的默认web端口。`2244`则是容器内的`22`端口的映射。

最后一行配置的意义则是为了应对目前Vagrant 1.6.2在处理文件夹同步上的问题。在使用host VM的情况下，项目的当前目录首先会被Vagrant自动映射为host VM上的一个临时目录。然后再通过Docker容器的Volumes参数将这个目录映射到容器内的`/vagrant`目录。但是这种实现带来了一个问题: 如果停止这个host VM再重新启动（halt or reload），那么这个临时目录的名称会改变。但由于容器并不会自动重新创建，因此容器内的`/vagrant`就对应到了一个不存在的目录。只有当reload或destroy后重建Docker容器时，才会重新映射到正确的位置。为了解决这个问题，这里使用了一个变通方法 ，就是将项目的根目录指定同步到一个固定的位置（/var/lib/docker_root），这样映射关系就不会受到host VM重起的影响了。

最后要说明的是，如果物理主机上能够直接运行Docker，那么Vagrant默认并不会使用host VM，因此这里配置不会影响原生Docker容器的运行。

###3. /dockerfiles/rails/Dockerfile
这个文件是Rails容器自动化构建脚本。Vagrant的Dcoker provider支持直接从镜像启动容器和从Dockerfile构建容器两种方式。一般对于需要定制化的容器，肯定是需要使用Dockerfile的。

这个文件的内容比较长，下面将从头至尾分段介绍。

####3.1 声明基础镜像

```sh
FROM phusion/baseimage:0.9.10
# Set correct environment variables.
ENV HOME /root
# Regenerate SSH host keys
RUN /etc/my_init.d/00_regen_ssh_host_keys.sh
```
第一行`FROM phusion/baseimage:0.9.10`声明了此容器是基于 phusion/baseimage 这个镜像的 0.9.10 版本创建的。之所以要使用这个镜像，而不是常用的 ubuntu，主要是为了使用它内建的ssh服务及init脚本支持能力。如果要自行来配置这样一个镜像，需要花费大量的时间与精力的。

紧接着的两行脚本是 phusion/baseimage 推荐使用的，直接引用即可。详细信息可参考[官方网站](https://github.com/phusion/baseimage-docker)。

####3.2 本地配置

```sh
# Change the timezone
RUN cp -f /usr/share/zoneinfo/PRC /etc/localtime
# Set the software sources to the fastest server.
ADD sources.list /etc/apt/sources.list
RUN apt-get update
```
作为国内用户，当然要把时区和软件源都设置为国内了。这里需要在`dockerfiles/rails`下创建一个`sources.list`文件，里面的内容就是您喜爱的任意软件源配置。

####3.3 安装常用软件与ruby 2.1

```sh
# Install basic tools and libraries
RUN apt-get install -q -y ca-certificates git vim
RUN apt-get install -q -y libsqlite3-dev

# Install ruby dependencies
RUN apt-get update && apt-get install -y \
      build-essential \
      zlib1g-dev \
      libssl-dev \
      libreadline6-dev \
      libyaml-dev

# Install ruby from source and cleanup afterward (from murielsalvan/ruby)
ADD http://ruby.taobao.org/mirrors/ruby/ruby-2.1.2.tar.gz /tmp/
RUN cd /tmp && \
      tar -xzf ruby-2.1.2.tar.gz && \
      cd ruby-2.1.2 && \
      ./configure && \
      make && \
      make install && \
      cd .. && \
      rm -rf ruby-2.1.2 && \
      rm -f ruby-2.1.2.tar.gz

# Set the gem sources to ruby.taobao.org
RUN gem sources --remove https://rubygems.org/
RUN gem sources -a https://ruby.taobao.org/

# Install bundler
RUN gem install bundler --no-ri --no-rdoc
```
这一段虽然很长，但功能很简单。就是安装一些常用的开发工具、Ruby 2.1.2及bundler。当然，这里也做了一些本地化处理，将gem source改为taobao的镜像源。

####3.4 配置ssh key

```sh
# Add ssh authorized key
ADD docker_vm.pub /tmp/my_key
RUN cat /tmp/my_key >> /root/.ssh/authorized_keys && rm -f /tmp/my_key
```
phusion/baseimage已经内置了ssh服务。但并有配置ssh keys。为了能用ssh登录进容器，需要用ssh-keygen创建一对自己的公私密钥。并且将公钥配置进容器中。

####3.5 处理环境变量

```sh
# dump environment variables for container's link, required in development.
ADD dump_link_env.sh /etc/my_init.d/dump_link_env.sh
RUN chmod a+x /etc/my_init.d/*
# Allow sshd load these environment variables
RUN echo 'PermitUserEnvironment yes' >> /etc/ssh/sshd_config
```
这一段是比较关键的部分。在Docker容器使用link功能连接时，会在发起连接的容器内设置一系列的环境变量，以便让程序通过这些环境变更与另一个容器交互。在生产环境中，一般一个容器对应一个应用，而这个应用就是这个容器的唯一进程，所以不需要做特别处理。但是在开发环境中，我们会通过ssh登录到容器中，而ssh会话中并不包括这些环境变量。因此，需要在容器启动时将这些环境变更保存下来，并让ssh去读取这个文件。

这里所用的脚本`dump_link_env.sh`内容如下：

```sh
#! /bin/sh
env | grep _ >> /etc/environment
env | grep _ > /root/.ssh/environment
```

####3.6 清理并设置启动命令

```sh
# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]
```
最后两行比较简单，就不用多做解释了。

###4. /Vagrantfile
现在host VM与Dockerfile都准备好了。只剩下最终Docker provider的配置了。

在项目根目录下的`Vagrantfile`里，定义了两个Docker容器。一个是Rails开发环境，另一个则是为了演示link功能而创建的redis容器。

文件内容如下:

```ruby
# Force the provider so we don't have to type in --provider=docker all the time
ENV['VAGRANT_DEFAULT_PROVIDER'] = 'docker'

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.define "db" do |db1|
   db1.vm.provider "docker" do |d|
     d.vagrant_vagrantfile = "docker_host/Vagrantfile"
     d.image = "dockerfile/redis"
     d.name = "demo_db"
   end
  end

  config.vm.define "rails" do |rails|
    rails.vm.provider "docker" do |d|
      d.vagrant_vagrantfile = "docker_host/Vagrantfile"
      d.build_dir = "dockerfiles/rails"
      d.ports = ["3000:3000", "2244:22"]
      d.create_args = ["-h=rails_vm"]
      d.link "demo_db:redis"
      d.has_ssh = true
      # Mapping to the host, only need in Host VM.
      d.volumes = ["/var/lib/docker_root:/vagrant"]
    end

    # Use own key file
    rails.ssh.private_key_path = "dockerfiles/docker_vm.key"
    rails.ssh.username = "root"
    rails.ssh.port = "22"
  end
end
```

在这个文件里，需要特别说明的主要是"rails"容器的配置。

* `d.vagrant_vagrantfile = "docker_host/Vagrantfile"` 表示容器如果需要使用host VM,应该使用这个配置文件来启动。

* `d.build_dir = "dockerfiles/rails"`， 指示dockerfile文件所在位置。 
* `d.ports = ["3000:3000", "2244:22"]`，容器对外开放的端口映射。这里的端口号要与host VM的配置一致。
* `d.link "demo_db:redis"`， 表示将demo_db这个容器以redis这个名称连接到本容器内。
* `d.volumes = ["/var/lib/docker_root:/vagrant"]， 将host VM中自定义的同步目录映射到/vagrant。实际在不使用host VM时，是不需要这个配置的。但为了避免不同平台使用不同的配置文件，还是统一加上了。
* `rails.ssh.private_key_path = "dockerfiles/docker_vm.key"`，这里配置了当使用'vagrant ssh rails'登录时引用的key文件。这个文件必须要和Dockerfile里面的文件是对应的。
* `rails.ssh.port = "22"`，指定`vagrant ssh`时使用的端口。这个配置原本是不需要的，属于[当前版本的Bug](https://github.com/mitchellh/vagrant/issues/3799)。在最新的源码中已经修正了。

##四、使用
----
现在整个开发环境已经就绪了。让我们开动吧。

###1. 启动
将终端窗口的当前目录切换为项目的根目录，并执行下列命令：

```sh
$ vagrant up
```
Vagrant开始启动Docker容器了，在我的Linux上，输出如下所示:

```sh
==> rails: Building the container from a Dockerfile...
==> db: Creating the container...
    db:   Name: demo_db
    db:  Image: dockerfile/redis
    db: Volume: /home/beta/vagrant/vagrant-docker:/vagrant
    db:   Port: 2222:22
    db:  
    db: Container created: 336b9c3186273eb1
==> db: Starting container...
==> db: Provisioners will not be run since container doesn't support SSH.
    rails: Image: 3ef1f2cb3b9b
==> rails: Fixed port collision for 22 => 2222. Now on port 2200.
==> rails: Creating the container...
    rails:   Name: vagrant-docker_rails_1400658212
    rails:  Image: 3ef1f2cb3b9b
    rails: Volume: /var/lib/docker_root:/vagrant
    rails: Volume: /home/beta/vagrant/vagrant-docker:/vagrant
    rails:   Port: 2200:22
    rails:   Port: 3000:3000
    rails:   Port: 2244:22
    rails:   Link: demo_db:redis
    rails:  
    rails: Container created: a1968cc7caf036c7
==> rails: Starting container...
==> rails: Waiting for machine to boot. This may take a few minutes...
    rails: SSH address: 172.17.0.3:22
    rails: SSH username: root
    rails: SSH auth method: private key
    rails: Warning: Connection refused. Retrying...
==> rails: Machine booted and ready!
```
首次启动时，因为了构建Dockerfile,会需要较长的时间，请耐心等待。

注意这里有一个奇怪的问题。明明redis容器没有开放22端口，也没有配置为使用ssh。但Vagrant还是为它转发了22端口。其实这也是一个[程序Bug](https://github.com/mitchellh/vagrant/issues/3857)，现在已经被修正了。

另外需要注意的是，如果您使用的是Mac OS X或Windows,那么首次启动时会先创建host VM,需要花费更多时间。输出内容也会更多。

###2. 创建Rails项目
因为我们在Rails容器构建过程中并没有安装rails gem. 所以，在首次启动完成后，这是最先要做的：

```sh
$ vagrant ssh rails
root@rails_vm:~# gem install rails --no-ri
root@rails_vm:~# cd /vagrant/
root@rails_vm:/vagrant# rails new demo_app
```
在创建demo_app后，要把gem安装到vendor/bundle中。这么做的原因是因为Docker provider与其它provider不同，当使用'Vagrant reload rails'来重载rails容器时，Vagarnt会按照Dockerfile重新构建一个新的容器。而我们并不希望每次重新构建容器时都需要重新安装所有gem. 因此，需要执行下面的命令:

```sh
root@rails_vm:/vagrant/demo_app# bundle install --path=vendor/bundle/ --binstubs=.bin
```
同时记得把vendor/bundle和.bin加入.gitignore。

###3. 测试应用
现在可以运行demo_app了:

```sh
root@rails_vm:/vagrant/demo_app# .bin/rails s
=> Booting WEBrick
=> Rails 4.1.1 application starting in development on http://0.0.0.0:3000
=> Run `rails server -h` for more startup options
=> Notice: server is listening on all interfaces (0.0.0.0). Consider using 127.0.0.1 (--binding option)
=> Ctrl-C to shutdown server
[2014-05-21 16:03:12] INFO  WEBrick 1.3.1
[2014-05-21 16:03:12] INFO  ruby 2.1.2 (2014-05-08) [x86_64-linux]
[2014-05-21 16:03:12] INFO  WEBrick::HTTPServer#start: pid=54 port=3000
```
打开您主机上的浏览器，转到<http://localhost:3000>, 熟悉的画面又出现在眼前...

###4. 测试link
Rails已经顺利跑起来了，现在该看看link的redis容器是不是能正常使用了。

首先检查一下环境变量:

```sh
root@rails_vm:~# env | grep REDIS
REDIS_PORT_6379_TCP_PROTO=tcp
REDIS_NAME=/vagrant-docker_rails_1400658212/redis
REDIS_PORT_6379_TCP_ADDR=172.17.0.2
REDIS_PORT_22_TCP_ADDR=172.17.0.2
REDIS_PORT_6379_TCP_PORT=6379
REDIS_PORT_6379_TCP=tcp://172.17.0.2:6379
REDIS_PORT=tcp://172.17.0.2:22
REDIS_PORT_22_TCP_PORT=22
REDIS_PORT_22_TCP=tcp://172.17.0.2:22
REDIS_PORT_22_TCP_PROTO=tcp
```
可以看到变量已经设置好了。下一步是安装redis client：

```sh
root@rails_vm:~# gem install redis --no-ri --no-rdoc
Fetching: redis-3.0.7.gem (100%)
Successfully installed redis-3.0.7
1 gem installed
```
开始测试:

```ruby
root@rails_vm:~# irb
irb(main):001:0> require 'redis'
=> true
irb(main):002:0> redis = Redis.new host: ENV["REDIS_PORT_6379_TCP_ADDR"]
=> #<Redis client v3.0.7 for redis://172.17.0.2:6379/0>
irb(main):003:0> redis.set "name", "Beta CZ"
=> "OK"
irb(main):004:0> redis.get "name"
=> "Beta CZ"
```
一切正常。

###5. 配置 Rubymine Remote Ruby SDK
前面所有操作都是远程登录到容器中做的。但Vagrant的意义不应该是在本机写代码，在虚拟机中运行和测试吗？
的确如此，下面就将介绍如何使用Rubymine来实现这一点。

Rubymine可以说是目前最好的用于开发Ruby应用的IDE。在很早的时候就提供了对远程调试的支持。现在更是直接支持自动Vagrant虚拟机。但是因为Docker容器的特殊性，在使用host VM时，Rubymine并不能自动探测出正确的配置，需要自行设置。

Remote Ruby SDK的配置并不复杂。在 project setting中只需要配置两个地方。下面就以Rubymine 6.3为例，给出配置内容。

首先需要配置一个`deployment`环境，按下图配置即可：
{% assign src='/vagrant/rubymine-cfg1.png' %}
{% include image.html %}

然后按下图配置主机和虚拟机的目录映射：
{% assign src='/vagrant/rubymine-cfg2.png' %}
{% include image.html %}

最后在`Ruby SDK and Gems`中按下图配置一个Remote SDK(使用 "Fill from deployment server settting"):
{% assign src='/vagrant/rubymine-cfg3.png' %}
{% include image.html %}

Everyting is OK!

##小结
----
在本篇中，我们用Vagrant和Docker provider,创建了一个完整的Rails开发环境。对于Linux平台的用户来说，Docker provider带来性能与效率的提升是非常明显的。而对于其它平台的用户，虽然在性能上并不能获得显著的提高，但至少可以从开发环境与生产环境一致性中获得益处。

###参考
* [Feature Preview: Docker-Based Development Environments](https://www.vagrantup.com/blog/feature-preview-vagrant-1-6-docker-dev-environments.html)
* [Vagrant官方网站](http://www.vagrantup.com/)
* [Docker官方网站](https://www.docker.io/)
