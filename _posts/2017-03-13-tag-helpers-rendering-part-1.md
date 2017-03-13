---
layout: post
title: "Tag Helpers Rendering Part 1"
date: 2017-03-13
categories: article
comments: true
---

In a [previous post](http://blog.techdominator.com/article/rendering-a-tag-helper-inside-another-tag-helper.html), I reported my take on how to programatically render an ASP.NET Core tag helper in C# code, precisely inside another tag helper's class.

At the end of the article I laid out some interrogations that I had, among them was: How to properly create the necessary `TagHelperContext` and `TagHelperOutput` objects?

After some investigation I managed to somewhat understand how the ASP.NET Core framework renders tag helpers. This post is the first part of a series about how tag helpers rendering works in the ASP.NET Core framework.

In the present post, I am going to talk about the environment that a I set up 
in order to investigate the behaviors related to tag helpers content generation.

## The debugger is an exploration tool

The [Visual Studio debugger](https://www.youtube.com/watch?v=7ab4z9u7Q_I) is a great diagnostic tool that can help to pin down malfunctions fast. In addition, it is a great learning and exploration tool. 

The ability to set breakpoints, to perform "step over" and "step into" inside any available code base can make the process of understanding behaviors of interest much easier.

In fact, it is possible to follow step by step what the system is doing and to inspect the content of the variables involved at virtually any point.

I cannot stress enough how much this made the investigation process progress smoothly.

## Building the playground

ASP.NET Core is composed of a [lot of projects](https://github.com/aspnet), I had to dig up the tag helper rendering behavior in two of these:
- [Mvc](https://github.com/Mvc) which is the actual core ASP.NET Core Framework
- The [Razor](https://github.com/Razor) template engine project

The [Mvc](https://github.com/Mvc) solution comes with the convenient 'MvcSandbox' project that references the projects inside the [Mvc](https://github.com/Mvc) solution instead of referencing Nuget packages. This allows us to have the previously described debugging capability.

Unfortunately for our case, we are going to need to step into the Razor template engine code which is not included in the [Mvc solution](https://github.com/Mvc) by default.

In order to debug the Razor code we need to do the following actions:

1. Clone the [Razor](https://github.com/Razor) solution and build it locally.
2. Add the projects located under the `src` folder of the Razor solution as existing projects in the Mvc solution.
3. Figure out which projects from the Mvc solution depends on which projects from the Razor solution (by grepping csproj files).
4. Replacing the nuget dependencies to `Microsoft.AspNetCore.Razor.*` in the Mvc projects by project references pointing to the projects added in step 2.

Once all of these step done, I had the ability to step into any Mvc and Razor line of code.

## Getting template code generated by Razor

As you might know, razor cshtml views are actually converted to C# classes that inherit from the [`RazorPage`](https://github.com/aspnet/Mvc/blob/dev/src/Microsoft.AspNetCore.Mvc.Razor/RazorPage.cs) class.

The generated C# class overrides the `ExecuteAsync` to make it contain the html output generation behavior.

Tag helpers are actually rendered under this method, so we are going to need to have access to the generated template code in order to inspect it.

One easy way to get the generated code when using ASP.NET Core 1.1 is to actually introduce an error in the cshtml file, launch the application and try to display the sabotaged view which will display an error page.

For example, inserting the `@{ int a = "word"; }` somewhere in the `Views/Home/index.cshtml` view causes the following error page to display:
<div class="img-container">
![The error page displays C# code]({{ site.url }}/imgs/c_sharp_code.PNG)
</div>

You can see here that the relevant C# code is dumped and can thus be copy pasted in a text editor for inspection.

## A very simple example

In order to disect the tag helper rendering behavior, we will use the `~/Views/Home/Index.cshtml` view under the MvcSandbox project to render the [`<img>` tag helper](http://www.davepaquette.com/archive/2015/07/01/mvc-6-image-tag-helper.aspx). We will then use the techniques described previously to get the generated C# code and to follow the execution of the template.

The following is the Index.cshtml file:

<script src="https://gist.github.com/MissaouiChedy/bd345b998c91668ccb44598a7e9bccee.js"></script>

Here the `asp-append-version` attribute activates the [`ImageTagHelper`](https://github.com/aspnet/Mvc/blob/dev/src/Microsoft.AspNetCore.Mvc.TagHelpers/ImageTagHelper.cs) which optimizes the image loading process by leveraging compression and browser caching.

And here is the C# code generated from the previous template:

<script src="https://gist.github.com/MissaouiChedy/b57ab0b8b52d895ef932131e4f6eb962.js"></script>

If you take a look at the previous listing under the `ExecuteAsync` you will notice that objects belonging to the following classes are used: `TagHelperRunner`, `TagHelperScopeManager` and `TagHelperExecutionContext`. These classes are involved in the tag helper rendering process all we have to do is to step into their execution to understand what's going on.

## In the upcoming post...

We are going to dissect the execution of the `RazorPage.ExecuteAsync` method in order to understand the rendering process.