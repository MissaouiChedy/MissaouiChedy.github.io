---
layout: post
title: "Thread synchronization with Monitors in C#"
date: 2019-04-28
categories: article
comments: true
---
Concurrent programming is important
It is useful for async IO which improves overall responsivness
It is useful for Parrallelism which improves CPU bound performance by leveraging multicore
It useful to model some domain problems as concurent or parallel
Historically, Concurrency and parallelism where achieved by using processes and threads, the CLR is mature enough to support both
.NET X introduced multiple abstractions that makes it easier to build applications that leverages parallelism and concurrency such as TPL, Parallel.ForEach, async/await.

When programming concurrently, we are usually faced with the shared resource problem. In fact, multiple threads of execution cannot access mutable objects safely at the same time as we will see further.

In this post, we are going to explain briefly why we have to synchronize access to shared resources and we are going to discuss Monitors a synchronization mechanism available in .NET.

## Race conditions

Race condition occurs when multiple threads access the same mutable object at the risk of leaving it in an inconsitent or corrupt state.
Example

Note: Immutable objects does not suffer this problem since they never change, that is why runtimes with solid concurrent semantics such as Erlang encourages the usage of immutable data strucutre and discourages sharing resources in the first place.

We need a way to synchronize

## The lock statement

The lock statement allows to lock an object ensuring that only one thread accesses the objects at given time.
Example

The C# compiler is renowed for providing a lot of assitance and features to developers. Along with LINQ query notation and the using statement, the lock statement is converted by the compiler to an intermediate representation which looks like this:
CODE

You can see here that the lock statement uses the Monitor class under the hood 
Explain the example (Enter, exit, Finally exit)

The monitor class is not only useful to lock objects, it can also be used to implement a synchronization concepts called conditions. 

## Conditions
Conditions are about waiting and notifying, consider the following example:
Example

See how we synchronized multiple threads of execution by notifying other threads when a certain condition is reached.  


## Closing thoughts

As we mentionned previously, concurrent programming is now very important because reasons.
I initially learned concurrent concepts by reading the excellent Modern operating systems and especially the Processes and threads chapter.

CLR via C# has been also very helpful in realizing that async for I/O and parallelism for CPU bound.