---
layout: post
title: "Basic Docker Cheat Sheet"
date: 2017-06-03
categories: article
comments: true
---

A couple of years ago, I was hearing a lot of positive stuff around [Linux containers](https://linuxcontainers.org) and specifically about the [Docker engine](https://www.docker.com/).

Recently, I had the opportunity to play around with some Docker containers and I must say that it is a quite useful tool.

Numerous resources exist in the web that discusses the [benefits around Docker](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/7.0_Release_Notes/sect-Red_Hat_Enterprise_Linux-7.0_Release_Notes-Linux_Containers_with_Docker_Format-Advantages_of_Using_Docker.html) and [containers in general](https://www.jpablo128.com/why-use-lxc-linux-containers/) as well as the [technical details](http://blog.scottlowe.org/2013/11/25/a-brief-introduction-to-linux-containers-with-lxc/) of its inner workings.

In this post, I am going to summarize the main tasks that I usually perform with the docker engine but before we proceed, I wanted to point out the two aspects I like the most about it:
- Allows a workflow in which [development folks build containers and operations folks runs them](https://www.dockerbook.com/)
- Containers offer a [stronger isolation level](https://docs.docker.com/engine/security/security/) than regular OS processes

## Searching for an image
`docker search "<SEARCH_TERMS>"`

- This will search the docker hub for images relevant to the search terms.


## Creating a container in attached mode
`docker run -i -t <IMAGE_NAME> <SHELL_COMMAND>`

- `SHELL_COMMAND` is usually an actual shell environment such as `/bin/bash` or `/bin/sh`.

## Creating a container in daemon mode
`docker run -name <CONTAINER_NAME> -d -p <HOST_PORT>:<CONTAINER_PORT> <IMAGE_NAME> <COMMAND>`

- It can be convenient to set a `CONTAINER_NAME` to refer to it easily.
- `-p` allows to map a host tcp/udp port to a containers port.
- `COMMAND` usually starts a server for example: `mongod`


## Listing containers
`docker ps -a`

- `-a` allows to list stopped containers along with running containers

## starting and stopping containers
`docker start <CONTAINER_NAME | CONTAINER_HASH_ID>`
- starts the container identified by its name or its hash id

`docker stop <CONTAINER_NAME | CONTAINER_HASH_ID>`
- stops the specified container

## attaching the console to a running container
`docker attach <CONTAINER_NAME | CONTAINER_HASH_ID>`
- attach the current console to the specified container

`docker exec <CONTAINER_NAME | CONTAINER_HASH_ID> <COMMAND>`
- executes `COMMAND` inside the specified container, this can be useful if attaching to the container will bring a console with the output of the main service running in the container

## detaching the console from a running container without stopping it
`Ctrl+P+Q` 
- use this combination in a console attached to a container via `docker attach`.

## removing and renaming
`docker rm <CONTAINER_NAME | CONTAINER_HASH_ID>`
- **removes** the specified container

`docker rename <CONTAINER_NAME | CONTAINER_HASH_ID> <NEW_NAME>` 
- **renames** the specified container
