---
layout: post
title: "phoenix channels C# client"
date: 2017-07-19
categories: article
comments: true
---

Phoenix channels, which we discussed in a [previous post]({{ site.url }}/article/elixir-phoenix-so-far-channels.html), are very useful for building two way communication between web clients and servers.

We also mentioned that clients doesn't have to be elixir or erlang processes, in fact multiple clients exist for different languages.

The [JavaScript ES6 client](https://github.com/phoenixframework/phoenix/blob/master/priv/static/phoenix.js) seems to be the reference implementation for the phoenix channels clients, this is somewhat nice since it is possible to run JavaScript from many environments; mainly from web browsers and even from native smartphone OS SDKs via various incarnations of the [WebView](https://developer.android.com/guide/webapps/webview.html) component.  

As you may know, I am currently working on a Xamarin mobile application and it would be ideal to use a C# implementation of the phoenix channel client instead of embedding the JavaScript client somehow. 

Fortunately, there is a pretty stable (so far) open source C# implementation called [PhoenixSharp](https://github.com/Mazyod/PhoenixSharp) that I managed to get working in a Xamarin project with some tweaks.

## using phoenix-sharp in a Xamarin setup

The [PhoenixSharp](https://github.com/Mazyod/PhoenixSharp) repository can be cloned and the main project can be added to a Xamarin Solution [as an existing project](https://msdn.microsoft.com/en-us/library/ff460187.aspx). The PhoenixSharp project is targeting .NET Framework 3.0 to ensure compatibility with the [Unity](https://unity3d.com) game engine.

The project wouldn't initially build in my machine I suspect that this is due the fact that the .NET Framework 3.0 SDK is not installed, I was able to get the project to build by changing the target to .NET Framework 4.5.2.

<div class="img-container">
![PhoenixSharp target framework]({{ site.url }}/imgs/PhoenixSharpTarget.PNG)
</div>

Using *PhoenixSharp* from a Xamarin Android project requires adding a reference to the `Phoenix` project from the Xamarin Android project and to install two nuget packages:
- [Json.NET](https://www.nuget.org/packages/Newtonsoft.Json/) which a JSON serialization/deserialization library
- [WebSocketSharp](https://www.nuget.org/packages/WebSocketSharp) which is a websocket client implementation

## phoenix-sharp dependencies

Before using the channel client you have to provide a websocket client implementation by implementing the `PhoenixSharp.IWebSocket` interface. In fact, *PhoenixSharp* does not depend on any websocket library giving you the flexibility (and the extra work :-) ) to provide a websocket implementation.

The simplest thing here is to use the *WebSocketSharp* library to implement `IWebSocket`. An example working implementation is provided in the [project's ReadMe](https://github.com/Mazyod/PhoenixSharp#getting-started).

The library depends on Json.NET especially on its `Newtonsoft.Json.Linq.JObject` type, payloads returned from the server are available as `JObject`s inside the message receiving event handlers.

## common channel operations
The following snippet shows some common channel operations:
<script src="https://gist.github.com/MissaouiChedy/6e7674c74df15d8ff83fdfaf781ea793.js"></script>

It is possible to create a socket connection by providing the url of the server as well as the connection payload that will be passed to the `Socket.connect` function on the server side.

A channel is created by providing a topic and is typically joined
just after, joining the channel via the `Join` method allows to send and receive messages to/from the topic. It is possible to register join reply callbacks to react to eventual errors when joining the topic.

The `On` method allows to register a callback that will handle the specified message.

The `Push` method allows to send messages to the backend that will be intercepted by the proper `Channel.handle_in` function, it is possible to register callbacks for eventual replies.


## handling incoming messages and errors with observable collections

The channel connection can be thought of as a continuous stream of incoming messages and can be easily modeled as an *observable collection*.

Consider the following example:
<script src="https://gist.github.com/MissaouiChedy/8763e8303119b71ce0792905134f8c44.js"></script>

The messages and replies reception callbacks can be used to push the received data to the `messageStream` `IObservable<MessagePayload>`, here we used the `Subject<T>` class available in the `System.Reactive` namespace which is an `IObservable<T>` implementation that must be **[used with caution](https://stackoverflow.com/questions/14396449/why-are-subjects-not-recommended-in-net-reactive-extensions)**.

This is a great way to handle incoming message events that, as discussed in a [previous post](http://localhost:4000/article/reactive-extension-csharp.html), allows to decouple event notification from event handling.

## converting payloads

As we mentioned previously, messages and replies payloads returned by the backend channel are represented as `Newtonsoft.Json.Linq.JObject` objects, e can access data in the `JObject` by using the indexer operator(`[]`).
Consider the following example:

<script src="https://gist.github.com/MissaouiChedy/cbad804b46a338e84a699ef97d27c112.js"></script>

The fields in the `JObject` are directly accessible by using the indexer operator, the `ToObject<T>` extension method can be used to convert fields to multiple types as we can see in the previous example.

## Closing thoughts

PhoenixSharp has been stable so far, it would be very nice if in the future it gets `netstandard 2.0` compatibility and a reactive based interface (as opposed to a callback based). Looking forward to contribute.  


