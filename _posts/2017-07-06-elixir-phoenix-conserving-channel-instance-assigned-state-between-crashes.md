---
layout: post
title: "conserving channel instance assigned state between crashes"
date: 2017-07-06
categories: article
comments: true
---

In a [previous post]({{ site.url }}/article/elixir-phoenix-so-far-channels.html), we talked about [phoenix framework channels](http://www.phoenixframework.org/docs/channels) and their utility in establishing two way communications between web clients and servers.

We also mentioned that the channel module, in which callback functions such as `handle_in` and `handle_out` are defined, is an actual OTP GenServer. An instance of the channel module is started by the OTP framework when its `start_link` function is called.

It possible for the developer to store arbitrary *state* in the channle instance by using the [`assign`](http://www.phoenixframework.org/docs/channels#section-socket-assigns) mechanism. Unfortunately, this *state* can be lost when the channel instance crashes.

In this post, we are going to see a way to conserve *transient assign state* between channel instance crashes, by transient we mean that the state should be retained between crashes but not after a regular shutdown.

First let's get a sense of how the `assign` mechanism works.

## storing state in a channel instance

One of the characteristics of GenServers is that they are able to maintain state, consider the following listing:
<script src="https://gist.github.com/MissaouiChedy/d921b485f96cee30eb2fe364045d23fb.js"></script>

You can see that all the functions in the previous GenServer accepts a `state` argument, the *state* is passed to each defined callback function and must be included in the term it returns.

It is possible to create a mutated copy of the state inside the callback functions(`handle_cast`, `handle_call`) and to return it instead.

When using phoenix channels, there is always a `socket` argument passed to all of its callback functions(`handle_in`, `handle_out`...).
The `socket` argument contains state (usually a `Phoenix.Socket` struct) needed by the phoenix framework to manage the execution of the *channel instance* so usually we don't mess around with its content.

Nonetheless, the `Phoenix.Socket` struct contains the `assigns` field which is a map that contain arbitrary [erlang terms](http://erlang.org/doc/reference_manual/data_types.html), consider the following listing:

<script src="https://gist.github.com/MissaouiChedy/6ed8a6869296f12071ba2fd274f92ac9.js"></script>

With the `assign` function we can get a new `Phoenix.Socket` copy with a key-value pair inserted in the `assigns` field(in the `join` function) which can be later accessed directly in order to read the stored state(in the `handle_in` function).

## channel instances can crash

When developing in erlang/elixir, we tend to follow the [let it crash](http://wiki.c2.com/?LetItCrash) principle. This means that we do not code defensively and we expect our OTP behavior to be restarted via a Supervisor when crashes happen.

When the state maintained by an OTP behavior is important it needs to be recovered when the behavior instance restarts.

Functions defined in channel modules can cause channel instance crashes and if the state stored under `socket.assigns` should persist crashes then we need a mechanism to restore it when the channel instance gets restarted.

There is one thing to note about channel instances: [*they are not supervised*](https://elixirforum.com/t/why-arent-phoenix-channel-instances-supervised/6630). In fact, when a channel instance crashes it is the responsibility of the channel client to reestablish the two way communication causing a new channel instance to be created.

In OTP, there is no automatic way to recover GenServers state even when the instance is supervised. It is the responsibility of the developer [to handle state recovery](https://stackoverflow.com/questions/846312/how-can-i-restore-process-state-after-a-crash).

## conserving state with join, terminate and ets tables

One way to conserve channel instance state between crashes is to backup the important state somewhere when the channel crashes and to fetch it and pass it to the new channel instance when it is created.

The previous assumes that we have a callback that is executed when the channel instance crashes and a global storage space. Fortunately, in OTP we have both.


### the terminate callback

OTP GenServers modules can define the [`terminate/2`](https://hexdocs.pm/elixir/GenServer.html#c:terminate/2) callback that is called when an instance is about to stop and that takes two arguments:
- **reason** which is usually a tuple representing the error that happened
- **state** which is the actual instance state when the crash happened

The `terminate` callback allows us to basically store the important state when the `reason` is an error, or to perform some other processing when the `reason` is a normal shutdown(when the client disconnects explicitly for example).

Be advised that the `terminate` callback **is not guaranteed to execute in some circumstances**, for example when the instance is stopped with a *brutal kill*. It is usually discouraged to handle resource de-allocation inside the `terminate` callback for the previous reason. I encourage you to read the [`terminate`'s function description](https://hexdocs.pm/elixir/GenServer.html#c:terminate/2) in the elixir documentation.

In our case, we are handling transient state conservation i.e. state that should persist unexpected crashes but that is discarded when a normal shutdown happens so we assume it is OK to just use the `terminate` callback.

### ets tables

[Ets tables](https://elixir-lang.org/getting-started/mix-otp/ets.html) can be thought of as a key-value store local to an erlang VM, consider the following snippet:
<script src="https://gist.github.com/MissaouiChedy/7470f15455c4b7c4a2c9d71baceccb9c.js"></script>

Processes can create and delete *tables* in which they can store and retrieve key-value pairs and which can be accessed by multiple processes.

Note that:

- Access to ets tables can be restricted 
- Keys and values can be any erlang term
- We can choose the underlying data structure that a table uses

### example

Consider the following channel module:
<script src="https://gist.github.com/MissaouiChedy/67f7f5e095cf2462a9de11bc9e0e6632.js"></script>

The `join` function verifies whether a state has been backed up in the `:holder` table, if it is the case the channel is initialized with the backed up state otherwise, it is initialized with the default state(`[]`). This allows us to recover previous state.

The `:holder` table is created under `ChanState.start` i.e. when the OTP application starts.

The `terminate` function when called in a crash situation, will backup the state in the `:holder` table. It will cleanup the relevant state from the `:ets` table in the event of a normal shutdown. This allows us to backup the important state.

In the [chan_state](https://github.com/MissaouiChedy/chan_state), you will found a test demonstrating the state conservation under `test/channels/stateful_channel_test.exs`, check it out!

## closing thoughts

There are other methods to conserve state that exists.
We can for example create a companion process for each channel instance in which it backs up and recovers its state.

It is also possible to return the state of a crashed GenServer to a Supervisor and to build proper recovery in the Supervisor it self.

In our current project, we decided to stick with the *ets tables* solution because it is in our opinion [the simplest thing that could possibly work](http://wiki.c2.com/?DoTheSimplestThingThatCouldPossiblyWork).  










