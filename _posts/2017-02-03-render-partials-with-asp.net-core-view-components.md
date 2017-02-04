---
layout: post
title: "Render partials with ASP.net Core View Components"
date: 2017-02-03
categories: article
comments: true
---
[In a previous post]({{ site.url }}/article/using-html-helper-inside-tag-helpers.html), I showed how it is possible to render a *cshtml template* inside a *Tag Helper* and I mentioned that there is a better mechanism available in asp.net core which is [Razor View Component](https://docs.microsoft.com/en-us/aspnet/core/mvc/views/view-components).

The ViewComponent facility allows to render a 'partial' cshtml template inside another cshtml view.

In this post I am going to summarize the key points regarding the creation and usage of View Components.

*As usual full code is in [Github](https://github.com/MissaouiChedy/RazorViewComponents).*

## Using a View Component
View components are typically invoked by awaiting the result of the `Component.InvokeAsync` method.

<script src="https://gist.github.com/MissaouiChedy/c5c5a256e036acfb97d04eeafbf7a6ac.js"></script>

It is possible to pass data to the view component via an anonymously typed object.

Starting from asp.net core 1.1 it is possible to use View Components with a tag helper like syntax:
<script src="https://gist.github.com/MissaouiChedy/e9bc15061add30db3a5c1e6ebcc974e4.js"></script>

Notice how the previous example feels more consistent with the html syntax. Also the 'html tag' needs to be prefixed with `vc:` and don't forget to import the tag helpers under `~/Views/_ViewImports`.


## Creating a View Component
A view component is usually made of two elements: a *C# class* and a *cshtml view*.
### View Component class
The C# class must be conform to one of these criteria to be considered a *ViewComponent*:
- Inherit from the `Microsoft.AspNetCore.Mvc.ViewComponent`
- Be slapped with the `[ViewComponent]` attribute
- Inherit from a class that is slapped with the `[ViewComponent]` attribute
- Its name is suffixed by 'ViewComponent'

Inheriting from the `Microsoft.AspNetCore.Mvc.ViewComponent` class is the most convenient approach IMHO since it makes available protected properties such as a ready to use `ViewData` dictionary and methods such as `View`.

The class must then implement the `InvokeAsync` (or its synchronous counterpart `Invoke`), here is an example:
<script src="https://gist.github.com/MissaouiChedy/c50d1921fda968c805f314458f377d5a.js"></script>

The `Invoke` method takes two arguments that are going to be mapped to the properties of the anonymously typed object that is passed to `Component.InvokeAsync`.

### View Component cshtml view

The primary cshtml view that is going to be rendered by the *ViewComponent* class is usually placed under the `~/Views/Shared/Components/<ComponentName_WithoutViewComponentSuffix>` folder and is named `Default.cshtml`. 

Following the previous file placing conventions allows the `View` method to fetch the view file without requiring from the developer to specify the template path.

View Components views are rendered in the same fashion as regular top level views in controller's actions, it is possible to pass data to the view by using a *model object* (when the view is strongly typed) or by using the `ViewData` dictionary or its expando object facade the `ViewBag`.

In fact the *ViewComponent* class can be considered a mini controller that renders a partial views.

<script src="https://gist.github.com/MissaouiChedy/e2b4a86af953d5c992f5737ea6168db4.js"></script>

The previous cshtml view accesses data available in the view model passed to it as well as data in the `ViewData` dictionary.

## Why View Components?
View components offer a way to render cshtml partial views by leveraging the power of razor and offers an alternative to the deprecated Html Helper facility.

Tag helpers on the other hand allows to build html content and to manipulate html existing content with an imperative approach that can be painful when building complex views.

Nonetheless, the Tag Helper facility offers the ability to create parent-child relationships between tag helpers which allows some nesting behavior:
<script src="https://gist.github.com/MissaouiChedy/c6e83770c830f309d6a6c9f3be182d64.js"></script>

The previous is currently **not** feasible with View Components and is going to be the subject of the next post.



