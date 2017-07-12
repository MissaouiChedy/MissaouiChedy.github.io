---
layout: post
title: "reactive extension in C#"
date: 2017-07-12
categories: article
comments: true
---

In the past two years I have been hearing a lot about *reactive programming*, my first exposure to this new "paradigm" happened when I was playing around with some [scala](https://www.scala-lang.org/) two years ago which got me to discover the [reactive manifesto](http://www.reactivemanifesto.org/), but it is only after watching [Erik Meijer's talk "What does it mean to be Reactive?"](https://www.youtube.com/watch?v=sTSQlYX5DU0) that I learned that it was essentially a style of event handling based on *observable/push based collections*.

Recently, I have been working a lot with web sockets and I have been handling incoming server messages by using `IObservable<T>`, I must say that it is a great way to decouple *event notification* from *event handling*.

## classic way of handling events

Historically, handling events has been a matter of registering a callback in the relevant object that needs to handle the event, consider the following example:

<script src="https://gist.github.com/MissaouiChedy/d1dad96dbdbc2281e3007aa6c43d420e.js"></script>

The hypothetical `WebSocketConnection` class is naturally able to handle incoming messages from the server, it does so by allowing the programmer to register a callback delegate in order to do something with the received payload.

This style of event handling is a bit rigid; in fact it tightly couples *event notification* with *event handling*. One of the drawbacks of this tight coupling is that it is difficult to build event handling that requires further downstream notification.

## observable collections

Consider what would be the previous web socket example if we used the reactive extension:
<script src="https://gist.github.com/MissaouiChedy/63768e645c4376eb3c226c6e32b96405.js"></script>

Connecting to the web socket returns us an `IObservable<WSMessage>`, I like to think of `IObservable` as a programmable tap; they represent a continuous stream of values of a certain type which can represent an event, in our example the event is a message from the server.

As you can see in the example, the tap is programmable via Linq operations that allows for example to filter and project on the sequence of data that is going to be received over time, of course, these operations are executed when data is available on the stream.

It is possible to open the tap and to let the events flow by calling the `Subscribe` method on the `IObservable<T>`, by passing a callback we can handle each `T` object that will be delivered to the observable collection.

`IObservable<T>` is often referred to as a *push based observable collection*.

It is observable because we can attach *element available* callbacks on it and as opposed to `IEnumerable` which is a pull based collection i.e. the user of the `IEnumerable` pulls elements from the sequence, `IObservable` is push based i.e. elements of the list are pushed to the callback subscribed by the user of the sequence. 

Subscribing returns an `IDisposable` subscription object that needs to be disposed of (by calling `Dispose` on the subscription) when the flow of events is no longer needed.

You can see in the example how the `StartHandling` method subscribes to the `domainStream` and then returns it to its caller. `StartHandling`'s caller is then free to add additional processing steps to the `IObservable` and to `Subscribe` to it.

The user of the observable collections acquires *event notification* by getting an `IObservable<T>` instance, it is then free to `Subscribe` to the `IObservable<T>` or not, essentially making *event handling* a choice that can be placed somewhere else.

## benefits of using observable collections

`IObservable` represents a continuous source of events, it can be passed around and returned to multiple parts of an application allowing each part to arbitrarily add processing steps to the `IObservable` before subscribing to it eventually.

*Observable collections* allows for a more declarative programming model thanks to the support for Linq operations.

The `IObservable<T>` interface is defined under the `System` namespace in the base class library making it always available thus directly usable inside [domain layers]({{ site.url }}/article/model-view-view-model.html).

Thanks to the [`Observables.FromEventPattern`](https://msdn.microsoft.com/en-us/library/system.reactive.linq.observable.fromeventpattern(v=vs.103).aspx) method and to the [`Subject<T>`](https://msdn.microsoft.com/en-us/library/hh242970(v=vs.103).aspx) class it is possible to convert callback based event handling interfaces to reactive based ones.

## closing thoughts

How to create a concrete implementation of an `IObservable` remains unknown for me, so far I have been just using libraries returning `IObservables` and occasionally adapting callback based interfaces to interfaces returning `IObservable`.

Looking forward to shed some light on that.