---
layout: post
title: "the circuit breaker pattern <br/> part 1 - basic principle"
date: 2017-08-24
categories: article
comments: true
---

I first encountered the *Circuit Breaker* design pattern in the excellent [Release it!](https://pragprog.com/book/mnee/release-it) book, in which it is described as way to build stability in a back-end system.

Since I am currently building a back-end service for an actual mobile application, I decided to play around with the concept in C# and Elixir.

This is going to be 3 part post, in this part we are going to discuss the basic principle as well as the potential benefits of using a *Circuit Breaker*.

## Motivation

Let's consider a web service deployed in a production environment fulfilling requests via a REST API. This service depends upon a database that is deployed on a different node.

The database system can become unavailable for various reasons; network congestion, network partition, database crash you name it...

In order to ensure the stability of the web service we should handle most of the error conditions, some of the error conditions can be related to the unavailability of the database service.

Unavailability error conditions can be for example *timeout errors* indicating that a system is unreachable or *access violation errors* eventually indicating a bad configuration issue.  

These unavailability error conditions can be transient i.e. spanning to at most a couple of requests but sometimes they might last for a considerable amount of time(here considerable depends on the situation).

For example, suppose that the database is under a heavy load and that its response time is decreased enough to cause timeout errors on the web service side.

Instead of shedding more load on the database, it would be nice if the web server did the following:
 - embrace the fact that the database will not respond in a certain time span
 - do something more useful than shedding more load and getting errors

Something more useful can be for example:
- returning a stale yet available cached piece of data
- notifying the client service or user that the system is temporarily unavailable
- buffering data writes for later flush in the database

The circuit breaker pattern allows us to structure the integration point cleanly when implementing the previously described behavior.

## Structure and behavior

Let's consider the following structure:

<div class="img-container">
![Circuit Breaker Structure]({{ site.url }}/imgs/CircuitBreakerStructure.PNG)
</div>

Here we have a `Repository` and a `CircuitBreaker` class;
the `CircuitBreaker` class extends the `Repository` class and adds the *circuit breaking behavior*.  

`CircuitBreaker` objects are stateful and respond differently depending on their state.

Consider the following state diagram:

<div class="img-container">
![Circuit Breaker States]({{ site.url }}/imgs/CircuitBreakerStates.PNG)
</div>

Here we can see that the circuit breaker can be in 3 different states:
- `Closed` which is the initial "healthy" state
- `Open` in which the `CircuitBreaker` always indicates to client code that the *circuit is open*
- `HalfOpen` which is an intermediary state between `Open` and `Closed`

`CircuitBreaker` objects respond to requests normally when in `Closed` state. At same time they keep track of the occurring errors (by counting or occurrence frequency calculation), when a predefined error limit is reached the object transitions to the `Open` state.

When entering the `Open` state, a transition to the `HalfOpen` state can be scheduled to occur after a certain amount of time. When in this state any call to the methods of the `CircuitBreaker` will throw an exception indicating that the service is temporarily unavailable.

When in the `HalfOpen` state the `CircuitBreaker` tries to execute the first requested operation(method call). If it succeeds, then the `CircuitBreaker` is switched to `Closed` otherwise it is switched back to `Open`.

## Benefit

The main benefit from using a *circuit breaker* in an integration point is, as we pointed out previously, to acknowledge the fact that the external service will be unavailable for some time and to try to do something useful while it is down.

This allows to improve the stability of the system by assuming that any external service will fail.

## closing thoughts

I have heard countless stories about how the Netflix folks builds and operate their services while targeting very high availability goals.

I invite you to checkout [this post](https://medium.com/netflix-techblog/fault-tolerance-in-a-high-volume-distributed-system-91ab4faae74a) to get a sense of how resiliency can be build in software services.

Also checkout [this post](https://martinfowler.com/bliki/CircuitBreaker.html) by Martin Fowler about the *circuit breaker pattern*.
Finally, in the upcoming part we will see an example of a circuit breaker in C# application using a [MongoDB](https://docs.mongodb.com/) database service. 

