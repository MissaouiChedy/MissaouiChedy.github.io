---
layout: post
title: "The Circuit Breaker Pattern Part 3 - Elixir implementation"
date: 2017-09-27
categories: article
comments: true
---

In previous posts, we discussed the *Circuit Breaker* design pattern and we made a simple C# implementation.

This will be the last post in our circuit breaker series and we will discuss an Elixir/OTP implementation available in this [Github repository.](https://github.com/MissaouiChedy/circuit_breaker)


## High level structure

In this example, we have a very simple OTP application that uses [Wikipedia's api:](https://www.mediawiki.org/wiki/API:Main_page)

<div class="img-container">
![High level structure elixir circuit breaker]({{ site.url }}/imgs/ElixirCircuitBreakerHighLevel.PNG)
</div>

For the sake of simplicity the application performs a single operation which getting extracts from articles having the titles *"Earth"* or *"Mar"* via the this url: `https://en.wikipedia.org/w/api.php?action=query&prop=extracts&exchars=100&explaintext&titles=Earth|Mar&continue&format=json` which, by the way, is not very [RESTful](http://www.restapitutorial.com/lessons/whatisrest.html).

When invoking the `CircuitBreaker.main` function the application will perform multiple successive queries with some delay between each one(800ms).

Executing the `main` function will produce the following output when the Wikipedia API is available and reachable:

```
iex(1)> CircuitBreaker.main
{:ok,
 %{"53393174" => %{"ns" => 0, "pageid" => 53393174, "title" => "Mar"},
   "9228" => %{"extract" => "Earth is the third planet from the Sun...",
     "ns" => 0, "pageid" => 9228, "title" => "Earth"}}}
```

By disabling the internet connection on the machine, you will start to see timeout and [non existing domain](https://www.dnsknowledge.com/whatis/nxdomain-non-existent-domain-2/) errors:

```
{:error, :timeout}
{:error, :nxdomain}
{:error, :nxdomain}
{:error, :nxdomain}
{:error, :nxdomain}
```

When the error limit is reached the circuit transitions to the *open* state:

```
{:error, :circuit_open}
```

Finally, when re-enabling the internet connection the circuit will transition back to *closed* at some point:

```
{:error, :circuit_open}
{:error, :circuit_open}
{:ok,
 %{"53393174" => %{"ns" => 0, "pageid" => 53393174, "title" => "Mar"},
   "9228" => %{"extract" => "Earth is the third planet from the Sun...",
     "ns" => 0, "pageid" => 9228, "title" => "Earth"}}}
```


## Deeper level structure
Consider the following module structure diagram:

<div class="img-container">
![module structure circuit breaker]({{ site.url }}/imgs/ModuleStructureCircuitBreaker.PNG)
</div>

The top level `CircuitBreaker` module contains the main function which runs the example:

<script src="https://gist.github.com/MissaouiChedy/3ab799584ad7fec7ad863005ab331e69.js"></script>

The `CircuitBreaker.ApiGateway` module acts as a gateway to the Wikipedia api and provides essentially a single fetching operation:

<script src="https://gist.github.com/MissaouiChedy/209e330c0d0d8d42676a54c9f81c66a0.js"></script>

Here we used the [HTTPoison](https://github.com/edgurgel/httpoison) library to perform http requests.

### Circuit breaker API Gateway

We know that a *Circuit Breaker* is essentially a state machine that executes one operation differently depending on its state, here is the state machine diagram representing the states and transitions characterizing a *Circuit Breaker:*

<div class="img-container">
![Circuit Breaker States]({{ site.url }}/imgs/CircuitBreakerStates.PNG)
</div>

The `CircuitBreaker.ApiGatewayCircuitBreaker` is implemented as [gen_statem]({{ site.url }}/article/implementing-state-machine-elixir.html) which is an OTP behavior that allow us to create state machines.

When using `gen_statem`, a single module can be sufficient to implement the state machine. This requires way less moving parts than the C# implementation in which we had to create a class for each state by following the *State Design pattern.*

Consider the following snippet:

<script src="https://gist.github.com/MissaouiChedy/be74dadf682d85ea1b1dceda0017629d.js"></script>

States are modeled as function, for each state we define multiple functions that matches each call that we need to handle for that state.

Then, all we have to do is to use `:gen_statem.call` or `:gen_statem.cast` to execute the desired operation. The `gen_statem` module takes care of calling the right state function for the right operation.



## Closing thoughts

Bu using the `gen_statem` behavior I realized that it is much more convenient than the *State Pattern* for implementing state machines.

As we mentioned in the [C# example's post]({{ site.url }}/article/circuit-breaker-pattern-part-2-csharp-implementation.html), more sophisticated actions can be implemented when the circuit is open and we can base the circuit opening on more advanced statistical measures that simply counting errors.

Finally, I would like you to checkout the [fuse](https://github.com/jlouis/fuse) Erlang library that allows you to create ETS table based circuit breaker. According to its maintainer and creator [it is highly reliable and rigorously tested](https://www.youtube.com/watch?v=vsiNx2ttqtg&t=17m6s), so check it out.   
