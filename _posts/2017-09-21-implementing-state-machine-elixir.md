---
layout: post
title: "Implementing a state machine in elixir"
date: 2017-09-21
categories: article
comments: true
---

Recently, I was experimenting with a [circuit breaker]({{ site.url }}/article/circuit-breaker-pattern-part-1-basic-principle.html) implementation in elixir and I naturally came across the need to implement a state machine.

I was aware of the [generic finite state machine OTP behavior](http://erlang.org/doc/man/gen_fsm.html) and while searching for details about it, I discovered that [OTP 19](https://www.erlang.org/news/tag/OTP-19) introduced the new [`gen_statem`](http://erlang.org/doc/man/gen_statem.html) behavior as an improved way to implement state machines in [Erlang/Elixir]({{ site.url }}/article/elixir-erlang-platform.html).

In this post, we are going to see a sample implementation of a state machine representing a human's mood by using `gen_statem`. The full example is available on [Github](https://github.com/MissaouiChedy/new_gen_statem).

## Human state machine

In our example, we have a state machine representing a human being that provides 4 operations:

- `say_hello` will cause the (hypothetical)human to respond with a greeting message
- `praise` allows to impact the mood of the human positively
- `insult` allows to impact the mood of the human negatively
- `reset` allows to reset the human's state

The human can be in one of 3 different states at a given time, consider the following state diagram:

<div class="img-container">
![human state machine]({{ site.url }}/imgs/HumanStateMachine.PNG)
</div>

The greeting message returned by `say_hello` will depend on the human's state of mind, we can expect them to answer cheerfully when `Happy` and grumpily when `Angry.` 

The `praise` and `insult` operations allows to change the mood of the human who maintains a count of all praises and insults received. When the `praises` count is greater that the `insults` count the human transitions to `happy`, the inverse makes them transition to `angry` , finally equal `praises` and `insults` brings back the human to a `neutral state.`

## Using gen_statem

[jadlr's github gist](https://gist.github.com/jadlr/7ccb10acde10622b4f9ab0615c5400ea) was very helpful in figuring out how to use `gen_statem` in Elixir.

A `gen_statem` can be initially thought off as a regular GenServer that can be started and initialized:

<script src="https://gist.github.com/MissaouiChedy/a949e072a0050c167f51eb8b0e328d31.js"></script>

Here the main difference is with the `init` function that returns a tuple of the following form: `{:ok, state, data}`. 

There is a distinction between `state` which is an atom representing the current state machine's state and `data` which is maintained between the calls to the behavior.

The `callback_mode` function is used to choose one of the two callback modes supported by `gen_statem`, we chose the `:state_functions` mode which allows us to model states as functions.

Consider the `say_hello` operation:

<script src="https://gist.github.com/MissaouiChedy/a788fd33b5c36ff45cd75ba80dd5f5ae.js"></script>

We defined a `say_hello` function that makes a `:gen_statem.call` to delegate the proper state function calling to the `gen_statem`, then for each state we defined a function named after the state. Each state specific function is set up to match the initially defined message atom i.e. `:hello`.

The `gen_statem` behavior makes sure to call the appropriate function depending on the state of the human, all we have to do is to define what happens in what states for which operations.

The `say_hello` operation does not cause any state transition, note how it returns a `{:keep_state, ...}` tuple to `gen_statem`.

If a function needs to cause a state transition it does so by returning a `{:next_state, :next_state, ...}` tuple, consider the `reset` operation for example:

<script src="https://gist.github.com/MissaouiChedy/2a94884cfe5988a2b51b6a244ad0be0f.js"></script>

`reset` causes the human to transition to a `neutral` state.

## Closing thoughts

`gen_statem` allows us to implement cleanly factored state machines in Elixir which can be very useful when dealing with complex use cases that can be modeled as state machines.

Finally, I would like to point out that there is a seemingly [convenient Elixir wrapper](https://github.com/antipax/gen_state_machine) for `gen_statem` **that I encourage you to check out**.


