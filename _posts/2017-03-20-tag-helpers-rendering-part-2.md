---
layout: post
title: "Tag Helpers Rendering<br>Part 2"
date: 2017-03-20
categories: article
comments: true
---

In the [previous post](http://blog.techdominator.com/article/tag-helpers-rendering-part-1.html), I discussed how to setup an exploration environment that allows to step into and over the execution of the ASP.NET Core framework and specifically in the [Mvc](https://github.com/aspnet/Mvc) and the [Razor](https://github.com/aspnet/Razor) projects code bases in order to understand the Tag Helpers rendering mechanism.

The tag helpers used in cshtml views are rendered by the C# classes generated.The ability to follow its execution step by step proved to be useful. 

At the end of the last post, I showed the C# class originating from a very simple cshtml file.

Let's now analyze its execution starting with the generated razor page.

## Razor Page Class

Here is the simple `cshtml` file that we are considering:
<script src="https://gist.github.com/MissaouiChedy/bd345b998c91668ccb44598a7e9bccee.js"></script>

The previous chtml view is compiled to the following C# code:
<script src="https://gist.github.com/MissaouiChedy/12b20245be6c4830963f612817954ad9.js"></script>

You will notice that the previous code listing was formatted, actually I removed all the [`#line`](https://msdn.microsoft.com/en-us/library/34dk387t.aspx) and [`#pragma`](https://msdn.microsoft.com/en-us/library/x74w198a.aspx) directives and I simplified the fully qualified class names, which makes for code that is less painful to read.

### Observations
After scanning the previous code we can make some observations:

First off, I did not know that it was possible to [put `using` statements inside a `namespace` scope](http://stackoverflow.com/questions/125319/should-using-statements-be-inside-or-outside-the-namespace) to include name spaces. Every day is a school day...

Then, The generated `_Views_Home_Index_cshtml` class inherits from the `RazorPage` abstract class parametrized with the `dynamic` type. Here the `dynamic` type is used because the view is **not** strongly typed.

`_Views_Home_Index_cshtml` overrides the `ExecuteAsync` method in which the template rendering logic is located.

Finally, some properties in the `_Views_Home_Index_cshtml` are set up to contain instances of Tag Helper related classes: `TagHelperExecutionContext`, `TagHelperRunner`, `TagHelperScopeManager` and `ImageTagHelper`.

## Diving in ExecuteAsync

We are going to focus on the tag helpers related objects, specifically on the following snippet(further tweaked for readability) extracted from the `ExecuteAsync` method:
<script src="https://gist.github.com/MissaouiChedy/544206a02ea7f4653f466504c1b771cf.js"></script>

## The TagHelperScopeManager Creates a TagHelperExecutionContext

The `TagHelperScopeManager.Begin` method returns a `TagHelperExecutionContext` after taking the following arguments:
- The name of the to be generated tag
- The mode of the to be generated tag (Open-close, self-closing...)
- A UniqueId string
- A [function object](https://msdn.microsoft.com/en-us/library/bb534960(v=vs.110).aspx) that executes any nested tag helpers

Looking inside the [`TagHelperScopeManager`](https://github.com/aspnet/Razor/blob/dev/src/Microsoft.AspNetCore.Razor.Runtime/Runtime/TagHelpers/TagHelperScopeManager.cs) class shows that it encapsulates a `TagHelperExecutionContext` instances pooling behavior which might be there to allow reuse of existing instances.

The responsibility of the scope manager through the `Begin` method is to perform checks on the arguments it gets passed, to create a dictionary object needed by the `TagHelperExecutionContext` and to delegate the instantiation of the `TagHelperExecutionContext` to the `ExecutionContextPool` private class.

By default, the scope manager creates a new items Dictionary object. But if it detects that a `parentExecutionContext` exists for the current scope it creates a `CopyOnWrite` dictionary that is initialized with the parent's item dictionary (`parentExecutionContext.Items`).

The arguments listed earlier along with the created items dictionary are passed to the `ExecutionContextPool` object that either returns a freshly created `TagHelperExecutionContext` or a reinitialized existing one.

The `TagHelperScopeManager.End` seems to be used in nested tag helpers scenarii, although not sure, it looks like it keeps track of levels of nesting.

So to make it short the scope manager creates a `TagHelperExecutionContext`.

## Tag Helper Execution Context

The `TagHelperExecutionContext` object is used to contain the created tag helpers and their attributes.

In our example, the `ExecuteAsync` method creates two tag helpers: the expected `ImageTagHelper` and a `UrlResolutionTagHelper`.

The creation of the `UrlResolutionTagHelper` is a bit strange, in our example we just made use of the `ImageTagHelper`. 

Here we must remember that tag helpers can be activated by [attribute](http://blog.techdominator.com/article/basic-tag-helpers-creation-cheat-sheet.html#Tag-helper-activated-by-attribute) and by [html element name](http://blog.techdominator.com/article/basic-tag-helpers-creation-cheat-sheet.html#Tag-helper-activated-on-standard-html-element). It turns out that the `UrlResolutionTagHelper` gets activated on the `img` html element, among others, in order to resolve relative assets path.

Both the `UrlResolutionTagHelper` and the `ImageTagHelper` as well as their html attributes are added to the `TagHelperExecutionContext` via the `Add`, `AddHtmlAttribute` and `AddTagHelperAttribute` methods.

The responsibility of the tag helper execution context is to hold the state related to multiple tag helpers that gets activated on the same html element.

The constructor of the `TagHelperExecutionContext` class accepts the following arguments:

- The name of the tag that is going to be generated 
- The mode of the tag that is going to be generated (Open-close, self-closing...)
- The Items dictionary created by the scope manager.
- The UniqueId string
- The [function object](https://msdn.microsoft.com/en-us/library/bb534960(v=vs.110).aspx) that executes any nested tag helpers
- The `startTagHelperWritingScope` callback
- The `endTagHelperWritingScope` callback

Then it creates a `TagHelperOutput` object and a `TagHelperContext` object which will be respectively assigned to the `Output` and `Context` public properties. All the elements needed to fulfill the previous instantiation are passed to `TagHelperExecutionContext`'s constructor.  

The previous instances will be necessary in order to call the `ProcessAsync` method on the tag helpers that needs to be rendered.

The two last arguments of the `TagHelperExecutionContext`: `startTagHelperWritingScope` and `endTagHelperWritingScope` are callbacks defined under the `RazorPageBase` class and are used in the `TagHelperExecutionContext.SetOutputContentAsync` which executes the nested tag helpers if any. The responsibility of these callbacks is not clear yet, some more on this next time.

## Rendering The Tag Helpers

After being populated the with the tag helpers objects and their attributes the `TagHelperExecutionContext` is passed to the `TagHelperRunner.RunAsync` method which performs the following actions:
1. Orders the tag helper objects contained in the context(recall the `TagHelper.Order` property)
2. Iterates over the ordered tag helpers and calls `TagHelper.Init` on them
3. Iterates over the ordered tag helpers and calls `ProcessAsync` on each one. The `TagHelperOutput` and `TagHelperContext` contained in the execution context are used.

The result of the processing is available in the `TagHelperExecutionContext.Output` property and is further written to the current page by the `RazorPage.Write`.

Looking inside the `Write` method shows that the `TagHelperOutput.WriteTo` is used to generate the final html content.

## Summary

The complexity introduced by the collaboration between the `TagHelperScopeManager`, `TagHelperExecutionContext` and `TagHelperRunner` is necessary to handle *multiple tag helpers activation on the same html element* as well as to manage *nested tag helpers processing*.

Nested tag helpers processing is still not clear and is going to be the subject of an upcoming post some day. 


 







 


