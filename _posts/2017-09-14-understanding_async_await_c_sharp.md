---
layout: post
title: "Understanding async/await in C#"
date: 2017-09-14
categories: article
comments: true
---

Asynchronous programming is essentially having routines that returns immediately after being called. I was first exposed to this kind of calls with [Ajax](https://developer.mozilla.org/en-US/docs/AJAX) on the browser.

[C# 5 introduced the `async` and `await` keywords](https://docs.microsoft.com/en-us/dotnet/csharp/async) which are very useful for making calls to asynchronous methods without breaking the *linear flow of the program.*

I had a hard time understanding `async/await` and especially the difference between the `Task.Wait` method and the `await` statement.

In this post, We will try to explain the very basic principle of `async/await`.

## Methods returning Tasks

The [TPL library](https://docs.microsoft.com/en-us/dotnet/standard/parallel-programming/task-parallel-library-tpl) allows us to create a `Task` object which represents a on going operation, the operation is usually executed in a different thread ([but not always depending on the synchronization context](https://msdn.microsoft.com/en-us/magazine/gg598924.aspx)).

Consider the following:

<script src="https://gist.github.com/MissaouiChedy/9819c3f6158a30405ecbc486dcc9f7f0.js"></script>

Creating a method that returns a task is basically creating an asynchronous method that will return its `Task` object immediately when it is called, as in the following example:

<script src="https://gist.github.com/MissaouiChedy/4b77c28a20c09b984f0d4f196d1c3695.js"></script>

Whenever called the `GetIntAsync` method returns immediately, to get the result returned by the task we have to wait for it somehow. 

## Waiting synchronously

The `Task` class provides methods that allows us to wait synchronously for the operation completion, calling `Task.Wait` or referencing the `Task.Result` property will cause the current thread to block waiting for the completion of the task, consider the following:

<script src="https://gist.github.com/MissaouiChedy/fb94ff0429a917a5474b6483a815937a.js"></script>

Before proceeding to *doing stuff with* `res` the `DoStuff` method have to wait synchronously for the task completion.

This basically defeats the purpose of asynchrony which we use to get a chance to do something else on the same thread while an operation completes. 

This is especially useful for IO bound operation that involves using high latency media such as networks and disks. Instead of waiting for IO in the current thread we can do useful work instead and wait for IO in another thread. 

[NodeJS](https://nodejs.org) is [renowned to be very fast for IO bound workload](https://strongloop.com/strongblog/node-js-is-faster-than-java/) because nearly all of its API is asynchronous!

Fortunately, we don't have to wait synchronously each time we need the result of an asynchronous operation, we can schedule a callback that will be executed on task completion.

## Scheduling a continuation (aka callback)

The `Task` class provides the `ContinueWith` method to which we can pass a statement lambda that will be executed on task completion, consider the following:

<script src="https://gist.github.com/MissaouiChedy/5ee10914b1cbe66a08926ab438a99947.js"></script>

The `DoStuff` method does not block waiting for `GetIntAsync` to complete, instead it schedules a continuation to be executed when the task completes. Notice how the statement lambda gets `res` as an argument.

You can clearly see here that continuations are essentially callbacks and this is very similar to classic async programming that we can witness in various languages such as Javascript ES5 and Java for example.

This style of passing callback can get feisty in complex scenarii and we can end up with a [callback hell](http://callbackhell.com) in which we have to jump from callback to callback to follow the execution logic.

The `await` keyword allows to avoid this callback hell by basically "waiting without blocking" without breaking the linear flow of the program.

## The Await keyword schedules continuations for us

Consider the example:

<script src="https://gist.github.com/MissaouiChedy/cc4c0effe856d9259034262a7a0eeff2.js"></script>

The `await` keyword is here used to call the asynchronous `GetIntAsync` method, notice here how we assigned the returned result directly to an `int` variable that can be used by the subsequent statements.

Note here that `await` is **not blocking the current thread** and the *do something with res* part is only executed when `GetIntAsync` is finished.

The `await` keyword basically instructs the C# compiler to:
 - take all statements after await
 - package them into a lambda
 - generate code that schedules the lambda for us

Instead of registering callbacks our selves, the `await` keywords allows us to delegate the work to the compiler.

This allows us to have a linear code flow while leveraging the benefits of asynchrony i.e. waiting without blocking.

Note also how we marked `DoStuff` as an `async` method returning a `Task`, all methods using the `await` keyword must be marked as `async`, since they are waiting without blocking they become asynchronous methods themselves and returns immediately when called.

We don't have to deal with the generated code and of course in reality the process is more complex than described earlier, checkout the closing thoughts for pointers to details.

### What happens when an exception is thrown?

The great thing about `async/await` is that most of the rest language feature work as expected, exception for example:

<script src="https://gist.github.com/MissaouiChedy/72ccf1c351925e510ded1c4ccb45db69.js"></script>

The thrown exception can be caught and the `catch` block will be executed when the exception is thrown in the asynchronous operation, so no worries.

## Closing thoughts

`async/await` is one of the C# features that are [boosting my productivity the most]({{ site.url }}/article/why-i-like-c-sharp.html#c-features-i-appreciate-the-most), fortunately more languages are adopting this construct like [Javascript](https://developers.google.com/web/fundamentals/getting-started/primers/async-functions), [Python](https://docs.python.org/3/library/asyncio-task.html) and more.

If you are interested in more detail about `async/await`, I encourage you to check part 5 of [C# in depth](http://csharpindepth.com/) by [Jon Skeet](https://stackoverflow.com/users/22656/jon-skeet).

Also check out chapter 28 of [CLR via C#, 4th Edition](https://www.amazon.com/CLR-via-4th-Developer-Reference/dp/0735667454) by Jeffrey Richter for a discussion about the benefits of asynchrony for IO bound operations.