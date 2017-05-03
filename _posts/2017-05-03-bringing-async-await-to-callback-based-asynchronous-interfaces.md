---
layout: post
title: "bringing async/await to callback based asynchronous interfaces"
date: 2017-05-03
categories: article
comments: true
---

During the last week, I have been prototyping around a new dating/chat mobile application concept. Since I own an Android device it seemed natural to perform the prototyping on Android.

After playing around with some cross platform tools and the Android SDK itself, I decided to use [Xamarin](https://www.xamarin.com/) for the following reasons:
- Xamarin is cross platform it supports [Android](https://www.android.com/), [iOS](https://www.apple.com/ios/ios-10/) and even [UWP](https://docs.microsoft.com/en-us/windows/uwp/layout/design-and-ui-intro)
- Ability to use C# which is the language I am the most productive with
- Ability to use the abstractions defined in the native SDK of the targeted platform, which brings a native look and feel to the application

I am currently building an MVP version of the Android application and I encountered a lot of asynchronous APIs (such as [`LocationManager`](https://developer.android.com/guide/topics/location/strategies.html) and Facebook's [`GraphRequest`](https://developers.facebook.com/docs/reference/android/4.16.0/class/GraphRequest)) that uses a callback based interface.

In this post we are going to see how to convert these callback based interfaces to `Task` based interfaces that we can use with `async/await`.

Introducing `async/await` and the [Task Parallel Library](https://msdn.microsoft.com/en-us/library/dd460717(v=vs.110).aspx) is beyond the scope of this post, so if you are not familiar with these concepts you can take a look at these links first:
- [Async and Await](http://blog.stephencleary.com/2012/02/async-and-await.html)
- [Task-based Asynchronous Pattern (TAP)](https://msdn.microsoft.com/en-us/library/hh873175.aspx)
- [Asynchronous Programming with Async and Await (C# and Visual Basic)](https://msdn.microsoft.com/library/hh191443(vs.110).aspx)
- [Understanding C# async/await Compilation](https://weblogs.asp.net/dixin/understanding-c-sharp-async-await-1-compilation)


## Callback based interfaces

The Android SDK is written in the Java programming language. In Java, continuations to asynchronous methods that returns to the caller immediately are specified via callback command object.

Consider the following hypothetical Java class that represent a data access object:

<script src="https://gist.github.com/MissaouiChedy/4b0cce2a6f843df5a82101d4315b15dd.js"></script>
The `getPersonAsync` method performs a database lookup for a specific user by their id, this method accepts an object that implements the `GetPersonCallback` interface which defines the `OnSuccess` method.

When the result of the computation (`Person` object in the previous example) is available later in time, the `OnSuccess` method is called with the available `Person` object.

This kind of interface can be used as follows:
<script src="https://gist.github.com/MissaouiChedy/63c13fb4e9f678f6bcbeb788d11b5a9d.js"></script>

The `getPersonAsync` method is called with the a provided `id` and an instance of an [anonymous class](https://docs.oracle.com/javase/tutorial/java/javaOO/anonymousclasses.html). The concept of anonymous classes allows to define and instantiate an object implementing an interface at the same time. This concept is usually not needed in C# since it provides support for [lambda expressions](https://msdn.microsoft.com/en-us/library/bb397687.aspx), [events](https://msdn.microsoft.com/en-us/library/aa645739(v=vs.71).aspx) and [delegate objects](https://msdn.microsoft.com/en-us/library/900fyy8e.aspx).

This style of callback passing is not ideal especially in C# for two reasons:
- We can't conveniently create anonymous object as in Java so we have to separately define a class implementing the callback interface

- This style of callback passing breaks the flow of the program and we have to jump from callback to callback to follow the execution

In C# we have support for the awaitable pattern and it would be nice if we could convert these async methods from accepting callbacks to returning `Task` objects.

## from accepting callbacks to returning tasks

The `System.Threading.Task` namespace, home of the task parallel library, contains the `TaskCompletionSource` class which is key to the `Task` returning transition.

Consider the following C# class that wraps the previous `PersonDAO`:

<script src="https://gist.github.com/MissaouiChedy/549942b4dcd58b9124deb1ee92771355.js"></script>

In Xamarin, Java classes are usable in C# code through some mechanism involving the [JNI](https://www3.ntu.edu.sg/home/ehchua/programming/java/JavaNativeInterface.html)(Java interface for using native code) so in the previous example we just reference objects of the `PersonDAO` java class and call methods on available in them.

The `PersonDAOWrapper` class defines the `GetPersonAsync` method that takes an `id` and returns a `Task<Person>`, this method starts by creating a `TaskCompletionSource<Person>` object which provides a legit `Task` property that can be returned to the caller. It also defines a `SetResult` method that allows to notify it that the result is available which will cause the returned task (via `Task` property) to contain the result.

In the previous example we use the callback based method by passing a callback object that notifies the *task completion source* when the result is available via the `SetResult` method.

As we previously pointed out, in C# we had to define a private class implementing the callback but thanks to the `async/await` constructs we don't need to specify the subsequent steps inside the callback objects. Consider the following snippet, this is how `GetPersonAsync` is used:

<script src="https://gist.github.com/MissaouiChedy/901d606c04dc3e06eda4844eeee23f4c.js"></script>

Notice here how we used the `await` keyword in order to wait in a non blocking fashion for the result to be available. The "Do something with the result part" sits just after the asynchronous call as if the call was synchronous, in this fashion the flow of the program can be followed without jumping from callback to callback.

Since `SomeMethod` uses the await keyword it needs to be marked as `async`, usually `async` methods should return a `Task` or a `Task<T>` and [**returning void is discouraged**](http://stackoverflow.com/questions/12144077/async-await-when-to-return-a-task-vs-void).

I used `void` in the example to show that it is possible to sometime use `void` as a return type for `async` methods. In Xamarin specifically with Android, we usually need to use `await` under an `Activity` life-cycle method such as `OnCreate` or `OnPause`. Since we cannot change the returning type of these methods ( which is usually `void`) when overriding them,  we just keep it as it is when making the life-cycle method `async`.

## closing thoughts

The possibility to use the Android SDK classes and APIs with C# is a huge productivity boost, from my standpoint.

Being able to use Visual Studio, [Linq](https://msdn.microsoft.com/en-us/library/bb397906.aspx), [Extension Methods](https://msdn.microsoft.com/en-us/library/bb383977.aspx), async/await and all the nice C# features when developing cross platform mobile apps is very delightful.

The only complaint that I have regarding Xamarin so far is that the build and deploy process starts to take noticeable time to complete when the projects grows in size.