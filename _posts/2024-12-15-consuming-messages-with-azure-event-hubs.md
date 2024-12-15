---
layout: post
title: "Consuming Messages With Azure Event Hubs"
date: 2024-12-15
categories: article
comments: true
---
In [event driven systems,](https://martinfowler.com/articles/201701-event-driven.html) consuming events/messages is usually more tricky then sending messages involving among others concerns such as:

 - Acknowledging processed messages
 - Managed messages we failed to process
 - Scaling message processing

In this post, we will start small by exploring very basic event consuming with Azure Event hubs with a C#/.NET console App.

Full working example [is available on Github as usual.](https://github.com/MissaouiChedy/BlogSamples/tree/main/AzureEventhubsConsumingMessages)

## Message Consuming Concepts

Before diving in the example let's first discuss some message consuming concepts in Event Hubs.

### Consumer Group

[Consumer Groups](https://learn.microsoft.com/en-us/azure/event-hubs/event-hubs-features#consumer-groups) are created under topics (event hubs) and are useful for distributing events to several consumers.


Consider the following messaging structure:
<div class="img-container">
![Azure Event Hubs Consumer Groups]({{ site.url }}/imgs/MessageCGEventHub.png)
</div>

'Application A' sends events to the `Event hub topic` event hub, which is going to be consumed by 3 different applications.

Here we defined 3 consumer groups, one for each application, **this enables each application to receive a copy of each event** sent to the `Event hub topic` event hub.

Consumer groups can be created by using the az cli like so:
```sh
az eventhubs eventhub consumer-group create `
  --consumer-group-name "<CONSUMER_GROUP_NAME>" `
  --eventhub-name "<EVENT_HUB_TOPIC_NAME>" `
  --namespace-name "<EVENT_HUB_NAMESPACE>" `
  --resource-group "<RESOURCE_GROUP_NAME>"
```

> Note that by default, for every created event hub the `$Default` consumer group is created also.


### Checkpoint Store
[The checkpoint store](https://learn.microsoft.com/en-us/azure/event-hubs/event-hubs-features#checkpointing) is typically an [Azure Blob Container](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blobs-introduction) containing the offset and sequence number of the last processed event.

For each consumer group, a folder will be defined containing a file in which offset and sequence number is saved in the metadata of the file:

<div class="img-container">
![Azure Event Hubs CheckPoint Metadata]({{ site.url }}/imgs/CheckPointStoreMetadata.png)
</div>

Recall that event hub does not remove processed events, events are cleaned up based on retention configuration and can be captured for further reprocessing.

Essentially, Event hubs consumer clients refer to the checkpoint data **as 'the needle' to know from which event to start the processing** in the sequence of the event stream.

Storage account and the Blob Container can be created like so using the az cli:
```sh
az storage account create --name $storageAccountName `
  --resource-group $resourceGroupName `
  --access-tier 'Hot' `
  --sku "Standard_LRS" `
  --allow-blob-public-access true

az storage container create --name $storageContainerName `
  --account-name $storageAccountName `
  --auth-mode login
```
Note the following important arguments:
- Storage Account:
  - `--access-tier` here we selected the Hot tier given that we will access the data often
  - `--sku` here we selected Standard_LRS which is the cheaper for our demo purpose
  - `--allow-blob-public-access` here we allowed public access to simplify the access configuration
  - In production scenario, you may want to reconsider these values with cost effectiveness, reliability and security in mind
- Blob Storage
  - `--auth-mode` here we specified [`login` which is the new preferred authentication method based on Entra ID](https://learn.microsoft.com/en-us/azure/storage/blobs/authorize-data-operations-cli) over `key` authentication  

## Simple Message Consuming

To consume messages from the event hub consumer group, we will use the Event Hub SDK nuget package in a simple .NET Console App, [loosely based on the official tutorial😉:](https://learn.microsoft.com/en-us/azure/event-hubs/event-hubs-dotnet-standard-getstarted-send?tabs=passwordless%2Croles-azure-portal)

```csharp
using Azure.Identity;
using Azure.Messaging.EventHubs;
using Azure.Messaging.EventHubs.Processor;
using Azure.Storage.Blobs;
using System.Text;
using System.Text.Json;

/*
 * Create a Blob Container Client Used For check-pointing
 */
var storageClient = new BlobContainerClient(
    new Uri("https://mainconsumerstorageacc.blob.core.windows.net/main-consumer"),
    new DefaultAzureCredential());

/*
 * Create an Event Processor Client for Consuming Events
 */
var processor = new EventProcessorClient(
    storageClient,
    "main-consumer",
    "evh-test-consuming.servicebus.windows.net",
    "main-topic",
    new DefaultAzureCredential());

/*
 * Register event handling methods for processing messages and errors
 */
processor.ProcessEventAsync += ProcessEventHandler;
processor.ProcessErrorAsync += ProcessErrorHandler;

/*
 * Start event processing
 */
await processor.StartProcessingAsync();

Console.WriteLine("Waiting for key press to stop processing...");
Console.ReadKey();

/*
 * Stop event processing before exiting the application
 */
await processor.StopProcessingAsync();

/*
 * Define the event processing method
 */
async Task ProcessEventHandler(ProcessEventArgs eventArgs)
{
    try
    {
        /*
         * Effeciently Deserialize the Message from JSON
         */
        var readOnlySpan = new ReadOnlySpan<byte>(eventArgs.Data.Body.ToArray());
        Message receivedMessage = JsonSerializer
            .Deserialize<Message>(readOnlySpan);

        if (receivedMessage.isValid())
        {
            Console.WriteLine($"\tReceived message: {receivedMessage}");
        }
        else
        {
            string unknownMessage = Encoding
                .UTF8
                .GetString(eventArgs.Data.Body.ToArray());

            Console.WriteLine($"\tReceived Unknown Message Format: {unknownMessage}");
        }
    }
    catch (JsonException)
    {
        /*
         * JSON Deserialization errors are handled
         * in the catch block
         */
        string unknownMessage = Encoding
                .UTF8
                .GetString(eventArgs.Data.Body.ToArray());

        Console.WriteLine($"\tReceived Non Parsable Message: {unknownMessage}");
    }
    /*
     * Update the checkpoint store to mark the event as processed
     */
    await eventArgs.UpdateCheckpointAsync();
}

/*
 * Define the Error Handler Method
 */
Task ProcessErrorHandler(ProcessErrorEventArgs eventArgs)
{
    Console.WriteLine(@$"\tPartition '{eventArgs.PartitionId}':
    an unhandled exception was encountered. This was not expected to happen.");
    Console.WriteLine(eventArgs.Exception.Message);
    return Task.CompletedTask;
}

/*
 * Message Record Definition
 */
readonly record struct Message(Guid Id, DateTime TimeStamp, string Content)
{
    public bool isValid()
    {
        Message defaultMessage = default;

        return Id != defaultMessage.Id
            && TimeStamp != defaultMessage.TimeStamp
            && !string.IsNullOrEmpty(Content);
    }
}
```

At the very bottom of the program we define the Message Record with a `isValid()` method.

At the very beginning, we instantiate a `BlobContainerClient` used by the `EventProcessorClient` for checkpoint store access.

The `EventProcessorClient` **is guaranteed** to be [thread safe](https://learn.microsoft.com/en-us/dotnet/api/overview/azure/messaging.eventhubs.processor-readme?view=azure-dotnet#thread-safety) 
can be created once per application (process) for effective [connection to event hub management.](https://github.com/Azure/azure-sdk-for-net/blob/main/sdk/eventhub/Azure.Messaging.EventHubs/README.md#client-lifetime)

Event processor methods are then registered with the `EventProcessorClient`, one for event handling and one for error handling.

Event processing is then started by calling `StartProcessingAsync()`.

The `ProcessEventHandler` method deserializes the event payload [somewhat efficiently](https://medium.com/@tomas.madajevas/memory-efficient-deserialization-of-nested-json-2f248517129d) by using [`ReadOnlySpan<byte>`](https://learn.microsoft.com/en-us/dotnet/standard/serialization/system-text-json/deserialization#deserialize-from-utf-8) and handles cases where the message is not in JSON format, or is not the expected `Message` record defined in the program.

The `ProcessEventHandler` method then displays the message received directly in the console regardless of the case, this is for demonstration purpose.

Note that at the end of the `ProcessEventHandler` method, we call the `UpdateCheckpointAsync` method that will update the checkpoint store data by moving the latest event *needle*.

Calling the update of the checkpoint is something you have to do yourself as a programmer and [there are good checkpoint update practices,](https://learn.microsoft.com/en-us/azure/architecture/serverless/event-hubs-functions/performance-scale#checkpointing) **keep in mind that 
the checkpoint store should not be updated on every single message processing.**

But for the purpose of our example updating on every message processing is good enough, and this a subject to be addressed in another post.

Finally, once the program starts listening to events, it can be stopped by pressing any key.  

## Observing Message Consumption

To try out our example, we will send messages using [the Event Hubs Data Explorer.](https://learn.microsoft.com/en-us/azure/event-hubs/event-hubs-data-explorer)

<div class="img-container">
![Azure Event Hubs Data Explorer]({{ site.url }}/imgs/EventHubDataExplorer.png)
</div>

In the following sample run, we sent three messages:
1. Non JSON Message
2. Unknown Message Format and then 
3. Properly formed Message

<div class="img-container">
![Azure Event Hubs Message Received]({{ site.url }}/imgs/AzureEventHubsMessageReceived.png)
</div>

We can also observe the outgoing messages directly in the portal:

<div class="img-container">
![Azure Event Hubs Message Received2]({{ site.url }}/imgs/AzureEventHubsMessageReceived2.png)
</div>

## Closing Thoughts

As mentioned in the introduction, message consuming can get interesting when reliability and scaling are involved.

We will explore these concerns in the upcoming posts.