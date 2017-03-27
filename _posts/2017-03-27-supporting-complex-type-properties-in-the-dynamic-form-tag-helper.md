---
layout: post
title: "Supporting Complex Type Properties in The Dynamic Form Tag Helper"
date: 2017-03-27
categories: article
comments: true
---

This post builds on the [First Dynamic Form Tag Helper Attempt](http://blog.techdominator.com/article/first-dynamic-form-tag-helper-attempt.html). This time we are going to introduce small complex typed properties support.

The current version of the [dynamic form tag helper](https://github.com/MissaouiChedy/DynamicFormTagHelper/tree/first_attempt) is able to iterate over a view model object's properties and to generate a form group for each simple property. Each form group contains a `label`, an `input` and a validation message `span`.

Often times, view model classes contains properties that belongs to user defined types (classes).We refer to this properties as complex properties.

## Complex Properties in View Models

Complex types are usually user defined classes that can contain properties belonging to a simple type or to another complex type.

For example, consider the following view model classes:
<script src="https://gist.github.com/MissaouiChedy/bf4de4cb7166270b84a0575c9355539b.js"></script>

The `PersonViewModel` class contains the `OwnedDog` property which belongs to the `DogViewModel` class. Here `OwnedDog` is a complex typed property since `DogViewModel` is a user defined class.

The dynamic form tag helper needs to take in consideration such properties in order to generate validatable and bindable form controls for the simple properties contained inside complex properties.

Our dynamic tag helper needs to generate the following form, when given an object of the previous `PersonViewModel` class:

<div class="img-container">
![Complex Property Form]({{ site.url }}/imgs/ComplexProperty.PNG)
</div>

Before we continue, I would like to point out that my current definition of complex types is sloppy, what about generic, iterable, enum and struct types? Are they also consider complex? This is not very clear yet.

In the interest of brevity we are going to stick with this definition. I hope I will refined it as I explore more stuff.

Please take a look at the `IsSimpleType` method under the [`FormGroupBuilder`](https://github.com/MissaouiChedy/DynamicFormTagHelper/blob/master/TagHelpers/FormGroupBuilder.cs#L130) class for the actual details.

## Implementing Complex Property Support

The strategy for generating form groups for complex properties is simple(no pun intended).

We need to iterate over each of the root model properties, if the property is simple, we call the `_getFormGroupForSimpleProperty` method and if the property is complex, we call `_getFormGroupForComplexProperty`. This is done under the top level and public `FormGroupBuilder.GetFormGroup` method:
<script src="https://gist.github.com/MissaouiChedy/19753a94d7d3f7865186bab07c3615b9.js"></script>

The `_getFormGroupForComplexProperty` method iterates over the properties nested inside the complex property and calls the top level `GetFormGroup` method:

<script src="https://gist.github.com/MissaouiChedy/77f9488e60987e5cb5028f4e41f74ac9.js"></script>

Here we use recursion (`GetFormGroup` calls itself through `_getFormGroupForComplexProperty`) to attain simple properties buried under arbitrary levels of nesting.

This was sufficient to generate the form groups, the problem is that they are not validatable and bindable yet.

## Setting Property Names Properly When Creating ModelExpressions

The `FormGroupBuilder` class instantiates `label`, `input` and validation `span` tag helpers. All of these tag helpers needs a ModelExpression object containing metadata necessary to properly initialize the tag helpers.

Consider the following piece of code:

```
TagHelper input = new InputTagHelper(generator)
{
    For = new ModelExpression(property.Metadata.PropertyName, property),
    ...
};
```
Here we pass the property name as available under `Metadata`. It turns out that the first argument of the `ModelExpression` constructor is used to set the `name` html attribute on the generated `input` element. Setting the `name` html attribute is critical since [server side validation and model binding relies on it](https://docs.microsoft.com/en-us/aspnet/core/mvc/models/model-binding#how-model-binding-works) to properly create the model object from POST request parameters.

This means that we need to make sure that the passed property name is fully qualified with respect to the root model object.

Going back to the Person and Dog example, when building the `ModelExpression` when creating an `InputTagHelper` for the `Name` property under the `DogViewModel` class we need to supply the following name: `OwnedDog.Name`.

`property.Metadata.PropertyName` as in the previous piece of code returns simply `Name`.

That is why I introduced the following method to handle fully qualified property name building:

<script src="https://gist.github.com/MissaouiChedy/180f2b59d7935e63bd8b6b7e3a72438e.js"></script>

## Conclusion

In the [DynamicFormTagHelper](https://github.com/MissaouiChedy/DynamicFormTagHelper) Github repository, you will find the full code that contains an example with 2 levels of complex property nesting that generates the following form:
<div class="img-container">
![Multiple nested Property Form]({{ site.url }}/imgs/MultipleNestedProperties.gif)
</div>

Try submitting the form with valid and invalid values, you will see that model binding and validation both work.

In an upcoming post we will focus on the case of generic or iterable properties.



