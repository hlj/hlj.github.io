---
title: 'Docker实战： 一、简介'
summary: "Docker是一个开源的容器引擎，用于在任何地方自动化部署任何应用程序。"
tags: Docker 服务器
category: 服务器
series: Docker实战
layout: post
---

{% assign align='left' %}
{% assign src='/docker/docker-top-logo.png' %}
{% include image.html %}

在Docker的主页上是这么介绍它的：

> Docker is an open-source engine that automates the deployment of any application as a lightweight, portable, self-sufficient container that will run virtually anywhere.
>
> Docker containers can encapsulate any payload, and will run consistently on and between virtually any server. The same container that a developer builds and tests on a laptop will run at scale, in production*, on VMs, bare-metal servers, OpenStack clusters, public instances, or combinations of the above.


从第一句话中我们可以知道，Docker是一个开源的容器引擎，用于在任何地方自动化部署任何应用程序。
它所谓的容器内可以包含任何内容，运行在几乎任何基础设施上。并能保持测试与生产环境的一致性。

Docker最本质的能力就是可以帮助我们将任何应用程序及它的所有依赖项，打包成独立的、易于分发及部署的容器。这些容器可以轻松运行在任何Docker所支持的基础设施上，使我们有能力构建所谓的PaaS.

{% series_list %}

## 基础知识
对于Docker的历史、实现原理、运行机制、限制条件等更多细节问题，请移步至

[Docker 介绍: 相关技术](http://tiewei.github.io/cloud/Docker-Getting-Start/)

 这个页面。此页面基本上涵盖Docker相关的所有基础知识。

## 我能用Docker吗？

Docker目前最基本的限制，就是它基于Linux 64bit，无法在windows/unix或32bit的linux环境下使用。因此，如果您没有Linux 64bit的主机，或者您的应用要求运行在windows/unix环境下，那现在就可以直接飘走了。

除此之外，应该没有什么硬性限制能阻止您使用Docker。

## 它能解决什么问题？

Docker是 PaaS 提供商 dotCloud 开源的一个容器引擎。dotCloud公司使用它为成千上万的客户提供应用平台服务。Google、Redhat、百度等巨头也加入了对Docker的支持。可以说是风头正劲。

但它与我们这些普通公司又有什么关系呢? 本人认为，使用Docker最大的意义在于推进DevOps.

DevOps是一个热门的话题，同时也是一个复杂的话题。它包含了从开发到运维的一系列方法与工具的整合。Docker的出现，改变了我们传统的应用程序发布与管理方式。Docker所提供的一次打包，多处运行、开发与生产环境统一、应用间隔离、运行环境版本化、应用服务化等理念与手段，能很好的补充现有DevOps工具在应用开发、部署与管理方面的短板。同时，Docker作为应用程序更高层次的包装，也能与puppet,chef等现有DevOps工具无缝结合，必将进一步推动DevOps的发展。
