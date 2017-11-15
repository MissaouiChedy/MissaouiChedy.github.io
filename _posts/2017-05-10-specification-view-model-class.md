---
layout: post
title: "specification for an input/output view model class"
date: 2017-05-10
categories: article
comments: true
---
**UPDATE,** 15 Nov2017 &mdash; *Thanks to [Magick's](https://disqus.com/by/disqus_QtZAMoouIE) comment we have been able to make the specification more consistent, please checkout the updated "6.Provide a way to get a domain model instance populated with the data from the view model" point*

<hr/>

In a [previous post]({{ site.url }}/article/model-view-view-model.html), we talked about the MVVM pattern which aims to build a wrapper around a domain model class adding view specific behavior.

It is usually considered good practice to [create separate input and output view models](https://maxtoroq.github.io/2012/07/patterns-for-aspnet-mvc-plugins-viewmodels.htmls): 

- Input view models are typically used for form pages; they can contain form specific metadata (for [data validation](https://docs.microsoft.com/en-us/aspnet/core/mvc/models/validation) and [model binding](https://docs.microsoft.com/en-us/aspnet/core/mvc/models/model-binding)) and will be populated with the data present in the form when it gets submitted.
- Output view models are used to display data, they can contain, for example, helper methods that takes care of proper data formatting.

In this post, we are going to define a specification for a general purpose view model class which can be used for both input and output. I don't have enough experience with special purpose view models yet, so maybe we will elaborate on them in a future post.

## the specification

The view model class should fulfill the following requirements:

1.	[Expose the public properties of the domain model to client code](#spec1)
2.	[Provides a constructor that takes a domain model as its argument](#spec2) 
3.	[Contain view specific code(data and behavior)](#spec3)
4.	[Provide access to domain model methods](#spec4)
5.	[Automatically apply attributes on properties from the domain model on the properties of the view model](#spec5)
6.	[Provide a way to get a domain model instance populated with the data from the view model](#spec6)
7.	[Provide access to the view model version of nested entities and collections](#spec7)
8.	[Hides domain model versions of nested properties](#spec8)

Let's elaborate on these points.

<h2 id="spec1">exposing public properties of the domain model</h2>

The view model class should expose the public and simply typed properties of the domain model class, consider the following:

<script src="https://gist.github.com/MissaouiChedy/d691a69db41237c3497149156f3b2173.js"></script>

The `Person` class defines two simple properties `Id` and `Name`, according to the spec `PersonViewModel` is expected to provide access to these properties. Very straightforward.

<h2 id="spec2">providing a constructor that accepts a domain model</h2>

The view model class should provide a constructor that accepts an instance of the corresponding domain model. The provided instance is used to initialize the corresponding properties and will be typically used as a back-end for the domain model method calls.

Example:
<script src="https://gist.github.com/MissaouiChedy/f3e0ed27ac6a3489d067ff80549e5516.js"></script>
<h2 id="spec3">containing view specific code</h2>

Obviously, the responsibility of the view model class is to address any view specific concern by keeping it outside the domain model that it wraps, consider the following classes:

<script src="https://gist.github.com/MissaouiChedy/d7bc3dc67214ccb2a33e032a28fe70e4.js"></script>

The `[Display]` attribute is slapped on the `PersonViewModel.Name` property, this attribute provides to the view engine the label that should be displayed for the `Name` field. This view specific metadata attribute is kept out of the `Person` domain model class.

The `PersonViewModel.GetCapitalizedName` is a helper method that is going to be used by the view engine; encapsulated behavior for the view engine should be placed in the view model class. 

<h2 id="spec4">providing access to domain model methods</h2>

Domain model methods should be available on the view model and should behave as expected when called, the view model class as to implement some mechanism to ensure this.

<script src="https://gist.github.com/MissaouiChedy/c753664ade0e2bdd4dadedfcd845ccc0.js"></script>

The `IsPayingCustomer` method in the previous example, when called from a `PersonViewModel` instance should behave as if it was called from the corresponding `Person` instance.

<h2 id="spec5">applying attributes from the domain model</h2>

Attributes slapped on the properties of the domain model should be slapped as well on the equivalent properties on the view model. 

Attributes are sometimes used to indicate data constraints and some data constraints are domain specific and should consequently be factored in the domain layer.

These attributes need to be taken into account in the view model class, consider the following:

<script src="https://gist.github.com/MissaouiChedy/51e35063b1faeb4fcf90b12d1b1bae7f.js"></script>

The `[MaxLength]` attribute is slapped on the `Person.Name` property to limit the length of the person's name to 50 characters.

The `PersonViewModel` class should make sure to apply this attribute to the corresponding property, it can statically duplicate the attribute on top of the property or preferably implement a mechanism that applies dynamically the attribute from a domain model instance. 

<h2 id="spec6">providing a way to get a populated domain model instance</h2>

The view model class should provide a readable property or a method that returns a domain model instance that is populated with the data present in the view model instance, example:

<script src="https://gist.github.com/MissaouiChedy/dbc03af3c4fb31dd8ab9f4d90f4aa092.js"></script>

If you take a look at the usage near the end of the listing, you can see that mutations on the view model should be available in the domain model instance retrieved from the view model.

The `DomainModel` read-only property can (perhaps should) return **a copy** of the `DomainModel` object encapsulated in the view model and not a reference to it in order to prevent outside mutations of the encapsulated `DomainModel` object. Checkout the usage at the end of the listing.

<h2 id="spec7">providing access to view model incarnations of nested complex types and collections</h2>

Entity classes from the domain model can have properties that are themselves other entities or collection of other entities, consider the following example:

<script src="https://gist.github.com/MissaouiChedy/4dbb75bd2e691d92acbc43c2dff6733a.js"></script>

The `Person` class has an `OwnedCar` property of type `Car` and `Skills` property of type `List<Skill>`. For the `Car` and `Skill` entities we have defined corresponding view model classes `CarViewModel` and `SkillViewModel`.

The `PersonViewModel` class should provide access to the view model version of the `OwnedCar` and `Skills` properties, as in the following example:

<script src="https://gist.github.com/MissaouiChedy/f972a319acd51b74a154d4337bbae1e3.js"></script>

The view model class as to make sure that these properties are correctly initialized from the provided domain model instance.

<h2 id="spec8">hiding domain model versions of nested entities</h2>

Finally, the domain model versions of the nested entities as we saw in the previous section should be hidden in the view model class.

Using the previous `PersonViewModel` definition it should not be possible to perform the following:

<script src="https://gist.github.com/MissaouiChedy/9715f78fdf676b76d58b2601b151d98d.js"></script>

<span class="no-outline"><span>

