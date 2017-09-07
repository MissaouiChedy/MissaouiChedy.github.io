---
layout: post
title: "The Circuit Breaker Pattern Part 2 - C# implementation"
date: 2017-09-07
categories: article
comments: true
---

In a [previous post]({{ site.url }}/article/circuit-breaker-pattern-part-1-basic-principle.html), we presented the *Circuit Breaker* design pattern and discussed it usefulness in building stable back-end services.

In this post, we are going to take a look at an example .NET Core implementation of the pattern that you can find in this [Github repository](https://github.com/MissaouiChedy/CircuitBreakerSample). 

## High Level Structure and Behavior

In this example, we have a .NET Core console application that uses a MongoDB database instance, a very simple structure:

<div class="img-container">
![Example structure]({{ site.url }}/imgs/CBCSExampleStrucuture.PNG)
</div>

The console app asks the MongoDB instance to perform two operations:

 - Writing a single `Person` document in the `persons` collection
 - Reading all `Person` documents from the `persons` collection

`Person` is a very simple C# class, here is its definition:

<script src="https://gist.github.com/MissaouiChedy/d3053ac2615c908560ef95987769fed3.js"></script>

When executed the console app will perform 100 sequential operations, in each iteration the program randomly selects one of the two previously described operations(`read` or `write`).

Executing the program with a running database instance produces output similar to the following:

```
Written: { Id: 3, Name: 'Baby Roy 3'}

Read => { Id: 3, Name: 'Baby Roy 3'}

Read => { Id: 3, Name: 'Baby Roy 3'}

Read => { Id: 3, Name: 'Baby Roy 3'}

Written: { Id: 7, Name: 'Baby Roy 7'}

Written: { Id: 8, Name: 'Baby Roy 8'}

Written: { Id: 9, Name: 'Baby Roy 9'}

Written: { Id: 10, Name: 'Baby Roy 10'}
```

By killing the database instance you will start seeing timeout errors as follows:

```
MongoDB.Driver.MongoCommandException: Command find failed: interrupted at shutdown.

MongoDB.Driver.MongoConnectionException: An exception occurred while
sending a message to the server.

System.TimeoutException: A timeout occured after 2000ms selecting a server

...

```

When `Config.CircuitClosedErrorLimit` is reached the circuit gets opened:

```
CircuitBreakerSample.Exceptions.CircuitOpenException: 

Exception of type 'CircuitBreakerSample.Exceptions.CircuitOpenException' was thrown.

```

Finally, starting back the database instance will cause the circuit to close at some point:

```
CircuitBreakerSample.Exceptions.CircuitOpenException: 
Exception of type 'CircuitBreakerSample.Exceptions.CircuitOpenException' was thrown.

Read => { Id: 8, Name: 'Baby Roy 8'}, ...

Written: { Id: 41, Name: 'Baby Roy 41'}

...

```

## Deeper Level Structure

The following class diagram depicts the internal structure of the console application:

<div class="img-container">
![example uml class diagram]({{ site.url }}/imgs/CBUMLClassDiagram.png)
</div>
The [`Program`](https://github.com/MissaouiChedy/CircuitBreakerSample/blob/master/src/Program.cs)class contains the `Main` method which is the entry point of the application, this is where we implemented the previously described behavior.

The `DatabaseConnectionFactory` is responsible for creating and returning a `MongoClient` instance that is going to be used by the `MongoPersonRepository` to issue requests to the database instance.

The `MongoPersonRepository` implements the `IPersonRepository` interface and is the actual gateway to the external MongoDB instance, as you can see in the following this class is not used directly by `Program.Main`:

<script src="https://gist.github.com/MissaouiChedy/7d8dc024e63c359daf0e187774cf8587.js"></script>

Instead we use the *circuit breaker* version `CircuitBreakerRepository` which implements the same `IPersonRepository` and which wraps the `MongoPersonRepository` to add circuit breaking features.

Now let's take a closer look at it.

### The Circuit Breaker repository

In the [basic principles post]({{ site.url }}/article/circuit-breaker-pattern-part-1-basic-principle.html), we mentioned that the circuit breaker is a state machine that has 3 states with defined transitions:

<div class="img-container">
![Circuit Breaker States]({{ site.url }}/imgs/CircuitBreakerStates.PNG)
</div>

Essentially, state machine objects execute different behaviors depending on their state, this can be implemented by using nested `if` or `switch` statements, by using a [decision table](https://en.wikipedia.org/wiki/Decision_table) or by using *the state design pattern*.

In this example, the `CircuitBreakerRepository` defines a class hierarchy that is useful for handling state specific behavior and state transitions.

The `CircuitBreakerState` abstract class represents a state handler and have three concrete sub-classes:
- `CircuitBreakerClosed` which handles the closed state
- `CircuitBreakerOpen` which handles the open state
- `CircuitBreakerHalfOpen` which handles the half open state

The *state pattern* allows us to factor state machine code very neatly, to learn more about it you can checkout the following:
- The state design pattern chapter in [Design Patterns: Elements of Reusable Object-Oriented Software](https://www.amazon.com/Design-Patterns-Elements-Reusable-Object-Oriented/dp/0201633612)
- The state diagram chapter in [UML Distilled](https://martinfowler.com/books/uml.html)
- [This link](http://www.dofactory.com/net/state-design-pattern)


## Closing Thoughts

This example is a very basic and simple implementation, it is possible to implement more sophisticated behaviors such as:
- Saving documents in a caching layer in `CircuitBreakerOpen.Write` and making sure that they are written when transitioning to the closed state
- Opening the circuit when high latency is detected
- Basing the error limit on a robust statistical measure rather than simple error counting (error frequency for example)

These are left as an exercise to the reader <i class="fa fa-smile-o" aria-hidden="true"></i>

