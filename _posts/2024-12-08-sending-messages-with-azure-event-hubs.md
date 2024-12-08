---
layout: post
title: "Sending Messages With Azure Event Hubs"
date: 2024-12-08
categories: article
comments: true
---

[Azure Event Hubs](https://learn.microsoft.com/en-us/azure/event-hubs/event-hubs-about) is a messaging system available as a service in the Microsoft Azure Cloud.

Similar to [Kafka,](https://kafka.apache.org/) event hubs is designed to manage a huge throughput of messaging data and is even compatible with Kafka. 

In this post, let's explore a very simple concept, sending messages. 

Full working code example for this post is [available on Github.](https://github.com/MissaouiChedy/BlogSamples/tree/main/AzureEventHubSendingMessages)

## Event Hubs Namespaces and Event Hubs

### Namespaces
To use event hubs, we start by creating an event hubs namespace.

You can think of event hubs namespaces as containers for event hubs, event hubs are simply topics to which you can send messages.

We can create an event hubs namespace in our subscription by using the following [az cli snippet:](https://learn.microsoft.com/en-us/cli/azure/eventhubs/namespace?view=azure-cli-latest#az-eventhubs-namespace-create)
```sh
az eventhubs namespace create `
  --name 'eventhub-namespace-name' ` # should be globally unique 
  --resource-group 'resource-group-name' `
  --location '<REGION-NAME>' `
  --sku Standard `
  --capacity 1
```

In the previous, you have to provide the following arguments among others:
- sku: pricing tier for the event hub
- capacity: capacity of the event hub in [TU (Throughput units)](https://learn.microsoft.com/en-us/azure/event-hubs/event-hubs-scalability#throughput-units)

The previous argument are important because they impact, **the availability, performance and cost** of the namespace.

When considering cost vs required capacity with Azure Event Hub, we first have to consider [the pricing tier](https://learn.microsoft.com/en-us/azure/event-hubs/compare-tiers) and there are several available:
- **Basic:**
  - Designed for entry-level workloads with low throughput and minimal features.
  - Capacity is measured in TU.
  - Includes features like partitioning and standard availability.

- **Standard:**
  - Suitable for most production scenarios requiring higher throughput.
  - Capacity is measured in TU.
  - Offers 20 consumer groups and scaling via throughput units (TUs).
  - Supports additional features like Event Hubs Capture to Azure Blob Storage or Data Lake.

- **Premium:**
  - Optimized for mission-critical applications with guaranteed performance and isolation.
  - Capacity is measured in PU [(Processing Unit)](https://learn.microsoft.com/en-us/azure/event-hubs/event-hubs-scalability#processing-units)
  - Includes dedicated compute resources, lower latency, and support for VNET and private endpoints.
  - Offers advanced features like availability zones for enhanced reliability.

- **Dedicated:**
  - Provides a dedicated cluster for organizations with massive ingestion needs.
  - Ideal for scenarios requiring unlimited throughput and full control over the infrastructure.
  - Customizable with Event Hubs' maximum limits adjusted to specific workloads.

In the *Standard* pricing tier, capacity is measured in Throughput units.

1 TU is equivalent to:
- For incoming messages (sending): Up to 1 MB per second or 1,000 events per second (whichever comes first).
- For Outgoing messages (consuming): Up to 2 MB per second or 4,096 events per second.

In the *Premium* tier, **we can get more isolation** for the event hub workload and the capacity is measure in PU [(Processing Unit).](https://learn.microsoft.com/en-us/azure/event-hubs/event-hubs-scalability#processing-units)

PU represents a dedicated amount of compute (CPU Cores and RAM) resources for the workload. 

### Event Hub
To define a topic (called Event Hub in the context of azure event hub) in the event hub namespace, we can use the following az cli snippet:
```sh
az eventhubs eventhub create `
  --name "<EventHubName>" `
  --namespace-name "eventhub-namespace-name" `
  --resource-group 'resource-group-name' `
  --cleanup-policy Delete `
  --retention-time 2 `
  --partition-count 1
```

Notable arguments here are:
  - retention-time
  - cleanup-policy
  - partition-count

Event hub is designed to enable **message replay,** that is why it gives to the users the possibility to configure message retention and cleanup policy.

The partition concept is related to message consuming and to scaling horizontally with message throughput. 

We will explain it further in another post, for now you can just assume that partitions are the unit of scale, the more the partitions the more you can scale message consuming horizontally.

## Sending Messages
To send messages to the event hub, we will use the Event Hub SDK nuget package in a simple .NET Console App, [loosely based on the official tutorial😉:](https://learn.microsoft.com/en-us/azure/event-hubs/event-hubs-dotnet-standard-getstarted-send?tabs=passwordless%2Croles-azure-portal
)

```csharp
using Azure.Identity;
using Azure.Messaging.EventHubs;
using Azure.Messaging.EventHubs.Producer;
using System.Text;
using System.Text.Json;

int eventsCount = 10;
/*
 * Initialize the Producer Client Object
 */
EventHubProducerClient evhProducer = new EventHubProducerClient(
    "evh-test-sending.servicebus.windows.net",
    "main-topic",
    new DefaultAzureCredential());

/*
 * Use the Producer Client to create an event batch
 */
using EventDataBatch eventBatch = await evhProducer.CreateBatchAsync();

/*
 * Create a Batch of Messages
 */
Enumerable
    .Range(0, eventsCount)
    .ToList()
    .ForEach((_) =>
    {
        Message message = new(
            Guid.NewGuid(),
            DateTime.UtcNow,
            "KABLAM"
        );

        byte[] messageInBinary = Encoding
            .UTF8
            .GetBytes(JsonSerializer.Serialize(message));

        if (!eventBatch.TryAdd(new EventData(messageInBinary)))
        {
            throw new Exception($"Event is too large for the batch and cannot be sent.");
        }
    });

/*
 * Send The Event Batch, read key from console,
 * then dispose of Producer Client
 */
try
{
    await evhProducer.SendAsync(eventBatch);
    Console.WriteLine($"Batch of {eventsCount} events sent.");
    Console.ReadKey();
}
finally
{
    await evhProducer.DisposeAsync();
}

/*
 * Message Record Definition
 */
readonly record struct Message(Guid Id, DateTime TimeStamp, string Content) { }
```

At the very bottom of the program, we define the `Message` record which is our message format

At the beginning, we create an `EventHubProducerClient` by using `new DefaultAzureCredential()`, this enables us to authenticate to EventHub without having to use 
a connection string and to connect via az cli authentication locally and [Managed Identity](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview) Authentication in Azure Environments. 

`EventHubProducerClient` enables us then to create a message batch that we populate in our case with `eventsCount` messages.

Note here that messages are first serialized to a JSON string and are then converted to binary based on the UTF8 encoding, **Deserialization will have to assume** this encoding to be able to decode the message. 

Finally we send the message batch, you can observe if messages were sent successfully directly in the Azure Portal on the event hub resource's blade:

<div class="img-container">
![Azure Event Hub Message Sent]({{ site.url }}/imgs/AzureEventHubMessageSent.png)
</div>

## Closing Thoughts

With messaging system, usually sending messages is the easy part. It gets more interesting with message consuming and messaging resources creation.

We will explore this in the upcoming posts.
