---
layout: post
title: "Discovering JavaScript ES6"
date: 2017-10-12
categories: article
comments: true
---

A while ago, I was prototyping around the idea of a [dynamic form tag helper](http://blog.techdominator.com/article/considering-an-asp.net-core-reactive-form-tag-helper.html) for ASP.NET Core. I heard back then that Angular 2 (now [Angular 4](https://angular.io)) have a feature called reactive forms (now [dynamic forms](https://angular.io/guide/dynamic-form)) which provides the capability to generate an html form with model binding and model validation from an annotated object.

Long story short, in order to play around with Angular 2 I had to get up to learn some [TypeScript.](https://www.typescriptlang.org/) I was glad to discover then a lot of interesting features such as [static typing, class based object-orientation, for-each loops, interpolated strings and encapsulation capabilities](https://www.typescriptlang.org/docs/home.html) to name a few.

This week, I started working on a new web application project built with [React](https://reactjs.org) and I noticed that [JavaScript ES6](http://es6-features.org/) is the preferred language version to work with React which led me to some fiddling...

## Most of TypeScript goodness is already in ES6

I was pleasantly surprised to discover that most of the TypeScript features where already available in ES6, in fact [TypeScript is a superset of JavaScript](https://stackoverflow.com/a/32370000). Feeding legit JavaScript code to the TypeScript compiler will make it produce correct output without problems.

I would like to highlight some of the features that were IMHO most needed.

### Class based Object Orientation

It is possible to define a classes as in C#:

<script src="https://gist.github.com/MissaouiChedy/7577390a8f17dbb066a12600fc9140e9.js"></script>

The previous class contains a constructor, fields , properties and methods.

You can see also that inheritance is now explicitly supported via the `extends` keyword.
This is a huge cognitive load saver especially for programmers coming from a C#, Java or C++ background.

### for each loops

Consider the following example:

<script src="https://gist.github.com/MissaouiChedy/9b156cc9e888d75e122fb35075a4f06d.js"></script>

Yes, indeed you can say goodbye to most of the classic `for loops` in JavaScript and say hello to the new `for-of` construct which eliminates the need to reason about counter initialization and boundary conditions.

### map, reduce and filter

Since I discovered functional programming and with the availability of LINQ in C#, I became addicted to the `map`, `reduce` and `filter` functions when working with lists, consider the following:

<script src="https://gist.github.com/MissaouiChedy/6dad126e1f6d16228d6d325d6d869aba.js"></script>

All of these functions are now available and as you can see in the previous example, ES6 supports the [arrow function syntax](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Functions/Arrow_functions) for specifying [anonymous functions](https://en.wikibooks.org/wiki/JavaScript/Anonymous_functions) (lambdas) in a more compact way. As in C# we can create [expression lambdas](http://es6-features.org/#ExpressionBodies) as well as [statement lambdas](http://es6-features.org/#StatementBodies).

### Small pattern matching support
Some pattern matching capability is now supported, consider the following:

<script src="https://gist.github.com/MissaouiChedy/cf39a7796ddaf0d794e5f854481ab955.js"></script>

In is now more easier to unpack complex structures such as objects and arrays with safe defaults.

I understand that this is far from the pattern matching capability of functional languages but it can be useful to have still.

## Small Issue with the module system
### Module system
The JavaScript ES6 specification defines a syntax for creating modules and importing public definitions such as classes, functions and constants among others.

By creating a file it is possible to define a module:

<script src="https://gist.github.com/MissaouiChedy/fa9ae3cd81a18a379b2886f4d3b2901b.js"></script>

Here the `export` keyword is used to mark a definition as public i.e. importable from another module. The `format` function is not exported and is there for considered private to the module.

In the file in which we wish to use definitions from `mylib`, we use the `import` keyword to make the needed definitions available:

<script src="https://gist.github.com/MissaouiChedy/ffa19b441a3d62054b2232e6591fff0f.js"></script>

As you can see from the previous example, we can import specific definitions or we can use a wild card to import all the public definitions.

### Issue

Unfortunately, at the time of this writing [Node JS](https://nodejs.org) as well as all the modern browsers does not support the ES6 module syntax.

One way to use the syntax on the server side with Node is to rely on a compiler such as [Babel](https://babeljs.io/) which will generate code using the [CommonJs](http://requirejs.org/docs/commonjs.html) syntax supported by Node.

A similar approach is possible on the client side but it will require the use of [require.js.](http://requirejs.org/)

Checkout this [article by James M Snell](https://medium.com/the-node-js-collection/an-update-on-es6-modules-in-node-js-42c958b890c) for more details.

## Closing thoughts

I am looking forward to play around with [JavaScript ES7](https://www.ecma-international.org/ecma-262/7.0/) and its "main eventer" feature `async/await.` 

These new specifications are upping the value of JavaScript and are confirming it as a universal language that can be used to build an extended range of applications.

The new JavaScript along with modern frameworks such as React and Angular are making web front-end development more pleasant and appealing.

