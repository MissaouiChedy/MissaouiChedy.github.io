---
layout: post
title: "elixir and phoenix so far, channels"
date: 2017-06-15
categories: article
comments: true
---

The Phoenix framework has a built-in facility to manage two way communication between clients and the server called [*channel*].

Clients of Phoenix *channels* can be regular erlang processes or, more interestingly, external processes. In fact, there are a bunch of clients written in different languages that allows to communicate via Phoenix channels from web and mobile applications.

I've had the chance to use the [dn-phoenix] C# client that I am considering using in the Xamarin application that I am currently working on, more on this library further.

*Channels* abstract the underlying two way transport mechanism while offering a programming model based on the [*pub/sub*] pattern.

In this post, I am going to lay out the important parts of this great feature but first a couple of words about two way client server communication. 

## two way communication

Historically on the web, communication between clients and servers was always happening on a request/response basis: the client sends a request and the server returns a response. There was no way for the server to push data to the client without the client asking first.

In the last decade (or two), requirements for interactive web application that are able to refresh displayed content in soft real-time showed up such as online multiplayer video games and social networks.

Nowadays there are [some techniques for handling real-time updates] in web applications, the most interesting one is based on the [web-socket] protocol.

Phoenix channels, as pointed out earlier, abstracts away the tranport technique used for two way communication, it default to using [web-sockets and can fallback to a technique called long-polling] when the former is not supported by the target web client.

## essential phoenix channels concepts

Channels, as stated in the documentation, have some moving parts, consider the following chart: 
<div class="img-container">
![Phoenix Channel Clients]({{ site.url }}/imgs/phoenix_channel.PNG)
</div>

The previous diagram shows the components involved when using channels and how they interact. Let's start off by the client.

### channel client

Channel clients are usually external processes that uses a channel's client library in order to *join* a specific a *topic* in order to send and receive messages to/from the server.

They typically establish a web-socket connection to the server identified by a url similar to `ws://localhost:4000/socket` and then join a specific *topic*.

Channel client apis offer a way to send messages and to register callbacks that are executed when a message is received from the backend server.

The following listing shows an example usage with the C# [dn-phoenix] client:

<script src="https://gist.github.com/MissaouiChedy/c6b22d95b36b180bcd01513e08147416.js"></script>

The dn-phoenix client library seems pretty solid, it can handle the previously described capabilities as well as connection reestablishing behavior.

The only catch is that it is implemented with the Full .NET Framework and does not seem to work on Xamarin yet.

### topics

Topics in a pub/sub context represents a common interest to which individual processes can send/receive messages to/from.

In a typical pub/sub scenario, we can have multiple processes subscribed to a topic. Each time a process sends a message to the topic, the message is forwarded to the subscribed processes.

When using Phoenix channels, clients usually subscribe to a specific topic by calling the `Join` operation.

Topics are mapped to specific a channel module in the socket configuration.

### messages
Messages in the channel context, are defined by a name (also called an event) which usually a string and they carry a payload which usually a
JSON object.

The payload is usually a dictionary, or list type that is serialized when sent and that de-serialzed when received. The channels api makes this process very seamless both on the server and client side.

### channel module
Channels are actually modules that uses the Phoenix.Channel definition, they provide three basic interface functions, as you can see in the following snippet:
<script src="https://gist.github.com/MissaouiChedy/d60323de5a71537bcde537c6a188aa83.js"></script>

- `join` allows to handle a client trying to join a topic, usually some form of authorization is performed in this function.
- `handle_in` allows to specify what happens when a message arrives from the client, typically this function would broadcast the message to the other channels instances that joined the same *topic*.
- `handle_out` used with the `intercept` macro is used to capture messages that are going to the client's direction, this function usually decides whether or not to forward the message to the external client.

Channels are actually GenServers you can see in the components diagram that a channel instance is created for each client joining a topic, the `socket` argument is the actual `state` maintained by the GenServer and we can use it to store arbitrary data.

### socket configuration

We mentioned that a client joins a channel by establishing a web-socket connection to specific url. Web-Socket connections in elixir are usually targeted to specific path which is configured in the `MyApp.Endpoint` module:

<script src="https://gist.github.com/MissaouiChedy/e83fca101fac63d0a28d09994206e625.js"></script>

Here the `socket` subpath is mapped to the `MyApp.MyAppSocket` module.
The socket module is usually straightforward it just contains to key pieces:

<script src="https://gist.github.com/MissaouiChedy/f1ecb11879e84a704fb44780c211a402.js"></script>

 - The topic to channel mapping
 - The connect function that can act as a callback for inserting behavior when client tries to connect.


### Pubsub system

The `Phoenix.PubSub` module tracks down subscriptions to topics and takes care of forwarding messages from and to channel instances that can be distributed over different BEAM instances.

## Closing thoughts

After playing around with basic channels on single node, I am looking forward to see what kind of challenges arises when working with multiple nodes. I heard about the [Phoenix presence] module that provides solutions for inter-node consistency problems, also looking forward to play with that when need will come to scale to multiple nodes.



