---
layout: post
title: "Azure Event Hubs Event Processor, Yet Another Alternative"
date: 2025-03-08
categories: article
comments: true
---

<p class="summary">
In this post, we continue exploring alternative ways to process Azure Event Hubs events with the .NET SDK.
</p>


<div class="img-container">
  <img src="{{ site.url }}/imgs/AzureEventhubEventProcessorCover.webp" alt="Azure Eventhubs Event Processor Cover" />
</div>

In this post, we continue exploring alternative ways to process Azure Event Hubs events with the [.NET SDK.](https://github.com/Azure/azure-sdk-for-net/tree/main/sdk/eventhub)

This time, we will dive into the [`EventProcessor`](https://github.com/Azure/azure-sdk-for-net/blob/main/sdk/eventhub/Azure.Messaging.EventHubs/design/proposal-event-processor%7BT%7D.md) class, which provides a robust framework for building customized event-driven processors.

We will cover the key features and benefits of using the `EventProcessor` class, including its ability to 
customize checkpoint and ownership data storage, while leveraging resiliency and load balancing features from the SDK.

Additionally, we will discuss how to implement custom event processing logic, handle errors and use the various hooks available.

<i class="fa fa-github" aria-hidden="true"></i> **Full working sample** [is available on Github as usual](https://github.com/MissaouiChedy/BlogSamples/tree/main/AzureEventHubsEventProcessor)

## Event Processor

`EventProcessor` is an event consuming client with the capability of processing events from multiple partitions of an event hub. 

This makes it **suitable for production scenarios,** since the abstract class already implements a lot of features such as (among other):
- Connection/Disconnection management with the event hub
- Possibility to process events by batch
- Load balancing partition ownership
- Reclaiming ownership of partitions left of by crashed consumers

You typically use `EventProcessor` by defining a subclass of it and by implementing its abstract methods:

```csharp
public class CustomEventsProcessor : EventProcessor<CustomPartitionContext>
{
    ...

    public CustomEventsProcessor(...)
        : base(...)
    {
        ...
    }

    protected override async Task<IEnumerable<EventProcessorPartitionOwnership>> 
        ClaimOwnershipAsync(
            IEnumerable<EventProcessorPartitionOwnership> desiredOwnership,
            CancellationToken cancellationToken)
    {
        ...
    }

    protected override async Task<IEnumerable<EventProcessorPartitionOwnership>> 
        ListOwnershipAsync(CancellationToken cancellationToken)
    {
        ...
    }

    protected override Task OnProcessingErrorAsync(
        Exception exception, 
        CustomPartitionContext partition,
        string operationDescription,
        CancellationToken cancellationToken)
    {
        ...
    }

    protected override async Task OnProcessingEventBatchAsync(
        IEnumerable<EventData> events,
        CustomPartitionContext partition,
        CancellationToken cancellationToken)
    {
        ...
    }
    
    protected override async Task<EventProcessorCheckpoint> GetCheckpointAsync(
        string partitionId, 
        CancellationToken cancellationToken)
    {
        ...
    }

    protected override Task UpdateCheckpointAsync(
        string partitionId,
        long sequenceNumber,
        long? offset,
        CancellationToken cancellationToken)
    {
        ...
    }

    protected override async Task<IEnumerable<EventProcessorCheckpoint>> 
        ListCheckpointsAsync(CancellationToken cancellationToken)
    {
        ...
    }
}
```

There are 4 abstract methods that you must implement:

| Method                        | Responsibility                                                          |
|-------------------------------|-------------------------------------------------------------------------|
| `ClaimOwnershipAsync`         | Updates the ownership data                                              |
| `ListOwnershipAsync`          | Returns current ownership data                                          | 
| `OnProcessingEventBatchAsync` | Processes a batch of incoming events                                    |
| `OnProcessingErrorAsync`      | Handles errors thrown by the base class behavior during event reception |

In addition, we got 3 overridable methods related to checkpoint store customization, that **must be implemented too:**

| Method                  | Responsibility                                                          |
|-------------------------|-------------------------------------------------------------------------|
| `GetCheckpointAsync`    | Returns checkpoint data for one partition                               |
| `UpdateCheckpointAsync` | Update checkpoint data for one partition                                | 
| `ListCheckpointsAsync`  | Returns all checkpoint data for all partitions                          |

While `EventProcessor` checkpoint related methods are not abstract, they should be implemented nonetheless since the default implementation will simply throw a [`NotImplementedException.`](https://learn.microsoft.com/en-us/dotnet/api/system.notimplementedexception)

Note also that [`PartitionContext`](https://github.com/Azure/azure-sdk-for-net/blob/main/sdk/eventhub/Azure.Messaging.EventHubs/design/proposal-event-processor%7BT%7D.md#event-processor-partition) representing essentially the *current active partition for the operation* is also customizable and extendable.

It can be used for example to [store values that can be set as part of partition initialization.](https://github.com/Azure/azure-sdk-for-net/blob/main/sdk/eventhub/Azure.Messaging.EventHubs/design/proposal-event-processor%7BT%7D.md#create-a-custom-processor-with-custom-partition-context)

## Processing Events

`EventProcessor` provides the [`OnProcessingEventBatchAsync`](https://learn.microsoft.com/en-us/dotnet/api/azure.messaging.eventhubs.primitives.eventprocessor-1.onprocessingeventbatchasync?view=azure-dotnet#azure-messaging-eventhubs-primitives-eventprocessor-1-onprocessingeventbatchasync(system-collections-generic-ienumerable((azure-messaging-eventhubs-eventdata))-0-system-threading-cancellationtoken)) async method that allows to process a batch of events.

Unlike the typical [`EventProcessorClient,`](https://blog.techdominator.com/article/consuming-messages-with-azure-event-hubs.html) `EventProcessor` instances **are created with a maximum batch size** that allows the developer to process a batch of available events in one go.

In our sample, we implemented `OnProcessingEventBatchAsync` as in the following:
```csharp
protected override async Task OnProcessingEventBatchAsync(IEnumerable<EventData> events,
    CustomPartitionContext partition, CancellationToken cancellationToken)
{
    foreach (var eventData in events)
    {
        var readOnlySpan = new ReadOnlySpan<byte>(eventData.EventBody.ToArray());
        EventPayload receivedEvent = JsonSerializer
            .Deserialize<EventPayload>(readOnlySpan)!;

        Console.WriteLine($"Consumer {Identifier} received '{receivedEvent}'...");

        _processedEvents.Add(receivedEvent);
        await UpdateCheckpointAsync(partition.PartitionId, eventData.SequenceNumber,
            eventData.Offset, cancellationToken);
    }
}
```

Foreach event batch, we simply loop through the events one by one performing:
- Event De-serialization
- Adding the event to a list
- Updating the checkpoint store

Here note that as in the typical `EventProcessorClient,`, you have to perform checkpoint update explicitly giving you the option to perform it periodically.

In our example, we perform the checkpoint with every successfully processed events **since we use an underlying fast in-memory cache** with [Redis.](https://redis.io/)

## Handling Event Reception Errors

[`OnProcessingErrorAsync`](https://learn.microsoft.com/en-us/dotnet/api/azure.messaging.eventhubs.primitives.eventprocessor-1.onprocessingerrorasync?view=azure-dotnet#azure-messaging-eventhubs-primitives-eventprocessor-1-onprocessingerrorasync(system-exception-0-system-string-system-threading-cancellationtoken)) is called by the `EventProcessor` base class when an exception is thrown during event processing. 

Handling errors effectively is crucial to ensure the robustness and reliability of your event processing solution. 

If not implemented correctly, then **processing errors from the base class could be silently ignored.**

In our sample, we implemented it in a simplistic manner, but please **do consider what occurs when this is called in your production scenario:** 

```csharp
protected override Task OnProcessingErrorAsync(Exception exception, CustomPartitionContext partition,
    string operationDescription, CancellationToken cancellationToken)
{
    Console.WriteLine("Processing Error !");
    Console.WriteLine("==================");
    Console.WriteLine(exception.Message);

    return Task.CompletedTask;
}
```

## Managing Partition Ownership Storage

As we saw in a [previous post,](https://blog.techdominator.com/article/scaling-azure-event-hubs-event-consumption.html#partitions-less-than-consumers) within a consumer group a partition can only be owned by 1 client consumer and 1 client consumer can own several partitions, this is [by design in Event Hubs.](https://learn.microsoft.com/en-us/azure/event-hubs/event-processor-balance-partition-load#partition-ownership)

In the typical `EventProcessorClient`, ownership management is completely handled for the developer and is stored in a blob.

With `EventProcessor`, load balancing and partition reclaiming logic relies on the [`ClaimOwnershipAsync`](https://learn.microsoft.com/en-us/dotnet/api/azure.messaging.eventhubs.primitives.eventprocessor-1.claimownershipasync?view=azure-dotnet#azure-messaging-eventhubs-primitives-eventprocessor-1-claimownershipasync(system-collections-generic-ienumerable((azure-messaging-eventhubs-primitives-eventprocessorpartitionownership))-system-threading-cancellationtoken)) and [`ListOwnershipAsync`](https://learn.microsoft.com/en-us/dotnet/api/azure.messaging.eventhubs.primitives.eventprocessor-1.listownershipasync?view=azure-dotnet#azure-messaging-eventhubs-primitives-eventprocessor-1-listownershipasync(system-threading-cancellationtoken)) methods implemented by the developers to store and retrieve ownership data.

As a developer, **you don't have to manage any load balancing or reclaiming logic,** all you have to do is:
- Implement storage of the desired ownership determined by the base class
- Implement reading of the current ownership data

In our sample, these methods are implemented as in the following:
```csharp

protected override async Task<IEnumerable<EventProcessorPartitionOwnership>> 
    ClaimOwnershipAsync(
        IEnumerable<EventProcessorPartitionOwnership> desiredOwnership,
        CancellationToken cancellationToken)
{
    List<EventProcessorPartitionOwnership> ownerships = [];

    foreach (var ownership in desiredOwnership)
    {
        /*
         * Ensure that version field is updated
         */
        string version = Guid.NewGuid().ToString();

        await _checkpointOwnershipStore
            .SetOwnershipAsync(
                ownership.PartitionId,
                new Ownership(ownership.PartitionId, Identifier,
                    ownership.LastModifiedTime, version)
            );

        ownerships.Add(new EventProcessorPartitionOwnership
        {
            ConsumerGroup = ownership.ConsumerGroup,
            EventHubName = ownership.EventHubName,
            FullyQualifiedNamespace = ownership.FullyQualifiedNamespace,
            OwnerIdentifier = Identifier,
            PartitionId = ownership.PartitionId,
            LastModifiedTime = ownership.LastModifiedTime,
            /*
             * Ensure that version field is updated
             */
            Version = version
        });
    }

    return ownerships;
}

protected override async Task<IEnumerable<EventProcessorPartitionOwnership>>
    ListOwnershipAsync(CancellationToken cancellationToken)
{
    var ownership = await _checkpointOwnershipStore.GetAllOwnershipsAsync();

    return ownership
        .Select(o => new EventProcessorPartitionOwnership
        {
            FullyQualifiedNamespace = FullyQualifiedNamespace,
            ConsumerGroup = ConsumerGroup,
            EventHubName = EventHubName,
            OwnerIdentifier = o.OwnerId,
            PartitionId = o.PartitionId,
            LastModifiedTime = o.LastModifiedTime,
            Version = o.Version
        });
}
```

The two methods implementation relies on the `_checkpointOwnershipStore` member which acts as an abstraction for the ownership store.

Ultimately the [`RedisCheckpointOwnershipStore`](https://github.com/MissaouiChedy/BlogSamples/blob/main/AzureEventHubsEventProcessor/AzureEventHubsEventProcessor/CheckpointOwnershipStore/RedisCheckpointOwnershipStore.cs) class implements the `ICheckpointOwnershipStore` interface providing read/write capability in a Redis cache. (More details in the sample 😉)

In `ClaimOwnershipAsync`, we ensure that:
- New version is set for the desired ownership record provided by the base class
- Desired ownership is recorded in the redis cache
- Desired Ownership is returned to the base class as requested

In `ListOwnershipAsync`, we simply return what we stored in the cache via `ClaimOwnershipAsync`.

In Redis, an ownership record for a specific partition will look like this:

<div class="img-container">
  ![Event OwnerShip In Redis]({{ site.url }}/imgs/EventOwnerShipInRedis.png)
</div>

## Managing Partition Checkpoints Storage

To manage checkpoint storage operation, we have 3 methods to implement:

```csharp
protected override async Task<EventProcessorCheckpoint> GetCheckpointAsync(string partitionId,
    CancellationToken cancellationToken)
{
    Checkpoint checkpoint = await _checkpointOwnershipStore
        .GetCheckpointAsync(partitionId);

    if (checkpoint != Checkpoint.Null)
    {
        return new EventProcessorCheckpoint
        {
            StartingPosition = EventPosition.FromSequenceNumber(checkpoint.SequenceNumber),
            PartitionId = partitionId,
            ConsumerGroup = _checkpointOwnershipStore.ConsumerGroup,
            EventHubName = _checkpointOwnershipStore.Eventhub,
            FullyQualifiedNamespace = _checkpointOwnershipStore.EventhubNamespace,
            ClientIdentifier = checkpoint.OwnerId
        };
    }

    return new EventProcessorCheckpoint
    {
        StartingPosition = EventPosition.Earliest,
        PartitionId = partitionId,
        ConsumerGroup = _checkpointOwnershipStore.ConsumerGroup,
        EventHubName = _checkpointOwnershipStore.Eventhub,
        FullyQualifiedNamespace = _checkpointOwnershipStore.EventhubNamespace,
        ClientIdentifier = checkpoint.OwnerId
    };
}

protected override Task UpdateCheckpointAsync(string partitionId, long sequenceNumber,
    long? offset, CancellationToken cancellationToken)
{
    return _checkpointOwnershipStore.SetCheckpointAsync(partitionId, new Checkpoint
    (
        partitionId,
        offset.Value,
        sequenceNumber,
        Identifier
    ));
}

protected override async Task<IEnumerable<EventProcessorCheckpoint>> 
    ListCheckpointsAsync(CancellationToken cancellationToken)
{
    var checkpoints = await _checkpointOwnershipStore.GetAllCheckpointsAsync();

    return checkpoints
        .Select(c => new EventProcessorCheckpoint
        {
            StartingPosition = EventPosition.FromSequenceNumber(c.SequenceNumber),
            PartitionId = c.PartitionId,
            ConsumerGroup = _checkpointOwnershipStore.ConsumerGroup,
            EventHubName = _checkpointOwnershipStore.Eventhub,
            FullyQualifiedNamespace = _checkpointOwnershipStore.EventhubNamespace,
            ClientIdentifier = c.OwnerId
        });
}
```

Implementation is straightforward, we leverage `_checkpointOwnershipStore` to store and retrieve the checkpoint data, doing some data conversion along the way.

In redis, a checkpoint record for a specific partition will look like this:

<div class="img-container">
  ![Event checkpoint In Redis]({{ site.url }}/imgs/EventCheckpointInRedis.png)
</div>

## Additional Customization

Many more methods are overridable in the `EventProcessor` class, among others, you can customize the following behavior:

- Partition Initialization
- On Event Consuming Start
- On Event Consuming stop
- Processing Pre-condition validation

For a complete list, checkout the [`EventProcessor` class documentation.](https://learn.microsoft.com/en-us/dotnet/api/azure.messaging.eventhubs.primitives.eventprocessor-1?view=azure-dotnet)

## Closing Thoughts

The most interesting flexibility points with `EventProcessor` are:
- Batch processing of events
- Control over ownership storage
- Control over checkpoint storage

In our sample, we used the redis in-memory cache as in the previous post. 

While not interesting for storing checkpoint data (due to durability guarantees), **Redis can be interesting for ownership data storage** since *Ownership* is periodically re-calculated via the load balancing and re-claiming mechanisms and thus does not require persistence durability.
