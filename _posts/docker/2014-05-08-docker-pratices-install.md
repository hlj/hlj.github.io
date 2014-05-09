---
title: 'Docker实战： 二、安装'
summary: "在使用Vagrant创建的Ubuntu虚拟机中，通过Puppet来自动安装Docker。"
tags: Docker 服务器
category: 服务器
series: Docker实战
layout: post
---

{% assign align='right' %}
{% assign src='/docker/docker-top-logo.png' %}
{% include image.html %}


Docker可以运行在大多数Linux发行版上。但因为它对Linux Kernel版本有一定的要求（3.8以上），所以有些发行版需要自行升级内核。

一般建议在有条件的情况下，尽量选择Ubuntu Server版做为主机，因为Docker官方对Ubuntu的支持最好。

Docker的安装也比较简单，基本上按照[官方的文档](http://docs.docker.io/en/latest/)就可以很容易的安装完成。

但在本文中，我们会使用比较特别的方法来安装Docker：**用[Vagrant](http://www.vagrantup.com/)来创建和管理Ubuntu虚拟机，并通过[Puppet](http://puppetlabs.com/)来安装**。

{% series_list %}

##为什么？
为什么不直接使用官方的安装方法呢？为什么要引入Vagrant与Puppet呢？
其中主要的原因有以下几点：

* 很多人都是在Windows或Mac机器上做开发，而Docker必须运行在Linux环境下，这就给学习Docker带来了麻烦。而 Vagrant 是现在最流行的跨平台虚拟开发环境工具。通过使用Vagrant，Windows、 Mac OS X与Linux用户可以用完全相同的方式来安装并学习Docker。

* Vagrant能以自动化的方式同时管理一台或多台虚拟机。在今后遇到需要使用多台Docker服务器的场景时，可以节省大量的时间与精力。

* Puppet是一个被广泛使用的软件自动化配置与部署工具。在DevOps中起到了关键的作用。通过引入Puppet，我们可以在开发环境和生产环境共用一套配置脚本，只要开发环境配置好了，那么在生产环境安装Docker将是一件轻而易举的事情。

有关Vagrant与Puppet的使用说明超出了本文范围。如果您不太熟悉这两款软件，也没关系，只要按照本文的步骤，安装Docker是没问题的。

##安装Vagrant

安装方法请参见[Vgrant安装配置](https://github.com/astaxie/Go-in-Action/blob/master/ebook/zh/01.2.md), 注意只要安装好VirtualBox与Vagrant软件即可，先不要下载box。

同时建议您安装 [vagrant-vbguest](https://github.com/dotless-de/vagrant-vbguest) 这个Vagrant的插件。这个插件可以帮助您自动安装或更新VirtualBox Guest Additions。

##创建虚拟机

建议使用[Ubuntu官方的13.10版box](http://cloud-images.ubuntu.com/vagrant/saucy/current/saucy-server-cloudimg-amd64-vagrant-disk1.box)文件。您也可以在[http://www.vagrantbox.es](http://www.vagrantbox.es)上找到由其他人提供的各个版本的Ubuntu虚拟机。

虽然vagrant能自动下载镜像，但鉴于国内的网络现状，建议您还是先下载好相应的box文件。

下载好box文件后，就可以开始创建本次要使用的虚拟机了。下面假设下载的box文件保存为：～/vagrant/boxs/ubuntu-13.10-base.box。

{% highlight sh %}
$ mkdir -p ~/vagrant/docker-1
$ cd ~/vagrant/docker-1
$ vagrant init docker-1 ~/vagrant/boxs/ubuntu-13.10-base.box
$ vagrant up
{% endhighlight %}
至此，一个名为docker-1的虚拟机已创建完成并正在运行中，我们可以通过

```sh
$ vagrant ssh
```
来登录此虚拟机。

接下来需要配置此虚拟机使用puppet作为provision提供者，修改 Vagrantfile，添加以下配置：

```ruby
 # 设置hostname以防止puppet运行出现错误
 config.vm.hostname = "docker-1.hlj.com"
 # 设置provision方式为 Puppet
 config.vm.provision :puppet do |puppet|
    puppet.manifests_path = "puppet/manifests"
    puppet.module_path = "puppet/modules"
    puppet.manifest_file  = "site.pp"
 end
```

##在目标机器上安装Puppet
如果使用的是Ubuntu官方的vagrant box，Puppet应该已经预装了。如果没有的话，安装也很方便：

```sh
$ sudo apt-get update
$ sudo apt-get install puppet-common
```
因为是以单机方式使用Puppet，所以只需要安装puppet-common这个包就行了，无需安装puppet和puppet-master，也不需要进行任何配置。

##准备Puppet初始资源清单
1.首先创建一个容纳Puppet manifests和modules的目录结构：

```sh
$ cd ~/vagrant/docker-1
# 创建清单文件目录
$ mkdir -p puppet/manifests
# 模块目录
$ mkdir -p puppet/modules
# 创建主清单文件
$ touch puppet/manifests/site.pp
```

2.在site.pp中加入以下内容：

```puppet
# 创建 puppet 组
group { "puppet":
    ensure => present,
}

# 自动执行 apt-update，但限制每天最多一次
exec { "apt-update" :
  command => "/usr/bin/apt-get update",
  schedule => daily,
  require => Group[puppet]
}

# 确保在其它包资源执行前执行apt-update
Exec["apt-update"] -> Package <| |>
```

3.执行 `vagrant reload --provision`, 重启虚拟机并应用Puppet。如果一切正常，你应该看到类似如下输出：

```sh
...
[default] Running provisioner: puppet...
Running Puppet with site.pp...
Notice: /Stage[main]//Exec[apt-update]/returns: executed successfully
Notice: Finished catalog run in 16.60 seconds
...
```

到目前为止，Puppet还没有做什么实际工作，只是更新了apt数据库。但这是一个良好的开端，随后我们将填充它来完成实际的Docker安装工作。

##下载用于Puppet的Docker模块
虽然我们完全可以按照官方的安装指南来自己编写Docker的安装模块，但是既然已经有人帮我们写好了，那么本着不要重新发明轮子的精神，就直接下载使用吧。

```sh
# 因为在我的host机器上没有安装Puppet，所以安装Puppet模块的命令要到虚拟机中去执行
$ vagrant ssh
# 在虚拟机里切换到共享的/vagrant目录
vagrant@docker-1:~$ cd /vagrant
vagrant@docker-1:/vagrant$ puppet module install garethr-docker --target-dir=puppet/modules
vagrant@docker-1:/vagrant$ exit
$ ls puppet/modules
```
这时应该可以看到在modules下多了 `apt    docker epel   stdlib` 这4个模块。其中docker是主模块，其它3个是它所依赖的模块。

##使用Docker模块
在site.pp中增加：

```puppet
include docker
```
然后执行

```sh
$ vagrant provision
```
最新版本的Docker就已经安装在我们机器上，并且正常运行了。
下面让我们验证一下(此处版本号可能与本文不同，因为上述安装过程会自动安装最新版本的Docker)：

```sh
$ vagrant ssh
vagrant@docker-1:~$ sudo service docker status
docker start/running, process 14278
vagrant@docker-1:~$ sudo docker version
Client version: 0.8.0
Go version (client): go1.2
Git commit (client): cc3a8c8
Server version: 0.8.0
Git commit (server): cc3a8c8
Go version (server): go1.2
Last stable version: 0.8.0
```

在Docker Puppet模块的[GitHub主页](https://github.com/garethr/garethr-docker)上有其详细的使用说明。

通常情况下，像上面那样简单的配置就可以了。不过为了今后能更方便使用Docker，需要稍微增加一点脚本复杂度。现在将site.pp 中的 `include docker` 改为以下内容：

```puppet
# 同时绑定socket文件和tcp端口，以便今后引入Docker管理软件
class { 'docker':
  tcp_bind    => 'tcp://0.0.0.0:4243',
  socket_bind => 'unix:///var/run/docker.sock',
}

# 注意，因为某些众所周知的原因，国内用户不要添加以下内容，基础镜像的安装方法请参见下一篇文章。
# 自动下载基础镜像
docker::image { 'ubuntu':
    require => Class['docker'],
}
```

##UFW设置
现在Ubuntu都预装了ufw这个很好用的防火墙，但是默认并没有开启。如果您计划启用它的话，则需要对它进行一些配置，以保证Docker能正常工作。

首先下载UFW的Puppet模块：

```sh
$ cd puppet/modules
$ git clone https://github.com/hlj/puppet-module-ufw.git ufw
```
这个模块给我们操作UFW提供了基础。

下面创建一个Puppet模块来配置我们的ufw选项。

```sh
$ mkdir -p puppet/modules/ufw-docker/manifests
$ touch puppet/modules/ufw-docker/manifests/init.pp
```

更改 `init.pp` 的内容为：

```puppet
class ufw-docker {
    Exec {
        path => "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
    }

    include ufw

    ufw::allow { "allow-ssh-from-all":
        port => 22,
        ip => "any",
    }

    ufw::allow { "allow-docker-from-all":
        port => 4243,
        ip => "any"
    }
}
```

在 `site.pp` 中加入：

```puppet  
include ufw-docker
```

保存后执行

```sh
$ vagrant provision
```
这样，我们就启用了UFW，并且开放了ssh与docker端口。

*注：官方安装指南中关于 DEFAULT_FORWARD_POLICY 的配置，我在虚拟机上试验时，发现不需要修改。可能物理机会有区别，需要以后验证。*

##非ROOT用户授权
Docker的后台进程是以root用户权限执行的，所以我们在执行docker的命令时，需要用 `sudo docker ...`。但是Docker也提供了一种机制让我们不需要使用sudo就可以运行Docker命令。只需要把用户加入docker组即可。

现在，让我们来创建一个模块配置相应的用户：

```sh
$ mkdir -p puppet/modules/docker-user/manifests
$ touch puppet/modules/docker-user/manifests/init.pp
```

In `init.pp` :

```puppet
class docker-user($users) {

    # Define: add_to_group
    # add a user to docker group
    define add_to_group () {
        exec { "add_${name}_to_docker_group":
            command => "gpasswd -a ${name} docker",
            path => $path,
            unless => "grep -E 'docker\\S*${name}' /etc/group",
        }
    }

    group { "docker":
        ensure => present,
        require => Class["docker"]
    }

    add_to_group { $users:
        require => Group["docker"]
    }

    exec {"restart docker":
        command => "service docker restart",
        path => $path,
        require => Add_to_group[$users],
    }
}
```
在 `site.pp` 中加入:

```puppet
class { "docker-user":
    users => ["vagrant"], # 提供您想加入docker组的用户名
}
```
然后执行

```sh
$ vagrant provision
```
重新登录后，您应该可以不加sudo,直接执行Docker命令了。
