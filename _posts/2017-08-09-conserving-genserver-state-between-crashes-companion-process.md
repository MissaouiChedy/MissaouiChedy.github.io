---
layout: post
title: "conserving genserver state between crashes with a companion process"
date: 2017-08-09
categories: article
comments: true
---

In a [previous post](http://blog.techdominator.com/article/elixir-phoenix-conserving-channel-instance-assigned-state-between-crashes.html), we discussed a method for conserving a phoenix channel instance state between crashes that was based on [ETS tables](http://erlang.org/doc/man/ets.html).

In this post, we are going to see how to achieve similar results by using a a pair of processes instead as in [this example](https://github.com/MissaouiChedy/conservation).

## a reminder about conserving state

*OTP GenServers* are able to retain state between calls, in erlang and elixir it is often discouraged to code defensively so we basically let *GenServers* crash in the event of failure since they are going to be usually restarted by a *supervisor*.

When a *GenServer* crashes it looses its state, so if the retained state is important we need a way to save it and restore it between crashes.

## using a pair of processes

Assuming that we have the `Server` *GenServer* holding state `S`, we can create a second *GenServer* named `StateContainer` for example that is responsible for holding the state `S`, both *GenServers* will be supervised by the same *supervisor* named `ProcSupervisor`, consider the following diagram:

<div class="img-container">
![supervision structure diagram]({{ site.url }}/imgs/supervision_diagram.PNG)
</div>

The [`StateContainer`](https://github.com/MissaouiChedy/conservation/blob/master/lib/conservation/state_container.ex) *GenServer* is very trivial it basically provides two operations:
 - `get` that allows to read the contained state
 - `set` that allows to update the contained state

The `Server` *GenServer* depends upon the `StateContainer`, when `Server` is initialized(under `start_link` or `init`) it checks `StateContainer` for any previously saved state and when it is terminated it uses `StateContainer.set` to save its state.

The `ProcSupervisor` restarts any of `Server` and `StateContainer` when they crash.

## alternative supervision tree structure
In the excellent [Programming Elixir](https://pragprog.com/book/elixir/programming-elixir) book under chapter 17 *OTP Supervisors*, there is an example demonstrating how to achieve *GenServer* state conservation but with unnamed processes.

This post's example uses named *GenServers* to simplify things and to keep them concise. The example from the book is more interesting and shows how to dynamically create multiple sub supervision trees instances similar to the following:

<div class="img-container">
![supervision structure diagram]({{ site.url }}/imgs/supervision_diagram_dynamic.PNG)
</div>


Definitely, check-it out.

## why not putting the state in the supervisor

*OTP supervisors* are able to hold state as well, one might think that it would be possible for a *supervisor* to pass its *pid* to the supervised *GenServer* that subsequently uses any eventually defined interface on the *supervisor* to store and retrieve its *state*.

The previous sounds appealing as it allows to basically avoid the overhead of creating a *support process* for each stateful *GenServer*, unfortunately we can't mess around with the supervisor's *state tuple*.

In fact, I am assuming **that adding elements or fiddling with existing ones in the *supervisor's state tuple* will break the supervisor's code causing a lot of matching errors**.

## closing thoughts

Conserving *GenServer* state can sometime be a required, so far I am aware of two methods:
 - Using *ETS table* which is simple and straightforward but introduces a shared resource and with shared resources race conditions starts to creep
 
 - Using a *pair of processes* which allows for better isolation but requires more effort to implement and adds some overhead (in number of spawned processes)