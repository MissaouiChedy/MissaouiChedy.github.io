---
layout: post
title: "the elixir/erlang platform"
date: 2017-05-24
categories: article
comments: true
---

Currently working on a mobile application that we are building with [Xamarin](https://www.xamarin.com/), I was considering different available platforms for building and operating the application's back-end.

Normally, I would jump straight to a .NET based back-end except this time the back-end services that will support the mobile application are highly concurrent in nature and needs to maintain a [full duplex connection via websockets](https://www.websocket.org/) with each device.

Last year, I was playing around with the [Elixir language](https://elixir-lang.org/) and I even tried out some aspects of the [Erlang](https://www.erlang.org/) OTP framework.

We ([my business partner](https://www.linkedin.com/in/andolsi-jihed-15a0b8a3/) and I) finally chose to use the Elixir/Erlang platform for our back-end, in this post I am going to layout briefly what motivated this choice.

## open telecom platform

[OTP](http://erlang.org/doc/system_architecture_intro/sys_arch_intro.html) (open telecom platform) sounds like it is some switched telephone standard specification, actually it is a framework for building scalable and resilient distributed software systems.

[*Scalable*](https://stackoverflow.com/questions/9420014/what-does-it-mean-scalability) means that we can distribute behavior across multiple nodes (physical or virtual machines) to acquire more capacity, [*resilient*](https://blog.giantswarm.io/reliability-not-enough-resilient-applications-containerized-microservices/) means that the system is up and running when failure events happen (power outages, software crashes...).

OTP is usually packed by default in the erlang basic installations and since elixir code compiles to the erlang's vm bytecode it is effectively possible to [use OTP from elixir](http://blog.jonharrington.org/static/using-otp-from-elixir/).

Abstractions such as [GenServers](https://elixir-lang.org/getting-started/mix-otp/genserver.html), [Supervisors and Applications](https://elixir-lang.org/getting-started/mix-otp/supervisor-and-application.html) defined in the OTP framework with careful design can help us build highly available back-end services.

Erlang and OTP where initially designed to help build and run software for [telecom switches at Ericson](http://www.methodsandtools.com/archive/erlang.php), this kind of switching [equipment required very high availability](https://stackoverflow.com/questions/8426897/erlangs-99-9999999-nine-nines-reliability).


## real oo and concurrency model

[Joe Armstrong](https://twitter.com/joeerl), one of the creators of erlang, [claims that erlang is the most object oriented language available](http://tech.noredink.com/post/142689001488/the-most-object-oriented-language) thanks to its message passing mechanism.

Erlang's concurrency model applies the [shared nothing principle](https://en.wikipedia.org/wiki/Shared_nothing_architecture), in order to launch multiple behaviors concurrently you typically create an [erlang process](http://erlang.org/doc/reference_manual/processes.html). Erlang Processes have some interesting characteristics:

- They are identified by a `pid`
- They do not share state between each other
- They can pass immutable state between each other via messaging
- They are very lightweight, it is possible to create a large number of processes in single erlang VM. (here very large is relative to the number of OS threads and processes that an Operating system can manage)

The [GenServers](https://elixir-lang.org/getting-started/mix-otp/genserver.html) OTP behavior, allows to create a generic server that asynchronously replies to requests defined by the programmer, *GenServers* typically wrap vanilla processes to add life-cycle management functions such as `init/1` and `terminate/2`.

*GenServers* are able as well to maintain state, this characteristic allows us to treat them as [active objects](https://madhuraoakblog.wordpress.com/2014/05/10/active-object-pattern/) to which we send messages defined via `handle_call` and `handle_cast`. Even if Elixir and Erlang are functional programming languages they do support OO encapsulation and data/behavior consolidation.

## "let it crash"

Erlang's excellent fault tolerance attributes stems from the ["let is crash"](http://wiki.c2.com/?LetItCrash) principle, it is actually considered good practice to avoid coding defensively by not handling exceptions and by avoiding to anticipate failures in the software's implementation.

The recommended approach is to assign a *monitoring process* for each *running process* when the *running process* crashes it gets restarted right away by the *monitoring process*. In OTP terms, you assign an OTP [Supervisor](http://erlang.org/doc/design_principles/sup_princ.html) to one or many OTP behaviors (*GenServers* for example), the Supervisor monitors the activity of the *GenServer*, when the *Genserver* crashes for some reason, the *Supervisor* executes a restart strategy that will typically restart the *GenServer*.

This principle allows us to build behaviors that are resilient to nearly any failure condition without requiring developers to anticipate most of them.

Highly disciplined developers will reap large benefits from this approach, which will allow them to address "next level shit" failure conditions.

## hot code replacement

[OTP defines a mechanism to deploy new versions of OTP behaviors **without downtime**](http://www.erlang-embedded.com/2013/10/minimal-downtime-in-flight-drone-firmware-upgrade-in-erlang/), this allows us to basically avoid techniques such as [blue/green deployment](https://docs.cloudfoundry.org/devguide/deploy-apps/blue-green.html) that requires failing over to replicated deployment in order to ensure availability when updating running services.

## Why Elixir?

Why using Elixir instead of plain erlang? A couple of reasons:

- Elixir as a programming language seemed more approachable that erlang
- Elixir has a growing an healthy open source ecosystem with a seemingly state of the art web framework(Phoenix)

[The Phoenix framework](http://www.phoenixframework.org/) provides abstractions such as [channels](http://www.phoenixframework.org/docs/channels) that represents two way communication between clients and servers. In our project this feature is going to be much needed.

## closing thoughts

My business partner and I, being respectively Javascript/PHP and C# developers, are going to miss the regular `for` loops and `if` statements.
But we are looking forward to master pattern matching and recursion.

The erlang runtime has been notoriously slow in number intensive CPU bound computations, but we are also looking forward to out-source intensive number crunching to [golang](https://golang.org/) code when needed.

