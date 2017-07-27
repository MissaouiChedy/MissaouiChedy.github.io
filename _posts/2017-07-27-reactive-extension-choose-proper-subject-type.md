---
layout: post
title: "Reactive extension<br/> choose the proper subject type"
date: 2017-07-27
categories: article
comments: true
---

This week I faced in my current Xamarin project an odd timing issue related with observable collections and the [.NET reactive extension](https://github.com/Reactive-Extensions/Rx.NET#a-brief-intro). 

In this post, I wanted to document the debugging process and what I learned along the way about types of *observables* and *subjects* which essentially revolves around using the proper `Subject` implementation.
## the issue

I have a Xamarin mobile application that needs to join a [channel](http://www.phoenixframework.org/docs/channels) in a Phoenix based backend service.

When the mobile application joins the channel it receives immediately notifications about already connected users then it is supposed to render them on a map view. 

The issue was that **these notification where ignored and existing users where not getting rendered**.

After some debugging on both backend and frontend sides, I figured out that the issue was caused by the fact that on-join notifications where delivered fast and before letting the UI layer a chance to subscribe its event listeners(here the event is the reception of the notification).

Consider the following diagram:

<div class="img-container">
![UML diagram showing the classes involved]({{ site.url }}/imgs/ActiveStoreDiagram.PNG)
</div>

The diagram depicts the classes involved in the issue, here we have three classes involved:

The `BackendGateway` class with its `Connect` method establishes a web-socket connection with the backend, joins the specific topic and registers message reception handlers as you can see this in the following simplified snippet:

<script src="https://gist.github.com/MissaouiChedy/6ae585277c363e2f7ae483f9e0e96c4d.js"></script>

This method returns and `IObservable<Message>` and as you can see the class uses the `Subject` class has a `IObservable` implementation, the message reception handler converts the received payload to an internal representation and then pushes it to the `_observable` subject via `OnNext`.

The `ActiveStore` class, when started via its `Start` method, uses the `BackendGateway` class to connect to the backend, it gets the `IObservable<Message>` after calling `BackendGateway.Connect` to which it subscribes an incoming message event handler: 

<script src="https://gist.github.com/MissaouiChedy/d666607c39b60278a4bf0c199f787ef0.js"></script>

You can see that this handler performs some processing before pushing the messages to another down stream `Subject` which is returned by `ActiveStore.Start` to its callers.

The `MainActivity` class creates an `ActiveStore` instance and gets an `IObservable<Message>` by starting it via the `Start` method whereupon it registers a listener that will handle drawing actual users on the UI:

<script src="https://gist.github.com/MissaouiChedy/b58b572adbf4752aeddf165099b917ea.js"></script>

Here it turned out that in the time window spanning between the `BackendGateway` instance effectively joining the channel and `MainActivity` subscribing its `Message` reception handler is large enough to cuase the `MainActivity` to miss the initial notifications.

This situation has been caused by the fact that all the `IObservable`s in this chain where inadvertently implemented has *Hot Observables*.

## Hot vs cold observable

In the Reactive extension, there two kinds of observable collections:
- cold observables that starts publishing values only when an *Observer* is subscribed
- hot observables that starts publishing values usually when created even without any *Observer* subscription

In our previous example, the `BackendGateway` starts pushing events in the `Subject` that it return as soon as the connection is established with the backend, late subscribers will simply miss early notifications which in our case is unacceptable.

We can clearly see that the `IObservable<Message>`s returned respectively by `BackendGateway.Connect` and `ActiveStore.Start` have been implemented (inadvertently) as hot observables while they should have been implemented as cold observables.

Implementing all of these observables seems a bit challenging for me, but fortunately there is a simpler alternative.

Fortunately, thanks to an existing subject implementation we don't have to make these observable cold as we are going to see in the next section.

## replay subjects, know your subject types

The reactive extension defines multiple subject types, among them the [`ReplaySubject`](https://msdn.microsoft.com/en-us/library/hh211810(v=vs.103).aspx).

`ReplaySubject` keeps track of received messages and replays them in the order they arrived in to every new subscriber, simply using the `ReplaySubject` instead of the regular `Subject` allowed us to correct the issue in the previously described code. 

Late subscribers can now get all the notifications delivered since the 
establishment of the connection with the backend.

## closing thoughts 

Before being exposed to the `ReplaySubject` thanks to the excellent [Rx tutorial](http://www.introtorx.com/content/v1.0.10621.0/02_KeyTypes.html), I implemented a less than ideal work around on the backend side that essentially sends notifications after a two seconds delay in order to give the mobile app enough time to register its listeners. It's time to get rid of it <i class="fa fa-smile-o" aria-hidden="true"></i>


