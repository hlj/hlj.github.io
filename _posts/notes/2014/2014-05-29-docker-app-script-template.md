---
title: '一个管理Docker应用程序的脚本模板'
summary: "使用Shell脚本管理Docker容器"
tags: Docker Shell脚本
category: 脚本技术
layout: post
---

这是一个用于管理使用Docker打包的应用程序的脚本。通过包装docker命令，提供了特定应用程序的启动、停止、删除等管理功能。通过修改几个变量值，可以很容易的适配各类应用。

```sh
#! /bin/bash -

#####################################################
# 此文件为Docker容器管理脚本模板,可自由使用与传播.
# 请根据具体的应用程序作相应修改
# 如有疑问，请联系: Beta CZ <hlj8080@gmail.com>
#####################################################

# 应用程序配置，按需修改
imagename=dockerfile/redis
container_name=redis_db
start_cmd="docker run -d -p 6379:6379 --name ${container_name} ${imagename}"

# 获取容器状态命令, 除非Docker命令有变化，否则无需更改
container=(`docker ps | grep ${container_name}`)
container_stopped=(`docker ps -a | grep ${container_name}`)

# 以下内容只在必要时才能更改,并确保清楚其后果.
usage()
{
  echo " * Usage: $0 {start|stop|kill|remove|status}"
  exit 255
}

if [ $# -ne 1 ]; then
  usage
fi

if [ $1 != "start" ] && [ -z $container ] && [ -z $container_stopped ]; then
  echo "ERROR：容器 ${container_name} 不存在."
  exit 255
fi 

case $1 in
start)
  if [ $container ]
  then
    echo "${container_name} 应用正在运行中,请不要重复运行!"
    exit 255
  fi
        
  if [ $container_stopped ]
  then
    echo "${container_name} 已经停止，现在重新启动..."
    docker start ${container_name}
  else
    echo "${container_name} 开始启动..."
    container_id=(`${start_cmd}`)
  fi
  echo "启动完成,应用名称为:${container_name},ID为:${container_id}"
  ;;
stop)
  if [ $container ]; then
    docker stop ${container_name}
    echo "停止 ${container_name} 已完成."  
  elif [ $container_stopped ]; then
    echo "${container_name} 当前已经处于停止状态，操作无效."
  fi
  ;;
kill)
  if [ $container ]; then
    docker kill ${container_name}
    echo "杀死 ${container_name} 已完成."  
  elif [ $container_stopped ]; then
    echo "${container_name} 当前已经处于停止状态，操作无效."
  fi
  ;;
remove)
  if [ $container ]; then
    echo "${container_name} 正在运行中，无法删除。"
    exit 255
  elif [ $container_stopped ]; then
    docker rm ${container_name}
    echo "删除 ${container_name} 已完成."
  fi
  ;;
status)
  if [ $container ]; then
    echo "${container_name} 正在运行中."
  elif [ $container_stopped ]; then
    echo "${container_name} 容器已创建，但处于停止状态。"
  else
    echo "${container_name} 容器未找到！"
  fi
  ;;
*)
  usag
  ;;
esac
exit 0

```