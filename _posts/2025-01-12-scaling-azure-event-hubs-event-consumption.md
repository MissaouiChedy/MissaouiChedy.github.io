---
layout: post
title: "Scaling Azure Event Hubs Event Consumption"
date: 2025-01-12
categories: article
comments: true
---

With Azure EventHubs it is important to **understand the mechanisms available to scale events processing** across multiple workers.

In this post, we will discuss some concepts relevant to scaling event consumption across multiple workers and explore capabilities 
available in Azure Event Hubs for the scaling.

<i class="fa fa-github" aria-hidden="true"></i> **Full working sample** [is available on Github as usual.](https://github.com/MissaouiChedy/BlogSamples/tree/main/AzureEventHubsConsumerScaling)

## Horizontal Scaling
[Horizontal scaling,](https://azure.microsoft.com/en-us/resources/cloud-computing-dictionary/scaling-out-vs-scaling-up) also known as scaling out, is an important concept in [cloud computing.](https://nvlpubs.nist.gov/nistpubs/legacy/sp/nistspecialpublication800-145.pdf) 

Consider an application running on a single VM with say 4 CPUs and 16 GB of RAM, with this configuration the application is able
to handle a load of hundreds of requests per second:

<div class="img-container">
![Initial Scale]({{ site.url }}/imgs/InitialScale.png)
</div>

Overtime the application is getting successful and needs to handle more users and more requests per second.

In this case, we have two choices:

1 - Increase the resources of the VM to, for example, 8 CPUs and 32 GB of RAM *(Vertical Scaling):*
<div class="img-container">
![Vertical Scale]({{ site.url }}/imgs/VerticalScale.png)
</div>

2 - Add a second VM and balance the load between the two VMS *(Horizontal Scaling):*
<div class="img-container">
![Horizontal Scale]({{ site.url }}/imgs/HorizontalScale.png)
</div>

*Scaling Vertically* is **simple and straightforward** but it can have some drawbacks such as:
 - It is easy to hit the vertical scale limit quickly in the cloud
 - Scaling vertically may not be cost effective
 - Scaling vertically can require downtime  

*Scaling Horizontally* introduces complexity but **brings a lot of benefits** in return, complexity includes:
 - Load balancing mechanism must be setup and maintained
 - Applications must be stateless as much as possible
 - Stateful application (Databases) are more complex to scale-out

Nonetheless, horizontal scaling remains important in the cloud because once we invest in taming the complexity we get some benefits:

1. The horizontal scale limit is defined by **how much money you are willing to spend**
2. Redundancy and distribution bringing **high availability and resiliency**
3. Possible to **auto-scale** with minimal or without downtime  
4. Enables geo-distribution to **minimize network latency**

Discussing Horizontal vs Vertical Scaling further is out of the scope of this post, but you can [learn more about it here.](https://azure.microsoft.com/en-us/resources/cloud-computing-dictionary/scaling-out-vs-scaling-up) 😁

## Event Hubs Partitions
[Partitions](https://learn.microsoft.com/en-us/azure/event-hubs/event-hubs-features#partitions) are a logical concepts used by Azure Event Hubs to spread event consumption across multiple consumers.

Based on a *partition key value* provided by the event producer, event hub uses a hashing algorithm to determine the partition to which the event will be assigned.

<div class="img-container">
![Event Hub Partitions]({{ site.url }}/imgs/EventHubsPartitions.png)
</div>

Azure Event Hubs guarantees that **events having the same partition key value always land on the same partition.**
 
Partition keys are usually set by the producer and we typically use an event property such as geographical location, for example, in an order management application, we might choose the store area id as the partition key.

The idea is then to create 1 consumer for each partition per consumer group to optimize event consumption flow. 

How to properly set partition count can be tricky and you might want to consider the following **constraints when setting the partition count:**
- Partition count is set per Event Hub Topic at the creation time
- Not possible to modify the partition count after creation in the Standard and Basic tiers
- Only possible to increase partition count in the Premium tier
- There is a limit of partition count per namespace
- Not possible to decrease partition count after creation  

## Scaled Consumption Sample
Let's explore, [a sample console app](https://github.com/MissaouiChedy/BlogSamples/blob/main/AzureEventHubsConsumerScaling/AzureEventHubsConsumerScaling/Program.cs) with a several consumers implementation.

In our example, we start by creating an event hub topic with 3 partitions:
```sh
$partitionsCount = 3

## Create an Event Hub
az eventhubs eventhub create `
  --name $eventhubTopicName `
  --namespace-name $eventHubNamespace `
  --resource-group $resourceGroupName `
  --cleanup-policy Delete `
  --retention-time 2 `
  --partition-count $partitionsCount
```

Then in the following program, we setup 3 Tasks to consume events by using the same consumer group:
```csharp
int consumersCount = 3;

var consumers = Enumerable
    .Range(0, consumersCount)
    .Select((i) =>
    {
        var storageClient = new BlobContainerClient(
            new Uri("https://mainconsumerstorageacc.blob.core.windows.net/main-consumer"),
            new DefaultAzureCredential());

        var processor = new EventProcessorClient(
            storageClient,
            "main-consumer",
            "evh-test-consume-scaling.servicebus.windows.net",
            "main-topic",
            new DefaultAzureCredential());

        var eventConsumer = new EventConsumer(i, processor);
        eventConsumer.StartConsumptionAsync();

        return eventConsumer;
    })
    .ToList();
```

The program is then setup to wait for events until a key is pressed in the console:
```csharp
Console.WriteLine($"All '{consumersCount}' Consumers started, waiting for console input to stop...");
Console.ReadKey();
```

While, the program is waiting we use the [`SendMessagesToEventHubTopic.jmx`](https://github.com/MissaouiChedy/BlogSamples/blob/main/AzureEventHubsConsumerScaling/SendMessagesToEventHubTopic.jmx) [jmeter test](https://blog.techdominator.com/article/sending-events-to-eventhubs-with-jmeter.html) to send 200 events with `LocationId` as the partition key with values from 1 to 10. 

Finally the program prints the following report of what occurred related to partitions in the execution:
```
=================================================
Consumer 0 Received '40' Messages
Consumer 1 Received '40' Messages
Consumer 2 Received '120' Messages
Received '200' Messages
Location Ids received on Partition 0 '3,4,5,6,7,8'
Location Ids received on Partition 2 '1,2'
Location Ids received on Partition 1 '10,9'
============================================================================
0 Duplicate Messages found with the following Ids:
============================================================================
No Duplicate Message Received
```

The previous report shows:
- Count of messages processed by each consumer
- Total of messages received
- Location Ids received on each partition
- Count and listing of duplicate messages

In the previous run, the count of partitions is equal to the count of consumers, we can observe somethings here:
- Events balancing over partitions is not that even
- Guarantee of events having same partition key value landing on the same partition is respected

Let's see what happens when partitions count is not equal to consumers count.

### Partitions more than consumers

Running our example with only 1 consumer and given we have 3 partitions we get the following output:
```
=================================================
Consumer 0 Received '200' Messages
Received '200' Messages
Location Ids received on Partition 0 '3,4,5,6,7,8'
Location Ids received on Partition 1 '10,9'
Location Ids received on Partition 2 '1,2'
============================================================================
0 Duplicate Messages found with the following Ids:
============================================================================
No Duplicate Message Received
```

Here we can see that the single consumer was able to process all 200 events over all 3 partitions, meaning that in this case **no event will be lost** if consumers count is less than partitions count and **this is handled by the Event Hub SDK Consumer Client.**

### Partitions less than consumers
Running our example with 10 consumers and given we have 3 partitions we get the following output:
```
=================================================
Consumer 0 Received '160' Messages
Consumer 1 Received '120' Messages
Consumer 2 Received '0' Messages
Consumer 3 Received '40' Messages
Consumer 4 Received '0' Messages
Consumer 5 Received '40' Messages
Consumer 6 Received '0' Messages
Consumer 7 Received '0' Messages
Consumer 8 Received '0' Messages
Consumer 9 Received '0' Messages
Received '360' Messages
Location Ids received on Partition 1 '10,9'
Location Ids received on Partition 2 '1,2'
Location Ids received on Partition 0 '3,4,5,6,7,8'
============================================================================
160 Duplicate Messages found with the following Ids:
Message Id: 18c202e4-3975-410f-9c76-5d3afee60ae1, duplicated 1 time(s)
...
============================================================================
Last Duplicate Message was Received At 12/01/2025 10:56:41
Last Message Received At 12/01/2025 10:56:41
```

In the previous example, we have also set the consumer balancing strategy to [`Greedy`](https://learn.microsoft.com/en-us/dotnet/api/azure.messaging.eventhubs.processor.loadbalancingstrategy?view=azure-dotnet#fields) to cause some duplicate messages:

```csharp
var processor = new EventProcessorClient(
    storageClient,
    "main-consumer",
    "evh-test-consume-scaling.servicebus.windows.net",
    "main-topic",
    new DefaultAzureCredential(),
    new EventProcessorClientOptions
    {
        LoadBalancingStrategy = LoadBalancingStrategy.Greedy
    });
```

Here we have some observations:
1. Only 4 consumers received events to process
2. 360 events where received while 200 events were sent

In Azure Event hubs, it is **useless to setup consumers count more than partitions count** as excess consumers will eigher starve or get duplicate messages.

Duplicate messages are produced to honor the ['At Least Once'](https://learn.microsoft.com/en-us/azure/architecture/serverless/event-hubs-functions/resilient-design) guarantee for event delivery, Event Hubs is designed assuming that delivering duplicate events is better than loosing events.

That is why Event Hubs consumer should usually be designed to handle [duplicate events](https://learn.microsoft.com/en-us/azure/architecture/serverless/event-hubs-functions/resilient-design#idempotency) somehow.

## Summary

- Event Hubs event consumption is scaled horizontally with partitions
- Partition key choice is important
- Partition count setting is not that flexible and requires some planning
- To optimize consumption flow, partitions counts should be equal to consumers count
- Having consumer count less than partitions count does not cause event loss
- Useless to set consumer count greater than partitions count
- Consumers should be designed to handle duplicate events gracefully 


