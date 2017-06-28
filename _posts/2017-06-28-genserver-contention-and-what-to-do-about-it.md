---
layout: post
title: "genserver contention and what to do about it"
date: 2017-06-28
categories: article
comments: true
---

Elixir is based on the [erlang platform](https://www.erlang.org/), elixir code, just like erlang code, compiles to [BEAM bytecode](http://gomoripeti.github.io/beam_by_example/). [BEAM](http://www.erlang-factory.com/upload/presentations/708/HitchhikersTouroftheBEAM.pdf) is the virtual machine (AKA runtime) that runs erlang software.

Elixir supports also OTP and it is possible to build highly concurrent application by using abstractions such as *applications*, *supervisors* and *GenServers*. This allows us to basically leverage asynchrony for better IO bound performance and multi-core parallelism for better CPU bound performance.

Using elixir will not grant us incredible performance per se, rather it provides us a great language with primitives and abstractions that allows us to build for performance, reliability and scalability.   

In this post we are going to discuss *worker contention* which is a performance issue that can pop up when work is not properly distributed over enough worker instances. We will focus specifically on GenServers since they are the most basic type of OTP worker behavior.

## when does contention happen?


Let's consider a single *GenServer instance* that performs a single *expensive operation(compute)* and multiple *client processes* soliciting the GenServer by sending a single message each and expecting a reply:

<div class="img-container">
![single genserver contention]({{ site.url }}/imgs/single_genserver_contention.PNG)
</div>
Messages that are sent by the processes are queued in the GenServer's mailbox and are processed one by one.

Given `n` client processes and the fact that it takes `dt` time units (milliseconds for example) for the GenServer to process a single message, even if the first client reaching the GenServer will be served in `dt` time units, the n-th will be served in (`dt x m`) time units!!

In this situation, imagine what happens now if each client is sending multiple requests per second to the GenServer. The GenServer's mailbox will grow larger and larger making the it effectively become a bottleneck constituting a *contention point* in the application.

## pooling workers

One solution to the previous issue is to simply distribute the clients load (messages) to multiple GenServer instances, a new instance is created for each request. 

This is not ideal because a large number of very active clients will cause the creation of a very large number of instances.

An improvement to the previous solution is use a *pool* that will limit and keep track of GenServer instances.

<div class="img-container">
![single genserver contention]({{ site.url }}/imgs/genserver_pool.PNG)
</div>

The *pool* can be an actual GenServer that is responsible of creating and keeping track of GenServer instances, it is configured with a *maximum number of instances* to manage and provides two main functions: 
- `checkout` that allows to get an instance from the pool 
- `checkin` that allows to return back an instance to the pool 

The *pool* makes sure that no more instances than specified are created and allows to reuse previously created instances.

Clients usually `checkout` an instance, makes a request to the instance and when finished returns the instance back to the pool via the `checkin` function.

When the *pool* gets a `checkout` request it can either:
- return an existing available instance
- create and return a new instance
- cause the client to block waiting for an instance to become available when the limit is reached

Setting the appropriate *maximum instances number* is key to getting optimal performance, a small number will not remedy contention and a large number can allocate more resources than needed.

Furthermore, it depends on the type of work that the worker GenServer is performing:
 - CPU bound work should be distributed over *n* workers where n is equal to the number of cores in the machine
 - IO bound work should be distributed over *n* workers where n is tricky to figure out and depends upon the specificities of the IO medium (database, network, disk...)

The most pragmatic way to get this number wright is to benchmark the application in a production environment by experimenting with various values of *maximum instances*.

## a cpu bound example
In the following [Github repository](https://github.com/MissaouiChedy/Pooling), you can find a small elixir application that demonstrates the effect of contention.

The application basically calculates all prime numbers in a given range, when the range gets large the computation starts to become expensive.

The *primes calculation* is concurrently requested by `n` *client processes* on a single *GenServer instance*, then by `n` *client processes* on a pool of `n` GenServer instances where `n` is the number of cores in the machine.

The [Poolboy](https://github.com/devinus/poolboy) erlang library has been used to create the GenServers pool and it worked seamlessly in elixir.

In the interest of brevity, we won't dive into the inner-workings in this article. If you are interested in the details checkout the project's [README.md](https://github.com/MissaouiChedy/Pooling/blob/master/README.md) and the well factored and commented (I hope :-)) source code.

Nevertheless, here is a sample output of the program executed on my machine ([Intel Core i7 4750HQ](https://ark.intel.com/en/products/76087/Intel-Core-i7-4750HQ-Processor-6M-Cache-up-to-3_20-GHz)@800Mhz) with `range_size == 10000`:
<script src="https://gist.github.com/MissaouiChedy/ad4915add30c595ea03e66ceb4a4dcba.js"></script>

You can see that the pooled execution performs much better overall.

## pooling is not a silver bullet

Pooling will not solve every contention issue, in fact imagine having multiple *GenServer instances* in a *pool* that are performing operations that ultimately reads or writes from the same slow mechanical disk, here the contention issue has not been addressed and the contention point has been just pushed to the hardware disk.

When GenServers are stateful, in the sense that messages must be directed to a specific instance that holds a specific state, pooling as described earlier will not be sufficient and some routing mechanism will be needed to properly forward the correct message to the correct *GenServer instance*.

## closing thoughts
Using elixir, will not make your applications automatically fast and reliable.

Understanding how the primitives work and how to use them is key to building robust and powerful systems, otherwise issues will arise.  