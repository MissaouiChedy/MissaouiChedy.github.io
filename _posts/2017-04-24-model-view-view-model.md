---
layout: post
title: "Model View View Model"
date: 2017-04-24
categories: article
comments: true
---

ASP.NET Core as a an MVC web framework defines and uses a lot of abstractions and concepts to help developers build quality web applications fast.

One good practice, when developing a complex web application is to keep the business logic in its own layer which is decoupled from "everything else".

In this post, we are going to discuss MVVM (model view view model) which is a way to bridge two powerful software design strategies: Model View Controller(MVC) and Domain Driven Design(DDD).

MVVM allows us to keep our domain layer free of all user interface concerns while it is used by the view layer. Let's first introduce MVC and DDD.


## Model View Controller


[HTTP](https://tools.ietf.org/html/rfc7540) is the protocol that describes how the world wide web works. Typically it involves a client(the web browser) sending requests for resources to a web server, the client expects then a response that contains the requested resource.

The resource can be static in which case it is usually served directly or it can be dynamic in which case some processing is made before serving the generated resource.

Serving dynamic resources is one of the capabilities that allows us to create interactive web applications.

This is usually achieved by configuring the web server to run a specific program (or script) when a specific resource is requested.
For most web applications, the program invoked reads data from the web request, performs some database queries and generates a response (usually html) before sending it back to the client.

The old approach was consisting in mixing business logic, database queries and html generation logic in the same program(or script).

The [Model View Controller](https://docs.microsoft.com/en-us/aspnet/core/mvc/overview#what-is-the-mvc-pattern) pattern allows us to organize the previously described behavior in a more manageable structure.

In an MVC web framework, requests to resources are directed to *controllers*. In ASP.NET Core, Controllers are CLR classes that contains methods called *actions*, these action methods contains the processing that needs to be done when a specific resource is requested. Each action method is mapped to the specific resource path that it is expected to generate.

Under the *action method* lies behavior that manipulates *model classes* which data are usually stored and fetched from a database (via a data access layer) and represents entities belonging to the problem domain. For example, in a HR application we can have entities that represents Employees, Candidates or Employing Organizations.

After manipulating the *model classes* the *action method* uses a *view templating engine* to render the html that is going to be returned to the client. ASP.NET Core ships with the Razor template engine which is able to generate html from `cshtml` views.

To sum it up, in an MVC Framework:
- Controller's actions implement the processing required to generate a resource
- View rendering logic is factored in `cshtml` views and in helper classes(more on this later)
- Model classes are used to contain data fetched from the data access layer and passed to the view engine.

This structure [along with some other framework features](https://docs.microsoft.com/en-us/aspnet/core/mvc/overview#features), allows us to effectively manage the complexity that arises when building modern web applications.

Model classes are not bound to be simple data holders. In fact, it is often considered good practice to factor business logic inside them and this is partially what Domain Driven Design is about.

## Domain Driven Design

I consider DDD to be a software design strategy in which the developer aims to build solid understanding of the problem domain in which the application being build is acting.

This solid understanding is then leveraged to build a software representation that implements the core features of the application and that is independent of *real world concerns*.

This software representation is the *domain layer* and the understanding is the *domain model*. *Real world concerns* include problems such as data access, user experience or monitoring.

The *domain layer* is focused on implementing core logic that captures the essence of the problem domain. For example, in a hypothetical fast food management application the *domain layer* would contain classes such as a `Menu`, `FoodItem` and `DrinkItem`. If we have some discount rules, we can factor the discount calculation in the `Menu` class.

The logic contained in the *domain layer* is so abstract that it only depends on:
 - fundamental types defined in the standard library(`List`, `string`)
 - abstractions that it defines

Furthermore, the *domain layer* never performs IO(network or file-system access) directly; its functions and methods are "numbers in/numbers out" which makes them easily unit testable.

This freedom of most concerns allows the developer to focus thoroughly on addressing domain problems by making the following feedback loop short:
1. Communicate with domain experts
2. Build understanding
3. Implement understanding in software
4. Show implementation to domain experts
5. Get feedback
6. Improve
7. Repeat

There are more patterns and techniques associated with DDD that can be found in the seminal [Domain Driven Design book by Eric Evans](https://www.amazon.com/Domain-Driven-Design-Tackling-Complexity-Software/dp/0321125215) that lays down a strategy that goes beyond just having a *domain layer*.

In the remainder of this section we are going to focus on two concepts that will help us grasp MVVM.

As pointed out previously, the *domain layer* will usually contain *domain entities* that represents entities from the problem domain.

In Object oriented languages, especially C# these entities are actual classes exposing properties and methods and that reference each other in meaningful ways. 

In DDD(and OOP in general), it is considered bad practice to separate structure and behavior. Usually, each entity in the domain layer is expected to encapsulate relevant behavior. 

For example, the fast food `Menu` class can be expected to contain an `Add` method , that allows to add `FoodItem`s and `DrinkItem`s, and a `Price` read-only property that calculates the prices of the menu by taking specific discounts into account.  

A *domain model* that has poor or no behavior is usually referred to as an [Anemic Domain Model](https://martinfowler.com/bliki/AnemicDomainModel.html) which is considered an anti-pattern. In my opinion, not factoring domain behavior in the *domain model* means pulling it to a separate layer that might not provide the independence needed to tackle hard domain problems. 

To sum it up, the first step when following the DDD strategy is to factor domain concepts in a domain layer which is decoupled from ideally all real world concerns. The domain layer contains rich domain objects (usually entities) that exposes useful properties and behaviors.

MVC allows developers to build web applications fast and DDD allows to build the core business functionalities fast.
Let's now see how both are used together.

## Putting MVC and DDD together: MVVM

As we mentioned previously, action methods in controllers manipulates domain entities fetched from the database before passing them to the view engine.

As you might know, the Razor view engine renders cshtml views to html content, cshtml allows to include arbitrary C# code along with html markup, as in the following example:

<script src="https://gist.github.com/MissaouiChedy/3bb23ebd41e54454f790e49c93fc5830.js"></script>

In the previous example, the `ViewData` dictionary is used pass data to the view engine and you can see how the `"Name"` and `"IsAdmin"` entries are used to display data. The `@{}` block at the beginning of listing contains C# code, we can define and populate variables inside it and use them subsequently in the cshtml view.

Relying exclusively on the `ViewData` dictionary to pass data to the view and including complex logic in it are bad practices that brings back the old approach discussed previously that consisted in mixing all view, domain and database logic into the same unit.

Fortunately, razor views can be strongly typed which means that they can take a typed object as an argument:

<script src="https://gist.github.com/MissaouiChedy/2a47082cd0b1b148cbc8aaaa61f3fc8b.js"></script>

In the previous example, you can see that the object passed exposes properties that are strongly typed which help us avoid some of the clutter associated with the `ViewData` dictionary.

The typed object passed to the view is called the **view model**, in addition to containing data that is going to be displayed the *view model* contains any view specific behavior and metadata. The arbitrary code sitting in the `@{}` in the `ViewData` example will be typically factored inside one or more methods in the *view model*.

Getting back to the controller's action method, it can seem convenient and appropriate to pass the *domain model*(domain entity) to the view. Unfortunately, this can lead to bloating the *domain model* with methods that handle view logic and with attributes that contains view specific metadata.

The MVVM strategy consists in creating at least one, possibly several, *view model(s)* for each *domain model* to encapsulate and contain view specific concerns such as: internationalization, model binding, view specific data representations(`SelectItemList` for instance) and data validation to name a few.

In some situations we can go as far as to creating a view model for each view, if it makes sense.

The *view model* essentially wraps the *domain model* and adds the view specific functionality, which allows us to keep the domain layer free of all UI concerns.

## Summary

A good approach to building modern web application is to use an MVC web framework such as ASP.NET Core and to leverage the MVC abstractions to manage the complexity of the web platform (request handling, session management, view rendering...).

The core domain functionality should be factored in separate layer free of all real world concerns in which domain problems can be more easily addressed.

The domain layer is then used by the MVC application to provide useful features to users of the application. One of the keys to keep domain layer purity is to wrap domain models with view models in UI specific code.

And this is what MVVM is about.

In upcoming posts, we are going to show some concrete MVVM examples and we will lay down some specifications that view models need to fulfill.