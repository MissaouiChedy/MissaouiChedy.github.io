---
layout: post
title: "Considering an Asp.Net Core Reactive Form Tag Helper"
date: 2017-02-25
categories: article
comments: true
---

Building forms is one of the aspects of web development that is challenging me the most. It took me actually some time to figure out all the elements involved: posting form data, server side validation, client side validation, model binding, anti-forgery tokens and maybe some other parts that I am not aware of.   

I always had the impression that building forms is a repetitive task, but when I first sought to automate it I realized that care must be taken for several details.

Recently I've been prototyping around the idea of creating a tag helper that acts like [Angular 2's dynamic forms](https://angular.io/docs/ts/latest/cookbook/dynamic-form.html).
## Objective
The idea is to create a tag helper that will be usable as in the following example:
<script src="https://gist.github.com/MissaouiChedy/490d3aecd85594fe6ebd30be2bca1603.js"></script>

The `<reactive-form>` tag helper inspects the properties under the `@Model` object and will leverage their metadata (type information, attributes applied ...) to generate an html form with client side validation that correctly sends data to the target `asp-action`.

### Overrideability

The `<reactive-form>` tag helper must allow the developer to override its default generation behavior possibly by applying customization attributes to the model class or more interestingly by directly specifying the desired changes inside the content of the `<reactive-form>` tag helper:

<script src="https://gist.github.com/MissaouiChedy/c92b76f04c509e9689e8688964c89459.js"></script>

In the previous example the nested `<override>` tag helper is used twice to respectively add a css class to the `<input>` generated for the `Name` property and disables the generation of a form control for the `Age` property.

## Benefits and Drawbacks

It will be sufficient to create and annotate(with attributes) a C# view model class and its properties to get a working form.

The main benefit that the `<reactive-form>` tag helper can provide is a serious decrease of the amount of time needed to create a working form for the developers that will be familiar with its use.

Which brings us to the main drawback i.e. the learning curve. A well designed `<reactive-form>` tag helper will be, as mentioned previously, customizable.

Most of the developers will need to customize the default behavior and they will have to learn how to.

## Implementation challenges

I am foreseeing a lot of challenges in the making of such a tag helper:
- How to create a comprehensible a default behavior overriding strategy?
- How to handle concerns such as styling and internationalization?
- How to handle multi step forms?
- How to handle custom form controls(which might be tag helpers, view components or legacy html helpers)?
- How to handle custom client side validation?

## What's next?

In an [upcoming post](http://blog.techdominator.com/article/first-dynamic-form-tag-helper-attempt.html), I will report my first attempt at building the `<reactive-form>` tag helper. Stay tuned <i class="fa fa-smile-o" aria-hidden="true"></i>.

 






