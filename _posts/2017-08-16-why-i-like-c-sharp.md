---
layout: post
title: "Why I Like C#"
date: 2017-08-16
categories: article
comments: true
---

So far, I considered [C#](https://docs.microsoft.com/en-us/dotnet/csharp/getting-started/introduction-to-the-csharp-language-and-the-net-framework) as the best language in its category (managed object-oriented languages with static typing) and it seems that this not bound to change yet with the new goodness that will be available in [C# 7](https://docs.microsoft.com/en-us/dotnet/csharp/whats-new/csharp-7).

Coding in C# feels very productive and it is my current favorite programming language. In this post, I would like to articulate the reasons of this choice.

## Many things can be done using C\#

Many types of applications can be developed by using C#:
 - Cross platform Web applications and APIS with [ASP.NET CORE](https://docs.microsoft.com/en-us/aspnet/core/)
 - 2D and 3D Video games with [Unity](https://unity3d.com)
 - Windows desktop applications with [WPF](https://docs.microsoft.com/en-us/dotnet/framework/wpf/getting-started/introduction-to-wpf-in-vs)
 - Cross platform mobile application with [Xamarin](https://www.xamarin.com/platform)

The most exciting thing that led me to adopt C# as a primary language is the [.NET Core Runtime](https://www.microsoft.com/net/core#windowscmd) which allows to run C# applications on Linux.

## Community support and tooling

[Visual studio](https://www.visualstudio.com) is one of the best IDE available and offers naturally excellent support for C#. The VS Debugger as well as [Intellisense](https://code.visualstudio.com/docs/editor/intellisense) are huge productivity boosts.

One might think that minimal support for building C# application would cost money, but actually it is not the case because an open source .NET community is rising steadily by building a large volume of accessible educational resources and [open source libraries](https://github.com/trending/c%23).

## C# features I appreciate the most

[**Automatic properties**](https://docs.microsoft.com/en-us/dotnet/csharp/programming-guide/classes-and-structs/auto-implemented-properties) are very nice and allows us to avoid a lot of  boiler plate when defining encapsulated properties.

[**LINQ**](https://docs.microsoft.com/en-us/dotnet/csharp/programming-guide/concepts/linq/introduction-to-linq-queries) allows to cut a lot of fluff by allowing a declarative chaining of operations and allows for a bit of a functional style of programming which is nice to have in some cases.

[**async/await**](https://docs.microsoft.com/en-us/dotnet/csharp/async) is a construct that allows to get rid of callback based asynchronous interfaces that in my opinion can pollute the code base seriously in complex cases. This basically makes asynchrony more affordable from a maintainability stand point.

## Closing thoughts

I am looking forward to **pattern matching** in C# 7 in which I hope we will more support for the functional style of programming.







